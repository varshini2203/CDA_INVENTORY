// lib/services/fixed_asset_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cda_inventory/models/fixed_asset.dart';
import 'activity_log_service.dart';

class FixedAssetService {
  static final CollectionReference<Map<String, dynamic>> _col =
  FirebaseFirestore.instance.collection('fixed_assets');

  // ── IN-MEMORY CACHE (full asset list, ordered by name) ───────────────────
  // Same pattern as InventoryService/ProductService/DroneService: fetch
  // once, reuse across navigation/rebuilds, invalidate on any write.
  // Previously getAssets() had no cache at all — every open of the Fixed
  // Assets list screen re-downloaded the entire `fixed_assets` collection,
  // even when navigating back to a screen you'd already loaded seconds
  // earlier in the same session.
  static List<FixedAsset>? _assetsCache;

  static void clearCache() {
    _assetsCache = null;
  }

  // ── GET ALL (cached one-shot fetch — call once from initState and reuse
  //    the result, do NOT call this from build()) ──────────────────────────
  static Future<List<FixedAsset>> getAssets({bool forceRefresh = false}) async {
    if (!forceRefresh && _assetsCache != null) return _assetsCache!;

    final snap = await _col.orderBy('name').get();
    final list = snap.docs
        .map((doc) => FixedAsset.fromFirestore(
        doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();

    _assetsCache = list;
    return list;
  }

  // ── STREAM (real-time) ────────────────────────────────────────────────────
  // Kept for reference only. Per the optimization pass, Fixed Assets is a
  // slow-changing collection so it should NOT be streamed — use getAssets()
  // above instead. Do not wire this into a StreamBuilder inside build().
  static Stream<List<FixedAsset>> streamAssets() {
    return _col.orderBy('name').snapshots().map(
          (s) => s.docs.map((doc) => FixedAsset.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>)).toList(),
    );
  }

  // ── ADD ───────────────────────────────────────────────────────────────────
  static Future<void> addAsset(Map<String, dynamic> data) async {
    await _col.add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    clearCache();
    ActivityLogService.logAdd(
      module: 'Fixed Assets',
      itemName: (data['name'] as String?) ?? 'New asset',
      data: data,
    );
  }

  // ── UPDATE ────────────────────────────────────────────────────────────────
  static Future<void> updateAsset(
      String id, Map<String, dynamic> data) async {
    final existing = await _col.doc(id).get();
    final before = existing.data() ?? {};
    await _col.doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    clearCache();
    ActivityLogService.logEdit(
      module: 'Fixed Assets',
      itemName: (data['name'] as String?) ?? (before['name'] as String?) ?? id,
      before: before,
      after: {...before, ...data},
    );
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  static Future<void> deleteAsset(String id) async {
    final existing = await _col.doc(id).get();
    final before = existing.data() ?? {};
    await _col.doc(id).delete();
    clearCache();
    ActivityLogService.logDelete(
      module: 'Fixed Assets',
      itemName: (before['name'] as String?) ?? id,
      data: before,
    );
  }

  // ── DELETE BY NAME ─────────────────────────────────────────────────────
  // Used by InventorySyncService to remove the Fixed-Assets copy of an
  // item when the original is deleted from Inventory or New Products.
  static Future<void> deleteByName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final snap = await _col.where('name', isEqualTo: trimmed).get();
    if (snap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    clearCache();
  }

  // ── BULK SEED (batched writes — 400 per batch) ────────────────────────────
  static Future<Map<String, int>> seedAssets(
      List<Map<String, dynamic>> assets) async {
    int success = 0;
    int failed = 0;
    const batchSize = 400;

    for (var i = 0; i < assets.length; i += batchSize) {
      final batch = FirebaseFirestore.instance.batch();
      final chunk = assets.sublist(
        i,
        (i + batchSize).clamp(0, assets.length),
      );

      for (final a in chunk) {
        try {
          batch.set(_col.doc(), {
            ...a,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          success++;
        } catch (_) {
          failed++;
        }
      }
      await batch.commit();
    }

    clearCache();
    return {'success': success, 'failed': failed};
  }
}