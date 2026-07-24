// lib/models/product.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;       // Firestore auto-generated doc ID (was int)
  final String name;
  final String category;
  final int quantity;
  final double price;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.price,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  // ── Firestore DocumentSnapshot → Product ──────────────────────────────────
  factory Product.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // ── Product → Firestore map (for update) ─────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'quantity': quantity,
      'price': price,
      'notes': notes ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ── Product → Firestore map (for create — adds createdAt) ─────────────────
  Map<String, dynamic> toCreateMap() {
    return {
      ...toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // ── CopyWith ──────────────────────────────────────────────────────────────
  Product copyWith({
    String? id,
    String? name,
    String? category,
    int? quantity,
    double? price,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ── Stock helpers ─────────────────────────────────────────────────────────
  bool get isOutOfStock => quantity == 0;
  bool get isLowStock => quantity > 0 && quantity <= 2;
  bool get isInStock => quantity > 2;

  String get stockLabel {
    if (isOutOfStock) return 'Out of Stock';
    if (isLowStock) return 'Low Stock';
    return 'In Stock';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Product(id: $id, name: $name, qty: $quantity, price: $price)';
}