// lib/models/estimate.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'invoice_line_item.dart';
import 'customer_details.dart';

class Estimate {
  final String? id;
  final String referenceNo;

  final String partyName;
  final String? partyPhone;
  final CustomerDetails? customer;

  final List<InvoiceLineItem> lineItems;

  final String estimateDate; // dd-MM-yyyy
  final String? validTill;

  final bool gstEnabled;
  final double cgstPercent;
  final double sgstPercent;
  final double igstPercent;
  final bool isInterState;

  final double shipping;
  final bool roundOffEnabled;

  final String status; // Open | Converted | Expired
  final String? convertedInvoiceId;
  final String? convertedInvoiceNo;

  final String? notes;
  final String? termsNotes;

  final String? addedBy;
  final DateTime? addedAt;
  final String? branch; // "firm"

  static const List<String> statusOptions = ['Open', 'Converted', 'Expired'];

  Estimate({
    this.id,
    required this.referenceNo,
    this.partyName = '',
    this.partyPhone,
    this.customer,
    this.lineItems = const [],
    required this.estimateDate,
    this.validTill,
    this.gstEnabled = false,
    this.cgstPercent = 9.0,
    this.sgstPercent = 9.0,
    this.igstPercent = 18.0,
    this.isInterState = false,
    this.shipping = 0.0,
    this.roundOffEnabled = false,
    this.status = 'Open',
    this.convertedInvoiceId,
    this.convertedInvoiceNo,
    this.notes,
    this.termsNotes,
    this.addedBy,
    this.addedAt,
    this.branch,
  });

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

  // Estimate has no "balance" concept the way invoices do — the full
  // amount is "outstanding" until converted, mirroring Vyapar's Estimate
  // list where Balance == Amount for Open estimates and 0 for Converted.
  double get balanceDue => isConverted ? 0.0 : grandTotal;

  DateTime? get estimateDateTime => _parseDdMmYyyy(estimateDate);
  DateTime? get validTillDate => _parseDdMmYyyy(validTill);

  static DateTime? _parseDdMmYyyy(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]), m = int.tryParse(parts[1]), y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  factory Estimate.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Estimate(
      id: doc.id,
      referenceNo: data['reference_no']?.toString() ?? '',
      partyName: data['party_name']?.toString() ?? '',
      partyPhone: data['party_phone']?.toString(),
      customer: data['customer'] != null
          ? CustomerDetails.fromMap(Map<String, dynamic>.from(data['customer']))
          : null,
      lineItems: (data['line_items'] as List<dynamic>?)
          ?.map((e) => InvoiceLineItem.fromMap(Map<String, dynamic>.from(e)))
          .toList() ??
          [],
      estimateDate: data['estimate_date']?.toString() ?? '',
      validTill: data['valid_till']?.toString(),
      gstEnabled: data['gst_enabled'] ?? false,
      cgstPercent: (data['cgst_percent'] as num?)?.toDouble() ?? 9.0,
      sgstPercent: (data['sgst_percent'] as num?)?.toDouble() ?? 9.0,
      igstPercent: (data['igst_percent'] as num?)?.toDouble() ?? 18.0,
      isInterState: data['is_inter_state'] ?? false,
      shipping: (data['shipping'] as num?)?.toDouble() ?? 0.0,
      roundOffEnabled: data['round_off_enabled'] ?? false,
      status: data['status']?.toString() ?? 'Open',
      convertedInvoiceId: data['converted_invoice_id']?.toString(),
      convertedInvoiceNo: data['converted_invoice_no']?.toString(),
      notes: data['notes']?.toString(),
      termsNotes: data['terms_notes']?.toString(),
      addedBy: data['added_by']?.toString(),
      addedAt: (data['added_at'] as Timestamp?)?.toDate(),
      branch: data['branch']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reference_no': referenceNo,
      'party_name': partyName,
      'party_phone': partyPhone,
      'customer': customer?.toMap(),
      'line_items': lineItems.map((e) => e.toMap()).toList(),
      'estimate_date': estimateDate,
      'valid_till': validTill,
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
      'notes': notes,
      'terms_notes': termsNotes,
      'added_by': addedBy,
      'added_at': addedAt != null ? Timestamp.fromDate(addedAt!) : null,
      'branch': branch,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  Estimate copyWith({
    String? id,
    bool clearId = false,
    String? referenceNo,
    String? partyName,
    String? partyPhone,
    CustomerDetails? customer,
    List<InvoiceLineItem>? lineItems,
    String? estimateDate,
    String? validTill,
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
    String? notes,
    String? termsNotes,
    String? addedBy,
    DateTime? addedAt,
    String? branch,
  }) {
    return Estimate(
      id: clearId ? null : (id ?? this.id),
      referenceNo: referenceNo ?? this.referenceNo,
      partyName: partyName ?? this.partyName,
      partyPhone: partyPhone ?? this.partyPhone,
      customer: customer ?? this.customer,
      lineItems: lineItems ?? this.lineItems,
      estimateDate: estimateDate ?? this.estimateDate,
      validTill: validTill ?? this.validTill,
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
      notes: notes ?? this.notes,
      termsNotes: termsNotes ?? this.termsNotes,
      addedBy: addedBy ?? this.addedBy,
      addedAt: addedAt ?? this.addedAt,
      branch: branch ?? this.branch,
    );
  }
}