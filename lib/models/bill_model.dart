import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single scanned bill/invoice hardcopy stored in the system.
///
/// The bill image is stored as a Base64-encoded string directly inside the
/// Firestore document (no Firebase Storage / billing plan required). Keep
/// images reasonably compressed (see image_picker's `imageQuality: 85`)
/// since Firestore documents have a 1MB size limit.
class BillModel {
  final String id;
  final String vendorName;
  final String billNumber;
  final double amount;
  final DateTime billDate;
  final String category;
  final String imageBase64; // Base64-encoded JPEG bytes, stored in Firestore
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  BillModel({
    required this.id,
    required this.vendorName,
    required this.billNumber,
    required this.amount,
    required this.billDate,
    required this.category,
    required this.imageBase64,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory BillModel.fromMap(String id, Map<String, dynamic> map) {
    return BillModel(
      id: id,
      vendorName: map['vendorName'] ?? '',
      billNumber: map['billNumber'] ?? '',
      amount: (map['amount'] is int)
          ? (map['amount'] as int).toDouble()
          : (map['amount'] ?? 0.0).toDouble(),
      billDate: (map['billDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: map['category'] ?? 'Other',
      imageBase64: map['imageBase64'] ?? '',
      notes: map['notes'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendorName': vendorName,
      'billNumber': billNumber,
      'amount': amount,
      'billDate': Timestamp.fromDate(billDate),
      'category': category,
      'imageBase64': imageBase64,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  BillModel copyWith({
    String? vendorName,
    String? billNumber,
    double? amount,
    DateTime? billDate,
    String? category,
    String? imageBase64,
    String? notes,
    DateTime? updatedAt,
  }) {
    return BillModel(
      id: id,
      vendorName: vendorName ?? this.vendorName,
      billNumber: billNumber ?? this.billNumber,
      amount: amount ?? this.amount,
      billDate: billDate ?? this.billDate,
      category: category ?? this.category,
      imageBase64: imageBase64 ?? this.imageBase64,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}