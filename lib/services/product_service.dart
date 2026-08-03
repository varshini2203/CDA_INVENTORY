// lib/services/product_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../constants/gamification_constants.dart';
import 'activity_log_service.dart';
import 'gamification_service.dart';
import 'staff_reward_service.dart';

class ProductService {
  static const String _module = 'Products';

  // ── Singleton ──────────────────────────────────────────────────────────────
  ProductService._internal();
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;

  // ── Firestore collection reference ────────────────────────────────────────
  static final CollectionReference<Map<String, dynamic>> _col =
  FirebaseFirestore.instance.collection('products');

  // ── IN-MEMORY CACHE (full products list, ordered by name) ────────────────
  // Mirrors the pattern already used in StockService/DroneService: fetch
  // once, reuse across screen navigation, and only hit Firestore again
  // after a write or an explicit forceRefresh (e.g. a manual Refresh
  // button). Nothing here changes what any caller receives — same data,
  // same ordering — only when a Firestore round-trip actually happens.
  static List<Product>? _productsCache;

  static void clearCache() {
    _productsCache = null;
  }

  // ═══════════════════════════════════════════════════════════════
  //  GET ALL  (cached one-shot fetch, mirrors old getProducts())
  // ═══════════════════════════════════════════════════════════════
  static Future<List<Product>> getProducts({bool forceRefresh = false}) async {
    if (!forceRefresh && _productsCache != null) return _productsCache!;
    final snapshot = await _col.orderBy('name').get();
    final list = snapshot.docs.map(Product.fromDoc).toList();
    _productsCache = list;
    return list;
  }

