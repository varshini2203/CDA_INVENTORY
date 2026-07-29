// lib/services/access_control_service.dart
//
// Central place for everything related to the new "Admin full control"
// feature:
//   - what happens the moment ANY user logs in (creates/refreshes their
//     access record + fires an admin notification)
//   - admin approving/denying/changing access
//   - streams the admin screens use to show live data
//
// Firestore layout added by this feature:
//
//   users/{uid}
//       ...existing fields...
//       accessLevel   : 'none' | 'viewer' | 'editor'
//       accessStatus  : 'pending' | 'approved' | 'denied'
//       approvedBy    : admin uid (nullable)
//       approvedAt    : Timestamp (nullable)
//       lastLogin     : Timestamp
//       isOnline      : bool
//
//   admin_notifications/{id}
//       type           : 'access_request' | 'info'
//       userId, userName, userEmail
//       message
//       requestedAccess: 'viewer' | 'editor'
//       status         : 'pending' | 'approved' | 'denied' | 'na'
//       read           : bool
//       createdAt      : Timestamp
//
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_access_models.dart';
import 'activity_log_service.dart';
import 'gamification_service.dart';

/// Thrown by [AccessControlService.onUserLoggedIn] when the signed-in
/// Firebase Auth account belongs to an employee the admin has removed.
/// The Auth account itself still exists (we can't disable it client-side),
/// so callers must catch this, sign the user back out immediately, and
/// show a clear "your account was removed" message instead of letting
/// them anywhere near the app.
class AccountRemovedException implements Exception {
  const AccountRemovedException();
  @override
  String toString() => 'This account has been removed by the admin.';
}

/// Wraps a source [Stream] so that every NEW listener immediately
/// receives the most recently emitted value (or error) before it
/// starts receiving further live updates.
///
/// Plain `Stream.asBroadcastStream()` / `StreamController.broadcast()`
/// do NOT do this: a broadcast stream only ever delivers events that
/// occur strictly after `.listen()` is called. That is exactly why the
/// Admin pages in this app got stuck on their loading indicator forever
/// after a repeat visit — see the long comment above the `Streams`
/// section in [AccessControlService]. `_ReplayStream` closes that gap
/// with the same guarantee an rxdart `BehaviorSubject` provides, using
/// only `dart:async`.
class _ReplayStream<T> {
  _ReplayStream(Stream<T> source, {void Function()? onError}) {
    _sub = source.listen(
          (value) {
        _hasValue = true;
        _hasError = false;
        _lastValue = value;
        _controller.add(value);
      },
      onError: (Object e, StackTrace st) {
        _hasError = true;
        _hasValue = false;
        _lastError = e;
        _lastStackTrace = st;
        onError?.call();
        _controller.addError(e, st);
      },
    );
  }

  late final StreamSubscription<T> _sub;

  // Internal fan-out: one always-on broadcast controller fed by the
  // single real Firestore subscription above. `stream` (below) is what
  // screens actually receive, and is built fresh — with an immediate
  // replay — for every listener via Stream.multi.
  final StreamController<T> _controller = StreamController<T>.broadcast();

  T? _lastValue;
  bool _hasValue = false;
  Object? _lastError;
  StackTrace? _lastStackTrace;
  bool _hasError = false;

  /// The stream to hand out to callers/StreamBuilders. Every listener —
  /// first or hundredth, immediate or five minutes later, and whether
  /// one or several screens are listening concurrently — gets the last
  /// known value/error replayed before anything new arrives.
  ///
  /// NOTE: this deliberately does NOT use an `async*` generator. A
  /// generator function returns a single-subscription stream, so a
  /// second concurrent listener (e.g. EmployeeAccessScreen and
  /// ActivityFeedScreen both calling `streamAllEmployees()` at the same
  /// time) would crash with "Stream has already been listened to."
  /// `Stream.multi` runs its callback once per listener while still
  /// letting any number of listeners attach — the correct primitive for
  /// a shared, replaying broadcast stream.
  Stream<T> get stream => Stream<T>.multi((controller) {
    if (_hasValue) {
      controller.add(_lastValue as T);
    } else if (_hasError) {
      controller.addError(_lastError!, _lastStackTrace!);
    }
    final sub = _controller.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = sub.cancel;
  }, isBroadcast: true);
}

