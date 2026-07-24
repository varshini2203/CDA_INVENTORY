// lib/services/consumable_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cda_inventory/models/consumable.dart';
import 'package:cda_inventory/data/seed_consumables.dart';
import 'activity_log_service.dart';

class ConsumableService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _collection =
  _firestore.collection('consumables');

  // ── IN-MEMORY CACHE (full consumables list, ordered by name) ─────────────
  // Mirrors the ProductService/StockService pattern: the seeded
  // "consumables" collection has ~700+ documents, and ConsumableListScreen
  // re-ran this query from scratch every time the screen was opened
  // (initState -> loadConsumables()), including every time the app
  // returned to it via back-navigation. That's a full-collection read on
  // every visit. Now we fetch once, reuse across navigation, and only hit
  // Firestore again after a write (add/update/delete/seed) or an explicit
  // forceRefresh. Nothing about what callers receive changes — same data,
  // same ordering — only when a Firestore round-trip actually happens.
  static List<Consumable>? _consumablesCache;

  static void clearCache() {
    _consumablesCache = null;
  }

  /// Fetch all consumables from Firestore (cached after the first call).
  static Future<List<Consumable>> getConsumables({bool forceRefresh = false}) async {
    if (!forceRefresh && _consumablesCache != null) return _consumablesCache!;
    final snapshot = await _collection.orderBy('name').get();
    final list =
    snapshot.docs.map((doc) => Consumable.fromFirestore(doc)).toList();
    _consumablesCache = list;
    return list;
  }

  /// Add a new consumable. Accepts a plain map of field values
  /// (e.g. {'name': ..., 'category': ..., 'quantity': ..., 'minimumStock': ..., 'description': ...}).
  static Future<void> addConsumable(Map<String, dynamic> data) async {
    await _collection.add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
    clearCache();
    ActivityLogService.logAdd(
      module: 'Consumables',
      itemName: (data['name'] as String?) ?? 'New item',
      data: data,
    );
  }

  /// Update an existing consumable by document ID. Accepts a plain map
  /// of the fields to update.
  static Future<void> updateConsumable(
      String id, Map<String, dynamic> data) async {
    final existing = await _collection.doc(id).get();
    final before = (existing.data() as Map<String, dynamic>?) ?? {};
    await _collection.doc(id).update(data);
    clearCache();
    ActivityLogService.logEdit(
      module: 'Consumables',
      itemName: (data['name'] as String?) ?? (before['name'] as String?) ?? id,
      before: before,
      after: {...before, ...data},
    );
  }

  /// Delete a consumable by document ID.
  static Future<void> deleteConsumable(String id) async {
    final existing = await _collection.doc(id).get();
    final before = (existing.data() as Map<String, dynamic>?) ?? {};
    await _collection.doc(id).delete();
    clearCache();
    ActivityLogService.logDelete(
      module: 'Consumables',
      itemName: (before['name'] as String?) ?? id,
      data: before,
    );
  }

  /// Delete every document in the 'consumables' collection. Used to wipe
  /// old/incorrectly-seeded data before a fresh seedConsumables() run —
  /// unlike seedConsumables(), which only ever adds documents and will
  /// duplicate data if run more than once. Batches deletes to stay under
  /// Firestore's 500-write limit. Not individually activity-logged (that'd
  /// be 700+ log entries); logs a single summary entry instead.
  static Future<void> deleteAllConsumables() async {
    final snapshot = await _collection.get();
    final docs = snapshot.docs;

    const chunkSize = 450;
    for (var i = 0; i < docs.length; i += chunkSize) {
      final chunk = docs.sublist(
        i,
        i + chunkSize > docs.length ? docs.length : i + chunkSize,
      );
      final batch = _firestore.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    clearCache();
    ActivityLogService.logDelete(
      module: 'Consumables',
      itemName: 'All consumables (${docs.length} items)',
      data: {'count': docs.length, 'reason': 'wipe before reseed'},
    );
  }

  /// Bulk-upload the master inventory list from the CDA spreadsheet.
  /// Splits writes into batches to stay under Firestore's 500-write limit.
  static Future<void> seedConsumables() async {
    final items = SeedConsumables.items;

    const chunkSize = 450;
    for (var i = 0; i < items.length; i += chunkSize) {
      final chunk = items.sublist(
        i,
        i + chunkSize > items.length ? items.length : i + chunkSize,
      );

      final batch = _firestore.batch();
      for (final item in chunk) {
        final docRef = _collection.doc();
        // The seed data's 'notes' field holds the branch's *display* label
        // ("CDA Admin" / "CDA Ops"), but the 'branch' field on each document
        // must store the raw values the list screen filters against
        // ("Branch 1" / "Branch 2") — Consumable.belongsToBranch() and the
        // branch chips in ConsumableListScreen both compare against the raw
        // form. Translate the label to the raw value before writing so the
        // branch filter actually matches.
        batch.set(docRef, {
          'name': item['name'],
          'category': item['category'],
          'quantity': item['quantity'],
          'minimumStock': item['minStock'],
          'branch': _rawBranchFromLabel(item['notes'] ?? ''),
          'description': item['unit'].toString().isNotEmpty
              ? 'Unit: ${item['unit']}'
              : '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
    clearCache();
  }

  /// Maps a seed-data branch label ("CDA Admin" / "CDA Ops", possibly
  /// comma-joined for items in both) back to the raw branch value that
  /// Consumable.belongsToBranch() and the branch filter chips compare
  /// against ("Branch 1" / "Branch 2"). Anything unrecognized passes
  /// through unchanged.
  static String _rawBranchFromLabel(String label) {
    const labelToRaw = {
      'CDA Admin': 'Branch 1',
      'CDA Ops': 'Branch 2',
    };
    if (label.isEmpty) return '';
    return label
        .split(',')
        .map((e) => e.trim())
        .map((e) => labelToRaw[e] ?? e)
        .join(', ');
  }
}