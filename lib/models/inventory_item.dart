// lib/models/inventory_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ── Status helpers ────────────────────────────────────────────────────────────
const Map<String, String> kStatusLabels = {
  'available':   'Available',
  'in_service':  'In Service',
  'maintenance': 'Maintenance',
  'retired':     'Retired',
  'in_stock':    'In Stock',
};

const Map<String, Color> kStatusColors = {
  'available':   Colors.green,
  'in_service':  Colors.red,
  'maintenance': Colors.orange,
  'retired':     Colors.grey,
  'in_stock':    Colors.blue,
};

// ── CategoryMeta ──────────────────────────────────────────────────────────────
class CategoryMeta {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final bool tracksDates;

  const CategoryMeta({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    this.tracksDates = false,
  });
}

// ── Category lists ────────────────────────────────────────────────────────────
const List<CategoryMeta> kAllCategories = [
  CategoryMeta(
    key:         'drone',
    label:       'FPV Drone',
    icon:        Icons.flight_rounded,
    color:       Colors.green,
    tracksDates: true,
  ),
  CategoryMeta(
    key:         'battery',
    label:       'Battery',
    icon:        Icons.battery_charging_full,
    color:       Colors.amber,
    tracksDates: false,
  ),
  CategoryMeta(
    key:         'charger',
    label:       'Charger',
    icon:        Icons.electrical_services,
    color:       Colors.orange,
    tracksDates: false,
  ),
  CategoryMeta(
    key:         'camera',
    label:       'Camera',
    icon:        Icons.camera_alt_rounded,
    color:       Colors.purple,
    tracksDates: true,
  ),
  CategoryMeta(
    key:         'controller',
    label:       'Controller',
    icon:        Icons.sports_esports_rounded,
    color:       Colors.blue,
    tracksDates: false,
  ),
  CategoryMeta(
    key:         'accessory',
    label:       'Accessory',
    icon:        Icons.extension_rounded,
    color:       Colors.teal,
    tracksDates: false,
  ),
  CategoryMeta(
    key:         'other',
    label:       'Other',
    icon:        Icons.inventory_2_rounded,
    color:       Colors.blueGrey,
    tracksDates: false,
  ),
];

// Includes the "All" chip used in the filter UI
const List<CategoryMeta> kAllCategoriesWithAll = [
  CategoryMeta(
    key:   'all',
    label: 'All',
    icon:  Icons.grid_view_rounded,
    color: Colors.blueGrey,
  ),
  ...kAllCategories,
];

// Used in the form dropdown (same as kAllCategories, no "All" entry)
const List<CategoryMeta> kFormCategories = kAllCategories;

CategoryMeta categoryByKey(String key) => kAllCategories.firstWhere(
      (c) => c.key == key,
  orElse: () => kAllCategories.last,
);

// ── InventoryItem ─────────────────────────────────────────────────────────────
class InventoryItem {
  final String? id;       // Firestore document ID (String, not int)
  final int branchId;
  final String itemName;
  final String category;
  final String status;
  final int quantity;
  final String? notes;
  final String? dateIn;
  final String? dateOut;

  const InventoryItem({
    this.id,
    required this.branchId,
    required this.itemName,
    required this.category,
    required this.status,
    required this.quantity,
    this.notes,
    this.dateIn,
    this.dateOut,
  });

  // ── Firestore ───────────────────────────────────────────────────────────────
  factory InventoryItem.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return InventoryItem(
      id:       doc.id,
      branchId: (d['branch_id'] as num?)?.toInt() ?? 0,
      itemName: d['item_name']?.toString()  ?? '',
      category: d['category']?.toString()   ?? 'other',
      status:   d['status']?.toString()     ?? 'available',
      quantity: (d['quantity'] as num?)?.toInt() ?? 0,
      notes:    d['notes']?.toString(),
      dateIn:   d['date_in']?.toString(),
      dateOut:  d['date_out']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'branch_id':  branchId,
    'item_name':  itemName,
    'category':   category,
    'status':     status,
    'quantity':   quantity,
    'notes':      notes,
    'date_in':    dateIn,
    'date_out':   dateOut,
  };

  // ── Legacy JSON ─────────────────────────────────────────────────────────────
  factory InventoryItem.fromJson(Map<String, dynamic> d) => InventoryItem(
    id:       d['id']?.toString(),
    branchId: (d['branch_id'] as num?)?.toInt() ?? 0,
    itemName: d['item_name']?.toString()  ?? '',
    category: d['category']?.toString()   ?? 'other',
    status:   d['status']?.toString()     ?? 'available',
    quantity: (d['quantity'] as num?)?.toInt() ?? 0,
    notes:    d['notes']?.toString(),
    dateIn:   d['date_in']?.toString(),
    dateOut:  d['date_out']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'branch_id':  branchId,
    'item_name':  itemName,
    'category':   category,
    'status':     status,
    'quantity':   quantity,
    'notes':      notes,
    'date_in':    dateIn,
    'date_out':   dateOut,
  };

  // ── copyWith ────────────────────────────────────────────────────────────────
  InventoryItem copyWith({
    String? id,
    int?    branchId,
    String? itemName,
    String? category,
    String? status,
    int?    quantity,
    String? notes,
    String? dateIn,
    String? dateOut,
  }) =>
      InventoryItem(
        id:       id       ?? this.id,
        branchId: branchId ?? this.branchId,
        itemName: itemName ?? this.itemName,
        category: category ?? this.category,
        status:   status   ?? this.status,
        quantity: quantity  ?? this.quantity,
        notes:    notes    ?? this.notes,
        dateIn:   dateIn   ?? this.dateIn,
        dateOut:  dateOut  ?? this.dateOut,
      );
}

// ── BranchSummary ─────────────────────────────────────────────────────────────
class BranchSummary {
  final String branch;
  final int totalItems;
  final int droneCount;
  final int inServiceCount;
  final String status;
  final Map<String, int> categoryBreakdown;

  const BranchSummary({
    required this.branch,
    required this.totalItems,
    required this.droneCount,
    required this.inServiceCount,
    required this.status,
    required this.categoryBreakdown,
  });

  /// Compute summary client-side from a list of Firestore items.
  factory BranchSummary.fromItems(
      String branchLabel, List<InventoryItem> items) {
    final breakdown = <String, int>{};
    int drones    = 0;
    int inService = 0;

    for (final item in items) {
      breakdown[item.category] =
          (breakdown[item.category] ?? 0) + item.quantity;
      if (item.category == 'drone')      drones    += item.quantity;
      if (item.status   == 'in_service') inService += item.quantity;
    }

    final total =
    items.fold<int>(0, (sum, i) => sum + i.quantity);

    return BranchSummary(
      branch:            branchLabel,
      totalItems:        total,
      droneCount:        drones,
      inServiceCount:    inService,
      status:            total > 0 ? 'Active' : 'Empty',
      categoryBreakdown: breakdown,
    );
  }

  // Keep fromJson so nothing else breaks
  factory BranchSummary.fromJson(Map<String, dynamic> json) => BranchSummary(
    branch:            json['branch']?.toString() ?? '',
    totalItems:        (json['total_items']       as num?)?.toInt() ?? 0,
    droneCount:        (json['drone_count']       as num?)?.toInt() ?? 0,
    inServiceCount:    (json['in_service_count']  as num?)?.toInt() ?? 0,
    status:            json['status']?.toString() ?? '',
    categoryBreakdown: Map<String, int>.from(
        json['category_breakdown'] ?? {}),
  );
}