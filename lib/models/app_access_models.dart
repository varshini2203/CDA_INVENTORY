// lib/models/app_access_models.dart
//
// Shared models for the Admin Control system:
//  - AppUserAccess : the access-control fields stored on users/{uid}
//  - AdminNotificationModel : entries in admin_notifications collection
//  - ActivityLogModel : entries in activity_logs collection
//
// These are intentionally simple data classes (no code-gen) so they drop
// straight into the existing Firestore-based app without new dependencies.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Access level an employee can be granted by the admin.
enum AccessLevel { none, viewer, editor }

AccessLevel accessLevelFromString(String? value) {
  switch (value) {
    case 'editor':
      return AccessLevel.editor;
    case 'viewer':
      return AccessLevel.viewer;
    default:
      return AccessLevel.none;
  }
}

String accessLevelToString(AccessLevel level) {
  switch (level) {
    case AccessLevel.editor:
      return 'editor';
    case AccessLevel.viewer:
      return 'viewer';
    case AccessLevel.none:
      return 'none';
  }
}

/// Status of an employee's access request.
enum AccessStatus { pending, approved, rejected }

AccessStatus accessStatusFromString(String? value) {
  switch (value) {
    case 'approved':
      return AccessStatus.approved;
    case 'denied': // legacy value written before the Phase-3/4 rename
    case 'rejected':
      return AccessStatus.rejected;
    default:
      return AccessStatus.pending;
  }
}

String accessStatusToString(AccessStatus status) {
  switch (status) {
    case AccessStatus.approved:
      return 'approved';
    case AccessStatus.rejected:
      return 'rejected';
    case AccessStatus.pending:
      return 'pending';
  }
}

/// Full access-control snapshot for a single user, mirrors the fields
/// added to the `users/{uid}` Firestore document.
class AppUserAccess {
  final String uid;
  final String name;
  final String email;
  final String role; // 'admin' | 'employee'
  final String branch;
  final String phone;
  final AccessLevel accessLevel;
  final AccessStatus accessStatus;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final bool isOnline;

  AppUserAccess({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.branch = '',
    this.phone = '',
    required this.accessLevel,
    required this.accessStatus,
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
    this.lastLogin,
    this.isOnline = false,
  });

  bool get isAdmin => role == 'admin';
  bool get canEdit => isAdmin || accessLevel == AccessLevel.editor;
  bool get canView =>
      isAdmin ||
          (accessStatus == AccessStatus.approved && accessLevel != AccessLevel.none);

  factory AppUserAccess.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return AppUserAccess.fromMap(doc.id, doc.data() ?? {});
  }

  /// Same field mapping as [fromDoc], but works off a plain map the caller
  /// already has in memory (e.g. right after writing it) instead of
  /// requiring a fresh Firestore read just to re-read what was just sent.
  factory AppUserAccess.fromMap(String uid, Map<String, dynamic> data) {
    return AppUserAccess(
      uid: uid,
      name: (data['name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      role: (data['role'] as String?) ?? 'employee',
      branch: (data['branch'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      accessLevel: accessLevelFromString(data['accessLevel'] as String?),
      accessStatus: accessStatusFromString(data['accessStatus'] as String?),
      approvedBy: data['approvedBy'] as String?,
      // serverTimestamp() sentinel values aren't real Timestamps client-side
      // yet, so guard the cast instead of assuming Timestamp.
      approvedAt: data['approvedAt'] is Timestamp
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      lastLogin: data['lastLogin'] is Timestamp
          ? (data['lastLogin'] as Timestamp).toDate()
          : null,
      isOnline: (data['isOnline'] as bool?) ?? false,
    );
  }
}

/// A notification shown to the admin (login/access request, or a general
/// heads-up about something that happened in the app).
class AdminNotificationModel {
  final String id;
  final String type; // 'access_request' | 'info'
  final String userId;
  final String userName;
  final String userEmail;
  final String message;
  final String requestedAccess; // 'viewer' | 'editor' (for access_request)
  final String status; // 'pending' | 'approved' | 'denied' | 'na'
  final bool read;
  final DateTime? createdAt;

  AdminNotificationModel({
    required this.id,
    required this.type,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.message,
    required this.requestedAccess,
    required this.status,
    required this.read,
    this.createdAt,
  });

  factory AdminNotificationModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AdminNotificationModel(
      id: doc.id,
      type: (data['type'] as String?) ?? 'info',
      userId: (data['userId'] as String?) ?? '',
      userName: (data['userName'] as String?) ?? 'Unknown',
      userEmail: (data['userEmail'] as String?) ?? '',
      message: (data['message'] as String?) ?? '',
      requestedAccess: (data['requestedAccess'] as String?) ?? 'viewer',
      status: (data['status'] as String?) ?? 'na',
      read: (data['read'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// One row in the live audit trail — either a screen visit or an action
/// (add / edit / delete / login / logout / access change, etc).
///
/// `module`, `action` and `itemName` power the rich "who did what, where"
/// sentence in the Activity Feed (e.g. "Sudharshan added DJI Mavic 3 in
/// Drones"). `changes` holds a field-level diff for edits — a map of
/// `{ fieldLabel: { 'old': ..., 'new': ... } }` — so the admin can see
/// exactly what was changed, not just that something was.
class ActivityLogModel {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final String kind; // 'screen_visit' | 'action'
  final String label; // screen name, or a human-readable action sentence
  final String? module; // e.g. 'Stock', 'Drones', 'Purchases', 'Bills'
  final String? action; // 'added' | 'edited' | 'deleted' | 'login' | ...
  final String? itemName; // the specific record affected, e.g. product name
  final Map<String, dynamic>? changes; // fieldLabel -> {old, new} (edits only)
  final String? details;
  final DateTime? timestamp;

  ActivityLogModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.kind,
    required this.label,
    this.module,
    this.action,
    this.itemName,
    this.changes,
    this.details,
    this.timestamp,
  });

  /// True when this row carries a before/after diff worth showing.
  bool get hasChanges => changes != null && changes!.isNotEmpty;

  factory ActivityLogModel.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    Map<String, dynamic>? parsedChanges;
    final rawChanges = data['changes'];
    if (rawChanges is Map) {
      parsedChanges = <String, dynamic>{};
      rawChanges.forEach((key, value) {
        if (value is Map) {
          parsedChanges!['$key'] = Map<String, dynamic>.from(value);
        }
      });
    }

    return ActivityLogModel(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      userName: (data['userName'] as String?) ?? 'Unknown',
      userRole: (data['userRole'] as String?) ?? 'employee',
      kind: (data['kind'] as String?) ?? 'action',
      label: (data['label'] as String?) ?? '',
      module: data['module'] as String?,
      action: data['action'] as String?,
      itemName: data['itemName'] as String?,
      changes: parsedChanges,
      details: data['details'] as String?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}