// lib/screens/delivery_challan/delivery_challan_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cda_inventory/models/delivery_challan.dart';
import 'package:cda_inventory/services/delivery_challan_service.dart';
import 'package:cda_inventory/services/invoice_service.dart';
import 'package:cda_inventory/shared/inventory_ui.dart';
import 'add_delivery_challan_screen.dart';
import 'delivery_challan_view_screen.dart';

class DeliveryChallanListScreen extends StatefulWidget {
  const DeliveryChallanListScreen({super.key});
  @override
  State<DeliveryChallanListScreen> createState() => _DeliveryChallanListScreenState();
}

class _DeliveryChallanListScreenState extends State<DeliveryChallanListScreen> {
  static const kBg = Color(0xFFF4F6F9);
  static const kNavy = Color(0xFF0A1628);
  static const kRed = Color(0xFFE94D5F);
  static const kBlue = Color(0xFF2F6FE4);
  static const kGreen = Color(0xFF00B894);
  static const kOrange = Color(0xFFFFB800);
  static const kPurple = Color(0xFF8B5CF6);
  static const kBorder = Color(0xFFE7EAF0);
  static const kTextDark = Color(0xFF1F2937);
  static const kTextSub = Color(0xFF6B7280);
  static const kTextMute = Color(0xFF9CA3AF);

  List<DeliveryChallan> _challans = [];
  bool _isLoading = true;
  bool _selectMode = false;
  final Set<String> _selectedIds = {};
  final _searchController = TextEditingController();
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final challans = await DeliveryChallanService.fetchChallans(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _challans = challans;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<DeliveryChallan> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    return _challans.where((c) {
      final matchesQ = q.isEmpty ||
          c.challanNo.toLowerCase().contains(q) ||
          (c.customer?.name.toLowerCase().contains(q) ?? false);
      final matchesStatus = _statusFilter == 'All' || c.status == _statusFilter;
      return matchesQ && matchesStatus;
    }).toList();
  }

  void _addChallan() async {
    final result = await Navigator.push(context, MaterialPageRoute(
        settings: const RouteSettings(name: 'Add Delivery Challan'),
        builder: (_) => const AddDeliveryChallanScreen()));
    if (result == true) _load(forceRefresh: true);
  }

  void _viewChallan(DeliveryChallan c) async {
    final result = await Navigator.push(context, MaterialPageRoute(
        settings: const RouteSettings(name: 'View Delivery Challan'),
        builder: (_) => DeliveryChallanViewScreen(challan: c)));
    if (result == true) _load(forceRefresh: true);
  }

