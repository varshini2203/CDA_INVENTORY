// lib/screens/inventory/inventory_dashboard.dart

import 'package:flutter/material.dart';
import '../../models/inventory_model.dart';
import '../../services/inventory_service.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';
import 'package:cda_inventory/data/seed_products.dart';
import 'package:cda_inventory/data/seed_adambakkam_inventory_dashboard.dart';
import 'package:cda_inventory/services/seed_guard_service.dart';

class InventoryDashboard extends StatefulWidget {
  const InventoryDashboard({super.key});

  @override
  State<InventoryDashboard> createState() => _InventoryDashboardState();
}

class _InventoryDashboardState extends State<InventoryDashboard>
    with SingleTickerProviderStateMixin {
  // ── Firestore stream replaces the http-fetched list ────────────────────────
  // Raw list from Firestore (always full, unfiltered)
  List<InventoryItem> inventory = [];

  // Derived list after search / category / sort
  List<InventoryItem> filteredInventory = [];

  bool isLoading = true;
  bool isGridView = false;
  bool isSeedingData = false;
  String selectedCategory = "ALL";
  int selectedBranch = 0; // 0 = All Branches, 1 = Branch 1, 2 = Branch 2
  String searchQuery = "";
  // sortBy: 'name' | 'quantity' | 'category' | 'date' | 'lowStock'
  String sortBy = "name";
  bool sortAscending = true;

  final TextEditingController _searchController = TextEditingController();
  late AnimationController _fabAnimController;

  // ── In-memory guard cache ────────────────────────────────────────────────
  // _autoSeedIfNeeded() used to call SeedGuardService.hasSeeded
  // ('inventory_branch_migration') — a Firestore read — every single time
  // this screen loaded or reloaded (initState, pull-to-refresh, and after
  // every add/edit/delete/seed). The answer can only ever go from false to
  // true, once, for the lifetime of the app install, so once we've seen it
  // return true we cache that in memory and never pay for that read again
  // for the rest of this app session. `static` so the cache survives even
  // if this State object is disposed and recreated (e.g. navigating away
  // and back), not just across rebuilds of a single instance.
  static bool _branchMigrationDoneCache = false;

  // ── Design tokens (matches Invoices theme) ──────────────────────────────
  static const Color kNavy    = Color(0xFF0A1628);
  static const Color kTeal    = Color(0xFF00D4AA);
  static const Color kCoral   = Color(0xFFFF6B6B);
  static const Color kAmber   = Color(0xFFFFB800);
  static const Color kSurface = Color(0xFFF0F4F8);
  static const Color kGreen   = Color(0xFF00B894);
  static const Color kPurple  = Color(0xFF6C63FF);

  static const List<String> categories = [
    "ALL",
    "ONFIELD",
    "RPTO",
    "STATIONARY",
    "ELECTRICAL",
    "TOOL KITS",
    "LAB ROOM",
    "CHARGING STATION",
    "NAVIN KIT",
    "FPV DRONES",
    "REMOTE CONTROLLER",
    "ADDITIONAL DRONE SPARE",
    "3D PRINTER",
    "HOUSEKEEPING SUPPLIES",
    "MANAGER ROOM",
    "INSTRUCTOR ROOM",
    "CORRIDOR THINGS",
    "REST ROOM THING",
  ];

  static const Map<String, IconData> categoryIcons = {
    "ALL": Icons.apps_rounded,
    "ONFIELD": Icons.flight_takeoff,
    "RPTO": Icons.verified_user,
    "STATIONARY": Icons.edit_note,
    "ELECTRICAL": Icons.electrical_services,
    "TOOL KITS": Icons.construction,
    "LAB ROOM": Icons.science,
    "CHARGING STATION": Icons.battery_charging_full,
    "NAVIN KIT": Icons.backpack,
    "FPV DRONES": Icons.videocam,
    "REMOTE CONTROLLER": Icons.sports_esports,
    "ADDITIONAL DRONE SPARE": Icons.build_circle,
    "3D PRINTER": Icons.print,
    "HOUSEKEEPING SUPPLIES": Icons.cleaning_services,
    "MANAGER ROOM": Icons.meeting_room,
    "INSTRUCTOR ROOM": Icons.school,
    "CORRIDOR THINGS": Icons.door_sliding,
    "REST ROOM THING": Icons.wc,
  };

  // Category accent colors kept as-is — these are data-level distinctions,
  // not part of the app shell theme, so they stay untouched.
  static const Map<String, Color> categoryColors = {
    "ALL": Color(0xFF1565C0),
    "ONFIELD": Color(0xFF2E7D32),
    "RPTO": Color(0xFF6A1B9A),
    "STATIONARY": Color(0xFFE65100),
    "ELECTRICAL": Color(0xFFF9A825),
    "TOOL KITS": Color(0xFF37474F),
    "LAB ROOM": Color(0xFF00838F),
    "CHARGING STATION": Color(0xFF558B2F),
    "NAVIN KIT": Color(0xFF4527A0),
    "FPV DRONES": Color(0xFFC62828),
    "REMOTE CONTROLLER": Color(0xFF00695C),
    "ADDITIONAL DRONE SPARE": Color(0xFF4E342E),
    "3D PRINTER": Color(0xFF1565C0),
    "HOUSEKEEPING SUPPLIES": Color(0xFF00838F),
    "MANAGER ROOM": Color(0xFF283593),
    "INSTRUCTOR ROOM": Color(0xFF1B5E20),
    "CORRIDOR THINGS": Color(0xFF4A148C),
    "REST ROOM THING": Color(0xFF880E4F),
  };

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadInventoryOnce();
  }

  // ── Single one-shot Firestore read, reused for display AND for the
  //    auto-seed / migration checks below (was: a live watchInventory()
  //    listener + 2 separate full-collection reads — 3x the reads on
  //    every screen open). Call this from initState, pull-to-refresh, and
  //    after any add/edit/delete/seed — never from build(). ─────────────
  Future<void> _loadInventoryOnce() async {
    setState(() => isLoading = true);
    try {
      final items = await InventoryService().getInventory();
      if (!mounted) return;
      setState(() {
        inventory = items;
        _applyFilters();
        isLoading = false;
      });
      // Reuse the list we just read instead of issuing 1-2 more full
      // collection reads to answer "is it empty" / "does it need migration".
      await _autoSeedIfNeeded(items);
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showError("Firestore error: $e");
    }
  }

  /// On a brand-new install the 'inventory' collection is empty. Push both
  /// branches' item lists in automatically the first time so everything
  /// shows up here without the user needing to find and tap the seed
  /// buttons manually. If the collection already has data but it predates
  /// Branch 1 / Branch 2 tagging (no 'branch' field on any document), wipe
  /// and reseed once so every item gets tagged correctly.
  ///
  /// Takes the list already loaded by _loadInventoryOnce() instead of
  /// re-querying Firestore to check "is it empty" / "does it need branch
  /// migration" — that used to cost 2 extra full-collection reads on
  /// every single screen open.
  Future<void> _autoSeedIfNeeded(List<InventoryItem> existing) async {
    try {
      if (existing.isEmpty) {
        // Guarded like SearchScreen's product auto-seed: once this has
        // run one time for this installation, it can never fire again
        // automatically, even if the collection is later emptied (e.g.
        // during testing). Without this guard, any transient read
        // failure that made `existing` look empty would silently
        // reseed ~1,560 documents again.
        final alreadySeeded = await SeedGuardService.hasSeeded('inventory');
        if (alreadySeeded) return;
        await InventoryService()
            .seedAllProducts(SeedProducts.allProducts, branchOverride: 2);
        await InventoryService().seedAllProducts(
            SeedAdambakkamInventoryDashboard.allProducts,
            branchOverride: 1);
        await SeedGuardService.markSeeded('inventory');
        if (mounted) await _loadInventoryOnce();
        return;
      }

      // ── Branch-migration guard ────────────────────────────────────────
      // THIS WAS THE ROOT CAUSE of the 96k reads / 16k writes / 20k
      // deletes seen in the Firebase console. `_seedProductsBatch()`
      // used to default every seeded item's `branch` to 0 whenever the
      // raw seed map didn't contain a 'branch' key — which is true for
      // every single entry in both seed_products.dart and
      // seed_adambakkam_inventory_dashboard.dart. That means the
      // client-side check below (`every item's branch == 0`) was
      // ALWAYS true, even immediately after wipeAndReseedWithBranches()
      // ran specifically to fix it — so every single Inventory
      // Dashboard open re-triggered a full wipe (read + delete of all
      // ~1,560 docs) and a full reseed (another ~1,560 writes), forever.
      //
      // Two independent fixes are now in place:
      //   1. seedAllProducts()/wipeAndReseedWithBranches() take an
      //      explicit branchOverride so real branch numbers (1 for
      //      Adambakkam, 2 for Branch 2) are actually written, so the
      //      condition below stops being true after the first fix.
      //   2. This SeedGuardService guard means the migration can only
      //      ever run ONCE per installation regardless of what the
      //      in-memory branch check sees on any future screen open —
      //      a destructive wipe+rewrite of the whole collection should
      //      never be allowed to run silently and repeatedly no matter
      //      what triggers it.
      // Check the in-memory cache first — if we already know this is done,
      // skip the Firestore read entirely (short-circuit evaluation means
      // SeedGuardService.hasSeeded() is never called once the cache is true).
      final alreadyMigrated = _branchMigrationDoneCache ||
          await SeedGuardService.hasSeeded('inventory_branch_migration');
      if (alreadyMigrated) {
        _branchMigrationDoneCache = true;
        return;
      }

      // Cheap client-side check on the list we already have in memory —
      // no additional Firestore read.
      final needsMigration = existing.every((i) => i.branch == 0) &&
          existing.isNotEmpty;
      if (needsMigration) {
        // ── FIX ────────────────────────────────────────────────────────
        // This used to call InventoryService().wipeAndReseedWithBranches()
        // automatically, right here, with no user confirmation, and only
        // called markSeeded() AFTER it finished successfully. If that
        // wipe+reseed ever threw partway through — a dropped batch commit,
        // a transient offline error, or the Firestore delete/write quota
        // running out mid-operation — execution jumped straight to the
        // catch(_) block below, markSeeded() was never reached, and the
        // in-memory `_branchMigrationDoneCache` was never set either.
        // That means the exact same "delete everything, then reseed
        // everything" operation silently re-ran on every single future
        // screen open, forever — each retry deleting whatever partial
        // data was left over from the last failed attempt. That is what
        // produced the 20,000-deletes/day quota exhaustion, and it is
        // exactly what left the collection in the half-deleted, all-
        // branch-0, 335-of-1,560-items state you're seeing on screen.
        //
        // A destructive whole-collection delete+rewrite must never run
        // silently or automatically, and must never be allowed to retry
        // on its own after a failure. So this now only sets a flag and
        // tells the admin to run it manually — the actual wipe+reseed
        // lives in _resetAndReseedInventory() below, behind an explicit
        // confirmation dialog, same as Branch Inventory's "Clear &
        // Re-seed".
        _needsBranchMigrationBanner = true;
        if (mounted) setState(() {});
      } else {
        // Nothing to migrate — mark it done anyway so this check never
        // needs to run again on future screen opens.
        await SeedGuardService.markSeeded('inventory_branch_migration');
        _branchMigrationDoneCache = true;
      }
    } catch (_) {
      // Silent — user can still seed/reset manually via the ⋮ menu.
    }
  }

  // Set when _autoSeedIfNeeded() detects every item still has branch == 0.
  // Shows a banner pointing the admin at the manual "Reset & Re-seed
  // Inventory" action instead of ever wiping the collection automatically.
  bool _needsBranchMigrationBanner = false;

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimController.dispose();
    super.dispose();
  }

  // ── Seed all products ──────────────────────────────────────────────────────
  Future<void> _seedAllProducts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.cloud_upload_rounded, color: kTeal),
            SizedBox(width: 8),
            Text("Seed All Products",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'This will add all ${SeedProducts.allProducts.length} pre-defined products to Firestore.\n\nThis is a one-time setup action. Continue?',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kTeal,
              foregroundColor: kNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.upload_rounded, size: 16),
            label: const Text("Seed Now"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isSeedingData = true);

    final result = await InventoryService()
        .seedAllProducts(SeedProducts.allProducts, branchOverride: 2);

    if (!mounted) return;
    setState(() => isSeedingData = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text("Seeded: ${result['success']} added, ${result['failed']} skipped"),
        ]),
        backgroundColor: kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
      ),
    );
    await _loadInventoryOnce(); // one fresh read after the write
  }

  // ── Seed Adambakkam (Branch 1) products only ───────────────────────────────
  Future<void> _seedAdambakkam() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.location_city_rounded, color: kTeal),
            SizedBox(width: 8),
            Text("Seed Adambakkam Products",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'This will add all ${SeedAdambakkamInventoryDashboard.allProducts.length} '
              'items from the Adambakkam (Branch 1) inventory spreadsheet to '
              'Firestore.\n\nThis is safe to run once — it will not touch or '
              'duplicate any existing items. Continue?',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kTeal,
              foregroundColor: kNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.upload_rounded, size: 16),
            label: const Text("Seed Now"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isSeedingData = true);

    final result = await InventoryService().seedAllProducts(
        SeedAdambakkamInventoryDashboard.allProducts,
        branchOverride: 1);

    if (!mounted) return;
    setState(() => isSeedingData = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text("Adambakkam seeded: ${result['success']} added, ${result['failed']} skipped"),
        ]),
        backgroundColor: kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
      ),
    );
    await _loadInventoryOnce(); // one fresh read after the write
  }

  // ── Reset & Re-seed Inventory (manual, explicit, confirmed) ────────────────
  // This is the ONLY place a full wipe-and-reseed of the 'inventory'
  // collection is allowed to happen. It replaces the old automatic call
  // inside _autoSeedIfNeeded() — see the comment there for why that was
  // unsafe. Guarded against double-taps with _isResetting, same pattern
  // as Branch Inventory's "Clear & Re-seed".
  bool _isResetting = false;

  Future<void> _resetAndReseedInventory() async {
    if (_isResetting) return; // already running — ignore duplicate taps

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: kCoral),
            SizedBox(width: 8),
            Text('Reset & Re-seed Inventory?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'This will permanently delete ALL ${inventory.length} current items '
              'in Inventory, then upload a clean copy of both branches '
              '(${SeedAdambakkamInventoryDashboard.allProducts.length} for Branch 1, '
              '${SeedProducts.allProducts.length} for Branch 2) with the correct '
              'branch tags.\n\nUse this if Branch 1 / Branch 2 show 0 items or the '
              'total looks wrong.\n\nThis cannot be undone. Continue?',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset & Re-seed'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() {
      _isResetting = true;
      isSeedingData = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: kCoral)),
    );

    try {
      await InventoryService().wipeAndReseedWithBranches([
        MapEntry(1, SeedAdambakkamInventoryDashboard.allProducts),
        MapEntry(2, SeedProducts.allProducts),
      ]);
      // Only mark the guards done — and only clear the banner — once the
      // wipe+reseed has actually completed without throwing. If this line
      // is never reached, 'inventory_branch_migration' stays unmarked and
      // _needsBranchMigrationBanner stays true, but nothing retries on its
      // own — the admin will see the banner and can just tap this again.
      await SeedGuardService.markSeeded('inventory');
      await SeedGuardService.markSeeded('inventory_branch_migration');
      _branchMigrationDoneCache = true;
      _needsBranchMigrationBanner = false;

      if (!mounted) return;
      Navigator.pop(context); // close loader
      await _loadInventoryOnce();
      _showResetSnack(
        'Inventory reset and re-seeded '
            '(${SeedAdambakkamInventoryDashboard.allProducts.length + SeedProducts.allProducts.length} items).',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loader
      // Deliberately NOT retried automatically and NOT marked as seeded —
      // the admin sees the exact error and can re-run manually once the
      // underlying issue (offline, permissions, quota) is resolved.
      _showResetSnack('Reset & re-seed failed: $e', isError: true);
    } finally {
      if (mounted) setState(() {
        _isResetting = false;
        isSeedingData = false;
      });
    }
  }

  void _showResetSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: isError ? kCoral : kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Widget _buildBranchMigrationBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCoral.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kCoral.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: kCoral),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Items are missing a branch tag — Branch 1 / Branch 2 will show 0. '
                  'Use ⋮ → "Reset & Re-seed Inventory" to fix this.',
              style: TextStyle(fontSize: 12.5, color: kNavy),
            ),
          ),
          TextButton(
            onPressed: _isResetting ? null : _resetAndReseedInventory,
            child: const Text('Fix now', style: TextStyle(color: kCoral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Filters & sort ─────────────────────────────────────────────────────────
  void _applyFilters() {
    List<InventoryItem> result = inventory;

    if (selectedBranch != 0) {
      result = result.where((item) => item.branch == selectedBranch).toList();
    }

    if (selectedCategory != "ALL") {
      result =
          result.where((item) => item.category == selectedCategory).toList();
    }

    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((item) {
        return item.name.toLowerCase().contains(q) ||
            item.location.toLowerCase().contains(q) ||
            item.category.toLowerCase().contains(q);
      }).toList();
    }

    result.sort((a, b) {
      int cmp;
      switch (sortBy) {
        case 'quantity':
          cmp = a.quantity.compareTo(b.quantity);
          break;
        case 'category':
          cmp = a.category.compareTo(b.category);
          break;
        case 'date':
        // Items without a createdAt (legacy/seeded before the field
        // existed) sort to the bottom regardless of direction, rather
        // than clumping at whichever end epoch-zero would land on.
          final aDate = a.createdAt;
          final bDate = b.createdAt;
          if (aDate == null && bDate == null) {
            cmp = 0;
          } else if (aDate == null) {
            cmp = 1;
          } else if (bDate == null) {
            cmp = -1;
          } else {
            cmp = aDate.compareTo(bDate);
          }
          break;
        case 'lowStock':
        // Lowest quantity first, always — this option has a fixed
        // direction so the toolbar toggle doesn't apply to it.
          cmp = a.quantity.compareTo(b.quantity);
          break;
        default:
          cmp = a.name.compareTo(b.name);
      }
      // 'lowStock' ignores the asc/desc toggle by design (always low → high).
      if (sortBy == 'lowStock') return cmp;
      return sortAscending ? cmp : -cmp;
    });

    filteredInventory = result;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: kCoral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<void> _confirmDelete(InventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: kCoral),
            SizedBox(width: 8),
            Text("Delete Item",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Remove "${item.name}" from inventory?',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await InventoryService().deleteProduct(item.id); // String id
        await _loadInventoryOnce(); // one fresh read after the write
      } catch (e) {
        _showError('Delete failed: $e');
      }
    }
  }

  // ── Stats ──────────────────────────────────────────────────────────────────
  int get _totalItems => inventory.length;
  int get _totalQuantity =>
      inventory.fold(0, (sum, item) => sum + item.quantity);
  int get _lowStockCount =>
      inventory.where((item) => item.isLowStock).length;
  int get _outOfStockCount =>
      inventory.where((item) => item.isOutOfStock).length;

  Color _categoryColor(String? cat) =>
      categoryColors[cat] ?? kTeal;
  IconData _categoryIcon(String? cat) =>
      categoryIcons[cat] ?? Icons.inventory_2;
  Color _qtyColor(int qty) {
    if (qty == 0) return kCoral;
    if (qty <= 2) return kAmber;
    return kGreen;
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              if (!isLoading) ...[
                if (_needsBranchMigrationBanner)
                  SliverToBoxAdapter(child: _buildBranchMigrationBanner()),
                SliverToBoxAdapter(child: _buildStatsRow()),
                SliverToBoxAdapter(child: _buildBranchToggle()),
                SliverToBoxAdapter(child: _buildSearchBar()),
                SliverToBoxAdapter(child: _buildCategoryChips()),
                SliverToBoxAdapter(child: _buildToolbar()),
                _buildInventoryList(),
              ] else
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: kTeal)),
                ),
            ],
          ),

          // Seeding overlay
          if (isSeedingData)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: kTeal),
                      const SizedBox(height: 16),
                      const Text("Seeding Products…",
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16, color: kNavy)),
                      const SizedBox(height: 4),
                      Text(
                        "Adding ${SeedProducts.allProducts.length} items to Firestore",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ── SLIVER APP BAR ─────────────────────────────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 190,
      floating: false,
      pinned: true,
      backgroundColor: kNavy,
      foregroundColor: Colors.white,
      // Title lives on the SliverAppBar itself so it only appears in the
      // collapsed/pinned state and never overlaps the expanded content.
      title: const Text(
        'Inventory',
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      titleSpacing: 0,
      actions: [
        if (inventory.isEmpty && !isLoading)
          IconButton(
            icon: const Icon(Icons.cloud_upload_rounded),
            onPressed: _seedAllProducts,
            tooltip: "Seed All Products",
          ),
        IconButton(
          icon: Icon(isGridView ? Icons.list_rounded : Icons.grid_view_rounded),
          onPressed: () => setState(() => isGridView = !isGridView),
          tooltip: isGridView ? "List view" : "Grid view",
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          enabled: !_isResetting,
          onSelected: (value) {
            if (value == 'seed') _seedAllProducts();
            if (value == 'seed_adambakkam') _seedAdambakkam();
            if (value == 'reset_reseed') _resetAndReseedInventory();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'seed',
              child: Row(children: [
                const Icon(Icons.cloud_upload_rounded, size: 18, color: kTeal),
                const SizedBox(width: 8),
                Text('Seed All Products', style: TextStyle(color: kNavy)),
              ]),
            ),
            PopupMenuItem(
              value: 'seed_adambakkam',
              child: Row(children: [
                const Icon(Icons.location_city_rounded, size: 18, color: kTeal),
                const SizedBox(width: 8),
                Text('Seed Adambakkam Products', style: TextStyle(color: kNavy)),
              ]),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'reset_reseed',
              child: Row(children: [
                const Icon(Icons.delete_sweep_rounded, size: 18, color: kCoral),
                const SizedBox(width: 8),
                Text('Reset & Re-seed Inventory', style: TextStyle(color: kNavy)),
              ]),
            ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        // No title here — avoids double-rendering over the stats/branding below.
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A1628), Color(0xFF162944)],
            ),
          ),
          child: ClipRect(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_rounded, color: kTeal, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "CDA Inventory",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Asset Management System",
                      style: TextStyle(
                        color: kTeal,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        collapseMode: CollapseMode.parallax,
      ),
    );
  }

  // ── STATS ROW ──────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
      child: Row(
        children: [
          _statCard("Items", "$_totalItems", Icons.category_rounded, kTeal),
          const SizedBox(width: 8),
          _statCard("Units", "$_totalQuantity", Icons.layers_rounded, kPurple),
          const SizedBox(width: 8),
          _statCard(
              "Low",
              "$_lowStockCount",
              Icons.warning_amber_rounded,
              _lowStockCount > 0 ? kAmber : Colors.grey.shade400),
          const SizedBox(width: 8),
          _statCard(
              "Empty",
              "$_outOfStockCount",
              Icons.remove_circle_outline_rounded,
              _outOfStockCount > 0 ? kCoral : Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2)),
          ],
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ── BRANCH TOGGLE ───────────────────────────────────────────────────────────
  Widget _buildBranchToggle() {
    final options = <_BranchOption>[
      _BranchOption(0, 'All Branches', Icons.apps_rounded),
      _BranchOption(1, 'CDA Admin', Icons.location_city_rounded),
      _BranchOption(2, 'CDA Ops', Icons.business_rounded),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: options.map((opt) {
          final isSelected = selectedBranch == opt.id;
          final count = opt.id == 0
              ? inventory.length
              : inventory.where((item) => item.branch == opt.id).length;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: opt.id == 2 ? 0 : 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedBranch = opt.id;
                    _applyFilters();
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? kNavy : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? kNavy : Colors.grey.shade300),
                    boxShadow: isSelected
                        ? [BoxShadow(color: kNavy.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))]
                        : [],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(opt.icon, size: 18, color: isSelected ? kTeal : Colors.grey.shade600),
                      const SizedBox(height: 3),
                      Text(opt.label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : kNavy,
                          )),
                      Text('$count',
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white70 : Colors.grey.shade500,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── SEARCH BAR ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              searchQuery = value;
              _applyFilters();
            });
          },
          decoration: InputDecoration(
            hintText: "Search by name, location, category…",
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: kNavy),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.grey),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  searchQuery = "";
                  _applyFilters();
                });
              },
            )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  // ── CATEGORY CHIPS ─────────────────────────────────────────────────────────
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat = categories[i];
          final isSelected = selectedCategory == cat;
          final color = categoryColors[cat] ?? kTeal;
          final branchScoped = selectedBranch == 0
              ? inventory
              : inventory.where((item) => item.branch == selectedBranch).toList();
          final count = cat == 'ALL'
              ? branchScoped.length
              : branchScoped.where((item) => item.category == cat).length;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedCategory = cat;
                _applyFilters();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? color : Colors.grey.shade300),
                boxShadow: isSelected
                    ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Row(
                children: [
                  Icon(categoryIcons[cat] ?? Icons.category,
                      size: 14, color: isSelected ? Colors.white : color),
                  const SizedBox(width: 5),
                  Text(cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey[700],
                      )),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withOpacity(0.25) : color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : color,
                          )),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── TOOLBAR ────────────────────────────────────────────────────────────────
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      child: Row(
        children: [
          Text(
            "${filteredInventory.length} item${filteredInventory.length != 1 ? 's' : ''}",
            style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              setState(() {
                if (value == 'lowStock') {
                  // Fixed-direction option: always low → high, no toggle.
                  sortBy = 'lowStock';
                  sortAscending = true;
                } else if (value == 'dateNewest') {
                  sortBy = 'date';
                  sortAscending = false; // latest createdAt first
                } else if (value == 'dateOldest') {
                  sortBy = 'date';
                  sortAscending = true; // earliest createdAt first
                } else if (sortBy == value) {
                  sortAscending = !sortAscending;
                } else {
                  sortBy = value;
                  sortAscending = true;
                }
                _applyFilters();
              });
            },
            itemBuilder: (_) => [
              _sortMenuItem("name", "Name"),
              _sortMenuItem("quantity", "Quantity"),
              _sortMenuItem("category", "Category"),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'dateNewest',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward_rounded,
                        size: 16,
                        color: (sortBy == 'date' && !sortAscending) ? kNavy : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Newest to Oldest'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'dateOldest',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward_rounded,
                        size: 16,
                        color: (sortBy == 'date' && sortAscending) ? kNavy : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Oldest to Newest'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'lowStock',
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: sortBy == 'lowStock' ? kAmber : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Low Stock First'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    sortBy == 'lowStock'
                        ? Icons.warning_amber_rounded
                        : (sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
                    size: 14,
                    color: kNavy,
                  ),
                  const SizedBox(width: 4),
                  Text("Sort: ${_sortLabel()}", style: const TextStyle(fontSize: 12, color: kNavy)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _sortLabel() {
    switch (sortBy) {
      case 'quantity':
        return 'Quantity';
      case 'category':
        return 'Category';
      case 'date':
        return sortAscending ? 'Oldest' : 'Newest';
      case 'lowStock':
        return 'Low Stock';
      default:
        return 'Name';
    }
  }

  PopupMenuItem<String> _sortMenuItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            sortBy == value
                ? (sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                : Icons.remove,
            size: 16,
            color: sortBy == value ? kNavy : Colors.transparent,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  // ── LIST / GRID ────────────────────────────────────────────────────────────
  Widget _buildInventoryList() {
    if (filteredInventory.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }

    if (isGridView) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.1,
          ),
          delegate: SliverChildBuilderDelegate(
                (_, i) => _buildGridCard(filteredInventory[i]),
            childCount: filteredInventory.length,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (_, i) => _buildListCard(filteredInventory[i]),
          childCount: filteredInventory.length,
        ),
      ),
    );
  }

  // ── LIST CARD ──────────────────────────────────────────────────────────────
  Widget _buildListCard(InventoryItem item) {
    final color = _categoryColor(item.category);
    final qty = item.quantity;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditProductScreen(product: item),
                settings: const RouteSettings(name: 'Edit Product'),
              ),
            );
            if (mounted) _loadInventoryOnce();
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                // Left icon + qty
                Container(
                  width: 56,
                  height: 72,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_categoryIcon(item.category), color: color, size: 22),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _qtyColor(qty),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text("$qty",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kNavy),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _miniTag(item.category, color),
                            if (selectedBranch == 0 && item.branch != 0) ...[
                              const SizedBox(width: 6),
                              _miniTag(item.branch == 1 ? 'B1' : 'B2', kPurple),
                            ],
                            const SizedBox(width: 6),
                            if (item.location.isNotEmpty)
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 11, color: Colors.grey[500]),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: Text(item.location,
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (item.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(item.description,
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                    ),
                  ),
                ),

                // Actions
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18, color: kAmber),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProductScreen(product: item),
                            settings: const RouteSettings(name: 'Edit Product'),
                          ),
                        );
                        if (mounted) _loadInventoryOnce();
                      },
                      tooltip: "Edit",
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_rounded, size: 18, color: kCoral),
                      onPressed: () => _confirmDelete(item),
                      tooltip: "Delete",
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── GRID CARD ──────────────────────────────────────────────────────────────
  Widget _buildGridCard(InventoryItem item) {
    final color = _categoryColor(item.category);
    final qty = item.quantity;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditProductScreen(product: item),
              settings: const RouteSettings(name: 'Edit Product'),
            ),
          );
          if (mounted) _loadInventoryOnce();
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_categoryIcon(item.category), color: color, size: 20),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _qtyColor(qty),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text("$qty",
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(item.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kNavy),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              _miniTag(item.category, color),
              if (selectedBranch == 0 && item.branch != 0) ...[
                const SizedBox(height: 4),
                _miniTag(item.branch == 1 ? 'B1' : 'B2', kPurple),
              ],
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProductScreen(product: item),
                            settings: const RouteSettings(name: 'Edit Product'),
                          ),
                        );
                        if (mounted) _loadInventoryOnce();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: kAmber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_rounded, size: 16, color: kAmber),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _confirmDelete(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: kCoral.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_rounded, size: 16, color: kCoral),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── EMPTY STATE ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            searchQuery.isNotEmpty
                ? 'No results for "$searchQuery"'
                : "No items in ${selectedCategory == 'ALL' ? 'inventory' : selectedCategory}",
            style: TextStyle(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          if (inventory.isEmpty && searchQuery.isEmpty) ...[
            Text(
              "Tap ⋮ → Seed All Products to load pre-defined items",
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _seedAllProducts,
              icon: const Icon(Icons.cloud_upload_rounded, size: 16),
              label: const Text("Seed All Products"),
              style: ElevatedButton.styleFrom(
                backgroundColor: kTeal,
                foregroundColor: kNavy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ] else
            Text("Tap + to add a new item", style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      backgroundColor: kTeal,
      foregroundColor: kNavy,
      icon: const Icon(Icons.add_rounded),
      label: const Text("Add Item", style: TextStyle(fontWeight: FontWeight.w700)),
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AddProductScreen(),
            settings: const RouteSettings(name: 'Add Product'),
          ),
        );
        if (mounted) _loadInventoryOnce();
      },
    );
  }

  // ── MINI TAG ───────────────────────────────────────────────────────────────
  Widget _miniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
          overflow: TextOverflow.ellipsis),
    );
  }
}

class _BranchOption {
  final int id;
  final String label;
  final IconData icon;
  const _BranchOption(this.id, this.label, this.icon);
}