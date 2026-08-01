import 'package:flutter/material.dart';
import 'package:cda_inventory/models/consumable.dart';          // ← absolute import
import 'package:cda_inventory/services/consumable_service.dart'; // ← absolute import
import 'package:cda_inventory/screens/consumables/add_consumable_screen.dart'; // ← absolute import
import 'package:cda_inventory/screens/consumables/edit_consumable_screen.dart'; // ← absolute import

enum ConsumableSortOption { newest, oldest, lowStock }

class ConsumableListScreen extends StatefulWidget {
  const ConsumableListScreen({super.key});

  @override
  State<ConsumableListScreen> createState() => _ConsumableListScreenState();
}

class _ConsumableListScreenState extends State<ConsumableListScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<Consumable>> consumablesFuture;
  String searchQuery = '';
  String selectedFilter = 'All'; // category filter
  String selectedBranch = 'All'; // branch filter (raw Firestore value, e.g. 'Branch 1')
  ConsumableSortOption sortOption = ConsumableSortOption.newest; // ← NEW
  final TextEditingController searchController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  static const Color kNavy    = Color(0xFF0A1628);
  static const Color kTeal    = Color(0xFF00D4AA);
  static const Color kCoral   = Color(0xFFFF6B6B);
  static const Color kAmber   = Color(0xFFFFB800);
  static const Color kSurface = Color(0xFFF0F4F8);
  static const Color kGreen   = Color(0xFF00B894);

  // These now match exactly what's stored in Firestore's 'branch' field
  // (confirmed against seed_consumables.dart: docs are seeded with
  // 'CDA Admin' / 'CDA Ops' directly, not placeholder 'Branch 1'/'Branch 2'
  // values). No display-label translation is needed since the stored
  // value already is the display label.
  static const List<String> branches = ['All', 'CDA Admin', 'CDA Ops'];

  // Kept only for backward compatibility with any older docs that might
  // still use the legacy 'Branch 1'/'Branch 2' raw values.
  static const Map<String, String> branchLabels = {
    'Branch 1': 'CDA Admin',
    'Branch 2': 'CDA Ops',
  };

  /// Maps a raw branch value (possibly comma-joined, e.g. "Branch 1, Branch 2")
  /// to its display label(s), e.g. "CDA Admin, CDA Ops".
  String _branchLabel(String rawBranch) {
    if (rawBranch.isEmpty) return '';
    return rawBranch
        .split(RegExp(r'[,&]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => branchLabels[e] ?? e)
        .join(', ');
  }

  // Known categories get a nice icon/color. Anything else (and there are
  // ~90 real categories in the seeded data, e.g. "Row-3", "Charging
  // Station", "Md Room"...) falls back to a generic icon/color below.
  static const Map<String, IconData> categoryIcons = {
    'Stationery':  Icons.edit_note,
    'Drone Parts': Icons.flight,
    'Electronics': Icons.electrical_services,
    'Training':    Icons.school,
  };

  static const Map<String, Color> categoryColors = {
    'Stationery':  Color(0xFF4F8EF7),
    'Drone Parts': Color(0xFF7C3AED),
    'Electronics': Color(0xFF059669),
    'Training':    Color(0xFFD97706),
  };

  // A small palette cycled through for categories that don't have an
  // explicit color above, so different categories are still visually
  // distinguishable instead of all defaulting to the same blue.
  static const List<Color> _fallbackPalette = [
    Color(0xFF4F8EF7), Color(0xFF7C3AED), Color(0xFF059669),
    Color(0xFFD97706), Color(0xFFDB2777), Color(0xFF0891B2),
    Color(0xFF65A30D), Color(0xFFEA580C),
  ];

  Color _colorFor(String category) {
    if (categoryColors.containsKey(category)) return categoryColors[category]!;
    final idx = category.hashCode.abs() % _fallbackPalette.length;
    return _fallbackPalette[idx];
  }

  IconData _iconFor(String category) =>
      categoryIcons[category] ?? Icons.inventory_2;

  /// Categories derived from whatever's actually loaded, so the filter
  /// row always matches the real data instead of a hardcoded 4-item list.
  /// Splits comma-joined category values (e.g. "Row-3, Tool Kits") since
  /// some seeded items belong to more than one category/location.
  List<String> _categoriesFrom(List<Consumable> items) {
    final set = <String>{};
    for (final item in items) {
      for (final c in item.category.split(',')) {
        final trimmed = c.trim();
        if (trimmed.isNotEmpty) set.add(trimmed);
      }
    }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    loadConsumables();
  }

  @override
  void dispose() {
    searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── Load / refresh ─────────────────────────────────────────────────────
  void loadConsumables({bool forceRefresh = false}) {
    consumablesFuture =
        ConsumableService.getConsumables(forceRefresh: forceRefresh);
    consumablesFuture.then((_) => _animController.forward(from: 0));
  }

  void refresh({bool forceRefresh = false}) {
    setState(() {
      loadConsumables(forceRefresh: forceRefresh);
    });
  }

  // ── Seed consumables (cloud upload) ─────────────────────────────────────
  Future<void> _seedConsumables() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.cloud_upload_rounded, color: kTeal),
            SizedBox(width: 8),
            Text('Seed Consumables?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'This will delete all existing consumables and re-upload the master '
              'inventory list (from the CDA spreadsheet) to Firestore, so branch '
              'tags are set correctly. This cannot be undone.\n\nContinue?',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
            Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kTeal,
              foregroundColor: kNavy,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: kTeal),
      ),
    );

    try {
      await ConsumableService.deleteAllConsumables();
      await ConsumableService.seedConsumables();
      if (!mounted) return;
      Navigator.pop(context); // close loader
      refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: const [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Consumables seeded successfully'),
          ]),
          backgroundColor: kGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Seed failed: $e')),
          ]),
          backgroundColor: kCoral,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }

  Future<void> deleteConsumable(
      BuildContext ctx, String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: kCoral),
            SizedBox(width: 8),
            Text('Delete Item',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Remove "$name" from inventory?\nThis cannot be undone.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
            Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ConsumableService.deleteConsumable(id);
      refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('"$name" removed'),
            ]),
            backgroundColor: kCoral,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(12),
          ),
        );
      }
    }
  }

  List<Consumable> _filtered(List<Consumable> all) {
    return all.where((item) {
      final matchSearch =
          item.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
              item.category.toLowerCase().contains(searchQuery.toLowerCase());
      final matchCategory = selectedFilter == 'All' ||
          item.category.split(',').map((e) => e.trim()).contains(selectedFilter);
      final matchBranch = item.belongsToBranch(selectedBranch);
      return matchSearch && matchCategory && matchBranch;
    }).toList();
  }

  // ── Sort ────────────────────────────────────────────────────────────────
  List<Consumable> _sorted(List<Consumable> items) {
    final sorted = List<Consumable>.from(items);
    switch (sortOption) {
      case ConsumableSortOption.newest:
        sorted.sort((a, b) => b.id.compareTo(a.id));
        break;
      case ConsumableSortOption.oldest:
        sorted.sort((a, b) => a.id.compareTo(b.id));
        break;
      case ConsumableSortOption.lowStock:
        sorted.sort((a, b) => a.quantity.compareTo(b.quantity));
        break;
    }
    return sorted;
  }

  Color _stockColor(Consumable item) {
    if (item.quantity == 0) return kCoral;
    if (item.quantity <= item.minimumStock) return kAmber;
    return kGreen;
  }

  String _stockLabel(Consumable item) {
    if (item.quantity == 0) return 'Out of stock';
    if (item.quantity <= item.minimumStock) return 'Low stock';
    return 'In stock';
  }

  void _showDetail(BuildContext ctx, Consumable item) {
    final catColor = _colorFor(item.category);
    final catIcon  = _iconFor(item.category);

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(catIcon, color: catColor, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item.category,
                          style: TextStyle(
                            color: catColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _detailStat('Available', '${item.quantity}',
                    Icons.inventory_2, _stockColor(item)),
                const SizedBox(width: 12),
                _detailStat('Min. Stock', '${item.minimumStock}',
                    Icons.warning_amber_rounded, kAmber),
                const SizedBox(width: 12),
                _detailStat('Status', _stockLabel(item),
                    Icons.circle, _stockColor(item)),
              ],
            ),
            if (item.branch.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.business_rounded,
                      size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(_branchLabel(item.branch), // ← display label, not raw value
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700)),
                ],
              ),
            ],
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Description',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500),
              ),
              const SizedBox(height: 6),
              Text(item.description,
                  style: const TextStyle(fontSize: 15, height: 1.5)),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kNavy,
                      side: const BorderSide(color: kNavy),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditConsumableScreen(item: item),
                          settings: const RouteSettings(name: 'Edit Consumable'),
                        ),
                      );
                      if (result == true) refresh();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_rounded),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kCoral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      deleteConsumable(context, item.id, item.name);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _detailStat(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: color),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 190,
            floating: false,
            pinned: true,
            backgroundColor: kNavy,
            foregroundColor: Colors.white,
            title: const Text(
              'Consumables',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              PopupMenuButton<ConsumableSortOption>(
                icon: const Icon(Icons.sort_rounded),
                tooltip: 'Sort',
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (value) => setState(() => sortOption = value),
                itemBuilder: (context) => [
                  _sortMenuItem(ConsumableSortOption.newest,
                      'Newest to Oldest', Icons.arrow_downward_rounded),
                  _sortMenuItem(ConsumableSortOption.oldest,
                      'Oldest to Newest', Icons.arrow_upward_rounded),
                  _sortMenuItem(ConsumableSortOption.lowStock,
                      'Low Stock First', Icons.warning_amber_rounded),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.cloud_upload_rounded),
                onPressed: _seedConsumables,
                tooltip: 'Seed consumables',
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => refresh(forceRefresh: true),
                tooltip: 'Refresh',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
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
                          const Text(
                            'Consumables',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'CDA Inventory System',
                            style: TextStyle(
                              color: kTeal,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FutureBuilder<List<Consumable>>(
                            future: consumablesFuture,
                            builder: (_, snap) {
                              if (!snap.hasData) return const SizedBox.shrink();
                              final all = snap.data!;
                              final low = all
                                  .where((i) =>
                              i.quantity <= i.minimumStock &&
                                  i.quantity > 0)
                                  .length;
                              final out =
                                  all.where((i) => i.quantity == 0).length;
                              return Row(children: [
                                _kpiChip(Icons.inventory_2_rounded,
                                    '${all.length}', 'Total'),
                                const SizedBox(width: 10),
                                _kpiChip(Icons.warning_amber_rounded,
                                    '$low', 'Low'),
                                const SizedBox(width: 10),
                                _kpiChip(Icons.remove_circle_outline,
                                    '$out', 'Out'),
                              ]);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              collapseMode: CollapseMode.parallax,
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              color: kNavy,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onChanged: (v) => setState(() => searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search by name or category…',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Colors.white.withValues(alpha: 0.6), size: 20),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                      icon: Icon(Icons.clear_rounded,
                          color: Colors.white.withValues(alpha: 0.6), size: 18),
                      onPressed: () {
                        searchController.clear();
                        setState(() => searchQuery = '');
                      },
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
          ),

          // Branch + Category filters — built once data is loaded so the
          // category chips always reflect what's actually in the collection.
          SliverToBoxAdapter(
            child: FutureBuilder<List<Consumable>>(
              future: consumablesFuture,
              builder: (_, snap) {
                final all = snap.data ?? [];
                final dynamicCategories = _categoriesFrom(all);

                return Container(
                  color: kSurface,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Branch chips ──────────────────────────────
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(
                          'BRANCH',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: branches.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final b = branches[i]; // matches stored value directly
                            final selected = selectedBranch == b;
                            return _filterChip(
                              // Stored value already is the display label,
                              // so no translation needed here.
                              label: b == 'All' ? 'All' : (branchLabels[b] ?? b),
                              selected: selected,
                              activeColor: kNavy,
                              onTap: () =>
                                  setState(() => selectedBranch = b),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Category chips (dynamic) ──────────────────
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(
                          'CATEGORY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: dynamicCategories.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final cat = dynamicCategories[i];
                            final selected = selectedFilter == cat;
                            return _filterChip(
                              label: cat,
                              selected: selected,
                              activeColor: kTeal,
                              activeLabelColor: kNavy,
                              onTap: () =>
                                  setState(() => selectedFilter = cat),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
            sliver: FutureBuilder<List<Consumable>>(
              future: consumablesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(
                        child: CircularProgressIndicator(color: kTeal)),
                  );
                }
                if (snapshot.hasError) {
                  return SliverFillRemaining(child: _buildError());
                }

                final all   = snapshot.data ?? [];
                final items = _sorted(_filtered(all)); // ← sort applied here

                if (all.isEmpty) {
                  return SliverFillRemaining(
                      child: _buildEmpty(isEmpty: true));
                }
                if (items.isEmpty) {
                  return SliverFillRemaining(
                      child: _buildEmpty(isEmpty: false));
                }

                final lowStock = items
                    .where(
                        (i) => i.quantity <= i.minimumStock && i.quantity > 0)
                    .length;
                final outOfStock =
                    items.where((i) => i.quantity == 0).length;

                return SliverList(
                  delegate: SliverChildListDelegate([
                    if (selectedFilter == 'All') ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            _statChip('${items.length}', 'Total', kTeal),
                            const SizedBox(width: 8),
                            _statChip('$lowStock', 'Low', kAmber),
                            const SizedBox(width: 8),
                            _statChip('$outOfStock', 'Out', kCoral),
                          ],
                        ),
                      ),
                    ],
                    ...items.map((item) => FadeTransition(
                      opacity: _fadeAnim,
                      child: _buildCard(item),
                    )),
                  ]),
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kTeal,
        foregroundColor: kNavy,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item',
            style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddConsumableScreen(),
              settings: const RouteSettings(name: 'Add Consumable'),
            ),
          );
          if (result == true) refresh();
        },
      ),
    );
  }

  // ── Sort menu item builder ────────────────────────────────────────────
  PopupMenuItem<ConsumableSortOption> _sortMenuItem(
      ConsumableSortOption value, String label, IconData icon) {
    final selected = sortOption == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: selected ? kTeal : Colors.grey.shade600),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? kTeal : kNavy,
            ),
          ),
          if (selected) ...[
            const Spacer(),
            const Icon(Icons.check_rounded, size: 16, color: kTeal),
          ],
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required Color activeColor,
    Color activeLabelColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
            BoxShadow(
              color: activeColor.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? activeLabelColor : Colors.grey.shade700,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _kpiChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: kTeal, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(count,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: color)),
            Text(label,
                style:
                TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Consumable item) {
    final catColor   = _colorFor(item.category);
    final catIcon    = _iconFor(item.category);
    final stockColor = _stockColor(item);
    final stockLabel = _stockLabel(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showDetail(context, item),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(catIcon, color: catColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: kNavy),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.label_outline,
                                size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                item.category,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500),
                              ),
                            ),
                            if (item.branch.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.business_rounded,
                                  size: 12, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(
                                _branchLabel(item.branch), // ← display label
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: stockColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle,
                                      size: 7, color: stockColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    stockLabel,
                                    style: TextStyle(
                                        color: stockColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Qty: ${item.quantity}',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                _actionBtn(
                  icon: Icons.visibility_rounded,
                  label: 'View',
                  color: kNavy,
                  onTap: () => _showDetail(context, item),
                ),
                const SizedBox(width: 8),
                _actionBtn(
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                  color: kAmber,
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditConsumableScreen(item: item),
                        settings: const RouteSettings(name: 'Edit Consumable'),
                      ),
                    );
                    if (result == true) refresh();
                  },
                ),
                const SizedBox(width: 8),
                _actionBtn(
                  icon: Icons.delete_rounded,
                  label: 'Delete',
                  color: kCoral,
                  onTap: () =>
                      deleteConsumable(context, item.id, item.name),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: kCoral.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 40, color: kCoral),
            ),
            const SizedBox(height: 20),
            const Text('Failed to load',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: kNavy)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => refresh(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty({required bool isEmpty}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isEmpty
                ? Icons.inventory_2_outlined
                : Icons.search_off_rounded,
            size: 72,
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 16),
          Text(
            isEmpty ? 'No items yet' : 'No matches found',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            isEmpty
                ? 'Tap + Add Item to get started'
                : 'Try a different search term',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
          if (isEmpty) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: kTeal,
                  foregroundColor: kNavy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddConsumableScreen(),
                    settings: const RouteSettings(name: 'Add Consumable'),
                  ),
                );
                if (result == true) refresh();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Item',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}