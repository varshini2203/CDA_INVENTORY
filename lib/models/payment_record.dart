// lib/models/payment_record.dart
class PaymentRecord {
  final String id;
  final double amount;
  final DateTime date;
  final String method;      // 'Cash' | 'Bank Transfer' | 'UPI' | 'Cheque' | 'Card'
  final String? reference;  // transaction/cheque number
  final String? notes;

  PaymentRecord({
    required this.id,
    required this.amount,
    required this.date,
    required this.method,
    this.reference,
    this.notes,
  });

  factory PaymentRecord.fromMap(Map<String, dynamic> m) => PaymentRecord(
    id: m['id']?.toString() ?? '',
    amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
    date: (m['date'] is String)
        ? DateTime.tryParse(m['date']) ?? DateTime.now()
        : (m['date']?.toDate() ?? DateTime.now()),
    method: m['method']?.toString() ?? 'Cash',
    reference: m['reference']?.toString(),
    notes: m['notes']?.toString(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'date': date.toIso8601String(),
    'method': method,
    'reference': reference,
    'notes': notes,
  };
}