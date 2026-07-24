// lib/models/inventory_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItem {
  final String id;           // Firestore document ID
  final String name;
  final String category;
  final String location;
  final int quantity;
  final String description;
  final int branch;          // 1 = Branch 1 (Adambakkam), 2 = Branch 2, 0 = unassigned/legacy item
  final String? addedBy;     // 🆕 name of whoever added/edited this item
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.quantity,
    this.description = '',
    this.branch = 0,
    this.addedBy,
    this.createdAt,
    this.updatedAt,
  });

  // ── Firestore → Model ──────────────────────────────────────────────────────
  factory InventoryItem.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InventoryItem(
      id: doc.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? 'ONFIELD',
      location: data['location'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      description: data['description'] as String? ?? '',
      branch: (data['branch'] as num?)?.toInt() ?? 0,
      addedBy: data['addedBy'] as String?,   // 🆕 null-safe for older docs
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // ── Model → Firestore map ──────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'location': location,
      'quantity': quantity,
      'description': description,
      'branch': branch,
      'addedBy': addedBy,   // 🆕
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ── Map used only on create (adds createdAt) ───────────────────────────────
  Map<String, dynamic> toCreateMap() {
    return {
      ...toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // ── Convert to plain Map (for backward compat with existing UI widgets) ────
  Map<String, dynamic> toPlainMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'location': location,
      'quantity': quantity,
      'description': description,
      'branch': branch,
      'addedBy': addedBy,   // 🆕
    };
  }

  // ── Branch display helper ───────────────────────────────────────────────────
  String get branchLabel {
    switch (branch) {
      case 1:
        return 'CDA Admin';
      case 2:
        return 'CDA Ops';
      default:
        return 'Unassigned';
    }
  }

  // ── CopyWith ───────────────────────────────────────────────────────────────
  InventoryItem copyWith({
    String? id,
    String? name,
    String? category,
    String? location,
    int? quantity,
    String? description,
    int? branch,
    String? addedBy,        // 🆕
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      location: location ?? this.location,
      quantity: quantity ?? this.quantity,
      description: description ?? this.description,
      branch: branch ?? this.branch,
      addedBy: addedBy ?? this.addedBy,   // 🆕
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ── Stock status helpers ───────────────────────────────────────────────────
  bool get isOutOfStock => quantity == 0;
  bool get isLowStock => quantity > 0 && quantity <= 2;
  bool get isInStock => quantity > 2;

  String get stockLabel {
    if (isOutOfStock) return 'Out of Stock';
    if (isLowStock) return 'Low Stock';
    return 'In Stock';
  }

  @override
  String toString() =>
      'InventoryItem(id: $id, name: $name, qty: $quantity, category: $category)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is InventoryItem &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}