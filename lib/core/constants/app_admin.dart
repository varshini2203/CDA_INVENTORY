// lib/core/constants/app_admin.dart
//
// SINGLE SOURCE OF TRUTH for "who is allowed to be Admin".
//
// Only the email address below can ever hold the 'admin' role in this
// app. Nobody else can register as admin, and even if a Firestore
// document is ever hand-edited to say role: 'admin', the Admin login
// screen will still refuse to let it in unless the email matches too.
//
// This value MUST stay in sync with the isAdminEmail() function in
// firestore.rules — if you ever change this, update that too.
const String kAdminEmail = 'info@chennaidroneacademy.com';

/// Case/whitespace-insensitive comparison against [kAdminEmail].
bool isAdminEmail(String? email) {
  if (email == null) return false;
  return email.trim().toLowerCase() == kAdminEmail.trim().toLowerCase();
}