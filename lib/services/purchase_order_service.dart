import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase_order.dart';
import 'activity_log_service.dart';

class PurchaseOrderService {
  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('purchase_orders');

  // ── IN-MEMORY CACHE ─────────────────────────────────────────────────────
  // Shared by the Purchases hub, Purchase Order list, Reports, and the
  // vendor-autocomplete lookup on the Add Purchase Order screen — all of
  // which used to trigger their own full-collection read.
  static List<PurchaseOrder>? _cache;

  static void clearCache() => _cache = null;

  // ── GET all purchase orders (sorted client-side, no index needed) ─────────
  static Future<List<PurchaseOrder>> getAllPurchaseOrders({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;
    try {
      final snap = await _col.get();
      final orders = snap.docs
          .map((d) => PurchaseOrder.fromFirestore(
          d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      // Sort by order date descending (newest first)
      orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      _cache = orders;
      return orders;
    } catch (e) {
      throw Exception('Failed to load purchase orders: $e');
    }
  }

  // ── GET purchase orders filtered by branch (client-side, no index needed) ─
  static Future<List<PurchaseOrder>> getPurchaseOrdersByBranch(String branch, {bool forceRefresh = false}) async {
    try {
      final all = await getAllPurchaseOrders(forceRefresh: forceRefresh);
      if (branch == 'All') return all;
      return all.where((p) => p.branch == branch).toList();
    } catch (e) {
      throw Exception('Failed to filter purchase orders: $e');
    }
  }

  // ── ADD purchase order ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> addPurchaseOrder(PurchaseOrder order) async {
    try {
      final data = order.toFirestore()
        ..['created_at'] = FieldValue.serverTimestamp();

      final docRef = await _col.add(data);
      clearCache();
      ActivityLogService.logAdd(
        module: 'Purchase Orders',
        itemName: order.productName,
        data: {
          'vendor': order.vendorName,
          'quantity': order.quantity,
          'expected_cost': order.expectedCost,
          'branch': order.branch,
          'status': order.status,
          'order_date': order.orderDate,
          'expected_delivery': order.expectedDeliveryDate,
        },
      );
      return {
        'success': true,
        'message': 'Purchase order saved successfully',
        'id': docRef.id,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to save purchase order: $e',
      };
    }
  }

  // ── UPDATE purchase order (full field edit, distinct from updateStatus) ───
  static Future<Map<String, dynamic>> updatePurchaseOrder(
      String id, PurchaseOrder order) async {
    try {
      final existing = await getPurchaseOrderById(id);
      await _col.doc(id).update(order.toFirestore()
        ..['updated_at'] = FieldValue.serverTimestamp());
      clearCache();
      ActivityLogService.logEdit(
        module: 'Purchase Orders',
        itemName: order.productName,
        before: existing == null
            ? {}
            : {
          'vendor': existing.vendorName,
          'quantity': existing.quantity,
          'expected_cost': existing.expectedCost,
          'branch': existing.branch,
          'status': existing.status,
          'expected_delivery': existing.expectedDeliveryDate,
          'notes': existing.notes,
        },
        after: {
          'vendor': order.vendorName,
          'quantity': order.quantity,
          'expected_cost': order.expectedCost,
          'branch': order.branch,
          'status': order.status,
          'expected_delivery': order.expectedDeliveryDate,
          'notes': order.notes,
        },
      );
      return {
        'success': true,
        'message': 'Purchase order updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update purchase order: $e',
      };
    }
  }

  // ── UPDATE status (Pending / Received / Cancelled) ─────────────────────────
  static Future<Map<String, dynamic>> updateStatus(String id, String status) async {
    try {
      final existing = await getPurchaseOrderById(id);
      await _col.doc(id).update({'status': status});
      clearCache();
      ActivityLogService.logEdit(
        module: 'Purchase Orders',
        itemName: existing?.productName ?? id,
        before: {'status': existing?.status},
        after: {'status': status},
      );
      return {
        'success': true,
        'message': 'Status updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update status: $e',
      };
    }
  }

  // ── DELETE purchase order ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> deletePurchaseOrder(String id) async {
    try {
      final existing = await getPurchaseOrderById(id);
      await _col.doc(id).delete();
      clearCache();
      ActivityLogService.logDelete(
        module: 'Purchase Orders',
        itemName: existing?.productName ?? id,
        data: existing == null
            ? null
            : {
          'vendor': existing.vendorName,
          'quantity': existing.quantity,
          'expected_cost': existing.expectedCost,
          'status': existing.status,
        },
      );
      return {
        'success': true,
        'message': 'Purchase order deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete purchase order: $e',
      };
    }
  }

  // ── GET single purchase order by ID ──────────────────────────────────────────
  static Future<PurchaseOrder?> getPurchaseOrderById(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return PurchaseOrder.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>);
    } catch (_) {
      return null;
    }
  }

  // ── AGGREGATE: quick counts/totals used by the Purchases hub screen ───────
  static Future<Map<String, dynamic>> getSummary() async {
    try {
      final all = await getAllPurchaseOrders();
      final total = all.fold<double>(0.0, (s, p) => s + (p.expectedCost * p.quantity));
      final pending = all.where((p) => p.status == 'Pending').length;
      return {'count': all.length, 'total': total, 'pending': pending};
    } catch (_) {
      return {'count': 0, 'total': 0.0, 'pending': 0};
    }
  }

  /// Distinct vendor names seen so far, most recent first — powers vendor
  /// autocomplete on the Add Purchase Order screen.
  static Future<List<String>> getKnownVendors() async {
    try {
      final all = await getAllPurchaseOrders();
      final seen = <String>{};
      final vendors = <String>[];
      for (final p in all) {
        if (p.vendorName.trim().isNotEmpty && seen.add(p.vendorName)) {
          vendors.add(p.vendorName);
        }
      }
      return vendors;
    } catch (_) {
      return [];
    }
  }
}