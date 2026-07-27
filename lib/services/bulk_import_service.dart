// lib/services/bulk_import_service.dart
//
// Parses bulk-upload files (Excel .xlsx or PDF) into plain row maps that
// the Bulk Import screen can preview, edit, and commit. Column headers
// are matched fuzzily against a set of known aliases per target model, so
// the same file works whether the header says "Name", "Item Name" or
// "Product Name".
//
// IMPORTANT — PDF parsing is heuristic. PDFs have no real "table"
// structure once text is extracted; this reconstructs columns by
// splitting each line on runs of 2+ spaces / tabs, which is the same
// trick used for plain-text table recovery. It works reasonably well for
// simple, left-aligned tables exported straight from Excel/Sheets, but
// will misfire on multi-line cells, merged cells, or tightly-packed
// columns. The Bulk Import screen always shows a warning banner and a
// full row-by-row review step before anything is written to Firestore —
// never trust this output blindly.
//
// Requires these packages in pubspec.yaml (in addition to the `excel`
// package already used by ExcelExportService):
//   file_picker: ^8.0.0
//   syncfusion_flutter_pdf: ^26.0.0   // free "Community" license, no key needed

import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:syncfusion_flutter_pdf/pdf.dart';

enum BulkImportTarget { newProducts, inventory, stockManagement }

class BulkImportResult {
  final List<String> headers; // raw header text, as found in the file
  final List<Map<String, String>> rows; // raw header -> raw cell text
  final List<String> warnings;

  const BulkImportResult({
    required this.headers,
    required this.rows,
    this.warnings = const [],
  });

  bool get isEmpty => rows.isEmpty;
}

class BulkImportService {
  BulkImportService._();

  // ── Known field aliases, per target ─────────────────────────────────────
  // Header text is lower-cased + trimmed before matching, so "Qty", "qty "
  // and "QTY" all match 'qty'.
  static const Map<BulkImportTarget, Map<String, List<String>>> _aliases = {
    BulkImportTarget.newProducts: {
      'productName': ['product name', 'name', 'item name', 'product'],
      'productCode': ['product code', 'code', 'sku'],
      'category': ['category'],
      'brand': ['brand'],
      'modelNumber': ['model number', 'model', 'model no'],
      'description': ['description', 'desc'],
      'vendorName': ['vendor name', 'vendor', 'supplier'],
      'vendorContact': ['vendor contact', 'contact', 'phone'],
      'vendorEmail': ['vendor email', 'email'],
      'purchaseDate': ['purchase date', 'date'],
      // "Purchase Price" is the Stock Summary Report's column name for
      // this same cost figure.
      'purchaseCost': [
        'purchase cost',
        'purchase price',
        'cost',
        'price',
        'amount',
      ],
      // "Stock Quantity" is the Stock Summary Report's column name for
      // this same on-hand count.
      'quantity': ['quantity', 'qty', 'stock quantity', 'stock qty'],
      'unit': ['unit', 'uom'],
      // ── Stock Summary Report columns (Sale Price / Available Quantity
      //    for Sale / Reserved Quantity / Stock Value) — imported straight
      //    onto the matching NewProduct fields, no manual remapping. ────
      'salePrice': ['sale price', 'selling price', 'mrp'],
      'availableQuantityForSale': [
        'available quantity for sale',
        'available qty for sale',
        'available quantity',
        'available for sale',
      ],
      'reservedQuantity': ['reserved quantity', 'reserved qty', 'reserved'],
      'stockValue': ['stock value', 'total value', 'inventory value'],
      'branch': ['branch'],
      'storageLocation': ['storage location', 'location'],
      'minimumStockLevel': [
        'minimum stock level',
        'min stock',
        'minimum stock',
      ],
      'status': ['status'],
      'addedBy': ['added by', 'requested by'],
      'employeeId': ['employee id', 'emp id'],
      'department': ['department'],
      'remarks': ['remarks', 'notes'],
    },
    BulkImportTarget.inventory: {
      'name': ['name', 'item name', 'product name'],
      'category': ['category'],
      'location': ['location'],
      'quantity': ['quantity', 'qty'],
      'description': ['description', 'desc'],
      'branch': ['branch'],
      'addedBy': ['added by'],
    },
    BulkImportTarget.stockManagement: {
      'name': ['name', 'item name', 'product name'],
      'category': ['category', 'type'],
      'quantity': ['quantity', 'qty', 'stock quantity', 'stock qty'],
      'branch': ['branch'],
      'minStock': ['min stock', 'minimum stock', 'minimum stock level'],
      'unit': ['unit', 'uom'],
      'sku': ['sku', 'code', 'product code'],
      'location': ['location', 'storage location'],
    },
  };

