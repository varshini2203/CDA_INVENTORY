import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseReturn {
  final String? id;
  final String productName;
  final String vendorName;
  final int quantity;
  final double amount;
  final String reason;
  final String referenceInvoice;
  final String branch;
  final String returnDate;
  final DateTime? createdAt;

  PurchaseReturn({
    this.id,
    required this.productName,
    required this.vendorName,
    required this.quantity,
    required this.amount,
    required this.reason,
    required this.referenceInvoice,
    required this.branch,
    required this.returnDate,
    this.createdAt,
  });

  factory PurchaseReturn.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return PurchaseReturn(
      id: doc.id,
      productName: d['product_name']?.toString() ?? '',
      vendorName: d['vendor_name']?.toString() ?? '',
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
    'vendor_name': vendorName,
    'quantity': quantity,
    'amount': amount,
    'reason': reason,
    'reference_invoice': referenceInvoice,
    'branch': branch,
    'return_date': returnDate,
  };
}