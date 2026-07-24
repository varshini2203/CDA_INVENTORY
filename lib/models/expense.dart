import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String? id;
  final String category; // Rent, Electricity, Salary, Transport, Misc, ...
  final double amount;
  final String paidTo;
  final String branch;
  final String expenseDate;
  final String notes;
  final DateTime? createdAt;

  Expense({
    this.id,
    required this.category,
    required this.amount,
    required this.paidTo,
    required this.branch,
    required this.expenseDate,
    this.notes = '',
    this.createdAt,
  });

  factory Expense.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Expense(
      id: doc.id,
      category: d['category']?.toString() ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      paidTo: d['paid_to']?.toString() ?? '',
      branch: d['branch']?.toString() ?? '',
      expenseDate: d['expense_date']?.toString() ?? '',
      notes: d['notes']?.toString() ?? '',
      createdAt:
      d['created_at'] != null ? (d['created_at'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'category': category,
    'amount': amount,
    'paid_to': paidTo,
    'branch': branch,
    'expense_date': expenseDate,
    'notes': notes,
  };
}