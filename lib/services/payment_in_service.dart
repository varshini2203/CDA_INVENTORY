// lib/services/payment_in_service.dart
//
// Firestore access for the `payment_ins` collection. Follows the exact
// cache / activity-log pattern already used by PaymentOutService. In
// addition, addPaymentIn() pushes a matching PaymentRecord onto every
// invoice the receipt is allocated against, via InvoiceService.recordPayment,
// so Sale Invoice balance-due / status stay correct automatically.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_in.dart';
import '../models/payment_record.dart';
import 'activity_log_service.dart';
import 'invoice_service.dart';

class PaymentInService {
  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('payment_ins');

  // ── IN-MEMORY CACHE ────────────────────────────────────────────────────
  static List<PaymentIn>? _cache;

  static void clearCache() => _cache = null;

  // ── GET all payment-ins (sorted client-side, no index needed) ──────────
  static Future<List<PaymentIn>> getAllPaymentIns({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache != null) return _cache!;
    try {
      final snap = await _col.get();
      final payments = snap.docs
          .map((d) =>
          PaymentIn.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
      payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
      _cache = payments;
      return payments;
    } catch (e) {
      throw Exception('Failed to load payment-ins: $e');
    }
  }

  // ── GET payment-ins filtered by branch ──────────────────────────────────
  static Future<List<PaymentIn>> getPaymentInsByBranch(
      String branch, {
        bool forceRefresh = false,
      }) async {
    try {
      final all = await getAllPaymentIns(forceRefresh: forceRefresh);
      if (branch == 'All') return all;
      return all.where((p) => p.branch == branch).toList();
    } catch (e) {
      throw Exception('Failed to filter payment-ins: $e');
    }
  }

  // ── ADD payment-in (+ sync every linked invoice's balance) ──────────────
  static Future<Map<String, dynamic>> addPaymentIn(PaymentIn payment) async {
    try {
      final data = payment.toFirestore()
        ..['created_at'] = FieldValue.serverTimestamp();

      final docRef = await _col.add(data);

      final invoiceService = InvoiceService();
      for (final alloc in payment.invoiceAllocations) {
        if (alloc.amountApplied <= 0) continue;
        await invoiceService.recordPayment(
          alloc.invoiceId,
          PaymentRecord(
            id: '${docRef.id}_${alloc.invoiceId}',
            amount: alloc.amountApplied,
            date: DateTime.now(),
            method: payment.paymentMode,
            reference:
            payment.referenceNumber.isEmpty ? null : payment.referenceNumber,
            notes: 'Payment-In receipt for ${payment.customerName}',
          ),
        );
      }

      clearCache();
      ActivityLogService.logAdd(
        module: 'Payments In',
        itemName: payment.customerName,
        data: {
          'amount': payment.amount,
          'payment_mode': payment.paymentMode,
          'reference_number': payment.referenceNumber,
          'branch': payment.branch,
          'payment_date': payment.paymentDate,
          'notes': payment.notes,
          'advance_amount': payment.advanceAmount,
          'invoices_settled':
          payment.invoiceAllocations.map((e) => e.invoiceNo).join(', '),
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

  // ── UPDATE payment-in (+ re-sync invoice balances) ───────────────────────
  // Reverses the old allocation's effect on each invoice's payment list
  // first, then re-applies the (possibly unchanged) new allocations. This
  // keeps invoice balance-due correct even if the customer, amount, or
  // allocations were edited.
  static Future<Map<String, dynamic>> updatePaymentIn(
      String id, PaymentIn payment) async {
    try {
      final existing = await getPaymentInById(id);
      final invoiceService = InvoiceService();

      if (existing != null) {
        for (final oldAlloc in existing.invoiceAllocations) {
          try {
            await invoiceService.removePayment(
                oldAlloc.invoiceId, '${id}_${oldAlloc.invoiceId}');
          } catch (_) {
            // Invoice may have been deleted separately — safe to skip.
          }
        }
      }

      await _col.doc(id).update(payment.toFirestore());

      for (final alloc in payment.invoiceAllocations) {
        if (alloc.amountApplied <= 0) continue;
        try {
          await invoiceService.recordPayment(
            alloc.invoiceId,
            PaymentRecord(
              id: '${id}_${alloc.invoiceId}',
              amount: alloc.amountApplied,
              date: DateTime.now(),
              method: payment.paymentMode,
              reference: payment.referenceNumber.isEmpty
                  ? null
                  : payment.referenceNumber,
              notes: 'Payment-In receipt for ${payment.customerName}',
            ),
          );
        } catch (_) {
          // Invoice may have been deleted separately — safe to skip.
        }
      }

      clearCache();
      ActivityLogService.logAction(
        'Updated payment-in for ${payment.customerName}',
        module: 'Payments In',
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

  // ── DELETE payment-in ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> deletePaymentIn(String id) async {
    try {
      final existing = await getPaymentInById(id);
      await _col.doc(id).delete();
      clearCache();
      ActivityLogService.logDelete(
        module: 'Payments In',
        itemName: existing?.customerName ?? id,
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

  // ── GET single payment-in by ID ─────────────────────────────────────────
  static Future<PaymentIn?> getPaymentInById(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return PaymentIn.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
    } catch (_) {
      return null;
    }
  }
}