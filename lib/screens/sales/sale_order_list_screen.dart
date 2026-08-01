// lib/screens/sales/sale_order_list_screen.dart
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cda_inventory/models/sale_order.dart';
import 'package:cda_inventory/services/sale_order_service.dart';
import 'package:cda_inventory/services/sale_order_pdf_service.dart';
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

  // ── Edit an existing order ──────────────────────────────────────────────
  Future<void> _editOrder(SaleOrder o) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Edit Sale Order'),
        builder: (_) => AddSaleOrderScreen(orderToEdit: o),
      ),
    );
    if (result == true) _load(forceRefresh: true);
  }

  // ── Delete an order ──────────────────────────────────────────────────────
  Future<void> _deleteOrder(SaleOrder o) async {
    if (o.id == null) return;
    final confirm = await showConfirmDeleteDialog(
      context,
      title: 'Delete Sale Order',
      message: 'Are you sure you want to delete order ${o.orderNo}?',
    );
    if (!confirm) return;
    try {
      await SaleOrderService.deleteOrder(o.id!);
      if (!mounted) return;
      setState(() => _orders.removeWhere((x) => x.id == o.id));
      showAppSnack(context, 'Sale order deleted successfully');
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'Failed to delete order: $e', isError: true);
    }
  }

  // ── Share order details as text ─────────────────────────────────────────
  Future<void> _shareOrder(SaleOrder o) async {
    final buffer = StringBuffer()
      ..writeln('Sale Order ${o.orderNo}')
      ..writeln('Status: ${o.status}')
      ..writeln('Customer: ${o.customer?.name.isNotEmpty == true ? o.customer!.name : 'Walk-in Customer'}')
      ..writeln('Branch: ${kBranchLabels[o.branch] ?? o.branch}')
      ..writeln('Order Date: ${o.orderDate}')
      ..writeln('Delivery Date: ${o.deliveryDate ?? '—'}')
      ..writeln('Items: ${o.lineItems.length}')
      ..writeln('---')
      ..writeln('Subtotal: ₹${o.subtotal.toStringAsFixed(2)}');
    if (o.totalTax > 0) buffer.writeln('Tax: ₹${o.totalTax.toStringAsFixed(2)}');
    if (o.shipping > 0) buffer.writeln('Shipping: ₹${o.shipping.toStringAsFixed(2)}');
    buffer.writeln('Grand Total: ₹${o.grandTotal.toStringAsFixed(2)}');
    if (o.notes.trim().isNotEmpty) buffer.writeln('Notes: ${o.notes}');
    await Share.share(buffer.toString(), subject: 'Sale Order ${o.orderNo}');
  }

  // ── Print — SkyLynk-branded PDF, opened in the browser's print/preview
  // dialog ───────────────────────────────────────────────────────────────
  Future<void> _printOrder(SaleOrder o) async {
    try {
      await Printing.layoutPdf(onLayout: (format) => SaleOrderPdfService.generate(o));
    } catch (e) {
      if (mounted) showAppSnack(context, 'Failed to generate PDF: $e', isError: true);
    }
  }

  // ── Share as PDF — sends the generated PDF straight to WhatsApp/Email/
  // etc via the native share sheet ─────────────────────────────────────
  Future<void> _sharePdf(SaleOrder o) async {
    try {
      final bytes = await SaleOrderPdfService.generate(o);
      await Printing.sharePdf(bytes: bytes, filename: 'sale_order_${o.orderNo}.pdf');
    } catch (e) {
      if (mounted) showAppSnack(context, 'Failed to share PDF: $e', isError: true);
    }
  }

  // ── Bulk export — all filtered orders as a single PDF report ───────────
  Future<void> _exportPdf() async {
    if (_filtered.isEmpty) {
      showAppSnack(context, 'Nothing to export', isError: true);
      return;
    }
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: 'Sale Orders Report'),
          pw.Table.fromTextArray(
            headers: ['Order No.', 'Customer', 'Order Date', 'Delivery Date', 'Status', 'Amount'],
            data: _filtered
                .map((o) => [
              o.orderNo,
              o.customer?.name.isNotEmpty == true ? o.customer!.name : 'Walk-in Customer',
              o.orderDate,
              o.deliveryDate ?? '-',
              o.status,
              o.grandTotal.toStringAsFixed(2),
            ])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Total Orders Value: Rs. ${_filtered.fold(0.0, (s, o) => s + o.grandTotal).toStringAsFixed(2)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'sale_orders_report.pdf');
  }

  // ── View full order details ─────────────────────────────────────────────
  void _viewOrder(SaleOrder o) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: kBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: kBlue, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(o.orderNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kTextDark)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: _statusColor(o.status).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Text(o.status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _statusColor(o.status))),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Text(o.customer?.name.isNotEmpty == true ? o.customer!.name : 'Walk-in Customer',
                          style: const TextStyle(color: kTextSub, fontSize: 13)),
                    ],
                  ),
                ),
                Text('₹${o.grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: kTextDark)),
              ]),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              if ((o.customer?.phone ?? '').trim().isNotEmpty) _detailRow('Phone', o.customer!.phone!),
              _detailRow('Branch', kBranchLabels[o.branch] ?? o.branch),
              _detailRow('Order Date', o.orderDate),
              _detailRow('Delivery Date', o.deliveryDate ?? '—'),
              _detailRow('Items', '${o.lineItems.length}'),
              _detailRow('Subtotal', '₹${o.subtotal.toStringAsFixed(2)}'),
              if (o.totalTax > 0) _detailRow('Tax', '₹${o.totalTax.toStringAsFixed(2)}'),
              if (o.shipping > 0) _detailRow('Shipping', '₹${o.shipping.toStringAsFixed(2)}'),
              _detailRow('Grand Total', '₹${o.grandTotal.toStringAsFixed(2)}'),
              if (o.notes.trim().isNotEmpty) _detailRow('Notes', o.notes),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _printOrder(o),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kTextDark,
                      side: const BorderSide(color: kBorder),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _sharePdf(o),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kBlue,
                      side: const BorderSide(color: kBlue),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Share PDF'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _shareOrder(o),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kBlue,
                      side: const BorderSide(color: kBlue),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Share Text'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _editOrder(o);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kNavy,
                      side: const BorderSide(color: kNavy),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: kTextDark, fontSize: 13.5, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );

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
            IconButton(
              tooltip: 'Print / Export PDF',
              icon: const Icon(Icons.print_rounded, size: 20, color: kTextSub),
              onPressed: _exportPdf,
            ),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
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
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert_rounded, color: kTextMute, size: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (v) {
                switch (v) {
                  case 'print': _printOrder(o); break;
                  case 'pdf': _sharePdf(o); break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'print', child: Row(children: [Icon(Icons.print_outlined, size: 18, color: kTextDark), SizedBox(width: 10), Text('Print')])),
                PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf_outlined, size: 18, color: kBlue), SizedBox(width: 10), Text('Share as PDF')])),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _viewOrder(o),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: kNavy.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kNavy.withOpacity(0.18)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined, color: kNavy, size: 16),
                      SizedBox(width: 4),
                      Text('View', style: TextStyle(color: kNavy, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => _editOrder(o),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: kOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kOrange.withOpacity(0.35)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, color: kOrange, size: 16),
                      SizedBox(width: 4),
                      Text('Edit', style: TextStyle(color: kOrange, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => _shareOrder(o),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: kBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBlue.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.ios_share_rounded, color: kBlue, size: 16),
                      SizedBox(width: 4),
                      Text('Share', style: TextStyle(color: kBlue, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
            if (o.id != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _deleteOrder(o),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: kRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kRed.withOpacity(0.35)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded, color: kRed, size: 16),
                        SizedBox(width: 4),
                        Text('Delete', style: TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ]),
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