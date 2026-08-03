// lib/services/branch_inventory_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_item.dart';
import '../data/seed_branch1_inventory.dart';
import '../data/seed_branch2_inventory.dart';
import 'activity_log_service.dart';

class BranchInventoryService {
  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('branch_inventory');

  static Query<Map<String, dynamic>> _branchQuery(int branchId) =>
      _col.where('branch_id', isEqualTo: branchId);

  static List<InventoryItem> _toDocs(
      QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs
          .map((d) => InventoryItem.fromFirestore(
          d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

  // ── IN-MEMORY CACHE (full item list per branch) ───────────────────────
  // Mirrors the pattern already used in ProductService/StockService/
  // DroneService: fetch each branch's items from Firestore once, reuse
  // that same in-memory list across screen navigation and filter/search
  // changes, and only hit Firestore again after a write to that branch
  // (create/update/delete/clear/seed) or an explicit forceRefresh (e.g. a
  // manual pull-to-refresh). Previously every fetchInventory()/
  // fetchSummary() call — including every screen re-open — re-queried the
  // entire branch collection from scratch.
  static final Map<int, List<InventoryItem>> _branchCache = {};

  static void clearCache([int? branchId]) {
    if (branchId != null) {
      _branchCache.remove(branchId);
    } else {
      _branchCache.clear();
    }
  }

  static Future<List<InventoryItem>> _getBranchItems(
      int branchId, {
        bool forceRefresh = false,
      }) async {
    if (!forceRefresh && _branchCache.containsKey(branchId)) {
      return _branchCache[branchId]!;
    }
    final snap = await _branchQuery(branchId).get()
    as QuerySnapshot<Map<String, dynamic>>;
    final items = _toDocs(snap);
    _branchCache[branchId] = items;
    return items;
  }

  // ── fetchSummary ─────────────────────────────────────────────────────────
  static Future<BranchSummary> fetchSummary(
      int branchId, {
        bool forceRefresh = false,
      }) async {
    final items = await _getBranchItems(branchId, forceRefresh: forceRefresh);
    return BranchSummary.fromItems('Branch $branchId', items);
  }

  // ── fetchInventory ────────────────────────────────────────────────────────
  static Future<List<InventoryItem>> fetchInventory(
      int branchId, {
        String? category,
        String? search,
        bool forceRefresh = false,
      }) async {
    List<InventoryItem> items =
    List.of(await _getBranchItems(branchId, forceRefresh: forceRefresh));
    // Category filter — now applied client-side against the cached list
    // instead of a separate Firestore query per category.
    if (category != null && category != 'all') {
      items = items.where((i) => i.category == category).toList();
    }
    // Sort client-side by item name alphabetically
    items.sort((a, b) => a.itemName.compareTo(b.itemName));
    // Search filter client-side
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      items = items
          .where((item) =>
      item.itemName.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q) ||
          (item.notes?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return items;
  }

  // ── createItem ────────────────────────────────────────────────────────────
  static Future<InventoryItem> createItem(
      int branchId, InventoryItem item) async {
    final data = item.toFirestore()
      ..['created_at'] = FieldValue.serverTimestamp();
    final docRef = await _col.add(data);
    clearCache(branchId);
    ActivityLogService.logAdd(
      module: 'Branch Inventory',
      itemName: item.itemName,
      data: {
        'branch_id': branchId,
        'category': item.category,
        'status': item.status,
        'quantity': item.quantity,
        'notes': item.notes,
      },
    );
    return item.copyWith(id: docRef.id);
  }

  // ── updateItem ────────────────────────────────────────────────────────────
  static Future<InventoryItem> updateItem(
      int branchId, InventoryItem item) async {
    if (item.id == null) {
      throw Exception('Cannot update item without an id');
    }
    final existingDoc = await _col.doc(item.id).get();
    final before = existingDoc.data() ?? {};
    await _col.doc(item.id).update(item.toFirestore());
    clearCache(branchId);
    ActivityLogService.logEdit(
      module: 'Branch Inventory',
      itemName: item.itemName,
      before: {
        'category': before['category'],
        'status': before['status'],
        'quantity': before['quantity'],
        'notes': before['notes'],
      },
      after: {
        'category': item.category,
        'status': item.status,
        'quantity': item.quantity,
        'notes': item.notes,
      },
    );
    return item;
  }

  // ── deleteItem ────────────────────────────────────────────────────────────
  static Future<void> deleteItem(int branchId, String itemId) async {
    final existingDoc = await _col.doc(itemId).get();
    final before = existingDoc.data() ?? {};
    await _col.doc(itemId).delete();
    clearCache(branchId);
    ActivityLogService.logDelete(
      module: 'Branch Inventory',
      itemName: (before['item_name'] as String?) ?? itemId,
      data: {
        'branch_id': branchId,
        'category': before['category'],
        'quantity': before['quantity'],
      },
    );
  }

  // ── deleteByNameAndBranch ───────────────────────────────────────────────
  // Used by InventorySyncService to remove the Branch-module copy of an
  // item when the original is deleted from Inventory or New Products.
  // Matched by item_name + branch_id (same name-matching approach the
  // add-sync uses) since no cross-collection id is stored.
  static Future<void> deleteByNameAndBranch(
      int branchId, String itemName) async {
    final trimmed = itemName.trim();
    if (trimmed.isEmpty) return;
    final snap = await _col
        .where('branch_id', isEqualTo: branchId)
        .where('item_name', isEqualTo: trimmed)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    clearCache(branchId);
  }

  // ── clearBranch ──────────────────────────────────────────────────────────
  /// Deletes ALL inventory items for a given branch. Useful when you need
  /// to wipe bad/duplicate data and let auto-seed (or a manual seed call)
  /// repopulate it from scratch. Batched at 450 deletes per commit since
  /// Firestore caps a single batch at 500 ops.
  static Future<void> clearBranch(int branchId) async {
    final snap = await _branchQuery(branchId).get()
    as QuerySnapshot<Map<String, dynamic>>;
    final docs = snap.docs;
    const chunkSize = 450;

    for (var i = 0; i < docs.length; i += chunkSize) {
      final chunk = docs.sublist(
        i,
        (i + chunkSize > docs.length) ? docs.length : i + chunkSize,
      );
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    clearCache(branchId);
  }

  // ── seedBranch1 ───────────────────────────────────────────────────────────
  /// Bulk-uploads the Adambakkam seed list (lib/data/seed_branch1_inventory.dart)
  /// into the 'branch_inventory' collection, tagged with branch_id: 1.
  /// Uses batched writes since Firestore caps a single batch at 500 ops.
  static Future<void> seedBranch1() async {
    final items = SeedBranch1Inventory.items;
    const chunkSize = 450;

    for (var i = 0; i < items.length; i += chunkSize) {
      final chunk = items.sublist(
        i,
        (i + chunkSize > items.length) ? items.length : i + chunkSize,
      );

      final batch = FirebaseFirestore.instance.batch();
      for (final item in chunk) {
        final docRef = _col.doc();
        batch.set(docRef, {
          ...item,
          'branch_id': 1,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
    clearCache(1);
  }

  // ── seedBranch2 ───────────────────────────────────────────────────────────
  /// Bulk-uploads the master seed list (lib/data/seed_branch2_inventory.dart)
  /// into the 'branch_inventory' collection, tagged with branch_id: 2.
  /// Uses batched writes since Firestore caps a single batch at 500 ops.
  static Future<void> seedBranch2() async {
    final items = SeedBranch2Inventory.items;
    const chunkSize = 450;

    for (var i = 0; i < items.length; i += chunkSize) {
      final chunk = items.sublist(
        i,
        (i + chunkSize > items.length) ? items.length : i + chunkSize,
      );

      final batch = FirebaseFirestore.instance.batch();
      for (final item in chunk) {
        final docRef = _col.doc();
        batch.set(docRef, {
          ...item,
          'branch_id': 2,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
    clearCache(2);
  }
}