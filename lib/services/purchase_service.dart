import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase.dart';
import '../constants/gamification_constants.dart';
import 'activity_log_service.dart';
import 'staff_reward_service.dart';

class PurchaseService {
  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('purchases');

  // ── IN-MEMORY CACHE ─────────────────────────────────────────────────────
  // getAllPurchases() is called from multiple screens (Purchases Menu,
  // Purchase List, Reports Dashboard, Purchase Report) that all want the
  // same full list. Caching it here means only the FIRST caller in a
  // session pays for a Firestore read; everyone else reuses the same list
  // in memory until a write invalidates it.
  static List<Purchase>? _cache;

  /// Clears the cached purchase list. Called automatically after
  /// add/delete so every screen sees fresh data on its next read.
  static void clearCache() => _cache = null;

  // ── GET all purchases (sorted client-side, no index needed) ───────────────
  static Future<List<Purchase>> getAllPurchases({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;
    try {
      final snap = await _col.get();
      final purchases = snap.docs
          .map((d) => Purchase.fromFirestore(
          d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      // Sort by purchase date descending (newest first)
      purchases.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
      _cache = purchases;
      return purchases;
    } catch (e) {
      throw Exception('Failed to load purchases: $e');
    }
  }

  // ── GET purchases filtered by branch (client-side, no index needed) ────────
  static Future<List<Purchase>> getPurchasesByBranch(String branch, {bool forceRefresh = false}) async {
    try {
      final all = await getAllPurchases(forceRefresh: forceRefresh);
      if (branch == 'All') return all;
      return all.where((p) => p.branch == branch).toList();
    } catch (e) {
      throw Exception('Failed to filter purchases: $e');
    }
  }

  // ── ADD purchase ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> addPurchase(Purchase purchase) async {
    try {
      final data = purchase.toFirestore()
        ..['created_at'] = FieldValue.serverTimestamp();

      final docRef = await _col.add(data);
      clearCache();
      ActivityLogService.logAdd(
        module: 'Purchases',
        itemName: purchase.productName,
        data: {
          'vendor': purchase.vendorName,
          'quantity': purchase.quantity,
          'cost': purchase.cost,
          'invoice_number': purchase.invoiceNumber,
          'branch': purchase.branch,
          'purchase_date': purchase.purchaseDate,
        },
      );
      StaffRewardService.recordActivity(
        action: StaffAction.purchaseEntry,
        module: 'Purchases',
        refId: 'purchases_${docRef.id}_add',
      );
      return {
        'success': true,
        'message': 'Purchase saved successfully',
        'id': docRef.id,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to save purchase: $e',
      };
    }
  }

  // ── DELETE purchase ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> deletePurchase(String id) async {
    try {
      final existing = await getPurchaseById(id);
      await _col.doc(id).delete();
      clearCache();
      ActivityLogService.logDelete(
        module: 'Purchases',
        itemName: existing?.productName ?? id,
        data: existing == null
            ? null
            : {
          'vendor': existing.vendorName,
          'quantity': existing.quantity,
          'cost': existing.cost,
          'branch': existing.branch,
        },
      );
      return {
        'success': true,
        'message': 'Purchase deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete purchase: $e',
      };
    }
  }

  // ── Duplicate bill-number check (used before create/update) ────────────────
  static Future<bool> billNumberExists(String billNumber, {String? excludeId}) async {
    if (billNumber.trim().isEmpty) return false;
    final snapshot =
    await _col.where('invoice_number', isEqualTo: billNumber).get();
    if (snapshot.docs.isEmpty) return false;
    if (excludeId == null) return true;
    return snapshot.docs.any((doc) => doc.id != excludeId);
  }

  // ── Next bill number suggestion (e.g. "PB-0001") ────────────────────────
  // Looks at the highest numeric suffix among existing purchase bill
  // numbers and suggests the next one in sequence, zero-padded to 4
  // digits. Falls back to re-checking against Firestore in case the
  // in-memory cache is stale (e.g. another device just saved a bill).
  static Future<String> suggestNextBillNumber({bool forceRefresh = false}) async {
    final purchases = await getAllPurchases(forceRefresh: forceRefresh);
    int maxNum = 0;
    for (final p in purchases) {
      final match = RegExp(r'(\d+)$').firstMatch(p.invoiceNumber);
      if (match == null) continue;
      final n = int.tryParse(match.group(1)!);
      if (n != null && n > maxNum) maxNum = n;
    }

    int next = maxNum + 1;
    String candidate = 'PB-${next.toString().padLeft(4, '0')}';
    int guard = 0;
    while (await billNumberExists(candidate) && guard < 20) {
      next++;
      candidate = 'PB-${next.toString().padLeft(4, '0')}';
      guard++;
    }
    return candidate;
  }

  // ── GET single purchase by ID ──────────────────────────────────────────────
  static Future<Purchase?> getPurchaseById(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return Purchase.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>);
    } catch (_) {
      return null;
    }
  }
}