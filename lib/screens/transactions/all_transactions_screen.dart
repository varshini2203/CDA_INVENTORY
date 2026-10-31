// lib/screens/transactions/all_transactions_screen.dart
//
// ALL TRANSACTIONS -- one combined, Vyapar-style list of every Sale Invoice
// and every Purchase bill, newest first, with totals on top.
//
// READ-ONLY on top of the existing modules: it only reads from
// InvoiceService / PurchaseService (same caches the Sale Invoices and
// Purchases screens use) and never changes them. Tapping a row opens the
// existing Invoice view / Purchase screen.
//
// Access: Sale rows need the 'invoices' module, Purchase rows need the
// 'purchases' module (same rule as the Sale Invoices / Purchases menu), so
// an employee never sees data they could not open elsewhere.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cda_inventory/models/invoice.dart';
import 'package:cda_inventory/models/purchase.dart';
import 'package:cda_inventory/services/invoice_service.dart';
import 'package:cda_inventory/services/purchase_service.dart';
import 'package:cda_inventory/core/access/access_scope.dart';
import 'package:cda_inventory/core/access/restricted_modules.dart';
import 'package:cda_inventory/screens/invoices/invoice_view_screen.dart';
import 'package:cda_inventory/screens/purchases/add_purchase_screen.dart';

enum _TxnType { sale, purchase }

enum _Range { all, today, thisMonth, lastMonth, thisYear, custom }

/// One normalised row (either a sale invoice or a purchase bill).
class _Txn {
  final _TxnType type;
  final String ref;
  final String party;
  final String items;
  final String payMode;
  final String status;
  final DateTime? date;
  final double total;
  final double? received; // sales only
  final double? balance; // sales only
  final Object source; // Invoice or Purchase

