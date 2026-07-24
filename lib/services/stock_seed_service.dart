// lib/services/stock_seed_service.dart
//
// One-time seeding utility that populates the `stock_items` Firestore
// collection (used by the Stock Management dashboard) from the bundled
// SeedStockItems dataset. Safe to run multiple times — it uses the same
// deterministic doc-id scheme as StockService (`product__branch`), so it
// upserts (merge: true) instead of creating duplicates.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cda_inventory/data/seed_stock_items.dart';
import 'package:cda_inventory/services/stock_service.dart';

class StockSeedService {
  StockSeedService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static CollectionReference get _items => _db.collection('stock_items');

  // Firestore treats "/" as a path separator even inside a doc ID string,
  // so any product name containing one (e.g. "Landing Gear/ Stabilizer",
  // "8/16Ch Receiver") silently splits the reference into extra segments
  // and throws invalid-argument. Strip "/" (and other characters Firestore
  // disallows in a document ID: ".", "..", leading "__...__") before
  // collapsing whitespace, so the ID is always a single flat segment.
  static String _itemDocId(String productName, String branch) {
    String safe(String s) => s
        .trim()
        .toLowerCase()
        .replaceAll('/', '-')
        .replaceAll('.', '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return '${safe(productName)}__${safe(branch)}';
  }

  /// Seeds all items from SeedStockItems.items into Firestore.
  /// Returns the number of items written.
  /// [onProgress] is called after each batch commits (0.0–1.0).
  static Future<int> seedAll({void Function(double progress)? onProgress}) async {
    final data = SeedStockItems.items;
    const chunkSize = 400; // stay safely under Firestore's 500 ops/batch limit
    final now = Timestamp.fromDate(DateTime.now());
    int written = 0;

    for (var i = 0; i < data.length; i += chunkSize) {
      final chunk = data.sublist(
        i,
        (i + chunkSize > data.length) ? data.length : i + chunkSize,
      );
      final batch = _db.batch();

      for (final raw in chunk) {
        final productName = raw['product_name'] as String;
        final branch = raw['branch'] as String;
        final docId = _itemDocId(productName, branch);
        final ref = _items.doc(docId);

        batch.set(ref, {
          'product_name': productName,
          'branch': branch,
          'category': raw['category'],
          'quantity': raw['quantity'],
          'min_stock': raw['min_stock'],
          'unit': raw['unit'],
          if ((raw['location'] as String).isNotEmpty)
            'location': raw['location'],
          'updated_at': now,
        }, SetOptions(merge: true));
      }

      await batch.commit();
      written += chunk.length;
      onProgress?.call(written / data.length);
    }

    StockService.clearCache();
    return written;
  }

  /// Quick check used to decide whether to show the "Seed sample data"
  /// prompt — true when stock_items is empty.
  static Future<bool> isEmpty() async {
    final snap = await _items.limit(1).get();
    return snap.docs.isEmpty;
  }
}