  /// The one field each target absolutely cannot be saved without.
  static const Map<BulkImportTarget, String> requiredField = {
    BulkImportTarget.newProducts: 'productName',
    BulkImportTarget.inventory: 'name',
    BulkImportTarget.stockManagement: 'name',
  };

  /// Human-readable labels for the internal field keys above, used when
  /// rendering the editable preview rows.
  static const Map<String, String> fieldLabels = {
    'productName': 'Product Name',
    'productCode': 'Product Code',
    'category': 'Category',
    'brand': 'Brand',
    'modelNumber': 'Model Number',
    'description': 'Description',
    'vendorName': 'Vendor Name',
    'vendorContact': 'Vendor Contact',
    'vendorEmail': 'Vendor Email',
    'purchaseDate': 'Purchase Date',
    'purchaseCost': 'Purchase Cost',
    'quantity': 'Quantity',
    'unit': 'Unit',
    'salePrice': 'Sale Price',
    'availableQuantityForSale': 'Available Quantity for Sale',
    'reservedQuantity': 'Reserved Quantity',
    'stockValue': 'Stock Value',
    'branch': 'Branch',
    'storageLocation': 'Storage Location',
    'minimumStockLevel': 'Minimum Stock Level',
    'status': 'Status',
    'addedBy': 'Added By',
    'employeeId': 'Employee ID',
    'department': 'Department',
    'remarks': 'Remarks',
    'name': 'Name',
    'location': 'Location',
    'minStock': 'Minimum Stock',
    'sku': 'SKU / Code',
  };

  /// The order fields should appear in on the preview card.
  static const Map<BulkImportTarget, List<String>> fieldOrder = {
    BulkImportTarget.newProducts: [
      'productName',
      'productCode',
      'category',
      'brand',
      'modelNumber',
      'quantity',
      'unit',
      'purchaseCost',
      'salePrice',
      'availableQuantityForSale',
      'reservedQuantity',
      'stockValue',
      'purchaseDate',
      'vendorName',
      'vendorContact',
      'vendorEmail',
      'branch',
      'storageLocation',
      'minimumStockLevel',
      'status',
      'addedBy',
      'employeeId',
      'department',
      'description',
      'remarks',
    ],
    BulkImportTarget.inventory: [
      'name',
      'category',
      'location',
      'quantity',
      'branch',
      'addedBy',
      'description',
    ],
    BulkImportTarget.stockManagement: [
      'name',
      'category',
      'quantity',
      'branch',
      'minStock',
      'unit',
      'sku',
      'location',
    ],
  };

  /// Maps a raw spreadsheet/PDF header row onto our internal field keys.
  /// Returns e.g. {'Product Name': 'productName', 'Qty': 'quantity'}.
  /// Headers that don't match anything known are simply left out.
  static Map<String, String> mapHeaders(
      List<String> rawHeaders, BulkImportTarget target) {
    final aliasMap = _aliases[target]!;
    final result = <String, String>{};
    for (final raw in rawHeaders) {
      final norm = raw.trim().toLowerCase();
      if (norm.isEmpty) continue;
      for (final entry in aliasMap.entries) {
        if (entry.value.contains(norm)) {
          result[raw] = entry.key;
          break;
        }
      }
    }
    return result;
  }

  /// Converts raw parsed rows into internal-field-keyed rows, using
  /// [mapHeaders]. Columns that weren't recognized are dropped (their raw
  /// headers are returned separately so the UI can warn about them).
  static ({List<Map<String, String>> rows, List<String> unrecognized})
  toFieldRows(BulkImportResult result, BulkImportTarget target) {
    final headerMap = mapHeaders(result.headers, target);
    final unrecognized =
    result.headers.where((h) => !headerMap.containsKey(h)).toList();

    final fieldRows = result.rows.map((raw) {
      final mapped = <String, String>{};
      raw.forEach((header, value) {
        final field = headerMap[header];
        if (field != null && value.trim().isNotEmpty) {
          mapped[field] = value.trim();
        }
      });
      return mapped;
    }).toList();

    return (rows: fieldRows, unrecognized: unrecognized);
  }

