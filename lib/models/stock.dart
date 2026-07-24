// lib/models/stock.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// ── StockItem ─────────────────────────────────────────────────────────────────
class StockItem {
  final String? id;
  final String productName;
  final int quantity;
  final String branch;
  final String category;
  final int minStock;
  final String? sku;
  final String unit;
  final String? location;
  final Timestamp? updatedAt;

  StockItem({
    this.id,
    required this.productName,
    required this.quantity,
    required this.branch,
    required this.category,
    this.minStock = 10,
    this.sku,
    this.unit = 'pcs',
    this.location,
    this.updatedAt,
  });

  factory StockItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockItem(
      id:          doc.id,
      productName: data['product_name'] ?? '',
      quantity:    (data['quantity']    as num?)?.toInt() ?? 0,
      branch:      data['branch']       ?? '',
      category:    data['category']     ?? 'consumable',
      minStock:    (data['min_stock']   as num?)?.toInt() ?? 10,
      sku:         data['sku']?.toString(),
      unit:        data['unit']?.toString() ?? 'pcs',
      location:    data['location']?.toString(),
      updatedAt:   data['updated_at'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'product_name': productName,
    'quantity':     quantity,
    'branch':       branch,
    'category':     category,
    'min_stock':    minStock,
    if (sku != null) 'sku': sku,
    'unit':         unit,
    if (location != null) 'location': location,
  };

  bool get isLowStock => quantity <= minStock;

  /// 0.0–1.0+ fill level relative to the minimum stock threshold.
  double get stockRatio => minStock > 0 ? quantity / minStock : 1.0;

  /// How many units are needed to get back above the minimum threshold.
  /// 0 when stock is already at or above the minimum.
  int get unitsToReorder => quantity < minStock ? (minStock - quantity) : 0;

  StockItem copyWith({
    int? quantity,
    String? category,
    int? minStock,
    String? sku,
    String? unit,
    String? location,
  }) =>
      StockItem(
        id:          id,
        productName: productName,
        quantity:    quantity   ?? this.quantity,
        branch:      branch,
        category:    category   ?? this.category,
        minStock:    minStock   ?? this.minStock,
        sku:         sku        ?? this.sku,
        unit:        unit       ?? this.unit,
        location:    location   ?? this.location,
        updatedAt:   updatedAt,
      );
}

// ── StockTransaction ──────────────────────────────────────────────────────────
// type is one of: IN, OUT, ADJUST, TRANSFER_IN, TRANSFER_OUT
class StockTransaction {
  final String? id;
  final String type;
  final String productName;
  final int quantity;
  final String person;
  final String branch;
  final String departmentOrPurpose;
  final String date;
  final String time;
  final String? remarks;
  final Timestamp? createdAt;

  StockTransaction({
    this.id,
    required this.type,
    required this.productName,
    required this.quantity,
    required this.person,
    required this.branch,
    required this.departmentOrPurpose,
    required this.date,
    required this.time,
    this.remarks,
    this.createdAt,
  });

  factory StockTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockTransaction(
      id:                  doc.id,
      type:                data['type']                   ?? 'IN',
      productName:         data['product_name']           ?? '',
      quantity:            (data['quantity'] as num?)?.toInt() ?? 0,
      person:              data['person']                 ?? '',
      branch:              data['branch']                 ?? '',
      departmentOrPurpose: data['department_or_purpose'] ?? '',
      date:                data['date']                  ?? '',
      time:                data['time']                  ?? '',
      remarks:             data['remarks']?.toString(),
      createdAt:           data['created_at'] as Timestamp?,
    );
  }

  bool get isInbound  => type == 'IN' || type == 'TRANSFER_IN';
  bool get isOutbound => type == 'OUT' || type == 'TRANSFER_OUT';
  bool get isAdjustment => type == 'ADJUST';

  DateTime? get dateTime {
    final parts = date.split('-');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  // ── NO created_at here — service layer adds it to avoid web SDK conflict ──
  Map<String, dynamic> toFirestore() => {
    'type':                  type,
    'product_name':          productName,
    'quantity':              quantity,
    'person':                person,
    'branch':                branch,
    'department_or_purpose': departmentOrPurpose,
    'date':                  date,
    'time':                  time,
    'remarks':               remarks ?? '',
  };
}

// ── Dashboard aggregates ──────────────────────────────────────────────────────
class StockDashboardData {
  final int totalProducts;
  final int lowStockCount;
  final int fixedAssets;
  final int consumables;
  final List<BranchStock> branchStocks;
  final List<StockItem> lowStockItems;
  final List<StockTransaction> recentActivity;

  StockDashboardData({
    required this.totalProducts,
    required this.lowStockCount,
    required this.fixedAssets,
    required this.consumables,
    required this.branchStocks,
    required this.lowStockItems,
    this.recentActivity = const [],
  });
}

class BranchStock {
  final String branch;
  final int itemCount;

  BranchStock({required this.branch, required this.itemCount});
}