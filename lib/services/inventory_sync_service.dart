// lib/services/inventory_sync_service.dart
//
// Cross-module propagation. Whenever an item is added OR deleted via
// InventoryService or NewProductService, this applies the same change to
// every other module so nothing has to be entered (or removed) twice:
//
//   Inventory add/delete     → Search Products, Branch module, Stock
//                               Management, Fixed Assets OR Consumables
//                               (auto-classified)
//   New Product add/delete  → Inventory, Search Products, Branch module,
//                               Stock Management, Fixed Assets OR
//                               Consumables
//
// Each downstream write is isolated in its own try/catch so a failure in
// one module (e.g. a bad branch id) never blocks the others or the
// original add/delete the user is waiting on.
//
// Downstream modules don't store a cross-collection id back to the item
// that created them, so deletes are matched the same simple way adds are
// written: by name (+ branch, in the modules that track one). Stock
// Management is the one exception — its doc id is already deterministic
// (name + branch), so a delete decrements/removes that exact doc instead
// of running a name query.

import 'package:flutter/foundation.dart';

import 'package:cda_inventory/models/inventory_model.dart' as inv_model;
import 'package:cda_inventory/models/new_product.dart';
import 'package:cda_inventory/models/inventory_item.dart' as branch_model;

import 'package:cda_inventory/services/product_service.dart';
import 'package:cda_inventory/services/branch_inventory_service.dart';
import 'package:cda_inventory/services/stock_service.dart';
import 'package:cda_inventory/services/fixed_asset_service.dart';
import 'package:cda_inventory/services/consumable_service.dart';
import 'package:cda_inventory/services/inventory_service.dart';

class InventorySyncService {
  InventorySyncService._();

  // ── Category classification ─────────────────────────────────────────
  // Anything durable/equipment-like is a Fixed Asset; anything that gets
  // used up / restocked is a Consumable. Covers both the Inventory
  // module's category list and the New Products module's category list.
  static const Set<String> _fixedAssetCategories = {
    'ONFIELD',
    'RPTO',
    'ELECTRICAL',
    'TOOL KITS',
    'LAB ROOM',
    'CHARGING STATION',
    'NAVIN KIT',
    'FPV DRONES',
    'REMOTE CONTROLLER',
    'ADDITIONAL DRONE SPARE',
    '3D PRINTER',
    'MANAGER ROOM',
    'INSTRUCTOR ROOM',
    'FRAMES',
    'MOTORS & ESCS',
    'FLIGHT CONTROLLERS',
    'CAMERAS & FPV',
    'RADIOS & RECEIVERS',
    'TOOLS & ACCESSORIES',
    'COMPLETE DRONE / KIT',
  };

  static bool isFixedAsset(String category) {
    final norm = category.trim().toUpperCase();
    // Stock Management already speaks in these two literal buckets —
    // trust them directly instead of running them through the
    // Inventory/New Products category list, which they'd never match.
    if (norm == 'FIXED_ASSET') return true;
    if (norm == 'CONSUMABLE') return false;
    return _fixedAssetCategories.contains(norm);
  }

  // ── Branch module category-key inference ────────────────────────────
  static String _branchCategoryKey(String category) {
    final c = category.toLowerCase();
    if (c.contains('drone')) return 'drone';
    if (c.contains('batter')) return 'battery';
    if (c.contains('charg')) return 'charger';
    if (c.contains('camera') || c.contains('fpv')) return 'camera';
    if (c.contains('control') || c.contains('remote')) return 'controller';
    if (c.contains('accessor') || c.contains('tool') || c.contains('spare')) {
      return 'accessory';
    }
    return 'other';
  }

  static int _branchIdFromLabel(String label) {
    final l = label.trim().toLowerCase();
    if (l.contains('admin')) return 1;
    if (l.contains('ops')) return 2;
    return 1; // safe default so nothing silently disappears from Branch
  }

