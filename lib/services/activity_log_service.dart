// lib/services/activity_log_service.dart
//
// Writes every screen visit AND every add/edit/delete action to Firestore
// so the admin can see, in real time, "whatever happens in the app" —
// who did it, in which module, to which item, and exactly what changed.
//
// Screen visits are captured automatically for every screen in the app
// via AccessRouteObserver (see lib/core/access/access_route_observer.dart)
// — no per-screen wiring needed.
//
// CRUD actions are logged with three named-parameter helpers, called from
// the relevant service right where the Firestore write already happens:
//
//   ActivityLogService.logAdd(module: 'Stock', itemName: productName, data: {...});
//
//   ActivityLogService.logEdit(
//     module: 'Stock',
//     itemName: productName,
//     before: {'Quantity': 10, 'Category': 'consumable'},
//     after:  {'Quantity': 25, 'Category': 'consumable'},
//   );
//   // -> only the fields that actually changed are recorded/shown; if
//   // nothing changed, nothing is written.
//
//   ActivityLogService.logDelete(module: 'Stock', itemName: productName, data: {...});
//
// Pass human-readable field labels ('Quantity', not 'quantity_val'). Values
// can be plain String/num/bool, or DateTime/Timestamp — both are converted
// to a readable date automatically before being stored, so callers never
// need to pre-format dates themselves.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/app_access_models.dart';

