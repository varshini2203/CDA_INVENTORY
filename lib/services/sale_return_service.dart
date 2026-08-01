import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sale_return.dart';
import 'activity_log_service.dart';

class SaleReturnService {
  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('sale_returns');

  // ── IN-MEMORY CACHE (full sale-return list) ───────────────────────────
  static List<SaleReturn>? _cache;

  static void clearCache() => _cache = null;

  // ── GET all sale returns (sorted client-side, no index needed) ────────
  static Future<List<SaleReturn>> getAllSaleReturns({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache != null) return _cache!;
    try {
      final snap = await _col.get();
      final items = snap.docs
          .map((d) =>
          SaleReturn.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      // Sort by return date descending (newest first)
      items.sort((a, b) => b.returnDate.compareTo(a.returnDate));
      _cache = items;
      return items;
    } catch (e) {
      throw Exception('Failed to load sale returns: $e');
    }
  }

  // ── GET sale returns filtered by branch (client-side, no index needed) ─
  static Future<List<SaleReturn>> getSaleReturnsByBranch(
      String branch, {
        bool forceRefresh = false,
      }) async {
    try {
      final all = await getAllSaleReturns(forceRefresh: forceRefresh);
      if (branch == 'All') return all;
      return all.where((s) => s.branch == branch).toList();
    } catch (e) {
      throw Exception('Failed to filter sale returns: $e');
    }
  }

  // ── ADD sale return ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> addSaleReturn(SaleReturn ret) async {
    try {
      final data = ret.toFirestore()..['created_at'] = FieldValue.serverTimestamp();

      final docRef = await _col.add(data);
      clearCache();
      ActivityLogService.logAdd(
        module: 'Sale Returns',
        itemName: ret.productName,
        data: {
          'customer': ret.customerName,
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
        'message': 'Sale return / credit note saved successfully',
        'id': docRef.id,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to save sale return: $e',
      };
    }
  }

  // ── UPDATE sale return ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> updateSaleReturn(String id, SaleReturn ret) async {
    try {
      final before = await getSaleReturnById(id);
      await _col.doc(id).update(ret.toFirestore());
      clearCache();
      if (before != null) {
        ActivityLogService.logEdit(
          module: 'Sale Returns',
          itemName: ret.productName,
          before: {
            'customer': before.customerName,
            'quantity': before.quantity,
            'amount': before.amount,
            'reason': before.reason,
            'reference_invoice': before.referenceInvoice,
            'branch': before.branch,
            'return_date': before.returnDate,
          },
          after: {
            'customer': ret.customerName,
            'quantity': ret.quantity,
            'amount': ret.amount,
            'reason': ret.reason,
            'reference_invoice': ret.referenceInvoice,
            'branch': ret.branch,
            'return_date': ret.returnDate,
          },
        );
      }
      return {
        'success': true,
        'message': 'Sale return / credit note updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update sale return: $e',
      };
    }
  }

  // ── DELETE sale return ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> deleteSaleReturn(String id) async {
    try {
      final existing = await getSaleReturnById(id);
      await _col.doc(id).delete();
      clearCache();
      ActivityLogService.logDelete(
        module: 'Sale Returns',
        itemName: existing?.productName ?? id,
        data: existing == null
            ? null
            : {
          'customer': existing.customerName,
          'quantity': existing.quantity,
          'amount': existing.amount,
          'reason': existing.reason,
        },
      );
      return {
        'success': true,
        'message': 'Sale return deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete sale return: $e',
      };
    }
  }

  // ── GET single sale return by ID ────────────────────────────────────────
  static Future<SaleReturn?> getSaleReturnById(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return SaleReturn.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
    } catch (_) {
      return null;
    }
  }
}