  // ── EXCEL ────────────────────────────────────────────────────────────────
  static BulkImportResult parseExcel(Uint8List bytes) {
    final book = xls.Excel.decodeBytes(bytes);
    if (book.tables.isEmpty) {
      return const BulkImportResult(
        headers: [],
        rows: [],
        warnings: ['The workbook has no sheets.'],
      );
    }

    final sheet = book.tables[book.tables.keys.first]!;
    if (sheet.maxRows == 0) {
      return const BulkImportResult(
        headers: [],
        rows: [],
        warnings: ['The first sheet is empty.'],
      );
    }

    final headerRow = sheet
        .row(0)
        .map((c) => (c?.value ?? '').toString().trim())
        .toList();

    final rows = <Map<String, String>>[];
    for (var r = 1; r < sheet.maxRows; r++) {
      final cells = sheet.row(r);
      final isBlank = cells.every(
              (c) => c == null || c.value == null || c.value.toString().trim().isEmpty);
      if (isBlank) continue;

      final map = <String, String>{};
      for (var c = 0; c < headerRow.length && c < cells.length; c++) {
        map[headerRow[c]] = (cells[c]?.value ?? '').toString().trim();
      }
      rows.add(map);
    }

    return BulkImportResult(headers: headerRow, rows: rows);
  }

  // ── PDF (heuristic — text extraction, not real table parsing) ──────────
  static BulkImportResult parsePdf(Uint8List bytes) {
    final warnings = <String>[
      'PDF import is heuristic — columns are reconstructed from spacing in '
          'the extracted text, not a real table structure. Review every row '
          'below carefully before importing; when in doubt, use Excel instead.',
    ];

    late final String text;
    try {
      final doc = PdfDocument(inputBytes: bytes);
      text = PdfTextExtractor(doc).extractText();
      doc.dispose();
    } catch (e) {
      return BulkImportResult(
        headers: const [],
        rows: const [],
        warnings: [...warnings, 'Could not read this PDF: $e'],
      );
    }

    final lines = text
        .split('\n')
        .map((l) => l.trimRight())
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return BulkImportResult(
        headers: const [],
        rows: const [],
        warnings: [
          ...warnings,
          'No text could be extracted — this PDF may be a scanned image '
              'rather than a real text/table PDF.',
        ],
      );
    }

    // Split each line into "columns" on runs of 2+ spaces or a tab.
    final colSplit = RegExp(r'\s{2,}|\t');
    List<String> splitLine(String line) => line
        .split(colSplit)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final headerCells = splitLine(lines.first);
    if (headerCells.length < 2) {
      return BulkImportResult(
        headers: const [],
        rows: const [],
        warnings: [
          ...warnings,
          'Could not detect a header row with multiple columns — this PDF '
              'may not contain a plain table.',
        ],
      );
    }

    final rows = <Map<String, String>>[];
    for (var i = 1; i < lines.length; i++) {
      final cells = splitLine(lines[i]);
      if (cells.isEmpty) continue;
      final map = <String, String>{};
      for (var c = 0; c < headerCells.length && c < cells.length; c++) {
        map[headerCells[c]] = cells[c];
      }
      rows.add(map);
    }

    if (rows.isEmpty) {
      warnings.add('Only a header row was found — no data rows detected.');
    }

    return BulkImportResult(headers: headerCells, rows: rows, warnings: warnings);
  }

  /// Picks the right parser based on file extension.
  static BulkImportResult parse(Uint8List bytes, String filename) {
    final ext = filename.toLowerCase().split('.').last;
    if (ext == 'xlsx' || ext == 'xls') return parseExcel(bytes);
    if (ext == 'pdf') return parsePdf(bytes);
    return const BulkImportResult(
      headers: [],
      rows: [],
      warnings: ['Unsupported file type — please upload a .xlsx or .pdf file.'],
    );
  }
}