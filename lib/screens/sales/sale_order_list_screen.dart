// lib/screens/sales/sale_order_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cda_inventory/models/sale_order.dart';
import 'package:cda_inventory/services/sale_order_service.dart';
import 'package:cda_inventory/shared/inventory_ui.dart';
import 'add_sale_order_screen.dart';

class SaleOrderListScreen extends StatefulWidget {
  const SaleOrderListScreen({super.key});
  @override
  State<SaleOrderListScreen> createState() => _SaleOrderListScreenState();
}

class _SaleOrderListScreenState extends State<SaleOrderListScreen> with SingleTickerProviderStateMixin {
  static const kBg = Color(0xFFF4F6F9);
  static const kNavy = Color(0xFF0A1628);
  static const kRed = Color(0xFFE94D5F);
  static const kBlue = Color(0xFF2F6FE4);
  static const kGreen = Color(0xFF00B894);
  static const kOrange = Color(0xFFFFB800);
  static const kBorder = Color(0xFFE7EAF0);
  static const kTextDark = Color(0xFF1F2937);
  static const kTextSub = Color(0xFF6B7280);
  static const kTextMute = Color(0xFF9CA3AF);
  static const kRowAlt = Color(0xFFF7F9FC);

  late TabController _tabController;
  List<SaleOrder> _orders = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final orders = await SaleOrderService.fetchOrders(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<SaleOrder> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _orders;
    return _orders.where((o) =>
    o.orderNo.toLowerCase().contains(q) ||
        (o.customer?.name.toLowerCase().contains(q) ?? false)).toList();
  }

  void _addOrder() async {
    final result = await Navigator.push(context, MaterialPageRoute(
        settings: const RouteSettings(name: 'Add Sale Order'), builder: (_) => const AddSaleOrderScreen()));
    if (result == true) _load(forceRefresh: true);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Closed': return kGreen;
      case 'Cancelled': return kRed;
      default: return kOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kTextDark,
        elevation: 0.5,
        title: const Text('Sale Order', style: TextStyle(color: kTextDark, fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => _load(forceRefresh: true))],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(children: [
            Expanded(child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
              child: Row(children: [
                const Icon(Icons.search_rounded, color: kTextMute, size: 20),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _searchController, onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 14, color: kTextDark),
                    decoration: const InputDecoration(hintText: 'Search Transactions', hintStyle: TextStyle(color: kTextMute, fontSize: 14), border: InputBorder.none, isDense: true))),
              ]),
            )),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _addOrder,
              style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: Colors.white, elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Sale Order', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ]),
        ),
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: kNavy,
            unselectedLabelColor: kTextMute,
            indicatorColor: kBlue,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5),
            tabs: const [Tab(text: 'SALE ORDERS'), Tab(text: 'ONLINE ORDERS')],
          ),
        ),
        Expanded(
          child: TabBarView(controller: _tabController, children: [
            _buildOrdersBody(),
            _buildOnlineOrdersEmpty(),
          ]),
        ),
      ]),
    );
  }

  Widget _buildOrdersBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: kRed));
    if (_filtered.isEmpty) return _buildEmpty();
    return RefreshIndicator(
      color: kRed,
      onRefresh: () => _load(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _orderCard(_filtered[i], i),
      ),
    );
  }

  Widget _orderCard(SaleOrder o, int i) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: kBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.receipt_long_rounded, color: kBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(o.orderNo, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextDark)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _statusColor(o.status).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(o.status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _statusColor(o.status))),
                ),
              ]),
              const SizedBox(height: 3),
              Text(o.customer?.name.isNotEmpty == true ? o.customer!.name : 'Walk-in Customer',
                  style: const TextStyle(fontSize: 12.5, color: kTextSub)),
              const SizedBox(height: 2),
              Text('${o.orderDate}${o.deliveryDate != null ? '  →  Delivery: ${o.deliveryDate}' : ''}',
                  style: const TextStyle(fontSize: 11, color: kTextMute)),
            ]),
          ),
          Text('₹${o.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTextDark)),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 130, height: 130,
            decoration: BoxDecoration(color: kBlue.withOpacity(0.06), shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_rounded, size: 60, color: kBlue),
          ),
          const SizedBox(height: 22),
          const Text('Make & share sale orders & convert them to sale invoice instantly.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: kTextSub)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _addOrder,
            style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Add Your First Sale Order', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
        ]),
      ),
    );
  }

  Widget _buildOnlineOrdersEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.shopping_bag_outlined, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 14),
        Text('No online orders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
      ]),
    );
  }
}