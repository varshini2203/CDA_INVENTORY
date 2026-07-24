import 'package:flutter/material.dart';
import 'package:cda_inventory/models/inventory_item.dart';
import 'package:cda_inventory/services/branch_inventory_service.dart';
import 'package:cda_inventory/services/seed_guard_service.dart';
import 'package:cda_inventory/widgets/item_form_sheet.dart';

class BranchInventoryScreen extends StatefulWidget {
  final int branchId;
  final String branchLabel;

  const BranchInventoryScreen({
    super.key,
    required this.branchId,
    this.branchLabel = 'Branch',
  });

  @override
  State<BranchInventoryScreen> createState() => _BranchInventoryScreenState();
}

/// Drop-in replacement for the old hardcoded screen — use this if other
/// code in your app still references `Branch2InventoryScreen()` directly.
class Branch2InventoryScreen extends BranchInventoryScreen {
  const Branch2InventoryScreen({super.key}) : super(branchId: 2, branchLabel: 'Branch 2');
}

/// Branch 1 - Adambakkam.
class Branch1InventoryScreen extends BranchInventoryScreen {
  const Branch1InventoryScreen({super.key})
      : super(branchId: 1, branchLabel: 'Branch 1 - Adambakkam');
}

class _BranchInventoryScreenState extends State<BranchInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Guards against Clear & Re-seed being triggered again while a cycle is
  // already running. Each cycle deletes 500-1100+ documents then rewrites
  // the same number — without this guard, impatient repeated taps (or a
  // double-tap) during that multi-second window multiply reads, writes,
  // and deletes fast, which is what burned through the daily Firestore
  // quota during testing.
  bool _isSeeding = false;

  Future<BranchSummary>? _summaryFuture;
  Future<List<InventoryItem>>? _itemsFuture;
  Future<List<InventoryItem>>? _allItemsFuture; // unfiltered — used to build the Rows list

  // ── Single source of truth, read from Firestore ONCE per _loadAll() call.
  //    Summary, the Rows tab, and the filtered Items tab are all derived
  //    from this in memory — search/category/section changes never touch
  //    Firestore. (Previously each of those was a separate Firestore query,
  //    and every keystroke in the search box re-queried the whole branch.)
  List<InventoryItem> _rawItems = [];

  String _selectedCategory = 'all';
  String _searchQuery = '';
  String? _selectedSection; // active "row" filter, e.g. 'ROW-1', 'ONFIELD'
  final TextEditingController _searchController = TextEditingController();

  /// Extracts the row/section name (e.g. "ROW-1", "ONFIELD") that an item
  /// was imported from, based on the "From: <section>" prefix stored in
  /// `notes` by the spreadsheet import. Items without a recognizable
  /// section are grouped under "General".
  static String sectionOf(InventoryItem item) {
    final notes = item.notes ?? '';
    const prefix = 'From: ';
    if (!notes.startsWith(prefix)) return 'General';
    var section = notes.substring(prefix.length);
    final parenIdx = section.indexOf('(');
    if (parenIdx != -1) section = section.substring(0, parenIdx);
    return section.trim().isEmpty ? 'General' : section.trim();
  }

  // ── Design tokens (matches Invoices theme) ──────────────────────────────
  static const Color kNavy    = Color(0xFF0A1628);
  static const Color kTeal    = Color(0xFF00D4AA);
  static const Color kCoral   = Color(0xFFFF6B6B);
  static const Color kAmber   = Color(0xFFFFB800);
  static const Color kSurface = Color(0xFFF0F4F8);
  static const Color kGreen   = Color(0xFF00B894);
  static const Color kPurple  = Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  /// Single Firestore read for the whole screen. Summary + Rows tab + auto-seed
  /// check all reuse this same list instead of issuing their own queries
  /// (previously: fetchSummary + fetchInventory(unfiltered) + fetchInventory
  /// (filtered) + the auto-seed check's own fetchInventory — 4 near-full-
  /// collection reads on a single screen open).
  Future<void> _loadAll() async {
    try {
      final items = await BranchInventoryService.fetchInventory(widget.branchId);
      if (!mounted) return;

      if (items.isEmpty) {
        // Guard: only ever auto-seed each branch ONE time, ever — not
        // once per empty-check. Without this, emptying a branch (via
        // normal deletions or Clear & Re-seed) and reopening this screen
        // would silently rewrite ~1,125 (Branch 1) or ~492 (Branch 2)
        // documents on every single visit — this was the one auto-seed
        // path that had no guard at all.
        final seedKey = widget.branchId == 1 ? 'branch1' : 'branch2';
        final alreadySeeded = await SeedGuardService.hasSeeded(seedKey);
        if (alreadySeeded) {
          // Genuinely empty on purpose (e.g. fully sold out / cleared) —
          // leave it empty instead of silently reseeding.
          setState(() {
            _rawItems = [];
            _summaryFuture =
                Future.value(BranchSummary.fromItems('Branch ${widget.branchId}', []));
            _allItemsFuture = Future.value(<InventoryItem>[]);
          });
          _loadItemsOnly();
          return;
        }

        // Brand-new branch — seed once, then reload from the freshly
        // written data (this genuinely needs a second read, since the
        // data didn't exist a moment ago).
        if (widget.branchId == 1) {
          await BranchInventoryService.seedBranch1();
        } else if (widget.branchId == 2) {
          await BranchInventoryService.seedBranch2();
        }
        await SeedGuardService.markSeeded(seedKey);
        if (mounted) await _loadAll();
        return;
      }

      setState(() {
        _rawItems = items;
        _summaryFuture =
            Future.value(BranchSummary.fromItems('Branch ${widget.branchId}', items));
        _allItemsFuture = Future.value(items);
      });
      _loadItemsOnly();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _summaryFuture = Future.error(e);
        _allItemsFuture = Future.error(e);
        _itemsFuture = Future.error(e);
      });
    }
  }

  /// Filters the already-loaded [_rawItems] in memory — no Firestore call.
  /// Safe to call on every keystroke / category tap / section change.
  void _loadItemsOnly() {
    Iterable<InventoryItem> items = _rawItems;

    if (_selectedCategory != 'all') {
      items = items.where((i) => i.category == _selectedCategory);
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      items = items.where((i) =>
      i.itemName.toLowerCase().contains(q) ||
          i.category.toLowerCase().contains(q) ||
          (i.notes?.toLowerCase().contains(q) ?? false));
    }
    var list = items.toList()..sort((a, b) => a.itemName.compareTo(b.itemName));
    if (_selectedSection != null) {
      list = list.where((i) => sectionOf(i) == _selectedSection).toList();
    }

    setState(() {
      _itemsFuture = Future.value(list);
    });
  }

  void _selectSection(String? section) {
    setState(() => _selectedSection = section);
    _loadItemsOnly();
    if (section != null) _tabController.animateTo(2);
  }

  void _filterByCategory(String cat) {
    setState(() => _selectedCategory = cat);
    _loadItemsOnly();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _loadItemsOnly();
  }

  Future<void> _openAddItem() async {
    final result = await showModalBottomSheet<InventoryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemFormSheet(
        branchId: widget.branchId,
        initialCategory: _selectedCategory == 'all' ? null : _selectedCategory,
      ),
    );
    if (result != null) {
      _loadAll();
      if (mounted) {
        _showSnack('Item added');
      }
    }
  }

  Future<void> _openEditItem(InventoryItem item) async {
    final result = await showModalBottomSheet<InventoryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemFormSheet(branchId: widget.branchId, existingItem: item),
    );
    if (result != null) {
      _loadAll();
      if (mounted) {
        _showSnack('Item updated');
      }
    }
  }

  Future<void> _confirmDelete(InventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: kCoral),
            SizedBox(width: 8),
            Text('Delete item?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Remove "${item.itemName}" from inventory? This can\'t be undone.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await BranchInventoryService.deleteItem(widget.branchId, item.id!);
        _loadAll();
        if (mounted) {
          _showSnack('Item deleted');
        }
      } catch (e) {
        if (mounted) {
          _showSnack(
            'Delete failed: ${e.toString().replaceFirst('Exception: ', '')}',
            isError: true,
          );
        }
      }
    }
  }

  // ── Seed (Branch 1 - Adambakkam) ────────────────────────────────────────
  Future<void> _seedBranch1() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.cloud_upload_rounded, color: kTeal),
            SizedBox(width: 8),
            Text('Seed Branch 1 - Adambakkam?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'This will upload the Adambakkam inventory list (1125 items) to '
              'Firestore, tagged as Branch 1. Existing items will not be '
              'deleted, but running this more than once will create '
              'duplicates.\n\nContinue?',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kTeal,
              foregroundColor: kNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    if (_isSeeding) return; // already running — ignore duplicate taps
    setState(() => _isSeeding = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: kTeal),
      ),
    );

    try {
      await BranchInventoryService.seedBranch1();
      await SeedGuardService.markSeeded('branch1');
      if (!mounted) return;
      Navigator.pop(context); // close loader
      _loadAll();
      _showSnack('Branch 1 - Adambakkam seeded successfully');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loader
      _showSnack('Seed failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  // ── Seed (Branch 2 only) ────────────────────────────────────────────────
  Future<void> _seedBranch2() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.cloud_upload_rounded, color: kTeal),
            SizedBox(width: 8),
            Text('Seed Branch 2?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'This will upload the master inventory list (492 items) to Firestore, '
              'tagged as Branch 2. Existing items will not be deleted, but running '
              'this more than once will create duplicates.\n\nContinue?',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kTeal,
              foregroundColor: kNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    if (_isSeeding) return; // already running — ignore duplicate taps
    setState(() => _isSeeding = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: kTeal),
      ),
    );

    try {
      await BranchInventoryService.seedBranch2();
      await SeedGuardService.markSeeded('branch2');
      if (!mounted) return;
      Navigator.pop(context); // close loader
      _loadAll();
      _showSnack('Branch 2 seeded successfully');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loader
      _showSnack('Seed failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  // ── Clear & Re-seed (debug utility) ─────────────────────────────────────
  /// Wipes every item for this branch, then re-uploads the correct seed
  /// list from scratch. Use this if totals look wrong (e.g. inflated by
  /// duplicate/partial seeds from an earlier run).
  Future<void> _clearAndReseed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: kCoral),
            SizedBox(width: 8),
            Text('Clear & Re-seed?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'This will permanently delete ALL current items for '
              '${widget.branchLabel}, then upload a clean copy of the seed '
              'data. Use this if totals look inflated from duplicate seeding.'
              '\n\nThis cannot be undone. Continue?',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Clear & Re-seed'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    if (_isSeeding) return; // already running — ignore duplicate taps
    setState(() => _isSeeding = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: kCoral),
      ),
    );

    try {
      await BranchInventoryService.clearBranch(widget.branchId);
      if (widget.branchId == 1) {
        await BranchInventoryService.seedBranch1();
        await SeedGuardService.markSeeded('branch1');
      } else if (widget.branchId == 2) {
        await BranchInventoryService.seedBranch2();
        await SeedGuardService.markSeeded('branch2');
      }
      if (!mounted) return;
      Navigator.pop(context); // close loader
      _loadAll();
      _showSnack('${widget.branchLabel} cleared and re-seeded');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loader
      _showSnack('Clear & re-seed failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
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
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: Text(
          '${widget.branchLabel} Inventory',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A1628), Color(0xFF162944)],
            ),
          ),
        ),
        actions: [
          // Seed / Clear & Re-seed menu — only for branches with a matching
          // seed data source.
          if (widget.branchId == 1 || widget.branchId == 2)
            PopupMenuButton<String>(
              icon: const Icon(Icons.cloud_upload_rounded),
              tooltip: _isSeeding ? 'Seeding in progress…' : 'Seed options',
              enabled: !_isSeeding,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (_isSeeding) return;
                if (value == 'seed') {
                  widget.branchId == 1 ? _seedBranch1() : _seedBranch2();
                } else if (value == 'clear_reseed') {
                  _clearAndReseed();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'seed',
                  child: Row(children: [
                    const Icon(Icons.cloud_upload_rounded, size: 18, color: kTeal),
                    const SizedBox(width: 8),
                    Text('Seed ${widget.branchLabel}', style: const TextStyle(color: kNavy)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'clear_reseed',
                  child: Row(children: [
                    const Icon(Icons.delete_sweep_rounded, size: 18, color: kCoral),
                    const SizedBox(width: 8),
                    const Text('Clear & Re-seed', style: TextStyle(color: kCoral)),
                  ]),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAll,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kTeal,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded), text: 'Summary'),
            Tab(icon: Icon(Icons.grid_view_rounded), text: 'Rows'),
            Tab(icon: Icon(Icons.list_alt_rounded), text: 'Items'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSummaryTab(), _buildRowsTab(), _buildItemsTab()],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (_, __) => _tabController.index == 2
            ? FloatingActionButton.extended(
          onPressed: _openAddItem,
          backgroundColor: kTeal,
          foregroundColor: kNavy,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w700)),
        )
            : const SizedBox.shrink(),
      ),
    );
  }

  // ─── Summary Tab ──────────────────────────────────────────────────────────

  Widget _buildSummaryTab() {
    return FutureBuilder<BranchSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildError(snapshot.error.toString());
        }
        if (!snapshot.hasData) {
          // Covers ConnectionState.none too — _summaryFuture is still
          // null on the very first build, before _loadAll()'s setState
          // has run. Without this, snapshot.data! crashes with
          // "Unexpected null value." for one frame on every screen open.
          return const Center(child: CircularProgressIndicator(color: kTeal));
        }
        final s = snapshot.data!;
        return RefreshIndicator(
          color: kTeal,
          onRefresh: () async => _loadAll(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBranchHeader(s),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _buildStatCard('Total Items', s.totalItems.toString(),
                        Icons.inventory_2_rounded, kTeal),
                    _buildStatCard('FPV Drones', s.droneCount.toString(),
                        Icons.flight_rounded, kPurple),
                    _buildStatCard('In Service', s.inServiceCount.toString(),
                        Icons.build_circle_rounded, kCoral),
                    _buildStatCard('Status', s.status,
                        Icons.check_circle_rounded, kGreen),
                  ],
                ),
                const SizedBox(height: 20),
                _buildCategoryBreakdown(s),
                const SizedBox(height: 20),
                _buildQuickActions(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBranchHeader(BranchSummary s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1628), Color(0xFF162944)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.business_rounded, color: kTeal, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.branch,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: kGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(s.status,
                      style: const TextStyle(
                          color: kGreen, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(BranchSummary s) {
    final entries = s.categoryBreakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return const SizedBox.shrink();
    final maxValue = entries.first.value == 0 ? 1 : entries.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kNavy)),
          const SizedBox(height: 12),
          ...entries.map((e) {
            final cat = categoryByKey(e.key);
            final pct = e.value / maxValue;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(cat.icon, size: 16, color: cat.color),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 130,
                    child: Text(cat.label, style: const TextStyle(fontSize: 12, color: kNavy), overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.02, 1.0),
                        minHeight: 8,
                        backgroundColor: cat.color.withOpacity(0.1),
                        color: cat.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 28, child: Text('${e.value}', style: const TextStyle(fontSize: 12, color: kNavy), textAlign: TextAlign.right)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kNavy)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildActionButton('View All Items', Icons.list_alt_rounded, kNavy, () {
                setState(() => _selectedSection = null);
                _filterByCategory('all');
                _tabController.animateTo(2);
              }),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionButton('Add Item', Icons.add_circle_outline_rounded, kTeal, () {
                _tabController.animateTo(2);
                _openAddItem();
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    final isLight = color == kTeal;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isLight ? kNavy : Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: isLight ? kNavy : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ─── Rows Tab (browse by spreadsheet row / section) ────────────────────────

  Widget _buildRowsTab() {
    return FutureBuilder<List<InventoryItem>>(
      future: _allItemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kTeal));
        }
        if (snapshot.hasError) {
          return _buildError(snapshot.error.toString());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_rounded, size: 72, color: Colors.grey.shade200),
                const SizedBox(height: 16),
                Text('No rows yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              ],
            ),
          );
        }

        final Map<String, List<InventoryItem>> grouped = {};
        for (final item in items) {
          grouped.putIfAbsent(sectionOf(item), () => []).add(item);
        }
        final sectionNames = grouped.keys.toList()
          ..sort((a, b) => a.compareTo(b));

        return RefreshIndicator(
          color: kTeal,
          onRefresh: () async => _loadAll(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: sectionNames.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final name = sectionNames[i];
              final list = grouped[name]!;
              final totalQty = list.fold<int>(0, (sum, it) => sum + it.quantity);
              final isActive = _selectedSection == name;
              return Material(
                color: isActive ? kPurple.withOpacity(0.08) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _selectSection(name),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isActive ? kPurple : Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: isActive
                          ? []
                          : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: kPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.folder_rounded, color: kPurple, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 14, color: kNavy)),
                              const SizedBox(height: 2),
                              Text(
                                '${list.length} products  •  Qty $totalQty',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ─── Items Tab ─────────────────────────────────────────────────────────────

  Widget _buildItemsTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Container(
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kNavy.withOpacity(0.10)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 14, color: kNavy, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search items…',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: kNavy),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: kNavy),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
                    : null,
                filled: false,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              ),
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: kAllCategoriesWithAll.map((cat) {
                final isSelected = _selectedCategory == cat.key;
                // Hand-built pill instead of Material's FilterChip. The
                // FilterChip version (selectedColor/backgroundColor with
                // alphaBlend + surfaceTintColor: Colors.transparent) still
                // rendered as solid dark, unreadable badges in practice —
                // Material 3's chip theme resolution can still win out over
                // the widget-level colors depending on the Flutter SDK
                // version. Plain Container/GestureDetector with hardcoded
                // Colors.* values can't be reinterpreted by any theme, the
                // same technique already used in search_screen.dart's
                // category bar.
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _filterByCategory(cat.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cat.color
                            : Color.alphaBlend(cat.color.withOpacity(0.12), Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? cat.color : cat.color.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat.icon, size: 16, color: isSelected ? Colors.white : cat.color),
                          const SizedBox(width: 6),
                          Text(
                            cat.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : kNavy,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (_selectedSection != null)
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: const Icon(Icons.folder_rounded, size: 16, color: Colors.white),
                label: Text('Row: $_selectedSection'),
                backgroundColor: kPurple,
                labelStyle: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                onDeleted: () => _selectSection(null),
              ),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<InventoryItem>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildError(snapshot.error.toString());
              }
              if (!snapshot.hasData) {
                // _itemsFuture starts out null, same reasoning as the
                // Summary tab above — guard before the bang.
                return const Center(child: CircularProgressIndicator(color: kTeal));
              }
              final items = snapshot.data!;
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_rounded, size: 72, color: Colors.grey.shade200),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty ||
                            _selectedCategory != 'all' ||
                            _selectedSection != null
                            ? 'No items match your filters'
                            : 'No items yet — tap "Add Item" to get started',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                color: kTeal,
                onRefresh: () async => _loadAll(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => _buildItemCard(items[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(InventoryItem item) {
    final cat = categoryByKey(item.category);
    final statusColor = kStatusColors[item.status] ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: () => _openEditItem(item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: cat.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(cat.icon, color: cat.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kNavy)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _tag(cat.label, cat.color),
                        _tag(kStatusLabels[item.status] ?? item.status, statusColor),
                      ],
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(item.notes!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ),
                    if (item.dateIn != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'In: ${item.dateIn}${item.dateOut != null ? '  Out: ${item.dateOut}' : ''}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Qty: ${item.quantity}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: cat.color, fontSize: 14)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        color: kAmber,
                        onPressed: () => _openEditItem(item),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded, size: 18),
                        color: kCoral,
                        onPressed: () => _confirmDelete(item),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }

  // ─── Error state ────────────────────────────────────────────────────────────

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: kCoral.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.cloud_off_rounded, size: 40, color: kCoral),
            ),
            const SizedBox(height: 20),
            const Text('Failed to load data',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kNavy)),
            const SizedBox(height: 8),
            Text(msg.replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}