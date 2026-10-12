// lib/models/new_product.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// New Product model — backed by the `new_products` collection in
/// Cloud Firestore. Represents an item a branch wants to bring in /
/// evaluate before it becomes part of the main Inventory / Fixed Assets
/// catalog: who requested it, who it was bought from, and who approved
/// it, alongside the basic product details.
///
/// Follows the exact same shape as [FixedAsset] / [Consumable] models in
/// this project: a plain immutable class with `fromFirestore` / `toMap` /
/// `copyWith`, Firestore `Timestamp` <-> `DateTime` conversion, and no
/// external state — all reads/writes go through [NewProductService].
class NewProduct {
  // ── Identity ──────────────────────────────────────────────────────────
  final String productId; // == Firestore doc id

  // ── Basic Information ─────────────────────────────────────────────────
  final String productName;
  final String productCode;
  final String category;
  final String brand;
  final String modelNumber;
  final String description;

  // ── Purchase Information ──────────────────────────────────────────────
  final String vendorName;
  final String vendorContact;
  final String vendorEmail;
  final DateTime purchaseDate;
  final double purchaseCost; // == "Purchase Price" on the Stock Summary Report
  final int quantity; // == "Stock Quantity" on the Stock Summary Report
  final String unit;

  // ── Stock / Pricing Information ───────────────────────────────────────
  // These four mirror the Stock Summary Report columns 1:1 so a report
  // can be bulk-imported straight into this module without any manual
  // remapping (see BulkImportService._aliases).
  final double salePrice; // "Sale Price"
  // GST option — 0 means "Without GST"; any value > 0 means "With GST" at
  // that percentage (5 / 12 / 18 / 28 from the preset list, or any custom
  // % typed manually). Always read/written through [NewProductGst] so the
  // Add/Edit screen, bulk import, PDF and Excel exports can never disagree.
  final double gstRate;
  final int availableQuantityForSale; // "Available Quantity for Sale"
  final int reservedQuantity; // "Reserved Quantity"
  final double stockValue; // "Stock Value"

  // ── Inventory Information ─────────────────────────────────────────────
  final String branch;
  final String storageLocation;
  final int minimumStockLevel;

  // ── Status ────────────────────────────────────────────────────────────
  final String status;

  // ── Grouping ──────────────────────────────────────────────────────────
  // true  -> "List of Products in Website"
  // false -> "Product Availability Branches"
  final bool listedOnWebsite;

  // ── Requested By ──────────────────────────────────────────────────────
  final String addedBy;
  final String employeeId;
  final String department;

  // ── Approval Information ──────────────────────────────────────────────
  final String approvedBy;
  final DateTime? approvalDate;
  final String remarks;

  // ── Attachments (Base64-encoded, stored inline in the document — same
  //    pattern as BillModel / InvoiceModel: no Firebase Storage bucket
  //    required) ───────────────────────────────────────────────────────
  final String productImage; // base64 string, '' if none
  final String invoiceFile; // base64 string, '' if none

  // ── Notes ─────────────────────────────────────────────────────────────
  final String notes;

  // ── Timestamps ────────────────────────────────────────────────────────
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Convenience alias so `product.id` reads naturally in list/detail
  /// widgets, matching the other models in this project (`FixedAsset.id`,
  /// `Consumable.id`, …).
  String get id => productId;

  // ── GST helpers (derived — nothing extra stored besides gstRate) ──────
  bool get hasGst => gstRate > 0;

  /// "Without GST" or "With GST 18%" — the exact text shown in the Add/Edit
  /// dropdown, the PDF / Excel reports and written back by bulk import.
  String get gstLabel => NewProductGst.label(gstRate);

  /// GST amount charged on one unit at [salePrice] (0 when Without GST).
  double get gstAmount => NewProductGst.gstAmount(salePrice, gstRate);

  /// Sale price per unit including GST (== [salePrice] when Without GST).
  double get salePriceWithGst => NewProductGst.priceWithGst(salePrice, gstRate);

