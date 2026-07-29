// lib/services/inventory_movement_service.dart
//
// Service layer for the Enterprise Inventory Movement module. Follows the
// exact same conventions already used across the app (StockService,
// ProductService, DroneService):
//   - static methods, no DI container
//   - manual read -> validate -> batch-write instead of runTransaction
//     (kept web-compatible, matching every other service in this codebase)
//   - an in-memory cache for the unfiltered list, cleared on every write
//   - every mutating action is mirrored into ActivityLogService and
//     StaffRewardService, exactly like StockService.addStockIn/addStockOut
//
// Quantity is kept in sync with the existing `products` collection (the
// same collection ProductService reads/writes) so nothing about the
// existing Product model or ProductService needed to change:
//   - Dispatch (Approved -> Dispatched)  : products.quantity -= movement.quantity
//   - Return   (Dispatched -> Returned)  : products.quantity += movement.quantity

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/gamification_constants.dart';
import '../models/inventory_movement.dart';
import 'activity_log_service.dart';
import 'staff_reward_service.dart';

class InventoryMovementService {
  static const String _module = 'Inventory Movement';

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference get _movements =>
      _db.collection('inventory_movements');
  static CollectionReference get _products => _db.collection('products');

  // ── IN-MEMORY CACHE (unfiltered movement list) ───────────────────────────
  // Mirrors StockService's `_allItemsCache` pattern: the Dashboard, History
  // and Pending-Approvals screens all need the full collection, so fetch
  // once and reuse instead of every screen triggering its own read.
  static List<InventoryMovement>? _allCache;

  static void clearCache() => _allCache = null;

