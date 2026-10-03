// lib/services/drone_service.dart
//
// Firebase Firestore backend — drop-in replacement for the REST DroneService.
// All public method signatures are preserved so the UI screens need zero changes
// except that IDs are now Strings instead of ints.
//
// Firestore structure:
//   drones/                        ← collection
//     {droneId}/                   ← document
//       history/                   ← sub-collection
//         {historyId}              ← document
//
// IMPORTANT: The Reports screen's Drone IN/OUT counts are computed entirely
// from the `history` sub-collection (see report_service.dart). Every code
// path that sets or changes a drone's status MUST write a matching history
// record, or those changes will silently disappear from the monthly report
// even though the drone's own `status` field is correct. That's why both
// addDrone() and updateDrone() below now write a history entry in addition
// to updateStatus().

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/drone.dart';
import 'activity_log_service.dart';
import 'current_user_service.dart';

// ─── API RESULT WRAPPER (unchanged) ──────────────────────────────────────────

class ApiResult<T> {
  final T? data;
  final String? error;
  bool get success => error == null;

  ApiResult.ok(this.data) : error = null;
  ApiResult.err(this.error) : data = null;
}

// ─── SERVICE ──────────────────────────────────────────────────────────────────

class DroneService {
  final FirebaseFirestore _db;

  DroneService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  // Convenience references
  CollectionReference<Map<String, dynamic>> get _drones =>
      _db.collection('drones');

  CollectionReference<Map<String, dynamic>> _history(String droneId) =>
      _drones.doc(droneId).collection('history');

  // ── BRANCH OPTIONS ───────────────────────────────────────────────────────
  static const String branchAll = 'ALL';
  static const List<String> branches = <String>['CDA Admin', 'CDA Ops'];

  // ── OVERDUE-DRONE REMINDER THRESHOLD ─────────────────────────────────────
  static const Duration overdueThreshold = Duration(hours: 4);

  // ── IN-MEMORY CACHE (full drone list, ordered by last_updated) ──────────
  static List<Drone>? _dronesCache;

  static void clearCache() {
    _dronesCache = null;
  }

