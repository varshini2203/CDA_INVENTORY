// lib/services/invoice_service.dart

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cda_inventory/models/invoice.dart';
import 'package:cda_inventory/models/payment_record.dart';
import 'package:cda_inventory/models/recurring_config.dart';
import 'package:cda_inventory/models/customer_details.dart';
import '../constants/gamification_constants.dart';
import 'activity_log_service.dart';
import 'gamification_service.dart';
import 'staff_reward_service.dart';

class InvoiceService {
  // ── Firestore collection reference ──────────────────────────────────────────
  static final CollectionReference<Map<String, dynamic>> _col =
  FirebaseFirestore.instance.collection('invoices');

  // ── IN-MEMORY CACHE (full invoice list, ordered by last update) ──────────
  // Same pattern as ProductService/InventoryService/DroneService/StockService:
  // fetch once, reuse across navigation/rebuilds, invalidate on any write.
  // Previously fetchInvoices() hit Firestore on every single call — every
  // time the Invoice List screen was opened, including simply navigating
  // away and back — re-downloading the entire `invoices` collection each
  // time. Now it's read once per session (or since the last write) and
  // reused.
  static List<Invoice>? _invoicesCache;

  static void clearCache() {
    _invoicesCache = null;
  }

  // ── GET all invoices (ordered by last update descending, cached) ────────────
  Future<List<Invoice>> fetchInvoices({bool forceRefresh = false}) async {
    if (!forceRefresh && _invoicesCache != null) return _invoicesCache!;

    final snapshot = await _col
        .orderBy('updated_at', descending: true)
        .get();

    final list = snapshot.docs
        .map((doc) => Invoice.fromFirestore(
        doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();

    _invoicesCache = list;
    return list;
  }

  // ── GET single invoice by Firestore doc ID ───────────────────────────────────
  // Deliberately NOT served from the list cache — the detail screen wants
  // the freshest single-document state (e.g. right after a deep link or a
  // payment recorded elsewhere), and a single-doc read is cheap regardless.
  Future<Invoice> fetchInvoiceById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('Invoice not found');
    }
    return Invoice.fromFirestore(
        doc as DocumentSnapshot<Map<String, dynamic>>);
  }

  // ── POST — create new invoice ────────────────────────────────────────────────
  Future<Invoice> createInvoice(Invoice invoice) async {
    final data = invoice.toFirestore()
      ..['created_at'] = FieldValue.serverTimestamp();

    final docRef = await _col.add(data);
    clearCache();
    ActivityLogService.logAdd(
      module: 'Invoices',
      itemName: invoice.invoiceNo,
      data: {
        'vendor': invoice.vendorName,
        'amount': invoice.amount,
        'status': invoice.status,
        'due_date': invoice.dueDate,
      },
    );
    StaffRewardService.recordActivity(
      action: StaffAction.invoiceUpload,
      module: 'Invoices',
      refId: 'invoices_${docRef.id}_add',
    );

    // The Firestore add + activity log above already succeeded, so
    // it's safe to award XP exactly once for this invoice. Best
    // effort: a gamification hiccup must never block invoice creation.
    try {
      await GamificationService.recordInvoiceUploaded();
    } catch (_) {}

    return invoice.copyWith(id: docRef.id);
  }

  // ── PUT — update existing invoice ────────────────────────────────────────────
  Future<Invoice> updateInvoice(Invoice invoice) async {
    if (invoice.id == null) {
      throw Exception('Cannot update an invoice without an id');
    }
    final existingDoc = await _col.doc(invoice.id).get();
    final before = existingDoc.data() ?? {};
    await _col.doc(invoice.id).update(invoice.toFirestore());
    clearCache();
    ActivityLogService.logEdit(
      module: 'Invoices',
      itemName: invoice.invoiceNo,
      before: {
        'vendor': before['vendor_name'],
        'amount': before['amount'],
        'status': before['status'],
        'due_date': before['due_date'],
      },
      after: {
        'vendor': invoice.vendorName,
        'amount': invoice.amount,
        'status': invoice.status,
        'due_date': invoice.dueDate,
      },
    );
    return invoice;
  }

  // ── DELETE ───────────────────────────────────────────────────────────────────
  Future<void> deleteInvoice(String id) async {
    final existingDoc = await _col.doc(id).get();
    final before = existingDoc.data() ?? {};
    await _col.doc(id).delete();
    clearCache();
    ActivityLogService.logDelete(
      module: 'Invoices',
      itemName: (before['invoice_no'] as String?) ?? id,
      data: {
        'vendor': before['vendor_name'],
        'amount': before['amount'],
        'status': before['status'],
      },
    );
  }

