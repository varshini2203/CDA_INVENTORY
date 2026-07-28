// lib/services/bulk_import/module_import_configs.dart
//
// The ONLY file a module needs to add/edit to plug into the Dynamic Bulk
// Import Engine. Each `ModuleImportConfig` below configures exactly the
// three things the requirements call for:
//   1. Required fields
//   2. Optional fields (+ their defaults)
//   3. Firestore collection
// ...and reuses this project's EXISTING models/services for everything
// else — `InventoryItem`/`InventoryService`, `NewProduct`/
// `NewProductService`, `InventorySyncService`, `ActivityLogService` — the
// engine never talks to Firestore in a module-specific way; it only calls
// back into the functions configured here.
//
// Alias groups follow the examples from the spec, e.g.:
//   Product Name = Product, Name, Item, Item Name
//   Quantity = Qty, Stock, Available Qty
//   Category = Type
//   Location = Rack, Row, Shelf, Tray
//   Date = Stock Date, Added Date
//
// To add a future module (Consumables, Fixed Assets, Purchase Orders...):
// write one more `ModuleImportConfig` here, add it to `moduleImportConfigs`,
// and (if it needs a screen) point a `BulkImportScreen` at its key. No
// changes to the parser or engine are ever required.

import '../../models/inventory_model.dart';
import '../../models/new_product.dart';
import '../activity_log_service.dart';
import '../inventory_service.dart';
import '../inventory_sync_service.dart';
import '../new_product_service.dart';
import 'import_field_config.dart';

// ── Shared alias groups (reused across modules so "Location" etc. behave
//    identically everywhere) ─────────────────────────────────────────────
const _nameAliases = ['product name', 'product', 'name', 'item', 'item name'];
const _quantityAliases = ['quantity', 'qty', 'stock', 'available qty'];
const _categoryAliases = ['category', 'type'];
const _locationAliases = [
  'location',
  'rack',
  'row',
  'shelf',
  'tray',
  'storage location',
];
const _dateAliases = ['date', 'stock date', 'added date'];
const _branchAliases = ['branch'];
const _addedByAliases = ['added by', 'requested by'];
const _descriptionAliases = ['description', 'desc', 'notes', 'remarks'];

String _norm(String? s) => (s ?? '').trim().toLowerCase();

String _asText(Map<String, dynamic> row, String key, [String fallback = '']) {
  final v = row[key];
  if (v == null) return fallback;
  final s = v.toString().trim();
  return s.isEmpty ? fallback : s;
}

