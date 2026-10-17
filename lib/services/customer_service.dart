// lib/services/customer_service.dart
//
// Central customer (party) master stored in the Firestore `customers`
// collection. Every invoice save upserts the customer here, and the
// invoice form reads from here to auto-fill all customer details.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cda_inventory/models/customer_details.dart';
import 'activity_log_service.dart';

class CustomerService {
  static final CollectionReference<Map<String, dynamic>> _col =
  FirebaseFirestore.instance.collection('customers');

  static List<CustomerDetails>? _cache;

  static void clearCache() => _cache = null;

  static String? _clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  // ── GET all customers (cached, sorted by name) ────────────────────────────
  Future<List<CustomerDetails>> fetchCustomers({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;
    final snap = await _col.get();
    final list = snap.docs
        .map((d) => CustomerDetails.fromFirestore(
        d as DocumentSnapshot<Map<String, dynamic>>))
        .where((c) => c.name.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.nameKey.compareTo(b.nameKey));
    _cache = list;
    return list;
  }

  // ── Duplicate lookup (phone first, then exact name) ───────────────────────
  Future<CustomerDetails?> findExisting({
    required String name,
    String? phone,
    String? excludeId,
  }) async {
    final all = await fetchCustomers();
    final probe = CustomerDetails(name: name, phone: phone);
    for (final c in all) {
      if (c.id == excludeId) continue;
      if (probe.phoneKey.isNotEmpty && c.phoneKey == probe.phoneKey) return c;
    }
    for (final c in all) {
      if (c.id == excludeId) continue;
      if (c.nameKey == probe.nameKey &&
          (probe.phoneKey.isEmpty || c.phoneKey.isEmpty)) {
        return c;
      }
    }
    return null;
  }

  // ── POST ──────────────────────────────────────────────────────────────────
  Future<CustomerDetails> addCustomer(CustomerDetails c) async {
    final data = c.toFirestore()..['created_at'] = FieldValue.serverTimestamp();
    final ref = await _col.add(data);
    clearCache();
    ActivityLogService.logAdd(
      module: 'Customers',
      itemName: c.name,
      data: {'phone': c.phone, 'gstin': c.gstin},
    );
    return c.copyWith(id: ref.id);
  }

  // ── PUT ───────────────────────────────────────────────────────────────────
  Future<void> updateCustomer(CustomerDetails c) async {
    if (c.id == null) throw Exception('Cannot update a customer without an id');
    await _col.doc(c.id).update(c.toFirestore());
    clearCache();
    ActivityLogService.logEdit(
      module: 'Customers',
      itemName: c.name,
      before: const {},
      after: {'phone': c.phone, 'gstin': c.gstin},
    );
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  Future<void> deleteCustomer(CustomerDetails c) async {
    if (c.id == null) return;
    await _col.doc(c.id).delete();
    clearCache();
    ActivityLogService.logDelete(
      module: 'Customers',
      itemName: c.name,
      data: {'phone': c.phone, 'gstin': c.gstin},
    );
  }

  // ── Auto-save from a transaction (invoice etc.) ───────────────────────────
  // Creates the customer if new; otherwise fills/updates the stored record
  // with any non-empty details from the transaction. Never throws.
  static Future<void> upsertFromTransaction(CustomerDetails? c) async {
    try {
      if (c == null || c.name.trim().isEmpty) return;
      final svc = CustomerService();
      final existing = await svc.findExisting(name: c.name, phone: c.phone);
      if (existing == null) {
        await svc.addCustomer(CustomerDetails(
          name: c.name.trim(),
          phone: _clean(c.phone),
          email: _clean(c.email),
          gstin: _clean(c.gstin),
          billingAddress: _clean(c.billingAddress),
          shippingAddress: _clean(c.shippingAddress),
          placeOfSupply: c.placeOfSupply,
        ));
        return;
      }
      final merged = existing.copyWith(
        name: c.name.trim(),
        phone: _clean(c.phone) ?? existing.phone,
        email: _clean(c.email) ?? existing.email,
        gstin: _clean(c.gstin) ?? existing.gstin,
        billingAddress: _clean(c.billingAddress) ?? existing.billingAddress,
        shippingAddress: _clean(c.shippingAddress) ?? existing.shippingAddress,
        placeOfSupply: c.placeOfSupply,
      );
      final changed = merged.name != existing.name ||
          merged.phone != existing.phone ||
          merged.email != existing.email ||
          merged.gstin != existing.gstin ||
          merged.billingAddress != existing.billingAddress ||
          merged.shippingAddress != existing.shippingAddress ||
          merged.placeOfSupply != existing.placeOfSupply;
      if (changed) await svc.updateCustomer(merged);
    } catch (_) {
      // Best effort — saving a customer must never block saving an invoice.
    }
  }

  // ── Suggestions for the invoice form: saved customers first, then any
  //    customers found only inside older invoices ────────────────────────────
  Future<List<CustomerDetails>> fetchSuggestions(
      List<CustomerDetails> legacy) async {
    List<CustomerDetails> saved = [];
    try {
      saved = await fetchCustomers();
    } catch (_) {}
    final out = <CustomerDetails>[...saved];
    final seen = <String>{
      for (final c in saved)
        c.phoneKey.isNotEmpty ? 'p:${c.phoneKey}' : 'n:${c.nameKey}',
    };
    final savedNames = {for (final c in saved) c.nameKey};
    for (final c in legacy) {
      if (c.name.trim().isEmpty) continue;
      final key = c.phoneKey.isNotEmpty ? 'p:${c.phoneKey}' : 'n:${c.nameKey}';
      if (seen.contains(key)) continue;
      if (c.phoneKey.isEmpty && savedNames.contains(c.nameKey)) continue;
      seen.add(key);
      out.add(c);
    }
    out.sort((a, b) => a.nameKey.compareTo(b.nameKey));
    return out;
  }

  // ── One-time import of customers already present in old invoices ──────────
  Future<int> importFromDetails(List<CustomerDetails> list) async {
    var added = 0;
    for (final c in list) {
      if (c.name.trim().isEmpty) continue;
      final existing = await findExisting(name: c.name, phone: c.phone);
      if (existing != null) continue;
      await addCustomer(CustomerDetails(
        name: c.name.trim(),
        phone: _clean(c.phone),
        email: _clean(c.email),
        gstin: _clean(c.gstin),
        billingAddress: _clean(c.billingAddress),
        shippingAddress: _clean(c.shippingAddress),
        placeOfSupply: c.placeOfSupply,
      ));
      added++;
    }
    return added;
  }
}