  Future<void> _convertToInvoice(DeliveryChallan c) async {
    if (c.status == 'Converted') {
      showAppSnack(context, 'This challan is already converted to invoice ${c.convertedInvoiceNo ?? ''}', isError: true);
      return;
    }
    final confirm = await showConfirmDeleteDialog(
      context,
      title: 'Convert to Sale Invoice?',
      message: 'This will create a new Sale Invoice from ${c.challanNo} with all its items.',
    );
    if (!confirm) return;
    try {
      final invoiceService = InvoiceService();
      final newNo = await invoiceService.suggestNextInvoiceNumber(forceRefresh: true);
      final invoice = await DeliveryChallanService.convertToInvoice(c, newInvoiceNo: newNo);
      if (!mounted) return;
      showAppSnack(context, 'Converted to Sale Invoice ${invoice.invoiceNo}');
      _load(forceRefresh: true);
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'Conversion failed: $e', isError: true);
    }
  }

  Future<void> _deleteChallan(DeliveryChallan c) async {
    final confirm = await showConfirmDeleteDialog(
      context,
      title: 'Delete Delivery Challan',
      message: 'Are you sure you want to delete ${c.challanNo}?',
    );
    if (!confirm || c.id == null) return;
    try {
      await DeliveryChallanService.deleteChallan(c.id!);
      if (!mounted) return;
      showAppSnack(context, 'Delivery challan deleted');
      _load(forceRefresh: true);
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'Delete failed: $e', isError: true);
    }
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showConfirmDeleteDialog(
      context,
      title: 'Delete ${_selectedIds.length} Challans',
      message: 'Are you sure you want to delete the selected delivery challans?',
    );
    if (!confirm) return;
    try {
      await DeliveryChallanService.deleteChallansBulk(_selectedIds.toList());
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _selectMode = false;
      });
      showAppSnack(context, 'Deleted successfully');
      _load(forceRefresh: true);
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'Delete failed: $e', isError: true);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Delivered': return kBlue;
      case 'Converted': return kGreen;
      case 'Cancelled': return kRed;
      default: return kOrange;
    }
  }

  double get _totalAmount => _filtered.fold(0.0, (s, c) => s + c.grandTotal);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kTextDark,
        elevation: 0.5,
        title: Text(_selectMode ? '${_selectedIds.length} Selected' : 'Delivery Challan',
            style: const TextStyle(color: kTextDark, fontWeight: FontWeight.w700, fontSize: 17)),
        leading: _selectMode
            ? IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => setState(() {
              _selectMode = false;
              _selectedIds.clear();
            }))
            : null,
        actions: _selectMode
            ? [
          IconButton(icon: const Icon(Icons.delete_outline_rounded, color: kRed), onPressed: _bulkDelete),
          const SizedBox(width: 6),
        ]
            : [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => _load(forceRefresh: true))],
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
              onPressed: _addChallan,
              style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: Colors.white, elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Delivery Challan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ]),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['All', ...DeliveryChallan.statusOptions].map((s) {
                final selected = _statusFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : kTextSub)),
                    selected: selected,
                    onSelected: (_) => setState(() => _statusFilter = s),
                    selectedColor: kNavy,
                    backgroundColor: kBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: selected ? kNavy : kBorder)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (!_isLoading && _filtered.isNotEmpty) _summaryBar(),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _summaryBar() {
    return Container(
      width: double.infinity,
      color: kNavy,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Text('${_filtered.length} Challans', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('Total: ₹${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: kRed));
    if (_filtered.isEmpty) return _buildEmpty();
    return RefreshIndicator(
      color: kRed,
      onRefresh: () => _load(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _challanCard(_filtered[i]),
      ),
    );
  }

  Widget _challanCard(DeliveryChallan c) {
    final selected = c.id != null && _selectedIds.contains(c.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? kBlue : kBorder, width: selected ? 1.4 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (_selectMode) {
            setState(() {
              if (selected) {
                _selectedIds.remove(c.id);
              } else if (c.id != null) {
                _selectedIds.add(c.id!);
              }
            });
          } else {
            _viewChallan(c);
          }
        },
        onLongPress: c.id == null
            ? null
            : () => setState(() {
          _selectMode = true;
          _selectedIds.add(c.id!);
        }),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            if (_selectMode) ...[
              Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: selected ? kBlue : kTextMute, size: 22),
              const SizedBox(width: 10),
            ] else
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: kPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.local_shipping_rounded, color: kPurple, size: 20),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(c.challanNo, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextDark)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _statusColor(c.status).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(c.status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _statusColor(c.status))),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(c.customer?.name.isNotEmpty == true ? c.customer!.name : 'Walk-in Customer',
                    style: const TextStyle(fontSize: 12.5, color: kTextSub)),
                const SizedBox(height: 2),
                Text('${c.challanDate}  •  ${c.totalQty} item(s)',
                    style: const TextStyle(fontSize: 11, color: kTextMute)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${c.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTextDark)),
              const SizedBox(height: 6),
              if (!_selectMode)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert_rounded, color: kTextMute, size: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (v) {
                    switch (v) {
                      case 'view': _viewChallan(c); break;
                      case 'convert': _convertToInvoice(c); break;
                      case 'delete': _deleteChallan(c); break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility_outlined, size: 18, color: kTextDark), SizedBox(width: 10), Text('View')])),
                    PopupMenuItem(value: 'convert', enabled: c.status != 'Converted' && c.status != 'Cancelled',
                        child: const Row(children: [Icon(Icons.sync_alt_rounded, size: 18, color: kGreen), SizedBox(width: 10), Text('Convert to Sale')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: kRed), SizedBox(width: 10), Text('Delete')])),
                  ],
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 150, height: 150,
            decoration: BoxDecoration(color: kBlue.withOpacity(0.06), shape: BoxShape.circle),
            child: const Icon(Icons.local_shipping_rounded, size: 64, color: kBlue),
          ),
          const SizedBox(height: 22),
          const Text('Make & share delivery challan with your customers\n& convert it to sale whenever you want.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: kTextSub, height: 1.4)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _addChallan,
            style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Add Your First Delivery Challan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
        ]),
      ),
    );
  }
}