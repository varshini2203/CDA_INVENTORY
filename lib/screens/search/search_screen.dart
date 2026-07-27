// lib/screens/search/search_screen.dart
//
// Search Products screen — browses the shared `products` Firestore
// collection with three ways to slice it, matching how items are actually
// found on the shelf rather than just by name:
//
//   • By Category — the column headers from each source sheet (Tools,
//     Charging Station, Row 2, Service Rack, Admin Room, etc.)
//   • By Row      — Row 1 .. Row 5 (Branch 1 shelving)
//   • By Tray     — every distinct Tray/Draw/Table-Draw marker seen in the
//     data (Tray 1..16, Draw 1, Draw 2, Table 2 - Draw 1, ...)
//
// Chip lists for all three modes are computed FROM the loaded data (not
// hardcoded), so newly added branches/rooms/rows show up automatically
// without another code change here.
//
// Auto-seed is guarded exactly like every other module in this app
// (SeedGuardService, keyed 'products'): fires at most once per install,
// only when the collection is empty, and never retries silently. Manual
// re-seed lives behind an explicit confirmation dialog in the app bar menu.

import 'package:flutter/material.dart';

import 'package:cda_inventory/models/product.dart';
import 'package:cda_inventory/services/product_service.dart';
import 'package:cda_inventory/services/seed_guard_service.dart';
import 'package:cda_inventory/data/seed_search_products.dart';
import 'package:cda_inventory/data/seed_branch1_products.dart';