class AccessControlService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  static CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('admin_notifications');

  // ──────────────────────────────────────────────────────────────
  // Called right after every successful sign-in (any role, any
  // screen). Makes sure the user has an access record and — for
  // employees — notifies the admin that someone wants in.
  // Returns the resolved AppUserAccess so the caller can decide
  // where to route the user next.
  // ──────────────────────────────────────────────────────────────
  static Future<AppUserAccess> onUserLoggedIn({
    required String uid,
    required String name,
    required String email,
    required String role, // 'admin' | 'employee'
    // Callers that already performed a users/{uid} read for this exact
    // sign-in (AuthService.loginWithRole() / getCurrentUserRoleAndProfile())
    // pass that result straight in here so this method doesn't pay for a
    // second read of the same document a moment later. Leave both null
    // (the default) to fall back to reading it here, unchanged from before.
    Map<String, dynamic>? existingData,
    bool? existingDataFound,
  }) async {
    final docRef = _users.doc(uid);

    final bool snapExists;
    final Map<String, dynamic> data;
    if (existingDataFound != null) {
      snapExists = existingDataFound;
      data = existingData ?? {};
    } else {
      final snap = await docRef.get();
      snapExists = snap.exists;
      data = snap.data() ?? {};
    }

    // Requirement: log every employee/admin login.
    await logLogin(uid: uid, email: email);

    // A missing doc could mean "never logged in before" OR "admin removed
    // this employee" — those must NOT be treated the same way, or removal
    // would silently self-heal back into a fresh pending account on the
    // employee's next login.
    if (!snapExists && role != 'admin' && await wasRemoved(uid)) {
      throw const AccountRemovedException();
    }

    final isAdmin = role == 'admin';

    // A doc can already exist (e.g. created by register()) without ever
    // having had accessLevel/accessStatus set — treat that the same as a
    // brand new account so nobody accidentally starts out un-tracked.
    final needsInit = !snapExists ||
        data['accessLevel'] == null ||
        data['accessStatus'] == null;

    // Build the post-write field set locally so we don't have to pay for a
    // second Firestore read just to get back the values we already know we
    // just wrote (serverTimestamp() fields resolve to null client-side
    // until the server round-trips anyway, and nothing downstream branches
    // on lastLogin/approvedAt — only on role/accessLevel/accessStatus).
    late final Map<String, dynamic> merged;

    if (needsInit) {
      final writeData = {
        'name': name,
        'email': email,
        'role': role,
        'accessLevel': isAdmin ? 'editor' : 'none',
        'accessStatus': isAdmin ? 'approved' : 'pending',
        'lastLogin': FieldValue.serverTimestamp(),
        'isOnline': true,
      };
      await docRef.set(writeData, SetOptions(merge: true));
      merged = {...data, ...writeData};

      if (!isAdmin) {
        await _createLoginNotification(
          uid: uid,
          name: name,
          email: email,
          message: '$name just logged in for the first time and is requesting access.',
        );
      }
    } else {
      final existingStatus = accessStatusFromString(data['accessStatus'] as String?);

      final writeData = {
        'lastLogin': FieldValue.serverTimestamp(),
        'isOnline': true,
      };
      await docRef.set(writeData, SetOptions(merge: true));
      merged = {...data, ...writeData};

      // Every login by a non-admin who isn't already approved re-notifies
      // the admin (covers first-ever login and any later attempt while
      // still pending/denied).
      if (!isAdmin && existingStatus != AccessStatus.approved) {
        await _createLoginNotification(
          uid: uid,
          name: name,
          email: email,
          message: '$name just logged in and is waiting for access.',
        );
      }
    }

    // Ensure every authenticated user has a gamification profile,
    // right here — the single choke point every login path (Admin
    // login, Employee login, and the splash-screen auto-login for an
    // already-signed-in session) already passes through. This means a
    // profile is created the moment someone logs in, without them ever
    // needing to open the Gamification tab. Best-effort: gamification
    // is a secondary feature, so a failure here must never block or
    // fail the actual login.
    try {
      await GamificationService.ensureProfile(
        name: name,
        branch: (merged['branch'] as String?) ?? '',
      );
    } catch (_) {}

    return AppUserAccess.fromMap(uid, merged);
  }

  static Future<void> markOffline(String uid) async {
    try {
      await _users.doc(uid).set({'isOnline': false}, SetOptions(merge: true));
    } catch (_) {
      // best-effort only
    }
  }

  /// Public entry point for creating the "someone wants access" admin
  /// notification. Called from AuthService.register() right after account
  /// creation (spec requirement 1: notify at registration, not just at
  /// first login) and internally from onUserLoggedIn() as a fallback for
  /// any account that reaches login without ever going through register().
  static Future<void> notifyAdminOfNewRequest({
    required String uid,
    required String name,
    required String email,
  }) {
    return _createLoginNotification(
      uid: uid,
      name: name,
      email: email,
      message: '$name just registered and is requesting access.',
    );
  }

  static Future<void> _createLoginNotification({
    required String uid,
    required String name,
    required String email,
    required String message,
  }) async {
    await _notifications.add({
      'type': 'access_request',
      'userId': uid,
      'userName': name,
      'userEmail': email,
      'message': message,
      'requestedAccess': 'viewer',
      'status': 'pending',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ──────────────────────────────────────────────────────────────
  // Admin actions
  // ──────────────────────────────────────────────────────────────
  static Future<void> approveAccess({
    required String userId,
    required AccessLevel level,
    String? notificationId,
  }) async {
    final admin = _auth.currentUser;
    await _users.doc(userId).set({
      'accessLevel': accessLevelToString(level),
      // NOTE: 'role' (admin/employee) is intentionally left untouched here.
      // It must never be set to the access level (viewer/editor) — that
      // value already lives in 'accessLevel' above. Overwriting 'role'
      // broke every role=='employee' query (Manage Employees, login
      // routing, etc.) the moment an employee got approved.
      'accessStatus': 'approved',
      'status': 'approved', // mirrors spec's users.status field
      'approvedBy': admin?.email ?? admin?.uid,
      'approvedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (notificationId != null) {
      await _notifications.doc(notificationId).set({
        'status': 'approved',
        'requestedAccess': accessLevelToString(level),
        'read': true,
      }, SetOptions(merge: true));
    }

    // NOTE: intentionally no _logActivity() call here — ActivityLogService
    // .logAdd() below already writes a well-formed feed entry for this
    // exact approval. Calling both wrote two rows for one click (one
    // readable, one showing as a blank "Unknown —" row).
    final userDoc = await _users.doc(userId).get();
    ActivityLogService.logAdd(
      module: 'Employees',
      itemName: (userDoc.data()?['name'] as String?) ??
          (userDoc.data()?['email'] as String?) ?? userId,
      data: {'access_level': accessLevelToString(level), 'status': 'approved'},
    );
  }

  /// Reject an access request (Phase 4). Distinct from [removeEmployee]:
  /// the employee's account and history stay, they just can't get in
  /// unless the admin later re-approves them from Manage Employees.
  static Future<void> rejectAccess({
    required String userId,
    String? notificationId,
  }) async {
    final admin = _auth.currentUser;
    await _users.doc(userId).set({
      'accessLevel': 'none',
      'accessStatus': 'rejected',
      'status': 'rejected', // mirrors spec's users.status field
      'approvedBy': admin?.email ?? admin?.uid,
      'approvedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (notificationId != null) {
      await _notifications.doc(notificationId).set({
        'status': 'rejected',
        'read': true,
      }, SetOptions(merge: true));
    }

    // NOTE: intentionally no _logActivity() call here — see the matching
    // comment in approveAccess() above.
    final userDoc = await _users.doc(userId).get();
    ActivityLogService.logEdit(
      module: 'Employees',
      itemName: (userDoc.data()?['name'] as String?) ??
          (userDoc.data()?['email'] as String?) ?? userId,
      before: {'status': 'pending'},
      after: {'status': 'rejected'},
    );
  }

  /// Back-compat alias — older call sites (and the notification card that
  /// still says "Deny") can keep calling this name.
  static Future<void> denyAccess({
    required String userId,
    String? notificationId,
  }) =>
      rejectAccess(userId: userId, notificationId: notificationId);

  /// Promote/demote an already-approved employee, or revoke them back to
  /// no access, from the Manage Employees screen.
  static Future<void> setAccessLevel({
    required String userId,
    required AccessLevel level,
  }) async {
    final adminUid = _auth.currentUser?.uid;
    final beforeDoc = await _users.doc(userId).get();
    final beforeLevel = beforeDoc.data()?['accessLevel'];
    await _users.doc(userId).set({
      'accessLevel': accessLevelToString(level),
      'accessStatus':
      level == AccessLevel.none ? 'rejected' : 'approved',
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    ActivityLogService.logEdit(
      module: 'Employees',
      itemName: (beforeDoc.data()?['name'] as String?) ??
          (beforeDoc.data()?['email'] as String?) ?? userId,
      before: {'access_level': beforeLevel},
      after: {'access_level': accessLevelToString(level)},
    );
  }

  /// Phase 4 "Remove Employee". We can't disable another user's Firebase
  /// Auth account from the client SDK (that needs the Admin SDK / a Cloud
  /// Function), so per the spec's "or mark inactive" fallback we:
  ///   1. Record the removal in `removed_users/{uid}` (so the login flow
  ///      can show a clear "your account was removed" message instead of
  ///      a confusing generic error), then
  ///   2. Delete `users/{uid}` outright.
  /// Once that doc is gone, every Firestore rule that calls userDoc(uid)
  /// fails to resolve and denies by default — the removed employee's
  /// Firebase Auth login will still succeed, but they can't read or write
  /// a single collection in the app, and the login flow signs them
  /// straight back out when it notices the missing doc.
  static Future<void> removeEmployee(String userId) async {
    final adminUid = _auth.currentUser?.uid;
    final beforeDoc = await _users.doc(userId).get();
    final before = beforeDoc.data() ?? {};
    await _db.collection('removed_users').doc(userId).set({
      'removedBy': adminUid,
      'removedAt': FieldValue.serverTimestamp(),
    });
    await _users.doc(userId).delete();
    ActivityLogService.logDelete(
      module: 'Employees',
      itemName: (before['name'] as String?) ?? (before['email'] as String?) ?? userId,
      data: {'access_level': before['accessLevel'], 'email': before['email']},
    );
  }

  /// True if this uid was explicitly removed by the admin — checked right
  /// after login so a removed employee gets a clear message instead of a
  /// silent dead end.
  static Future<bool> wasRemoved(String uid) async {
    final doc = await _db.collection('removed_users').doc(uid).get();
    return doc.exists;
  }

  static Future<void> markNotificationRead(String notificationId) async {
    await _notifications.doc(notificationId).set(
      {'read': true},
      SetOptions(merge: true),
    );
  }

  /// One-tap migration for employees who existed before this feature:
  /// gives everyone currently missing an accessLevel a default 'viewer'
  /// (approved), per the agreed rollout plan. Safe to run repeatedly.
  static Future<int> migrateLegacyUsersToViewer() async {
    final snap = await _users.get();
    var migrated = 0;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      final data = doc.data();
      final role = (data['role'] as String?) ?? 'employee';

      // ── Repair pass: an older version of approveAccess() incorrectly
      // overwrote 'role' with the access level ('viewer'/'editor') instead
      // of leaving it as 'employee'. Any doc whose 'role' is one of those
      // two values is a victim of that bug (never a legitimate role) —
      // reset it back to 'employee' so it shows up again in every
      // role=='employee' query (Manage Employees, login routing, etc.)
      // without touching their actual accessLevel/accessStatus.
      if (role == 'viewer' || role == 'editor') {
        batch.set(doc.reference, {'role': 'employee'}, SetOptions(merge: true));
        migrated++;
        continue;
      }

      if (role == 'admin') continue;
      if (data['accessLevel'] == null || data['accessStatus'] == null) {
        batch.set(
          doc.reference,
          {
            'accessLevel': 'viewer',
            'accessStatus': 'approved',
          },
          SetOptions(merge: true),
        );
        migrated++;
      }
    }
    if (migrated > 0) await batch.commit();
    return migrated;
  }

  // ──────────────────────────────────────────────────────────────
  // Streams
  //
  // These are called from several screens at once (the dashboard's
  // notification badge, Employee Access, Admin Notifications, Activity
  // Feed all ask for the same handful of queries). Without memoizing,
  // every call — and every StreamBuilder rebuild — opened a brand-new
  // Firestore real-time listener for the exact same query, multiplying
  // active listeners far beyond what the screens actually need and
  // burning through the read quota fast. Each query below now opens
  // exactly ONE listener per app session (as a broadcast stream so
  // multiple screens can share it), reused by every caller.
  //
  // IMPORTANT — why this needed a second fix on top of memoizing:
  // A plain `.asBroadcastStream()` (or `StreamController.broadcast()`)
  // NEVER replays an already-emitted value to a listener that attaches
  // later. It only delivers events that occur AFTER `.listen()` is
  // called. Because these streams are cached as static singletons that
  // live for the whole app session, the underlying Firestore listener
  // is usually still running (e.g. the dashboard's pending-count badge
  // keeps one subscriber attached at all times) — but it already fired
  // its one-and-only initial snapshot long ago. So when you navigate
  // back into EmployeeAccessScreen / AdminNotificationsScreen, Flutter
  // builds a brand-new StreamBuilder, which becomes a brand-new
  // listener on the same cached broadcast stream. That listener gets
  // nothing until the NEXT real Firestore write happens anywhere in the
  // app — which, on a page you just navigated into, can be seconds,
  // minutes, or never. Meanwhile the screen's own "loading" guard
  // (`!snapshot.hasData && !snapshot.hasError`) stays true, so the
  // spinner never goes away. That's the exact bug: intermittent,
  // reproduces only on a repeat visit, never on first launch (first
  // subscriber always gets the initial snapshot), and unrelated to
  // routing, dispose(), or any _isLoading flag (there isn't one).
  //
  // Fix: wrap each source stream in `_ReplayStream`, a tiny cache that
  // remembers the most recent value/error and immediately re-emits it
  // to every NEW subscriber before forwarding further live updates —
  // the same guarantee an rxdart BehaviorSubject gives, without adding
  // the dependency.
  // ──────────────────────────────────────────────────────────────
  static final Map<String, Stream<AppUserAccess>> _userStreamCache = {};
  static Stream<AppUserAccess> streamUser(String uid) {
    return _userStreamCache[uid] ??= _ReplayStream<AppUserAccess>(
      _users.doc(uid).snapshots().map(AppUserAccess.fromDoc),
      onError: () => _userStreamCache.remove(uid),
    ).stream;
  }

  static Stream<List<AppUserAccess>>? _allEmployeesStream;
  static Stream<List<AppUserAccess>> streamAllEmployees() {
    return _allEmployeesStream ??= _ReplayStream<List<AppUserAccess>>(
      _users
          .where('role', isEqualTo: 'employee')
          .snapshots()
          .map((s) => s.docs.map(AppUserAccess.fromDoc).toList()),
      onError: () => _allEmployeesStream = null,
    ).stream;
  }

  /// Every employee currently awaiting admin approval — the source of
  /// truth for the "Pending Requests" page. Reads straight from
  /// users/{uid} (not admin_notifications) so it can never drift out of
  /// sync with what streamUser()/CurrentAccess is showing the employee.
  static Stream<List<AppUserAccess>>? _pendingUsersStream;
  static Stream<List<AppUserAccess>> streamPendingUsers() {
    return _pendingUsersStream ??= _ReplayStream<List<AppUserAccess>>(
      _users
          .where('role', isEqualTo: 'employee')
          .where('accessStatus', isEqualTo: 'pending')
          .snapshots()
          .map((s) => s.docs.map(AppUserAccess.fromDoc).toList()),
      onError: () => _pendingUsersStream = null,
    ).stream;
  }

  /// Live count of pending employees, for the admin dashboard's
  /// "Notifications (N)" badge. Just a transform of the single shared
  /// streamPendingUsers() listener above — no extra Firestore listener.
  static Stream<int> streamPendingCount() {
    return streamPendingUsers().map((list) => list.length);
  }

  static Stream<List<AdminNotificationModel>>? _notificationsStream;
  static Stream<List<AdminNotificationModel>> streamNotifications() {
    return _notificationsStream ??= _ReplayStream<List<AdminNotificationModel>>(
      _notifications
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .map((s) => s.docs.map(AdminNotificationModel.fromDoc).toList()),
      onError: () => _notificationsStream = null,
    ).stream;
  }

  static Stream<int>? _unreadCountStream;
  static Stream<int> streamUnreadCount() {
    return _unreadCountStream ??= _ReplayStream<int>(
      _notifications
          .where('read', isEqualTo: false)
          .snapshots()
          .map((s) => s.docs.length),
      onError: () => _unreadCountStream = null,
    ).stream;
  }

  // ──────────────────────────────────────────────────────────────
  // Activity logging for login/registration/dashboard-access events.
  //
  // IMPORTANT: this writes into the SAME 'activity_logs' collection that
  // ActivityLogService reads for the Live Activity Feed, so the schema
  // here must match what ActivityLogModel.fromDoc expects (userName,
  // kind, label) — not just {userId, email, action, performedBy}. The
  // old schema was missing 'userName' and 'label', which made every
  // login/registration render as a blank "Unknown — " row in the feed.
  //
  // Never let a logging failure break the actual operation it's
  // attached to (approve/reject/login/register must still succeed).
  // ──────────────────────────────────────────────────────────────
  static Future<void> _logActivity({
    required String userId,
    required String action,
    required String performedBy,
    String? email,
  }) async {
    try {
      final doc = await _users.doc(userId).get();
      final data = doc.data();
      final resolvedEmail = email ?? (data?['email'] as String?) ?? '';
      final userName = (data?['name'] as String?) ??
          (resolvedEmail.isNotEmpty ? resolvedEmail : 'Unknown');
      final userRole = (data?['role'] as String?) ?? 'employee';
      await _db.collection('activity_logs').add({
        'userId': userId,
        'userName': userName,
        'userRole': userRole,
        'kind': 'action',
        'label': action,
        'email': resolvedEmail,
        'action': null, // not an add/edit/delete — keeps _sentenceFor's fallback branch
        'performedBy': performedBy,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // best-effort only — never block the real operation on this
    }
  }

  /// Call right after Firebase Auth account creation in AuthService.register().
  static Future<void> logRegistration({required String uid, required String email}) {
    return _logActivity(userId: uid, email: email, action: 'Employee registered', performedBy: email);
  }

  /// Call right after a successful sign-in (admin or employee).
  static Future<void> logLogin({required String uid, required String email}) {
    return _logActivity(userId: uid, email: email, action: 'Login', performedBy: email);
  }

  /// Call when a user's dashboard actually renders (not just signs in) —
  /// distinct from "Login" so the trail shows they made it past any
  /// approval gate.
  static Future<void> logDashboardAccess({required String uid, required String email}) {
    return _logActivity(userId: uid, email: email, action: 'Dashboard access', performedBy: email);
  }

  /// Live audit trail for the admin's Activity Feed screen, schema-matched
  /// to the simplified { userId, email, action, timestamp, performedBy }
  /// rows written by [_logActivity]/[logRegistration]/[logLogin]/etc, in
  /// addition to the richer screen_visit/action rows ActivityLogService
  /// writes. Both live in the same activity_logs collection.
  static Stream<List<Map<String, dynamic>>> streamActivityLogsRaw({int limit = 200}) {
    return _db
        .collection('activity_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}