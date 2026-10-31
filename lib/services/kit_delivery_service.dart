// lib/services/kit_delivery_service.dart
//
// Firestore backend for the "Kit Deliveries" module.
//
//   kit_deliveries/{kitId}
//
// Every write also (a) keeps the device reminder in sync
// (KitReminderService) and (b) records an entry in the Admin Activity Feed
// (ActivityLogService), exactly like the Drone Services module does.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/kit_templates.dart';
import '../models/kit_delivery.dart';
import 'activity_log_service.dart';
import 'current_user_service.dart';
import 'kit_reminder_service.dart';

class KitResult<T> {
  final T? data;
  final String? error;
  bool get success => error == null;

  KitResult.ok(this.data) : error = null;
  KitResult.err(this.error) : data = null;
}

class KitDeliveryService {
  KitDeliveryService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String module = 'Kit Deliveries';
  static const String branchAll = 'ALL';

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('kit_deliveries');

  // ── STREAMS ───────────────────────────────────────────────────────────────

  /// Every kit, soonest promised date first. Filtering (pending / overdue /
  /// search / branch) is done on the client so no composite Firestore index
  /// is needed.
  Stream<List<KitDelivery>> kitsStream() {
    return _col.orderBy('delivered_at', descending: true).snapshots().map(
          (snap) => snap.docs
          .map((d) => KitDelivery.fromFirestore(d))
          .toList(),
    );
  }

  /// Kits that are still missing parts.
  Stream<List<KitDelivery>> pendingKitsStream() => kitsStream().map((all) {
    final list = all.where((k) => k.isPending).toList();
    list.sort(_byPromisedDate);
    return list;
  });

  /// Pending kits whose promised day has arrived / passed. This drives the
  /// dashboard bell badge.
  Stream<List<KitDelivery>> dueKitsStream() =>
      pendingKitsStream().map((l) => l.where((k) => k.isDueOrOverdue).toList());

  Stream<int> dueCountStream() => dueKitsStream().map((l) => l.length);

  /// Same as [kitsStream] but also re-registers the device reminders every
  /// time the data changes. This is what makes a kit created on ANOTHER
  /// phone/PC remind this device too (scheduled notifications are local to
  /// each device). Listen to this once, near the top of the app.
  Stream<List<KitDelivery>> kitsStreamWithReminderSync() =>
      kitsStream().map((list) {
        // Fire and forget: reminders are best-effort and never block the UI.
        KitReminderService.instance.syncAll(list);
        return list;
      });

  /// Soonest promised date first; kits without a date last.
  static int _byPromisedDate(KitDelivery a, KitDelivery b) {
    final ap = a.promisedDate;
    final bp = b.promisedDate;
    if (ap == null && bp == null) return 0;
    if (ap == null) return 1;
    if (bp == null) return -1;
    return ap.compareTo(bp);
  }

  // ── READ ONE ──────────────────────────────────────────────────────────────

  Stream<KitDelivery?> kitStream(String id) => _col.doc(id).snapshots().map(
        (s) => s.exists ? KitDelivery.fromFirestore(s) : null,
  );

  // ── ADD ───────────────────────────────────────────────────────────────────

  Future<KitResult<KitDelivery>> addKit(KitDelivery kit) async {
    try {
      final who = await CurrentUserService.getName();
      final data = kit.copyWith(createdBy: who).toFirestore();
      data['created_at'] = FieldValue.serverTimestamp();
      data['updated_at'] = FieldValue.serverTimestamp();

      final ref = await _col.add(data);
      final saved =
      kit.copyWith(id: ref.id, createdBy: who, createdAt: DateTime.now());

      KitReminderService.instance.schedule(saved);

      ActivityLogService.logAdd(
        module: module,
        itemName: kit.customerName,
        data: {
          'Customer': kit.customerName,
          'Branch': kit.branch,
          'Invoice': kit.invoiceRef,
          'Parts pending': kit.pendingSummary.isEmpty ? 'None' : kit.pendingSummary,
          'Promised date': kit.promisedDate,
        },
      );
      return KitResult.ok(saved);
    } catch (e) {
      return KitResult.err(_error(e));
    }
  }

  // ── UPDATE (full edit) ────────────────────────────────────────────────────

  Future<KitResult<KitDelivery>> updateKit(
      KitDelivery before, KitDelivery after) async {
    try {
      // If the edit raised the delivered count of any part, keep the
      // hand-over history in step with it.
      final added = <String, int>{};
      for (final a in after.items) {
        final prev = before.items.where((x) => x.name == a.name);
        final was = prev.isEmpty ? 0 : prev.first.deliveredQty;
        if (a.deliveredQty > was) added[a.name] = a.deliveredQty - was;
      }
      final who = await CurrentUserService.getName();
      final handovers = added.isEmpty
          ? after.handovers
          : [
        ...after.handovers,
        KitHandover(
          at: DateTime.now(),
          by: who,
          note: 'Added while editing',
          quantities: added,
        ),
      ];

      // Re-derive completion so editing quantities can finish / re-open a kit.
      final fixed = after.copyWith(
        id: before.id,
        handovers: handovers,
        completedAt: after.isComplete
            ? (before.completedAt ?? DateTime.now())
            : null,
      );

      final data = fixed.toFirestore();
      // A re-opened kit must lose its completed_at.
      if (!fixed.isComplete) data['completed_at'] = null;
      data['updated_at'] = FieldValue.serverTimestamp();
      // created_by belongs to the original author — never overwrite it.
      data.remove('created_by');

      await _col.doc(before.id).update(data);

      KitReminderService.instance.schedule(fixed);

      ActivityLogService.logEdit(
        module: module,
        itemName: fixed.customerName,
        before: {
          'Customer': before.customerName,
          'Branch': before.branch,
          'Invoice': before.invoiceRef,
          'Parts pending': before.pendingSummary,
          'Promised date': before.promisedDate,
        },
        after: {
          'Customer': fixed.customerName,
          'Branch': fixed.branch,
          'Invoice': fixed.invoiceRef,
          'Parts pending': fixed.pendingSummary,
          'Promised date': fixed.promisedDate,
        },
      );
      return KitResult.ok(fixed);
    } catch (e) {
      return KitResult.err(_error(e));
    }
  }

