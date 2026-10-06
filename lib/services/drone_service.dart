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
// FLEET: only drones flagged `in_master_list` (seeded from DRONE_LIST.xlsx via
// data/seed_drones.dart) are ever listed or selectable. There is no manual
// drone creation. IN/OUT date & time are ALWAYS taken from the server clock
// at the moment of the action — callers cannot supply or edit them — and the
// person is ALWAYS the logged-in user (CurrentUserService).
//
// IMPORTANT: The Reports screen's Drone IN/OUT counts are computed entirely
// from the `history` sub-collection (see report_service.dart). Every code
// path that sets or changes a drone's status MUST write a matching history
// record, or those changes will silently disappear from the monthly report
// even though the drone's own `status` field is correct. That's why both
// updateDrone() and updateStatus() below write a history entry in addition
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
        .where((d) => d.inMasterList)
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
              (d.uin ?? '').toLowerCase().contains(q) ||
              (d.gps ?? '').toLowerCase().contains(q) ||
              (d.linkType ?? '').toLowerCase().contains(q) ||
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
        .where((d) => d.inMasterList)
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
        if (!d.inMasterList) return false;
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
          'model': beforeData['model'],
        },
        after: {
          'status': drone.status,
          'pilot': statusChanged ? who : drone.pilotName,
          'updated_by': who,
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

  // ── UPDATE STATUS (IN / OUT movement) ──────────────────────────────────────
  // Date & time = server clock at the moment of the action (never typed).
  // Person       = logged-in user (never typed).
  Future<ApiResult<Drone>> updateStatus(
      String id,
      String status, {
        String? note,
        String? purpose,
        List<String> additionalProducts = const [],
        String? condition,
      }) async {
    try {
      final who = await CurrentUserService.getName();
      final localNow = DateTime.now(); // display only — stored value is server time
      final ts = FieldValue.serverTimestamp();
      final upperStatus = status.toUpperCase();
      final isOut = upperStatus == 'OUT';

      final currentDoc = await _drones.doc(id).get();
      if (!currentDoc.exists) return ApiResult.err('Drone not found.');
      final currentData = currentDoc.data() ?? {};
      final currentStatus =
          currentData['status']?.toString().toUpperCase() ?? 'IN';
      if (currentStatus == upperStatus) {
        return ApiResult.err(
            '${currentData['name'] ?? 'Drone'} is already $upperStatus.');
      }

      final updates = <String, dynamic>{
        'status': upperStatus,
        'has_movement': true,
        'last_updated': ts,
        'pilot_name': who,
        'updated_by': who,
        'additional_products': additionalProducts,
        'condition': condition,
        if (isOut) ...{
          'purpose': purpose,
          'checked_out_at': ts,
          'reminder_acknowledged': false,
        } else ...{
          'purpose': null,
          'checked_in_at': ts,
        },
      };

      // Run status update + history write atomically
      final batch = _db.batch();
      batch.update(_drones.doc(id), updates);
      batch.set(_history(id).doc(), {
        'drone_id': id,
        'pilot': who,
        'updated_by': who,
        'status': upperStatus,
        'notes': note,
        'purpose': isOut ? purpose : null,
        'additional_products': additionalProducts,
        'condition': condition,
        'timestamp': ts,
      });
      await batch.commit();

      final localTs = Timestamp.fromDate(localNow);
      final doc = Drone.fromMap(id, {
        ...currentData,
        ...updates,
        'last_updated': localTs,
        if (isOut) 'checked_out_at': localTs else 'checked_in_at': localTs,
      });
      clearCache();
      ActivityLogService.logEdit(
        module: 'Drones',
        itemName: (currentData['name'] as String?) ?? id,
        before: {'status': currentData['status']},
        after: {
          'status': upperStatus,
          'note': note,
          'used_by': who,
          if (isOut) 'purpose': purpose,
          if (additionalProducts.isNotEmpty)
            'additional_products': additionalProducts.join(', '),
          if (condition != null) 'condition': condition,
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

  // ── IN/OUT RECORDS (one per OUT→IN trip) ───────────────────────────────────
  // Every OUT starts a NEW record; the matching IN closes it. A closed record
  // is never touched again — the next OUT creates a second record for the
  // same drone. Derived from the drone's history, so existing data works too.
  Future<ApiResult<List<Drone>>> getMovementRecords(
      {bool forceRefresh = false}) async {
    try {
      // Every drone document (not only the current fleet list), so records
      // from drones registered earlier are included too.
      final allSnap = await _drones.get();
      final fleet = allSnap.docs
          .map((doc) => Drone.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
      final histRes = await getAllHistory();
      final byDrone = <String, List<DroneHistory>>{};
      for (final h in histRes.data ?? const <DroneHistory>[]) {
        byDrone.putIfAbsent(h.droneId, () => []).add(h);
      }
      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      final records = <Drone>[];
      for (final d in fleet.where(
              (d) => d.hasMovement || (byDrone[d.id] ?? const []).isNotEmpty)) {
        // Oldest first; entries with no timestamp (very old data) go first.
        final events = (byDrone[d.id] ?? []).toList()
          ..sort((a, b) => (a.timestamp ?? epoch).compareTo(b.timestamp ?? epoch));
        // Pair each OUT with the next IN.
        final trips = <List<DroneHistory?>>[]; // [out, in]
        for (final h in events) {
          if (h.status == 'OUT') {
            trips.add([h, null]);
          } else if (h.status == 'IN') {
            if (trips.isNotEmpty && trips.last[1] == null) {
              trips.last[1] = h;
            } else {
              trips.add([null, h]);
            }
          }
        }
        if (trips.isEmpty) {
          records.add(d);
          continue;
        }
        for (var i = 0; i < trips.length; i++) {
          final out = trips[i][0], inn = trips[i][1];
          final isLatest = i == trips.length - 1;
          if (isLatest) {
            // Latest record mirrors the live drone (status, current state).
            records.add(d.copyWith(
              tripId: out?.id ?? inn?.id,
              tripInId: inn?.id,
              checkedOutAt: out?.timestamp ?? d.checkedOutAt,
              // An open (OUT) record must NOT inherit the previous trip's IN time.
              checkedInAt: inn?.timestamp,
              clearCheckedInAt: inn == null,
            ));
          } else {
            final who = inn?.pilot ?? out?.pilot ?? d.pilotName;
            records.add(Drone(
              id: d.id,
              name: d.name,
              model: d.model,
              serialNumber: d.serialNumber,
              status: inn != null ? 'IN' : 'OUT',
              uin: d.uin,
              droneClass: d.droneClass,
              pilotName: who,
              category: d.category,
              gps: d.gps,
              linkType: d.linkType,
              inMasterList: d.inMasterList,
              hasMovement: true,
              additionalProducts: out?.additionalProducts ?? const [],
              condition: inn?.condition ?? out?.condition,
              branch: d.branch,
              purpose: out?.purpose,
              checkedOutAt: out?.timestamp,
              checkedInAt: inn?.timestamp,
              lastUpdated: inn?.timestamp ?? out?.timestamp,
              updatedBy: who,
              reminderAcknowledged: true,
              tripId: out?.id ?? inn?.id,
              tripInId: inn?.id,
              isPastTrip: true,
            ));
          }
        }
      }
      return ApiResult.ok(records);
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  // ── DELETE ONE IN/OUT RECORD ───────────────────────────────────────────────
  // Removes just this OUT→IN record (its history entries). The drone itself
  // stays in the fleet; its live status is recomputed from what remains.
  Future<ApiResult<bool>> deleteMovementRecord(Drone rec) async {
    try {
      final ids = <String>{
        if (rec.tripId != null) rec.tripId!,
        if (rec.tripInId != null) rec.tripInId!,
      };
      final batch = _db.batch();
      for (final hid in ids) {
        batch.delete(_history(rec.id).doc(hid));
      }
      await batch.commit();

      // Recompute the drone's live state from the remaining history.
      final snap = await _history(rec.id)
          .orderBy('timestamp', descending: true)
          .get();
      final rest = snap.docs.map((d) => d.data()).toList();
      final upd = <String, dynamic>{
        'last_updated': FieldValue.serverTimestamp(),
      };
      if (rest.isEmpty) {
        upd.addAll({
          'status': 'IN',
          'has_movement': false,
          'checked_out_at': FieldValue.delete(),
          'checked_in_at': FieldValue.delete(),
          'purpose': null,
          'additional_products': <String>[],
          'reminder_acknowledged': false,
        });
      } else {
        final last = rest.first;
        final lastStatus = (last['status']?.toString() ?? 'IN').toUpperCase();
        Timestamp? firstOf(String st) {
          for (final r in rest) {
            if ((r['status']?.toString().toUpperCase()) == st &&
                r['timestamp'] is Timestamp) {
              return r['timestamp'] as Timestamp;
            }
          }
          return null;
        }
        final outTs = firstOf('OUT');
        final inTs = firstOf('IN');
        upd.addAll({
          'status': lastStatus,
          'has_movement': true,
          'checked_out_at': outTs ?? FieldValue.delete(),
          'checked_in_at': inTs ?? FieldValue.delete(),
          if (lastStatus == 'IN') 'purpose': null,
        });
      }
      await _drones.doc(rec.id).update(upd);
      clearCache();
      ActivityLogService.logEdit(
        module: 'Drones',
        itemName: rec.name,
        before: {'record': 'IN/OUT record'},
        after: {'record': 'deleted'},
      );
      return ApiResult.ok(true);
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  /// Every drone document, including ones outside the current fleet list —
  /// used so old history entries can still show their drone's name.
  Future<ApiResult<List<Drone>>> getAllDroneDocs() async {
    try {
      final snap = await _drones.get();
      return ApiResult.ok(snap.docs
          .map((doc) => Drone.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList());
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