  const NewProduct({
    required this.productId,
    required this.productName,
    this.productCode = '',
    this.category = 'General',
    this.brand = '',
    this.modelNumber = '',
    this.description = '',
    required this.vendorName,
    this.vendorContact = '',
    this.vendorEmail = '',
    required this.purchaseDate,
    this.purchaseCost = 0,
    this.quantity = 1,
    this.unit = 'Pcs',
    this.salePrice = 0,
    this.gstRate = 0,
    this.availableQuantityForSale = 0,
    this.reservedQuantity = 0,
    this.stockValue = 0,
    required this.branch,
    this.storageLocation = '',
    this.minimumStockLevel = 0,
    this.status = 'In Stock',
    this.listedOnWebsite = false,
    required this.addedBy,
    this.employeeId = '',
    this.department = '',
    this.approvedBy = '',
    this.approvalDate,
    this.remarks = '',
    this.productImage = '',
    this.invoiceFile = '',
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  // ── Firestore -> Model ───────────────────────────────────────────────
  factory NewProduct.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    return NewProduct.fromMap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  factory NewProduct.fromMap(String id, Map<String, dynamic> data) {
    DateTime? _ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    int _asInt(dynamic v, int fallback) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? fallback;
    }

    double _asDouble(dynamic v, double fallback) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? fallback;
    }

    String _asString(dynamic v, [String fallback = '']) =>
        v == null ? fallback : v.toString();

    return NewProduct(
      productId: id,
      productName: _asString(data['productName']),
      productCode: _asString(data['productCode']),
      category: _asString(data['category'], 'General'),
      brand: _asString(data['brand']),
      modelNumber: _asString(data['modelNumber']),
      description: _asString(data['description']),
      vendorName: _asString(data['vendorName']),
      vendorContact: _asString(data['vendorContact']),
      vendorEmail: _asString(data['vendorEmail']),
      purchaseDate: _ts(data['purchaseDate']) ?? DateTime.now(),
      purchaseCost: _asDouble(data['purchaseCost'], 0),
      quantity: _asInt(data['quantity'], 0),
      unit: _asString(data['unit'], 'Pcs'),
      salePrice: _asDouble(data['salePrice'], 0),
      // Older documents have no GST fields at all -> "Without GST".
      gstRate: NewProductGst.resolve(
        type: data['gstType'],
        percent: data['gstRate'],
      ),
      availableQuantityForSale: _asInt(data['availableQuantityForSale'], 0),
      reservedQuantity: _asInt(data['reservedQuantity'], 0),
      stockValue: _asDouble(data['stockValue'], 0),
      branch: _asString(data['branch'], 'CDA Admin'),
      storageLocation: _asString(data['storageLocation']),
      minimumStockLevel: _asInt(data['minimumStockLevel'], 0),
      status: _asString(data['status'], 'In Stock'),
      listedOnWebsite: data['listedOnWebsite'] == true ||
          _asString(data['listedOnWebsite']).toLowerCase() == 'true',
      addedBy: _asString(data['addedBy']),
      employeeId: _asString(data['employeeId']),
      department: _asString(data['department']),
      approvedBy: _asString(data['approvedBy']),
      approvalDate: _ts(data['approvalDate']),
      remarks: _asString(data['remarks']),
      productImage: _asString(data['productImage']),
      invoiceFile: _asString(data['invoiceFile']),
      notes: _asString(data['notes']),
      createdAt: _ts(data['createdAt']),
      updatedAt: _ts(data['updatedAt']),
    );
  }

  // ── Model -> Firestore ───────────────────────────────────────────────
  /// Deliberately excludes `productId` / `createdAt` / `updatedAt` — the
  /// id is the document id itself, and both timestamps are stamped by
  /// [NewProductService] using `FieldValue.serverTimestamp()`.
  Map<String, dynamic> toMap() => {
    'productName': productName,
    'productCode': productCode,
    'category': category,
    'brand': brand,
    'modelNumber': modelNumber,
    'description': description,
    'vendorName': vendorName,
    'vendorContact': vendorContact,
    'vendorEmail': vendorEmail,
    'purchaseDate': Timestamp.fromDate(purchaseDate),
    'purchaseCost': purchaseCost,
    'quantity': quantity,
    'unit': unit,
    'salePrice': salePrice,
    'gstRate': gstRate,
    // Human-readable twin of gstRate ("With GST" / "Without GST") so the
    // Firestore console, exports and bulk files are easy to read.
    'gstType': hasGst ? 'With GST' : 'Without GST',
    'availableQuantityForSale': availableQuantityForSale,
    'reservedQuantity': reservedQuantity,
    'stockValue': stockValue,
    'branch': branch,
    'storageLocation': storageLocation,
    'minimumStockLevel': minimumStockLevel,
    'status': status,
    'listedOnWebsite': listedOnWebsite,
    'addedBy': addedBy,
    'employeeId': employeeId,
    'department': department,
    'approvedBy': approvedBy,
    'approvalDate':
    approvalDate == null ? null : Timestamp.fromDate(approvalDate!),
    'remarks': remarks,
    'productImage': productImage,
    'invoiceFile': invoiceFile,
    'notes': notes,
  };