  const _Txn({
    required this.type,
    required this.ref,
    required this.party,
    required this.items,
    required this.payMode,
    required this.status,
    required this.date,
    required this.total,
    required this.source,
    this.received,
    this.balance,
  });
}

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  static const Color _navy = Color(0xFF0A1628);
  static const Color _teal = Color(0xFF00D4AA);
  static const Color _blue = Color(0xFF2F6FE4);
  static const Color _green = Color(0xFF00B894);
  static const Color _orange = Color(0xFFF57C00);
  static const Color _red = Color(0xFFE53935);
  static const Color _surface = Color(0xFFF0F4F8);

  final InvoiceService _invoiceService = InvoiceService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<_Txn> _all = [];
  bool _loading = true;
  String? _error;

  bool _canSales = false;
  bool _canPurchases = false;

  _TxnType? _typeFilter; // null = All
  _Range _range = _Range.all;
  DateTimeRange? _custom;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────
  Future<void> _load({bool force = false}) async {
    final access = context.read<CurrentAccess>();
    _canSales = access.canAccessModule(RestrictedModules.invoices);
    _canPurchases = access.canAccessModule(RestrictedModules.purchases);

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<List<_Txn>>([
        _canSales ? _loadSales(force) : Future.value(<_Txn>[]),
        _canPurchases ? _loadPurchases(force) : Future.value(<_Txn>[]),
      ]);
      final all = <_Txn>[...results[0], ...results[1]];
      all.sort((a, b) {
        final da = a.date, db = b.date;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
      if (!mounted) return;
      setState(() {
        _all = all;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<List<_Txn>> _loadSales(bool force) async {
    final list = await _invoiceService.fetchInvoices(forceRefresh: force);
    return list.map(_fromInvoice).toList();
  }

  Future<List<_Txn>> _loadPurchases(bool force) async {
    final list = await PurchaseService.getAllPurchases(forceRefresh: force);
    return list.map(_fromPurchase).toList();
  }

  _Txn _fromInvoice(Invoice i) {
    final cust = i.customer?.name.trim() ?? '';
    final party = cust.isNotEmpty
        ? cust
        : (i.vendorName.trim().isNotEmpty ? i.vendorName.trim() : 'Walk-in');
    return _Txn(
      type: _TxnType.sale,
      ref: i.invoiceNo,
      party: party,
      items: i.displayProductName,
      payMode: i.paymentMode,
      status: i.effectiveStatus,
      date: i.purchaseDateTime ?? i.addedAt,
      total: i.displayAmount,
      received: i.amountPaid,
      balance: i.balanceDue,
      source: i,
    );
  }

  _Txn _fromPurchase(Purchase p) {
    return _Txn(
      type: _TxnType.purchase,
      ref: p.invoiceNumber,
      party: p.displayVendorName,
      items: p.displayProductName,
      payMode: p.paymentType,
      status: '',
      date: _parseDate(p.purchaseDate) ?? p.createdAt,
      total: p.displayAmount,
      source: p,
    );
  }

  /// Accepts dd-MM-yyyy, dd/MM/yyyy and yyyy-MM-dd.
  static DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.trim().split(RegExp(r'[-/]'));
    if (parts.length != 3) return null;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    final c = int.tryParse(parts[2]);
    if (a == null || b == null || c == null) return null;
    if (parts[0].length == 4) return DateTime(a, b, c);
    return DateTime(c, b, a);
  }

  // ── Filtering ───────────────────────────────────────────────────────────
  DateTimeRange? _currentRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case _Range.all:
        return null;
      case _Range.today:
        return DateTimeRange(
            start: today, end: today.add(const Duration(days: 1)));
      case _Range.thisMonth:
        return DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: DateTime(now.year, now.month + 1, 1));
      case _Range.lastMonth:
        return DateTimeRange(
            start: DateTime(now.year, now.month - 1, 1),
            end: DateTime(now.year, now.month, 1));
      case _Range.thisYear:
        return DateTimeRange(
            start: DateTime(now.year, 1, 1), end: DateTime(now.year + 1, 1, 1));
      case _Range.custom:
        final c = _custom;
        if (c == null) return null;
        return DateTimeRange(
            start: DateTime(c.start.year, c.start.month, c.start.day),
            end: DateTime(c.end.year, c.end.month, c.end.day)
                .add(const Duration(days: 1)));
    }
  }

  List<_Txn> get _filtered {
    final range = _currentRange();
    final q = _query.trim().toLowerCase();
    return _all.where((t) {
      if (_typeFilter != null && t.type != _typeFilter) return false;
      if (range != null) {
        final d = t.date;
        if (d == null) return false;
        final day = DateTime(d.year, d.month, d.day);
        if (day.isBefore(range.start) || !day.isBefore(range.end)) return false;
      }
      if (q.isNotEmpty) {
        final hay =
        '${t.ref} ${t.party} ${t.items} ${t.payMode}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _onRangeChanged(_Range? r) async {
    if (r == null) return;
    if (r == _Range.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(now.year + 1, 12, 31),
        initialDateRange: _custom,
      );
      if (picked == null) return;
      setState(() {
        _custom = picked;
        _range = _Range.custom;
      });
      return;
    }
    setState(() => _range = r);
  }

  Future<void> _open(_Txn t) async {
    final src = t.source;
    if (src is Invoice) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'Invoice View'),
          builder: (_) => InvoiceViewScreen(invoice: src),
        ),
      );
    } else if (src is Purchase) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'Edit Purchase'),
          builder: (_) => AddPurchaseScreen(purchaseToEdit: src),
        ),
      );
    }
    if (mounted) _load(force: true);
  }

  // ── Formatting ──────────────────────────────────────────────────────────
  static String _money(double v) {
    final neg = v < 0;
    final parts = v.abs().toStringAsFixed(2).split('.');
    var whole = parts[0];
    if (whole.length > 3) {
      final last3 = whole.substring(whole.length - 3);
      var rest = whole.substring(0, whole.length - 3);
      final groups = <String>[];
      while (rest.length > 2) {
        groups.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) groups.insert(0, rest);
      whole = '${groups.join(',')},$last3';
    }
    return '${neg ? '-' : ''}\u20B9$whole.${parts[1]}';
  }

  static String _fmtDate(DateTime? d) {
    if (d == null) return '--';
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
  }

  static String _rangeLabel(_Range r) {
    switch (r) {
      case _Range.all:
        return 'All Time';
      case _Range.today:
        return 'Today';
      case _Range.thisMonth:
        return 'This Month';
      case _Range.lastMonth:
        return 'Last Month';
      case _Range.thisYear:
        return 'This Year';
      case _Range.custom:
        return 'Custom Range';
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Watching keeps the screen in sync if the admin changes access live.
    context.watch<CurrentAccess>();

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('All Transactions',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : () => _load(force: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: _body(),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _teal));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42, color: _red),
              const SizedBox(height: 10),
              Text('Could not load transactions\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87)),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => _load(force: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (!_canSales && !_canPurchases) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'You do not have access to Sales or Purchases. Please contact your admin.',
              textAlign: TextAlign.center),
        ),
      );
    }

    final rows = _filtered;
    return RefreshIndicator(
      color: _teal,
      onRefresh: () => _load(force: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        itemCount: 1 + (rows.isEmpty ? 1 : rows.length),
        itemBuilder: (context, i) {
          if (i == 0) return _header(rows);
          if (rows.isEmpty) return _empty();
          return _row(rows[i - 1]);
        },
      ),
    );
  }

  // ── Header: totals + filters ────────────────────────────────────────────
  Widget _header(List<_Txn> rows) {
    double sales = 0, purchases = 0, receivable = 0;
    for (final t in rows) {
      if (t.type == _TxnType.sale) {
        sales += t.total;
        receivable += t.balance ?? 0;
      } else {
        purchases += t.total;
      }
    }

    final saleCount = _all.where((t) => t.type == _TxnType.sale).length;
    final purchaseCount = _all.where((t) => t.type == _TxnType.purchase).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, c) {
          final perRow = c.maxWidth >= 720 ? 4 : 2;
          const gap = 10.0;
          final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
          Widget tile(String label, double value, Color color, IconData icon) {
            return SizedBox(
              width: w,
              child: Material(
                color: Colors.white,
                elevation: 1.5,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: color, width: 4)),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(_money(value),
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: color)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              if (_canSales)
                tile('Total Sales', sales, _green, Icons.trending_up_rounded),
              if (_canPurchases)
                tile('Total Purchases', purchases, _orange,
                    Icons.shopping_cart_rounded),
              if (_canSales && _canPurchases)
                tile('Sales \u2212 Purchases', sales - purchases,
                    sales - purchases >= 0 ? _blue : _red,
                    Icons.balance_rounded),
              if (_canSales)
                tile('To Receive (Sales)', receivable, _red,
                    Icons.account_balance_wallet_rounded),
            ],
          );
        }),
        const SizedBox(height: 14),
        // Search
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Search party, bill no, item, payment mode',
            hintStyle: TextStyle(color: Colors.grey.shade600),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
        const SizedBox(height: 10),
        // Type chips + date range
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _typeChip('All (${_all.length})', null),
            if (_canSales) _typeChip('Sale ($saleCount)', _TxnType.sale),
            if (_canPurchases)
              _typeChip('Purchase ($purchaseCount)', _TxnType.purchase),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<_Range>(
                  value: _range,
                  isDense: true,
                  dropdownColor: Colors.white, // popup background
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.black87),
                  items: [
                    for (final r in _Range.values)
                      DropdownMenuItem(
                        value: r,
                        child: Text(
                          r == _Range.custom && _custom != null
                              ? '${_fmtDate(_custom!.start)} - ${_fmtDate(_custom!.end)}'
                              : _rangeLabel(r),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                  onChanged: _onRangeChanged,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('${rows.length} transaction${rows.length == 1 ? '' : 's'}',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _typeChip(String label, _TxnType? value) {
    final sel = _typeFilter == value;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: sel ? Colors.white : Colors.black87)),
      selected: sel,
      selectedColor: _navy,
      backgroundColor: Colors.white,
      showCheckmark: false,
      onSelected: (_) => setState(() => _typeFilter = value),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 46, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text('No transactions found',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text('Try a different type, date range or search.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  // ── One transaction row ─────────────────────────────────────────────────
  Widget _row(_Txn t) {
    final isSale = t.type == _TxnType.sale;
    final color = isSale ? _green : _orange;
    final balance = t.balance ?? 0;

    Widget pill(String text, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w800, color: c)),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1.5,
        shadowColor: Colors.black26,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(t),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: color, width: 4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          pill(isSale ? 'SALE' : 'PURCHASE', color),
                          Text(t.ref.isEmpty ? '--' : '#${t.ref}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87)),
                          Text(_fmtDate(t.date),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(t.party.isEmpty ? '--' : t.party,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A2E))),
                      if (t.items.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(t.items,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5, color: Colors.grey.shade600)),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (t.payMode.isNotEmpty)
                            pill(t.payMode.toUpperCase(), _blue),
                          if (isSale && t.status.isNotEmpty)
                            pill(
                                t.status.toUpperCase(),
                                t.status == 'Paid'
                                    ? _green
                                    : (t.status == 'Overdue' ? _red : _orange)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_money(t.total),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: color)),
                    if (isSale) ...[
                      const SizedBox(height: 4),
                      Text('Received ${_money(t.received ?? 0)}',
                          style: TextStyle(
                              fontSize: 11.5, color: Colors.grey.shade600)),
                      Text('Balance ${_money(balance)}',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: balance > 0.01 ? _red : _green)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}