int _asInt(Map<String, dynamic> row, String key, [int fallback = 0]) {
  final v = row[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return fallback;
}

double _asDouble(Map<String, dynamic> row, String key, [double fallback = 0]) {
  final v = row[key];
  if (v is num) return v.toDouble();
  return fallback;
}

DateTime? _asDate(Map<String, dynamic> row, String key) {
  final v = row[key];
  return v is DateTime ? v : null;
}

// ═══════════════════════════════════════════════════════════════════════
//  INVENTORY
// ═══════════════════════════════════════════════════════════════════════
// Branch is stored on `InventoryItem` as an int (1 = CDA Admin, 2 = CDA
// Ops, 0 = unassigned) — same normalization the old bulk-import screen
// used, ported over unchanged.
int _normalizeInventoryBranch(String raw) {
  final norm = _norm(raw);
  if (norm.isEmpty) return 0;
  if (norm.contains('admin')) return 1;
  if (norm.contains('ops')) return 2;
  return int.tryParse(norm) ?? 0;
}

final ModuleImportConfig inventoryImportConfig = ModuleImportConfig(
  moduleKey: 'inventory',
  moduleLabel: 'Inventory',
  collectionPath: 'inventory',
  titleFieldKey: 'name',
  quantityFieldKey: 'quantity',
  fields: [
    const ImportFieldConfig(
      key: 'name',
      label: 'Product Name',
      aliases: _nameAliases,
      required: true,
    ),
    const ImportFieldConfig(
      key: 'category',
      label: 'Category',
      aliases: _categoryAliases,
      defaultValue: 'ONFIELD',
    ),
    const ImportFieldConfig(
      key: 'quantity',
      label: 'Quantity',
      aliases: _quantityAliases,
      type: ImportValueType.integer,
      defaultValue: 1,
    ),
    const ImportFieldConfig(
      key: 'location',
      label: 'Location',
      aliases: _locationAliases,
      defaultValue: '',
    ),
    const ImportFieldConfig(
      key: 'description',
      label: 'Description',
      aliases: _descriptionAliases,
      defaultValue: '',
    ),
    const ImportFieldConfig(
      key: 'branch',
      label: 'Branch',
      aliases: _branchAliases,
      defaultValue: '',
    ),
    const ImportFieldConfig(
      key: 'addedBy',
      label: 'Added By',
      aliases: _addedByAliases,
      defaultValue: 'Bulk Import',
    ),
    // Recognized so a "Stock Date" / "Added Date" column is never dumped
    // into "unrecognized columns" — `InventoryItem` has no date field of
    // its own (createdAt is stamped by the engine), so it's parsed and
    // then simply not written.
    const ImportFieldConfig(
      key: 'date',
      label: 'Date',
      aliases: _dateAliases,
      type: ImportValueType.date,
    ),
  ],
  buildDedupeKey: (row) => [
    _norm(_asText(row, 'name')),
    _normalizeInventoryBranch(_asText(row, 'branch')),
    _norm(_asText(row, 'location')),
  ].join('|'),
  buildDedupeKeyFromDoc: (doc) => [
    _norm(doc['name'] as String?),
    (doc['branch'] as num?)?.toInt() ?? 0,
    _norm(doc['location'] as String?),
  ].join('|'),
  buildFields: (row) {
    // Reuses `InventoryItem` itself to build the field map, so the
    // Firestore document this engine writes is byte-for-byte the same
    // shape `InventoryService.addProduct` already writes.
    final item = InventoryItem(
      id: '',
      name: _asText(row, 'name'),
      category: _asText(row, 'category', 'ONFIELD'),
      location: _asText(row, 'location'),
      quantity: _asInt(row, 'quantity', 1),
      description: _asText(row, 'description'),
      branch: _normalizeInventoryBranch(_asText(row, 'branch')),
      addedBy: _asText(row, 'addedBy', 'Bulk Import'),
    );
    final map = item.toMap();
    // The engine stamps its own timestamps uniformly across every module.
    map.remove('createdAt');
    map.remove('updatedAt');
    return map;
  },
  afterWrite: (docId, fields) async {
    InventoryService.clearCache();
    await InventorySyncService.syncFromInventoryAdd(
      InventoryItem(
        id: docId,
        name: (fields['name'] as String?) ?? '',
        category: (fields['category'] as String?) ?? 'ONFIELD',
        location: (fields['location'] as String?) ?? '',
        quantity: (fields['quantity'] as num?)?.toInt() ?? 0,
        description: (fields['description'] as String?) ?? '',
        branch: (fields['branch'] as num?)?.toInt() ?? 0,
        addedBy: fields['addedBy'] as String?,
      ),
    );
  },
  clearCache: InventoryService.clearCache,
);

// ═══════════════════════════════════════════════════════════════════════
//  NEW PRODUCTS
// ═══════════════════════════════════════════════════════════════════════
// Branch on `NewProduct` is a display string ('CDA Admin' / 'CDA Ops'),
// ported unchanged from the old bulk-import screen's normalization.
String _normalizeNewProductBranch(String raw) {
  final norm = _norm(raw);
  if (norm.contains('admin')) return 'CDA Admin';
  if (norm.contains('ops')) return 'CDA Ops';
  return norm.isEmpty ? 'CDA Admin' : raw.trim();
}

final ModuleImportConfig newProductsImportConfig = ModuleImportConfig(
  moduleKey: 'newProducts',
  moduleLabel: 'New Products',
  collectionPath: 'new_products',
  titleFieldKey: 'productName',
  quantityFieldKey: 'quantity',
  fields: [
    const ImportFieldConfig(
      key: 'productName',
      label: 'Product Name',
      aliases: _nameAliases,
      required: true,
    ),
    const ImportFieldConfig(
      key: 'productCode',
      label: 'Product Code',
      aliases: ['product code', 'code', 'sku'],
      defaultValue: '',
    ),
    const ImportFieldConfig(
      key: 'category',
      label: 'Category',
      aliases: _categoryAliases,
      defaultValue: 'General',
    ),
    const ImportFieldConfig(
      key: 'brand',
      label: 'Brand',
      aliases: ['brand'],
      defaultValue: '',
    ),
    const ImportFieldConfig(
      key: 'modelNumber',
      label: 'Model Number',
      aliases: ['model number', 'model', 'model no'],
      defaultValue: '',
    ),
    const ImportFieldConfig(
      key: 'description',
      label: 'Description',
      aliases: ['description', 'desc'],
      defaultValue: '',
    ),
    const ImportFieldConfig(
      key: 'vendorName',
      label: 'Vendor Name',
      aliases: ['vendor name', 'vendor', 'supplier'],
      defaultValue: '',
    ),
    const ImportFieldConfig(
      key: 'vendorContact',
      label: 'Vendor Contact',
      aliases: ['vendor contact', 'contact', 'phone'],
      defaultValue: '',
    ),
    const ImportFieldConfig(
      key: 'vendorEmail',
      label: 'Vendor Email',
      aliases: ['vendor email', 'email'],
      defaultValue: '',
    ),
    ImportFieldConfig(
      key: 'purchaseDate',
      label: 'Purchase Date',
      aliases: const ['purchase date', ..._dateAliases],
      type: ImportValueType.date,
      defaultValueBuilder: () => DateTime.now(),
    ),
    const ImportFieldConfig(
      key: 'purchaseCost',
      label: 'Purchase Cost',
      aliases: ['purchase cost', 'purchase price', 'cost', 'price', 'amount'],
      type: ImportValueType.decimal,
      defaultValue: 0.0,
    ),
    const ImportFieldConfig(
      key: 'quantity',
      label: 'Quantity',
      aliases: [..._quantityAliases, 'stock quantity', 'stock qty'],
      type: ImportValueType.integer,
      defaultValue: 1,
    ),
    const ImportFieldConfig(
      key: 'unit',
      label: 'Unit',
      aliases: ['unit', 'uom'],
      defaultValue: 'Pcs',
    ),
    const ImportFieldConfig(
      key: 'salePrice',
      label: 'Sale Price',
      aliases: ['sale price', 'selling price', 'mrp'],
      type: ImportValueType.decimal,
      defaultValue: 0.0,
    ),
    // No generic default — falls back to Quantity in `buildFields` below,
    // same behavior the previous bulk-import screen had.
    const ImportFieldConfig(
      key: 'availableQuantityForSale',
      label: 'Available Quantity for Sale',
      aliases: [
        'available quantity for sale',
        'available qty for sale',
        'available quantity',
        'available for sale',
      ],
      type: ImportValueType.integer,
    ),
    const ImportFieldConfig(
      key: 'reservedQuantity',
      label: 'Reserved Quantity',
      aliases: ['reserved quantity', 'reserved qty', 'reserved'],
      type: ImportValueType.integer,
      defaultValue: 0,
    ),
    const ImportFieldConfig(
      key: 'stockValue',
      label: 'Stock Value',
      aliases: ['stock value', 'total value', 'inventory value'],
      type: ImportValueType.decimal,
      defaultValue: 0.0,
    ),
    const ImportFieldConfig(
      key: 'branch',
      label: 'Branch',
      aliases: _branchAliases,
      defaultValue: '',
    ),
    const ImportFieldConfig(
      key: 'storageLocation',
      label: 'Storage Location',
      aliases: _locationAliases,
      defaultValue: '',
    ),
    const ImportFieldConfig(
      key: 'minimumStockLevel',
      label: 'Minimum Stock Level',
      aliases: ['minimum stock level', 'min stock', 'minimum stock'],
      type: ImportValueType.integer,
      defaultValue: 0,
    ),
    const ImportFieldConfig(
      key: 'status',
      label: 'Status',
      aliases: ['status'],
      defaultValue: 'In Stock',
    ),
    const ImportFieldConfig(
      key: 'addedBy',
      label: 'Added By',
      aliases: _addedByAliases,
      defaultValue: 'Bulk Import',
    ),
    const ImportFieldConfig(
      key: 'employeeId',
      label: 'Employee ID',
      aliases: ['employee id', 'emp id'],
      defaultValue: '',
    ),
    const ImportFieldConfig(
      key: 'department',
      label: 'Department',
      aliases: ['department'],
      defaultValue: '',
    ),
    const ImportFieldConfig(
      key: 'remarks',
      label: 'Remarks',
      aliases: ['remarks'],
      defaultValue: '',
    ),
  ],
  buildDedupeKey: (row) {
    final code = _norm(_asText(row, 'productCode'));
    final identity = code.isNotEmpty ? code : _norm(_asText(row, 'productName'));
    return '$identity|${_norm(_normalizeNewProductBranch(_asText(row, 'branch')))}';
  },
  buildDedupeKeyFromDoc: (doc) {
    final code = _norm(doc['productCode'] as String?);
    final identity = code.isNotEmpty ? code : _norm(doc['productName'] as String?);
    return '$identity|${_norm(doc['branch'] as String?)}';
  },
  buildFields: (row) {
    final quantity = _asInt(row, 'quantity', 1);
    // Reuses `NewProduct` itself to build the field map, so the document
    // shape matches exactly what `NewProductService.addNewProduct` writes.
    final product = NewProduct(
      productId: '',
      productName: _asText(row, 'productName'),
      productCode: _asText(row, 'productCode'),
      category: _asText(row, 'category', 'General'),
      brand: _asText(row, 'brand'),
      modelNumber: _asText(row, 'modelNumber'),
      description: _asText(row, 'description'),
      vendorName: _asText(row, 'vendorName'),
      vendorContact: _asText(row, 'vendorContact'),
      vendorEmail: _asText(row, 'vendorEmail'),
      purchaseDate: _asDate(row, 'purchaseDate') ?? DateTime.now(),
      purchaseCost: _asDouble(row, 'purchaseCost'),
      quantity: quantity,
      unit: _asText(row, 'unit', 'Pcs'),
      salePrice: _asDouble(row, 'salePrice'),
      // Falls back to Quantity when the file has no dedicated "Available
      // Quantity for Sale" column, same as a fresh row on the Stock
      // Summary Report where the two start out equal.
      availableQuantityForSale:
      row['availableQuantityForSale'] != null
          ? _asInt(row, 'availableQuantityForSale')
          : quantity,
      reservedQuantity: _asInt(row, 'reservedQuantity'),
      stockValue: _asDouble(row, 'stockValue'),
      branch: _normalizeNewProductBranch(_asText(row, 'branch')),
      storageLocation: _asText(row, 'storageLocation'),
      minimumStockLevel: _asInt(row, 'minimumStockLevel'),
      status: _asText(row, 'status', 'In Stock'),
      addedBy: _asText(row, 'addedBy', 'Bulk Import'),
      employeeId: _asText(row, 'employeeId'),
      department: _asText(row, 'department'),
      remarks: _asText(row, 'remarks'),
    );
    return product.toMap();
  },
  afterWrite: (docId, fields) async {
    NewProductService.clearCache();
    final product = NewProduct.fromMap(docId, fields);
    // Mirrors `NewProductService.addNewProduct`'s own fan-out: push into
    // Inventory, Search Products, Branch, Stock Management and Fixed
    // Assets/Consumables, so bulk-imported New Products show up
    // everywhere a manually-added one would.
    await InventorySyncService.syncFromNewProductAdd(product);
  },
  clearCache: NewProductService.clearCache,
);

// ═══════════════════════════════════════════════════════════════════════
//  STOCK MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════
// Not yet migrated onto the full engine (see the note in
// bulk_import_screen.dart) — the legacy path only uses this config to
// drive `DynamicImportParser.parse()` (dynamic header/alias matching +
// required-field validation) and then reads `row.values['name']`,
// `row.values['branch']`, `row.values['quantity']`, `row.values['category']`
// and `row.values['location']` directly. `buildDedupeKey` /
// `buildDedupeKeyFromDoc` / `buildFields` below are unused for now, but are
// kept consistent with the other configs so this module can be switched
// onto the full engine later with no changes to this file.
final ModuleImportConfig stockManagementImportConfig = ModuleImportConfig(
  moduleKey: 'stockManagement',
  moduleLabel: 'Stock Management',
  collectionPath: 'stock_management',
  titleFieldKey: 'name',
  quantityFieldKey: 'quantity',
  fields: [
    const ImportFieldConfig(
      key: 'name',
      label: 'Product Name',
      aliases: _nameAliases,
      required: true,
    ),
    const ImportFieldConfig(
      key: 'category',
      label: 'Category',
      aliases: _categoryAliases,
      defaultValue: 'consumable',
    ),
    const ImportFieldConfig(
      key: 'quantity',
      label: 'Quantity',
      aliases: _quantityAliases,
      type: ImportValueType.integer,
      defaultValue: 1,
    ),
    const ImportFieldConfig(
      key: 'location',
      label: 'Location',
      aliases: _locationAliases,
      defaultValue: '',
    ),
    const ImportFieldConfig(
      key: 'branch',
      label: 'Branch',
      aliases: _branchAliases,
      defaultValue: '',
    ),
  ],
  buildDedupeKey: (row) => [
    _norm(_asText(row, 'name')),
    _norm(_asText(row, 'branch')),
  ].join('|'),
  buildDedupeKeyFromDoc: (doc) => [
    _norm(doc['name'] as String?),
    _norm(doc['branch'] as String?),
  ].join('|'),
  buildFields: (row) => {
    'name': _asText(row, 'name'),
    'category': _asText(row, 'category', 'consumable'),
    'quantity': _asInt(row, 'quantity', 1),
    'location': _asText(row, 'location'),
    'branch': _asText(row, 'branch'),
  },
);

/// Every module currently wired into the engine, keyed by
/// `ModuleImportConfig.moduleKey`. Add a future module's config here.
final Map<String, ModuleImportConfig> moduleImportConfigs = {
  inventoryImportConfig.moduleKey: inventoryImportConfig,
  newProductsImportConfig.moduleKey: newProductsImportConfig,
  stockManagementImportConfig.moduleKey: stockManagementImportConfig,
};

/// One place recording that a bulk import run happened, reusing
/// `ActivityLogService` exactly like the rest of this app's write paths.
Future<void> logBulkImportSummary({
  required ModuleImportConfig config,
  required int total,
  required int created,
  required int updated,
  required int skipped,
  required int failed,
  String? importedBy,
}) async {
  try {
    await ActivityLogService.logAction(
      'Bulk import: $total row(s) — $created created, $updated updated, '
          '$skipped skipped, $failed failed',
      module: config.moduleLabel,
      details: importedBy != null ? 'Imported by $importedBy' : null,
    );
  } catch (_) {
    // Logging must never fail the import itself.
  }
}