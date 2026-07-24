// lib/services/seed_guard_service.dart
//
// Prevents the app's silent "auto-seed if collection looks empty" logic
// (in InventoryDashboard and SearchScreen) from re-running every time a
// screen is opened. Previously, each of those screens checked ONLY
// "is the collection empty right now?" with no memory of whether it had
// already been seeded before — so testing empty-state UI (deleting all
// items, then reopening the screen) silently re-wrote 1,500+ documents
// per visit, with no confirmation and no visible warning. Repeating that
// a couple dozen times during a single testing session was enough on its
// own to exhaust the daily Firestore quota.
//
// This adds a tiny, cheap (~1 doc read) permanent marker in Firestore:
// once a collection has been auto-seeded ONE time, it never auto-seeds
// again automatically — even if the collection is emptied again later.
// Manual seeding via the explicit "Seed" buttons (which already require
// a confirmation dialog) still works regardless; it just also sets the
// marker so future auto-seed checks skip too.
import 'package:cloud_firestore/cloud_firestore.dart';

class SeedGuardService {
  SeedGuardService._();

  static final CollectionReference<Map<String, dynamic>> _statusCol =
  FirebaseFirestore.instance.collection('seed_status');

  /// True if [key] (e.g. 'inventory', 'products') has ever been marked
  /// seeded before. A single cheap document read — far cheaper than the
  /// 1,000+ document writes it's guarding against.
  static Future<bool> hasSeeded(String key) async {
    try {
      final doc = await _statusCol.doc(key).get();
      return doc.exists && (doc.data()?['seeded'] == true);
    } catch (_) {
      // If we can't tell (e.g. offline, quota issues), fail SAFE by
      // assuming it HAS been seeded — better to skip a legitimate seed
      // than to risk silently repeating a 1,000+ write bulk operation.
      return true;
    }
  }

  /// Marks [key] as seeded so no future auto-seed check will trigger for
  /// it again. Call this right after any successful seed — automatic or
  /// manual.
  static Future<void> markSeeded(String key) async {
    try {
      await _statusCol.doc(key).set({
        'seeded': true,
        'seededAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Best-effort — worst case the guard doesn't persist and the next
      // empty-check re-seeds once more, which is still far better than
      // no guard at all.
    }
  }
}