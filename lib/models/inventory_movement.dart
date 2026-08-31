// lib/models/inventory_movement.dart
//
// Data model for the Enterprise Inventory Movement module — v2.
//
// Major changes from v1:
//   - A single movement now carries a LIST of items (product + quantity
//     each), not just one product. `totalQuantity` is the auto-summed
//     total across every line item.
//   - The whole Pending -> Approved -> Dispatched -> Returned approval
//     workflow is gone. There are only two actions now: Check Out and
//     Check In, each independently stamped with its own date/time + who
//     did it, the moment it happens (no waiting on anyone's approval).

import 'package:cloud_firestore/cloud_firestore.dart';

/// Movement type — where the stock is going / what it's for. Shown as a
/// dropdown of common values, but the field itself is free text so a
/// custom value can always be typed in instead (see MovementTypeField).
class MovementType {
  static const branch = 'Branch';
  static const workshop = 'Workshop';
  static const expo = 'Expo';
  static const repair = 'Repair';
  static const other = 'Other';

  static const List<String> all = [branch, workshop, expo, repair, other];
}

/// A single line item within a movement (one product + its quantity).
class MovementItem {
  final String productId; // '' if typed manually / not in the product list
  final String productName;
  final int quantity;

  const MovementItem({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  factory MovementItem.fromMap(Map<String, dynamic> map) => MovementItem(
    productId: map['product_id'] as String? ?? '',
    productName: map['product_name'] as String? ?? '',
    quantity: (map['quantity'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
  };

  MovementItem copyWith({String? productId, String? productName, int? quantity}) =>
      MovementItem(
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        quantity: quantity ?? this.quantity,
      );
}

class InventoryMovement {
  final String id;

  // ── What & how much — one or more line items ────────────────────────────
  final List<MovementItem> items;
  final int totalQuantity; // sum of every item's quantity, kept in sync

  // ── Movement details ──────────────────────────────────────────────────
  final String movementType; // Branch / Workshop / Expo / Repair / Other / custom
  final String from;
  final String to;
  final String purpose;
  final String remarks;

  // ── Who ────────────────────────────────────────────────────────────────
  final String usedBy;

  // ── Check Out / Check In — each independent, each stamped the instant
  // it happens. No approval step in between. ───────────────────────────────
  final DateTime? checkedOutAt;
  final String? checkedOutBy;
  final DateTime? checkedInAt;
  final String? checkedInBy;

  // ── Auto-captured record metadata ────────────────────────────────────────
  final DateTime? createdAt;
  final String createdBy;

  const InventoryMovement({
    required this.id,
    required this.items,
    required this.totalQuantity,
    required this.movementType,
    required this.from,
    required this.to,
    this.purpose = '',
    this.remarks = '',
    required this.usedBy,
    this.checkedOutAt,
    this.checkedOutBy,
    this.checkedInAt,
    this.checkedInBy,
    this.createdAt,
    required this.createdBy,
  });

  // ── Firestore DocumentSnapshot -> InventoryMovement ─────────────────────
  factory InventoryMovement.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? ts(String key) => (data[key] as Timestamp?)?.toDate();
    final rawItems = (data['items'] as List?) ?? const [];
    var items = rawItems
        .map((e) => MovementItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    // ── Backward compatibility with the pre-v2 schema ─────────────────────
    // Older movements (created before the structured `items` list existed)
    // stored a single free-text description directly on the document under
    // one of a few possible keys. If there's no `items` array, recover the
    // name from whichever legacy field is present so it still displays,
    // instead of silently showing "No product recorded".
    if (items.isEmpty) {
      final legacyName = (data['item_name'] ?? data['product_name'] ?? data['product'] ?? data['title'] ?? data['name'])
      as String?;
      if (legacyName != null && legacyName.trim().isNotEmpty) {
        final legacyQty = (data['total_quantity'] as num?)?.toInt() ??
            (data['quantity'] as num?)?.toInt() ??
            (data['qty'] as num?)?.toInt() ??
            0;
        items = [MovementItem(productId: '', productName: legacyName.trim(), quantity: legacyQty)];
      }
    }

    return InventoryMovement(
      id: doc.id,
      items: items,
      totalQuantity: (data['total_quantity'] as num?)?.toInt() ??
          items.fold<int>(0, (sum, i) => sum + i.quantity),
      movementType: data['movement_type'] as String? ?? MovementType.other,
      from: data['from'] as String? ?? '',
      to: data['to'] as String? ?? '',
      purpose: data['purpose'] as String? ?? '',
      remarks: data['remarks'] as String? ?? '',
      usedBy: data['used_by'] as String? ?? '',
      checkedOutAt: ts('checked_out_at'),
      checkedOutBy: data['checked_out_by'] as String?,
      checkedInAt: ts('checked_in_at'),
      checkedInBy: data['checked_in_by'] as String?,
      createdAt: ts('created_at'),
      createdBy: data['created_by'] as String? ?? '',
    );
  }

  // ── Create map (initial write) ──────────────────────────────────────────
  // The caller decides which of checked_out_at / checked_in_at (if either)
  // gets stamped at creation time by passing `action` through the service —
  // this map only carries the fields common to every new movement.
  Map<String, dynamic> toCreateMap() => {
    'items': items.map((i) => i.toMap()).toList(),
    'total_quantity': totalQuantity,
    'movement_type': movementType,
    'from': from,
    'to': to,
    'purpose': purpose,
    'remarks': remarks,
    'used_by': usedBy,
    'created_at': FieldValue.serverTimestamp(),
    'created_by': createdBy,
  };

  // ── Derived / display helpers ───────────────────────────────────────────
  bool get isCheckedOut => checkedOutAt != null;
  bool get isCheckedIn => checkedInAt != null;

  /// Still out — checked out but hasn't been checked back in yet.
  bool get isOpen => isCheckedOut && !isCheckedIn;

  bool get isCheckedOutToday => _isToday(checkedOutAt);
  bool get isCheckedInToday => _isToday(checkedInAt);

  static bool _isToday(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    return now.year == d.year && now.month == d.month && now.day == d.day;
  }

  /// Short label for list/badge display.
  String get statusLabel {
    if (isCheckedIn) return 'Checked In';
    if (isCheckedOut) return 'Checked Out';
    return 'Draft';
  }

  /// One-line summary of the items in this movement, e.g.
  /// "Soldering Iron +2 more" — used on list rows.
  String get itemsSummary {
    if (items.isEmpty) return 'No product recorded';
    if (items.length == 1) return items.first.productName;
    return '${items.first.productName} +${items.length - 1} more';
  }

  InventoryMovement copyWith({
    List<MovementItem>? items,
    int? totalQuantity,
    String? movementType,
    String? from,
    String? to,
    String? purpose,
    String? remarks,
    String? usedBy,
    DateTime? checkedOutAt,
    String? checkedOutBy,
    DateTime? checkedInAt,
    String? checkedInBy,
  }) {
    return InventoryMovement(
      id: id,
      items: items ?? this.items,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      movementType: movementType ?? this.movementType,
      from: from ?? this.from,
      to: to ?? this.to,
      purpose: purpose ?? this.purpose,
      remarks: remarks ?? this.remarks,
      usedBy: usedBy ?? this.usedBy,
      checkedOutAt: checkedOutAt ?? this.checkedOutAt,
      checkedOutBy: checkedOutBy ?? this.checkedOutBy,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      checkedInBy: checkedInBy ?? this.checkedInBy,
      createdAt: createdAt,
      createdBy: createdBy,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is InventoryMovement &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Aggregate counts for the Movement Dashboard cards.
class MovementDashboardData {
  final int totalMovements;
  final int checkedOutOpen; // checked out, not yet checked back in
  final int checkedInToday;
  final int checkedOutToday;
  final List<InventoryMovement> recent;

  const MovementDashboardData({
    required this.totalMovements,
    required this.checkedOutOpen,
    required this.checkedInToday,
    required this.checkedOutToday,
    this.recent = const [],
  });
}