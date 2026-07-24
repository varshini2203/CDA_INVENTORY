import 'package:cloud_firestore/cloud_firestore.dart';
import 'invoice_line_item.dart';

class PurchaseOrder {
  final String? id;
  final String productName;
  final String vendorName;
  final String? vendorPhone;
  final int quantity;
  final double expectedCost;
  final String branch;
  final String orderDate;
  final String expectedDeliveryDate;
  final String status; // Pending, Received, Cancelled
  final String notes;
  final String? poNumber;
  final String stateOfSupply;
  final List<InvoiceLineItem> lineItems;
  final DateTime? createdAt;

  PurchaseOrder({
    this.id,
    required this.productName,
    required this.vendorName,
    this.vendorPhone,
    required this.quantity,
    required this.expectedCost,
    required this.branch,
    required this.orderDate,
    required this.expectedDeliveryDate,
    this.status = 'Pending',
    this.notes = '',
    this.poNumber,
    this.stateOfSupply = 'Tamil Nadu',
    this.lineItems = const [],
    this.createdAt,
  });

  factory PurchaseOrder.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return PurchaseOrder(
      id: doc.id,
      productName: d['product_name']?.toString() ?? '',
      vendorName: d['vendor_name']?.toString() ?? '',
      vendorPhone: d['vendor_phone']?.toString(),
      quantity: (d['quantity'] as num?)?.toInt() ?? 0,
      expectedCost: (d['expected_cost'] as num?)?.toDouble() ?? 0.0,
      branch: d['branch']?.toString() ?? '',
      orderDate: d['order_date']?.toString() ?? '',
      expectedDeliveryDate: d['expected_delivery_date']?.toString() ?? '',
      status: d['status']?.toString() ?? 'Pending',
      notes: d['notes']?.toString() ?? '',
      poNumber: d['po_number']?.toString(),
      stateOfSupply: d['state_of_supply']?.toString() ?? 'Tamil Nadu',
      lineItems: (d['line_items'] as List<dynamic>?)
          ?.map((e) => InvoiceLineItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList() ??
          const [],
      createdAt:
      d['created_at'] != null ? (d['created_at'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'product_name': productName,
    'vendor_name': vendorName,
    'vendor_phone': vendorPhone,
    'quantity': quantity,
    'expected_cost': expectedCost,
    'branch': branch,
    'order_date': orderDate,
    'expected_delivery_date': expectedDeliveryDate,
    'status': status,
    'notes': notes,
    'po_number': poNumber,
    'state_of_supply': stateOfSupply,
    'line_items': lineItems.map((e) => e.toMap()).toList(),
  };

  PurchaseOrder copyWith({String? status}) => PurchaseOrder(
    id: id,
    productName: productName,
    vendorName: vendorName,
    vendorPhone: vendorPhone,
    quantity: quantity,
    expectedCost: expectedCost,
    branch: branch,
    orderDate: orderDate,
    expectedDeliveryDate: expectedDeliveryDate,
    status: status ?? this.status,
    notes: notes,
    poNumber: poNumber,
    stateOfSupply: stateOfSupply,
    lineItems: lineItems,
    createdAt: createdAt,
  );
}