import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cda_inventory/models/stock.dart';
import 'package:cda_inventory/services/stock_service.dart';
import 'stock_item_detail_screen.dart';
import 'stock_adjust_screen.dart';
import 'stock_transfer_screen.dart';
import 'add_stock_item_screen.dart';

class StockItemsScreen extends StatefulWidget {
  const StockItemsScreen({super.key});

  @override
  State<StockItemsScreen> createState() => _StockItemsScreenState();
}

class _StockItemsScreenState extends State<StockItemsScreen> {
  List<StockItem> _allItems = [];
  List<StockItem> _filtered = [];
  bool    _loading = true;
  String? _error;

  final _searchController = TextEditingController();

  String _filterBranch   = 'All';
  String _filterCategory = 'All';
  String _sortBy         = 'name'; // name | qty_asc | qty_desc | low_stock

  static const List<String> _branches   = ['All', 'Branch 1', 'Branch 2'];
  static const List<String> _categories = ['All', 'consumable', 'fixed_asset'];
  static const List<Map<String, String>> _sortOptions = [
    {'key': 'name',      'label': 'Name'},
    {'key': 'qty_asc',   'label': 'Qty ↑'},
    {'key': 'qty_desc',  'label': 'Qty ↓'},
    {'key': 'low_stock', 'label': 'Low Stock'},
  ];