  // ── DELETE multiple invoices in one batch (bulk / multi-select delete) ──────
  Future<void> deleteInvoicesBulk(List<String> ids) async {
    if (ids.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      batch.delete(_col.doc(id));
    }
    await batch.commit();
    clearCache();
    ActivityLogService.logAction(
      'Bulk deleted ${ids.length} invoice(s)',
      module: 'Invoices',
    );
  }

  // ── Duplicate invoice-number check (used before create/update) ──────────────
  // Left as a direct Firestore query rather than served from the cache —
  // this needs to be correct against the server at save time (two admins
  // could be creating invoices concurrently), not against a possibly-stale
  // in-memory snapshot. It's already a targeted `where()` query, not a full
  // collection read, so it isn't part of the read-cost problem this cache
  // fixes.
  Future<bool> invoiceNumberExists(String invoiceNo, {String? excludeId}) async {
    final snapshot =
    await _col.where('invoice_no', isEqualTo: invoiceNo).get();
    if (snapshot.docs.isEmpty) return false;
    if (excludeId == null) return true;
    return snapshot.docs.any((doc) => doc.id != excludeId);
  }

  // ── Distinct vendor names, for autocomplete suggestions ──────────────────────
  // Now derived from the same cached invoice list instead of issuing its
  // own separate full-collection read — callers that already triggered
  // fetchInvoices() this session (e.g. opening the Invoice List screen
  // first) get this for free.
  Future<List<String>> fetchVendorNames({bool forceRefresh = false}) async {
    final invoices = await fetchInvoices(forceRefresh: forceRefresh);
    final names = invoices
        .map((inv) => inv.vendorName)
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    names.sort();
    return names;
  }

  // ── Distinct customers (name + phone), for the Sale invoice "Search by
  // Name/Phone" field. Derived from the same cached invoice list — no
  // extra Firestore read beyond what fetchInvoices() already does.
  Future<List<CustomerDetails>> fetchCustomerSuggestions({bool forceRefresh = false}) async {
    final invoices = await fetchInvoices(forceRefresh: forceRefresh);
    final seen = <String>{};
    final customers = <CustomerDetails>[];
    for (final inv in invoices) {
      final c = inv.customer;
      if (c == null || c.name.trim().isEmpty) continue;
      final key = '${c.name.trim().toLowerCase()}|${c.phone ?? ''}';
      if (seen.add(key)) customers.add(c);
    }
    customers.sort((a, b) => a.name.compareTo(b.name));
    return customers;
  }

  // ── Random invoice number generator ───────────────────────────────────────
  // Each invoice gets a date-stamped, unique code (e.g. "INV-230726-4F2K")
  // instead of a plain running count (1, 2, 3…). The date prefix (DDMMYY)
  // makes it easy to tell at a glance when an invoice was raised; the random
  // suffix guarantees uniqueness even when several invoices are made the
  // same day. Excludes easily-confused characters (0/O, 1/I).
  static const String _codeChars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static final Random _rand = Random();

  String _randomInvoiceSuffix({int length = 4}) {
    return List.generate(
      length,
          (_) => _codeChars[_rand.nextInt(_codeChars.length)],
    ).join();
  }