  // ═══════════════════════════════════════════════════════════════
  //  REAL-TIME STREAM  (live updates — preferred over getProducts)
  // ═══════════════════════════════════════════════════════════════
  static Stream<List<Product>> watchProducts() {
    return _col.orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs.map(Product.fromDoc).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  ADD  (mirrors old addProduct(Map data))
  // ═══════════════════════════════════════════════════════════════
  static Future<Product> addProduct(Map<String, dynamic> data) async {
    final product = Product(
      id: '',                                         // Firestore assigns
      name: (data['name'] as String).trim(),
      category: data['category'] as String,
      quantity: (data['quantity'] as num).toInt(),
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      notes: data['notes'] as String?,
      branch: data['branch'] as String?,
      room: data['room'] as String?,
      row: data['row'] as String?,
      rack: data['rack'] as String?,
      tray: data['tray'] as String?,
    );

    final docRef = await _col.add(product.toCreateMap());
    clearCache();

    ActivityLogService.logAdd(
      module: _module,
      itemName: product.name,
      data: {
        'Category': product.category,
        'Quantity': product.quantity,
        'Price': product.price,
        if ((product.notes ?? '').isNotEmpty) 'Notes': product.notes,
        if ((product.branch ?? '').isNotEmpty) 'Branch': product.branch,
        if ((product.room ?? '').isNotEmpty) 'Room': product.room,
        if ((product.row ?? '').isNotEmpty) 'Row': product.row,
        if ((product.rack ?? '').isNotEmpty) 'Rack': product.rack,
        if ((product.tray ?? '').isNotEmpty) 'Tray': product.tray,
      },
    );

    StaffRewardService.recordActivity(
      action: StaffAction.addProduct,
      module: _module,
      refId: 'products_${docRef.id}_add',
    );

    // Firestore write + activity log above already succeeded at this
    // point, so it's safe to award XP exactly once for this creation.
    // Best-effort: never let a gamification hiccup surface as a
    // product-creation failure.
    try {
      await GamificationService.recordProductAdded();
    } catch (_) {}

    return product.copyWith(id: docRef.id, createdAt: DateTime.now());
  }

  // ═══════════════════════════════════════════════════════════════
  //  UPDATE  (mirrors old updateProduct(int id, Map data))
  //          id is now a String (Firestore doc ID)
  // ═══════════════════════════════════════════════════════════════
  static Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    // Read the existing values first so the activity feed can show
    // exactly which fields changed, old value → new value.
    final beforeSnap = await _col.doc(id).get();
    final beforeData = beforeSnap.data() ?? {};

    final product = Product(
      id: id,
      name: (data['name'] as String).trim(),
      category: data['category'] as String,
      quantity: (data['quantity'] as num).toInt(),
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      notes: data['notes'] as String?,
      branch: data['branch'] as String?,
      room: data['room'] as String?,
      row: data['row'] as String?,
      rack: data['rack'] as String?,
      tray: data['tray'] as String?,
    );

    await _col.doc(id).update(product.toMap());
    clearCache();

    ActivityLogService.logEdit(
      module: _module,
      itemName: product.name,
      before: {
        'Name': beforeData['name'],
        'Category': beforeData['category'],
        'Quantity': beforeData['quantity'],
        'Price': beforeData['price'],
        'Notes': beforeData['notes'],
        'Branch': beforeData['branch'],
        'Room': beforeData['room'],
        'Row': beforeData['row'],
        'Rack': beforeData['rack'],
        'Tray': beforeData['tray'],
      },
      after: {
        'Name': product.name,
        'Category': product.category,
        'Quantity': product.quantity,
        'Price': product.price,
        'Notes': product.notes,
        'Branch': product.branch,
        'Room': product.room,
        'Row': product.row,
        'Rack': product.rack,
        'Tray': product.tray,
      },
    );

    StaffRewardService.recordActivity(
      action: StaffAction.editProduct,
      module: _module,
      // No refId: each edit is a genuinely new event, not a retry of the
      // same one — repeat edits should each earn XP.
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DELETE  (mirrors old deleteProduct(int id))
  //          id is now a String
  // ═══════════════════════════════════════════════════════════════
  static Future<void> deleteProduct(String id) async {
    // Read it first so the feed can show what was deleted, not just that
    // "a product" was deleted.
    final snap = await _col.doc(id).get();
    final data = snap.data() ?? {};
    final name = (data['name'] as String?) ?? id;

    await _col.doc(id).delete();
    clearCache();

    ActivityLogService.logDelete(
      module: _module,
      itemName: name,
      data: {
        'Category': data['category'],
        'Quantity': data['quantity'],
        'Price': data['price'],
      },
    );

    StaffRewardService.recordActivity(
      action: StaffAction.deleteProduct,
      module: _module,
      refId: 'products_${id}_delete',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  QUERY HELPERS
  // ═══════════════════════════════════════════════════════════════

  /// Filter by category in Firestore (server-side).
  static Future<List<Product>> getByCategory(String category) async {
    final snapshot = await _col
        .where('category', isEqualTo: category)
        .orderBy('name')
        .get();
    return snapshot.docs.map(Product.fromDoc).toList();
  }

  /// Stream filtered by category (live).
  static Stream<List<Product>> watchByCategory(String category) {
    return _col
        .where('category', isEqualTo: category)
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(Product.fromDoc).toList());
  }

  /// Exact-match lookup by branch (server-side).
  static Future<List<Product>> getByBranch(String branch) async {
    final snapshot = await _col.where('branch', isEqualTo: branch).get();
    return snapshot.docs.map(Product.fromDoc).toList();
  }

  /// Exact-match lookup by room (server-side).
  static Future<List<Product>> getByRoom(String room) async {
    final snapshot = await _col.where('room', isEqualTo: room).get();
    return snapshot.docs.map(Product.fromDoc).toList();
  }

  /// Exact-match lookup by shelf row (server-side).
  static Future<List<Product>> getByRow(String row) async {
    final snapshot = await _col.where('row', isEqualTo: row).get();
    return snapshot.docs.map(Product.fromDoc).toList();
  }

  /// Exact-match lookup by rack (server-side).
  static Future<List<Product>> getByRack(String rack) async {
    final snapshot = await _col.where('rack', isEqualTo: rack).get();
    return snapshot.docs.map(Product.fromDoc).toList();
  }

  /// Exact-match lookup by tray (server-side).
  static Future<List<Product>> getByTray(String tray) async {
    final snapshot = await _col.where('tray', isEqualTo: tray).get();
    return snapshot.docs.map(Product.fromDoc).toList();
  }

  /// Items at or below a stock threshold.
  static Future<List<Product>> getLowStock({int threshold = 2}) async {
    final snapshot = await _col
        .where('quantity', isLessThanOrEqualTo: threshold)
        .orderBy('quantity')
        .get();
    return snapshot.docs.map(Product.fromDoc).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  //  BULK SEED  (batched writes — much faster than sequential adds)
  // ═══════════════════════════════════════════════════════════════
  static Future<Map<String, int>> seedProducts(
      List<Map<String, dynamic>> products) async {
    int success = 0;
    int failed = 0;
    const batchSize = 400; // Firestore batch limit is 500

    for (var i = 0; i < products.length; i += batchSize) {
      final batch = FirebaseFirestore.instance.batch();
      final chunk = products.sublist(
        i,
        (i + batchSize).clamp(0, products.length),
      );

      for (final p in chunk) {
        try {
          final product = Product(
            id: '',
            name: (p['name'] as String).trim(),
            // Some seed sources (e.g. the physical-inventory sheets) don't
            // set a separate 'category' — the room they were found in
            // doubles as the category in that case.
            category: (p['category'] as String?) ?? (p['room'] as String?) ?? 'Uncategorised',
            quantity: (p['quantity'] as num).toInt(),
            price: (p['price'] as num?)?.toDouble() ?? 0.0,
            notes: p['notes'] as String?,
            branch: p['branch'] as String?,
            room: p['room'] as String?,
            row: p['row'] as String?,
            rack: p['rack'] as String?,
            tray: p['tray'] as String?,
          );
          batch.set(_col.doc(), product.toCreateMap());
          success++;
        } catch (_) {
          failed++;
        }
      }
      await batch.commit();
    }

    clearCache();

    ActivityLogService.logAction(
      'Bulk-seeded $success product(s)${failed > 0 ? ' ($failed failed)' : ''}',
      module: _module,
    );

    return {'success': success, 'failed': failed};
  }
}