  static String _branchLabelFromId(int id) => id == 2 ? 'CDA Ops' : 'CDA Admin';

  // ── Shared downstream push (Search Products / Branch / Stock / FA-CO) ─
  static Future<void> _pushDownstream({
    required String name,
    required String category,
    required int quantity,
    required String branchLabel,
    String location = '',
    String description = '',
    String? addedBy,
    bool includeStock = true,
  }) async {
    // 1) Search Products module
    try {
      await ProductService.addProduct({
        'name': name,
        'category': category,
        'quantity': quantity,
        'price': 0.0,
        'notes': description,
      });
    } catch (e) {
      debugPrint('InventorySyncService: Search Products sync failed: $e');
    }

    // 2) Branch module
    try {
      final branchId = _branchIdFromLabel(branchLabel);
      await BranchInventoryService.createItem(
        branchId,
        branch_model.InventoryItem(
          branchId: branchId,
          itemName: name,
          category: _branchCategoryKey(category),
          status: 'available',
          quantity: quantity,
          notes: description.isEmpty ? null : description,
        ),
      );
    } catch (e) {
      debugPrint('InventorySyncService: Branch module sync failed: $e');
    }

    // 3) Stock Management module — skipped when the caller is Stock
    //    Management itself (it already wrote this item directly; running
    //    it again here would double the quantity).
    if (includeStock) {
      try {
        await StockService.addStockIn(
          productName: name,
          quantity: quantity,
          receivedBy: addedBy?.isNotEmpty == true ? addedBy! : 'System Sync',
          branch: branchLabel,
          date: DateTime.now().toIso8601String(),
          remarks: 'Auto-synced from ${description.isEmpty ? 'module add' : description}',
          category: isFixedAsset(category) ? 'fixed_asset' : 'consumable',
        );
      } catch (e) {
        debugPrint('InventorySyncService: Stock Management sync failed: $e');
      }
    }

    // 4) Fixed Assets OR Consumables (auto-segregated)
    try {
      if (isFixedAsset(category)) {
        await FixedAssetService.addAsset({
          'name': name,
          'quantity': quantity,
          'branch': branchLabel,
          'location': location,
          'description': description,
          'category': category,
          'status': 'Active',
        });
      } else {
        await ConsumableService.addConsumable({
          'name': name,
          'category': category,
          'quantity': quantity,
          'minimumStock': 5,
          'description': description,
          'branch': branchLabel == 'CDA Admin' ? 'Branch 1' : 'Branch 2',
          'addedBy': addedBy,
        });
      }
    } catch (e) {
      debugPrint('InventorySyncService: Fixed Assets/Consumables sync failed: $e');
    }
  }

  // ── Entry point: called after InventoryService.addProduct() ─────────
  static Future<void> syncFromInventoryAdd(inv_model.InventoryItem item) async {
    await _pushDownstream(
      name: item.name,
      category: item.category,
      quantity: item.quantity,
      branchLabel: item.branchLabel,
      location: item.location,
      description: item.description,
      addedBy: item.addedBy,
    );
  }

  // ── Entry point: called after NewProductService.addNewProduct() ─────
  static Future<void> syncFromNewProductAdd(NewProduct product) async {
    // a) Push into Inventory first (skipDownstreamSync avoids a duplicate
    //    round of Search Products / Branch / Stock / FA-CO writes, since
    //    we run that ourselves right below with the New Product's data).
    try {
      await InventoryService().addProduct(
        name: product.productName,
        category: product.category,
        location: product.storageLocation,
        quantity: product.quantity,
        description: product.description,
        branch: _branchIdFromLabel(product.branch),
        addedBy: product.addedBy,
        skipDownstreamSync: true,
      );
    } catch (e) {
      debugPrint('InventorySyncService: Inventory sync failed: $e');
    }

    // b) Search Products / Branch / Stock / Fixed Assets / Consumables
    await _pushDownstream(
      name: product.productName,
      category: product.category,
      quantity: product.quantity,
      branchLabel: product.branch.isEmpty ? _branchLabelFromId(1) : product.branch,
      location: product.storageLocation,
      description: product.description,
      addedBy: product.addedBy,
    );
  }

