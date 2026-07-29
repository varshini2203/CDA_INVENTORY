import 'package:cloud_firestore/cloud_firestore.dart';

class SaleReturn {
  final String? id;
  final String productName;
  final String customerName;
  final int quantity;
  final double amount;
  final String reason;
  final String referenceInvoice;
  final String branch;
  final String returnDate;
  final DateTime? createdAt;

  SaleReturn({
    this.id,
    required this.productName,
    required this.customerName,
    required this.quantity,
    required this.amount,
    required this.reason,
    required this.referenceInvoice,
    required this.branch,
    required this.returnDate,
    this.createdAt,
  });

  factory SaleReturn.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return SaleReturn(
      id: doc.id,
      productName: d['product_name']?.toString() ?? '',
      customerName: d['customer_name']?.toString() ?? '',
      quantity: (d['quantity'] as num?)?.toInt() ?? 0,
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      reason: d['reason']?.toString() ?? '',
      referenceInvoice: d['reference_invoice']?.toString() ?? '',
      branch: d['branch']?.toString() ?? '',
      returnDate: d['return_date']?.toString() ?? '',
      createdAt:
      d['created_at'] != null ? (d['created_at'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'product_name': productName,
    'customer_name': customerName,
    'quantity': quantity,
    'amount': amount,
    'reason': reason,
    'reference_invoice': referenceInvoice,
    'branch': branch,
    'return_date': returnDate,
  };
}