// lib/services/new_product_service.dart
//
// Data-access layer for the New Products module. Follows the exact same
// shape as FixedAssetService / ConsumableService / InvoiceService in this
// project:
//   • static, no instances
//   • one in-memory cache for the "fetch once, reuse everywhere" list
//     screens rely on, invalidated on every write
//   • a live Stream variant for screens that want real-time updates
//   • every CRUD method logs to ActivityLogService right where the
//     Firestore write happens
//
// Attachments (product photo / invoice photo) are stored as Base64
// strings directly on the document — same approach as BillsService — so
// no Firebase Storage bucket / Blaze plan is required anywhere in the
// app.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

import 'package:cda_inventory/models/new_product.dart';
import 'activity_log_service.dart';
import 'gamification_service.dart';
import 'inventory_sync_service.dart';

class NewProductService {
  NewProductService._(); // static-only, no instances

  static final CollectionReference<Map<String, dynamic>> _col =
  FirebaseFirestore.instance.collection('new_products');

  static final CollectionReference<Map<String, dynamic>> _notifications =
  FirebaseFirestore.instance.collection('notifications');

  // ── IN-MEMORY CACHE (full list, newest first) ────────────────────────
  // Same pattern as FixedAssetService/ProductService: fetch once, reuse
  // across navigation/rebuilds, invalidate on any write.
  static List<NewProduct>? _cache;

  static void clearCache() => _cache = null;

  // ── Image / attachment compression ───────────────────────────────────
  // Firestore caps a document at 1,048,487 bytes. Both attachments are
  // capped well under that so the two together plus the rest of the
  // document's fields stay safely inside the limit.
  static const int _maxRawBytes = 450000;
  static const int _maxDimension = 1600;

  static String encodeImageForFirestore(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      // Not a decodable image — encode as-is and let Firestore reject it
      // if it's genuinely too large, rather than silently corrupt it.
      return base64Encode(bytes);
    }

    img.Image working = decoded;

    if (working.width > _maxDimension || working.height > _maxDimension) {
      working = img.copyResize(
        working,
        width: working.width >= working.height ? _maxDimension : null,
        height: working.height > working.width ? _maxDimension : null,
      );
    }

    var quality = 85;
    Uint8List out = Uint8List.fromList(img.encodeJpg(working, quality: quality));

    while (out.length > _maxRawBytes && quality > 30) {
      quality -= 10;
      out = Uint8List.fromList(img.encodeJpg(working, quality: quality));
    }

    while (out.length > _maxRawBytes &&
        working.width > 400 &&
        working.height > 400) {
      working = img.copyResize(working, width: (working.width * 0.8).round());
      out = Uint8List.fromList(img.encodeJpg(working, quality: quality));
    }

