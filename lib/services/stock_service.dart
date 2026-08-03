// lib/services/stock_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cda_inventory/models/stock.dart';
import '../constants/gamification_constants.dart';
import 'activity_log_service.dart';
import 'gamification_service.dart';
import 'staff_reward_service.dart';

class StockService {
  static const String _module = 'Stock';

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference get _items =>
      _db.collection('stock_items');
  static CollectionReference get _transactions =>
      _db.collection('stock_transactions');

  // ── IN-MEMORY CACHE (unfiltered item list only) ─────────────────────────
  // The Stock Dashboard and the unfiltered Stock Items list both need the
  // full stock_items collection. Without this they'd each trigger their
  // own full read every time either screen is opened. Filtered queries
  // (by branch/category) still go straight to Firestore since a
  // server-side filter is already cheap and correct for those.
  static List<StockItem>? _allItemsCache;

  static void clearCache() {
    _allItemsCache = null;
    _historyCache.clear();
  }

  static Future<List<StockItem>> _fetchAllItems({bool forceRefresh = false}) async {
    if (!forceRefresh && _allItemsCache != null) return _allItemsCache!;
    final snap = await _items.get();
    final all = snap.docs.map(StockItem.fromFirestore).toList();
    _allItemsCache = all;
    return all;
  }

  // ── Dashboard ──────────────────────────────────────────────────────────────
  static Future<StockDashboardData> fetchDashboard({bool forceRefresh = false}) async {
    final all = await _fetchAllItems(forceRefresh: forceRefresh);

    final lowItems = all.where((i) => i.isLowStock).toList();
    final fixed    = all.where((i) => i.category == 'fixed_asset').length;
    final consume  = all.where((i) => i.category == 'consumable').length;

    final branchMap = <String, int>{};
    for (final item in all) {
      branchMap[item.branch] = (branchMap[item.branch] ?? 0) + 1;
    }
    final branchStocks = branchMap.entries
        .map((e) => BranchStock(branch: e.key, itemCount: e.value))
        .toList()
      ..sort((a, b) => a.branch.compareTo(b.branch));

    List<StockTransaction> recent = [];
    try {
      recent = await fetchRecentHistory(limit: 6);
    } catch (_) {
      // Dashboard should still render even if the activity feed fails.
    }

    return StockDashboardData(
      totalProducts: all.length,
      lowStockCount: lowItems.length,
      fixedAssets:   fixed,
      consumables:   consume,
      branchStocks:  branchStocks,
      lowStockItems: lowItems,
      recentActivity: recent,
    );
  }

  // ── All Stock Items ────────────────────────────────────────────────────────
  static Future<List<StockItem>> fetchItems({
    String? branch,
    String? category,
    bool forceRefresh = false,
  }) async {
    // Unfiltered call — reuse the shared cache (same data the Dashboard uses).
    if (branch == null && category == null) {
      final all = await _fetchAllItems(forceRefresh: forceRefresh);
      return [...all]..sort((a, b) => a.productName.compareTo(b.productName));
    }

    Query q = _items;
    if (branch   != null) q = q.where('branch',   isEqualTo: branch);
    if (category != null) q = q.where('category', isEqualTo: category);

    final snap = await q.get();
    return snap.docs.map(StockItem.fromFirestore).toList()
      ..sort((a, b) => a.productName.compareTo(b.productName));
  }

  static Future<StockItem?> fetchItemById(String id) async {
    final doc = await _items.doc(id).get();
    if (!doc.exists) return null;
    return StockItem.fromFirestore(doc);
  }

  // ── Manual catalog entry (0 qty) — register a product before first purchase ─
  static Future<void> createItem({
    required String productName,
    required String branch,
    String category = 'consumable',
    int minStock = 10,
    String? sku,
    String unit = 'pcs',
    String? location,
  }) async {
    final itemId = _itemDocId(productName, branch);
    final ref = _items.doc(itemId);
    final existing = await ref.get();
    if (existing.exists) {
      throw Exception('"$productName" already exists in $branch.');
    }
    await ref.set({
      'product_name': productName,
      'quantity':     0,
      'branch':       branch,
      'category':     category,
      'min_stock':    minStock,
      if (sku != null && sku.isNotEmpty) 'sku': sku,
      'unit':         unit,
      if (location != null && location.isNotEmpty) 'location': location,
      'updated_at':   Timestamp.fromDate(DateTime.now()),
    });
    clearCache();

    ActivityLogService.logAdd(
      module: _module,
      itemName: productName,
      data: {
        'Branch': branch,
        'Category': category,
        'Min stock': minStock,
        'Unit': unit,
        if (sku != null && sku.isNotEmpty) 'SKU': sku,
        if (location != null && location.isNotEmpty) 'Location': location,
      },
    );

    StaffRewardService.recordActivity(
      action: StaffAction.stockUpdate,
      module: _module,
      refId: 'stock_${itemId}_create',
    );
  }