enum _FilterMode { all, category, row, tray }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // ── Design tokens (matches Search Products' established look: off-white
  //    page, white cards, dark navy app bar, solid-black selected chip —
  //    see activity_feed_screen.dart's notes on matching this screen). ──
  static const Color kNavy = Color(0xFF0A1628);
  static const Color kSurface = Color(0xFFF5F7FA);
  static const Color kChipSelected = Color(0xFF111318);
  static const Color kChipFill = Color(0xFFF0F1F3);
  static const Color kBorder = Color(0xFFE3E6EA);
  static const Color kTextSecondary = Color(0xFF6B7280);
  static const Color kGreen = Color(0xFF00B894);
  static const Color kAmber = Color(0xFFFFB800);
  static const Color kRed = Color(0xFFE5484D);
  static const Color kBlue = Color(0xFF1565C0);

  // ── Data state ────────────────────────────────────────────────────────
  List<Product> _all = [];
  List<Product> _filtered = [];
  bool _isLoading = true;
  bool _isSeeding = false;
  String? _error;

  // ── Filter state ──────────────────────────────────────────────────────
  _FilterMode _mode = _FilterMode.all;
  String? _selectedValue; // selected category / row / tray, null = none
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  // In-memory guard so a re-seed check never fires more than once per
  // app session even if this screen is opened repeatedly (mirrors the
  // pattern in InventoryDashboard's _branchMigrationDoneCache).
  static bool _seedCheckedThisSession = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Firestore fetch ───────────────────────────────────────────────────
  // forceRefresh: false on initState (reuse ProductService's shared
  // cache if another screen already warmed it up this session). Pull-to-
  // refresh and the manual Refresh button always pass true.
  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final products = await ProductService.getProducts(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _all = products;
        _isLoading = false;
      });
      _applyFilters();
      await _autoSeedIfNeeded(products);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Guarded auto-seed ─────────────────────────────────────────────────
  // Only runs once per install (SeedGuardService key 'products'), and
  // only when the collection is genuinely empty. Seeds the general
  // catalogue (On Field / RPTO / etc.) plus the rebuilt Branch 1
  // (Adambakkam) inventory — the one with correct Row/Rack/Tray grouping
  // — so Search Products has real Row/Tray chips out of the box.
  Future<void> _autoSeedIfNeeded(List<Product> existing) async {
    if (existing.isNotEmpty) return;
    if (_seedCheckedThisSession) return;
    try {
      final alreadySeeded = await SeedGuardService.hasSeeded('products');
      if (alreadySeeded) {
        _seedCheckedThisSession = true;
        return;
      }
      await _runSeed();
      await SeedGuardService.markSeeded('products');
      _seedCheckedThisSession = true;
    } catch (_) {
      // Best-effort — a failed auto-seed just means the screen shows
      // empty state; the manual "Seed Data" action can retry.
    }
  }

  Future<void> _runSeed() async {
    setState(() => _isSeeding = true);
    try {
      await ProductService.seedProducts(SeedSearchProducts.allItems);
      await ProductService.seedProducts(SeedBranch1Products.allItems);
      if (mounted) await _load(forceRefresh: true);
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  Future<void> _confirmManualSeed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Re-seed Search Products?'),
        content: const Text(
          'This adds the full catalogue (On Field, RPTO, etc.) and the '
              'Branch 1 (Adambakkam) inventory — including Row/Rack/Tray '
              'locations — to the products collection. Existing items are '
              'left untouched; this only ever adds new documents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kNavy),
            child: const Text('Seed'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _runSeed();
  }

  // ── Derived chip lists (computed from loaded data, not hardcoded) ────
  List<String> get _categories {
    final set = <String>{for (final p in _all) if (p.category.trim().isNotEmpty) p.category.trim()};
    final list = set.toList()..sort();
    return list;
  }

  List<String> get _rows {
    final set = <String>{for (final p in _all) if ((p.row ?? '').trim().isNotEmpty) p.row!.trim()};
    final list = set.toList()..sort(_naturalCompare);
    return list;
  }

  List<String> get _trays {
    final set = <String>{for (final p in _all) if ((p.tray ?? '').trim().isNotEmpty) p.tray!.trim()};
    final list = set.toList()..sort(_naturalCompare);
    return list;
  }

  /// Sorts "Row 2" before "Row 10", "Tray 2" before "Tray 16", etc. by
  /// comparing any trailing number numerically instead of as text.
  int _naturalCompare(String a, String b) {
    final numA = RegExp(r'(\d+)$').firstMatch(a);
    final numB = RegExp(r'(\d+)$').firstMatch(b);
    if (numA != null && numB != null) {
      final prefixA = a.substring(0, numA.start);
      final prefixB = b.substring(0, numB.start);
      if (prefixA == prefixB) {
        return int.parse(numA.group(1)!).compareTo(int.parse(numB.group(1)!));
      }
    }
    return a.compareTo(b);
  }

  // ── Apply filters locally (mode + selected value + free-text query) ──
  void _applyFilters() {
    setState(() {
      _filtered = _all.where((p) {
        final matchesMode = switch (_mode) {
          _FilterMode.all => true,
          _FilterMode.category => _selectedValue == null || p.category.trim() == _selectedValue,
          _FilterMode.row => _selectedValue == null || (p.row ?? '').trim() == _selectedValue,
          _FilterMode.tray => _selectedValue == null || (p.tray ?? '').trim() == _selectedValue,
        };
        if (!matchesMode) return false;
        if (_query.trim().isEmpty) return true;
        final q = _query.trim().toLowerCase();
        return p.name.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            (p.row ?? '').toLowerCase().contains(q) ||
            (p.rack ?? '').toLowerCase().contains(q) ||
            (p.tray ?? '').toLowerCase().contains(q) ||
            (p.notes ?? '').toLowerCase().contains(q);
      }).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    });
  }

  void _selectMode(_FilterMode mode) {
    setState(() {
      _mode = mode;
      _selectedValue = null;
    });
    _applyFilters();
  }

  void _selectValue(String? value) {
    setState(() => _selectedValue = value);
    _applyFilters();
  }

  void _onSearchChanged(String value) {
    _query = value;
    _applyFilters();
  }

  // ── Location text — the raw row/rack/tray values already read like
  //    "Row 2", "Fourth Row", "Tray 4", "Draw 1" on their own, so this
  //    just joins whichever are present rather than adding another
  //    "Row "/"Tray " prefix on top (that would print "Row Row 2"). ────
  String _locationText(Product p) {
    final parts = <String>[
      if ((p.row ?? '').trim().isNotEmpty) p.row!.trim(),
      if ((p.rack ?? '').trim().isNotEmpty) p.rack!.trim(),
      if ((p.tray ?? '').trim().isNotEmpty) p.tray!.trim(),
    ];
    return parts.join(' · ');
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // Forced light theme for this whole screen. The app's ambient theme
    // defaults to dark (see ThemeProvider), and every card/surface here is
    // hardcoded white — any Text/Icon that didn't set an explicit color
    // (product names, stat values, quantity numbers, search hint) was
    // inheriting the dark theme's default WHITE text color and rendering
    // invisible on these white cards. Same root cause already documented
    // in item_form_sheet.dart, just needed applying here too since this
    // bug affects the whole screen body, not only the bottom sheets.
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: kSurface,
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: const Color(0xFF111318),
          displayColor: const Color(0xFF111318),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF111318)),
      ),
      child: Scaffold(
        backgroundColor: kSurface,
        appBar: _buildAppBar(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildError()
            : RefreshIndicator(
          onRefresh: () => _load(forceRefresh: true),
          child: _buildBody(),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: kNavy,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Product'),
          onPressed: _openAddSheet,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Search Products'),
      backgroundColor: kNavy,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          onPressed: _isSeeding ? null : () => _load(forceRefresh: true),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (v) {
            if (v == 'seed') _confirmManualSeed();
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(
              value: 'seed',
              child: Row(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Seed Data'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text('Failed to load products',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _load(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: kNavy, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isSeeding) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Seeding product catalogue…', style: TextStyle(color: kTextSecondary)),
          ],
        ),
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildStatsStrip()),
        SliverToBoxAdapter(child: _buildSearchBar()),
        SliverToBoxAdapter(child: _buildModeSelector()),
        SliverToBoxAdapter(child: _buildValueChips()),
        SliverToBoxAdapter(child: _buildResultCountBadge()),
        _all.isEmpty
            ? SliverFillRemaining(hasScrollBody: false, child: _buildEmptyCollection())
            : _filtered.isEmpty
            ? SliverFillRemaining(hasScrollBody: false, child: _buildNoResults())
            : _buildProductList(),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  // ── Stats strip ───────────────────────────────────────────────────────
  Widget _buildStatsStrip() {
    final total = _all.length;
    final lowStock = _all.where((p) => p.isLowStock).length;
    final outOfStock = _all.where((p) => p.isOutOfStock).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(child: _statCard('Total', '$total', Icons.inventory_2_outlined, kBlue)),
          const SizedBox(width: 10),
          Expanded(child: _statCard('Low Stock', '$lowStock', Icons.warning_amber_rounded, kAmber)),
          const SizedBox(width: 10),
          Expanded(child: _statCard('Out of Stock', '$outOfStock', Icons.remove_circle_outline, kRed)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
        ],
      ),
    );
  }

  // ── Search bar ───────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search by name, category, row, rack, or tray…',
          hintStyle: const TextStyle(fontSize: 13.5),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
            },
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kNavy, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Mode selector: All / Category / Row / Tray ─────────────────────────
  Widget _buildModeSelector() {
    Widget modeChip(String label, IconData icon, _FilterMode mode) {
      final selected = _mode == mode;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: Icon(icon, size: 15, color: selected ? Colors.white : kTextSecondary),
          label: Text(label),
          labelStyle: TextStyle(
            color: selected ? Colors.white : kTextSecondary,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          selected: selected,
          onSelected: (_) => _selectMode(mode),
          selectedColor: kChipSelected,
          backgroundColor: kChipFill,
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: selected ? kChipSelected : kBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            modeChip('All', Icons.apps_rounded, _FilterMode.all),
            modeChip('By Category', Icons.category_outlined, _FilterMode.category),
            modeChip('By Row', Icons.view_week_outlined, _FilterMode.row),
            modeChip('By Tray', Icons.inbox_outlined, _FilterMode.tray),
          ],
        ),
      ),
    );
  }

  // ── Value chips for the active mode (Category / Row / Tray lists) ────
  Widget _buildValueChips() {
    if (_mode == _FilterMode.all) return const SizedBox.shrink();

    final values = switch (_mode) {
      _FilterMode.category => _categories,
      _FilterMode.row => _rows,
      _FilterMode.tray => _trays,
      _FilterMode.all => <String>[],
    };

    if (values.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Text(
          _mode == _FilterMode.row
              ? 'No items have a Row assigned yet.'
              : _mode == _FilterMode.tray
              ? 'No items have a Tray assigned yet.'
              : 'No categories yet.',
          style: const TextStyle(color: kTextSecondary, fontSize: 12.5),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _valueChip('All', null, _countFor(null)),
          ...values.map((v) => _valueChip(v, v, _countFor(v))),
        ],
      ),
    );
  }

  int _countFor(String? value) {
    if (value == null) return _all.length;
    return switch (_mode) {
      _FilterMode.category => _all.where((p) => p.category.trim() == value).length,
      _FilterMode.row => _all.where((p) => (p.row ?? '').trim() == value).length,
      _FilterMode.tray => _all.where((p) => (p.tray ?? '').trim() == value).length,
      _FilterMode.all => _all.length,
    };
  }

  Widget _valueChip(String label, String? value, int count) {
    final selected = _selectedValue == value;
    return ChoiceChip(
      label: Text('$label · $count'),
      labelStyle: TextStyle(
        color: selected ? Colors.white : kTextSecondary,
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      selected: selected,
      onSelected: (_) => _selectValue(value),
      selectedColor: kChipSelected,
      backgroundColor: kChipFill,
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selected ? kChipSelected : kBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  // ── Result count badge ───────────────────────────────────────────────
  Widget _buildResultCountBadge() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: kBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBlue.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined, size: 14, color: kBlue),
                const SizedBox(width: 6),
                Text(
                  '${_filtered.length} of ${_all.length} products',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: kBlue, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Product list ─────────────────────────────────────────────────────
  Widget _buildProductList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _ProductCard(
            product: _filtered[index],
            locationText: _locationText(_filtered[index]),
            onTap: () => _openDetailSheet(_filtered[index]),
          ),
        ),
        childCount: _filtered.length,
      ),
    );
  }

  Widget _buildEmptyCollection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No products yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
              'Seed the catalogue to get started, or add your first product.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _confirmManualSeed,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Seed Data'),
              style: ElevatedButton.styleFrom(backgroundColor: kNavy, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No matching products', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              'Try a different search term or clear the filter.',
              style: TextStyle(color: kTextSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                _query = '';
                _selectMode(_FilterMode.all);
              },
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Add / Edit / Delete ──────────────────────────────────────────────
  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductFormSheet(
        categories: _categories,
        onSaved: () => _load(forceRefresh: true),
      ),
    );
  }

  void _openEditSheet(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductFormSheet(
        categories: _categories,
        existing: product,
        onSaved: () => _load(forceRefresh: true),
      ),
    );
  }

  void _openDetailSheet(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductDetailSheet(
        product: product,
        locationText: _locationText(product),
        onEdit: () {
          Navigator.pop(ctx);
          _openEditSheet(product);
        },
        onDelete: () async {
          Navigator.pop(ctx);
          await _confirmDelete(product);
        },
      ),
    );
  }

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('"${product.name}" will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ProductService.deleteProduct(product.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${product.name}" deleted')),
        );
      }
      await _load(forceRefresh: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  PRODUCT CARD
// ═══════════════════════════════════════════════════════════════════════
class _ProductCard extends StatelessWidget {
  final Product product;
  final String locationText;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.locationText,
    required this.onTap,
  });

  Color get _stockColor {
    if (product.isOutOfStock) return const Color(0xFFE5484D);
    if (product.isLowStock) return const Color(0xFFFFB800);
    return const Color(0xFF00B894);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3E6EA)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(color: _stockColor, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _pill(product.category, const Color(0xFF1565C0)),
                        if (locationText.isNotEmpty)
                          _pill(locationText, const Color(0xFF6C63FF), icon: Icons.place_outlined),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${product.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  Text(
                    product.stockLabel,
                    style: TextStyle(fontSize: 10.5, color: _stockColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  DETAIL SHEET
// ═══════════════════════════════════════════════════════════════════════
class _ProductDetailSheet extends StatelessWidget {
  final Product product;
  final String locationText;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductDetailSheet({
    required this.product,
    required this.locationText,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light(),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              Text(product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A1628))),
              const SizedBox(height: 12),
              _row('Category', product.category),
              _row('Quantity', '${product.quantity}  (${product.stockLabel})'),
              if (product.price > 0) _row('Price', '₹${product.price.toStringAsFixed(2)}'),
              if (locationText.isNotEmpty) _row('Location', locationText),
              if ((product.notes ?? '').trim().isNotEmpty) _row('Notes', product.notes!.trim()),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE5484D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12.5)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0A1628)))),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  ADD / EDIT FORM SHEET
