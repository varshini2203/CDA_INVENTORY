import 'package:flutter/material.dart';

import 'package:cda_inventory/data/seed_fixed_assets.dart';
import 'package:cda_inventory/models/fixed_asset.dart';
import 'package:cda_inventory/services/fixed_asset_service.dart';

import 'add_fixed_product_screen.dart';
import 'fixed_product_details_screen.dart';

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
        return 'Low Stock First';
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

  List<FixedAsset>? _assets;
  String? _loadError;

  late final AnimationController _fabAnimationController;

  static const List<String> _branches = [
    'All',
    'CDA Admin',
    'CDA Ops',
  ];

  static const Color _navy = Color(0xFF0A1628);
  static const Color _accent = Color(0xFF00D4AA);
  static const Color _surface = Color(0xFFF0F4F8);

  static const int _lowStockThreshold = 2;

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
    Color(0xFF00D4AA),
    Color(0xFF6C63FF),
    Color(0xFFFFB800),
    Color(0xFFFF6B6B),
    Color(0xFF00B894),
    Color(0xFF2E86DE),
    Color(0xFFE84393),
    Color(0xFFD35400),
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

  @override
  void initState() {
    super.initState();

    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();

    _loadAssets();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    try {
      final assets = await FixedAssetService.getAssets();

      if (!mounted) return;

      setState(() {
        _assets = assets;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadError = error.toString();
      });
    }
  }

  Future<void> _retryLoad() async {
    setState(() {
      _assets = null;
      _loadError = null;
    });

    await _loadAssets();
  }

  List<FixedAsset> _filterList(List<FixedAsset> allAssets) {
    final searchText = _search.trim().toLowerCase();

    return allAssets.where((asset) {
      final matchesBranch = _branchFilter == 'All' ||
          asset.branch.trim() == _branchFilter;

      final matchesCategory = _categoryFilter == 'All' ||
          asset.category.trim() == _categoryFilter;

      final matchesSearch = searchText.isEmpty ||
          asset.name.toLowerCase().contains(searchText) ||
          asset.location.toLowerCase().contains(searchText) ||
          asset.category.toLowerCase().contains(searchText) ||
          asset.branch.toLowerCase().contains(searchText);

      return matchesBranch && matchesCategory && matchesSearch;
    }).toList();
  }

  List<FixedAsset> _sortList(List<FixedAsset> assets) {
    final sorted = List<FixedAsset>.from(assets);

    switch (_sortOption) {
      case AssetSortOption.dateNewest:
        sorted.sort((a, b) {
          final first = a.createdAt;
          final second = b.createdAt;

          if (first == null && second == null) return 0;
          if (first == null) return 1;
          if (second == null) return -1;

          return second.compareTo(first);
        });
        break;

      case AssetSortOption.dateOldest:
        sorted.sort((a, b) {
          final first = a.createdAt;
          final second = b.createdAt;

          if (first == null && second == null) return 0;
          if (first == null) return 1;
          if (second == null) return -1;

          return first.compareTo(second);
        });
        break;

      case AssetSortOption.lowStock:
        sorted.sort((a, b) {
          final aLow = a.quantity <= _lowStockThreshold;
          final bLow = b.quantity <= _lowStockThreshold;

          if (aLow && !bLow) return -1;
          if (!aLow && bLow) return 1;

          return a.quantity.compareTo(b.quantity);
        });
        break;

      case AssetSortOption.none:
        break;
    }

    return sorted;
  }

  List<String> _availableCategories(List<FixedAsset> assets) {
    final categories = <String>{};

    for (final asset in assets) {
      final category = asset.category.trim();

      if (category.isNotEmpty) {
        categories.add(category);
      }
    }

    final sorted = categories.toList()..sort();

    return [
      'All',
      ...sorted,
    ];
  }

  IconData _categoryIcon(String category) {
    final categoryLower = category.toLowerCase();

    for (final entry in _categoryKeywordIcons) {
      if (categoryLower.contains(entry.key)) {
        return entry.value;
      }
    }

    return Icons.category_rounded;
  }

  Color _categoryColor(String category) {
    final categoryLower = category.toLowerCase();

    for (final entry in _categoryKeywordColors.entries) {
      if (categoryLower.contains(entry.key)) {
        return entry.value;
      }
    }

    final index =
        category.hashCode.abs() % _categoryFallbackPalette.length;

    return _categoryFallbackPalette[index];
  }

  Future<void> _openAddScreen() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(
          name: 'Add Fixed Asset',
        ),
        builder: (_) => const AddFixedProductScreen(),
      ),
    );

    if (changed == true) {
      await _loadAssets();
    }
  }

  Future<void> _openEditScreen(FixedAsset asset) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(
          name: 'Edit Fixed Asset',
        ),
        builder: (_) => AddFixedProductScreen(
          existing: asset,
        ),
      ),
    );

    if (changed == true) {
      await _loadAssets();
    }
  }

  Future<void> _viewAsset(FixedAsset asset) async {
    final action = await FixedProductDetailsScreen.show(
      context: context,
      asset: asset,
    );

    if (!mounted || action == null) return;

    switch (action) {
      case FixedAssetDetailsAction.edit:
        await _openEditScreen(asset);
        break;

      case FixedAssetDetailsAction.delete:
        await _delete(asset);
        break;
    }
  }

  Future<void> _delete(FixedAsset asset) async {
    final confirmed = await _confirm(
      title: 'Remove Asset',
      message:
      'Remove "${asset.name}" from the registry? This action cannot be undone.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );

    if (!confirmed) return;

    try {
      await FixedAssetService.deleteAsset(asset.id);

      if (!mounted) return;

      _snack(
        '${asset.name} removed',
        isError: false,
      );

      await _loadAssets();
    } catch (error) {
      _snack(
        'Delete failed: $error',
        isError: true,
      );
    }
  }

  Future<void> _seedAllAssets() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.cloud_upload_rounded,
                color: _accent,
              ),
              SizedBox(width: 8),
              Text('Seed Fixed Assets'),
            ],
          ),
          content: Text(
            'This will add all ${SeedFixedAssets.allItems.length} fixed '
                'assets from the master spreadsheet into Firestore.\n\n'
                'This is normally a one-time action. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(
                Icons.upload_rounded,
                size: 17,
              ),
              label: const Text('Seed Now'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSeeding = true);

    try {
      final result = await FixedAssetService.seedAssets(
        SeedFixedAssets.allItems,
      );

      if (!mounted) return;

      _snack(
        'Seeded: ${result['success']} added, '
            '${result['failed']} skipped',
        isError: false,
      );

      await _loadAssets();
    } catch (error) {
      _snack(
        'Seeding failed: $error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSeeding = false);
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDestructive
                    ? Colors.red.shade700
                    : _accent,
                foregroundColor: Colors.white,
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void _snack(
      String message, {
        required bool isError,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red.shade700
            : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _openSortSheet() async {
    final selected = await showModalBottomSheet<AssetSortOption>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(22),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            18,
            14,
            18,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sort By',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              ...AssetSortOption.values.map((option) {
                final selectedOption = _sortOption == option;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    option.icon,
                    color: selectedOption
                        ? _accent
                        : Colors.grey.shade500,
                  ),
                  title: Text(
                    option.label,
                    style: TextStyle(
                      color: selectedOption
                          ? _accent
                          : Colors.black87,
                      fontWeight: selectedOption
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  trailing: selectedOption
                      ? const Icon(
                    Icons.check_rounded,
                    color: _accent,
                  )
                      : null,
                  onTap: () {
                    Navigator.pop(sheetContext, option);
                  },
                );
              }),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != _sortOption) {
      setState(() {
        _sortOption = selected;
      });
    }
  }

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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _navy,
                  ),
                );
              }

              final filtered = _filterList(_assets!);
              final sorted = _sortList(filtered);

              final totalQuantity = sorted.fold<int>(
                0,
                    (sum, asset) => sum + asset.quantity,
              );

              final branchCount = sorted
                  .map((asset) => asset.branch.trim())
                  .where((branch) => branch.isNotEmpty)
                  .toSet()
                  .length;

              return RefreshIndicator(
                color: _navy,
                onRefresh: _loadAssets,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildHeader(
                        totalQuantity,
                        sorted.length,
                        branchCount,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _buildFilters(
                        sorted.length,
                        _assets!,
                      ),
                    ),
                    if (sorted.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmpty(
                          _assets!.isEmpty,
                        ),
                      )
                    else
                      _buildListSliver(sorted),
                  ],
                ),
              );
            },
          ),
          if (_isSeeding) _buildSeedingOverlay(),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(
          parent: _fabAnimationController,
          curve: Curves.elasticOut,
        ),
        child: FloatingActionButton.extended(
          onPressed: _isSeeding ? null : _openAddScreen,
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Add Asset',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _navy,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Fixed Assets',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _isSeeding ? null : _loadAssets,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Seed All Fixed Assets',
          onPressed: _isSeeding ? null : _seedAllAssets,
          icon: _isSeeding
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Icon(Icons.cloud_upload_rounded),
        ),
      ],
    );
  }

  Widget _buildHeader(
      int totalQuantity,
      int totalItems,
      int branchCount,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        24,
      ),
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
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
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
                value: '$totalQuantity',
              ),
              const SizedBox(width: 12),
              _statChip(
                icon: Icons.business_rounded,
                label: 'Branches',
                value: '$branchCount',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.23),
              ),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _search = value;
                });
              },
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration: const InputDecoration(
                hintText: 'Search by name, location or category…',
                hintStyle: TextStyle(
                  color: Colors.white60,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.white70,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
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
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.11),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white70,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(
      int resultCount,
      List<FixedAsset> allAssets,
      ) {
    final categories = _availableCategories(allAssets);
    final sortActive = _sortOption != AssetSortOption.none;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Branch',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _openSortSheet,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: sortActive
                        ? _accent.withOpacity(0.12)
                        : Colors.white,
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
                        sortActive
                            ? _sortOption.label
                            : 'Sort',
                        style: TextStyle(
                          color: sortActive
                              ? _accent
                              : Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _branches.length,
              separatorBuilder: (_, __) {
                return const SizedBox(width: 8);
              },
              itemBuilder: (_, index) {
                final branch = _branches[index];

                return ChoiceChip(
                  label: Text(branch),
                  selected: _branchFilter == branch,
                  selectedColor: _accent,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: _branchFilter == branch
                        ? _accent
                        : Colors.grey.shade300,
                  ),
                  labelStyle: TextStyle(
                    color: _branchFilter == branch
                        ? Colors.white
                        : Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _branchFilter = branch;
                    });
                  },
                );
              },
            ),
          ),
          if (categories.length > 1) ...[
            const SizedBox(height: 14),
            const Text(
              'Category',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (_, index) {
                  final category = categories[index];
                  final selected =
                      _categoryFilter == category;

                  final color = category == 'All'
                      ? _accent
                      : _categoryColor(category);

                  final icon = category == 'All'
                      ? Icons.apps_rounded
                      : _categoryIcon(category);

                  final count = category == 'All'
                      ? allAssets.length
                      : allAssets
                      .where(
                        (asset) =>
                    asset.category.trim() == category,
                  )
                      .length;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _categoryFilter = category;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? color
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? color
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 14,
                              color: selected
                                  ? Colors.white
                                  : color,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              category,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.grey.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white.withOpacity(0.22)
                                    : color.withOpacity(0.10),
                                borderRadius:
                                BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$resultCount result${resultCount == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Colors.black38,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListSliver(List<FixedAsset> assets) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        100,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final asset = assets[index];

            return _AssetCard(
              asset: asset,
              isLowStock:
              asset.quantity <= _lowStockThreshold,
              onView: () => _viewAsset(asset),
              onEdit: () => _openEditScreen(asset),
              onDelete: () => _delete(asset),
            );
          },
          childCount: assets.length,
        ),
      ),
    );
  }

  Widget _buildEmpty(bool collectionIsEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 72,
              color: Colors.blue.shade100,
            ),
            const SizedBox(height: 16),
            const Text(
              'No assets found',
              style: TextStyle(
                color: Colors.black45,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            if (collectionIsEmpty) ...[
              const Text(
                'Tap the upload icon to load all fixed assets.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed:
                _isSeeding ? null : _seedAllAssets,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(
                  Icons.cloud_upload_rounded,
                  size: 18,
                ),
                label: const Text('Seed Fixed Assets'),
              ),
            ] else
              const Text(
                'Try changing your search or filters.',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
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
            Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: Colors.red.shade200,
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not reach Firestore',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _retryLoad,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeedingOverlay() {
    return Positioned.fill(
      child: Container(
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
                const CircularProgressIndicator(
                  color: _navy,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Seeding Fixed Assets…',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Adding ${SeedFixedAssets.allItems.length} items',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  final FixedAsset asset;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isLowStock;

  const _AssetCard({
    required this.asset,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.isLowStock,
  });

  static const Color _navy = Color(0xFF0A1628);

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(asset.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isLowStock
            ? Border.all(
          color: Colors.orange.shade300,
          width: 1.4,
        )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 5,
                color: statusColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              asset.name,
                              style: const TextStyle(
                                color: Color(0xFF1A1A2E),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isLowStock) ...[
                            const _LowStockBadge(),
                            const SizedBox(width: 6),
                          ],
                          _StatusBadge(
                            status: asset.status.trim().isEmpty
                                ? 'Active'
                                : asset.status,
                            color: statusColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _InfoPill(
                            icon: Icons.business_rounded,
                            text: asset.branch.trim().isEmpty
                                ? 'No branch'
                                : asset.branch,
                          ),
                          _InfoPill(
                            icon: Icons.location_on_rounded,
                            text: asset.location.trim().isEmpty
                                ? 'No location'
                                : asset.location,
                          ),
                          _InfoPill(
                            icon: Icons.layers_rounded,
                            text: 'Qty: ${asset.quantity}',
                            highlight: true,
                            warning: isLowStock,
                          ),
                          if (asset.category.trim().isNotEmpty)
                            _InfoPill(
                              icon: Icons.category_rounded,
                              text: asset.category,
                            ),
                        ],
                      ),
                      if (asset.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Text(
                          asset.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              label: 'View',
                              icon: Icons.visibility_rounded,
                              color: _navy,
                              onTap: onView,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ActionButton(
                              label: 'Edit',
                              icon: Icons.edit_rounded,
                              color: Colors.orange.shade700,
                              onTap: onEdit,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ActionButton(
                              label: 'Remove',
                              icon:
                              Icons.delete_outline_rounded,
                              color: Colors.red.shade600,
                              onTap: onDelete,
                            ),
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
    switch (status.toLowerCase()) {
      case 'maintenance':
        return Colors.orange;
      case 'retired':
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
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orange.withOpacity(0.5),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 12,
            color: Colors.orange,
          ),
          SizedBox(width: 3),
          Text(
            'Low Stock',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusBadge({
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.4),
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;
  final bool warning;

  const _InfoPill({
    required this.icon,
    required this.text,
    this.highlight = false,
    this.warning = false,
  });

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
        Icon(
          icon,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 12.5,
            fontWeight: highlight || warning
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: color.withOpacity(0.24),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: color,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}