  // ── Edit item metadata (category / min stock / sku / unit / location) ──────
  // productName & branch are the document identity and are not editable here.
  static Future<void> updateItemDetails({
    required String id,
    String? category,
    int? minStock,
    String? sku,
    String? unit,
    String? location,
  }) async {
    // Read the current values first so the activity feed can show exactly
    // what changed, not just that an edit happened.
    final beforeSnap = await _items.doc(id).get();
    final beforeData = (beforeSnap.data() as Map<String, dynamic>?) ?? {};
    final productName = (beforeData['product_name'] ?? id).toString();

    final data = <String, dynamic>{
      'updated_at': Timestamp.fromDate(DateTime.now()),
    };
    if (category != null) data['category']  = category;
    if (minStock != null) data['min_stock'] = minStock;
    if (sku != null)      data['sku']       = sku;
    if (unit != null)     data['unit']      = unit;
    if (location != null) data['location']  = location;
    await _items.doc(id).update(data);
    clearCache();

    ActivityLogService.logEdit(
      module: _module,
      itemName: productName,
      before: {
        'Category': beforeData['category'],
        'Min stock': beforeData['min_stock'],
        'SKU': beforeData['sku'],
        'Unit': beforeData['unit'],
        'Location': beforeData['location'],
      },
      after: {
        'Category': category ?? beforeData['category'],
        'Min stock': minStock ?? beforeData['min_stock'],
        'SKU': sku ?? beforeData['sku'],
        'Unit': unit ?? beforeData['unit'],
        'Location': location ?? beforeData['location'],
      },
    );

    StaffRewardService.recordActivity(
      action: StaffAction.stockUpdate,
      module: _module,
    );
  }

  static Future<void> deleteItem(String id) async {
    // Read it first so the feed can show what was deleted, not just that
    // "an item" was deleted.
    final snap = await _items.doc(id).get();
    final data = (snap.data() as Map<String, dynamic>?) ?? {};
    final productName = (data['product_name'] ?? id).toString();

    await _items.doc(id).delete();
    clearCache();

    ActivityLogService.logDelete(
      module: _module,
      itemName: productName,
      data: {
        'Branch': data['branch'],
        'Category': data['category'],
        'Quantity': data['quantity'],
        'Min stock': data['min_stock'],
      },
    );
  }

  // ── Delete-sync helper ────────────────────────────────────────────────────
  // Used by InventorySyncService when an item is deleted from Inventory or
  // New Products. Stock Management's doc id is deterministic
  // (name + branch, see _itemDocId), so unlike the other modules this
  // doesn't need a name-based query — it can go straight to the doc.
  // Decrements the quantity that was added by the deleted item; only
  // removes the doc entirely once its quantity reaches zero, so it
  // doesn't wipe out stock that other adds contributed to the same
  // product/branch pair.
  static Future<void> removeStockSync({
    required String productName,
    required String branch,
    required int quantity,
  }) async {
    final itemId = _itemDocId(productName, branch);
    final itemRef = _items.doc(itemId);
    final snap = await itemRef.get();
    if (!snap.exists) return;

    final currentQty =
        ((snap.data() as Map<String, dynamic>?)?['quantity'] as int?) ?? 0;
    final newQty = currentQty - quantity;

    if (newQty <= 0) {
      await itemRef.delete();
    } else {
      await itemRef.update({
        'quantity': newQty,
        'updated_at': Timestamp.fromDate(DateTime.now()),
      });
    }
    clearCache();
  }

