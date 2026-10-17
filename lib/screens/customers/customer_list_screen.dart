// lib/screens/customers/customer_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cda_inventory/models/customer_details.dart';
import 'package:cda_inventory/models/invoice.dart';
import 'package:cda_inventory/services/customer_service.dart';
import 'package:cda_inventory/services/invoice_service.dart';
import 'package:cda_inventory/screens/customers/add_customer_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerStats {
  int invoices = 0;
  double total = 0;
  double due = 0;
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kCoral = Color(0xFFFF6B6B);
  static const Color kSurface = Color(0xFFF0F4F8);

  final _service = CustomerService();
  final _invoiceService = InvoiceService();
  final _searchC = TextEditingController();

  List<CustomerDetails> _customers = [];
  List<Invoice> _invoices = [];
  Map<String, _CustomerStats> _stats = {};
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    try {
      final customers = await _service.fetchCustomers(forceRefresh: force);
      List<Invoice> invoices = [];
      try {
        invoices = await _invoiceService.fetchInvoices(forceRefresh: force);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _invoices = invoices;
        _stats = _buildStats(customers, invoices);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Could not load customers: $e', isError: true);
    }
  }

  Map<String, _CustomerStats> _buildStats(
      List<CustomerDetails> customers, List<Invoice> invoices) {
    final byPhone = <String, CustomerDetails>{
      for (final c in customers)
        if (c.phoneKey.isNotEmpty) c.phoneKey: c,
    };
    final byName = <String, CustomerDetails>{
      for (final c in customers) c.nameKey: c,
    };
    final out = <String, _CustomerStats>{};
    for (final inv in invoices) {
      final ic = inv.customer;
      final nameKey = (ic?.name ?? inv.vendorName).trim().toLowerCase();
      CustomerDetails? match;
      if (ic != null && ic.phoneKey.isNotEmpty) match = byPhone[ic.phoneKey];
      match ??= byName[nameKey];
      if (match == null || match.id == null) continue;
      final s = out.putIfAbsent(match.id!, () => _CustomerStats());
      s.invoices += 1;
      s.total += inv.displayAmount;
      s.due += inv.balanceDue;
    }
    return out;
  }

  List<CustomerDetails> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _customers;
    return _customers
        .where((c) =>
    c.nameKey.contains(q) ||
        (c.phone ?? '').contains(q) ||
        (c.gstin ?? '').toLowerCase().contains(q) ||
        (c.email ?? '').toLowerCase().contains(q))
        .toList();
  }

  Future<void> _openEditor([CustomerDetails? c]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomerScreen(customerToEdit: c),
        settings: RouteSettings(name: c == null ? 'Add Customer' : 'Edit Customer'),
      ),
    );
    if (saved == true) {
      _snack(c == null ? 'Customer added' : 'Customer updated');
      _load();
    }
  }

  Future<void> _delete(CustomerDetails c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Customer'),
        content: Text(
            'Delete "${c.name}"? Existing invoices are not affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: kCoral)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteCustomer(c);
      _snack('Customer deleted');
      _load();
    } catch (e) {
      _snack('Could not delete: $e', isError: true);
    }
  }

  // Pulls customers that only exist inside old invoices into the master list.
  Future<void> _importFromInvoices() async {
    setState(() => _loading = true);
    try {
      final legacy = <CustomerDetails>[];
      for (final inv in _invoices) {
        final c = inv.customer;
        if (c != null && c.name.trim().isNotEmpty) {
          legacy.add(c);
        } else if (inv.vendorName.trim().isNotEmpty) {
          legacy.add(CustomerDetails(name: inv.vendorName));
        }
      }
      final added = await _service.importFromDetails(legacy);
      _snack(added == 0
          ? 'No new customers found in invoices'
          : '$added customer(s) imported from invoices');
      await _load(force: true);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _snack('Import failed: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? kCoral : kNavy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Customers',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'import') _importFromInvoices();
              if (v == 'refresh') _load(force: true);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'import',
                child: Row(children: [
                  Icon(Icons.download_rounded, size: 18, color: kNavy),
                  SizedBox(width: 10),
                  Text('Import from invoices'),
                ]),
              ),
              PopupMenuItem(
                value: 'refresh',
                child: Row(children: [
                  Icon(Icons.refresh_rounded, size: 18, color: kNavy),
                  SizedBox(width: 10),
                  Text('Refresh'),
                ]),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: kTeal,
        foregroundColor: kNavy,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Customer',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      ),
      body: Column(
        children: [
          Container(
            color: kNavy,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: TextField(
              controller: _searchC,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search name, phone, GSTIN…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.6)),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                  icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.6)),
                  onPressed: () {
                    _searchC.clear();
                    setState(() => _query = '');
                  },
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kTeal))
                : list.isEmpty
                ? _empty()
                : RefreshIndicator(
              color: kTeal,
              onRefresh: () => _load(force: true),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _customerCard(list[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return ListView(
      children: [
        const SizedBox(height: 90),
        Icon(Icons.groups_2_outlined, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 14),
        Center(
          child: Text(
            _query.isEmpty ? 'No customers yet' : 'No customers match "$_query"',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade500),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            _query.isEmpty
                ? 'Add one here, or they are saved automatically\nwhen you create an invoice.'
                : 'Try a different name or number.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
          ),
        ),
        if (_query.isEmpty) ...[
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton.icon(
              onPressed: _importFromInvoices,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Import from invoices'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: const BorderSide(color: kNavy),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _customerCard(CustomerDetails c) {
    final s = _stats[c.id];
    final initial = c.name.trim().isEmpty ? '?' : c.name.trim()[0].toUpperCase();
    final details = <String>[
      if ((c.phone ?? '').isNotEmpty) c.phone!,
      if ((c.gstin ?? '').isNotEmpty) 'GSTIN ${c.gstin}',
    ];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openEditor(c),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: kTeal.withOpacity(0.15),
                child: Text(initial,
                    style: const TextStyle(
                        color: kNavy, fontWeight: FontWeight.w800, fontSize: 17)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: kNavy)),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(details.join('  •  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                    if ((c.billingAddress ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(c.billingAddress!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade400)),
                    ],
                    if (s != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        _pill('${s.invoices} invoice${s.invoices == 1 ? '' : 's'}', kNavy),
                        const SizedBox(width: 6),
                        _pill('₹${s.total.toStringAsFixed(0)}', kTeal),
                        if (s.due > 0.01) ...[
                          const SizedBox(width: 6),
                          _pill('Due ₹${s.due.toStringAsFixed(0)}', kCoral),
                        ],
                      ]),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade400, size: 20),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'edit') _openEditor(c);
                  if (v == 'delete') _delete(c);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18, color: kNavy),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: kCoral),
                      SizedBox(width: 10),
                      Text('Delete', style: TextStyle(color: kCoral)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text,
        style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: color == kTeal ? const Color(0xFF00896F) : color)),
  );
}