  /// Human-readable field map used for [ActivityLogService.logEdit] diffs
  /// and for the Detail screen's grouped sections — keeps labels
  /// consistent wherever the record is displayed or diffed.
  Map<String, dynamic> toActivityLogMap() => {
    'Product Name': productName,
    'Product Code': productCode,
    'Category': category,
    'Brand': brand,
    'Model Number': modelNumber,
    'Vendor Name': vendorName,
    'Vendor Contact': vendorContact,
    'Vendor Email': vendorEmail,
    'Purchase Date': purchaseDate,
    'Purchase Cost': purchaseCost,
    'Quantity': quantity,
    'Unit': unit,
    'Sale Price': salePrice,
    'GST': gstLabel,
    'Available Quantity for Sale': availableQuantityForSale,
    'Reserved Quantity': reservedQuantity,
    'Stock Value': stockValue,
    'Branch': branch,
    'Storage Location': storageLocation,
    'Minimum Stock Level': minimumStockLevel,
    'Status': status,
    'List of Products in Website': listedOnWebsite ? 'Yes' : 'No',
    'Added By': addedBy,
    'Employee ID': employeeId,
    'Department': department,
    'Approved By': approvedBy,
    if (approvalDate != null) 'Approval Date': approvalDate,
    'Remarks': remarks,
    'Notes': notes,
  };