  // ── Stock IN ───────────────────────────────────────────────────────────────
  // Uses a manual read → write instead of runTransaction (web compatible)
  static Future<bool> addStockIn({
    required String productName,
    required int    quantity,
    required String receivedBy,
    required String branch,
    required String date,
    String remarks  = '',
    String category = 'consumable',
  }) async {
    final itemId  = _itemDocId(productName, branch);
    final itemRef = _items.doc(itemId);
    final now     = Timestamp.fromDate(DateTime.now());

    // Step 1: read current stock
    final snap = await itemRef.get();

    // Step 2: calculate new quantity
    int newQty;
    bool isNew = !snap.exists;
    final currentQty = isNew
        ? 0
        : ((snap.data() as Map<String, dynamic>)['quantity'] as int? ?? 0);
    if (isNew) {
      newQty = quantity;
    } else {
      newQty = currentQty + quantity;
    }

    // Step 3: batch write both documents atomically
    final batch = _db.batch();

    if (isNew) {
      batch.set(itemRef, {
        'product_name': productName,
        'quantity':     newQty,
        'branch':       branch,
        'category':     category,
        'min_stock':    10,
        'unit':         'pcs',
        'updated_at':   now,
      });
    } else {
      batch.update(itemRef, {'quantity': newQty, 'updated_at': now});
    }

    final txnRef  = _transactions.doc();
    final txnData = StockTransaction(
      type:                'IN',
      productName:         productName,
      quantity:            quantity,
      person:              receivedBy,
      branch:              branch,
      departmentOrPurpose: 'Purchase',
      date:                date,
      time:                _currentTime(),
      remarks:             remarks,
    ).toFirestore();
    txnData['created_at'] = now;

    batch.set(txnRef, txnData);
    await batch.commit();
    clearCache();

    if (isNew) {
      ActivityLogService.logAdd(
        module: _module,
        itemName: productName,
        data: {'Branch': branch, 'Category': category, 'Quantity': newQty},
      );
    } else {
      ActivityLogService.logEdit(
        module: _module,
        itemName: productName,
        before: {'Quantity': currentQty},
        after: {'Quantity': newQty},
      );
    }

    StaffRewardService.recordActivity(
      action: StaffAction.stockUpdate,
      module: _module,
      refId: 'stock_${itemId}_in_${txnRef.id}',
    );

    // batch.commit() above already succeeded, so it's safe to award XP
    // exactly once for this Stock In. Best-effort so a gamification
    // hiccup never surfaces as a Stock In failure.
    try {
      await GamificationService.recordStockUpdate();
    } catch (_) {}

    return true;
  }

  // ── Stock OUT ──────────────────────────────────────────────────────────────
  // Uses a manual read → validate → write instead of runTransaction (web compatible)
  static Future<bool> addStockOut({
    required String productName,
    required int    quantity,
    required String usedBy,
    required String purpose,
    required String branch,
    required String date,
    String remarks = '',
  }) async {
    final itemId  = _itemDocId(productName, branch);
    final itemRef = _items.doc(itemId);
    final now     = Timestamp.fromDate(DateTime.now());

    // Step 1: read current stock
    final snap = await itemRef.get();

    if (!snap.exists) {
      throw Exception('Product "$productName" not found in $branch.');
    }

    // Step 2: validate quantity
    final current =
        (snap.data() as Map<String, dynamic>)['quantity'] as int? ?? 0;
    if (current < quantity) {
      throw Exception(
          'Insufficient stock. Available: $current, Requested: $quantity');
    }

    final newQty = current - quantity;

    // Step 3: batch write both documents atomically
    final batch = _db.batch();

    batch.update(itemRef, {'quantity': newQty, 'updated_at': now});

    final txnRef  = _transactions.doc();
    final txnData = StockTransaction(
      type:                'OUT',
      productName:         productName,
      quantity:            quantity,
      person:              usedBy,
      branch:              branch,
      departmentOrPurpose: purpose,
      date:                date,
      time:                _currentTime(),
      remarks:             remarks,
    ).toFirestore();
    txnData['created_at'] = now;

    batch.set(txnRef, txnData);
    await batch.commit();
    clearCache();

    ActivityLogService.logEdit(
      module: _module,
      itemName: productName,
      before: {'Quantity': current},
      after: {'Quantity': newQty},
    );

    StaffRewardService.recordActivity(
      action: StaffAction.stockUpdate,
      module: _module,
      refId: 'stock_${itemId}_out_${txnRef.id}',
    );

    // Validation (insufficient-stock check) + batch.commit() above
    // already succeeded, so it's safe to award XP exactly once for
    // this Stock Out. Best-effort so a gamification hiccup never
    // surfaces as a Stock Out failure.
    try {
      await GamificationService.recordStockUpdate();
    } catch (_) {}

    return true;
  }

