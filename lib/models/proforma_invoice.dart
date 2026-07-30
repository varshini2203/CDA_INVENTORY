// lib/models/proforma_invoice.dart
//
// Proforma Invoice — a preliminary bill sent before the actual sale
// (no GST liability, not a legal tax invoice). Structurally it mirrors
// Estimate/Invoice: line items drive the totals, it carries its own
// customer + GST + shipping + round-off block, and it can be converted
// into a real Sale Invoice once the customer confirms.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'invoice_line_item.dart';
import 'customer_details.dart';

class ProformaInvoice {
  final String? id;
  final String proformaNo;

  final String partyName;
  final CustomerDetails? customer;

  final List<InvoiceLineItem> lineItems;

  final String proformaDate; // dd-MM-yyyy
  final String? validTill;   // dd-MM-yyyy
  final String? expectedDelivery; // dd-MM-yyyy — Expected Delivery Date
  final String? customerRefNo;    // Customer PO / Reference Number (optional)

  final bool gstEnabled;
  final double cgstPercent;
  final double sgstPercent;
  final double igstPercent;
  final bool isInterState;

  final double shipping;
  final bool roundOffEnabled;

  final String status; // Open | Converted | Expired — internal lifecycle flag (unchanged, drives conversion logic)
  final String? convertedInvoiceId;
  final String? convertedInvoiceNo;

  // Customer-facing workflow status shown on the Add/Edit Proforma screen.
  final String proformaStatus; // Draft | Sent | Accepted | Rejected | Expired | Converted to Invoice

  final String? notes;
  final String? termsNotes;

  final String? addedBy; // "Prepared By" — auto-filled with the logged-in user's name
  final DateTime? addedAt;
  final String? branch; // "firm"

  static const List<String> statusOptions = ['Open', 'Converted', 'Expired'];

  static const List<String> proformaStatusOptions = [
    'Draft', 'Sent', 'Accepted', 'Rejected', 'Expired', 'Converted to Invoice',
  ];

  ProformaInvoice({
    this.id,
    required this.proformaNo,
    this.partyName = '',
    this.customer,
    this.lineItems = const [],
    required this.proformaDate,
    this.validTill,
    this.expectedDelivery,
    this.customerRefNo,
    this.gstEnabled = false,
    this.cgstPercent = 9.0,
    this.sgstPercent = 9.0,
    this.igstPercent = 18.0,
    this.isInterState = false,
    this.shipping = 0.0,
    this.roundOffEnabled = true,
    this.status = 'Open',
    this.convertedInvoiceId,
    this.convertedInvoiceNo,
    this.proformaStatus = 'Draft',
    this.notes,
    this.termsNotes,
    this.addedBy,
    this.addedAt,
    this.branch,
  });

  // ── Derived totals (identical engine to Estimate/Invoice) ────────────
  bool get usesLineItems => lineItems.isNotEmpty;

  double get subtotal =>
      lineItems.fold(0.0, (sum, li) => sum + li.taxableAmount);

  double get cgstAmount => gstEnabled && !isInterState ? subtotal * (cgstPercent / 100) : 0.0;
  double get sgstAmount => gstEnabled && !isInterState ? subtotal * (sgstPercent / 100) : 0.0;
  double get igstAmount => gstEnabled && isInterState ? subtotal * (igstPercent / 100) : 0.0;

  double get lineTaxTotal => lineItems.fold(0.0, (sum, li) => sum + li.taxAmount);
  double get totalTax => usesLineItems ? lineTaxTotal : (cgstAmount + sgstAmount + igstAmount);

  double get _preRoundTotal => subtotal + totalTax + shipping;
  double get roundOffAmount =>
      roundOffEnabled ? (_preRoundTotal.roundToDouble() - _preRoundTotal) : 0.0;
  double get grandTotal => _preRoundTotal + roundOffAmount;

  double get displayAmount => grandTotal;
  int get totalQty => lineItems.fold(0, (sum, li) => sum + li.quantity);

  bool get isConverted => status == 'Converted';
  bool get isExpired {
    if (isConverted) return false;
    final v = validTillDate;
    if (v == null) return false;
    return v.isBefore(DateTime.now());
  }

  String get effectiveStatus {
    if (isConverted) return 'Converted';
    if (isExpired) return 'Expired';
    return 'Open';
  }

  // A proforma has no partial-payment concept — it's either fully open
  // (the whole amount is "pending confirmation") or converted (0 balance),
  // mirroring how Vyapar treats Proforma Invoice balances.
  double get balanceDue => isConverted ? 0.0 : grandTotal;

  DateTime? get proformaDateTime => _parseDdMmYyyy(proformaDate);
  DateTime? get validTillDate => _parseDdMmYyyy(validTill);
  DateTime? get expectedDeliveryDate => _parseDdMmYyyy(expectedDelivery);