  // ── HAND OVER PENDING PARTS ───────────────────────────────────────────────

  /// Records that [quantities] (part name -> qty) were handed over to the
  /// customer now. Quantities above what is still pending are clamped.
  /// Runs in a transaction so two people updating the same kit at the same
  /// time cannot overwrite each other.
  Future<KitResult<KitDelivery>> deliverItems(
      String kitId,
      Map<String, int> quantities, {
        String note = '',
        DateTime? newPromisedDate,
      }) async {
    try {
      final who = await CurrentUserService.getName();
      final ref = _col.doc(kitId);

      late KitDelivery before;
      late KitDelivery after;

      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw StateError('Kit not found');
        before = KitDelivery.fromFirestore(snap);

        final applied = <String, int>{};
        final newItems = before.items.map((item) {
          final want = quantities[item.name] ?? 0;
          if (want <= 0) return item;
          final give = want > item.pendingQty ? item.pendingQty : want;
          if (give <= 0) return item;
          applied[item.name] = give;
          return item.copyWith(deliveredQty: item.deliveredQty + give);
        }).toList();

        if (applied.isEmpty) throw StateError('Nothing to hand over');

        final handover = KitHandover(
          at: DateTime.now(),
          by: who,
          note: note.trim(),
          quantities: applied,
        );

        final updated = before.copyWith(
          items: newItems,
          handovers: [...before.handovers, handover],
        );
        // If parts are still left, the caller can postpone them to a new
        // date; a finished kit keeps its old date (nothing to remind).
        final DateTime? moved =
        (!updated.isComplete && newPromisedDate != null)
            ? newPromisedDate
            : null;
        after = updated.copyWith(
          completedAt: updated.isComplete ? DateTime.now() : null,
          promisedDate: moved,
        );

        final data = <String, dynamic>{
          'items': after.items.map((i) => i.toMap()).toList(),
          'handovers': after.handovers.map((h) => h.toMap()).toList(),
          'status': after.status,
          'pending_qty': after.totalPending,
          'completed_at': after.isComplete
              ? Timestamp.fromDate(after.completedAt!)
              : null,
          'updated_at': FieldValue.serverTimestamp(),
        };
        if (moved != null) {
          data['promised_date'] = Timestamp.fromDate(moved);
        }
        tx.update(ref, data);
      });

      // Reminder: stops automatically once the kit is complete.
      KitReminderService.instance.schedule(after);

      ActivityLogService.logEdit(
        module: module,
        itemName: after.customerName,
        before: {
          'Parts pending': before.pendingSummary,
          'Promised date': before.promisedDate,
        },
        after: {
          'Parts pending':
          after.pendingSummary.isEmpty ? 'None — kit complete' : after.pendingSummary,
          'Promised date': after.promisedDate,
        },
      );
      return KitResult.ok(after);
    } catch (e) {
      return KitResult.err(_error(e));
    }
  }

  // ── SNOOZE / RESCHEDULE ───────────────────────────────────────────────────

  /// Moves the promised date (e.g. "customer asked us to bring it next
  /// week"). The device reminder moves with it.
  Future<KitResult<KitDelivery>> setPromisedDate(
      KitDelivery kit, DateTime newDate) async {
    try {
      await _col.doc(kit.id).update({
        'promised_date': Timestamp.fromDate(newDate),
        'updated_at': FieldValue.serverTimestamp(),
      });
      final after = kit.copyWith(promisedDate: newDate);
      KitReminderService.instance.schedule(after);

      ActivityLogService.logEdit(
        module: module,
        itemName: kit.customerName,
        before: {'Promised date': kit.promisedDate},
        after: {'Promised date': newDate},
      );
      return KitResult.ok(after);
    } catch (e) {
      return KitResult.err(_error(e));
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  Future<KitResult<bool>> deleteKit(KitDelivery kit) async {
    try {
      await _col.doc(kit.id).delete();
      KitReminderService.instance.cancel(kit.id);

      ActivityLogService.logDelete(
        module: module,
        itemName: kit.customerName,
        data: {
          'Customer': kit.customerName,
          'Branch': kit.branch,
          'Invoice': kit.invoiceRef,
          'Parts pending': kit.pendingSummary,
        },
      );
      return KitResult.ok(true);
    } catch (e) {
      return KitResult.err(_error(e));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Default promised date for a new kit.
  static DateTime defaultPromisedDate([DateTime? from]) {
    final base = from ?? DateTime.now();
    final d = DateTime(base.year, base.month, base.day)
        .add(const Duration(days: kDefaultPendingPromiseDays));
    return d;
  }

  String _error(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'Permission denied. Add a Firestore rule for the '
              '"kit_deliveries" collection.';
        case 'unavailable':
          return 'Firestore is unavailable. Check your internet connection.';
        case 'not-found':
          return 'Kit not found.';
        default:
          return 'Firestore error (${e.code}): ${e.message}';
      }
    }
    if (e is StateError) return e.message;
    return e.toString();
  }
}