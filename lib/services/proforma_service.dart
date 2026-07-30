// lib/services/proforma_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cda_inventory/models/proforma_invoice.dart';
import 'package:cda_inventory/models/invoice.dart';
import 'package:cda_inventory/models/customer_details.dart';
import 'invoice_service.dart';
import 'activity_log_service.dart';

class ProformaService {
  // ── Firestore collection reference ───────────────────────────────────
  static final CollectionReference<Map<String, dynamic>> _col =
  FirebaseFirestore.instance.collection('proforma_invoices');

  // ── In-memory cache (same pattern as InvoiceService/EstimateService) ──
  static List<ProformaInvoice>? _cache;

  static void clearCache() {
    _cache = null;
  }

  Future<List<ProformaInvoice>> fetchProformas({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;

    final snapshot = await _col.orderBy('updated_at', descending: true).get();

    final list = snapshot.docs
        .map((doc) => ProformaInvoice.fromFirestore(
        doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();

    _cache = list;
    return list;
  }

  Future<ProformaInvoice> fetchProformaById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('Proforma invoice not found');
    }
    return ProformaInvoice.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
  }

  Future<ProformaInvoice> createProforma(ProformaInvoice proforma) async {
    final data = proforma.toFirestore()..['created_at'] = FieldValue.serverTimestamp();
    final docRef = await _col.add(data);
    clearCache();
    ActivityLogService.logAdd(
      module: 'Proforma Invoice',
      itemName: proforma.proformaNo,
      data: {
        'party': proforma.partyName,
        'amount': proforma.grandTotal,
        'status': proforma.status,
      },
    );
    return proforma.copyWith(id: docRef.id);
  }

  Future<ProformaInvoice> updateProforma(ProformaInvoice proforma) async {
    if (proforma.id == null) {
      throw Exception('Cannot update a proforma invoice without an id');
    }
    final existingDoc = await _col.doc(proforma.id).get();
    final before = existingDoc.data() ?? {};
    await _col.doc(proforma.id).update(proforma.toFirestore());
    clearCache();
    ActivityLogService.logEdit(
      module: 'Proforma Invoice',
      itemName: proforma.proformaNo,
      before: {'party': before['party_name'], 'status': before['status']},
      after: {'party': proforma.partyName, 'status': proforma.status},
    );
    return proforma;
  }

  Future<void> deleteProforma(String id) async {
    final existingDoc = await _col.doc(id).get();
    final before = existingDoc.data() ?? {};
    await _col.doc(id).delete();
    clearCache();
    ActivityLogService.logDelete(
      module: 'Proforma Invoice',
      itemName: (before['proforma_no'] as String?) ?? id,
      data: {'party': before['party_name']},
    );
  }

  Future<void> deleteProformasBulk(List<String> ids) async {
    if (ids.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      batch.delete(_col.doc(id));
    }
    await batch.commit();
    clearCache();
    ActivityLogService.logAction(
      'Bulk deleted ${ids.length} proforma invoice(s)',
      module: 'Proforma Invoice',
    );
  }

  Future<bool> proformaNoExists(String proformaNo, {String? excludeId}) async {
    final snapshot = await _col.where('proforma_no', isEqualTo: proformaNo).get();
    if (snapshot.docs.isEmpty) return false;
    if (excludeId == null) return true;
    return snapshot.docs.any((doc) => doc.id != excludeId);
  }

  // ── Next number suggestion, e.g. "PI-0001", "PI-0002" … ───────────────
  Future<String> suggestNextProformaNumber({bool forceRefresh = false}) async {
    final list = await fetchProformas(forceRefresh: forceRefresh);
    int maxNum = 0;
    for (final p in list) {
      final n = int.tryParse(p.proformaNo.replaceAll(RegExp(r'[^0-9]'), ''));
      if (n != null && n > maxNum) maxNum = n;
    }
    return 'PI-${(maxNum + 1).toString().padLeft(4, '0')}';
  }

  Future<List<CustomerDetails>> fetchCustomerSuggestions({bool forceRefresh = false}) async {
    final list = await fetchProformas(forceRefresh: forceRefresh);
    final seen = <String>{};
    final customers = <CustomerDetails>[];
    for (final p in list) {
      final c = p.customer;
      if (c == null || c.name.trim().isEmpty) continue;
      final key = '${c.name.trim().toLowerCase()}|${c.phone ?? ''}';
      if (seen.add(key)) customers.add(c);
    }
    customers.sort((a, b) => a.name.compareTo(b.name));
    return customers;
  }

  /// Converts an Open proforma invoice into a real Sale Invoice — mirrors
  /// Vyapar's "Convert" action on the Proforma Invoice transactions table.
  Future<Invoice> convertToInvoice(ProformaInvoice proforma, {required String newInvoiceNo}) async {
    final invoiceService = InvoiceService();
    final today = DateTime.now();
    final dateStr =
        '${today.day.toString().padLeft(2, '0')}-${today.month.toString().padLeft(2, '0')}-${today.year}';

    final invoice = Invoice(
      invoiceNo: newInvoiceNo,
      purchaseDate: dateStr,
      status: 'Pending',
      lineItems: proforma.lineItems,
      customer: proforma.customer,
      gstEnabled: proforma.gstEnabled,
      cgstPercent: proforma.cgstPercent,
      sgstPercent: proforma.sgstPercent,
      igstPercent: proforma.igstPercent,
      isInterState: proforma.isInterState,
      shipping: proforma.shipping,
      roundOffEnabled: proforma.roundOffEnabled,
      branch: proforma.branch,
      termsTitle: 'Sale Invoice',
      termsNotes: proforma.termsNotes,
      vendorName: proforma.partyName,
    );

    final created = await invoiceService.createInvoice(invoice);

    await updateProforma(proforma.copyWith(
      status: 'Converted',
      convertedInvoiceId: created.id,
      convertedInvoiceNo: created.invoiceNo,
    ));

    ActivityLogService.logAction(
      'Converted proforma invoice ${proforma.proformaNo} to invoice ${created.invoiceNo}',
      module: 'Proforma Invoice',
    );

    return created;
  }
}
