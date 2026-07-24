// lib/models/invoice.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'invoice_line_item.dart';
import 'customer_details.dart';
import 'payment_record.dart';
import 'recurring_config.dart';

class Invoice {
  final String? id;
  final String invoiceNo;

  // Legacy single-item fields — kept for old invoices / simple mode
  final String productName;
  final String vendorName;
  final int quantity;
  final double amount;

  final String purchaseDate;
  final String status;
  final String? dueDate;
  final String? notes;

  // ── New: line items (if non-empty, these drive totals instead of legacy fields) ──
  final List<InvoiceLineItem> lineItems;

  // ── New: customer / billing ──
  final CustomerDetails? customer;

  // ── New: GST ──
  final bool gstEnabled;
  final double cgstPercent;
  final double sgstPercent;
  final double igstPercent;
  final bool isInterState; // true → IGST only; false → CGST+SGST split

  // ── New: payments ──
  final List<PaymentRecord> payments;

  // ── New: recurring ──
  final RecurringConfig recurring;

  // ── New: audit / who-added info ──
  final String? addedBy;
  final DateTime? addedAt;

  // ── New: branch tagging (raw value: 'Branch 1' / 'Branch 2') ──
  final String? branch;

  // ── New: Sale-invoice style fields ──
  final String paymentMode;      // 'Credit' | 'Cash'
  final double shipping;
  final bool roundOffEnabled;
  final String termsTitle;       // e.g. 'Sale Invoice'
  final String? termsNotes;      // e.g. 'Thanks for doing business with us!'

  static const List<String> statusOptions = ['Pending', 'Paid'];
  static const List<String> paymentMethods = ['Cash', 'Bank Transfer', 'UPI', 'Cheque', 'Card'];
  static const List<String> recurringFrequencies = ['Weekly', 'Monthly', 'Quarterly', 'Yearly'];

  Invoice({
    this.id,
    required this.invoiceNo,
    this.productName = '',
    this.vendorName = '',
    this.quantity = 0,
    this.amount = 0.0,
    required this.purchaseDate,
    this.status = 'Pending',
    this.dueDate,
    this.notes,
    this.lineItems = const [],
    this.customer,
    this.gstEnabled = false,
    this.cgstPercent = 9.0,
    this.sgstPercent = 9.0,
    this.igstPercent = 18.0,
    this.isInterState = false,
    this.payments = const [],
    RecurringConfig? recurring,
    this.addedBy,
    this.addedAt,
    this.branch,
    this.paymentMode = 'Credit',
    this.shipping = 0.0,
    this.roundOffEnabled = false,
    this.termsTitle = 'Sale Invoice',
    this.termsNotes,
  }) : recurring = recurring ?? RecurringConfig();

  // ── Derived: line-item totals (fallback to legacy single amount/qty) ──
  bool get usesLineItems => lineItems.isNotEmpty;

  double get subtotal => usesLineItems
      ? lineItems.fold(0.0, (sum, li) => sum + li.taxableAmount)
      : amount * quantity;

  double get cgstAmount => gstEnabled && !isInterState ? subtotal * (cgstPercent / 100) : 0.0;
  double get sgstAmount => gstEnabled && !isInterState ? subtotal * (sgstPercent / 100) : 0.0;
  double get igstAmount => gstEnabled && isInterState ? subtotal * (igstPercent / 100) : 0.0;

  // Line items each carry their own tax rate (matches the per-row "Tax %"
  // column in the Sale invoice screen), so when line items are in use the
  // per-line tax sum drives the total instead of the single invoice-level
  // CGST/SGST/IGST split. Legacy single-amount invoices keep the old path.
  double get lineTaxTotal =>
      lineItems.fold(0.0, (sum, li) => sum + li.taxAmount);
  double get totalTax =>
      usesLineItems ? lineTaxTotal : (cgstAmount + sgstAmount + igstAmount);

  double get _preRoundTotal => subtotal + totalTax + shipping;
  double get roundOffAmount =>
      roundOffEnabled ? (_preRoundTotal.roundToDouble() - _preRoundTotal) : 0.0;
  double get grandTotal => _preRoundTotal + roundOffAmount;

  // ── Derived: payment tracking ──
  double get amountPaid => payments.fold(0.0, (sum, p) => sum + p.amount);
  double get balanceDue => (grandTotal - amountPaid).clamp(0, double.infinity);
  bool get isFullyPaid => balanceDue <= 0.01;
  bool get isPartiallyPaid => amountPaid > 0 && !isFullyPaid;

  // Effective display fields — used by existing UI unchanged
  double get displayAmount => usesLineItems ? grandTotal : amount;
  int get displayQuantity =>
      usesLineItems ? lineItems.fold(0, (sum, li) => sum + li.quantity) : quantity;
  String get displayProductName => usesLineItems
      ? (lineItems.length == 1 ? lineItems.first.description : '${lineItems.length} items')
      : productName;

  DateTime? get purchaseDateTime => _parseDdMmYyyy(purchaseDate);
  DateTime? get dueDateTime => _parseDdMmYyyy(dueDate);

