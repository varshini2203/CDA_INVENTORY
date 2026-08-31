// lib/services/inventory_movement_service.dart
//
// Service layer for the Enterprise Inventory Movement module — v2.
//
//   - Movements can carry multiple line items; stock is adjusted per item.
//   - No approval workflow. Two independent actions only:
//       Check Out : products.quantity -= item.quantity  (per line item)
//       Check In  : products.quantity += item.quantity  (per line item)
//     Each is stamped with date/time + who the instant it happens — either
//     right at creation (whichever action the user picked) or later from
//     the detail screen (the other side, if it hasn't happened yet).
//   - Manually-typed items (no productId) don't touch `products` at all —
//     same behaviour as before.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/gamification_constants.dart';
import '../models/inventory_movement.dart';
import 'activity_log_service.dart';
import 'staff_reward_service.dart';

/// Which action to perform immediately at creation time.
enum MovementAction { checkOut, checkIn }

class InventoryMovementService {
  static const String _module = 'Inventory Movement';

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference get _movements =>
      _db.collection('inventory_movements');
  static CollectionReference get _products => _db.collection('products');

  // ── IN-MEMORY CACHE (unfiltered movement list) ───────────────────────────
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

  // ── Real-time stream — used by the dashboard & history screens. ─────────
  static Stream<List<InventoryMovement>> streamAll() {
    return _movements.snapshots().map((s) {
      final list = s.docs.map(InventoryMovement.fromDoc).toList()
        ..sort((a, b) {
          final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
        });
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
    return MovementDashboardData(
      totalMovements: all.length,
      checkedOutOpen: all.where((m) => m.isOpen).length,
      checkedInToday: all.where((m) => m.isCheckedInToday).length,
      checkedOutToday: all.where((m) => m.isCheckedOutToday).length,
      recent: all.take(8).toList(),
    );
  }

  // ── Filtered history (Today / This Week / This Month / Type / Direction /
  // Destination) — filtered client-side over the cached full list. ─────────
  static Future<List<InventoryMovement>> fetchHistory({
    String dateFilter = 'All', // All | Today | This Week | This Month
    String? movementType, // null/'All' = no filter
    String? direction, // null/'All' | 'Checked Out' | 'Checked In' | 'Open'
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
      if (direction != null && direction != 'All') {
        switch (direction) {
          case 'Checked Out':
            if (!m.isCheckedOut) return false;
            break;
          case 'Checked In':
            if (!m.isCheckedIn) return false;
            break;
          case 'Open':
            if (!m.isOpen) return false;
            break;
        }
      }
      if (destination != null && destination.trim().isNotEmpty) {
        if (!m.to.toLowerCase().contains(destination.trim().toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // ── CREATE — one or more line items, plus an immediate Check Out or
  // Check In action (no approval step, no waiting). ────────────────────────
  static Future<InventoryMovement> createMovement({
    required List<MovementItem> items,
    required String movementType,
    required String from,
    required String to,
    String purpose = '',
    String remarks = '',
    required String usedBy,
    required MovementAction action,
    required String actedBy, // who is checking it in/out (current user)
    required String createdBy,
    DateTime? when, // manual date/time for the check-out/in stamp; defaults to now
  }) async {
    if (items.isEmpty) {
      throw Exception('Add at least one item.');
    }
    for (final item in items) {
      if (item.quantity <= 0) {
        throw Exception('Every item needs a quantity greater than zero.');
      }
    }
    final totalQuantity = items.fold<int>(0, (sum, i) => sum + i.quantity);

    final movRef = _movements.doc();
    final now = Timestamp.fromDate(when ?? DateTime.now());

    // Read current stock for every item that has a productId, so we can
    // validate + adjust it in the same batch as the movement write.
    final withProductId = items.where((i) => i.productId.isNotEmpty).toList();
    final prodSnaps = await Future.wait(
      withProductId.map((i) => _products.doc(i.productId).get()),
    );

    final batch = _db.batch();

    for (var idx = 0; idx < withProductId.length; idx++) {
      final item = withProductId[idx];
      final snap = prodSnaps[idx];
      if (!snap.exists) continue; // product removed since — skip stock touch
      final currentQty = ((snap.data() as Map<String, dynamic>)['quantity'] as num?)?.toInt() ?? 0;
      int newQty;
      if (action == MovementAction.checkOut) {
        if (currentQty < item.quantity) {
          throw Exception(
              'Insufficient stock for "${item.productName}". Available: $currentQty, Requested: ${item.quantity}');
        }
        newQty = currentQty - item.quantity;
      } else {
        newQty = currentQty + item.quantity;
      }
      batch.update(snap.reference, {
        'quantity': newQty,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final movement = InventoryMovement(
      id: movRef.id,
      items: items,
      totalQuantity: totalQuantity,
      movementType: movementType,
      from: from,
      to: to,
      purpose: purpose,
      remarks: remarks,
      usedBy: usedBy,
      createdBy: createdBy,
    );

    final createMap = movement.toCreateMap();
    if (action == MovementAction.checkOut) {
      createMap['checked_out_at'] = now;
      createMap['checked_out_by'] = actedBy;
    } else {
      createMap['checked_in_at'] = now;
      createMap['checked_in_by'] = actedBy;
    }
    batch.set(movRef, createMap);
    await batch.commit();
    clearCache();

    final actionLabel = action == MovementAction.checkOut ? 'Checked Out' : 'Checked In';
    ActivityLogService.logAdd(
      module: _module,
      itemName: movement.itemsSummary,
      data: {
        'Total Quantity': totalQuantity,
        'Items': items.length,
        'Type': movementType,
        'From': from,
        'To': to,
        'Used By': usedBy,
        'Action': actionLabel,
      },
    );

    StaffRewardService.recordActivity(
      action: StaffAction.stockUpdate,
      module: _module,
      refId: 'movement_${movRef.id}_create',
    );

    return InventoryMovement.fromDoc(await movRef.get());
  }

  // ── CHECK OUT — from the detail screen, for a movement that was created
  // as (or already is) a Check In and hasn't gone out yet. ─────────────────
  static Future<void> checkOut({
    required String id,
    required String checkedOutBy,
    DateTime? when, // manual date/time for the check-out stamp; defaults to now
  }) async {
    final movRef = _movements.doc(id);
    final movSnap = await movRef.get();
    if (!movSnap.exists) throw Exception('Movement not found.');
    final m = InventoryMovement.fromDoc(movSnap);
    if (m.isCheckedOut) {
      throw Exception('Already checked out.');
    }

    final withProductId = m.items.where((i) => i.productId.isNotEmpty).toList();
    final prodSnaps = await Future.wait(
      withProductId.map((i) => _products.doc(i.productId).get()),
    );

    final batch = _db.batch();
    for (var idx = 0; idx < withProductId.length; idx++) {
      final item = withProductId[idx];
      final snap = prodSnaps[idx];
      if (!snap.exists) continue;
      final currentQty = ((snap.data() as Map<String, dynamic>)['quantity'] as num?)?.toInt() ?? 0;
      if (currentQty < item.quantity) {
        throw Exception(
            'Insufficient stock for "${item.productName}". Available: $currentQty, Requested: ${item.quantity}');
      }
      batch.update(snap.reference, {
        'quantity': currentQty - item.quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    final now = Timestamp.fromDate(when ?? DateTime.now());
    batch.update(movRef, {'checked_out_at': now, 'checked_out_by': checkedOutBy});
    await batch.commit();
    clearCache();

    ActivityLogService.logEdit(
      module: _module,
      itemName: m.itemsSummary,
      before: {'Checked Out': 'No'},
      after: {'Checked Out': 'Yes', 'Checked Out By': checkedOutBy},
    );

    StaffRewardService.recordActivity(
      action: StaffAction.stockUpdate,
      module: _module,
      refId: 'movement_${id}_checkout',
    );
  }

  // ── CHECK IN — from the detail screen, closes out an open (checked out,
  // not yet checked in) movement and restores stock. ───────────────────────
  static Future<void> checkIn({
    required String id,
    required String checkedInBy,
    DateTime? when, // manual date/time for the check-in stamp; defaults to now
  }) async {
    final movRef = _movements.doc(id);
    final movSnap = await movRef.get();
    if (!movSnap.exists) throw Exception('Movement not found.');
    final m = InventoryMovement.fromDoc(movSnap);
    if (m.isCheckedIn) {
      throw Exception('Already checked in.');
    }

    final withProductId = m.items.where((i) => i.productId.isNotEmpty).toList();
    final prodSnaps = await Future.wait(
      withProductId.map((i) => _products.doc(i.productId).get()),
    );

    final batch = _db.batch();
    for (var idx = 0; idx < withProductId.length; idx++) {
      final item = withProductId[idx];
      final snap = prodSnaps[idx];
      if (!snap.exists) continue;
      final currentQty = ((snap.data() as Map<String, dynamic>)['quantity'] as num?)?.toInt() ?? 0;
      batch.update(snap.reference, {
        'quantity': currentQty + item.quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    final now = Timestamp.fromDate(when ?? DateTime.now());
    batch.update(movRef, {'checked_in_at': now, 'checked_in_by': checkedInBy});
    await batch.commit();
    clearCache();

    ActivityLogService.logEdit(
      module: _module,
      itemName: m.itemsSummary,
      before: {'Checked In': 'No'},
      after: {'Checked In': 'Yes', 'Checked In By': checkedInBy},
    );

    StaffRewardService.recordActivity(
      action: StaffAction.stockUpdate,
      module: _module,
      refId: 'movement_${id}_checkin',
    );
  }

  // ── UPDATE — edit the details of a movement (type/from/to/purpose/
  // remarks/used by only). Items and their quantities are locked once a
  // movement is created, since editing them after stock has already moved
  // would need a separate reconciliation step. ─────────────────────────────
  static Future<void> updateMovement({
    required String id,
    required String movementType,
    required String from,
    required String to,
    String purpose = '',
    String remarks = '',
    required String usedBy,
    DateTime? checkedOutAt, // pass to manually correct the Check Out stamp
    DateTime? checkedInAt, // pass to manually correct the Check In stamp
    List<MovementItem>? items, // only honoured if this movement currently has NO items —
    // safe to backfill since no stock was ever touched for it
  }) async {
    final snap = await _movements.doc(id).get();
    if (!snap.exists) throw Exception('Movement not found.');
    final m = InventoryMovement.fromDoc(snap);

    final updateMap = <String, dynamic>{
      'movement_type': movementType,
      'from': from,
      'to': to,
      'purpose': purpose,
      'remarks': remarks,
      'used_by': usedBy,
    };
    if (checkedOutAt != null) {
      updateMap['checked_out_at'] = Timestamp.fromDate(checkedOutAt);
    }
    if (checkedInAt != null) {
      updateMap['checked_in_at'] = Timestamp.fromDate(checkedInAt);
    }
    if (m.items.isEmpty && items != null && items.isNotEmpty) {
      updateMap['items'] = items.map((i) => i.toMap()).toList();
      updateMap['total_quantity'] = items.fold<int>(0, (sum, i) => sum + i.quantity);
    }

    await _movements.doc(id).update(updateMap);
    clearCache();

    ActivityLogService.logEdit(
      module: _module,
      itemName: m.itemsSummary,
      before: {'To': m.to, 'Type': m.movementType},
      after: {'To': to, 'Type': movementType},
    );
  }

  // ── DELETE — always reverses whatever net stock effect this movement had
  // before removing it, so deleting never leaves stock counts wrong:
  //   only Checked Out          -> add the quantity back
  //   only Checked In           -> take the quantity back out
  //   both Checked Out & In     -> net zero, nothing to reverse
  static Future<void> deleteMovement(String id) async {
    final snap = await _movements.doc(id).get();
    if (!snap.exists) return;
    final m = InventoryMovement.fromDoc(snap);

    final withProductId = m.items.where((i) => i.productId.isNotEmpty).toList();
    if (withProductId.isNotEmpty && (m.isCheckedOut ^ m.isCheckedIn)) {
      final reverseIsAdd = m.isCheckedOut && !m.isCheckedIn; // was taken out -> give back
      final prodSnaps = await Future.wait(
        withProductId.map((i) => _products.doc(i.productId).get()),
      );
      final batch = _db.batch();
      for (var idx = 0; idx < withProductId.length; idx++) {
        final item = withProductId[idx];
        final snapP = prodSnaps[idx];
        if (!snapP.exists) continue;
        final currentQty = ((snapP.data() as Map<String, dynamic>)['quantity'] as num?)?.toInt() ?? 0;
        final newQty = reverseIsAdd ? currentQty + item.quantity : currentQty - item.quantity;
        batch.update(snapP.reference, {
          'quantity': newQty < 0 ? 0 : newQty,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      batch.delete(_movements.doc(id));
      await batch.commit();
    } else {
      await _movements.doc(id).delete();
    }
    clearCache();

    ActivityLogService.logDelete(
      module: _module,
      itemName: m.itemsSummary,
      data: {'Total Quantity': m.totalQuantity, 'Status': m.statusLabel},
    );
  }
}