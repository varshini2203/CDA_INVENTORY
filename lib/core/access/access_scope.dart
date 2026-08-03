// lib/core/access/access_scope.dart
//
// App-wide, real-time view of "who am I and what am I allowed to do".
// Register once in main.dart:
//
//   ChangeNotifierProvider(create: (_) => CurrentAccess()),
//
// then call `context.read<CurrentAccess>().listenTo(uid)` right after a
// successful login, and any widget can read `context.watch<CurrentAccess>()`
// to check canEdit / canView / isAdmin. Wrap write-action widgets (Add
// buttons, edit icons, FABs) with EditGuard to auto-disable/hide them for
// viewer-level employees.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_access_models.dart';
import '../../services/access_control_service.dart';
import '../../services/activity_log_service.dart';

class CurrentAccess extends ChangeNotifier {
  AppUserAccess? _access;
  StreamSubscription<AppUserAccess>? _sub;

  AppUserAccess? get access => _access;
  bool get isAdmin => _access?.isAdmin ?? false;
  bool get canEdit => _access?.canEdit ?? false;
  bool get canView => _access?.canView ?? false;
  AccessStatus get status => _access?.accessStatus ?? AccessStatus.pending;

  /// [knownName]/[knownRole] let the caller (a login screen that already
  /// just fetched the user's access doc) attribute activity correctly
  /// from the very first frame, instead of waiting for this stream's
  /// first snapshot to arrive. Every login screen navigates to the
  /// dashboard on the line right after calling listenTo() — without this,
  /// the dashboard's own "viewed /dashboard" visit gets logged before the
  /// stream below has emitted anything, so it fell back to the service's
  /// hardcoded defaults ('Unknown' / 'employee') instead of the real user.
  /// The stream subscription below still takes over as the live source of
  /// truth for every log after that first one (so role/permission changes
  /// made mid-session are still picked up as before).
  void listenTo(String uid, {String? knownName, String? knownRole}) {
    _sub?.cancel();
    if (knownName != null && knownName.isNotEmpty && knownRole != null) {
      ActivityLogService.setCurrentUser(uid: uid, name: knownName, role: knownRole);
    }
    _sub = AccessControlService.streamUser(uid).listen((value) {
      _access = value;
      ActivityLogService.setCurrentUser(
        uid: value.uid,
        name: value.name.isNotEmpty ? value.name : value.email,
        role: value.role,
      );
      notifyListeners();
    });
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
    _access = null;
    ActivityLogService.clearCurrentUser();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Wrap any write-action widget (FAB, "Add" button, edit icon, etc) with
/// this to automatically hide/disable it for viewers while leaving it
/// untouched for admins/editors. Usage:
///
///   EditGuard(
///     child: FloatingActionButton(onPressed: _addItem, child: const Icon(Icons.add)),
///   )
class EditGuard extends StatelessWidget {
  final Widget child;
  final bool hideInsteadOfDisable;
  const EditGuard({super.key, required this.child, this.hideInsteadOfDisable = false});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<CurrentAccess>();
    if (access.canEdit) return child;
    if (hideInsteadOfDisable) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: true,
      child: Opacity(opacity: 0.4, child: child),
    );
  }
}

/// A slim banner to show at the top of screens for viewer-level users so
/// it's obvious why edit controls are disabled.
class ViewOnlyBanner extends StatelessWidget {
  const ViewOnlyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<CurrentAccess>();
    if (access.canEdit) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Colors.amber.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: const Row(
        children: [
          Icon(Icons.visibility_outlined, size: 14, color: Colors.amber),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'View-only access — ask your admin for edit access to make changes',
              style: TextStyle(fontSize: 11, color: Colors.amber),
            ),
          ),
        ],
      ),
    );
  }
}

/// Convenience guard for imperative checks inside onPressed handlers that
/// do more than one thing, e.g.:
///
///   onPressed: () {
///     if (!requireEditAccess(context)) return;
///     _saveProduct();
///   }
bool requireEditAccess(BuildContext context) {
  final access = context.read<CurrentAccess>();
  if (access.canEdit) return true;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('You have view-only access. Ask your admin for edit access.'),
      behavior: SnackBarBehavior.floating,
    ),
  );
  return false;
}

/// Client-side guard for admin-only routes (Pending Requests, Manage
/// Employees, Activity Feed). Firestore rules are the real enforcement —
/// a non-admin's reads/writes are rejected server-side regardless — this
/// just gives a clear "Admins only" message instead of a blank screen or
/// a stream of permission-denied errors if a non-admin ever lands here.
class AdminGuard extends StatelessWidget {
  final Widget child;
  const AdminGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<CurrentAccess>().isAdmin;
    if (isAdmin) return child;
    return Scaffold(
      backgroundColor: const Color(0xFF050A14),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 44, color: Colors.white.withOpacity(0.3)),
              const SizedBox(height: 16),
              const Text('Admins only', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'This page is restricted to the app administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}