  static DateTime? _parseDdMmYyyy(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]), m = int.tryParse(parts[1]), y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  factory ProformaInvoice.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ProformaInvoice(
      id: doc.id,
      proformaNo: data['proforma_no']?.toString() ?? '',
      partyName: data['party_name']?.toString() ?? '',
      customer: data['customer'] != null
          ? CustomerDetails.fromMap(Map<String, dynamic>.from(data['customer']))
          : null,
      lineItems: (data['line_items'] as List<dynamic>?)
          ?.map((e) => InvoiceLineItem.fromMap(Map<String, dynamic>.from(e)))
          .toList() ??
          [],
      proformaDate: data['proforma_date']?.toString() ?? '',
      validTill: data['valid_till']?.toString(),
      expectedDelivery: data['expected_delivery']?.toString(),
      customerRefNo: data['customer_ref_no']?.toString(),
      gstEnabled: data['gst_enabled'] ?? false,
      cgstPercent: (data['cgst_percent'] as num?)?.toDouble() ?? 9.0,
      sgstPercent: (data['sgst_percent'] as num?)?.toDouble() ?? 9.0,
      igstPercent: (data['igst_percent'] as num?)?.toDouble() ?? 18.0,
      isInterState: data['is_inter_state'] ?? false,
      shipping: (data['shipping'] as num?)?.toDouble() ?? 0.0,
      roundOffEnabled: data['round_off_enabled'] ?? true,
      status: data['status']?.toString() ?? 'Open',
      convertedInvoiceId: data['converted_invoice_id']?.toString(),
      convertedInvoiceNo: data['converted_invoice_no']?.toString(),
      proformaStatus: data['proforma_status']?.toString() ?? 'Draft',
      notes: data['notes']?.toString(),
      termsNotes: data['terms_notes']?.toString(),
      addedBy: data['added_by']?.toString(),
      addedAt: (data['added_at'] as Timestamp?)?.toDate(),
      branch: data['branch']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'proforma_no': proformaNo,
      'party_name': partyName,
      'customer': customer?.toMap(),
      'line_items': lineItems.map((e) => e.toMap()).toList(),
      'proforma_date': proformaDate,
      'valid_till': validTill,
      'expected_delivery': expectedDelivery,
      'customer_ref_no': customerRefNo,
      'gst_enabled': gstEnabled,
      'cgst_percent': cgstPercent,
      'sgst_percent': sgstPercent,
      'igst_percent': igstPercent,
      'is_inter_state': isInterState,
      'shipping': shipping,
      'round_off_enabled': roundOffEnabled,
      'status': status,
      'converted_invoice_id': convertedInvoiceId,
      'converted_invoice_no': convertedInvoiceNo,
      'proforma_status': proformaStatus,
      'notes': notes,
      'terms_notes': termsNotes,
      'added_by': addedBy,
      'added_at': addedAt != null ? Timestamp.fromDate(addedAt!) : null,
      'branch': branch,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  ProformaInvoice copyWith({
    String? id,
    bool clearId = false,
    String? proformaNo,
    String? partyName,
    CustomerDetails? customer,
    List<InvoiceLineItem>? lineItems,
    String? proformaDate,
    String? validTill,
    String? expectedDelivery,
    String? customerRefNo,
    bool? gstEnabled,
    double? cgstPercent,
    double? sgstPercent,
    double? igstPercent,
    bool? isInterState,
    double? shipping,
    bool? roundOffEnabled,
    String? status,
    String? convertedInvoiceId,
    String? convertedInvoiceNo,
    String? proformaStatus,
    String? notes,
    String? termsNotes,
    String? addedBy,
    DateTime? addedAt,
    String? branch,
  }) {
    return ProformaInvoice(
      id: clearId ? null : (id ?? this.id),
      proformaNo: proformaNo ?? this.proformaNo,
      partyName: partyName ?? this.partyName,
      customer: customer ?? this.customer,
      lineItems: lineItems ?? this.lineItems,
      proformaDate: proformaDate ?? this.proformaDate,
      validTill: validTill ?? this.validTill,
      expectedDelivery: expectedDelivery ?? this.expectedDelivery,
      customerRefNo: customerRefNo ?? this.customerRefNo,
      gstEnabled: gstEnabled ?? this.gstEnabled,
      cgstPercent: cgstPercent ?? this.cgstPercent,
      sgstPercent: sgstPercent ?? this.sgstPercent,
      igstPercent: igstPercent ?? this.igstPercent,
      isInterState: isInterState ?? this.isInterState,
      shipping: shipping ?? this.shipping,
      roundOffEnabled: roundOffEnabled ?? this.roundOffEnabled,
      status: status ?? this.status,
      convertedInvoiceId: convertedInvoiceId ?? this.convertedInvoiceId,
      convertedInvoiceNo: convertedInvoiceNo ?? this.convertedInvoiceNo,
      proformaStatus: proformaStatus ?? this.proformaStatus,
      notes: notes ?? this.notes,
      termsNotes: termsNotes ?? this.termsNotes,
      addedBy: addedBy ?? this.addedBy,
      addedAt: addedAt ?? this.addedAt,
      branch: branch ?? this.branch,
    );
  }
}
