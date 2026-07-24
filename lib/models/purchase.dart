// lib/models/purchase.dart
//
// Extended to support a full itemized purchase bill (line items, GST,
// shipping, round-off, payment type, terms & conditions, bill no. /
// bill date / state of supply) matching the Vyapar-style "Add Purchase"
// screen — while staying 100% backward compatible with every existing
// caller that only knows about the old single-item fields
// (productName / vendorName / quantity / cost / invoiceNumber).
//
// The legacy fields are kept as the "display/report" fields and are
// auto-derived from the line items when line items are present, so
// PurchaseService, PurchaseListScreen, PurchaseReportScreen, etc. all
// keep working unmodified.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'invoice_line_item.dart';
import 'customer_details.dart';

class Purchase {
  final String? id;          // Firestore document ID (String, not int)

  // ── Legacy single-item fields — kept for old purchases / simple mode,
  //    and as the derived "summary" fields once line items are used ──────
  final String productName;
  final String vendorName;
  final int quantity;
  final double cost;
  final String invoiceNumber; // also used as "Bill Number"
  final String branch;
  final String purchaseDate;  // also used as "Bill Date"
  final String? addedBy;
  final DateTime? createdAt;

  // ── New: itemized bill (Vyapar-style) ──────────────────────────────────
  final List<InvoiceLineItem> lineItems;
  final CustomerDetails? party;      // "Search by Name/Phone"
  final String? partyPhone;
  final String stateOfSupply;
  final String paymentType;          // 'Cash' | 'Bank Transfer' | 'UPI' | 'Cheque' | 'Card' | 'Credit'
  final double shipping;
  final bool roundOffEnabled;
  final String termsTitle;           // e.g. 'Purchase Bill'
  final String? termsNotes;          // e.g. 'Thanks for doing business with us!'
  final String? description;
  final String? imageUrl;

  static const List<String> paymentTypes = [
    'Cash', 'Bank Transfer', 'UPI', 'Cheque', 'Card', 'Credit',
  ];
  static const List<String> termsTitles = ['Purchase Bill', 'Purchase Order', 'Purchase Return'];

  Purchase({
    this.id,
    this.productName = '',
    this.vendorName = '',
    this.quantity = 0,
    this.cost = 0.0,
    this.invoiceNumber = '',
    required this.branch,
    required this.purchaseDate,
    this.addedBy,
    this.createdAt,
    this.lineItems = const [],
    this.party,
    this.partyPhone,
    this.stateOfSupply = 'Tamil Nadu',
    this.paymentType = 'Cash',
    this.shipping = 0.0,
    this.roundOffEnabled = true,
    this.termsTitle = 'Purchase Bill',
    this.termsNotes,
    this.description,
    this.imageUrl,
  });

  // ── Derived: line-item totals (itemized bill) ─────────────────────────
  bool get usesLineItems => lineItems.isNotEmpty;

  double get subtotal => usesLineItems
      ? lineItems.fold(0.0, (sum, li) => sum + li.taxableAmount)
      : cost * quantity;

  double get totalTax => lineItems.fold(0.0, (sum, li) => sum + li.taxAmount);
  double get totalDiscount => lineItems.fold(0.0, (sum, li) => sum + li.discountAmount);

  double get _preRoundTotal => subtotal + totalTax + shipping;
  double get roundOffAmount =>
      roundOffEnabled ? (_preRoundTotal.roundToDouble() - _preRoundTotal) : 0.0;
  double get grandTotal => _preRoundTotal + roundOffAmount;

  // Effective display fields used by existing UI unchanged
  double get displayAmount => usesLineItems ? grandTotal : (cost * quantity);
  int get displayQuantity =>
      usesLineItems ? lineItems.fold(0, (sum, li) => sum + li.quantity) : quantity;
  String get displayProductName => usesLineItems
      ? (lineItems.length == 1 ? lineItems.first.description : '${lineItems.length} items')
      : productName;
  String get displayVendorName => party?.name.isNotEmpty == true ? party!.name : vendorName;

