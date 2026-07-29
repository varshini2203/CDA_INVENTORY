// lib/services/delivery_challan_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cda_inventory/models/delivery_challan.dart';
import 'package:cda_inventory/models/invoice.dart';
import 'invoice_service.dart';
import 'activity_log_service.dart';

class DeliveryChallanService {
  static final CollectionReference<Map<String, dynamic>> _col =
  FirebaseFirestore.instance.collection('delivery_challans');

  static List<DeliveryChallan>? _cache;
  static void clearCache() => _cache = null;

  static const String _codeChars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static final Random _rand = Random();

  static Future<List<DeliveryChallan>> fetchChallans({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;
    final snap = await _col.get();
    final challans = snap.docs
        .map((d) => DeliveryChallan.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
        .toList()
      ..sort((a, b) => b.challanDate.compareTo(a.challanDate));
    _cache = challans;
    return challans;
  }

  static Future<DeliveryChallan> fetchChallanById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('Delivery challan not found');
    }
    return DeliveryChallan.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
  }

  static Future<String> generateChallanNo() async {
    final ts = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final code = List.generate(4, (_) => _codeChars[_rand.nextInt(_codeChars.length)]).join();
    return 'DC-$code-$ts';
  }

  static Future<DeliveryChallan> createChallan(DeliveryChallan challan) async {
    final data = challan.toFirestore()..['created_at'] = FieldValue.serverTimestamp();
    final ref = await _col.add(data);
    clearCache();
    ActivityLogService.logAdd(
      module: 'Delivery Challan',
      itemName: challan.challanNo,
      data: {
        'customer': challan.customer?.name,
        'amount': challan.grandTotal,
        'branch': challan.branch,
        'status': challan.status,
      },
    );
    return challan.copyWith(id: ref.id);
  }

  static Future<void> updateChallan(DeliveryChallan challan) async {
    if (challan.id == null) return;
    final existingDoc = await _col.doc(challan.id).get();
    final before = existingDoc.data() ?? {};
    await _col.doc(challan.id).update(challan.toFirestore());
    clearCache();
    ActivityLogService.logEdit(
      module: 'Delivery Challan',
      itemName: challan.challanNo,
      before: {'status': before['status'], 'amount': before['grand_total']},
      after: {'status': challan.status, 'amount': challan.grandTotal},
    );
  }

  static Future<void> updateStatus(String id, String status) async {
    final doc = await _col.doc(id).get();
    final before = doc.data() ?? {};
    await _col.doc(id).update({'status': status});
    clearCache();
    ActivityLogService.logEdit(
      module: 'Delivery Challan',
      itemName: (before['challan_no'] as String?) ?? id,
      before: {'status': before['status']},
      after: {'status': status},
    );
  }

  static Future<void> deleteChallan(String id) async {
    final doc = await _col.doc(id).get();
    final before = doc.data();
    await _col.doc(id).delete();
    clearCache();
    ActivityLogService.logDelete(
      module: 'Delivery Challan',
      itemName: (before?['challan_no'] as String?) ?? id,
      data: before,
    );
  }

  static Future<void> deleteChallansBulk(List<String> ids) async {
    if (ids.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      batch.delete(_col.doc(id));
    }
    await batch.commit();
    clearCache();
    ActivityLogService.logAction(
      'Bulk deleted ${ids.length} delivery challan(s)',
      module: 'Delivery Challan',
    );
  }

  /// Converts a delivery challan into a real Sale Invoice — mirrors Vyapar's
  /// "Convert" action on the Delivery Challan transactions table.
  static Future<Invoice> convertToInvoice(DeliveryChallan challan, {required String newInvoiceNo}) async {
    final invoiceService = InvoiceService();
    final today = DateTime.now();
    final dateStr =
        '${today.day.toString().padLeft(2, '0')}-${today.month.toString().padLeft(2, '0')}-${today.year}';

    final invoice = Invoice(
      invoiceNo: newInvoiceNo,
      purchaseDate: dateStr,
      status: 'Pending',
      lineItems: challan.lineItems,
      customer: challan.customer,
      gstEnabled: challan.gstEnabled,
      cgstPercent: challan.cgstPercent,
      sgstPercent: challan.sgstPercent,
      igstPercent: challan.igstPercent,
      isInterState: challan.isInterState,
      shipping: challan.shipping,
      roundOffEnabled: challan.roundOffEnabled,
      branch: challan.branch,
      termsTitle: 'Sale Invoice',
      termsNotes: challan.notes,
      vendorName: challan.customer?.name ?? '',
    );

    final created = await invoiceService.createInvoice(invoice);

    final updated = challan.copyWith(
      status: 'Converted',
      convertedInvoiceId: created.id,
      convertedInvoiceNo: created.invoiceNo,
    );
    await updateChallan(updated);

    ActivityLogService.logAction(
      'Converted delivery challan ${challan.challanNo} to invoice ${created.invoiceNo}',
      module: 'Delivery Challan',
    );

    return created;
  }

  static Future<bool> challanNoExists(String challanNo, {String? excludeId}) async {
    final snapshot = await _col.where('challan_no', isEqualTo: challanNo).get();
    if (snapshot.docs.isEmpty) return false;
    if (excludeId == null) return true;
    return snapshot.docs.any((doc) => doc.id != excludeId);
  }
}