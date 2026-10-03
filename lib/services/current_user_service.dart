// lib/services/current_user_service.dart
//
// SINGLE SOURCE OF TRUTH for "who is logged in right now".
//
// Every module (Inventory, New Products, Fixed Assets, Consumables, Stock
// In/Out/Transfer, Proforma, Drone In/Out, Drone Service, Movement, ...)
// must use this instead of asking the user to type their name.
//
//   final who = await CurrentUserService.getName();   // async, always correct
//   final who = CurrentUserService.nameSync;           // sync, after login
//
// Resolution order:
//   1. in-memory cache (set at login by ActivityLogService.setCurrentUser)
//   2. Firestore  users/{uid}.name
//   3. FirebaseAuth displayName
//   4. email prefix (before @)
//   5. 'Unknown'
//
// The cache is keyed by uid, so logging out and into another account can
// never leak the previous user's name.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CurrentUserService {
  CurrentUserService._();

  static String? _cachedUid;
  static String? _cachedName;

  /// Called from ActivityLogService.setCurrentUser (i.e. at login and
  /// whenever the access stream emits).
  static void setCurrent({required String uid, required String name}) {
    if (name.trim().isEmpty) return;
    _cachedUid = uid;
    _cachedName = name.trim();
  }

  static void clear() {
    _cachedUid = null;
    _cachedName = null;
  }

  static String? get uid => FirebaseAuth.instance.currentUser?.uid;

  /// Synchronous best-effort name. Safe to call from initState / build.
  /// Falls back to displayName / email prefix when the cache is cold.
  static String get nameSync {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Unknown';
    if (_cachedUid == user.uid && (_cachedName?.isNotEmpty ?? false)) {
      return _cachedName!;
    }
    return _fromAuth(user);
  }

  /// Always-correct name. Hits Firestore at most once per login.
  static Future<String> getName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Unknown';

    if (_cachedUid == user.uid && (_cachedName?.isNotEmpty ?? false)) {
      return _cachedName!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final name = (doc.data()?['name'] as String?)?.trim() ?? '';
      if (name.isNotEmpty) {
        setCurrent(uid: user.uid, name: name);
        return name;
      }
    } catch (_) {
      // Offline / rules problem — fall through to Auth data.
    }
    return _fromAuth(user);
  }

  static String _fromAuth(User user) {
    final dn = user.displayName?.trim() ?? '';
    if (dn.isNotEmpty) return dn;
    final email = user.email?.trim() ?? '';
    if (email.isNotEmpty) return email.split('@').first;
    return 'Unknown';
  }
}
