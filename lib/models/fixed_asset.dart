import 'package:cloud_firestore/cloud_firestore.dart';

/// Fixed Asset model — backed by the `fixed_assets` collection in
/// Cloud Firestore. Replaces the old MySQL/Node.js-backed model.
class FixedAsset {
  final String id;
  final String name;
  final int quantity;
  final String branch;
  final String location;
  final String description;
  final String category;
  final String status;
  final String? createdBy;
  final DateTime? createdAt;

  FixedAsset({
    required this.id,
    required this.name,
    required this.quantity,
    required this.branch,
    required this.location,
    required this.description,
    this.category = 'Fixed Asset',
    this.status = 'Active',
    this.createdBy,
    this.createdAt,
  });

  /// Build a [FixedAsset] from a Firestore document snapshot.
  factory FixedAsset.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return FixedAsset(
      id: doc.id,
      name: data['name'] as String? ?? '',
      quantity: data['quantity'] is int
          ? data['quantity'] as int
          : int.tryParse('${data['quantity']}') ?? 0,
      branch: data['branch'] as String? ?? 'CDA Admin',
      location: data['location'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? 'Fixed Asset',
      status: data['status'] as String? ?? 'Active',
      createdBy: data['createdBy'] as String?,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert to a map for writing to Firestore.
  /// Deliberately excludes id / createdBy / createdAt — those are set by
  /// the service layer (createdAt + createdBy only at creation time).
  Map<String, dynamic> toMap() => {
    'name': name,
    'quantity': quantity,
    'branch': branch,
    'location': location,
    'description': description,
    'category': category,
    'status': status,
  };

  FixedAsset copyWith({
    String? id,
    String? name,
    int? quantity,
    String? branch,
    String? location,
    String? description,
    String? category,
    String? status,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return FixedAsset(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      branch: branch ?? this.branch,
      location: location ?? this.location,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}