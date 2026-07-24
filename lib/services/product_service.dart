// lib/services/product_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import 'activity_log_service.dart';

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
      },
    );

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
      },
      after: {
        'Name': product.name,
        'Category': product.category,
        'Quantity': product.quantity,
        'Price': product.price,
        'Notes': product.notes,
      },
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
            category: p['category'] as String,
            quantity: (p['quantity'] as num).toInt(),
            price: (p['price'] as num?)?.toDouble() ?? 0.0,
            notes: p['notes'] as String?,
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