// lib/models/sale_order.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'invoice_line_item.dart';
import 'customer_details.dart';

class SaleOrder {
  final String? id;
  final String orderNo;
  final CustomerDetails? customer;
  final String orderDate;
  final String? deliveryDate;
  final String status; // Open, Closed, Cancelled
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
  final String? addedBy;
  final DateTime? createdAt;

  static const List<String> statusOptions = ['Open', 'Closed', 'Cancelled'];

  SaleOrder({
    this.id,
    required this.orderNo,
    this.customer,
    required this.orderDate,
    this.deliveryDate,
    this.status = 'Open',
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

  factory SaleOrder.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return SaleOrder(
      id: doc.id,
      orderNo: d['order_no']?.toString() ?? '',
      customer: d['customer'] != null
          ? CustomerDetails.fromMap(Map<String, dynamic>.from(d['customer']))
          : null,
      orderDate: d['order_date']?.toString() ?? '',
      deliveryDate: d['delivery_date']?.toString(),
      status: d['status']?.toString() ?? 'Open',
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
      addedBy: d['added_by']?.toString(),
      createdAt: d['created_at'] != null ? (d['created_at'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'order_no': orderNo,
    'customer': customer?.toMap(),
    'order_date': orderDate,
    'delivery_date': deliveryDate,
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
    'added_by': addedBy,
  };

  SaleOrder copyWith({String? id, String? status, bool clearId = false}) => SaleOrder(
    id: clearId ? null : (id ?? this.id),
    orderNo: orderNo,
    customer: customer,
    orderDate: orderDate,
    deliveryDate: deliveryDate,
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
    addedBy: addedBy,
    createdAt: createdAt,
  );
}