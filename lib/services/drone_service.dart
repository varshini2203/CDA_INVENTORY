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
  // Used by BranchDropdown (lib/widgets/drone_entry_form_fields.dart).
  // 'branchAll' is a sentinel meaning "no branch filter / not scoped to a
  // branch" — it is never itself written to a drone document's `branch`
  // field, only used as the dropdown's "All Branch" option value.
  static const String branchAll = 'ALL';
  static const List<String> branches = <String>['CDA Admin', 'CDA Ops'];

  // ── OVERDUE-DRONE REMINDER THRESHOLD ─────────────────────────────────────
  static const Duration overdueThreshold = Duration(hours: 4);

  // ── IN-MEMORY CACHE (full drone list, ordered by last_updated) ──────────
  // Every screen that lists drones needs the same "all drones, most recently
  // updated first" data — the status/category filters and search were
  // already applied in memory downstream in most cases, so there is no
  // correctness reason to hit Firestore again for them. This mirrors the
  // caching pattern already used in StockService: fetch once, reuse until a
  // write invalidates it, and never query Firestore again for filtering.
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
      // Base list now comes from the shared cache instead of a fresh
      // Firestore query every call. Status/category, which used to be
      // server-side `where()` clauses, are applied in memory below —
      // same result, since they were just narrowing an already
      // last_updated-ordered query.
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
          // Already ordered by last_updated desc from the cached fetch
            break;
        }
      }

      return ApiResult.ok(list);
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  // ── REAL-TIME STREAM (bonus — use in StreamBuilder if desired) ─────────────

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
  // A drone is "overdue" when it is currently OUT, has been for 4+ hours
  // (measured from checked_out_at, falling back to last_updated for older
  // records written before that field existed), and nobody has tapped
  // "Got it" for this OUT session yet (reminder_acknowledged == false).
  //
  // Note: like the rest of this file, this only re-evaluates when the
  // underlying Firestore query re-emits (i.e. on a write). It does not tick
  // every second/minute on its own — that's fine for the badge/list contents
  // (which only change on a status/ack write), the on-screen duration text
  // is recomputed per rebuild by the UI itself.
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

  /// Convenience projection of [overdueDronesStream] for badge counts (the
  /// AppBar bell + full-screen flyover on the dashboard).
  Stream<int> overdueDronesCountStream() =>
      overdueDronesStream().map((list) => list.length);

  /// Dismisses the overdue reminder for a single drone (the "Got it" button
  /// on the Drone Reminders screen) without requiring the drone to actually
  /// be marked IN. It re-arms automatically the next time this drone is
  /// marked OUT again, since updateStatus() resets this flag to false on
  /// every fresh OUT.
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
  // Writes the drone document AND an initial history entry reflecting the
  // status the drone was registered with. Without this, a drone added with
  // status 'OUT' (for example) would never show up as a "Drone OUT" event
  // in the monthly Reports page, since that report only reads the `history`
  // sub-collection, not the drone document's `status` field.

  Future<ApiResult<Drone>> addDrone(Drone drone, {DateTime? actionTime}) async {
    try {
      final data = drone.toFirestore();
      // actionTime lets the caller (Register New Drone screen) backdate the
      // IN/OUT status to when it actually started instead of "now". This
      // timestamp is what the 4-hour overdue-reminder countdown and the
      // monthly Drone IN/OUT report key off of, so setting it here once is
      // enough — nothing else needs to be touched afterwards.
      final ts =
      actionTime != null ? Timestamp.fromDate(actionTime) : FieldValue.serverTimestamp();
      data['created_at'] = ts;
      data['last_updated'] = ts;

      final status = drone.status.toUpperCase();
      // If the drone is being registered as OUT and the caller didn't
      // already set checkedOutAt explicitly on the Drone object, fall back
      // to actionTime so the overdue countdown starts from the chosen time.
      if (status == 'OUT' && drone.checkedOutAt == null) {
        data['checked_out_at'] = ts;
      }
      // Same idea for IN — stamps checked_in_at so the "In: ..." half of
      // the In/Out card display has something to show from day one.
      if (status == 'IN' && drone.checkedInAt == null) {
        data['checked_in_at'] = ts;
      }

      final ref = await _drones.add(data);

      // Log the initial status as a history entry so it's counted in reports.
      if (status.isNotEmpty) {
        await _history(ref.id).add({
          'drone_id': ref.id,
          'pilot': drone.pilotName ?? 'Unknown',
          'status': status,
          'notes': 'Initial registration',
          'timestamp': ts,
        });
      }

      final doc = drone.copyWith(
        id: ref.id,
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
          'pilot': drone.pilotName,
          'battery_level': drone.batteryLevel,
        },
      );
      return ApiResult.ok(doc);
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  // ── UPDATE DRONE ───────────────────────────────────────────────────────────
  // The Edit Drone screen allows changing the status field directly (rather
  // than via the dedicated toggle button that calls updateStatus()). If the
  // status actually changed, we log a history entry here too — otherwise
  // that IN/OUT transition is invisible to the monthly Reports page.

  Future<ApiResult<Drone>> updateDrone(Drone drone) async {
    try {
      // Fetch the current status BEFORE overwriting, so we can tell whether
      // this update represents an actual IN/OUT transition.
      final beforeDoc = await _drones.doc(drone.id).get();
      final beforeStatus =
      beforeDoc.data()?['status']?.toString().toUpperCase();

      final updates = drone.toFirestore();
      updates['last_updated'] = FieldValue.serverTimestamp();

      await _drones.doc(drone.id).update(updates);

      final afterStatus = drone.status.toUpperCase();
      if (afterStatus.isNotEmpty && afterStatus != beforeStatus) {
        await _history(drone.id).add({
          'drone_id': drone.id,
          'pilot': drone.pilotName ?? 'Unknown',
          'status': afterStatus,
          'notes': 'Status updated via edit',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      final doc = drone.copyWith(lastUpdated: DateTime.now());
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
          'pilot': drone.pilotName,
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
      // Delete history sub-collection first (Firestore doesn't cascade)
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

  // ── UPDATE STATUS ──────────────────────────────────────────────────────────
  // Also writes a history entry into the sub-collection. This is the
  // dedicated toggle-button path and was already correct.
  //
  // Additionally responsible for the bookkeeping the overdue-reminder
  // system depends on:
  //   - Marking OUT: stamps checked_out_at with this action's timestamp,
  //     stores `purpose`, and resets reminder_acknowledged to false so a
  //     fresh 4-hour countdown (and reminder eligibility) starts for this
  //     OUT session.
  //   - Marking IN: clears checked_out_at/purpose. overdueDronesStream()
  //     only queries status == 'OUT' anyway, so this is just hygiene for
  //     the next time the drone goes OUT.

  Future<ApiResult<Drone>> updateStatus(
      String id,
      String status, {
        String? note,
        int? batteryLevel,
        // Who actually performed this IN/OUT action (defaults to the
        // drone's currently assigned pilot_name if not supplied, kept for
        // backward compatibility with older call sites).
        String? performedBy,
        // Lets the person registering the entry backdate/forward-date it
        // instead of always stamping "now". Falls back to serverTimestamp()
        // when omitted.
        DateTime? actionTime,
        // Why the drone is being taken OUT (Training/Testing/Service/...).
        // Ignored when marking IN.
        String? purpose,
      }) async {
    try {
      final ts = actionTime != null
          ? Timestamp.fromDate(actionTime)
          : FieldValue.serverTimestamp();
      final upperStatus = status.toUpperCase();
      final isOut = upperStatus == 'OUT';

      final updates = <String, dynamic>{
        'status': upperStatus,
        'last_updated': ts,
        if (batteryLevel != null) 'battery_level': batteryLevel,
        if (performedBy != null && performedBy.isNotEmpty)
          'pilot_name': performedBy,
        if (isOut) ...{
          'purpose': purpose,
          'checked_out_at': ts,
          'reminder_acknowledged': false,
        } else ...{
          'purpose': null,
          // NOTE: checked_out_at is intentionally NOT cleared here anymore.
          // It's kept so the "In: ... · Out: ..." display on the Drone
          // In/Out card can still show the last OUT time even after the
          // drone has been brought back IN. overdueDronesStream() only
          // queries docs where status == 'OUT', so a stale checked_out_at
          // on an IN drone is never read for the overdue calculation.
          'checked_in_at': ts,
        },
      };

      // Fetch current pilot name for the history record
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

  // ── BACKFILL: derive missing In/Out timestamps from history ───────────
  // checked_in_at / checked_out_at are new fields — any drone whose last
  // IN or OUT toggle happened before this app update was shipped won't
  // have one (or both) of them set yet, so the "In: ... · Out: ..." card
  // display shows only whichever half it does have. This walks each such
  // drone's own history sub-collection (which has always been written on
  // every status change) and fills in the missing field from the most
  // recent matching entry there — no manual re-toggling required.
  //
  // Safe to call as often as you like: a drone with both fields already
  // set is skipped with zero extra reads, so once every drone has been
  // backfilled once this becomes a no-op pass over the in-memory list.
  // Returns the number of drone docs actually updated.
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
          // historyResult.data! is newest-first, so the first match for
          // each status is the most recent one.
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

  /// Combined Check-In / Check-Out history across every drone in the fleet,
  /// newest first. Used by the "Drone In/Out History" screen so staff can
  /// see who used which drone and when, without opening each drone one by
  /// one. Uses a Firestore `collectionGroup` query across every drone's
  /// `history` sub-collection, then sorts client-side (no `orderBy` on the
  /// query itself, so no composite/collection-group index needs to be
  /// created in the Firebase console for this to work).
  Future<ApiResult<List<DroneHistory>>> getAllHistory() async {
    try {
      final snap = await _db.collectionGroup('history').get();
      final list = snap.docs.map((doc) {
        // The parent of a history doc is drones/{droneId}/history, so its
        // parent's parent is the drones/{droneId} document itself.
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