  Future<List<Drone>> _fetchAllDrones({bool forceRefresh = false}) async {
    if (!forceRefresh && _dronesCache != null) return _dronesCache!;
    final snapshot =
    await _drones.orderBy('last_updated', descending: true).get();
    final list = snapshot.docs
        .map((doc) => Drone.fromFirestore(
        doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();
    _dronesCache = list;
    return list;
  }

  // ── GET ALL DRONES ─────────────────────────────────────────────────────────

  Future<ApiResult<List<Drone>>> getDrones({
    String? search,
    String? status,
    String? category,
    String? sort,
    bool forceRefresh = false,
  }) async {
    try {
      List<Drone> list = await _fetchAllDrones(forceRefresh: forceRefresh);

      if (status != null && status != 'ALL') {
        list = list.where((d) => d.status == status).toList();
      }
      if (category != null && category.isNotEmpty) {
        list = list.where((d) => d.category == category).toList();
      }

      // Client-side search (Firestore doesn't support full-text natively)
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        list = list.where((d) {
          return d.name.toLowerCase().contains(q) ||
              d.model.toLowerCase().contains(q) ||
              d.serialNumber.toLowerCase().contains(q) ||
              (d.pilotName ?? '').toLowerCase().contains(q);
        }).toList();
      }

      // Client-side sort
      if (sort != null) {
        switch (sort) {
          case 'name_asc':
            list.sort((a, b) => a.name.compareTo(b.name));
            break;
          case 'name_desc':
            list.sort((a, b) => b.name.compareTo(a.name));
            break;
          case 'battery_asc':
            list.sort((a, b) => a.batteryLevel.compareTo(b.batteryLevel));
            break;
          case 'battery_desc':
            list.sort((a, b) => b.batteryLevel.compareTo(a.batteryLevel));
            break;
          case 'recent':
          default:
            break;
        }
      }

      return ApiResult.ok(list);
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  // ── REAL-TIME STREAM ───────────────────────────────────────────────────────

  Stream<List<Drone>> dronesStream({String? status}) {
    Query<Map<String, dynamic>> query = _drones;
    if (status != null && status != 'ALL') {
      query = query.where('status', isEqualTo: status);
    }
    query = query.orderBy('last_updated', descending: true);
    return query.snapshots().map((snap) => snap.docs
        .map((doc) => Drone.fromFirestore(
        doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList());
  }

  // ── OVERDUE DRONES (Drone Reminders screen + bell/flyover) ─────────────────
  Stream<List<Drone>> overdueDronesStream() {
    return _drones
        .where('status', isEqualTo: 'OUT')
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      final list = snap.docs
          .map((doc) => Drone.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>))
          .where((d) {
        if (d.reminderAcknowledged) return false;
        final since = d.checkedOutAt ?? d.lastUpdated;
        if (since == null) return false;
        return now.difference(since) >= overdueThreshold;
      }).toList();

      // Longest-overdue first.
      list.sort((a, b) {
        final at = a.checkedOutAt ?? a.lastUpdated ?? now;
        final bt = b.checkedOutAt ?? b.lastUpdated ?? now;
        return at.compareTo(bt);
      });
      return list;
    });
  }

  Stream<int> overdueDronesCountStream() =>
      overdueDronesStream().map((list) => list.length);

  Future<ApiResult<bool>> acknowledgeReminder(String droneId) async {
    try {
      await _drones.doc(droneId).update({'reminder_acknowledged': true});
      clearCache();
      return ApiResult.ok(true);
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  // ── ADD DRONE ──────────────────────────────────────────────────────────────
  Future<ApiResult<Drone>> addDrone(Drone drone, {DateTime? actionTime}) async {
    try {
      // Logged-in user — auto-fetched, never typed. Saved with the record.
      final who = await CurrentUserService.getName();
      final data = drone.toFirestore();
      data['added_by'] = who;
      data['updated_by'] = who;
      data['pilot_name'] = who;

      final ts =
      actionTime != null ? Timestamp.fromDate(actionTime) : FieldValue.serverTimestamp();
      data['created_at'] = ts;
      data['last_updated'] = ts;

      final status = drone.status.toUpperCase();
      if (status == 'OUT' && drone.checkedOutAt == null) {
        data['checked_out_at'] = ts;
      }
      if (status == 'IN' && drone.checkedInAt == null) {
        data['checked_in_at'] = ts;
      }

      final ref = await _drones.add(data);

      // Log the initial status as a history entry so it's counted in reports.
      if (status.isNotEmpty) {
        await _history(ref.id).add({
          'drone_id': ref.id,
          'pilot': who,
          'added_by': who,
          'status': status,
          'notes': 'Initial registration',
          'timestamp': ts,
        });
      }

      final doc = drone.copyWith(
        id: ref.id,
        addedBy: who,
        updatedBy: who,
        pilotName: who,
        lastUpdated: actionTime ?? DateTime.now(),
        checkedOutAt: status == 'OUT' ? (drone.checkedOutAt ?? actionTime) : drone.checkedOutAt,
        checkedInAt: status == 'IN' ? (drone.checkedInAt ?? actionTime) : drone.checkedInAt,
      );
      clearCache();
      ActivityLogService.logAdd(
        module: 'Drones',
        itemName: drone.name,
        data: {
          'model': drone.model,
          'serial_number': drone.serialNumber,
          'status': drone.status,
          'pilot': who,
          'added_by': who,
          'battery_level': drone.batteryLevel,
        },
      );
      return ApiResult.ok(doc);
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  // ── UPDATE DRONE ───────────────────────────────────────────────────────────
  Future<ApiResult<Drone>> updateDrone(Drone drone) async {
    try {
      final beforeDoc = await _drones.doc(drone.id).get();
      final beforeStatus =
      beforeDoc.data()?['status']?.toString().toUpperCase();

      // Logged-in user — auto-fetched, never typed.
      final who = await CurrentUserService.getName();
      final updates = drone.toFirestore();
      updates['last_updated'] = FieldValue.serverTimestamp();
      // added_by is set once at registration — never overwrite it on edit.
      updates.remove('added_by');
      updates['updated_by'] = who;
      // "Used by" only changes when the IN/OUT status really changes.
      final statusChanged =
          drone.status.toUpperCase() != (beforeStatus ?? '');
      if (statusChanged) {
        updates['pilot_name'] = who;
      } else {
        updates.remove('pilot_name');
      }

      await _drones.doc(drone.id).update(updates);

      final afterStatus = drone.status.toUpperCase();
      if (afterStatus.isNotEmpty && afterStatus != beforeStatus) {
        await _history(drone.id).add({
          'drone_id': drone.id,
          'pilot': who,
          'updated_by': who,
          'status': afterStatus,
          'notes': 'Status updated via edit',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      final doc = drone.copyWith(
        lastUpdated: DateTime.now(),
        updatedBy: who,
        pilotName: statusChanged ? who : drone.pilotName,
      );
      clearCache();
      final beforeData = beforeDoc.data() ?? {};
      ActivityLogService.logEdit(
        module: 'Drones',
        itemName: drone.name,
        before: {
          'status': beforeData['status'],
          'pilot': beforeData['pilot_name'],
          'battery_level': beforeData['battery_level'],
          'model': beforeData['model'],
        },
        after: {
          'status': drone.status,
          'pilot': statusChanged ? who : drone.pilotName,
          'updated_by': who,
          'battery_level': drone.batteryLevel,
          'model': drone.model,
        },
      );
      return ApiResult.ok(doc);
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  // ── DELETE DRONE ───────────────────────────────────────────────────────────

  Future<ApiResult<bool>> deleteDrone(String id) async {
    try {
      final droneDoc = await _drones.doc(id).get();
      final droneData = droneDoc.data() ?? {};
      final historySnap = await _history(id).get();
      final batch = _db.batch();
      for (final doc in historySnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_drones.doc(id));
      await batch.commit();
      clearCache();
      ActivityLogService.logDelete(
        module: 'Drones',
        itemName: (droneData['name'] as String?) ?? id,
        data: {
          'model': droneData['model'],
          'status': droneData['status'],
        },
      );
      return ApiResult.ok(true);
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  // ── UPDATE STATUS (IN / OUT toggle) ────────────────────────────────────────
  Future<ApiResult<Drone>> updateStatus(
      String id,
      String status, {
        String? note,
        int? batteryLevel,
        String? performedBy, // ignored — always replaced by the logged-in user
        DateTime? actionTime,
        String? purpose,
      }) async {
    try {
      // Always the logged-in user — any caller-supplied name is ignored so
      // a name can never be typed/spoofed.
      performedBy = await CurrentUserService.getName();
      final ts = actionTime != null
          ? Timestamp.fromDate(actionTime)
          : FieldValue.serverTimestamp();
      final upperStatus = status.toUpperCase();
      final isOut = upperStatus == 'OUT';

      final updates = <String, dynamic>{
        'status': upperStatus,
        'last_updated': ts,
        if (batteryLevel != null) 'battery_level': batteryLevel,
        'pilot_name': performedBy,
        'updated_by': performedBy,
        if (isOut) ...{
          'purpose': purpose,
          'checked_out_at': ts,
          'reminder_acknowledged': false,
        } else ...{
          'purpose': null,
          'checked_in_at': ts,
        },
      };

      final currentDoc = await _drones.doc(id).get();
      final currentData = currentDoc.data() ?? {};
      final pilot = (performedBy != null && performedBy.isNotEmpty)
          ? performedBy
          : (currentData['pilot_name']?.toString() ?? 'Unknown');

      // Run status update + history write atomically
      final batch = _db.batch();
      batch.update(_drones.doc(id), updates);
      batch.set(_history(id).doc(), {
        'drone_id': id,
        'pilot': pilot,
        'updated_by': pilot,
        'status': upperStatus,
        'notes': note,
        'purpose': isOut ? purpose : null,
        'timestamp': ts,
      });
      await batch.commit();

      final doc = Drone.fromMap(id, {...currentData, ...updates});
      clearCache();
      ActivityLogService.logEdit(
        module: 'Drones',
        itemName: (currentData['name'] as String?) ?? id,
        before: {'status': currentData['status']},
        after: {
          'status': upperStatus,
          'note': note,
          'used_by': pilot,
          if (isOut) 'purpose': purpose,
        },
      );
      return ApiResult.ok(doc);
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  // ── BACKFILL: derive missing In/Out timestamps from history ───────────────
  Future<int> backfillCheckInOutTimestamps(List<Drone> drones) async {
    var updatedCount = 0;
    for (final d in drones) {
      if (d.checkedInAt != null && d.checkedOutAt != null) continue;
      try {
        final historyResult = await getHistory(d.id);
        if (!historyResult.success) continue;

        DateTime? inAt = d.checkedInAt;
        DateTime? outAt = d.checkedOutAt;
        for (final h in historyResult.data!) {
          if (inAt == null && h.status == 'IN' && h.timestamp != null) {
            inAt = h.timestamp;
          }
          if (outAt == null && h.status == 'OUT' && h.timestamp != null) {
            outAt = h.timestamp;
          }
          if (inAt != null && outAt != null) break;
        }

        final updates = <String, dynamic>{};
        if (inAt != null && d.checkedInAt == null) {
          updates['checked_in_at'] = Timestamp.fromDate(inAt);
        }
        if (outAt != null && d.checkedOutAt == null) {
          updates['checked_out_at'] = Timestamp.fromDate(outAt);
        }
        if (updates.isNotEmpty) {
          await _drones.doc(d.id).update(updates);
          updatedCount++;
        }
      } catch (_) {
        // Best-effort — skip this drone and keep going with the rest.
      }
    }
    if (updatedCount > 0) clearCache();
    return updatedCount;
  }

  // ── COMPLETE MAINTENANCE ───────────────────────────────────────────────────

  Future<ApiResult<Drone>> completeMaintenance(String id,
      {DateTime? nextDue}) async {
    try {
      await _drones.doc(id).update({
        'maintenance_due':
        nextDue != null ? Timestamp.fromDate(nextDue) : null,
        'last_updated': FieldValue.serverTimestamp(),
      });
      final doc = await _drones.doc(id).get();
      clearCache();
      return ApiResult.ok(Drone.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>));
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  // ── GET HISTORY ────────────────────────────────────────────────────────────

  Future<ApiResult<List<DroneHistory>>> getHistory(String droneId) async {
    try {
      final snap = await _history(droneId)
          .orderBy('timestamp', descending: true)
          .get();
      final list = snap.docs
          .map((doc) => DroneHistory.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>, droneId))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  /// Combined Check-In / Check-Out history across every drone, newest first.
  Future<ApiResult<List<DroneHistory>>> getAllHistory() async {
    try {
      final snap = await _db.collectionGroup('history').get();
      final list = snap.docs.map((doc) {
        final droneId = doc.reference.parent.parent?.id ?? '';
        return DroneHistory.fromFirestore(
            doc as DocumentSnapshot<Map<String, dynamic>>, droneId);
      }).toList()
        ..sort((a, b) {
          final at = a.timestamp;
          final bt = b.timestamp;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at); // newest first
        });
      return ApiResult.ok(list);
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  // ── SERVER STATS ───────────────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> getServerStats() async {
    try {
      final drones = await _fetchAllDrones();
      final inCount = drones.where((d) => d.status == 'IN').length;
      final outCount = drones.where((d) => d.status == 'OUT').length;
      return ApiResult.ok({
        'total': drones.length,
        'in': inCount,
        'out': outCount,
      });
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  // ── ERROR HELPER ───────────────────────────────────────────────────────────

  String _firestoreError(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'Permission denied. Check your Firestore security rules.';
        case 'unavailable':
          return 'Firestore is currently unavailable. Check your internet connection.';
        case 'not-found':
          return 'Document not found.';
        default:
          return 'Firestore error (${e.code}): ${e.message}';
      }
    }
    return 'Error: $e';
  }
}