// lib/screens/stock/stock_item_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cda_inventory/models/stock.dart';
import 'package:cda_inventory/services/stock_service.dart';
import 'stock_in_screen.dart';
import 'stock_out_screen.dart';
import 'stock_adjust_screen.dart';
import 'stock_transfer_screen.dart';

class StockItemDetailScreen extends StatefulWidget {
  final StockItem item;

  const StockItemDetailScreen({super.key, required this.item});

  @override
  State<StockItemDetailScreen> createState() => _StockItemDetailScreenState();
}

class _StockItemDetailScreenState extends State<StockItemDetailScreen> {
  late StockItem _item;
  List<StockTransaction> _history = [];
  bool _loadingHistory = true;
  bool _changed = false; // tells the caller a reload is needed on pop

  static const Color kNavy   = Color(0xFF0A1628);
  static const Color kTeal   = Color(0xFF00D4AA);
  static const Color kCoral  = Color(0xFFFF6B6B);
  static const Color kAmber  = Color(0xFFFFB800);
  static const Color kPurple = Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final h = await StockService.fetchTransactionsForItem(_item.productName, _item.branch);
      if (mounted) setState(() { _history = h; _loadingHistory = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _refreshItem() async {
    if (_item.id == null) return;
    final fresh = await StockService.fetchItemById(_item.id!);
    if (fresh != null && mounted) {
      setState(() { _item = fresh; _changed = true; });
    }
    _loadHistory();
  }

  Future<void> _goTo(Widget screen) async {
    final name = screen.runtimeType
        .toString()
        .replaceAll('Screen', '')
        .replaceAllMapped(RegExp(r'(?<!^)(?=[A-Z])'), (m) => ' ');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(settings: RouteSettings(name: name), builder: (_) => screen),
    );
    if (result == true) await _refreshItem();
  }

  void _showEditSheet() {
    final minStockController = TextEditingController(text: _item.minStock.toString());
    final skuController      = TextEditingController(text: _item.sku ?? '');
    final locationController = TextEditingController(text: _item.location ?? '');
    String category = _item.category;
    String unit      = _item.unit;
    const units = ['pcs', 'box', 'kg', 'litre', 'set', 'pack'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Edit Item Details', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kNavy)),
                  const SizedBox(height: 4),
                  Text('${_item.productName} · ${_item.branch}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 18),
                  Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Row(children: ['consumable', 'fixed_asset'].map((c) {
                    final selected = category == c;
                    final label = c == 'consumable' ? 'Consumable' : 'Fixed Asset';
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setSheetState(() => category = c),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? kNavy : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: selected ? Colors.white : Colors.grey.shade700)),
                          ),
                        ),
                      ),
                    );
                  }).toList()),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: minStockController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Minimum Stock',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: unit,
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                        onChanged: (v) => setSheetState(() => unit = v ?? unit),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: skuController,
                    decoration: InputDecoration(
                      labelText: 'SKU / Code (optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: InputDecoration(
                      labelText: 'Shelf / Location (optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kNavy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final minStock = int.tryParse(minStockController.text.trim());
                        if (minStock == null || minStock < 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Enter a valid minimum stock'), backgroundColor: kCoral),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        try {
                          await StockService.updateItemDetails(
                            id: _item.id!,
                            category: category,
                            minStock: minStock,
                            sku: skuController.text.trim(),
                            unit: unit,
                            location: locationController.text.trim(),
                          );
                          await _refreshItem();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Item updated'), backgroundColor: Color(0xFF00B894)),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Update failed: ${e.toString()}'), backgroundColor: kCoral),
                            );
                          }
                        }
                      },
                      child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.delete_outline_rounded, color: kCoral),
          SizedBox(width: 8),
          Text('Delete Item', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        content: Text(
          'Delete "${_item.productName}" from ${_item.branch}? This removes it from the catalog but keeps its transaction history.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kCoral, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await StockService.deleteItem(_item.id!);
                if (mounted) Navigator.pop(context, true);
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

  @override
  Widget build(BuildContext context) {
    final isLow = _item.isLowStock;
    final catColor = _item.category == 'fixed_asset' ? kPurple : kCoral;
    final catLabel = _item.category == 'fixed_asset' ? 'Fixed Asset' : 'Consumable';

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _changed);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          backgroundColor: kNavy,
          foregroundColor: Colors.white,
          title: const Text('Item Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () => Navigator.pop(context, _changed),
          ),
          actions: [
            IconButton(icon: const Icon(Icons.edit_rounded), tooltip: 'Edit', onPressed: _showEditSheet),
            IconButton(icon: const Icon(Icons.delete_rounded), tooltip: 'Delete', onPressed: _confirmDelete),
          ],
        ),
        body: RefreshIndicator(
          color: kTeal,
          onRefresh: _refreshItem,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header card ──────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(color: catColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                          child: Icon(
                            _item.category == 'fixed_asset' ? Icons.business_center_rounded : Icons.category_rounded,
                            color: catColor, size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_item.productName,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: kNavy)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Icon(Icons.store_rounded, size: 13, color: Colors.grey.shade400),
                                const SizedBox(width: 4),
                                Text(_item.branch, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: catColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Text(catLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: catColor)),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 18),
                      if (_item.sku != null && _item.sku!.isNotEmpty || _item.location != null && _item.location!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Wrap(spacing: 10, runSpacing: 8, children: [
                            if (_item.sku != null && _item.sku!.isNotEmpty)
                              _metaChip(Icons.qr_code_rounded, 'SKU: ${_item.sku}'),
                            if (_item.location != null && _item.location!.isNotEmpty)
                              _metaChip(Icons.place_outlined, _item.location!),
                          ]),
                        ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Row(children: [
                                Text('${_item.quantity}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: isLow ? kCoral : kNavy)),
                                const SizedBox(width: 4),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(_item.unit, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                                ),
                              ]),
                              if (isLow)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: kCoral.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.warning_amber_rounded, size: 13, color: kCoral),
                                    SizedBox(width: 4),
                                    Text('Low Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kCoral)),
                                  ]),
                                ),
                            ]),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _item.minStock > 0 ? (_item.quantity / _item.minStock).clamp(0.0, 1.0) : 1.0,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation(isLow ? kCoral : kTeal),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Minimum stock: ${_item.minStock} ${_item.unit}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                _sectionLabel('QUICK ACTIONS'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _quickAction('Stock IN', Icons.arrow_downward_rounded, const Color(0xFF00B894),
                          () => _goTo(StockInScreen(
                          initialProductName: _item.productName,
                          initialBranch: _item.branch,
                          initialCategory: _item.category)))),
                  const SizedBox(width: 10),
                  Expanded(child: _quickAction('Stock OUT', Icons.arrow_upward_rounded, kCoral,
                          () => _goTo(StockOutScreen(initialProductName: _item.productName, initialBranch: _item.branch)))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _quickAction('Adjust', Icons.tune_rounded, kAmber,
                          () => _goTo(StockAdjustScreen(item: _item)))),
                  const SizedBox(width: 10),
                  Expanded(child: _quickAction('Transfer', Icons.swap_horiz_rounded, kPurple,
                          () => _goTo(StockTransferScreen(item: _item)))),
                ]),

                const SizedBox(height: 24),
                _sectionLabel('TRANSACTION HISTORY'),
                const SizedBox(height: 10),
                _buildHistory(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 1.4));

  Widget _quickAction(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNavy)),
        ]),
      ),
    );
  }

  Widget _buildHistory() {
    if (_loadingHistory) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator(color: kTeal)),
      );
    }
    if (_history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Center(
          child: Column(children: [
            Icon(Icons.history_toggle_off_rounded, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('No transactions yet', style: TextStyle(color: Colors.grey.shade400)),
          ]),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          for (int i = 0; i < _history.length; i++) ...[
            _historyRow(_history[i]),
            if (i < _history.length - 1) Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey.shade100),
          ],
        ],
      ),
    );
  }

  Widget _historyRow(StockTransaction t) {
    Color color;
    IconData icon;
    if (t.isInbound) {
      color = const Color(0xFF00B894);
      icon = Icons.arrow_downward_rounded;
    } else if (t.isOutbound) {
      color = kCoral;
      icon = Icons.arrow_upward_rounded;
    } else {
      color = kAmber;
      icon = Icons.tune_rounded;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${t.type}  •  ${t.quantity} ${_item.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kNavy)),
              Text('${t.date} · ${t.time}  •  ${t.person}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              if (t.departmentOrPurpose.isNotEmpty)
                Text(t.departmentOrPurpose, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }
}