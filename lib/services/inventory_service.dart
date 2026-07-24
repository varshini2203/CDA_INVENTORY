// lib/services/inventory_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_model.dart';

class InventoryService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  InventoryService._internal();
  static final InventoryService _instance = InventoryService._internal();
  factory InventoryService() => _instance;

  // ── Firestore reference ────────────────────────────────────────────────────
  final CollectionReference<Map<String, dynamic>> _col =
  FirebaseFirestore.instance.collection('inventory');

  // ── IN-MEMORY CACHE (full inventory list, ordered by name) ───────────────
  // Same pattern as DroneService/ProductService: fetch once, reuse across
  // navigation/rebuilds, invalidate on any write. InventoryService is
  // already a singleton, so a static field is shared by every caller.
  static List<InventoryItem>? _inventoryCache;

  static void clearCache() {
    _inventoryCache = null;
  }

  // ── GET ALL (cached one-shot) ─────────────────────────────────────────────
  Future<List<InventoryItem>> getInventory({bool forceRefresh = false}) async {
    if (!forceRefresh && _inventoryCache != null) return _inventoryCache!;
    final snapshot = await _col.orderBy('name').get();
    final list = snapshot.docs.map(InventoryItem.fromDoc).toList();
    _inventoryCache = list;
    return list;
  }

  // ── REAL-TIME STREAM ───────────────────────────────────────────────────────
  Stream<List<InventoryItem>> watchInventory() {
    return _col.orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs.map(InventoryItem.fromDoc).toList(),
    );
  }

  // ── ADD ────────────────────────────────────────────────────────────────────
  Future<InventoryItem> addProduct({
    required String name,
    required String category,
    required String location,
    required int quantity,
    String description = '',
    int branch = 0,
    String? addedBy,
  }) async {
    final item = InventoryItem(
      id: '',
      name: name.trim(),
      category: category,
      location: location.trim(),
      quantity: quantity,
      description: description.trim(),
      branch: branch,
      addedBy: addedBy,
    );

    final docRef = await _col.add(item.toCreateMap());
    clearCache();
    return InventoryItem(
      id: docRef.id,
      name: item.name,
      category: item.category,
      location: item.location,
      quantity: item.quantity,
      description: item.description,
      branch: item.branch,
      addedBy: item.addedBy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // ── UPDATE ─────────────────────────────────────────────────────────────────
  Future<void> updateProduct({
    required String id,
    required String name,
    required String category,
    required String location,
    required int quantity,
    String description = '',
    int branch = 0,
    String? addedBy,
  }) async {
    final item = InventoryItem(
      id: id,
      name: name.trim(),
      category: category,
      location: location.trim(),
      quantity: quantity,
      description: description.trim(),
      branch: branch,
      addedBy: addedBy,
    );

    await _col.doc(id).update(item.toMap());
    clearCache();
  }

  // ── DELETE ─────────────────────────────────────────────────────────────────
  Future<void> deleteProduct(String id) async {
    await _col.doc(id).delete();
    clearCache();
  }

  // ── BULK SEED ──────────────────────────────────────────────────────────────
  // [branchOverride] forces every item written in this call to carry that
  // branch number, regardless of whatever (or nothing) is in each raw map's
  // own 'branch' key. See _seedProductsBatch() below for why this matters.
  Future<Map<String, int>> seedAllProducts(
      List<Map<String, dynamic>> products, {
        int? branchOverride,
      }) async {
    final result = await _seedProductsBatch(products, branchOverride: branchOverride);
    clearCache();
    return result;
  }

  // Shared batch-write core used by both seedAllProducts() and
  // wipeAndReseedWithBranches(). Does NOT touch the cache itself — callers
  // are responsible for invalidating once, after all their writes are done.
  //
  // [branchOverride]: the raw seed maps in data/seed_products.dart and
  // data/seed_adambakkam_inventory_dashboard.dart never actually contain a
  // 'branch' key — they're plain {name, category, location, quantity,
  // description} maps. Previously `branch: (p['branch'] as num?)?.toInt()
  // ?? 0` silently fell back to 0 for every single seeded item, including
  // when this was called from wipeAndReseedWithBranches() specifically to
  // FIX branch tagging. That meant the "does every item still have
  // branch == 0?" check on the Inventory Dashboard was NEVER satisfied by
  // the migration it triggered, so it re-triggered on the very next screen
  // open — wiping and reseeding the entire ~1,560-item collection again,
  // forever, every time anyone opened the Inventory Dashboard. That loop
  // (full collection read + full collection delete + full collection
  // rewrite + a re-read afterward, every single visit) is what was
  // actually driving the 96k reads / 16k writes / 20k deletes seen in the
  // Firebase console.
  //
  // Passing branchOverride now stamps every item from a given seed list
  // with its real branch number at write time, so the migration this
  // method backs actually converges instead of re-triggering indefinitely.
  Future<Map<String, int>> _seedProductsBatch(
      List<Map<String, dynamic>> products, {
        int? branchOverride,
      }) async {
    int success = 0;
    int failed = 0;

    const batchSize = 400;
    final batches = <WriteBatch>[];

    for (var i = 0; i < products.length; i += batchSize) {
      final batch = FirebaseFirestore.instance.batch();
      final chunk = products.sublist(
        i,
        (i + batchSize).clamp(0, products.length),
      );

      for (final p in chunk) {
        try {
          final item = InventoryItem(
            id: '',
            name: (p['name'] as String).trim(),
            category: p['category'] as String,
            location: (p['location'] as String).trim(),
            quantity: p['quantity'] as int,
            description: (p['description'] as String? ?? '').trim(),
            branch: branchOverride ?? (p['branch'] as num?)?.toInt() ?? 0,
          );
          final docRef = _col.doc();
          batch.set(docRef, item.toCreateMap());
          success++;
        } catch (_) {
          failed++;
        }
      }
      batches.add(batch);
    }

    for (final batch in batches) {
      await batch.commit();
    }

    return {'success': success, 'failed': failed};
  }

  // ── MIGRATION HELPERS ─────────────────────────────────────────────────────

  Future<QuerySnapshot<Map<String, dynamic>>> getRawSnapshot() => _col.get();

  // Server-side check: does ANY document already carry a 'branch' key at
  // all? (Previously unused — the caller in inventory_dashboard.dart used
  // its own client-side "every item's branch == 0" check instead, which is
  // NOT the same test: a doc can have branch == 0 on purpose, or because
  // it was seeded before this field existed, or — as the bug above shows —
  // because it was seeded with a bug. Kept here for any future caller that
  // wants the stricter "field literally missing" signal instead.)
  Future<bool> needsBranchMigration() async {
    final snap = await getRawSnapshot();
    if (snap.docs.isEmpty) return false;
    return snap.docs.every((d) => !d.data().containsKey('branch'));
  }

  // Wipes the entire collection and reseeds it from [branchProductLists],
  // where each entry is (branchNumber, itemsForThatBranch). Every item
  // written is now stamped with its real branch number via branchOverride
  // instead of silently defaulting to 0 — see _seedProductsBatch() above
  // for why that default was the actual root cause of the repeated
  // wipe+reseed loop.
  //
  // This is a destructive, expensive operation (delete + rewrite of the
  // WHOLE collection) and must only ever run behind a persistent
  // SeedGuardService guard — see inventory_dashboard.dart's
  // _autoSeedIfNeeded(), which now checks SeedGuardService.hasSeeded(
  // 'inventory_branch_migration') before calling this, and marks it
  // seeded immediately after, so it can only ever fire once per
  // installation regardless of what the in-memory branch check sees on
  // any given screen open.
  Future<void> wipeAndReseedWithBranches(
      List<MapEntry<int, List<Map<String, dynamic>>>> branchProductLists) async {
    final existing = await _col.get();
    const batchSize = 400;
    for (var i = 0; i < existing.docs.length; i += batchSize) {
      final batch = FirebaseFirestore.instance.batch();
      final chunk = existing.docs.sublist(
        i,
        (i + batchSize).clamp(0, existing.docs.length),
      );
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    for (final entry in branchProductLists) {
      await _seedProductsBatch(entry.value, branchOverride: entry.key);
    }
    // Single cache invalidation after the entire wipe+reseed operation,
    // instead of once per branch list via seedAllProducts().
    clearCache();
  }

  // ── QUERY HELPERS ──────────────────────────────────────────────────────────

  Future<List<InventoryItem>> getByCategory(String category) async {
    final snapshot = await _col
        .where('category', isEqualTo: category)
        .orderBy('name')
        .get();
    return snapshot.docs.map(InventoryItem.fromDoc).toList();
  }

  Future<List<InventoryItem>> getByBranch(int branch) async {
    final snapshot = await _col
        .where('branch', isEqualTo: branch)
        .orderBy('name')
        .get();
    return snapshot.docs.map(InventoryItem.fromDoc).toList();
  }

  Future<List<InventoryItem>> getLowStock({int threshold = 2}) async {
    final snapshot = await _col
        .where('quantity', isLessThanOrEqualTo: threshold)
        .orderBy('quantity')
        .get();
    return snapshot.docs.map(InventoryItem.fromDoc).toList();
  }
}