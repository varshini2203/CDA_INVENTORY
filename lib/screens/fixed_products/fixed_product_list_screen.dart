// lib/screens/fixed_assets/fixed_product_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cda_inventory/models/fixed_asset.dart';
import 'package:cda_inventory/services/fixed_asset_service.dart';
import 'package:cda_inventory/data/seed_fixed_assets.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  FIXED ASSET LIST SCREEN  (Firestore real-time)
// ═══════════════════════════════════════════════════════════════════════════

/// Sort options available for the list.
enum AssetSortOption {
  none,
  dateNewest,
  dateOldest,
  lowStock,
}

extension AssetSortOptionLabel on AssetSortOption {
  String get label {
    switch (this) {
      case AssetSortOption.dateNewest:
        return 'Date: Newest First';
      case AssetSortOption.dateOldest:
        return 'Date: Oldest First';
      case AssetSortOption.lowStock:
        return 'Low Stock (Qty ≤ 2)';
      case AssetSortOption.none:
        return 'Default';
    }
  }

  IconData get icon {
    switch (this) {
      case AssetSortOption.dateNewest:
        return Icons.arrow_downward_rounded;
      case AssetSortOption.dateOldest:
        return Icons.arrow_upward_rounded;
      case AssetSortOption.lowStock:
        return Icons.warning_amber_rounded;
      case AssetSortOption.none:
        return Icons.sort_rounded;
    }
  }
}

class FixedProductListScreen extends StatefulWidget {
  const FixedProductListScreen({super.key});

  @override
  State<FixedProductListScreen> createState() =>
      _FixedProductListScreenState();
}