  static DateTime? _parseDdMmYyyy(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]), m = int.tryParse(parts[1]), y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  /// Overdue is derived: unpaid + due date passed. Now also accounts for
  /// partial payments — a partially paid invoice past due is still Overdue.
  String get effectiveStatus {
    if (isFullyPaid) return 'Paid';
    final due = dueDateTime;
    if (due != null && due.isBefore(DateTime.now())) return 'Overdue';
    return isPartiallyPaid ? 'Partially Paid' : status;
  }

  factory Invoice.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Invoice(
      id: doc.id,
      invoiceNo: data['invoice_no']?.toString() ?? '',
      productName: data['product_name']?.toString() ?? '',
      vendorName: data['vendor_name']?.toString() ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      purchaseDate: data['purchase_date']?.toString() ?? '',
      status: data['status']?.toString() ?? 'Pending',
      dueDate: data['due_date']?.toString(),
      notes: data['notes']?.toString(),
      lineItems: (data['line_items'] as List<dynamic>?)
          ?.map((e) => InvoiceLineItem.fromMap(Map<String, dynamic>.from(e)))
          .toList() ??
          [],
      customer: data['customer'] != null
          ? CustomerDetails.fromMap(Map<String, dynamic>.from(data['customer']))
          : null,
      gstEnabled: data['gst_enabled'] ?? false,
      cgstPercent: (data['cgst_percent'] as num?)?.toDouble() ?? 9.0,
      sgstPercent: (data['sgst_percent'] as num?)?.toDouble() ?? 9.0,
      igstPercent: (data['igst_percent'] as num?)?.toDouble() ?? 18.0,
      isInterState: data['is_inter_state'] ?? false,
      payments: (data['payments'] as List<dynamic>?)
          ?.map((e) => PaymentRecord.fromMap(Map<String, dynamic>.from(e)))
          .toList() ??
          [],
      recurring: RecurringConfig.fromMap(
          data['recurring'] != null ? Map<String, dynamic>.from(data['recurring']) : null),
      addedBy: data['added_by']?.toString(),
      addedAt: (data['added_at'] as Timestamp?)?.toDate(),
      branch: data['branch']?.toString(),
      paymentMode: data['payment_mode']?.toString() ?? 'Credit',
      shipping: (data['shipping'] as num?)?.toDouble() ?? 0.0,
      roundOffEnabled: data['round_off_enabled'] ?? false,
      termsTitle: data['terms_title']?.toString() ?? 'Sale Invoice',
      termsNotes: data['terms_notes']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'invoice_no': invoiceNo,
      'product_name': productName,
      'vendor_name': vendorName,
      'quantity': quantity,
      'amount': amount,
      'purchase_date': purchaseDate,
      'status': status,
      'due_date': dueDate,
      'notes': notes,
      'line_items': lineItems.map((e) => e.toMap()).toList(),
      'customer': customer?.toMap(),
      'gst_enabled': gstEnabled,
      'cgst_percent': cgstPercent,
      'sgst_percent': sgstPercent,
      'igst_percent': igstPercent,
      'is_inter_state': isInterState,
      'payments': payments.map((e) => e.toMap()).toList(),
      'recurring': recurring.toMap(),
      'added_by': addedBy,
      'added_at': addedAt != null ? Timestamp.fromDate(addedAt!) : null,
      'branch': branch,
      'payment_mode': paymentMode,
      'shipping': shipping,
      'round_off_enabled': roundOffEnabled,
      'terms_title': termsTitle,
      'terms_notes': termsNotes,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  Invoice copyWith({
    String? id,
    String? invoiceNo,
    String? productName,
    String? vendorName,
    int? quantity,
    double? amount,
    String? purchaseDate,
    String? status,
    String? dueDate,
    String? notes,
    List<InvoiceLineItem>? lineItems,
    CustomerDetails? customer,
    bool? gstEnabled,
    double? cgstPercent,
    double? sgstPercent,
    double? igstPercent,
    bool? isInterState,
    List<PaymentRecord>? payments,
    RecurringConfig? recurring,
    bool clearId = false,
    String? addedBy,
    DateTime? addedAt,
    String? branch,
    String? paymentMode,
    double? shipping,
    bool? roundOffEnabled,
    String? termsTitle,
    String? termsNotes,
  }) {
    return Invoice(
      id: clearId ? null : (id ?? this.id),
      invoiceNo: invoiceNo ?? this.invoiceNo,
      productName: productName ?? this.productName,
      vendorName: vendorName ?? this.vendorName,
      quantity: quantity ?? this.quantity,
      amount: amount ?? this.amount,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      lineItems: lineItems ?? this.lineItems,
      customer: customer ?? this.customer,
      gstEnabled: gstEnabled ?? this.gstEnabled,
      cgstPercent: cgstPercent ?? this.cgstPercent,
      sgstPercent: sgstPercent ?? this.sgstPercent,
      igstPercent: igstPercent ?? this.igstPercent,
      isInterState: isInterState ?? this.isInterState,
      payments: payments ?? this.payments,
      recurring: recurring ?? this.recurring,
      addedBy: addedBy ?? this.addedBy,
      addedAt: addedAt ?? this.addedAt,
      branch: branch ?? this.branch,
      paymentMode: paymentMode ?? this.paymentMode,
      shipping: shipping ?? this.shipping,
      roundOffEnabled: roundOffEnabled ?? this.roundOffEnabled,
      termsTitle: termsTitle ?? this.termsTitle,
      termsNotes: termsNotes ?? this.termsNotes,
    );
  }

  double get totalValue => displayAmount;
}