  // ── Stock ADJUST — audit correction / damage / loss ─────────────────────────
  // Sets an exact new quantity and logs the delta as an ADJUST transaction.
  static Future<void> adjustStock({
    required String itemId,
    required int newQuantity,
    required String reason,
    required String adjustedBy,
  }) async {
    if (newQuantity < 0) {
      throw Exception('Quantity cannot be negative.');
    }
    final itemRef = _items.doc(itemId);
    final snap = await itemRef.get();
    if (!snap.exists) throw Exception('Item not found.');

    final data        = snap.data() as Map<String, dynamic>;
    final current      = (data['quantity'] as num?)?.toInt() ?? 0;
    final productName  = (data['product_name'] ?? '').toString();
    final branch       = (data['branch'] ?? '').toString();
    final delta        = newQuantity - current;
    final now          = Timestamp.fromDate(DateTime.now());

    final batch = _db.batch();
    batch.update(itemRef, {'quantity': newQuantity, 'updated_at': now});

    final txnRef = _transactions.doc();
    final txnData = StockTransaction(
      type:                'ADJUST',
      productName:         productName,
      quantity:            delta.abs(),
      person:              adjustedBy,
      branch:              branch,
      departmentOrPurpose: reason,
      date:                _currentDate(),
      time:                _currentTime(),
      remarks: delta >= 0
          ? 'Adjusted up by ${delta.abs()} (was $current, now $newQuantity)'
          : 'Adjusted down by ${delta.abs()} (was $current, now $newQuantity)',
    ).toFirestore();
    txnData['created_at'] = now;

    batch.set(txnRef, txnData);
    await batch.commit();
    clearCache();

    ActivityLogService.logEdit(
      module: _module,
      itemName: productName,
      before: {'Quantity': current},
      after: {'Quantity': newQuantity, 'Reason': reason},
    );

    StaffRewardService.recordActivity(
      action: StaffAction.stockUpdate,
      module: _module,
      refId: 'stock_${itemId}_adjust_${txnRef.id}',
    );

    // batch.commit() above already succeeded, so it's safe to award XP
    // exactly once for this adjustment. Best-effort so a gamification
    // hiccup never surfaces as an adjustment failure.
    try {
      await GamificationService.recordStockUpdate();
    } catch (_) {}
  }

  // ── TRANSFER — move quantity from one branch to another ─────────────────────
  static Future<void> transferStock({
    required String productName,
    required String fromBranch,
    required String toBranch,
    required int quantity,
    required String transferredBy,
    String remarks = '',
  }) async {
    if (fromBranch == toBranch) {
      throw Exception('Source and destination branch must be different.');
    }
    if (quantity <= 0) {
      throw Exception('Quantity must be greater than zero.');
    }

    final fromRef = _items.doc(_itemDocId(productName, fromBranch));
    final toRef   = _items.doc(_itemDocId(productName, toBranch));

    final fromSnap = await fromRef.get();
    if (!fromSnap.exists) {
      throw Exception('Product "$productName" not found in $fromBranch.');
    }
    final fromData = fromSnap.data() as Map<String, dynamic>;
    final fromQty  = (fromData['quantity'] as num?)?.toInt() ?? 0;
    if (fromQty < quantity) {
      throw Exception('Insufficient stock in $fromBranch. Available: $fromQty');
    }

    final toSnap = await toRef.get();
    final toQty  = toSnap.exists
        ? ((toSnap.data() as Map<String, dynamic>)['quantity'] as num?)?.toInt() ?? 0
        : 0;

    final now  = Timestamp.fromDate(DateTime.now());
    final date = _currentDate();
    final time = _currentTime();

    final batch = _db.batch();
    batch.update(fromRef, {'quantity': fromQty - quantity, 'updated_at': now});

    if (toSnap.exists) {
      batch.update(toRef, {'quantity': toQty + quantity, 'updated_at': now});
    } else {
      batch.set(toRef, {
        'product_name': productName,
        'quantity':     quantity,
        'branch':       toBranch,
        'category':     fromData['category'] ?? 'consumable',
        'min_stock':    (fromData['min_stock'] as num?)?.toInt() ?? 10,
        'unit':         fromData['unit'] ?? 'pcs',
        'updated_at':   now,
      });
    }

    final outTxn = StockTransaction(
      type:                'TRANSFER_OUT',
      productName:         productName,
      quantity:            quantity,
      person:              transferredBy,
      branch:              fromBranch,
      departmentOrPurpose: 'Transfer to $toBranch',
      date:                date,
      time:                time,
      remarks:             remarks,
    ).toFirestore();
    outTxn['created_at'] = now;

    final inTxn = StockTransaction(
      type:                'TRANSFER_IN',
      productName:         productName,
      quantity:            quantity,
      person:              transferredBy,
      branch:              toBranch,
      departmentOrPurpose: 'Transfer from $fromBranch',
      date:                date,
      time:                time,
      remarks:             remarks,
    ).toFirestore();
    inTxn['created_at'] = now;

    final outTxnRef = _transactions.doc();
    batch.set(outTxnRef, outTxn);
    batch.set(_transactions.doc(), inTxn);

    await batch.commit();
    clearCache();

    ActivityLogService.logEdit(
      module: _module,
      itemName: productName,
      before: {'Quantity in $fromBranch': fromQty, 'Quantity in $toBranch': toQty},
      after: {
        'Quantity in $fromBranch': fromQty - quantity,
        'Quantity in $toBranch': toQty + quantity,
      },
    );

    StaffRewardService.recordActivity(
      action: StaffAction.stockUpdate,
      module: _module,
      refId: 'stock_transfer_${outTxnRef.id}',
    );
  }