  String _datePrefix() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(now.day)}${two(now.month)}${two(now.year % 100)}';
  }

  // ── Next invoice number suggestion (e.g. "INV-230726-4F2K") ───────────────
  // Generates a date-prefixed code and checks it against existing invoices
  // so each one is guaranteed unique, retrying a few times on the (very
  // unlikely) chance of a same-day collision before falling back to a
  // timestamp-based suffix.
  Future<String> suggestNextInvoiceNumber({bool forceRefresh = false}) async {
    final prefix = _datePrefix();
    for (int attempt = 0; attempt < 8; attempt++) {
      final candidate = 'INV-$prefix-${_randomInvoiceSuffix()}';
      final exists = await invoiceNumberExists(candidate);
      if (!exists) return candidate;
    }
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    return 'INV-$prefix-$ts';
  }

  // ── Quick status update (e.g. "Mark as Paid") without touching other fields ─
  Future<void> updateStatus(String id, String status) async {
    final existingDoc = await _col.doc(id).get();
    final before = existingDoc.data() ?? {};
    await _col.doc(id).update({
      'status': status,
      'updated_at': FieldValue.serverTimestamp(),
    });
    clearCache();
    ActivityLogService.logEdit(
      module: 'Invoices',
      itemName: (before['invoice_no'] as String?) ?? id,
      before: {'status': before['status']},
      after: {'status': status},
    );
  }

  // ── Record a payment against an invoice ──────────────────────────────────
  Future<void> recordPayment(String invoiceId, PaymentRecord payment) async {
    final doc = await _col.doc(invoiceId).get();
    if (!doc.exists) throw Exception('Invoice not found');
    final invoice =
    Invoice.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
    final updatedPayments = [...invoice.payments, payment];
    final updated = invoice.copyWith(
      payments: updatedPayments,
      status: (invoice.grandTotal -
          updatedPayments.fold(0.0, (s, p) => s + p.amount)) <=
          0.01
          ? 'Paid'
          : invoice.status,
    );
    await _col.doc(invoiceId).update(updated.toFirestore());
    clearCache();
    ActivityLogService.logAdd(
      module: 'Invoices',
      itemName: '${invoice.invoiceNo} — Payment',
      data: {
        'amount': payment.amount,
        'new_status': updated.status,
      },
    );
  }

  Future<void> removePayment(String invoiceId, String paymentId) async {
    final doc = await _col.doc(invoiceId).get();
    if (!doc.exists) throw Exception('Invoice not found');
    final invoice =
    Invoice.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
    final updatedPayments =
    invoice.payments.where((p) => p.id != paymentId).toList();
    await _col
        .doc(invoiceId)
        .update(invoice.copyWith(payments: updatedPayments).toFirestore());
    clearCache();
    ActivityLogService.logDelete(
      module: 'Invoices',
      itemName: '${invoice.invoiceNo} — Payment',
      data: {'payment_id': paymentId},
    );
  }

  // ── Recurring: find invoices due for regeneration and clone them forward ──
  // Kept as a direct query (not the cache) — this scans for a specific
  // server-side condition (`recurring.is_recurring == true`), which is
  // usually a small subset of the collection, and correctness here matters
  // more than shaving one query, since it drives auto-generation of new
  // invoice documents.
  Future<List<Invoice>> generateDueRecurringInvoices() async {
    final now = DateTime.now();
    final snapshot =
    await _col.where('recurring.is_recurring', isEqualTo: true).get();
    final generated = <Invoice>[];

    for (final doc in snapshot.docs) {
      final invoice = Invoice.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>);
      final nextGen = invoice.recurring.nextGenerationDate;
      if (nextGen == null || nextGen.isAfter(now)) continue;
      if (invoice.recurring.endDate != null &&
          now.isAfter(invoice.recurring.endDate!)) continue;

      DateTime advance(DateTime d, String freq) {
        switch (freq) {
          case 'Weekly':
            return d.add(const Duration(days: 7));
          case 'Quarterly':
            return DateTime(d.year, d.month + 3, d.day);
          case 'Yearly':
            return DateTime(d.year + 1, d.month, d.day);
          default:
            return DateTime(d.year, d.month + 1, d.day); // Monthly
        }
      }

      final newDueDate = advance(nextGen, invoice.recurring.frequency);
      final clone = invoice.copyWith(
        clearId: true,
        invoiceNo:
        '${invoice.invoiceNo}-R${DateTime.now().millisecondsSinceEpoch % 10000}',
        purchaseDate:
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}',
        dueDate:
        '${newDueDate.day.toString().padLeft(2, '0')}-${newDueDate.month.toString().padLeft(2, '0')}-${newDueDate.year}',
        status: 'Pending',
        payments: [],
        recurring: RecurringConfig(
          isRecurring: true,
          frequency: invoice.recurring.frequency,
          nextGenerationDate: newDueDate,
          endDate: invoice.recurring.endDate,
          reminderDaysBeforeDue: invoice.recurring.reminderDaysBeforeDue,
        ),
      );
      // createInvoice() already calls clearCache() internally, so the
      // cache stays correct even when this loop generates several new
      // invoices in a row.
      final created = await createInvoice(clone);
      generated.add(created);
    }
    return generated;
  }

  // ── Invoices with a due-date reminder firing today ──────────────────────
  Future<List<Invoice>> fetchDueReminders() async {
    final all = await fetchInvoices();
    final now = DateTime.now();
    return all.where((inv) {
      if (inv.isFullyPaid) return false;
      final due = inv.dueDateTime;
      if (due == null) return false;
      final daysUntil = due.difference(now).inDays;
      return daysUntil >= 0 && daysUntil <= inv.recurring.reminderDaysBeforeDue;
    }).toList();
  }
}