class _FixedProductListScreenState extends State<FixedProductListScreen>
    with SingleTickerProviderStateMixin {
  String _search = '';
  String _branchFilter = 'All';
  String _categoryFilter = 'All';
  AssetSortOption _sortOption = AssetSortOption.none;
  bool _isSeeding = false;
  late AnimationController _fabAnim;

  // Fetched once and cached — was previously a StreamBuilder wired
  // directly to FixedAssetService.streamAssets() inside build(), which
  // re-opened a new Firestore listener (re-reading every asset) on every
  // rebuild, including every search keystroke and filter/sort tap.
  // Fixed Assets is slow-changing, so a one-shot fetch + manual refresh
  // after mutations is the right fit (see FixedAssetService.getAssets()).
  List<FixedAsset>? _assets;
  String? _loadError;

  Future<void> _loadAssets() async {
    try {
      final list = await FixedAssetService.getAssets();
      if (mounted) setState(() => _assets = list);
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    }
  }

  static const List<String> _branches = ['All', 'CDA Admin', 'CDA Ops'];

  // Palette aligned with the Inventory Dashboard (kNavy / kTeal / kSurface)
  // so both screens share one consistent visual identity instead of two
  // different accent colors (this screen was previously navy + blue;
  // Inventory is navy + teal).
  static const Color _navy    = Color(0xFF0A1628);
  static const Color _accent  = Color(0xFF00D4AA);
  static const Color _surface = Color(0xFFF0F4F8);

  // Low stock threshold — items with quantity <= this are "low stock".
  static const int _lowStockThreshold = 2;

  // ── Category icon/color, matching the Inventory Dashboard's style ────────
  // Inventory has one clean fixed category list; Fixed Assets' category
  // field is free-text and often combines several categories in one string
  // (e.g. "Admin Room, Instructor Room, Training Room"), so an exact-match
  // lookup like Inventory's won't cover most rows. Instead we match on
  // keywords found ANYWHERE in the category string (case-insensitive),
  // reusing Inventory's exact colors/icons wherever the same category
  // exists in both, and falling back to a stable hash-based color for
  // anything Inventory doesn't have (Admin Room, Md Room, Row-2, etc.) so
  // chips still look intentional and varied rather than defaulting to grey.
  static const List<MapEntry<String, IconData>> _categoryKeywordIcons = [
    MapEntry('onfield', Icons.flight_takeoff),
    MapEntry('rpto', Icons.verified_user),
    MapEntry('stationary', Icons.edit_note),
    MapEntry('electr', Icons.electrical_services),
    MapEntry('tool', Icons.construction),
    MapEntry('lab room', Icons.science),
    MapEntry('charging station', Icons.battery_charging_full),
    MapEntry('navin kit', Icons.backpack),
    MapEntry('fpv drone', Icons.videocam),
    MapEntry('remote controller', Icons.sports_esports),
    MapEntry('drone spare', Icons.build_circle),
    MapEntry('3d printer', Icons.print),
    MapEntry('housekeeping', Icons.cleaning_services),
    MapEntry('manager room', Icons.meeting_room),
    MapEntry('instructor room', Icons.school),
    MapEntry('corridor', Icons.door_sliding),
    MapEntry('rest room', Icons.wc),
    MapEntry('restroom', Icons.wc),
    MapEntry('admin room', Icons.badge_rounded),
    MapEntry('training room', Icons.groups_rounded),
    MapEntry('md room', Icons.business_center_rounded),
    MapEntry('row', Icons.view_column_rounded),
    MapEntry('propeller', Icons.settings_input_component_rounded),
    MapEntry('rack', Icons.inventory_rounded),
    MapEntry('transmitter', Icons.settings_remote_rounded),
    MapEntry('editor', Icons.desktop_windows_rounded),
    MapEntry('service', Icons.local_shipping_rounded),
  ];

  static const List<Color> _categoryFallbackPalette = [
    Color(0xFF00D4AA), // teal
    Color(0xFF6C63FF), // purple
    Color(0xFFFFB800), // amber
    Color(0xFFFF6B6B), // coral
    Color(0xFF00B894), // green
    Color(0xFF2E86DE), // blue
    Color(0xFFE84393), // pink
    Color(0xFFD35400), // burnt orange
  ];

  static const Map<String, Color> _categoryKeywordColors = {
    'onfield': Color(0xFF2E7D32),
    'rpto': Color(0xFF6C63FF),
    'stationary': Color(0xFFD84315),
    'electr': Color(0xFFF9A825),
    'tool': Color(0xFF455A64),
    'lab room': Color(0xFF00897B),
    'charging station': Color(0xFF00B894),
    'navin kit': Color(0xFF8E24AA),
    'fpv drone': Color(0xFFE53935),
  };

  IconData _categoryIcon(String category) {
    final lower = category.toLowerCase();
    for (final entry in _categoryKeywordIcons) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return Icons.category_rounded;
  }

  Color _categoryColor(String category) {
    final lower = category.toLowerCase();
    for (final entry in _categoryKeywordColors.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    // Stable fallback: same category string always gets the same color.
    final index = category.hashCode.abs() % _categoryFallbackPalette.length;
    return _categoryFallbackPalette[index];
  }

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnim.forward();
    _loadAssets();
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    super.dispose();
  }

  // ── Filtering ─────────────────────────────────────────────────────────────
  List<FixedAsset> _filterList(List<FixedAsset> all) {
    return all.where((a) {
      final matchBranch =
          _branchFilter == 'All' || a.branch == _branchFilter;
      final matchCategory = _categoryFilter == 'All' ||
          a.category == _categoryFilter;
      final matchSearch = _search.isEmpty ||
          a.name.toLowerCase().contains(_search.toLowerCase()) ||
          a.location.toLowerCase().contains(_search.toLowerCase());
      return matchBranch && matchCategory && matchSearch;
    }).toList();
  }

  /// Builds the list of categories to show in the filter, based on whatever
  /// category values actually exist in Firestore right now (plus 'All').
  List<String> _availableCategories(List<FixedAsset> all) {
    final set = <String>{};
    for (final a in all) {
      if (a.category.trim().isNotEmpty) set.add(a.category.trim());
    }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  // ── Sorting ───────────────────────────────────────────────────────────────
  List<FixedAsset> _sortList(List<FixedAsset> list) {
    final sorted = List<FixedAsset>.from(list);

    switch (_sortOption) {
      case AssetSortOption.dateNewest:
        sorted.sort((a, b) {
          final da = a.createdAt;
          final db = b.createdAt;
          if (da == null && db == null) return 0;
          if (da == null) return 1; // nulls last
          if (db == null) return -1;
          return db.compareTo(da); // newest first
        });
        break;
      case AssetSortOption.dateOldest:
        sorted.sort((a, b) {
          final da = a.createdAt;
          final db = b.createdAt;
          if (da == null && db == null) return 0;
          if (da == null) return 1; // nulls last
          if (db == null) return -1;
          return da.compareTo(db); // oldest first
        });
        break;
      case AssetSortOption.lowStock:
      // Low stock items first, then by quantity ascending.
        sorted.sort((a, b) => a.quantity.compareTo(b.quantity));
        break;
      case AssetSortOption.none:
        break;
    }

    return sorted;
  }

  // ── SEED ALL FIXED ASSETS ─────────────────────────────────────────────────
  Future<void> _seedAllAssets() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cloud_upload_rounded, color: Color(0xFF00D4AA)),
            SizedBox(width: 8),
            Text('Seed Fixed Assets'),
          ],
        ),
        content: Text(
          'This will add all ${SeedFixedAssets.allItems.length} fixed assets '
              'from the master spreadsheet into Firestore.\n\n'
              'This is a one-time setup action. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A1628),
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.upload_rounded,
                color: Colors.white, size: 16),
            label: const Text('Seed Now',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSeeding = true);

    try {
      final result =
      await FixedAssetService.seedAssets(SeedFixedAssets.allItems);
      if (!mounted) return;
      _snack(
        'Seeded: ${result['success']} added, ${result['failed']} skipped',
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Seeding failed: $e', isError: true);
    }

    if (mounted) setState(() => _isSeeding = false);
    _loadAssets();
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  Future<void> _delete(FixedAsset asset) async {
    final confirmed = await _confirm(
      title: 'Remove Asset',
      message:
      'Remove "${asset.name}" from the registry? This cannot be undone.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed) return;

    try {
      await FixedAssetService.deleteAsset(asset.id);
      _snack('${asset.name} removed', isError: false);
      _loadAssets();
    } catch (e) {
      _snack('Delete failed: $e', isError: true);
    }
  }

  // ── UI helpers ────────────────────────────────────────────────────────────
  void _snack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
      isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
              isDestructive ? Colors.red.shade700 : _accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openSortSheet() async {
    final selected = await showModalBottomSheet<AssetSortOption>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Sort By',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 10),
              ...AssetSortOption.values.map((opt) {
                final isSelected = _sortOption == opt;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    opt.icon,
                    color: isSelected ? _accent : Colors.grey.shade500,
                  ),
                  title: Text(
                    opt.label,
                    style: TextStyle(
                      fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? _accent : Colors.black87,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: _accent)
                      : null,
                  onTap: () => Navigator.pop(ctx, opt),
                );
              }),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != _sortOption) {
      setState(() => _sortOption = selected);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Builder(
            builder: (context) {
              if (_loadError != null) {
                return _buildError(_loadError!);
              }
              if (_assets == null) {
                return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2));
              }

              final filtered = _filterList(_assets!);
              final sorted = _sortList(filtered);
              final totalQty = sorted.fold<int>(
                  0, (sum, a) => sum + a.quantity);

              // A single CustomScrollView for the ENTIRE body (header
              // stat strip + search, filter row, and the asset list) —
              // everything scrolls together as one unit, same as the
              // dashboard screen. Previously the header + filters lived
              // in a fixed Column with only the asset list wrapped in
              // its own scrollable ListView beneath them, so the top
              // section never moved and the list only scrolled within
              // the leftover space below it — which read as "the top
              // isn't scrolling" whenever header + filters + list
              // together were taller than the screen.
              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(totalQty, sorted.length),
                  ),
                  SliverToBoxAdapter(
                    child: _buildFilters(sorted.length, _assets!),
                  ),
                  if (sorted.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmpty(_assets!.isEmpty),
                    )
                  else
                    _buildListSliver(sorted),
                ],
              );
            },
          ),

          // ── Seeding overlay ──────────────────────────────────────────
          if (_isSeeding)
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
                      const CircularProgressIndicator(color: _navy),
                      const SizedBox(height: 16),
                      const Text('Seeding Fixed Assets…',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        'Adding ${SeedFixedAssets.allItems.length} items to Firestore',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale:
        CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut),
        child: FloatingActionButton.extended(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Add Asset',
              style: TextStyle(fontWeight: FontWeight.w600)),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(settings: const RouteSettings(name: 'Add Fixed Asset'),
                  builder: (_) => const AddFixedAssetScreen()),
            );
            _loadAssets();
          },
        ),
      ),
    );
  }

  // ── APP BAR ───────────────────────────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _navy,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Fixed Assets',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
      ),
      actions: [
        // ── Seed button ──────────────────────────────────────────────
        IconButton(
          icon: _isSeeding
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2),
          )
              : const Icon(Icons.cloud_upload_rounded),
          tooltip: 'Seed All Fixed Assets',
          onPressed: _isSeeding ? null : _seedAllAssets,
        ),
      ],
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────
  Widget _buildHeader(int totalQty, int totalItems) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
              color: _navy.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statChip(
                icon: Icons.inventory_2_rounded,
                label: 'Total Items',
                value: '$totalItems',
              ),
              const SizedBox(width: 12),
              _statChip(
                icon: Icons.layers_rounded,
                label: 'Total Qty',
                value: '$totalQty',
              ),
              const SizedBox(width: 12),
              _statChip(
                icon: Icons.business_rounded,
                label: 'Branches',
                value: _branchFilter == 'All' ? '2' : '1',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border:
              Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search assets by name or location…',
                hintStyle: TextStyle(color: Colors.white60),
                prefixIcon: Icon(Icons.search_rounded,
                    color: Colors.white70),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding:
        const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── FILTERS ───────────────────────────────────────────────────────────────
  Widget _buildFilters(int resultCount, List<FixedAsset> allAssets) {
    final sortActive = _sortOption != AssetSortOption.none;
    final categories = _availableCategories(allAssets);
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Branch:',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black54)),
              const SizedBox(width: 8),
              ..._branches.map((b) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(b),
                  selected: _branchFilter == b,
                  selectedColor: _accent,
                  backgroundColor: _accent.withOpacity(0.10),
                  side: BorderSide(
                    color: _branchFilter == b
                        ? _accent
                        : _accent.withOpacity(0.35),
                  ),
                  labelStyle: TextStyle(
                    color: _branchFilter == b
                        ? Colors.white
                        : _accent,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) =>
                      setState(() => _branchFilter = b),
                ),
              )),
              const Spacer(),
              // ── Sort button ─────────────────────────────────────────
              InkWell(
                onTap: _openSortSheet,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sortActive
                        ? _accent.withOpacity(0.12)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sortActive
                          ? _accent
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sortOption.icon,
                        size: 16,
                        color: sortActive
                            ? _accent
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sortActive ? _sortOption.label : 'Sort',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sortActive
                              ? _accent
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (categories.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Category:',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black54)),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      itemBuilder: (_, i) {
                        final cat = categories[i];
                        final isSelected = _categoryFilter == cat;
                        final color = cat == 'All'
                            ? _accent
                            : _categoryColor(cat);
                        final icon = cat == 'All'
                            ? Icons.apps_rounded
                            : _categoryIcon(cat);
                        final count = cat == 'All'
                            ? allAssets.length
                            : allAssets
                            .where((a) => a.category == cat)
                            .length;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _categoryFilter = cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? color : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? color
                                      : Colors.grey.shade300,
                                ),
                                boxShadow: isSelected
                                    ? [
                                  BoxShadow(
                                      color: color.withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2))
                                ]
                                    : [],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon,
                                      size: 14,
                                      color: isSelected
                                          ? Colors.white
                                          : color),
                                  const SizedBox(width: 5),
                                  Text(cat,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey[700],
                                      )),
                                  if (count > 0) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white.withOpacity(0.25)
                                            : color.withOpacity(0.12),
                                        borderRadius:
                                        BorderRadius.circular(10),
                                      ),
                                      child: Text('$count',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? Colors.white
                                                : color,
                                          )),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text('$resultCount result${resultCount == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: Colors.black38,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ── LIST ──────────────────────────────────────────────────────────────────
  // Sliver version (was a ListView.builder) — sits inside the same
  // CustomScrollView as the header + filters above so the whole page
  // scrolls as one unit instead of the list scrolling separately in its
  // own leftover space.
  Widget _buildListSliver(List<FixedAsset> assets) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (ctx, i) => _AssetCard(
            asset: assets[i],
            isLowStock: assets[i].quantity <= _lowStockThreshold,
            onEdit: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(settings: const RouteSettings(name: 'Add Fixed Asset'),
                    builder: (_) =>
                        AddFixedAssetScreen(existing: assets[i])),
              );
              _loadAssets();
            },
            onDelete: () => _delete(assets[i]),
          ),
          childCount: assets.length,
        ),
      ),
    );
  }

  // ── EMPTY STATE ───────────────────────────────────────────────────────────
  Widget _buildEmpty(bool collectionIsEmpty) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 72, color: Colors.blue.shade100),
          const SizedBox(height: 16),
          const Text('No assets found',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black45)),
          const SizedBox(height: 6),
          // Show seed hint when collection is truly empty
          if (collectionIsEmpty) ...[
            const Text(
              'Tap the upload icon in the top bar\nto load all 223 fixed assets at once.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isSeeding ? null : _seedAllAssets,
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.cloud_upload_rounded, size: 18),
              label: const Text('Seed All Fixed Assets'),
            ),
          ] else ...[
            const Text('Try a different search or branch filter.',
                style: TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 64, color: Colors.red.shade200),
            const SizedBox(height: 16),
            const Text('Could not reach Firestore',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ASSET CARD
// ═══════════════════════════════════════════════════════════════════════════

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.onEdit,
    required this.onDelete,
    this.isLowStock = false,
  });

  final FixedAsset asset;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isLowStock;

  static const Color _navy = Color(0xFF0D2B6E);

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(asset.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isLowStock
            ? Border.all(color: Colors.orange.shade300, width: 1.4)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 5, color: statusColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              asset.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isLowStock) ...[
                            const _LowStockBadge(),
                            const SizedBox(width: 6),
                          ],
                          _StatusBadge(
                              status: asset.status,
                              color: statusColor),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          _InfoPill(
                              icon: Icons.business_rounded,
                              text: asset.branch),
                          _InfoPill(
                              icon: Icons.location_on_rounded,
                              text: asset.location.isEmpty
                                  ? 'No location'
                                  : asset.location),
                          _InfoPill(
                              icon: Icons.layers_rounded,
                              text: 'Qty: ${asset.quantity}',
                              highlight: true,
                              warning: isLowStock),
                          if (asset.category.isNotEmpty)
                            _InfoPill(
                                icon: Icons.category_rounded,
                                text: asset.category),
                        ],
                      ),
                      if (asset.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          asset.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey.shade600,
                              height: 1.4),
                        ),
                      ],
                      const Divider(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _ActionButton(
                            label: 'Edit',
                            icon: Icons.edit_rounded,
                            color: _navy,
                            onTap: onEdit,
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            label: 'Remove',
                            icon: Icons.delete_outline_rounded,
                            color: Colors.red.shade600,
                            onTap: onDelete,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Maintenance':
        return Colors.orange;
      case 'Retired':
        return Colors.red.shade400;
      default:
        return Colors.green;
    }
  }
}