// ═══════════════════════════════════════════════════════════════════════
class _ProductFormSheet extends StatefulWidget {
  final List<String> categories;
  final Product? existing; // null = add mode
  final VoidCallback onSaved;

  const _ProductFormSheet({
    required this.categories,
    this.existing,
    required this.onSaved,
  });

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _qtyController;
  late TextEditingController _priceController;
  late TextEditingController _rowController;
  late TextEditingController _rackController;
  late TextEditingController _trayController;
  late TextEditingController _notesController;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameController = TextEditingController(text: p?.name ?? '');
    _categoryController = TextEditingController(text: p?.category ?? '');
    _qtyController = TextEditingController(text: (p?.quantity ?? 1).toString());
    _priceController = TextEditingController(text: (p?.price ?? 0.0) == 0.0 ? '' : p!.price.toString());
    _rowController = TextEditingController(text: p?.row ?? '');
    _rackController = TextEditingController(text: p?.rack ?? '');
    _trayController = TextEditingController(text: p?.tray ?? '');
    _notesController = TextEditingController(text: p?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _rowController.dispose();
    _rackController.dispose();
    _trayController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'category': _categoryController.text.trim(),
      'quantity': int.tryParse(_qtyController.text.trim()) ?? 0,
      'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      'row': _rowController.text.trim().isEmpty ? null : _rowController.text.trim(),
      'rack': _rackController.text.trim().isEmpty ? null : _rackController.text.trim(),
      'tray': _trayController.text.trim().isEmpty ? null : _trayController.text.trim(),
    };

