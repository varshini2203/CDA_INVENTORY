// lib/screens/products/search_products_screen.dart
//
// Search Products screen — two search modes on one page:
//   • Row Search  — filter chips for every distinct `row` value, plus a
//     text box that narrows further by product name or row text.
//   • Tray Search — same idea, but chips are every distinct `tray` value.
//
// Chip values and product row/rack/tray fields are both normalized
// (trim + collapse internal whitespace + lowercase) before being
// compared, so a chip always matches every product that belongs to it
// regardless of stray spacing or casing differences in the source data.
// Chip-to-product matching uses exact equality on the normalized value
// (never `contains`), so a chip only ever shows products truly in that
// row/tray. The free-text search box is unaffected and still does a
// substring match, so it can be used together with a selected chip to
// narrow further.

import 'package:flutter/material.dart';

import 'package:cda_inventory/models/product.dart';
import 'package:cda_inventory/data/seed_branch1_products.dart';

class SearchProductsScreen extends StatefulWidget {
  final List<Product>? products;
  final String title;

  const SearchProductsScreen({
    super.key,
    this.products,
    this.title = 'Search Products',
  });

  @override
  State<SearchProductsScreen> createState() => _SearchProductsScreenState();
}

class _SearchProductsScreenState extends State<SearchProductsScreen>
    with SingleTickerProviderStateMixin {
  // ── Design tokens (matches Branch Inventory / Invoices theme) ──────────
  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kCoral = Color(0xFFFF6B6B);
  static const Color kAmber = Color(0xFFFFB800);
  static const Color kSurface = Color(0xFFF0F4F8);
  static const Color kGreen = Color(0xFF00B894);
  static const Color kPurple = Color(0xFF6C63FF);

  late final TabController _tabController;
  late final List<Product> _allProducts;

  final TextEditingController _rowSearchController = TextEditingController();
  final TextEditingController _traySearchController = TextEditingController();
  String _rowQuery = '';
  String _trayQuery = '';

  // Both hold the NORMALIZED chip value. null = "All" selected.
  String? _selectedRowNorm;
  String? _selectedTrayNorm;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _allProducts = widget.products ?? _productsFromBranch1Seed();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rowSearchController.dispose();
    _traySearchController.dispose();
    super.dispose();
  }

  static List<Product> _productsFromBranch1Seed() {
    final items = SeedBranch1Products.allItems;
    return List<Product>.generate(items.length, (i) {
      final m = items[i];
      return Product(
        id: 'branch1_seed_$i',
        name: m['name'] as String? ?? '',
        category: m['category'] as String? ?? '',
        quantity: (m['quantity'] as num?)?.toInt() ?? 0,
        price: 0.0,
        notes: m['notes'] as String?,
        row: m['row'] as String?,
        rack: m['rack'] as String?,
        tray: m['tray'] as String?,
      );
    });
  }

  // ── Normalization ────────────────────────────────────────────────────
  // Null-safe: trims leading/trailing whitespace, collapses any run of
  // internal whitespace to a single space, and lowercases the result.
  // This is the ONLY function used to decide whether a chip matches a
  // product, and the only function used to decide whether two raw
  // values collapse into the same chip.
  static String _normalize(String? value) {
    if (value == null) return '';
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  /// Builds the chip list for a dimension (row or tray).
  /// Returns pairs of (displayLabel, normalizedKey), deduplicated by
  /// normalizedKey, sorted numerically-then-alphabetically by the
  /// display label.
  static List<_ChipValue> _distinctChipValues(Iterable<String?> rawValues) {
    final byKey = <String, String>{}; // normalizedKey -> first display label seen
    for (final raw in rawValues) {
      final display = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
      if (display.isEmpty) continue;
      final key = _normalize(raw);
      byKey.putIfAbsent(key, () => display);
    }
    final entries = byKey.entries.map((e) => _ChipValue(label: e.value, key: e.key)).toList();
    entries.sort((a, b) {
      final na = RegExp(r'\d+').firstMatch(a.label);
      final nb = RegExp(r'\d+').firstMatch(b.label);
      if (na != null && nb != null) {
        final byNum = int.parse(na.group(0)!).compareTo(int.parse(nb.group(0)!));
        if (byNum != 0) return byNum;
      }
      return a.label.compareTo(b.label);
    });
    return entries;
  }

  List<_ChipValue> get _rowChips => _distinctChipValues(_allProducts.map((p) => p.row));
  List<_ChipValue> get _trayChips => _distinctChipValues(_allProducts.map((p) => p.tray));

  // ── Filtering ────────────────────────────────────────────────────────
  // Chip match: exact equality on normalized values only (no `contains`).
  // Text match: still a substring/contains match, and applies on top of
  // (i.e. together with) whatever chip is currently selected.
  List<Product> get _rowResults {
    return _allProducts.where((p) {
      if (_selectedRowNorm != null && _normalize(p.row) != _selectedRowNorm) {
        return false;
      }
      if (_rowQuery.trim().isEmpty) return true;
      final q = _rowQuery.trim().toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          (p.row ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<Product> get _trayResults {
    return _allProducts.where((p) {
      if (_selectedTrayNorm != null && _normalize(p.tray) != _selectedTrayNorm) {
        return false;
      }
      if (_trayQuery.trim().isEmpty) return true;
      final q = _trayQuery.trim().toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          (p.tray ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kTeal,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.view_agenda_outlined), text: 'Row Search'),
            Tab(icon: Icon(Icons.inbox_outlined), text: 'Tray Search'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SearchPane(
            chips: _rowChips,
            selectedKey: _selectedRowNorm,
            onChipSelected: (key) => setState(() => _selectedRowNorm = key),
            searchController: _rowSearchController,
            onQueryChanged: (v) => setState(() => _rowQuery = v),
            results: _rowResults,
            chipColor: kTeal,
            hintText: 'Search by row or product name…',
            emptyLabel: 'No products found in this row.',
          ),
          _SearchPane(
            chips: _trayChips,
            selectedKey: _selectedTrayNorm,
            onChipSelected: (key) => setState(() => _selectedTrayNorm = key),
            searchController: _traySearchController,
            onQueryChanged: (v) => setState(() => _trayQuery = v),
            results: _trayResults,
            chipColor: kPurple,
            hintText: 'Search by tray or product name…',
            emptyLabel: 'No products found in this tray.',
          ),
        ],
      ),
    );
  }
}

/// A chip's display label paired with its normalized comparison key.
class _ChipValue {
  final String label;
  final String key;
  const _ChipValue({required this.label, required this.key});
}

class _SearchPane extends StatelessWidget {
  final List<_ChipValue> chips;
  final String? selectedKey;
  final ValueChanged<String?> onChipSelected;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final List<Product> results;
  final Color chipColor;
  final String hintText;
  final String emptyLabel;

  const _SearchPane({
    required this.chips,
    required this.selectedKey,
    required this.onChipSelected,
    required this.searchController,
    required this.onQueryChanged,
    required this.results,
    required this.chipColor,
    required this.hintText,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: searchController,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chips.length + 1, // +1 for "All"
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final isAll = i == 0;
              final label = isAll ? 'All' : chips[i - 1].label;
              final key = isAll ? null : chips[i - 1].key;
              final selected = isAll ? selectedKey == null : selectedKey == key;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => onChipSelected(key),
                selectedColor: chipColor,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: chipColor.withOpacity(0.4)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${results.length} item${results.length == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: results.isEmpty
              ? Center(
            child: Text(
              emptyLabel,
              style: const TextStyle(color: Colors.black45),
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: results.length,
            itemBuilder: (context, i) => _ProductTile(
              product: results[i],
              highlightColor: chipColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final Color highlightColor;

  const _ProductTile({required this.product, required this.highlightColor});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if ((product.row ?? '').trim().isNotEmpty) product.row!.trim(),
      if ((product.rack ?? '').trim().isNotEmpty) product.rack!.trim(),
      if ((product.tray ?? '').trim().isNotEmpty) product.tray!.trim(),
    ];
    final location = parts.join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.category,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: highlightColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        location,
                        style: TextStyle(
                          color: highlightColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if ((product.notes ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.notes!,
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'x${product.quantity}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}