  static Future<List<InventoryMovement>> _fetchAll({bool forceRefresh = false}) async {
    if (!forceRefresh && _allCache != null) return _allCache!;
    final snap = await _movements.get();
    final all = snap.docs.map(InventoryMovement.fromDoc).toList()
      ..sort((a, b) {
        final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta); // newest first
      });
    _allCache = all;
    return all;
  }

  static Future<List<InventoryMovement>> fetchAll({bool forceRefresh = false}) =>
      _fetchAll(forceRefresh: forceRefresh);

  static Future<InventoryMovement?> fetchById(String id) async {
    final doc = await _movements.doc(id).get();
    if (!doc.exists) return null;
    return InventoryMovement.fromDoc(doc);
  }

  // ── Real-time stream — used by the dashboard & history screens so
  // approvals/dispatches/returns made from another device show up live. ────
  static Stream<List<InventoryMovement>> streamAll() {
    return _movements.snapshots().map((s) {
      final list = s.docs.map(InventoryMovement.fromDoc).toList()
        ..sort((a, b) {
          final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
        });
      // Keep the one-shot cache warm too, so switching between the
      // streamed dashboard and a fetchAll()-based screen doesn't force an
      // extra read.
      _allCache = list;
      return list;
    });
  }

  // ── Dashboard aggregates ──────────────────────────────────────────────────
  static Future<MovementDashboardData> fetchDashboard({bool forceRefresh = false}) async {
    final all = await _fetchAll(forceRefresh: forceRefresh);
    return _aggregate(all);
  }

  static MovementDashboardData _aggregate(List<InventoryMovement> all) {
    final active = all.where((m) => m.isActive).length;
    final out = all.where((m) => m.isOut).length;
    final overdue = all.where((m) => m.isOverdue).length;
    final returnedToday = all.where((m) => m.isReturnedToday).length;
    final pending = all.where((m) => m.isPending).length;

    return MovementDashboardData(
      totalActiveMovements: active,
      itemsOut: out,
      overdueReturns: overdue,
      returnedToday: returnedToday,
      pendingApprovals: pending,
      recent: all.take(8).toList(),
    );
  }

  // ── Filtered history (Today / This Week / This Month / Type / Status /
  // Destination) — filtered client-side over the cached full list, same
  // approach as StockService's history filters. ───────────────────────────
  static Future<List<InventoryMovement>> fetchHistory({
    String dateFilter = 'All', // All | Today | This Week | This Month
    String? movementType, // null/'All' = no filter
    String? status, // null/'All' = no filter
    String? destination, // free-text contains match on `to`
    bool forceRefresh = false,
  }) async {
    final all = await _fetchAll(forceRefresh: forceRefresh);
    final now = DateTime.now();

    return all.where((m) {
      if (dateFilter != 'All') {
        final created = m.createdAt;
        if (created == null) return false;
        switch (dateFilter) {
          case 'Today':
            if (!(created.year == now.year &&
                created.month == now.month &&
                created.day == now.day)) {
              return false;
            }
            break;
          case 'This Week':
            final startOfWeek =
            DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
            if (created.isBefore(startOfWeek)) return false;
            break;
          case 'This Month':
            if (!(created.year == now.year && created.month == now.month)) {
              return false;
            }
            break;
        }
      }
      if (movementType != null && movementType != 'All' && m.movementType != movementType) {
        return false;
      }
      if (status != null && status != 'All' && m.status != status) {
        return false;
      }
      if (destination != null && destination.trim().isNotEmpty) {
        if (!m.to.toLowerCase().contains(destination.trim().toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // ── CREATE — Movement request, starts life as Pending ────────────────────
  static Future<InventoryMovement> createMovement({
    required String productId,
    required String productName,
    required int quantity,
    required String movementType,
    required String from,
    required String to,
    String purpose = '',
    String remarks = '',
    required String takenBy,
    String usedBy = '',
    required String createdBy,
    DateTime? expectedReturnAt,
  }) async {
    if (quantity <= 0) {
      throw Exception('Quantity must be greater than zero.');
    }

    final movement = InventoryMovement(
      id: '',
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
      createdBy: createdBy,
      expectedReturnAt: expectedReturnAt,
    );

    final ref = await _movements.add(movement.toCreateMap());
    clearCache();

    ActivityLogService.logAdd(
      module: _module,
      itemName: productName,
      data: {
        'Quantity': quantity,
        'Type': movementType,
        'From': from,
        'To': to,
        'Taken By': takenBy,
        'Purpose': purpose,
        if (expectedReturnAt != null) 'Expected Return': expectedReturnAt,
      },
    );

    StaffRewardService.recordActivity(
      action: StaffAction.stockUpdate,
      module: _module,
      refId: 'movement_${ref.id}_create',
    );

    return InventoryMovement(
      id: ref.id,
      productId: movement.productId,
      productName: movement.productName,
      quantity: movement.quantity,
      movementType: movement.movementType,
      from: movement.from,
      to: movement.to,
      purpose: movement.purpose,
      remarks: movement.remarks,
      takenBy: movement.takenBy,
      usedBy: movement.usedBy,
      createdBy: movement.createdBy,
      expectedReturnAt: movement.expectedReturnAt,
    );
  }

  // ── APPROVE — Pending -> Approved ─────────────────────────────────────────
  static Future<void> approveMovement({
    required String id,
    required String approvedBy,
  }) async {
    final snap = await _movements.doc(id).get();
    if (!snap.exists) throw Exception('Movement not found.');
    final m = InventoryMovement.fromDoc(snap);
    if (!m.isPending) {
      throw Exception('Only pending movements can be approved.');
    }

    final now = Timestamp.fromDate(DateTime.now());
    await _movements.doc(id).update({
      'status': MovementStatus.approved,
      'approved_at': now,
      'approved_by': approvedBy,
    });
    clearCache();

    ActivityLogService.logEdit(
      module: _module,
      itemName: m.productName,
      before: {'Status': MovementStatus.pending},
      after: {'Status': MovementStatus.approved, 'Approved By': approvedBy},
    );
  }

  // ── REJECT — Pending -> Rejected ──────────────────────────────────────────
  static Future<void> rejectMovement({
    required String id,
    required String rejectedBy,
    String reason = '',
  }) async {
    final snap = await _movements.doc(id).get();
    if (!snap.exists) throw Exception('Movement not found.');
    final m = InventoryMovement.fromDoc(snap);
    if (!m.isPending) {
      throw Exception('Only pending movements can be rejected.');
    }

    await _movements.doc(id).update({
      'status': MovementStatus.rejected,
      'rejection_reason': reason,
      'approved_by': rejectedBy, // who actioned it
      'approved_at': Timestamp.fromDate(DateTime.now()),
    });
    clearCache();

    ActivityLogService.logEdit(
      module: _module,
      itemName: m.productName,
      before: {'Status': MovementStatus.pending},
      after: {'Status': MovementStatus.rejected, 'Reason': reason, 'Rejected By': rejectedBy},
    );
  }

  // ── DISPATCH — Approved -> Dispatched, decrements product stock ──────────
  // Manual read -> validate -> batch write, same pattern as
  // StockService.addStockOut (web-compatible, no runTransaction).
  static Future<void> dispatchMovement({
    required String id,
    required String dispatchedBy,
  }) async {
    final movRef = _movements.doc(id);
    final movSnap = await movRef.get();
    if (!movSnap.exists) throw Exception('Movement not found.');
    final m = InventoryMovement.fromDoc(movSnap);
    if (!m.isApproved) {
      throw Exception('Only approved movements can be dispatched.');
    }

    // Manually-entered items (typed in instead of picked from the product
    // list) have no productId, so there's no stock record to decrement —
    // just move the workflow forward without touching `products`.
    DocumentReference? prodRef;
    int? currentQty;
    int? newQty;
    if (m.productId.isNotEmpty) {
      prodRef = _products.doc(m.productId);
      final prodSnap = await prodRef.get();
      if (prodSnap.exists) {
        final prodData = prodSnap.data() as Map<String, dynamic>;
        currentQty = (prodData['quantity'] as num?)?.toInt() ?? 0;
        if (currentQty < m.quantity) {
          throw Exception(
              'Insufficient stock for "${m.productName}". Available: $currentQty, Requested: ${m.quantity}');
        }
        newQty = currentQty - m.quantity;
      } else {
        prodRef = null; // product was removed since the request was made
      }
    }
    final now = Timestamp.fromDate(DateTime.now());

    final batch = _db.batch();
    if (prodRef != null && newQty != null) {
      batch.update(prodRef, {
        'quantity': newQty,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.update(movRef, {
      'status': MovementStatus.dispatched,
      'dispatched_at': now,
      'dispatched_by': dispatchedBy,
    });
    await batch.commit();
    clearCache();

    ActivityLogService.logEdit(
      module: _module,
      itemName: m.productName,
      before: {'Status': MovementStatus.approved, if (currentQty != null) 'Stock Qty': currentQty},
      after: {
        'Status': MovementStatus.dispatched,
        if (newQty != null) 'Stock Qty': newQty,
        'Dispatched By': dispatchedBy,
      },
    );

    StaffRewardService.recordActivity(
      action: StaffAction.stockUpdate,
      module: _module,
      refId: 'movement_${id}_dispatch',
    );
  }

  // ── RETURN — Dispatched -> Returned, restores product stock ──────────────
  static Future<void> returnMovement({
    required String id,
    required String returnedBy,
  }) async {
    final movRef = _movements.doc(id);
    final movSnap = await movRef.get();
    if (!movSnap.exists) throw Exception('Movement not found.');
    final m = InventoryMovement.fromDoc(movSnap);
    if (!m.isDispatched) {
      throw Exception('Only dispatched (out) movements can be returned.');
    }

    final prodRef = m.productId.isEmpty ? null : _products.doc(m.productId);
    final prodSnap = prodRef != null ? await prodRef.get() : null;
    final currentQty = (prodSnap != null && prodSnap.exists)
        ? ((prodSnap.data() as Map<String, dynamic>)['quantity'] as num?)?.toInt() ?? 0
        : 0;
    final newQty = currentQty + m.quantity;
    final now = Timestamp.fromDate(DateTime.now());

    final batch = _db.batch();
    if (prodRef != null && prodSnap != null && prodSnap.exists) {
      batch.update(prodRef, {
        'quantity': newQty,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.update(movRef, {
      'status': MovementStatus.returned,
      'returned_at': now,
      'returned_by': returnedBy,
    });
    await batch.commit();
    clearCache();

    ActivityLogService.logEdit(
      module: _module,
      itemName: m.productName,
      before: {'Status': MovementStatus.dispatched, if (prodRef != null) 'Stock Qty': currentQty},
      after: {
        'Status': MovementStatus.returned,
        if (prodRef != null) 'Stock Qty': newQty,
        'Returned By': returnedBy,
      },
    );

    StaffRewardService.recordActivity(
      action: StaffAction.stockUpdate,
      module: _module,
      refId: 'movement_${id}_return',
    );
  }

  // ── UPDATE — edit a mistaken Pending entry (product, qty, destination,
  // etc). Same restriction as delete: once a movement has actually moved
  // stock (Dispatched/Returned) it's part of the audit trail and can no
  // longer be edited — only Pending/Approved/Rejected requests can. ───────
  static Future<void> updateMovement({
    required String id,
    required String productId,
    required String productName,
    required int quantity,
    required String movementType,
    required String from,
    required String to,
    String purpose = '',
    String remarks = '',
    required String takenBy,
    String usedBy = '',
    DateTime? expectedReturnAt,
  }) async {
    if (quantity <= 0) {
      throw Exception('Quantity must be greater than zero.');
    }
    final snap = await _movements.doc(id).get();
    if (!snap.exists) throw Exception('Movement not found.');
    final m = InventoryMovement.fromDoc(snap);
    if (m.isDispatched || m.isReturned) {
      throw Exception('Cannot edit a movement that has already moved stock.');
    }

    await _movements.doc(id).update({
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
      'expected_return_at':
      expectedReturnAt != null ? Timestamp.fromDate(expectedReturnAt) : null,
    });
    clearCache();

    ActivityLogService.logEdit(
      module: _module,
      itemName: productName,
      before: {'Quantity': m.quantity, 'To': m.to, 'Type': m.movementType},
      after: {'Quantity': quantity, 'To': to, 'Type': movementType},
    );
  }

  // ── DELETE (admin cleanup of a mistaken Pending/Rejected entry only —
  // never allowed once stock has actually moved, to keep the audit trail
  // and stock counts consistent). ─────────────────────────────────────────
  static Future<void> deleteMovement(String id) async {
    final snap = await _movements.doc(id).get();
    if (!snap.exists) return;
    final m = InventoryMovement.fromDoc(snap);
    if (m.isDispatched || m.isReturned) {
      throw Exception('Cannot delete a movement that has already moved stock.');
    }
    await _movements.doc(id).delete();
    clearCache();

    ActivityLogService.logDelete(
      module: _module,
      itemName: m.productName,
      data: {'Quantity': m.quantity, 'Status': m.status},
    );
  }
}