    try {
      if (_isEdit) {
        await ProductService.updateProduct(widget.existing!.id, data);
      } else {
        await ProductService.addProduct(data);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    // Forced light theme for this subtree — the ambient app theme may be
    // dark (see ThemeProvider), and this sheet's background is hardcoded
    // white, so labels/borders need to stay dark regardless of app theme
    // (same fix already applied in item_form_sheet.dart).
    return Theme(
      data: ThemeData.light().copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.black87),
          hintStyle: TextStyle(color: Colors.black45),
          floatingLabelStyle: TextStyle(color: Colors.black87),
          border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF0A1628), width: 2)),
        ),
      ),
      child: AnimatedPadding(
        padding: viewInsets,
        duration: const Duration(milliseconds: 150),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration:
                        BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    Text(
                      _isEdit ? 'Edit Product' : 'Add Product',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A1628)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Product name', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    Autocomplete<String>(
                      initialValue: TextEditingValue(text: _categoryController.text),
                      optionsBuilder: (v) {
                        if (v.text.isEmpty) return widget.categories;
                        return widget.categories
                            .where((c) => c.toLowerCase().contains(v.text.toLowerCase()));
                      },
                      onSelected: (v) => _categoryController.text = v,
                      fieldViewBuilder: (ctx, controller, focusNode, onSubmit) {
                        // Keep our own controller in sync with Autocomplete's
                        // internal one so free-typed (new) categories save too.
                        controller.text = _categoryController.text;
                        controller.addListener(() => _categoryController.text = controller.text);
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            hintText: 'Pick existing or type a new one',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Category is required' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                            validator: (v) {
                              final n = int.tryParse(v?.trim() ?? '');
                              if (n == null || n < 0) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Price (optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Physical location (optional)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.black54)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _rowController,
                            decoration:
                            const InputDecoration(labelText: 'Row', hintText: 'e.g. Row 2', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _rackController,
                            decoration: const InputDecoration(
                                labelText: 'Rack', hintText: 'e.g. Shelf 1', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _trayController,
                      decoration: const InputDecoration(
                          labelText: 'Tray', hintText: 'e.g. Tray 4, Draw 1', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A1628),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : Text(_isEdit ? 'Save Changes' : 'Add Product'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}