class ActivityLogService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final DateFormat _dateFmt = DateFormat('d MMM yyyy');

  static CollectionReference<Map<String, dynamic>> get _logs =>
      _db.collection('activity_logs');

  // Cached so we don't hit Firestore for the user doc on every nav frame.
  static String? _cachedUid;
  static String _cachedName = 'Unknown';
  static String _cachedRole = 'employee';

  static void setCurrentUser({
    required String uid,
    required String name,
    required String role,
  }) {
    _cachedUid = uid;
    _cachedName = name;
    _cachedRole = role;
  }

  static void clearCurrentUser() {
    _cachedUid = null;
    _cachedName = 'Unknown';
    _cachedRole = 'employee';
  }

  // ── Screen visits (unchanged — wired via AccessRouteObserver) ───────────
  static Future<void> logScreenVisit(String screenName) async {
    await _write(kind: 'screen_visit', label: screenName);
  }

  // ── Generic one-liner (kept for backwards compatibility — e.g. approve/
  // reject calls, or bulk operations that don't fit add/edit/delete
  // cleanly) ────────────────────────────────────────────────────────────
  static Future<void> logAction(String action, {String? module, String? details}) async {
    await _write(
      kind: 'action',
      label: module != null ? '[$module] $action' : action,
      module: module,
      details: details,
    );
  }

  // ── CREATE ───────────────────────────────────────────────────────────────
  /// Logs a new record being added to [module] (e.g. 'Stock', 'Drones',
  /// 'Purchases', 'Bills', 'Employees'). [itemName] identifies the record
  /// (product name, drone name, invoice number, employee name, etc).
  /// [data] is an optional snapshot of the fields it was created with,
  /// shown in the feed as the "new" values.
  static Future<void> logAdd({
    required String module,
    required String itemName,
    Map<String, dynamic>? data,
  }) async {
    final sanitized = data == null ? null : _sanitizeMap(data);
    final snapshot = sanitized == null
        ? null
        : sanitized.map((k, v) => MapEntry(k, {'old': null, 'new': v}));
    await _write(
      kind: 'action',
      action: 'added',
      module: module,
      itemName: itemName,
      label: 'Added $itemName',
      changes: snapshot,
    );
  }

  // ── UPDATE ───────────────────────────────────────────────────────────────
  /// Logs an edit to an existing record in [module]. Pass the record's
  /// field values [before] and [after] the edit, keyed by a human-readable
  /// label (e.g. 'Quantity', 'Category'). Only fields whose value actually
  /// changed are recorded — if nothing changed, nothing is written.
  static Future<void> logEdit({
    required String module,
    required String itemName,
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
  }) async {
    final diff = _diff(_sanitizeMap(before), _sanitizeMap(after));
    if (diff.isEmpty) return; // no real change — don't spam the feed
    await _write(
      kind: 'action',
      action: 'edited',
      module: module,
      itemName: itemName,
      label: 'Edited $itemName',
      changes: diff,
    );
  }

  // ── DELETE ───────────────────────────────────────────────────────────────
  /// Logs a record being removed from [module]. Pass the last known field
  /// values in [data] (read the doc right before deleting it) so the feed
  /// can show what was deleted, not just that "something" was.
  static Future<void> logDelete({
    required String module,
    required String itemName,
    Map<String, dynamic>? data,
  }) async {
    final sanitized = data == null ? null : _sanitizeMap(data);
    final snapshot = sanitized == null
        ? null
        : sanitized.map((k, v) => MapEntry(k, {'old': v, 'new': null}));
    await _write(
      kind: 'action',
      action: 'deleted',
      module: module,
      itemName: itemName,
      label: 'Deleted $itemName',
      changes: snapshot,
    );
  }

  // ── DELETE (manual, admin-triggered only) ─────────────────────────────
  // Nothing in this service ever auto-expires or auto-prunes a log entry.
  // The only way a row disappears from `activity_logs` is one of the two
  // methods below, and both are only ever called after the admin
  // explicitly confirms a delete in the UI (single row, or a bulk
  // "delete everything currently shown" sweep) — never automatically.

  /// Deletes a single activity log entry by its document id.
  static Future<void> deleteLog(String id) async {
    await _logs.doc(id).delete();
  }

  /// Deletes many activity log entries at once (e.g. "delete all of this
  /// week's Stock activity"). Batched in chunks of 450 — comfortably under
  /// Firestore's 500-writes-per-batch limit — so bulk deletes of any size
  /// still complete in as few round trips as possible.
  static Future<void> deleteLogs(List<String> ids) async {
    if (ids.isEmpty) return;
    const chunkSize = 450;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(i, i + chunkSize > ids.length ? ids.length : i + chunkSize);
      final batch = _db.batch();
      for (final id in chunk) {
        batch.delete(_logs.doc(id));
      }
      await batch.commit();
    }
  }


  // Kept only so any older call site still compiles; new code should call
  // logAdd/logEdit/logDelete above (named parameters) directly.
  @Deprecated('Use logAdd(module: ..., itemName: ..., data: ...) instead')
  static Future<void> logAdded(String module, String itemName, {Map<String, dynamic>? data}) =>
      logAdd(module: module, itemName: itemName, data: data);

  @Deprecated('Use logEdit(module: ..., itemName: ..., before: ..., after: ...) instead')
  static Future<void> logEdited(
      String module,
      String itemName, {
        required Map<String, dynamic> before,
        required Map<String, dynamic> after,
      }) =>
      logEdit(module: module, itemName: itemName, before: before, after: after);

  @Deprecated('Use logDelete(module: ..., itemName: ..., data: ...) instead')
  static Future<void> logDeleted(String module, String itemName, {Map<String, dynamic>? data}) =>
      logDelete(module: module, itemName: itemName, data: data);

  /// Field-by-field comparison of two flat, human-labeled maps. Returns
  /// only the entries whose value differs, each as {'old': ..., 'new': ...}.
  static Map<String, dynamic> _diff(
      Map<String, dynamic> before,
      Map<String, dynamic> after,
      ) {
    final out = <String, dynamic>{};
    final keys = {...before.keys, ...after.keys};
    for (final key in keys) {
      final oldValue = before[key];
      final newValue = after[key];
      if (oldValue != newValue) {
        out[key] = {'old': oldValue, 'new': newValue};
      }
    }
    return out;
  }

  /// Converts every value in [map] into something safe to store in
  /// Firestore and readable in the feed: DateTime/Timestamp become a
  /// formatted date string, nested maps/lists are sanitized recursively,
  /// and anything else that isn't a plain String/num/bool falls back to
  /// its toString(). This means callers can pass raw model values (a
  /// DateTime due-date, a Timestamp from Firestore, etc.) straight in
  /// without pre-formatting them.
  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) =>
      map.map((k, v) => MapEntry(k, _sanitizeValue(v)));

  static dynamic _sanitizeValue(dynamic v) {
    if (v == null || v is num || v is bool || v is String) return v;
    if (v is DateTime) return _dateFmt.format(v);
    if (v is Timestamp) return _dateFmt.format(v.toDate());
    if (v is List) return v.map(_sanitizeValue).toList();
    if (v is Map) {
      return v.map((key, val) => MapEntry(key.toString(), _sanitizeValue(val)));
    }
    return v.toString();
  }

  static Future<void> _write({
    required String kind,
    required String label,
    String? module,
    String? action,
    String? itemName,
    Map<String, dynamic>? changes,
    String? details,
  }) async {
    final uid = _cachedUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return; // nobody logged in (e.g. splash screen)
    try {
      await _logs.add({
        'userId': uid,
        'userName': _cachedName,
        'userRole': _cachedRole,
        'kind': kind,
        'label': label,
        'module': module,
        'action': action,
        'itemName': itemName,
        'changes': changes,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Never let logging failures break the app's actual functionality —
      // but DO surface the error in debug output. Silently swallowing this
      // completely (as before) made a genuine problem (e.g. Firestore
      // security rules rejecting the write, or being offline) look
      // identical, from the feed's point of view, to "nothing has
      // happened yet" — there was no way to tell the two apart.
      assert(() {
        // ignore: avoid_print
        print('ActivityLogService write failed ($kind/$action on $module): $e');
        return true;
      }());
    }
  }

  // Memoized broadcast streams — streamRecent()/streamForUser() are called
  // directly inside StreamBuilder(stream: ...) in the feed screen's
  // build(), so without caching, every rebuild (e.g. tapping a module
  // filter chip, which is a purely client-side filter) opened a brand-new
  // 200-doc listener and re-billed 200 reads. Caching means the listener
  // is opened once per distinct query and reused across rebuilds.
  //
  // .handleError below is the self-heal half of that: if the underlying
  // listener ever dies (dropped connection, rules denial, hot-reload
  // hiccup), the cache is cleared so the NEXT call opens a fresh listener
  // instead of every future screen visit hanging forever on a broadcast
  // stream that already finished and will never emit again.
  static final Map<int, Stream<List<ActivityLogModel>>> _recentStreams = {};
  static Stream<List<ActivityLogModel>> streamRecent({int limit = 60}) {
    return _recentStreams.putIfAbsent(
      limit,
          () => _logs
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(ActivityLogModel.fromDoc).toList())
          .handleError((Object e) {
        _recentStreams.remove(limit);
        throw e;
      })
          .asBroadcastStream(),
    );
  }

  static final Map<String, Stream<List<ActivityLogModel>>> _userStreams = {};
  static Stream<List<ActivityLogModel>> streamForUser(String uid, {int limit = 60}) {
    return _userStreams.putIfAbsent(
      uid,
          () => _logs
          .where('userId', isEqualTo: uid)
      // NOTE: deliberately no .orderBy('timestamp') here. Combining
      // where('userId', ...) with orderBy('timestamp') on a different
      // field requires a Firestore COMPOSITE INDEX. That index was
      // never created for this project, so this query used to throw
      // "[cloud_firestore/failed-precondition] The query requires an
      // index..." every time — which is why filtering the feed to a
      // single employee (or opening their standalone "View Activity"
      // screen) silently failed. A single-field where() needs no
      // extra index, so we sort/trim client-side instead — same
      // result, no Firebase console step required.
          .snapshots()
          .map((s) {
        final docs = s.docs.map(ActivityLogModel.fromDoc).toList()
          ..sort((a, b) {
            final at = a.timestamp;
            final bt = b.timestamp;
            if (at == null && bt == null) return 0;
            if (at == null) return 1; // pending server timestamp -> treat as newest-ish, sinks below confirmed ones
            if (bt == null) return -1;
            return bt.compareTo(at); // descending
          });
        return docs.length > limit ? docs.sublist(0, limit) : docs;
      })
          .handleError((Object e) {
        _userStreams.remove(uid);
        throw e;
      })
          .asBroadcastStream(),
    );
  }

  /// Live feed filtered to a single module (e.g. the Stock screen could
  /// show only Stock's own recent activity in a side panel). Same
  /// composite-index avoidance as streamForUser() above: no server-side
  /// orderBy, sort/trim client-side.
  static Stream<List<ActivityLogModel>> streamForModule(String module, {int limit = 200}) {
    return _logs
        .where('module', isEqualTo: module)
        .snapshots()
        .map((s) {
      final docs = s.docs.map(ActivityLogModel.fromDoc).toList()
        ..sort((a, b) {
          final at = a.timestamp;
          final bt = b.timestamp;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });
      return docs.length > limit ? docs.sublist(0, limit) : docs;
    });
  }
}