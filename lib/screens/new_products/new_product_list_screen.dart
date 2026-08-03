// lib/screens/new_products/new_product_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cda_inventory/models/new_product.dart';
import 'package:cda_inventory/services/new_product_service.dart';
import 'add_edit_new_product_screen.dart';
import 'new_product_detail_screen.dart';
import 'package:cda_inventory/screens/bulk_import/bulk_import_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  NEW PRODUCT LIST SCREEN  (dashboard + search + filters + sort + view/
//  edit/delete)
// ═══════════════════════════════════════════════════════════════════════════

enum NewProductSortOption { none, dateNewest, dateOldest, nameAZ }

extension NewProductSortOptionLabel on NewProductSortOption {
  String get label {
    switch (this) {
      case NewProductSortOption.dateNewest:
        return 'Newest First';
      case NewProductSortOption.dateOldest:
        return 'Oldest First';
      case NewProductSortOption.nameAZ:
        return 'Alphabetical';
      case NewProductSortOption.none:
        return 'Default';
    }
  }

  IconData get icon {
    switch (this) {
      case NewProductSortOption.dateNewest:
        return Icons.arrow_downward_rounded;
      case NewProductSortOption.dateOldest:
        return Icons.arrow_upward_rounded;
      case NewProductSortOption.nameAZ:
        return Icons.sort_by_alpha_rounded;
      case NewProductSortOption.none:
        return Icons.sort_rounded;
    }
  }
}

class NewProductListScreen extends StatefulWidget {
  const NewProductListScreen({super.key});

  @override
  State<NewProductListScreen> createState() => _NewProductListScreenState();
}

