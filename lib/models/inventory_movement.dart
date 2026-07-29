// lib/models/inventory_movement.dart
//
// Data model for the Enterprise Inventory Movement module.
// Follows the same conventions as lib/models/product.dart and
// lib/models/stock.dart: a plain Firestore-backed class with
// fromDoc / toCreateMap / toMap / copyWith, all timestamps read via
// FieldValue.serverTimestamp() on write and Timestamp -> DateTime on read.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Movement type — where the stock is going / what it's for.
class MovementType {
  static const branch = 'Branch';
  static const workshop = 'Workshop';
  static const expo = 'Expo';
  static const repair = 'Repair';
  static const other = 'Other';

  static const List<String> all = [branch, workshop, expo, repair, other];
}

/// Approval workflow status. Pending -> Approved -> Dispatched -> Returned,
/// with Rejected as a terminal branch off Pending.
class MovementStatus {
  static const pending = 'Pending';
  static const approved = 'Approved';
  static const dispatched = 'Dispatched';
  static const returned = 'Returned';
  static const rejected = 'Rejected';

  static const List<String> all = [
    pending,
    approved,
    dispatched,
    returned,
    rejected,
  ];

  /// Statuses that still count as "open" / not yet closed out.
  static const List<String> active = [pending, approved, dispatched];
}

class InventoryMovement {
  final String id;

  // ── What & how much ───────────────────────────────────────────────────
  final String productId;
  final String productName;
  final int quantity;

  // ── Movement details ──────────────────────────────────────────────────
  final String movementType; // Branch / Workshop / Expo / Repair / Other
  final String from;
  final String to;
  final String purpose;
  final String remarks;

  // ── People ─────────────────────────────────────────────────────────────
  final String takenBy;
  final String usedBy;
  final String returnedBy;

  // ── Workflow ───────────────────────────────────────────────────────────
  final String status; // MovementStatus.*
  final String? rejectionReason;

  // ── Auto-captured timestamps ──────────────────────────────────────────
  final DateTime? createdAt;
  final String createdBy;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime? dispatchedAt;
  final String? dispatchedBy;
  final DateTime? returnedAt;

  // ── Expected return ────────────────────────────────────────────────────
  final DateTime? expectedReturnAt;

  const InventoryMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.movementType,
    required this.from,
    required this.to,
    this.purpose = '',
    this.remarks = '',
    required this.takenBy,
    this.usedBy = '',
    this.returnedBy = '',
    this.status = MovementStatus.pending,
    this.rejectionReason,
    this.createdAt,
    required this.createdBy,
    this.approvedAt,
    this.approvedBy,
    this.dispatchedAt,
    this.dispatchedBy,
    this.returnedAt,
    this.expectedReturnAt,
  });

  // ── Firestore DocumentSnapshot -> InventoryMovement ─────────────────────
  factory InventoryMovement.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? ts(String key) => (data[key] as Timestamp?)?.toDate();
    return InventoryMovement(
      id: doc.id,
      productId: data['product_id'] as String? ?? '',
      productName: data['product_name'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      movementType: data['movement_type'] as String? ?? MovementType.other,
      from: data['from'] as String? ?? '',
      to: data['to'] as String? ?? '',
      purpose: data['purpose'] as String? ?? '',
      remarks: data['remarks'] as String? ?? '',
      takenBy: data['taken_by'] as String? ?? '',
      usedBy: data['used_by'] as String? ?? '',
      returnedBy: data['returned_by'] as String? ?? '',
      status: data['status'] as String? ?? MovementStatus.pending,
      rejectionReason: data['rejection_reason'] as String?,
      createdAt: ts('created_at'),
      createdBy: data['created_by'] as String? ?? '',
      approvedAt: ts('approved_at'),
      approvedBy: data['approved_by'] as String?,
      dispatchedAt: ts('dispatched_at'),
      dispatchedBy: data['dispatched_by'] as String?,
      returnedAt: ts('returned_at'),
      expectedReturnAt: ts('expected_return_at'),
    );
  }

  // ── Create map (initial write — status is always Pending) ──────────────
  Map<String, dynamic> toCreateMap() => {
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
    'movement_type': movementType,
    'from': from,
    'to': to,
    'purpose': purpose,
    'remarks': remarks,
    'taken_by': takenBy,
    'used_by': usedBy,
    'returned_by': '',
    'status': MovementStatus.pending,
    'created_at': FieldValue.serverTimestamp(),
    'created_by': createdBy,
    'expected_return_at':
    expectedReturnAt != null ? Timestamp.fromDate(expectedReturnAt!) : null,
  };

  // ── Derived / display helpers ───────────────────────────────────────────
  bool get isPending => status == MovementStatus.pending;
  bool get isApproved => status == MovementStatus.approved;
  bool get isDispatched => status == MovementStatus.dispatched;
  bool get isReturned => status == MovementStatus.returned;
  bool get isRejected => status == MovementStatus.rejected;
  bool get isActive => MovementStatus.active.contains(status);
  bool get isOut => status == MovementStatus.dispatched;

  /// Overdue = currently dispatched (out), has an expected-return date/time,
  /// and that date/time has already passed.
  bool get isOverdue =>
      isDispatched &&
          expectedReturnAt != null &&
          expectedReturnAt!.isBefore(DateTime.now());

  bool get isReturnedToday {
    if (!isReturned || returnedAt == null) return false;
    final now = DateTime.now();
    final r = returnedAt!;
    return now.year == r.year && now.month == r.month && now.day == r.day;
  }

  InventoryMovement copyWith({
    String? status,
    String? approvedBy,
    DateTime? approvedAt,
    String? dispatchedBy,
    DateTime? dispatchedAt,
    String? returnedBy,
    DateTime? returnedAt,
    String? rejectionReason,
  }) {
    return InventoryMovement(
      id: id,
      productId: productId,
      productName: productName,
      quantity: quantity,
      movementType: movementType,
      from: from,
      to: to,
      purpose: purpose,
      remarks: remarks,
      takenBy: takenBy,
      usedBy: usedBy,
      returnedBy: returnedBy ?? this.returnedBy,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt,
      createdBy: createdBy,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      dispatchedAt: dispatchedAt ?? this.dispatchedAt,
      dispatchedBy: dispatchedBy ?? this.dispatchedBy,
      returnedAt: returnedAt ?? this.returnedAt,
      expectedReturnAt: expectedReturnAt,
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
  final int totalActiveMovements;
  final int itemsOut;
  final int overdueReturns;
  final int returnedToday;
  final int pendingApprovals;
  final List<InventoryMovement> recent;

  const MovementDashboardData({
    required this.totalActiveMovements,
    required this.itemsOut,
    required this.overdueReturns,
    required this.returnedToday,
    required this.pendingApprovals,
    this.recent = const [],
  });
}