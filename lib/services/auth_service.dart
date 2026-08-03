import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'access_control_service.dart';
import '../core/constants/app_admin.dart';

class AuthService {
  // ── Instance references (for instance methods) ───────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Static references (for static methods) ───────────────────
  static final FirebaseAuth _sAuth = FirebaseAuth.instance;
  static final FirebaseFirestore _sDb = FirebaseFirestore.instance;

  // ── Auth state & current user ────────────────────────────────
  static User? get currentUser => _sAuth.currentUser;
  static String? get currentUserEmail => _sAuth.currentUser?.email;
  static String? get currentUserId => _sAuth.currentUser?.uid;
  static Stream<User?> get authStateChanges => _sAuth.authStateChanges();

  // ────────────────────────────────────────────────────────────
  // REGISTER  (instance method — matches RegisterScreen call)
  // role must be either 'admin' or 'employee'
  // ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> register(
      String name,
      String email,
      String password,
      String branch,
      String role,
      ) async {
    try {
      // ── Single-admin enforcement ─────────────────────────────
      // Nobody can self-register as 'admin' unless their email is the
      // one reserved admin address. Everyone else who tries is silently
      // registered as an employee instead (never rejected outright, so
      // we don't leak which email the real admin account uses).
      //
      // The reverse also has to be handled explicitly: RegisterScreen
      // always passes initialRole: 'employee' (registration is meant to
      // be employee-only), so without this line the one reserved admin
      // email would ALSO get silently created as an employee account —
      // which is exactly the bug that caused "registered as Employee"
      // errors when signing in with the admin email. The reserved email
      // always self-heals to admin, regardless of what role was passed in.
      if (isAdminEmail(email)) {
        role = 'admin';
      } else if (role == 'admin') {
        role = 'employee';
      }

      // 1. Create Firebase Auth account
      final UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // 2. Save extra info to Firestore 'users' collection.
      // accessLevel/accessStatus/status are set here (not just on first
      // login) so a brand-new registration shows up in the admin's
      // Pending Requests list immediately, per spec requirement 1.
      final isAdminAccount = role == 'admin';
      await _db.collection('users').doc(cred.user!.uid).set({
        'name':      name.trim(),
        'email':     email.trim(),
        'branch':    branch,
        'role':      isAdminAccount ? 'admin' : 'employee',
        'accessLevel': isAdminAccount ? 'editor' : 'none',
        'accessStatus': isAdminAccount ? 'approved' : 'pending',
        'status': isAdminAccount ? 'approved' : 'pending', // spec field name
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Update display name in Firebase Auth
      await cred.user!.updateDisplayName(name.trim());

      // 4. Log the registration event (spec requirement 5).
      await AccessControlService.logRegistration(uid: cred.user!.uid, email: email.trim());

      // 5. Notify the admin immediately — don't wait for first login.
      if (!isAdminAccount) {
        await AccessControlService.notifyAdminOfNewRequest(
          uid: cred.user!.uid,
          name: name.trim(),
          email: email.trim(),
        );
      }

      return {
        'success': true,
        'message': 'Account created successfully!',
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed. Please try again.';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak. Use at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      } else if (e.code == 'network-request-failed') {
        message = 'No internet connection. Please try again.';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Something went wrong: $e'};
    }
  }

  // ────────────────────────────────────────────────────────────
  // LOGIN  (static) — plain login, no role check.
  // Kept for backward compatibility; prefer loginWithRole() below
  // for the separate Admin / Employee login screens.
  // ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      await _sAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _mapAuthError(e)};
    } catch (e) {
      return {'success': false, 'message': 'Something went wrong: $e'};
    }
  }

  // ────────────────────────────────────────────────────────────
  // LOGIN WITH ROLE CHECK  (static)
  // Signs in, then verifies the account's Firestore role matches
  // requiredRole ('admin' or 'employee'). If it doesn't match,
  // the user is signed back out and an error is returned — so an
  // employee account can't get in through the Admin screen, and
  // vice versa.
  // ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> loginWithRole({
    required String email,
    required String password,
    required String requiredRole,
  }) async {
    try {
      final cred = await _sAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = cred.user!.uid;
      final doc = await _sDb.collection('users').doc(uid).get();
      var role = (doc.data()?['role'] as String?) ?? 'employee';

      // ── Single-admin enforcement (both directions) ────────────
      // 1. The reserved admin email ALWAYS resolves to 'admin', even if
      //    its Firestore doc is missing, stale, or says 'employee' (e.g.
      //    it was created through the employee-only Register screen).
      //    This is the self-heal that fixes "registered as Employee"
      //    errors for the real admin account.
      // 2. Nobody else may ever be treated as admin, no matter what
      //    their Firestore doc says.
      if (isAdminEmail(email)) {
        role = 'admin';
      } else if (role == 'admin') {
        role = 'employee';
      }

      if (requiredRole == 'admin' && !isAdminEmail(email)) {
        await _sAuth.signOut();
        return {
          'success': false,
          'message': 'This email is not authorized for Admin access.',
        };
      }

      if (role != requiredRole) {
        await _sAuth.signOut();
        // Label the account's ACTUAL role, not the tab the user happened
        // to click — otherwise the message reads backwards (e.g. telling
        // an employee account to "use Admin login instead").
        final actualLoginLabel = role == 'admin' ? 'Admin' : 'Employee';
        final actualLabel = role == 'admin' ? 'an Admin' : 'an Employee';
        return {
          'success': false,
          'message':
          'This account is registered as $actualLabel. Please use the $actualLoginLabel login instead.',
        };
      }

      // Login succeeded and the role check above passed — this is a real,
      // verified login, distinct from just "reached the dashboard" (an
      // employee waiting on admin approval logs in successfully here but
      // may not reach the dashboard for a while yet, so this event is
      // still worth capturing on its own).
      AccessControlService.logLogin(uid: uid, email: email.trim());

      // Hand back the doc data/existence we already paid for above so
      // callers can pass it straight into AccessControlService.onUserLoggedIn()
      // via existingData/existingDataFound instead of triggering a second
      // users/{uid} read for the exact same document a moment later.
      return {
        'success': true,
        'role': role,
        'docData': doc.data(),
        'docExists': doc.exists,
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _mapAuthError(e)};
    } catch (e) {
      return {'success': false, 'message': 'Something went wrong: $e'};
    }
  }

  static String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      default:
        return 'Login failed. Please try again.';
    }
  }

  // ────────────────────────────────────────────────────────────
  // LOGOUT  (static)
  // ────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    final uid = _sAuth.currentUser?.uid;
    if (uid != null) {
      await AccessControlService.markOffline(uid);
    }
    await _sAuth.signOut();
  }

  // ────────────────────────────────────────────────────────────
  // GET USER PROFILE from Firestore  (static)
  // ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final uid = _sAuth.currentUser?.uid;
      if (uid == null) return null;
      final doc = await _sDb.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────
  // UPDATE USER PROFILE  (static)
  // ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String branch,
  }) async {
    try {
      final uid = _sAuth.currentUser?.uid;
      if (uid == null) return {'success': false, 'message': 'Not logged in'};

      await _sDb.collection('users').doc(uid).update({
        'name':   name.trim(),
        'branch': branch,
      });
      await _sAuth.currentUser!.updateDisplayName(name.trim());

      return {'success': true, 'message': 'Profile updated!'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ────────────────────────────────────────────────────────────
  // CHANGE PASSWORD  (static)
  // ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _sAuth.currentUser;
      if (user == null) return {'success': false, 'message': 'Not logged in'};

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      await user.updatePassword(newPassword);
      return {'success': true, 'message': 'Password changed successfully!'};
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to change password';
      if (e.code == 'wrong-password') {
        message = 'Current password is incorrect.';
      } else if (e.code == 'weak-password') {
        message = 'New password is too weak.';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ────────────────────────────────────────────────────────────
  // FORGOT PASSWORD — sends reset email  (static)
  // ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    try {
      await _sAuth.sendPasswordResetEmail(email: email.trim());
      return {
        'success': true,
        'message': 'Password reset email sent! Check your inbox.',
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to send reset email';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ────────────────────────────────────────────────────────────
  // ROLE HELPERS  (static)
  // ────────────────────────────────────────────────────────────
  static Future<bool> isAdmin() async {
    final profile = await getUserProfile();
    return profile?['role'] == 'admin';
  }

  static Future<String> getRole() async {
    final profile = await getUserProfile();
    return (profile?['role'] as String?) ?? 'employee';
  }

  // ────────────────────────────────────────────────────────────
  // GET ROLE + RAW PROFILE IN ONE READ  (static)
  // Used by SplashScreen, which (unlike the login screens) isn't
  // preceded by AuthService.loginWithRole()'s own users/{uid} read —
  // it runs whenever the app (re)launches into an already-signed-in
  // session. Previously it called getRole() (one read) and then
  // AccessControlService.onUserLoggedIn() (a second read of the same
  // doc). This does the single read both of those needed and returns
  // enough for the caller to pass straight into onUserLoggedIn() via
  // existingData/existingDataFound, so only one read happens overall.
  // ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getCurrentUserRoleAndProfile() async {
    final uid = _sAuth.currentUser?.uid;
    if (uid == null) {
      return {'role': 'employee', 'docData': null, 'docExists': false};
    }
    final doc = await _sDb.collection('users').doc(uid).get();
    final data = doc.data();
    final role = (data?['role'] as String?) ?? 'employee';
    return {'role': role, 'docData': data, 'docExists': doc.exists};
  }
}