  static const Color kNavy  = Color(0xFF0A1628);
  static const Color kTeal  = Color(0xFF00D4AA);
  static const Color kCoral = Color(0xFFFF6B6B);
  static const Color kAmber = Color(0xFFFFB800);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() { _loading = true; _error = null; });
    try {
      // Always pull the full item list — branch/category are applied
      // locally in _applyFilter() so switching a filter chip never
      // triggers a new Firestore query. forceRefresh (pull-to-refresh)
      // bypasses StockService's in-memory cache; everything else reuses it.
      final items = await StockService.fetchItems(forceRefresh: forceRefresh);
      setState(() { _allItems = items; _loading = false; });
      _applyFilter();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    List<StockItem> list = _allItems.where((item) {
      if (_filterBranch   != 'All' && item.branch   != _filterBranch)   return false;
      if (_filterCategory != 'All' && item.category != _filterCategory) return false;
      if (q.isEmpty) return true;
      return item.productName.toLowerCase().contains(q)
          || item.branch.toLowerCase().contains(q)
          || (item.sku ?? '').toLowerCase().contains(q);
    }).toList();

    switch (_sortBy) {
      case 'qty_asc':
        list.sort((a, b) => a.quantity.compareTo(b.quantity));
        break;
      case 'qty_desc':
        list.sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
      case 'low_stock':
        list.sort((a, b) => a.quantity.compareTo(b.quantity));
        break;
      default:
        list.sort((a, b) => a.productName.compareTo(b.productName));
    }
    setState(() => _filtered = list);
  }

  void _navigateToAddItem() async {
    final result = await Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'Add Stock Item'), builder: (_) => const AddStockItemScreen()));
    if (result == true) _load();
  }

  void _navigateToDetail(StockItem item) async {
    final result = await Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'Stock Item Detail'), builder: (_) => StockItemDetailScreen(item: item)));
    if (result == true) _load();
  }

  void _showItemMenu(StockItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                Expanded(
                  child: Text(item.productName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kNavy),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.visibility_rounded, color: kNavy),
              title: const Text('View Details'),
              onTap: () { Navigator.pop(ctx); _navigateToDetail(item); },
            ),
            ListTile(
              leading: const Icon(Icons.tune_rounded, color: kAmber),
              title: const Text('Adjust Stock'),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'Stock Adjust'), builder: (_) => StockAdjustScreen(item: item)));
                if (result == true) _load();
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF6C63FF)),
              title: const Text('Transfer Stock'),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: 'Stock Transfer'), builder: (_) => StockTransferScreen(item: item)));
                if (result == true) _load();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: kCoral),
              title: const Text('Delete Item'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(item);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(StockItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.delete_outline_rounded, color: kCoral),
          SizedBox(width: 8),
          Text('Delete Item', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        content: Text('Delete "${item.productName}" from ${item.branch}?',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kCoral, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await StockService.deleteItem(item.id!);
                _load();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Delete failed: ${e.toString()}'), backgroundColor: kCoral),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    if (_filtered.isEmpty) return;
    final buffer = StringBuffer();
    buffer.writeln('Product,SKU,Branch,Category,Quantity,Unit,Min Stock,Location');
    for (final i in _filtered) {
      buffer.writeln('${i.productName},${i.sku ?? ''},${i.branch},${i.category},${i.quantity},${i.unit},${i.minStock},${i.location ?? ''}');
    }
    await Share.share(buffer.toString(), subject: 'Stock Items Export (${_filtered.length})');
  }

  Future<void> _exportPdf() async {
    if (_filtered.isEmpty) return;
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: 'Stock Items Report'),
          pw.Table.fromTextArray(
            headers: ['Product', 'Branch', 'Category', 'Qty', 'Unit', 'Min'],
            data: _filtered
                .map((i) => [i.productName, i.branch, i.category, i.quantity.toString(), i.unit, i.minStock.toString()])
                .toList(),
          ),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'stock_items_report.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: const Text('All Stock Items',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export',
            onSelected: (v) {
              if (v == 'csv') _exportCsv();
              if (v == 'pdf') _exportPdf();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'csv', child: Text('Export as CSV')),
              PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
            ],
          ),
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // ── Controls ────────────────────────────────────────────────
          Container(
            color: kNavy,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Column(children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search items, SKU…',
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Colors.white.withOpacity(0.6), size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  ..._branches.map((b) => _chip(
                      b == 'All' ? 'All Branches' : b,
                      b == _filterBranch, () {
                    setState(() => _filterBranch = b);
                    _applyFilter();
                  })),
                  const SizedBox(width: 8),
                  Container(
                      width: 1,
                      height: 20,
                      color: Colors.white24),
                  const SizedBox(width: 8),
                  ..._categories.map((c) {
                    final label = c == 'All'
                        ? 'All'
                        : c == 'consumable'
                        ? 'Consumable'
                        : 'Fixed Asset';
                    return _chip(label, c == _filterCategory, () {
                      setState(() => _filterCategory = c);
                      _applyFilter();
                    },
                        color: c == 'consumable'
                            ? kCoral
                            : c == 'fixed_asset'
                            ? const Color(0xFF6C63FF)
                            : kTeal);
                  }),
                ]),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  Text('Sort: ',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12)),
                  ..._sortOptions.map((s) => _chip(
                      s['label']!, s['key'] == _sortBy, () {
                    setState(() => _sortBy = s['key']!);
                    _applyFilter();
                  }, color: kAmber)),
                ]),
              ),
            ]),
          ),

          // ── Stats bar ────────────────────────────────────────────────
          if (!_loading && _error == null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Row(children: [
                _statBadge('${_filtered.length} Items',
                    Colors.grey.shade600),
                const SizedBox(width: 8),
                _statBadge(
                    '${_filtered.where((i) => i.isLowStock).length} Low Stock',
                    kCoral),
                const Spacer(),
                Text(
                    'Total qty: ${_filtered.fold<int>(0, (s, i) => s + i.quantity)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600)),
              ]),
            ),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                child: CircularProgressIndicator(color: kTeal))
                : _error != null
                ? _buildError()
                : _filtered.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
              onRefresh: () => _load(forceRefresh: true),
              color: kTeal,
              child: ListView.builder(
                padding:
                const EdgeInsets.fromLTRB(12, 8, 12, 90),
                itemCount: _filtered.length,
                itemBuilder: (_, i) =>
                    _buildItemCard(_filtered[i]),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kTeal,
        foregroundColor: Colors.white,
        onPressed: _navigateToAddItem,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap,
      {Color color = const Color(0xFF00D4AA)}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? color
                : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight:
                selected ? FontWeight.w700 : FontWeight.w400,
              )),
        ),
      ),
    );
  }

  Widget _statBadge(String label, Color color) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }

  Widget _buildItemCard(StockItem item) {
    final isLow    = item.isLowStock;
    final catColor = item.category == 'fixed_asset'
        ? const Color(0xFF6C63FF)
        : kCoral;
    final catLabel = item.category == 'fixed_asset'
        ? 'Fixed Asset'
        : 'Consumable';
    final catIcon  = item.category == 'fixed_asset'
        ? Icons.business_center_rounded
        : Icons.category_rounded;

    final pct = item.minStock > 0
        ? (item.quantity / item.minStock).clamp(0.0, 1.0)
        : 1.0;
    final barColor = pct < 0.3
        ? kCoral
        : pct < 0.7
        ? kAmber
        : kTeal;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isLow
            ? Border.all(color: kCoral.withOpacity(0.3))
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToDetail(item),
        onLongPress: () => _showItemMenu(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(catIcon, color: catColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.productName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: kNavy),
                          overflow: TextOverflow.ellipsis),
                      Row(children: [
                        Icon(Icons.store_rounded,
                            size: 11, color: Colors.grey.shade400),
                        const SizedBox(width: 3),
                        Text(item.branch,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(catLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: catColor,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ]),
                      if (item.sku != null && item.sku!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('SKU: ${item.sku}',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${item.quantity}',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isLow ? kCoral : kNavy)),
                    Text(item.unit,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400)),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade400, size: 20),
                  onPressed: () => _showItemMenu(item),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Stock level',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500)),
                          Text('Min: ${item.minStock}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.grey.shade100,
                          valueColor:
                          AlwaysStoppedAnimation(barColor),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLow) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kCoral.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 12, color: kCoral),
                      SizedBox(width: 3),
                      Text('Low',
                          style: TextStyle(
                              fontSize: 11,
                              color: kCoral,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 54, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Failed to load items',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(
              backgroundColor: kNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No items found',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text('Try a different filter or add a new item.',
              style: TextStyle(
                  color: Colors.grey.shade400, fontSize: 13)),
        ],
      ),
    );
  }
}