import 'package:cloud_firestore/cloud_firestore.dart';

class Consumable {
  final String id; // Firestore document ID
  final String name;
  final String category;
  final int quantity;
  final int minimumStock;
  final String description;
  final String branch; // e.g. 'Branch 1', 'Branch 2', or 'Branch 1, Branch 2'
  final String? addedBy;       // 🆕 name of whoever last added/edited this item
  final Timestamp? createdAt;
  final Timestamp? updatedAt;  // 🆕 server time of the last edit

  Consumable({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.minimumStock,
    required this.description,
    this.branch = '',
    this.addedBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Build a Consumable from a Firestore document snapshot.
  factory Consumable.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Consumable(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? 'Stationery',
      quantity: (data['quantity'] is int)
          ? data['quantity']
          : int.tryParse('${data['quantity']}') ?? 0,
      minimumStock: (data['minimumStock'] is int)
          ? data['minimumStock']
          : int.tryParse('${data['minimumStock']}') ?? 0,
      description: data['description'] ?? '',
      // Prefer the dedicated 'branch' field. Fall back to scanning
      // 'description' for older documents seeded before this field
      // existed (the original seed script wrote branch text straight
      // into description).
      branch: (data['branch'] as String?)?.isNotEmpty == true
          ? data['branch'] as String
          : _branchFromLegacyDescription(data['description'] ?? ''),
      addedBy: data['addedBy'] as String?,   // 🆕 null-safe, older docs won't have this
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : null,
      updatedAt: data['updatedAt'] is Timestamp   // 🆕
          ? data['updatedAt'] as Timestamp
          : null,
    );
  }

  static String _branchFromLegacyDescription(String desc) {
    if (desc.contains('Branch 1') || desc.contains('Branch 2')) return desc;
    return '';
  }

  /// True if this item is tagged for the given branch ("All" always matches).
  /// Handles multi-branch values like "CDA Admin, CDA Ops" or
  /// "CDA Ops & CDA Admin" (both ',' and '&' are used as separators in
  /// the seeded data).
  bool belongsToBranch(String targetBranch) {
    if (targetBranch == 'All') return true;
    return branch
        .split(RegExp(r'[,&]'))
        .map((e) => e.trim())
        .contains(targetBranch);
  }

  /// Convert to a map for writing to Firestore (no 'id' field, Firestore
  /// manages the document ID separately).
  ///
  /// NOTE: 'updatedAt' is intentionally NOT included here — set it directly
  /// in the update call with FieldValue.serverTimestamp() so Firestore
  /// stamps the real server time instead of a Dart DateTime/Timestamp value.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'quantity': quantity,
      'minimumStock': minimumStock,
      'description': description,
      'branch': branch,
      'addedBy': addedBy,   // 🆕
    };
  }

  Consumable copyWith({
    String? id,
    String? name,
    String? category,
    int? quantity,
    int? minimumStock,
    String? description,
    String? branch,
    String? addedBy,        // 🆕
    Timestamp? updatedAt,   // 🆕
  }) {
    return Consumable(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      minimumStock: minimumStock ?? this.minimumStock,
      description: description ?? this.description,
      branch: branch ?? this.branch,
      addedBy: addedBy ?? this.addedBy,       // 🆕
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt, // 🆕
    );
  }
}