  NewProduct copyWith({
    String? productId,
    String? productName,
    String? productCode,
    String? category,
    String? brand,
    String? modelNumber,
    String? description,
    String? vendorName,
    String? vendorContact,
    String? vendorEmail,
    DateTime? purchaseDate,
    double? purchaseCost,
    int? quantity,
    String? unit,
    double? salePrice,
    double? gstRate,
    int? availableQuantityForSale,
    int? reservedQuantity,
    double? stockValue,
    String? branch,
    String? storageLocation,
    int? minimumStockLevel,
    String? status,
    bool? listedOnWebsite,
    String? addedBy,
    String? employeeId,
    String? department,
    String? approvedBy,
    DateTime? approvalDate,
    bool clearApprovalDate = false,
    String? remarks,
    String? productImage,
    String? invoiceFile,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NewProduct(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      modelNumber: modelNumber ?? this.modelNumber,
      description: description ?? this.description,
      vendorName: vendorName ?? this.vendorName,
      vendorContact: vendorContact ?? this.vendorContact,
      vendorEmail: vendorEmail ?? this.vendorEmail,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchaseCost: purchaseCost ?? this.purchaseCost,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      salePrice: salePrice ?? this.salePrice,
      gstRate: gstRate ?? this.gstRate,
      availableQuantityForSale:
      availableQuantityForSale ?? this.availableQuantityForSale,
      reservedQuantity: reservedQuantity ?? this.reservedQuantity,
      stockValue: stockValue ?? this.stockValue,
      branch: branch ?? this.branch,
      storageLocation: storageLocation ?? this.storageLocation,
      minimumStockLevel: minimumStockLevel ?? this.minimumStockLevel,
      status: status ?? this.status,
      listedOnWebsite: listedOnWebsite ?? this.listedOnWebsite,
      addedBy: addedBy ?? this.addedBy,
      employeeId: employeeId ?? this.employeeId,
      department: department ?? this.department,
      approvedBy: approvedBy ?? this.approvedBy,
      approvalDate:
      clearApprovalDate ? null : (approvalDate ?? this.approvalDate),
      remarks: remarks ?? this.remarks,
      productImage: productImage ?? this.productImage,
      invoiceFile: invoiceFile ?? this.invoiceFile,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Single source of truth for the GST option on a New Product.
///
///   • Add/Edit screen  -> dropdown of [presetRates] + a "Custom %" entry
///   • Bulk import      -> [resolve] / [parse] turn any cell text into a rate
///   • PDF / Excel      -> [label] prints "Without GST" / "With GST 18%"
///
/// A rate of 0 means "Without GST". Any rate > 0 means "With GST".
class NewProductGst {
  NewProductGst._();

  static const String withoutLabel = 'Without GST';
  static const String customLabel = 'Custom GST %';

  /// Default presets — same slabs as the Add Sale / Invoice tax dropdown.
  static const List<double> presetRates = [5, 12, 18, 28];

  /// Rate used when a bulk file says "With GST" but gives no percentage.
  static const double defaultWithGstRate = 18;

  static bool isPreset(double rate) => rate == 0 || presetRates.contains(rate);

  static String _fmt(double rate) => rate % 1 == 0
      ? rate.toStringAsFixed(0)
      : rate.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

  /// "Without GST" / "With GST 18%" / "With GST 7.5%".
  static String label(double rate) =>
      rate <= 0 ? withoutLabel : 'With GST ${_fmt(rate)}%';

  /// Short form for tight table cells: "No GST" / "GST 18%".
  static String shortLabel(double rate) =>
      rate <= 0 ? 'No GST' : 'GST ${_fmt(rate)}%';

  /// Plain text for an editable % field ("" when Without GST).
  static String percentText(double rate) => rate <= 0 ? '' : _fmt(rate);

  static double gstAmount(double price, double rate) =>
      rate <= 0 ? 0 : price * rate / 100;

  static double priceWithGst(double price, double rate) =>
      price + gstAmount(price, rate);

  /// Options shown in the dropdown, in order: Without GST, presets, Custom.
  static List<String> get dropdownLabels => [
    withoutLabel,
    ...presetRates.map(label),
    customLabel,
  ];

  /// Dropdown label that represents [rate].
  static String dropdownLabelFor(double rate) =>
      isPreset(rate) ? label(rate) : customLabel;

  /// Reverse of [dropdownLabelFor] for presets; null for "Custom GST %".
  static double? presetFromDropdownLabel(String text) {
    if (text == withoutLabel) return 0;
    for (final r in presetRates) {
      if (label(r) == text) return r;
    }
    return null;
  }

  /// Reads a single cell / value and returns a GST rate, or null when the
  /// text isn't recognisable as a GST option at all. Accepts:
  ///   Without GST / Without Tax / No GST / No Tax / Nil / Exempt / - / 0 / 0%  -> 0
  ///   18 / 18% / GST 18% / With GST 18% / IGST 18                              -> 18
  ///   0.18 (an Excel "%"-formatted cell)                                       -> 18
  ///   With GST / Yes / Y / Included (no number)                                -> 18 (default)
  static double? parse(dynamic raw) {
    if (raw == null) return null;
    if (raw is bool) return raw ? defaultWithGstRate : 0;
    if (raw is num) return _fromNumber(raw.toDouble());

    final text = raw.toString().trim().toLowerCase();
    if (text.isEmpty) return null;

    const without = {
      'without gst', 'without tax', 'no gst', 'no tax', 'non gst', 'non-gst',
      'nil', 'nil rated', 'exempt', 'exempted', 'none', 'no', 'n', 'false',
      '-', '--', 'na', 'n/a', 'without', 'wo gst', 'w/o gst', 'excl gst',
      'excluding gst', 'ex gst',
    };
    if (without.contains(text)) return 0;

    final number = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
    if (number != null) {
      final v = double.tryParse(number.group(1)!);
      if (v != null) return _fromNumber(v, hasPercentSign: text.contains('%'));
    }

    const withGst = {
      'with gst', 'with tax', 'gst', 'tax', 'yes', 'y', 'true', 'included',
      'incl gst', 'including gst', 'inc gst', 'with',
    };
    if (withGst.contains(text)) return defaultWithGstRate;

    return null;
  }

  static double _fromNumber(double v, {bool hasPercentSign = false}) {
    if (v <= 0) return 0;
    // Excel stores a %-formatted 18% cell as 0.18.
    if (v < 1 && !hasPercentSign) {
      return double.parse((v * 100).toStringAsFixed(2));
    }
    if (v > 100) return 0; // not a plausible GST rate
    return v;
  }

  /// Combines the two bulk-file columns that may exist:
  ///   [type]    -> "With GST" / "Without GST" / "GST 18%" / "18%" ...
  ///   [percent] -> 18 / "18%" / 0.18 ...
  /// "Without" always wins; otherwise a percentage (from either column)
  /// wins; a bare "With GST" falls back to [defaultWithGstRate].
  static double resolve({dynamic type, dynamic percent}) {
    final fromType = parse(type);
    final fromPercent = parse(percent);

    if (fromType != null && fromType <= 0) return 0;
    if (fromPercent != null && fromPercent > 0) return fromPercent;
    if (fromType != null && fromType > 0) return fromType;
    return 0;
  }
}

/// Dropdown / chip option lists shared by the list, add/edit and detail
/// screens so they never drift out of sync with each other.
class NewProductOptions {
  NewProductOptions._();

  static const List<String> branches = ['CDA Admin', 'CDA Ops'];

  static const List<String> statuses = [
    'In Stock',
    'Low Stock',
    'Out of Stock',
  ];

  /// Same category list as the shop. 'Other' is the catch-all and must
  /// stay last. Icons / colours / legacy-value mapping live in
  /// lib/constants/new_product_categories.dart.
  static const List<String> categories = [
    'Accessories',
    'Action Camera',
    'Battery',
    'Drone Accessories',
    'Electronics',
    'Frames',
    'Goggles',
    'Motors',
    'Propeller',
    'R.T.F Drones',
    'Remote Controller',
    'Video Transmitter & Cameras & Antennas',
    'Other',
  ];

  static const List<String> units = [
    'Pcs',
    'Set',
    'Box',
    'Kg',
    'Gram',
    'Meter',
    'Litre',
    'Pair',
  ];
}