  // ── Shared downstream delete (Search Products / Branch / Stock / FA-CO) ─
  // Mirrors _pushDownstream(), but removes instead of creates. Matched by
  // name (+ branch where the module tracks one), the same way the add-sync
  // matches nothing at all — there's no stored cross-collection id, so a
  // delete here removes every doc in each module whose name (and branch,
  // where applicable) matches what was just deleted upstream.
  static Future<void> _deleteDownstream({
    required String name,
    required String category,
    required int quantity,
    required String branchLabel,
    bool includeStock = true,
  }) async {
    // 1) Search Products module
    try {
      await ProductService.deleteByName(name);
    } catch (e) {
      debugPrint('InventorySyncService: Search Products delete-sync failed: $e');
    }

    // 2) Branch module
    try {
      final branchId = _branchIdFromLabel(branchLabel);
      await BranchInventoryService.deleteByNameAndBranch(branchId, name);
    } catch (e) {
      debugPrint('InventorySyncService: Branch module delete-sync failed: $e');
    }

    // 3) Stock Management module — skipped when the caller is Stock
    //    Management itself, same as the add-sync.
    if (includeStock) {
      try {
        await StockService.removeStockSync(
          productName: name,
          branch: branchLabel,
          quantity: quantity,
        );
      } catch (e) {
        debugPrint('InventorySyncService: Stock Management delete-sync failed: $e');
      }
    }

    // 4) Fixed Assets OR Consumables (auto-segregated, same rule as add)
    try {
      if (isFixedAsset(category)) {
        await FixedAssetService.deleteByName(name);
      } else {
        await ConsumableService.deleteByName(name);
      }
    } catch (e) {
      debugPrint('InventorySyncService: Fixed Assets/Consumables delete-sync failed: $e');
    }
  }

  // ── Entry point: called after InventoryService.deleteProduct() ──────
  static Future<void> syncFromInventoryDelete(inv_model.InventoryItem item) async {
    await _deleteDownstream(
      name: item.name,
      category: item.category,
      quantity: item.quantity,
      branchLabel: item.branchLabel,
    );
  }

  // ── Entry point: called after NewProductService.deleteNewProduct() ──
  static Future<void> syncFromNewProductDelete(NewProduct product) async {
    final branchLabel =
    product.branch.isEmpty ? _branchLabelFromId(1) : product.branch;

    // a) Remove the Inventory copy that syncFromNewProductAdd created.
    try {
      await InventoryService.deleteByName(product.productName);
    } catch (e) {
      debugPrint('InventorySyncService: Inventory delete-sync failed: $e');
    }

    // b) Search Products / Branch / Stock / Fixed Assets / Consumables
    await _deleteDownstream(
      name: product.productName,
      category: product.category,
      quantity: product.quantity,
      branchLabel: branchLabel,
    );
  }

  // ── Entry point: called after a Stock Management add ────────────────
  // (StockService.addStockIn / bulk import). The stock item itself has
  // already been written by the caller, so this only fans out to Search
  // Products, the Branch module, and Fixed Assets OR Consumables —
  // `category` is expected to be the literal 'consumable' / 'fixed_asset'
  // bucket Stock Management already uses, which isFixedAsset() now
  // understands directly.
  static Future<void> syncFromStockAdd({
    required String name,
    required String category,
    required int quantity,
    required String branchLabel,
    String location = '',
    String description = '',
    String? addedBy,
  }) async {
    await _pushDownstream(
      name: name,
      category: category,
      quantity: quantity,
      branchLabel: branchLabel,
      location: location,
      description: description,
      addedBy: addedBy,
      includeStock: false,
    );
  }
}