  // ── Firestore ──────────────────────────────────────────────────────────
  factory Purchase.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Purchase(
      id:            doc.id,
      productName:   d['product_name']?.toString()   ?? '',
      vendorName:    d['vendor_name']?.toString()    ?? '',
      quantity:      (d['quantity']  as num?)?.toInt()    ?? 0,
      cost:          (d['cost']      as num?)?.toDouble() ?? 0.0,
      invoiceNumber: d['invoice_number']?.toString() ?? '',
      branch:        d['branch']?.toString()         ?? '',
      purchaseDate:  d['purchase_date']?.toString()  ?? '',
      addedBy:       d['added_by']?.toString(),
      createdAt: d['created_at'] != null
          ? (d['created_at'] as Timestamp).toDate()
          : null,
      lineItems: (d['line_items'] as List<dynamic>?)
          ?.map((e) => InvoiceLineItem.fromMap(Map<String, dynamic>.from(e)))
          .toList() ??
          [],
      party: d['party'] != null
          ? CustomerDetails.fromMap(Map<String, dynamic>.from(d['party']))
          : null,
      partyPhone: d['party_phone']?.toString(),
      stateOfSupply: d['state_of_supply']?.toString() ?? 'Tamil Nadu',
      paymentType: d['payment_type']?.toString() ?? 'Cash',
      shipping: (d['shipping'] as num?)?.toDouble() ?? 0.0,
      roundOffEnabled: d['round_off_enabled'] ?? true,
      termsTitle: d['terms_title']?.toString() ?? 'Purchase Bill',
      termsNotes: d['terms_notes']?.toString(),
      description: d['description']?.toString(),
      imageUrl: d['image_url']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'product_name':   productName,
    'vendor_name':    vendorName,
    'quantity':       quantity,
    'cost':           cost,
    'invoice_number': invoiceNumber,
    'branch':         branch,
    'purchase_date':  purchaseDate,
    'added_by':       addedBy,
    'created_at': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
    'line_items': lineItems.map((e) => e.toMap()).toList(),
    'party': party?.toMap(),
    'party_phone': partyPhone,
    'state_of_supply': stateOfSupply,
    'payment_type': paymentType,
    'shipping': shipping,
    'round_off_enabled': roundOffEnabled,
    'terms_title': termsTitle,
    'terms_notes': termsNotes,
    'description': description,
    'image_url': imageUrl,
  };

  // ── Legacy JSON (keep for compatibility) ───────────────────────────────────
  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
    id:            json['id']?.toString(),
    productName:   json['product_name']?.toString()   ?? '',
    vendorName:    json['vendor_name']?.toString()    ?? '',
    quantity:      (json['quantity']  as num?)?.toInt()    ?? 0,
    cost:          (json['cost']      as num?)?.toDouble() ?? 0.0,
    invoiceNumber: json['invoice_number']?.toString() ?? '',
    branch:        json['branch']?.toString()         ?? '',
    purchaseDate:  json['purchase_date']?.toString()  ?? '',
    addedBy:       json['added_by']?.toString(),
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'])
        : null,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'product_name':   productName,
    'vendor_name':    vendorName,
    'quantity':       quantity,
    'cost':           cost,
    'invoice_number': invoiceNumber,
    'branch':         branch,
    'purchase_date':  purchaseDate,
    'added_by':       addedBy,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };

  Purchase copyWith({
    String? id,
    String? productName,
    String? vendorName,
    int?    quantity,
    double? cost,
    String? invoiceNumber,
    String? branch,
    String? purchaseDate,
    String? addedBy,
    DateTime? createdAt,
    List<InvoiceLineItem>? lineItems,
    CustomerDetails? party,
    String? partyPhone,
    String? stateOfSupply,
    String? paymentType,
    double? shipping,
    bool? roundOffEnabled,
    String? termsTitle,
    String? termsNotes,
    String? description,
    String? imageUrl,
  }) =>
      Purchase(
        id:            id            ?? this.id,
        productName:   productName   ?? this.productName,
        vendorName:    vendorName    ?? this.vendorName,
        quantity:      quantity      ?? this.quantity,
        cost:          cost          ?? this.cost,
        invoiceNumber: invoiceNumber ?? this.invoiceNumber,
        branch:        branch        ?? this.branch,
        purchaseDate:  purchaseDate  ?? this.purchaseDate,
        addedBy:       addedBy       ?? this.addedBy,
        createdAt:     createdAt     ?? this.createdAt,
        lineItems:     lineItems     ?? this.lineItems,
        party:         party         ?? this.party,
        partyPhone:    partyPhone    ?? this.partyPhone,
        stateOfSupply: stateOfSupply ?? this.stateOfSupply,
        paymentType:   paymentType   ?? this.paymentType,
        shipping:      shipping      ?? this.shipping,
        roundOffEnabled: roundOffEnabled ?? this.roundOffEnabled,
        termsTitle:    termsTitle    ?? this.termsTitle,
        termsNotes:    termsNotes    ?? this.termsNotes,
        description:   description   ?? this.description,
        imageUrl:       imageUrl      ?? this.imageUrl,
      );
}