  // ── IN-MEMORY CACHE (per branch/type filter combo) ──────────────────────
  // History is filtered server-side (the 200-record limit applies per
  // filter combo, so we can't just filter one big local list without
  // changing which records show up for a given filter — that would be a
  // behavior change). Instead we cache each combo's result, so flipping
  // back and forth between filter chips the user already visited (e.g.
  // All → IN → All) reuses the cached page instead of re-querying.
  static final Map<String, List<StockTransaction>> _historyCache = {};

  static String _historyCacheKey(String? branch, String? type) =>
      '${branch ?? 'All'}|${type ?? 'All'}';

  // ── History — no orderBy, sort client-side ─────────────────────────────────
  static Future<List<StockTransaction>> fetchHistory({
    String? branch,
    String? type,
    bool forceRefresh = false,
  }) async {
    final key = _historyCacheKey(branch, type);
    if (!forceRefresh && _historyCache.containsKey(key)) {
      return _historyCache[key]!;
    }

    Query q = _transactions;
    if (branch != null && branch != 'All') {
      q = q.where('branch', isEqualTo: branch);
    }
    if (type != null && type != 'All') {
      q = q.where('type', isEqualTo: type);
    }

    final snap = await q.limit(200).get();
    final list  = snap.docs.map(StockTransaction.fromFirestore).toList();

    list.sort((a, b) {
      final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });

    _historyCache[key] = list;
    return list;
  }

  static Future<List<StockTransaction>> fetchRecentHistory({int limit = 6}) async {
    final all = await fetchHistory();
    return all.take(limit).toList();
  }

  // ── Item-specific history (used on the item detail screen) ─────────────────
  static Future<List<StockTransaction>> fetchTransactionsForItem(
      String productName, String branch) async {
    final snap = await _transactions
        .where('product_name', isEqualTo: productName)
        .where('branch', isEqualTo: branch)
        .limit(100)
        .get();
    final list = snap.docs.map(StockTransaction.fromFirestore).toList();
    list.sort((a, b) {
      final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });
    return list;
  }

  // ── Real-time stream: items ────────────────────────────────────────────────
  static Stream<List<StockItem>> streamItems({
    String? branch,
    String? category,
  }) {
    Query q = _items;
    if (branch   != null) q = q.where('branch',   isEqualTo: branch);
    if (category != null) q = q.where('category', isEqualTo: category);

    return q.snapshots().map((s) =>
    s.docs.map(StockItem.fromFirestore).toList()
      ..sort((a, b) => a.productName.compareTo(b.productName)));
  }

  // ── Real-time stream: history — no orderBy ─────────────────────────────────
  static Stream<List<StockTransaction>> streamHistory({
    String? branch,
    String? type,
  }) {
    Query q = _transactions;
    if (branch != null && branch != 'All') {
      q = q.where('branch', isEqualTo: branch);
    }
    if (type != null && type != 'All') {
      q = q.where('type', isEqualTo: type);
    }

    return q.limit(100).snapshots().map((s) {
      final list = s.docs.map(StockTransaction.fromFirestore).toList();
      list.sort((a, b) {
        final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  // Firestore treats "/" as a path separator even inside a doc ID string, so
  // a product name containing one (e.g. "Landing Gear/ Stabilizer") would
  // silently split the reference into extra segments and throw
  // invalid-argument. Strip "/" and "." before collapsing whitespace so the
  // ID is always a single flat segment.
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

  static String _currentTime() {
    final now = DateTime.now();
    final h   = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final m   = now.minute.toString().padLeft(2, '0');
    final p   = now.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  static String _currentDate() {
    final now = DateTime.now();
    return '${now.day}-${now.month}-${now.year}';
  }
}