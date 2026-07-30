// lib/models/delivery_challan.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'invoice_line_item.dart';
import 'customer_details.dart';

class DeliveryChallan {
  final String? id;
  final String challanNo;
  final CustomerDetails? customer;
  final String challanDate;
  final String? dueDate;
  final String status; // Pending, Delivered, Converted, Cancelled
  final String branch;
  final String notes;
  final List<InvoiceLineItem> lineItems;
  final double shipping;
  final bool roundOffEnabled;
  final bool gstEnabled;
  final double cgstPercent;
  final double sgstPercent;
  final double igstPercent;
  final bool isInterState;
  final String? vehicleNo;
  final String? transportName;
  final String? poNumber;
  final String? convertedInvoiceId;
  final String? convertedInvoiceNo;
  final String? addedBy;
  final DateTime? createdAt;

  static const List<String> statusOptions = ['Pending', 'Delivered', 'Converted', 'Cancelled'];

  DeliveryChallan({
    this.id,
    required this.challanNo,
    this.customer,
    required this.challanDate,
    this.dueDate,
    this.status = 'Pending',
    required this.branch,
    this.notes = '',
    this.lineItems = const [],
    this.shipping = 0,
    this.roundOffEnabled = true,
    this.gstEnabled = false,
    this.cgstPercent = 9,
    this.sgstPercent = 9,
    this.igstPercent = 18,
    this.isInterState = false,
    this.vehicleNo,
    this.transportName,
    this.poNumber,
    this.convertedInvoiceId,
    this.convertedInvoiceNo,
    this.addedBy,
    this.createdAt,
  });

  double get subtotal => lineItems.fold(0.0, (s, i) => s + i.taxableAmount);
  double get cgstAmount => gstEnabled && !isInterState ? subtotal * (cgstPercent / 100) : 0.0;
  double get sgstAmount => gstEnabled && !isInterState ? subtotal * (sgstPercent / 100) : 0.0;
  double get igstAmount => gstEnabled && isInterState ? subtotal * (igstPercent / 100) : 0.0;
  double get lineTaxTotal => lineItems.fold(0.0, (s, i) => s + i.taxAmount);
  double get totalTax => gstEnabled ? cgstAmount + sgstAmount + igstAmount : lineTaxTotal;
  double get _preRoundTotal => subtotal + totalTax + shipping;
  double get roundOffAmount =>
      roundOffEnabled ? (_preRoundTotal.roundToDouble() - _preRoundTotal) : 0.0;
  double get grandTotal => _preRoundTotal + roundOffAmount;
  int get totalQty => lineItems.fold(0, (s, i) => s + i.quantity);

  factory DeliveryChallan.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return DeliveryChallan(
      id: doc.id,
      challanNo: d['challan_no']?.toString() ?? '',
      customer: d['customer'] != null
          ? CustomerDetails.fromMap(Map<String, dynamic>.from(d['customer']))
          : null,
      challanDate: d['challan_date']?.toString() ?? '',
      dueDate: d['due_date']?.toString(),
      status: d['status']?.toString() ?? 'Pending',
      branch: d['branch']?.toString() ?? '',
      notes: d['notes']?.toString() ?? '',
      lineItems: (d['line_items'] as List<dynamic>?)
          ?.map((e) => InvoiceLineItem.fromMap(Map<String, dynamic>.from(e)))
          .toList() ??
          const [],
      shipping: (d['shipping'] as num?)?.toDouble() ?? 0,
      roundOffEnabled: d['round_off_enabled'] as bool? ?? true,
      gstEnabled: d['gst_enabled'] as bool? ?? false,
      cgstPercent: (d['cgst_percent'] as num?)?.toDouble() ?? 9,
      sgstPercent: (d['sgst_percent'] as num?)?.toDouble() ?? 9,
      igstPercent: (d['igst_percent'] as num?)?.toDouble() ?? 18,
      isInterState: d['is_inter_state'] as bool? ?? false,
      vehicleNo: d['vehicle_no']?.toString(),
      transportName: d['transport_name']?.toString(),
      poNumber: d['po_number']?.toString(),
      convertedInvoiceId: d['converted_invoice_id']?.toString(),
      convertedInvoiceNo: d['converted_invoice_no']?.toString(),
      addedBy: d['added_by']?.toString(),
      createdAt: d['created_at'] != null ? (d['created_at'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'challan_no': challanNo,
    'customer': customer?.toMap(),
    'challan_date': challanDate,
    'due_date': dueDate,
    'status': status,
    'branch': branch,
    'notes': notes,
    'line_items': lineItems.map((e) => e.toMap()).toList(),
    'shipping': shipping,
    'round_off_enabled': roundOffEnabled,
    'gst_enabled': gstEnabled,
    'cgst_percent': cgstPercent,
    'sgst_percent': sgstPercent,
    'igst_percent': igstPercent,
    'is_inter_state': isInterState,
    'vehicle_no': vehicleNo,
    'transport_name': transportName,
    'po_number': poNumber,
    'converted_invoice_id': convertedInvoiceId,
    'converted_invoice_no': convertedInvoiceNo,
    'added_by': addedBy,
  };

  DeliveryChallan copyWith({
    String? id,
    String? status,
    String? convertedInvoiceId,
    String? convertedInvoiceNo,
    bool clearId = false,
  }) => DeliveryChallan(
    id: clearId ? null : (id ?? this.id),
    challanNo: challanNo,
    customer: customer,
    challanDate: challanDate,
    dueDate: dueDate,
    status: status ?? this.status,
    branch: branch,
    notes: notes,
    lineItems: lineItems,
    shipping: shipping,
    roundOffEnabled: roundOffEnabled,
    gstEnabled: gstEnabled,
    cgstPercent: cgstPercent,
    sgstPercent: sgstPercent,
    igstPercent: igstPercent,
    isInterState: isInterState,
    vehicleNo: vehicleNo,
    transportName: transportName,
    poNumber: poNumber,
    convertedInvoiceId: convertedInvoiceId ?? this.convertedInvoiceId,
    convertedInvoiceNo: convertedInvoiceNo ?? this.convertedInvoiceNo,
    addedBy: addedBy,
    createdAt: createdAt,
  );
}