class _LowStockBadge extends StatelessWidget {
  const _LowStockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange),
          SizedBox(width: 3),
          Text(
            'Low Stock',
            style: TextStyle(
                color: Colors.orange,
                fontSize: 10.5,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.text,
    this.highlight = false,
    this.warning = false,
  });
  final IconData icon;
  final String text;
  final bool highlight;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? Colors.orange.shade700
        : highlight
        ? const Color(0xFF1976D2)
        : Colors.grey.shade500;
    final textColor = warning
        ? Colors.orange.shade700
        : highlight
        ? const Color(0xFF1976D2)
        : Colors.grey.shade700;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight:
            (highlight || warning) ? FontWeight.w700 : FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ADD / EDIT SCREEN  (unchanged from your original)
// ═══════════════════════════════════════════════════════════════════════════

class AddFixedAssetScreen extends StatefulWidget {
  final FixedAsset? existing;
  const AddFixedAssetScreen({super.key, this.existing});

  @override
  State<AddFixedAssetScreen> createState() =>
      _AddFixedAssetScreenState();
}

class _AddFixedAssetScreenState extends State<AddFixedAssetScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _location;
  late final TextEditingController _description;
  late final TextEditingController _addedBy;

  String _branch = 'CDA Admin';
  String _status = 'Active';
  bool _saving = false;
  late DateTime _addedOn;

  static const Color _navy = Color(0xFF0D1B4B);
  static const Color _accent = Color(0xFF1565C0);
  static const List<String> _branches = ['CDA Admin', 'CDA Ops'];
  static const List<String> _statuses = ['Active', 'Maintenance', 'Retired'];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name        = TextEditingController(text: e?.name ?? '');
    _quantity    = TextEditingController(
        text: e == null ? '' : '${e.quantity}');
    _location    = TextEditingController(text: e?.location ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _addedBy     = TextEditingController(text: e?.createdBy ?? '');
    _addedOn     = e?.createdAt ?? DateTime.now();
    _branch = (e != null && _branches.contains(e.branch))
        ? e.branch
        : 'CDA Admin';
    _status = (e != null && _statuses.contains(e.status))
        ? e.status
        : 'Active';
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _location.dispose();
    _description.dispose();
    _addedBy.dispose();
    super.dispose();
  }

  Future<void> _pickAddedOnDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _addedOn,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_addedOn),
    );
    if (pickedTime == null) return;

    setState(() {
      _addedOn = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'name': _name.text.trim(),
      'quantity': int.parse(_quantity.text.trim()),
      'branch': _branch,
      'location': _location.text.trim(),
      'description': _description.text.trim(),
      'category': 'Fixed Asset',
      'status': _status,
      'createdBy': _addedBy.text.trim().isEmpty
          ? 'Unknown user'
          : _addedBy.text.trim(),
      'createdAt': Timestamp.fromDate(_addedOn),
    };

    try {
      if (_isEdit) {
        await FixedAssetService.updateAsset(widget.existing!.id, data);
      } else {
        await FixedAssetService.addAsset(data);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Asset' : 'Add Fixed Asset',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        backgroundColor: _navy,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Added By'),
              _buildCard([_buildAddedByInfo()]),
              const SizedBox(height: 16),
              _sectionLabel('Asset Details'),
              _buildCard([
                _field(
                  controller: _name,
                  label: 'Asset Name',
                  icon: Icons.inventory_2_rounded,
                  validator: (v) =>
                  v == null || v.trim().isEmpty
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 14),
                _field(
                  controller: _quantity,
                  label: 'Quantity',
                  icon: Icons.layers_rounded,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Required';
                    }
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 0) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _field(
                  controller: _location,
                  label: 'Location / Room',
                  icon: Icons.location_on_rounded,
                  validator: (v) =>
                  v == null || v.trim().isEmpty
                      ? 'Location is required'
                      : null,
                ),
              ]),
              const SizedBox(height: 16),
              _sectionLabel('Classification'),
              _buildCard([
                _dropdown(
                  label: 'Branch',
                  icon: Icons.business_rounded,
                  value: _branch,
                  items: _branches,
                  onChanged: (v) => setState(() => _branch = v!),
                ),
                const SizedBox(height: 14),
                _labeledWidget(
                  label: 'Status',
                  icon: Icons.info_outline_rounded,
                  child: Row(
                    children: _statuses.map((s) {
                      final selected = _status == s;
                      final color = _statusColor(s);
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              right:
                              s == _statuses.last ? 0 : 8),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _status = s),
                            child: AnimatedContainer(
                              duration: const Duration(
                                  milliseconds: 200),
                              padding:
                              const EdgeInsets.symmetric(
                                  vertical: 12),
                              decoration: BoxDecoration(
                                color: selected
                                    ? color.withValues(alpha: 0.15)
                                    : Colors.white,
                                borderRadius:
                                BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? color
                                      : Colors.grey.shade300,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                s,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? color
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              _sectionLabel('Notes'),
              _buildCard([
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    labelStyle: TextStyle(color: Colors.grey.shade600),
                    floatingLabelStyle: const TextStyle(color: _accent),
                    prefixIcon: const Icon(Icons.notes_rounded,
                        color: _accent, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                        const BorderSide(color: _accent, width: 1.5)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                ),
              ]),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : Icon(
                      _isEdit ? Icons.save_rounded : Icons.add_circle_outline,
                      color: Colors.white),
                  label: Text(
                    _saving
                        ? 'Saving…'
                        : _isEdit
                        ? 'Save Changes'
                        : 'ADD FIXED ASSET',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _accent,
            letterSpacing: 1.2),
      ),
    );
  }

  // Groups a section's fields into one white, rounded, softly-shadowed
  // card — matching AddProductScreen's _buildCard() in the Inventory
  // page exactly, instead of leaving each field as its own separate
  // bordered box with no enclosing section container.
  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: children),
    );
  }

  // ── Added-by / date info — manually editable ─────────────────────────────
  // Now lives inside the same white _buildCard() as every other section
  // (previously had its own mint-green tinted container) so the whole
  // form reads as one consistent theme, matching Add New Item exactly.
  Widget _buildAddedByInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(
          controller: _addedBy,
          label: 'Your Name',
          icon: Icons.person_outline,
          validator: (v) => v == null || v.trim().isEmpty
              ? 'Enter your name'
              : null,
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: _pickAddedOnDate,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 20, color: _accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _formatDate(_addedOn),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(Icons.edit_rounded,
                    size: 16, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year, $hour:$minute $period';
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.words,
      validator: validator,
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        floatingLabelStyle: const TextStyle(color: _accent),
        prefixIcon: Icon(icon, color: _accent, size: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _accent, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        floatingLabelStyle: const TextStyle(color: _accent),
        prefixIcon: Icon(icon, color: _accent, size: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _accent, width: 1.5)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: items
          .map((i) => DropdownMenuItem(
        value: i,
        child: Text(
          i,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _labeledWidget({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Maintenance':
        return Colors.orange;
      case 'Retired':
        return Colors.red.shade400;
      default:
        return Colors.green;
    }
  }
}