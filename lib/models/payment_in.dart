// lib/models/payment_in.dart
//
// A "Payment-In" receipt from a customer. Mirrors the existing
// PaymentOut model/collection pattern, but adds invoice-allocation
// support so a receipt can be applied against one or more outstanding
// Sale Invoices (updating their balance-due via InvoiceService) and/or
// left partly or fully as an unallocated advance.

import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentInInvoiceAllocation {
  final String invoiceId;
  final String invoiceNo;
  final double amountApplied;

  PaymentInInvoiceAllocation({
    required this.invoiceId,
    required this.invoiceNo,
    required this.amountApplied,
  });

  factory PaymentInInvoiceAllocation.fromMap(Map<String, dynamic> m) =>
      PaymentInInvoiceAllocation(
        invoiceId: m['invoice_id']?.toString() ?? '',
        invoiceNo: m['invoice_no']?.toString() ?? '',
        amountApplied: (m['amount_applied'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toMap() => {
    'invoice_id': invoiceId,
    'invoice_no': invoiceNo,
    'amount_applied': amountApplied,
  };
}

class PaymentIn {
  final String? id;
  final String customerName;
  final String phone;
  final double amount; // total amount received
  final String paymentMode; // Cash, Bank Transfer, UPI, Cheque, Card
  final String referenceNumber;
  final String branch;
  final String paymentDate;
  final String notes;
  final List<PaymentInInvoiceAllocation> invoiceAllocations;
  final double advanceAmount; // portion not applied to any invoice
  final DateTime? createdAt;

  PaymentIn({
    this.id,
    required this.customerName,
    this.phone = '',
    required this.amount,
    required this.paymentMode,
    required this.referenceNumber,
    required this.branch,
    required this.paymentDate,
    this.notes = '',
    this.invoiceAllocations = const [],
    this.advanceAmount = 0,
    this.createdAt,
  });

  factory PaymentIn.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return PaymentIn(
      id: doc.id,
      customerName: d['customer_name']?.toString() ?? '',
      phone: d['phone']?.toString() ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: d['payment_mode']?.toString() ?? '',
      referenceNumber: d['reference_number']?.toString() ?? '',
      branch: d['branch']?.toString() ?? '',
      paymentDate: d['payment_date']?.toString() ?? '',
      notes: d['notes']?.toString() ?? '',
      invoiceAllocations: (d['invoice_allocations'] as List<dynamic>?)
          ?.map((e) =>
          PaymentInInvoiceAllocation.fromMap(Map<String, dynamic>.from(e)))
          .toList() ??
          [],
      advanceAmount: (d['advance_amount'] as num?)?.toDouble() ?? 0.0,
      createdAt:
      d['created_at'] != null ? (d['created_at'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'customer_name': customerName,
    'phone': phone,
    'amount': amount,
    'payment_mode': paymentMode,
    'reference_number': referenceNumber,
    'branch': branch,
    'payment_date': paymentDate,
    'notes': notes,
    'invoice_allocations': invoiceAllocations.map((e) => e.toMap()).toList(),
    'advance_amount': advanceAmount,
  };
}