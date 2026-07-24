import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase_return.dart';
import 'activity_log_service.dart';

class PurchaseReturnService {
  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('purchase_returns');

  // ── IN-MEMORY CACHE (full purchase-return list) ───────────────────────────
  // Same pattern now used by PurchaseService/PurchaseOrderService: fetch
  // once, reuse across navigation/rebuilds, invalidate on any write.
  // Previously this collection had no cache of its own — every call to
  // getAllPurchaseReturns() hit Firestore directly, so opening the Purchase
  // Returns list screen re-downloaded the whole collection every time,
  // even right after the Purchases Menu screen had already fetched it a
  // moment earlier.
  static List<PurchaseReturn>? _cache;

  static void clearCache() => _cache = null;

  // ── GET all purchase returns (sorted client-side, no index needed) ────────
  static Future<List<PurchaseReturn>> getAllPurchaseReturns({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache != null) return _cache!;
    try {
      final snap = await _col.get();
      final items = snap.docs
          .map((d) =>
          PurchaseReturn.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      // Sort by return date descending (newest first)
      items.sort((a, b) => b.returnDate.compareTo(a.returnDate));
      _cache = items;
      return items;
    } catch (e) {
      throw Exception('Failed to load purchase returns: $e');
    }
  }

  // ── GET purchase returns filtered by branch (client-side, no index needed) ─
  static Future<List<PurchaseReturn>> getPurchaseReturnsByBranch(
      String branch, {
        bool forceRefresh = false,
      }) async {
    try {
      final all = await getAllPurchaseReturns(forceRefresh: forceRefresh);
      if (branch == 'All') return all;
      return all.where((p) => p.branch == branch).toList();
    } catch (e) {
      throw Exception('Failed to filter purchase returns: $e');
    }
  }

  // ── ADD purchase return ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> addPurchaseReturn(PurchaseReturn ret) async {
    try {
      final data = ret.toFirestore()..['created_at'] = FieldValue.serverTimestamp();

      final docRef = await _col.add(data);
      clearCache();
      ActivityLogService.logAdd(
        module: 'Purchase Returns',
        itemName: ret.productName,
        data: {
          'vendor': ret.vendorName,
          'quantity': ret.quantity,
          'amount': ret.amount,
          'reason': ret.reason,
          'reference_invoice': ret.referenceInvoice,
          'branch': ret.branch,
          'return_date': ret.returnDate,
        },
      );
      return {
        'success': true,
        'message': 'Purchase return saved successfully',
        'id': docRef.id,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to save purchase return: $e',
      };
    }
  }

  // ── DELETE purchase return ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> deletePurchaseReturn(String id) async {
    try {
      final existing = await getPurchaseReturnById(id);
      await _col.doc(id).delete();
      clearCache();
      ActivityLogService.logDelete(
        module: 'Purchase Returns',
        itemName: existing?.productName ?? id,
        data: existing == null
            ? null
            : {
          'vendor': existing.vendorName,
          'quantity': existing.quantity,
          'amount': existing.amount,
          'reason': existing.reason,
        },
      );
      return {
        'success': true,
        'message': 'Purchase return deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete purchase return: $e',
      };
    }
  }

  // ── GET single purchase return by ID ────────────────────────────────────────
  // Deliberately NOT served from the list cache — used right before a
  // delete to fetch the freshest before-state for activity logging.
  static Future<PurchaseReturn?> getPurchaseReturnById(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return PurchaseReturn.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
    } catch (_) {
      return null;
    }
  }
}