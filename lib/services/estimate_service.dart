// lib/services/estimate_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cda_inventory/models/estimate.dart';
import 'package:cda_inventory/models/invoice.dart';
import 'package:cda_inventory/models/customer_details.dart';
import 'invoice_service.dart';
import 'activity_log_service.dart';

class EstimateService {
  static final CollectionReference<Map<String, dynamic>> _col =
  FirebaseFirestore.instance.collection('estimates');

  static List<Estimate>? _estimatesCache;

  static void clearCache() {
    _estimatesCache = null;
  }

  Future<List<Estimate>> fetchEstimates({bool forceRefresh = false}) async {
    if (!forceRefresh && _estimatesCache != null) return _estimatesCache!;

    final snapshot = await _col.orderBy('updated_at', descending: true).get();

    final list = snapshot.docs
        .map((doc) =>
        Estimate.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();

    _estimatesCache = list;
    return list;
  }

  Future<Estimate> fetchEstimateById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('Estimate not found');
    }
    return Estimate.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
  }

  Future<Estimate> createEstimate(Estimate estimate) async {
    final data = estimate.toFirestore()..['created_at'] = FieldValue.serverTimestamp();
    final docRef = await _col.add(data);
    clearCache();
    ActivityLogService.logAdd(
      module: 'Estimates',
      itemName: estimate.referenceNo,
      data: {
        'party': estimate.partyName,
        'amount': estimate.grandTotal,
        'status': estimate.status,
      },
    );
    return estimate.copyWith(id: docRef.id);
  }

  Future<Estimate> updateEstimate(Estimate estimate) async {
    if (estimate.id == null) {
      throw Exception('Cannot update an estimate without an id');
    }
    final existingDoc = await _col.doc(estimate.id).get();
    final before = existingDoc.data() ?? {};
    await _col.doc(estimate.id).update(estimate.toFirestore());
    clearCache();
    ActivityLogService.logEdit(
      module: 'Estimates',
      itemName: estimate.referenceNo,
      before: {'party': before['party_name'], 'status': before['status']},
      after: {'party': estimate.partyName, 'status': estimate.status},
    );
    return estimate;
  }

  Future<void> deleteEstimate(String id) async {
    final existingDoc = await _col.doc(id).get();
    final before = existingDoc.data() ?? {};
    await _col.doc(id).delete();
    clearCache();
    ActivityLogService.logDelete(
      module: 'Estimates',
      itemName: (before['reference_no'] as String?) ?? id,
      data: {'party': before['party_name']},
    );
  }

  Future<void> deleteEstimatesBulk(List<String> ids) async {
    if (ids.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      batch.delete(_col.doc(id));
    }
    await batch.commit();
    clearCache();
    ActivityLogService.logAction(
      'Bulk deleted ${ids.length} estimate(s)',
      module: 'Estimates',
    );
  }

  Future<bool> referenceNoExists(String referenceNo, {String? excludeId}) async {
    final snapshot = await _col.where('reference_no', isEqualTo: referenceNo).get();
    if (snapshot.docs.isEmpty) return false;
    if (excludeId == null) return true;
    return snapshot.docs.any((doc) => doc.id != excludeId);
  }

  Future<String> suggestNextReferenceNumber({bool forceRefresh = false}) async {
    final list = await fetchEstimates(forceRefresh: forceRefresh);
    int maxNum = 0;
    for (final e in list) {
      final n = int.tryParse(e.referenceNo.replaceAll(RegExp(r'[^0-9]'), ''));
      if (n != null && n > maxNum) maxNum = n;
    }
    return (maxNum + 1).toString();
  }

  Future<List<CustomerDetails>> fetchCustomerSuggestions({bool forceRefresh = false}) async {
    final list = await fetchEstimates(forceRefresh: forceRefresh);
    final seen = <String>{};
    final customers = <CustomerDetails>[];
    for (final e in list) {
      final c = e.customer;
      if (c == null || c.name.trim().isEmpty) continue;
      final key = '${c.name.trim().toLowerCase()}|${c.phone ?? ''}';
      if (seen.add(key)) customers.add(c);
    }
    customers.sort((a, b) => a.name.compareTo(b.name));
    return customers;
  }

  /// Converts an Open estimate into a Sale Invoice — mirrors Vyapar's
  /// "Convert" action in the Estimate/Quotation transactions table.
  Future<Invoice> convertToInvoice(Estimate estimate, {required String newInvoiceNo}) async {
    final invoiceService = InvoiceService();
    final today = DateTime.now();
    final dateStr =
        '${today.day.toString().padLeft(2, '0')}-${today.month.toString().padLeft(2, '0')}-${today.year}';

    final invoice = Invoice(
      invoiceNo: newInvoiceNo,
      purchaseDate: dateStr,
      status: 'Pending',
      lineItems: estimate.lineItems,
      customer: estimate.customer,
      gstEnabled: estimate.gstEnabled,
      cgstPercent: estimate.cgstPercent,
      sgstPercent: estimate.sgstPercent,
      igstPercent: estimate.igstPercent,
      isInterState: estimate.isInterState,
      shipping: estimate.shipping,
      roundOffEnabled: estimate.roundOffEnabled,
      branch: estimate.branch,
      termsTitle: 'Sale Invoice',
      termsNotes: estimate.termsNotes,
      vendorName: estimate.partyName,
    );

    final created = await invoiceService.createInvoice(invoice);

    await updateEstimate(estimate.copyWith(
      status: 'Converted',
      convertedInvoiceId: created.id,
      convertedInvoiceNo: created.invoiceNo,
    ));

    ActivityLogService.logAction(
      'Converted estimate ${estimate.referenceNo} to invoice ${created.invoiceNo}',
      module: 'Estimates',
    );

    return created;
  }
}