class _NewProductListScreenState extends State<NewProductListScreen>
    with SingleTickerProviderStateMixin {
  String _search = '';
  String _branchFilter = 'All';
  String _categoryFilter = 'All';
  String _vendorFilter = 'All';
  String _stockFilter = 'All'; // All | In Stock | Low Stock | Out of Stock
  NewProductSortOption _sortOption = NewProductSortOption.none;
  late AnimationController _fabAnim;

  List<NewProduct>? _products;
  String? _loadError;

  static const List<String> _branches = ['All', 'CDA Admin', 'CDA Ops'];

  static const Color _navy = Color(0xFF0A1628);
  static const Color _accent = Color(0xFF00D4AA);
  static const Color _surface = Color(0xFFF0F4F8);

  Future<void> _loadProducts() async {
    try {
      final list = await NewProductService.getNewProducts(forceRefresh: true);
      if (mounted) setState(() => _products = list);
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnim.forward();
    _loadProducts();
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    super.dispose();
  }

  // ── Derived filter option lists ──────────────────────────────────────
  List<String> _categoryOptions(List<NewProduct> all) {
    final set = <String>{'All', ...all.map((p) => p.category)};
    return set.toList();
  }

  List<String> _vendorOptions(List<NewProduct> all) {
    final set = <String>{
      'All',
      ...all.map((p) => p.vendorName).where((v) => v.isNotEmpty)
    };
    return set.toList();
  }

  // ── Filtering ─────────────────────────────────────────────────────────
  List<NewProduct> _filterList(List<NewProduct> all) {
    return all.where((p) {
      final matchBranch = _branchFilter == 'All' || p.branch == _branchFilter;
      final matchCategory =
          _categoryFilter == 'All' || p.category == _categoryFilter;
      final matchVendor =
          _vendorFilter == 'All' || p.vendorName == _vendorFilter;
      final matchStock = _stockFilter == 'All' ||
          NewProductService.stockStatus(p) == _stockFilter;
      final q = _search.toLowerCase();
      final matchSearch = q.isEmpty ||
          p.productName.toLowerCase().contains(q) ||
          p.vendorName.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q) ||
          p.productCode.toLowerCase().contains(q);
      return matchBranch &&
          matchCategory &&
          matchVendor &&
          matchStock &&
          matchSearch;
    }).toList();
  }

  // ── Sorting ───────────────────────────────────────────────────────────
  List<NewProduct> _sortList(List<NewProduct> list) {
    final sorted = List<NewProduct>.from(list);
    switch (_sortOption) {
      case NewProductSortOption.dateNewest:
        sorted.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
        break;
      case NewProductSortOption.dateOldest:
        sorted.sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));
        break;
      case NewProductSortOption.nameAZ:
        sorted.sort((a, b) =>
            a.productName.toLowerCase().compareTo(b.productName.toLowerCase()));
        break;
      case NewProductSortOption.none:
        break;
    }
    return sorted;
  }

  // ── DELETE ────────────────────────────────────────────────────────────
  Future<void> _delete(NewProduct product) async {
    final confirmed = await _confirm(
      title: 'Delete Product',
      message:
      'Delete "${product.productName}" from New Products? This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    try {
      await NewProductService.deleteNewProduct(product);
      _snack('${product.productName} deleted', isError: false);
      _loadProducts();
    } catch (e) {
      _snack('Delete failed: $e', isError: true);
    }
  }

  // ── UI helpers ────────────────────────────────────────────────────────
  void _snack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red.shade700 : _accent,
              foregroundColor: Colors.white,
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    final selected = await showModalBottomSheet<NewProductSortOption>(
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
              const Text('Sort By',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              ...NewProductSortOption.values.map((opt) {
                final isSelected = _sortOption == opt;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(opt.icon,
                      color: isSelected ? _accent : Colors.grey.shade500),
                  title: Text(
                    opt.label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? _accent : Colors.black87,
                    ),
                  ),
                  trailing:
                  isSelected ? Icon(Icons.check_rounded, color: _accent) : null,
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

  Future<void> _openMoreFiltersSheet(List<NewProduct> all) async {
    String category = _categoryFilter;
    String vendor = _vendorFilter;
    final categories = _categoryOptions(all);
    final vendors = _vendorOptions(all);

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              padding: EdgeInsets.fromLTRB(18, 14, 18,
                  24 + MediaQuery.of(ctx).viewInsets.bottom),
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
                  const Text('More Filters',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 14),
                  Text('Category',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((c) {
                      final sel = category == c;
                      return ChoiceChip(
                        label: Text(c),
                        selected: sel,
                        selectedColor: _accent,
                        labelStyle: TextStyle(
                            color: sel ? Colors.white : Colors.black87,
                            fontSize: 12),
                        onSelected: (_) => setSheetState(() => category = c),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Text('Vendor',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: vendors.map((v) {
                      final sel = vendor == v;
                      return ChoiceChip(
                        label: Text(v),
                        selected: sel,
                        selectedColor: _accent,
                        labelStyle: TextStyle(
                            color: sel ? Colors.white : Colors.black87,
                            fontSize: 12),
                        onSelected: (_) => setSheetState(() => vendor = v),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setSheetState(() {
                            category = 'All';
                            vendor = 'All';
                          }),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(ctx,
                              {'category': category, 'vendor': vendor}),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _categoryFilter = result['category'] ?? 'All';
        _vendorFilter = result['vendor'] ?? 'All';
      });
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('New Products',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Bulk Import',
            onPressed: () async {
              final imported = await Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'Bulk Import New Products'),
                  builder: (_) => const BulkImportScreen(
                    target: BulkImportTarget.newProducts,
                  ),
                ),
              );
              if (imported == true) _loadProducts();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_loadError != null) return _buildError(_loadError!);
          if (_products == null) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }

          final filtered = _filterList(_products!);
          final sorted = _sortList(filtered);
          final stats = NewProductService.computeStats(_products!);

          return RefreshIndicator(
            onRefresh: _loadProducts,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(stats)),
                SliverToBoxAdapter(child: _buildFilters(sorted.length)),
                if (sorted.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmpty(_products!.isEmpty),
                  )
                else
                  _buildListSliver(sorted),
              ],
            ),
          );
        },
      ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut),
        child: FloatingActionButton.extended(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Add Product',
              style: TextStyle(fontWeight: FontWeight.w600)),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: 'Add New Product'),
                builder: (_) => const AddEditNewProductScreen(),
              ),
            );
            _loadProducts();
          },
        ),
      ),
    );
  }

  // ── DASHBOARD HEADER ──────────────────────────────────────────────────
  Widget _buildHeader(Map<String, int> stats) {
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
          // NOTE: previously a GridView.count(childAspectRatio: 1.5) — that
          // locks card HEIGHT to a ratio of the card's WIDTH, so on wide
          // screens the cards balloon into huge squares. Inventory's stat
          // cards instead size themselves by their content (fixed small
          // padding/icon/text), staying compact no matter the screen
          // width. Two manual Rows below reproduce that same
          // content-sized behaviour so both modules' cards match.
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.inventory_2_rounded,
                  label: 'Total Products',
                  value: '${stats['total']}',
                  color: _accent,
                  selected: _stockFilter == 'All' && _branchFilter == 'All',
                  onTap: () => setState(() {
                    _stockFilter = 'All';
                    _branchFilter = 'All';
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'In Stock',
                  value: '${stats['inStock']}',
                  color: const Color(0xFF2E7D32),
                  selected: _stockFilter == NewProductService.stockIn,
                  onTap: () => _toggleStockFilter(NewProductService.stockIn),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  icon: Icons.warning_amber_rounded,
                  label: 'Low Stock',
                  value: '${stats['lowStock']}',
                  color: const Color(0xFFF9A825),
                  selected: _stockFilter == NewProductService.stockLow,
                  onTap: () => _toggleStockFilter(NewProductService.stockLow),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  icon: Icons.remove_shopping_cart_rounded,
                  label: 'Out of Stock',
                  value: '${stats['outOfStock']}',
                  color: const Color(0xFFC62828),
                  selected: _stockFilter == NewProductService.stockOutOfStock,
                  onTap: () =>
                      _toggleStockFilter(NewProductService.stockOutOfStock),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.apartment_rounded,
                  label: 'CDA Admin',
                  value: '${stats['cdaAdmin']}',
                  color: const Color(0xFF1976D2),
                  selected: _branchFilter == 'CDA Admin',
                  onTap: () => _toggleBranchFilter('CDA Admin'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  icon: Icons.store_rounded,
                  label: 'CDA Ops',
                  value: '${stats['cdaOps']}',
                  color: const Color(0xFF7B5EA7),
                  selected: _branchFilter == 'CDA Ops',
                  onTap: () => _toggleBranchFilter('CDA Ops'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  icon: Icons.calendar_month_rounded,
                  label: 'Added This Month',
                  value: '${stats['addedThisMonth']}',
                  color: const Color(0xFF00ACC1),
                ),
              ),
              const SizedBox(width: 8),
              // Empty spacer keeps this row's cards the same width as the
              // 4-card row above, instead of stretching to fill 3-across.
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search by name, vendor, category, brand, code…',
                hintStyle: TextStyle(color: Colors.white60),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white70),
                border: InputBorder.none,
                contentPadding:
                EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tapping a stock-status card toggles that filter on/off, and clears
  // the other stock filters (a product is only ever one status at once).
  void _toggleStockFilter(String status) {
    setState(() => _stockFilter = _stockFilter == status ? 'All' : status);
  }

  // Tapping a branch card toggles that branch filter on/off, reusing the
  // same _branchFilter the chip row below already uses.
  void _toggleBranchFilter(String branch) {
    setState(() => _branchFilter = _branchFilter == branch ? 'All' : branch);
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    Color color = Colors.white,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    // Content-sized (fixed padding/icon/text, no aspect-ratio or fill
    // constraint) so height stays constant no matter the screen width —
    // matches Inventory dashboard's _statCard sizing.
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: selected
            ? (color == Colors.white ? Colors.white : color).withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? (color == Colors.white ? Colors.white : color)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color == Colors.white ? Colors.white70 : color, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: card,
    );
  }

  // ── FILTERS ───────────────────────────────────────────────────────────
  Widget _buildFilters(int resultCount) {
    final sortActive = _sortOption != NewProductSortOption.none;
    final moreActive = _categoryFilter != 'All' || _vendorFilter != 'All';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Branch:',
                  style:
                  TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _branches.map((b) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(b),
                        selected: _branchFilter == b,
                        selectedColor: _accent,
                        backgroundColor: _accent.withOpacity(0.10),
                        side: BorderSide(
                          color: _branchFilter == b ? _accent : _accent.withOpacity(0.35),
                        ),
                        labelStyle: TextStyle(
                          color: _branchFilter == b ? Colors.white : _accent,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setState(() => _branchFilter = b),
                      ),
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _openMoreFiltersSheet(_products ?? []),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: moreActive
                        ? _accent.withOpacity(0.12)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: moreActive ? _accent : Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_list_rounded,
                          size: 16,
                          color: moreActive ? _accent : Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: moreActive ? _accent : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _openSortSheet,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sortActive
                        ? _accent.withOpacity(0.12)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sortActive ? _accent : Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_sortOption.icon,
                          size: 16,
                          color: sortActive ? _accent : Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        sortActive ? _sortOption.label : 'Sort',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sortActive ? _accent : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (_stockFilter != 'All')
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _activeFilterChip(
                    _stockFilter,
                    onClear: () => setState(() => _stockFilter = 'All'),
                  ),
                ),
              const Spacer(),
              Text('$resultCount result${resultCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: Colors.black38, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activeFilterChip(String label, {required VoidCallback onClear}) {
    return InkWell(
      onTap: onClear,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: _accent)),
            const SizedBox(width: 4),
            Icon(Icons.close_rounded, size: 13, color: _accent),
          ],
        ),
      ),
    );
  }

  // ── LIST ──────────────────────────────────────────────────────────────
  Widget _buildListSliver(List<NewProduct> products) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (ctx, i) => _NewProductCard(
            product: products[i],
            stockStatus: NewProductService.stockStatus(products[i]),
            statusColor: _stockColor(NewProductService.stockStatus(products[i])),
            onView: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'New Product Detail'),
                  builder: (_) => NewProductDetailScreen(product: products[i]),
                ),
              );
              _loadProducts();
            },
            onEdit: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'Edit New Product'),
                  builder: (_) =>
                      AddEditNewProductScreen(existing: products[i]),
                ),
              );
              _loadProducts();
            },
            onDelete: () => _delete(products[i]),
          ),
          childCount: products.length,
        ),
      ),
    );
  }

  // ── EMPTY / ERROR ─────────────────────────────────────────────────────
  Widget _buildEmpty(bool collectionIsEmpty) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.new_releases_outlined, size: 72, color: Colors.blue.shade100),
          const SizedBox(height: 16),
          Text(
            collectionIsEmpty ? 'No new products yet' : 'No matching products',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black45),
          ),
          const SizedBox(height: 6),
          Text(
            collectionIsEmpty
                ? 'Tap "Add Product" below to add your first new product.'
                : 'Try a different search, branch, status or filter.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
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
            Icon(Icons.cloud_off_rounded, size: 64, color: Colors.red.shade200),
            const SizedBox(height: 16),
            const Text('Could not reach Firestore',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _loadError = null);
                _loadProducts();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  static Color _stockColor(String status) {
    switch (status) {
      case NewProductService.stockOutOfStock:
        return const Color(0xFFC62828);
      case NewProductService.stockLow:
        return const Color(0xFFF9A825);
      default:
        return const Color(0xFF2E7D32); // In Stock
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  NEW PRODUCT CARD
// ═══════════════════════════════════════════════════════════════════════════

class _NewProductCard extends StatelessWidget {
  const _NewProductCard({
    required this.product,
    required this.statusColor,
    required this.stockStatus,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final NewProduct product;
  final Color statusColor;
  final String stockStatus;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const Color _navy = Color(0xFF0D2B6E);

  static Color _stockColor(String status) {
    switch (status) {
      case 'Out of Stock':
        return const Color(0xFFC62828);
      case 'Low Stock':
        return const Color(0xFFF9A825);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onView,
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
                                product.productName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusChip(status: stockStatus, color: statusColor),
                          ],
                        ),
                        if (product.productCode.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(product.productCode,
                              style: TextStyle(
                                  fontSize: 11.5, color: Colors.grey.shade500)),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 16,
                          runSpacing: 6,
                          children: [
                            _InfoPill(
                                icon: Icons.business_rounded, text: product.branch),
                            _InfoPill(
                                icon: Icons.storefront_rounded,
                                text: product.vendorName.isEmpty
                                    ? 'No vendor'
                                    : product.vendorName),
                            _InfoPill(
                                icon: Icons.layers_rounded,
                                text: 'Qty: ${product.quantity}',
                                highlight: true,
                                highlightColor: _stockColor(stockStatus)),
                            _InfoPill(
                                icon: Icons.category_rounded, text: product.category),
                            if (product.salePrice > 0)
                              _InfoPill(
                                  icon: Icons.sell_rounded,
                                  text:
                                  '₹${product.salePrice.toStringAsFixed(2)}'),
                            _InfoPill(
                                icon: Icons.calendar_today_rounded,
                                text: _formatDate(product.purchaseDate)),
                          ],
                        ),
                        const Divider(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _ActionButton(
                              label: 'View',
                              icon: Icons.visibility_outlined,
                              color: Colors.grey.shade700,
                              onTap: onView,
                            ),
                            const SizedBox(width: 8),
                            _ActionButton(
                              label: 'Edit',
                              icon: Icons.edit_rounded,
                              color: _navy,
                              onTap: onEdit,
                            ),
                            const SizedBox(width: 8),
                            _ActionButton(
                              label: 'Delete',
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
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.color});
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
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.text,
    this.highlight = false,
    this.highlightColor = const Color(0xFF1976D2),
  });
  final IconData icon;
  final String text;
  final bool highlight;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? highlightColor : Colors.grey.shade500;
    final textColor = highlight ? highlightColor : Colors.grey.shade700;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                style:
                TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}