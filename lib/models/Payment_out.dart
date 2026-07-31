import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentOut {
  final String? id;
  final String vendorName;
  final double amount;
  final String paymentMode; // Cash, Bank Transfer, UPI, Cheque
  final String referenceNumber;
  final String branch;
  final String paymentDate;
  final String notes;
  final String? attachmentName;
  final String? attachmentBase64;
  final DateTime? createdAt;

  PaymentOut({
    this.id,
    required this.vendorName,
    required this.amount,
    required this.paymentMode,
    required this.referenceNumber,
    required this.branch,
    required this.paymentDate,
    this.notes = '',
    this.attachmentName,
    this.attachmentBase64,
    this.createdAt,
  });

  factory PaymentOut.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return PaymentOut(
      id: doc.id,
      vendorName: d['vendor_name']?.toString() ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: d['payment_mode']?.toString() ?? '',
      referenceNumber: d['reference_number']?.toString() ?? '',
      branch: d['branch']?.toString() ?? '',
      paymentDate: d['payment_date']?.toString() ?? '',
      notes: d['notes']?.toString() ?? '',
      attachmentName: d['attachment_name']?.toString(),
      attachmentBase64: d['attachment_base64']?.toString(),
      createdAt:
      d['created_at'] != null ? (d['created_at'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'vendor_name': vendorName,
    'amount': amount,
    'payment_mode': paymentMode,
    'reference_number': referenceNumber,
    'branch': branch,
    'payment_date': paymentDate,
    'notes': notes,
    if (attachmentName != null) 'attachment_name': attachmentName,
    if (attachmentBase64 != null) 'attachment_base64': attachmentBase64,
  };
}