    return base64Encode(out);
  }

  // ── GET ALL (cached one-shot fetch — call once from initState and
  //    reuse the result, do NOT call this from build()) ────────────────
  // NOTE: We deliberately do NOT use .orderBy('createdAt', ...) here.
  // Firestore's orderBy() silently EXCLUDES any document that is missing
  // the field being ordered on (e.g. docs added by hand via the Firebase
  // Console, or older/imported docs without a createdAt timestamp) —
  // they don't just sort last, they vanish from the result set entirely.
  // Fetching everything and sorting client-side avoids that trap.
  static int _byCreatedAtDesc(NewProduct a, NewProduct b) {
    final aTime = a.createdAt;
    final bTime = b.createdAt;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1; // docs without a timestamp go last
    if (bTime == null) return -1;
    return bTime.compareTo(aTime); // descending (newest first)
  }

  static Future<List<NewProduct>> getNewProducts(
      {bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return List<NewProduct>.from(_cache!);

    final snap = await _col.get();
    final list = snap.docs.map(NewProduct.fromFirestore).toList()
      ..sort(_byCreatedAtDesc);

    _cache = list;
    return List<NewProduct>.from(list);
  }

  /// Live stream of all new products, newest first. Useful for screens
  /// that want real-time dashboard counts without a manual refresh.
  static Stream<List<NewProduct>> streamNewProducts() {
    return _col.snapshots().map((snap) =>
    snap.docs.map(NewProduct.fromFirestore).toList()
      ..sort(_byCreatedAtDesc));
  }

  static Future<NewProduct?> getNewProductById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return NewProduct.fromFirestore(doc);
  }

  // ── ADD ───────────────────────────────────────────────────────────────
  static Future<NewProduct> addNewProduct(NewProduct product) async {
    final data = {
      ...product.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _col.add(data);
    final created = product.copyWith(
      productId: docRef.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Keep cache in sync instead of clearing it, so the list screen can
    // show the new item immediately without an extra round-trip.
    _cache?.insert(0, created);

    ActivityLogService.logAdd(
      module: 'New Products',
      itemName: product.productName.isEmpty ? 'New product' : product.productName,
      data: product.toActivityLogMap(),
    );

    await _createNotification(
      title: 'New Product Added',
      body: '${product.productName} was added by ${product.addedBy}.',
      productId: docRef.id,
    );

    // Automatically fan this item out to Inventory, Search Products,
    // Branch, Stock Management, and Fixed Assets/Consumables (auto
    // segregated) so it shows up everywhere without manual re-entry.
    try {
      await InventorySyncService.syncFromNewProductAdd(created);
    } catch (_) {
      // Cross-module sync failures must never block the primary add —
      // InventorySyncService already isolates + logs each module's own
      // failure internally.
    }

    // The Firestore add + activity log above already succeeded, so
    // it's safe to award XP exactly once for this creation. Best
    // effort: a gamification hiccup must never block the primary add.
    try {
      await GamificationService.recordProductAdded();
    } catch (_) {}

    return created;
  }

  // ── UPDATE ────────────────────────────────────────────────────────────
  static Future<void> updateNewProduct(
      String id, NewProduct before, NewProduct after) async {
    await _col.doc(id).update({
      ...after.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    clearCache();

    ActivityLogService.logEdit(
      module: 'New Products',
      itemName: after.productName.isEmpty ? id : after.productName,
      before: before.toActivityLogMap(),
      after: after.toActivityLogMap(),
    );

    // Status-change notifications.
    if (before.status != after.status) {
      if (after.status == 'Approved') {
        await _createNotification(
          title: 'Product Approved',
          body: '${after.productName} was approved${after.approvedBy.isEmpty ? '' : ' by ${after.approvedBy}'}.',
          productId: id,
        );
      } else if (after.status == 'Rejected') {
        await _createNotification(
          title: 'Product Rejected',
          body: '${after.productName} was rejected${after.approvedBy.isEmpty ? '' : ' by ${after.approvedBy}'}.',
          productId: id,
        );
      }
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────
  static Future<void> deleteNewProduct(NewProduct product) async {
    await _col.doc(product.productId).delete();
    clearCache();

    ActivityLogService.logDelete(
      module: 'New Products',
      itemName: product.productName.isEmpty ? product.productId : product.productName,
      data: product.toActivityLogMap(),
    );

    // Mirror addNewProduct's fan-out: remove this item from Inventory,
    // Search Products, Branch, Stock Management, and Fixed Assets/
    // Consumables too, so a delete here doesn't leave stale copies
    // behind everywhere else.
    try {
      await InventorySyncService.syncFromNewProductDelete(product);
    } catch (_) {
      // Cross-module sync failures must never block the primary delete —
      // InventorySyncService already isolates + logs each module's own
      // failure internally.
    }
  }

  // ── NOTIFICATIONS ─────────────────────────────────────────────────────
  static Future<void> _createNotification({
    required String title,
    required String body,
    required String productId,
  }) async {
    try {
      await _notifications.add({
        'title': title,
        'body': body,
        'module': 'New Products',
        'referenceId': productId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Notifications are best-effort — never block a save on this.
    }
  }

  // ── STOCK STATUS ──────────────────────────────────────────────────────
  /// These products are the branch's sale-stock: bought in, sold to
  /// customers, and reordered once quantity runs down to (or below) the
  /// configured [NewProduct.minimumStockLevel]. This classifies a single
  /// product's current stock position for the dashboard / list UI.
  static const String stockOutOfStock = 'Out of Stock';
  static const String stockLow = 'Low Stock';
  static const String stockIn = 'In Stock';

  static String stockStatus(NewProduct p) {
    if (p.quantity <= 0) return stockOutOfStock;
    if (p.quantity <= p.minimumStockLevel) return stockLow;
    return stockIn;
  }

  // ── DASHBOARD STATISTICS ──────────────────────────────────────────────
  /// Computed client-side from whatever list the caller already has
  /// loaded (e.g. from [getNewProducts]) — no extra Firestore reads.
  ///
  /// These products are sale stock (bought in, sold to customers,
  /// restocked when quantity runs low/out) so the dashboard is built
  /// around stock position and branch split rather than an approval
  /// workflow.
  static Map<String, int> computeStats(List<NewProduct> products) {
    final now = DateTime.now();
    int addedThisMonth = 0;
    int inStock = 0;
    int lowStock = 0;
    int outOfStock = 0;
    int cdaAdmin = 0;
    int cdaOps = 0;

    for (final p in products) {
      switch (stockStatus(p)) {
        case stockOutOfStock:
          outOfStock++;
          break;
        case stockLow:
          lowStock++;
          break;
        default:
          inStock++;
      }

      if (p.branch == 'CDA Admin') {
        cdaAdmin++;
      } else if (p.branch == 'CDA Ops') {
        cdaOps++;
      }

      final created = p.createdAt;
      if (created != null &&
          created.year == now.year &&
          created.month == now.month) {
        addedThisMonth++;
      }
    }

    return {
      'total': products.length,
      'inStock': inStock,
      'lowStock': lowStock,
      'outOfStock': outOfStock,
      'cdaAdmin': cdaAdmin,
      'cdaOps': cdaOps,
      'addedThisMonth': addedThisMonth,
    };
  }
}