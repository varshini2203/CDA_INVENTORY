import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_out.dart';
import 'activity_log_service.dart';

class PaymentOutService {
  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('payment_outs');

  // ── IN-MEMORY CACHE (full payment-out list) ───────────────────────────────
  // Same pattern now used by PurchaseService/PurchaseOrderService: fetch
  // once, reuse across navigation/rebuilds, invalidate on any write.
  // Previously this collection had no cache of its own — every call to
  // getAllPaymentOuts() hit Firestore directly, so opening the Payment Out
  // list screen re-downloaded the whole collection every time, even right
  // after the Purchases Menu screen had already fetched it a moment
  // earlier.
  static List<PaymentOut>? _cache;

  static void clearCache() => _cache = null;

  // ── GET all payment outs (sorted client-side, no index needed) ────────────
  static Future<List<PaymentOut>> getAllPaymentOuts({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache != null) return _cache!;
    try {
      final snap = await _col.get();
      final payments = snap.docs
          .map((d) => PaymentOut.fromFirestore(
          d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      // Sort by payment date descending (newest first)
      payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
      _cache = payments;
      return payments;
    } catch (e) {
      throw Exception('Failed to load payment outs: $e');
    }
  }

  // ── GET payment outs filtered by branch (client-side, no index needed) ────
  static Future<List<PaymentOut>> getPaymentOutsByBranch(
      String branch, {
        bool forceRefresh = false,
      }) async {
    try {
      final all = await getAllPaymentOuts(forceRefresh: forceRefresh);
      if (branch == 'All') return all;
      return all.where((p) => p.branch == branch).toList();
    } catch (e) {
      throw Exception('Failed to filter payment outs: $e');
    }
  }

  // ── ADD payment out ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> addPaymentOut(PaymentOut payment) async {
    try {
      final data = payment.toFirestore()
        ..['created_at'] = FieldValue.serverTimestamp();

      final docRef = await _col.add(data);
      clearCache();
      ActivityLogService.logAdd(
        module: 'Payments Out',
        itemName: payment.vendorName,
        data: {
          'amount': payment.amount,
          'payment_mode': payment.paymentMode,
          'reference_number': payment.referenceNumber,
          'branch': payment.branch,
          'payment_date': payment.paymentDate,
          'notes': payment.notes,
        },
      );
      return {
        'success': true,
        'message': 'Payment recorded successfully',
        'id': docRef.id,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to save payment: $e',
      };
    }
  }

  // ── UPDATE payment out ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> updatePaymentOut(String id, PaymentOut payment) async {
    try {
      await _col.doc(id).update(payment.toFirestore());
      clearCache();
      ActivityLogService.logAction(
        'Updated payment-out for ${payment.vendorName}',
        module: 'Payments Out',
        details:
        'Amount: ₹${payment.amount}, Mode: ${payment.paymentMode}, Ref: ${payment.referenceNumber}, Branch: ${payment.branch}',
      );
      return {
        'success': true,
        'message': 'Payment updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update payment: $e',
      };
    }
  }

  // ── DELETE payment out ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> deletePaymentOut(String id) async {
    try {
      final existing = await getPaymentOutById(id);
      await _col.doc(id).delete();
      clearCache();
      ActivityLogService.logDelete(
        module: 'Payments Out',
        itemName: existing?.vendorName ?? id,
        data: existing == null
            ? null
            : {
          'amount': existing.amount,
          'payment_mode': existing.paymentMode,
          'branch': existing.branch,
        },
      );
      return {
        'success': true,
        'message': 'Payment deleted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete payment: $e',
      };
    }
  }

  // ── GET single payment out by ID ─────────────────────────────────────────────
  // Deliberately NOT served from the list cache — used right before a
  // delete to fetch the freshest before-state for activity logging.
  static Future<PaymentOut?> getPaymentOutById(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return PaymentOut.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>);
    } catch (_) {
      return null;
    }
  }
}