// lib/models/product.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;       // Firestore auto-generated doc ID (was int)
  final String name;
  final String category;
  final int quantity;
  final double price;
  final String? notes;
  // ── Physical storage location (rack room layout) ──────────────────────
  // Free-text so any existing labeling scheme (e.g. "R1", "Rack-3",
  // "Tray B") keeps working without a migration.
  final String? row;
  final String? rack;
  final String? tray;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.price,
    this.notes,
    this.row,
    this.rack,
    this.tray,
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
      row: data['row'] as String?,
      rack: data['rack'] as String?,
      tray: data['tray'] as String?,
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
      'row': row ?? '',
      'rack': rack ?? '',
      'tray': tray ?? '',
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
    String? row,
    String? rack,
    String? tray,
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
      row: row ?? this.row,
      rack: rack ?? this.rack,
      tray: tray ?? this.tray,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ── Location helper ───────────────────────────────────────────────────────
  /// Human-readable combined location, e.g. "Row 2 · Rack 3 · Tray B".
  /// Skips any part that hasn't been set instead of showing empty labels.
  String get locationLabel {
    final parts = <String>[
      if ((row ?? '').trim().isNotEmpty) 'Row ${row!.trim()}',
      if ((rack ?? '').trim().isNotEmpty) 'Rack ${rack!.trim()}',
      if ((tray ?? '').trim().isNotEmpty) 'Tray ${tray!.trim()}',
    ];
    return parts.join(' · ');
  }

  bool get hasLocation =>
      (row ?? '').trim().isNotEmpty ||
          (rack ?? '').trim().isNotEmpty ||
          (tray ?? '').trim().isNotEmpty;

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