import 'package:flutter/material.dart';
import 'package:cda_inventory/models/purchase_order.dart';
import 'package:cda_inventory/services/purchase_order_service.dart';
import 'package:cda_inventory/shared/inventory_ui.dart';
import 'add_purchase_order_screen.dart';

class PurchaseOrderListScreen extends StatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  State<PurchaseOrderListScreen> createState() => _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState extends State<PurchaseOrderListScreen> {
  List<PurchaseOrder> _all = [];
  List<PurchaseOrder> _filtered = [];
  bool _isLoading = true;
  String? _error;
  String _search = '';
  String _branchFilter = 'All';

  static const statusColors = {
    'Pending': AppColors.amber,
    'Received': AppColors.green,
    'Cancelled': AppColors.coral,
  };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await PurchaseOrderService.getAllPurchaseOrders();
      if (!mounted) return;
      setState(() {
        _all = data;
        _isLoading = false;
        _applyFilter();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _applyFilter() {
    _filtered = _all.where((p) {
      final q = _search.toLowerCase();
      final matchSearch = q.isEmpty ||
          p.productName.toLowerCase().contains(q) ||
          p.vendorName.toLowerCase().contains(q);
      final matchBranch = _branchFilter == 'All' || p.branch == _branchFilter;
      return matchSearch && matchBranch;
    }).toList();
  }

  Future<void> _updateStatus(PurchaseOrder p, String status) async {
    final result = await PurchaseOrderService.updateStatus(p.id!, status);
    if (result['success'] == true) {
      setState(() {
        final idx = _all.indexWhere((o) => o.id == p.id);
        if (idx != -1) _all[idx] = p.copyWith(status: status);
        _applyFilter();
      });
      if (mounted) showAppSnack(context, 'Status updated to $status');
    } else if (mounted) {
      showAppSnack(context, result['message'] ?? 'Update failed', isError: true);
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showConfirmDeleteDialog(
      context,
      title: 'Delete Purchase Order',
      message: 'Are you sure you want to delete this purchase order?',
    );
    if (!confirm) return;
    final result = await PurchaseOrderService.deletePurchaseOrder(id);
    if (result['success'] == true) {
      setState(() {
        _all.removeWhere((p) => p.id == id);
        _applyFilter();
      });
      if (mounted) showAppSnack(context, 'Purchase order deleted successfully');
    } else if (mounted) {
      showAppSnack(context, result['message'] ?? 'Delete failed', isError: true);
    }
  }

  double get _totalValue =>
      _filtered.fold(0.0, (sum, p) => sum + (p.expectedCost * p.quantity));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Purchase Order',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetch),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.navy,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              children: [
                const HeroBanner(
                  icon: Icons.assignment_rounded,
                  title: 'Purchase Orders',
                  subtitle: 'Track orders placed with vendors',
                ),
                const SizedBox(height: 14),
                Row(children: [
                  StatChip(icon: Icons.list_alt_rounded, label: 'Orders', value: '${_filtered.length}'),
                  const SizedBox(width: 12),
                  StatChip(
                      icon: Icons.currency_rupee_rounded,
                      label: 'Expected Value',
                      value: '₹${_totalValue.toStringAsFixed(0)}'),
                ]),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: TextField(
                    style: const TextStyle(
                        color: AppColors.navy, fontWeight: FontWeight.w500, fontSize: 14),
                    onChanged: (v) => setState(() {
                      _search = v;
                      _applyFilter();
                    }),
                    decoration: InputDecoration(
                      hintText: 'Search product, vendor...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.teal),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                          onPressed: () => setState(() {
                            _search = '';
                            _applyFilter();
                          }))
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: kBranchFilters.map((b) {
                      final sel = _branchFilter == b;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _branchFilter = b;
                            _applyFilter();
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.teal : Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: sel ? AppColors.teal : Colors.white.withOpacity(0.3)),
                            ),
                            child: Text(kBranchLabels[b] ?? b,
                                style: TextStyle(
                                    color: sel ? AppColors.navy : Colors.white,
                                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
                : _error != null
                ? _buildErrorState()
                : _filtered.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _fetch,
              color: AppColors.teal,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                itemCount: _filtered.length,
                itemBuilder: (ctx, i) => _buildCard(_filtered[i], i),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Order', style: TextStyle(fontWeight: FontWeight.w600)),
        onPressed: () async {
          final result = await Navigator.push<bool>(
              context, MaterialPageRoute(settings: const RouteSettings(name: 'Add Purchase Order'), builder: (_) => const AddPurchaseOrderScreen()));
          if (result == true) _fetch();
        },
      ),
    );
  }

  Widget _buildErrorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            padding: const EdgeInsets.all(20),
            decoration:
            BoxDecoration(color: AppColors.coral.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.cloud_off_rounded, size: 52, color: AppColors.coral)),
        const SizedBox(height: 20),
        const Text('Failed to Load',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 10),
        Text(_error ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _fetch,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ]),
    ),
  );

  Widget _buildEmptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
          padding: const EdgeInsets.all(24),
          decoration:
          BoxDecoration(color: AppColors.teal.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.assignment_outlined, size: 60, color: AppColors.teal)),
      const SizedBox(height: 20),
      const Text('No purchase orders found',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
      const SizedBox(height: 8),
      Text(
        _search.isNotEmpty ? 'Try adjusting your search' : 'Tap + to create your first order',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      ),
    ]),
  );

  Widget _buildCard(PurchaseOrder p, int index) {
    const accents = [AppColors.navy, AppColors.teal, AppColors.green, AppColors.amber];
    final accent = accents[index % accents.length];
    final total = p.expectedCost * p.quantity;
    final statusColor = statusColors[p.status] ?? AppColors.amber;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration:
              BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.assignment_rounded, color: accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.productName,
                      style:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
                  const SizedBox(height: 2),
                  Text(p.vendorName, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${total.toStringAsFixed(0)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: accent)),
                Text('Total', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
              ],
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(children: [
            Row(children: [
              InfoChip(Icons.format_list_numbered_rounded, 'Qty: ${p.quantity}'),
              const SizedBox(width: 8),
              InfoChip(Icons.location_city_rounded, kBranchLabels[p.branch] ?? p.branch),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              InfoChip(Icons.calendar_today_rounded, p.orderDate),
              const SizedBox(width: 8),
              Expanded(
                child: PopupMenuButton<String>(
                  onSelected: (v) => _updateStatus(p, v),
                  itemBuilder: (_) => statusColors.keys
                      .map((s) => PopupMenuItem(value: s, child: Text(s)))
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle, size: 8, color: statusColor),
                      const SizedBox(width: 6),
                      Text(p.status,
                          style: TextStyle(
                              fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down_rounded, size: 16, color: statusColor),
                    ]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InfoChip(
                    Icons.local_shipping_rounded,
                    p.expectedDeliveryDate.isEmpty
                        ? 'No delivery date'
                        : 'ETA ${p.expectedDeliveryDate}'),
                if (p.id != null)
                  GestureDetector(
                    onTap: () => _delete(p.id!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.coral.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.coral.withOpacity(0.35)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline_rounded, color: AppColors.coral, size: 16),
                          SizedBox(width: 4),
                          Text('Delete',
                              style: TextStyle(
                                  color: AppColors.coral, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ]),
        ),
      ]),
    );
  }
}