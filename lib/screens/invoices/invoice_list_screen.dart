// lib/screens/invoices/invoice_list_screen.dart
//
// "Sale Invoices" screen — styled to match the Vyapar desktop layout:
// search + Add Sale bar, filter chips (status / date / firm / user),
// a Total Sales Amount summary card, and a full Transactions table.
//
// Payment-In is now wired in two places:
//   1. A "Payment-In" button in the top bar (general receipt entry, no
//      customer preselected).
//   2. A "Receive Payment" row action (in the "⋮" menu) on any invoice
//      that still has a balance due — this pre-fills that invoice's
//      customer name on the Add Payment-In screen.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'invoice_view_screen.dart';
import 'package:cda_inventory/services/invoice_service.dart';
import 'package:cda_inventory/services/invoice_pdf_service.dart';
import 'package:cda_inventory/models/invoice.dart';
import 'package:cda_inventory/screens/invoices/add_invoice_screen.dart';
import 'package:cda_inventory/utils/status_helpers.dart';
import 'package:cda_inventory/screens/sales/add_payment_in_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final InvoiceService _invoiceService = InvoiceService();

  List<Invoice> _allInvoices      = [];
  List<Invoice> _filteredInvoices = [];

  bool _isLoading      = true;
  String _errorMessage = '';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSearchBar = false;

  // ── Filters (mirrors the "All Sale Invoices / Pick a date / All Firms /
  //    All Users" filter row in the reference design) ─────────────────────
  static const List<String> _statusFilterOptions = ['All', 'Paid', 'Pending', 'Overdue'];
  String _statusFilter = 'All';
  String _branchFilter = 'All';
  String _userFilter   = 'All';
  DateTimeRange? _dateRangeFilter;

  List<String> _branchList = [];
  List<String> _userList   = [];

  bool get _isFilterActive =>
      _statusFilter != 'All' ||
          _branchFilter != 'All' ||
          _userFilter != 'All' ||
          _dateRangeFilter != null;

  // ── Design tokens ──────────────────────────────────────────────────────
  static const Color kBg       = Color(0xFFF4F6F9);
  static const Color kNavy     = Color(0xFF0A1628);
  static const Color kRed      = Color(0xFFE94D5F);
  static const Color kBlue     = Color(0xFF2F6FE4);
  static const Color kGreen    = Color(0xFF00B894);
  static const Color kBorder   = Color(0xFFE7EAF0);
  static const Color kTextDark = Color(0xFF1F2937);
  static const Color kTextSub  = Color(0xFF6B7280);
  static const Color kTextMute = Color(0xFF9CA3AF);
  static const Color kRowAlt   = Color(0xFFF7F9FC);
  static const Color kRowSel   = Color(0xFFE7F0FE);

  static final NumberFormat _money2 =
  NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final NumberFormat _money0 =
  NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applySortAndFilter);
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applySortAndFilter);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices({bool forceRefresh = false}) async {
    setState(() {
      _isLoading    = true;
      _errorMessage = '';
    });
    try {
      final invoices = await _invoiceService.fetchInvoices(forceRefresh: forceRefresh);
      setState(() {
        _allInvoices = invoices;
        _branchList = invoices
            .map((i) => i.branch ?? '')
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        _userList = invoices
            .map((i) => i.addedBy ?? '')
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        _isLoading = false;
      });
      _applySortAndFilter();
    } catch (e) {
      setState(() {
        _isLoading    = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _applySortAndFilter() {
    final query = _searchController.text.toLowerCase();
    final filtered = _allInvoices.where((inv) {
      final partyName = _partyName(inv).toLowerCase();
      final matchesQuery = query.isEmpty ||
          inv.invoiceNo.toLowerCase().contains(query) ||
          partyName.contains(query);
      final matchesStatus =
          _statusFilter == 'All' || inv.effectiveStatus == _statusFilter;
      final matchesBranch =
          _branchFilter == 'All' || (inv.branch ?? '') == _branchFilter;
      final matchesUser =
          _userFilter == 'All' || (inv.addedBy ?? '') == _userFilter;

      bool matchesDate = true;
      if (_dateRangeFilter != null) {
        final d = inv.purchaseDateTime;
        if (d == null) {
          matchesDate = false;
        } else {
          matchesDate = !d.isBefore(_dateRangeFilter!.start) &&
              !d.isAfter(_dateRangeFilter!.end);
        }
      }

      return matchesQuery && matchesStatus && matchesBranch && matchesUser && matchesDate;
    }).toList()
      ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));

    setState(() => _filteredInvoices = filtered);
  }

  void _clearFilters() {
    setState(() {
      _statusFilter    = 'All';
      _branchFilter    = 'All';
      _userFilter      = 'All';
      _dateRangeFilter = null;
    });
    _applySortAndFilter();
  }

  // ── Derived display helpers ─────────────────────────────────────────────
  String _partyName(Invoice inv) {
    final custName = inv.customer?.name ?? '';
    return custName.isNotEmpty ? custName : inv.vendorName;
  }

  String _paymentType(Invoice inv) {
    if (inv.payments.isEmpty) return '—';
    return inv.payments.last.method;
  }

  double get _totalSalesAmount =>
      _filteredInvoices.fold(0.0, (sum, inv) => sum + inv.displayAmount);
  double get _totalReceived =>
      _filteredInvoices.fold(0.0, (sum, inv) => sum + inv.amountPaid);
  double get _totalBalance =>
      _filteredInvoices.fold(0.0, (sum, inv) => sum + inv.balanceDue);

  // ── Delete (single, with undo) ──────────────────────────────────────────
  void _showDeleteConfirmDialog(Invoice invoice) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: kRed),
            SizedBox(width: 8),
            Text('Delete Invoice',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Delete invoice ${invoice.invoiceNo}? This action cannot be undone.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteInvoice(invoice);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteInvoice(Invoice invoice) async {
    try {
      await _invoiceService.deleteInvoice(invoice.id!);
      setState(() => _allInvoices.removeWhere((i) => i.id == invoice.id));
      _applySortAndFilter();
      if (mounted) _showUndoSnack(invoice);
    } catch (e) {
      if (mounted) _showSnack('Failed to delete: ${e.toString()}', isError: true);
    }
  }

  void _showUndoSnack(Invoice invoice) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invoice ${invoice.invoiceNo} deleted'),
        backgroundColor: kNavy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: kBlue,
          onPressed: () async {
            try {
              await _invoiceService.createInvoice(invoice.copyWith(clearId: true));
              _loadInvoices();
            } catch (_) {
              _showSnack('Could not restore invoice', isError: true);
            }
          },
        ),
      ),
    );
  }

  // ── Per-row print / share ───────────────────────────────────────────────
  Future<void> _printInvoice(Invoice inv) async {
    try {
      final bytes = await InvoicePdfService.generate(inv);
      await Printing.sharePdf(bytes: bytes, filename: 'invoice_${inv.invoiceNo}.pdf');
    } catch (e) {
      _showSnack('Could not generate PDF: $e', isError: true);
    }
  }

  Future<void> _shareInvoice(Invoice inv) async {
    try {
      final bytes = await InvoicePdfService.generate(inv);
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: 'invoice_${inv.invoiceNo}.pdf', mimeType: 'application/pdf')],
        subject: 'Invoice ${inv.invoiceNo}',
      );
    } catch (e) {
      _showSnack('Could not share invoice: $e', isError: true);
    }
  }

  // ── Export (bulk) ───────────────────────────────────────────────────────
  Future<void> _exportCsv() async {
    if (_filteredInvoices.isEmpty) {
      _showSnack('Nothing to export', isError: true);
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('Date,Invoice No,Party Name,Payment Type,Amount,Balance,Status');
    for (final inv in _filteredInvoices) {
      buffer.writeln(
        '${inv.purchaseDate},${inv.invoiceNo},${_partyName(inv)},${_paymentType(inv)},'
            '${inv.displayAmount.toStringAsFixed(2)},${inv.balanceDue.toStringAsFixed(2)},${inv.effectiveStatus}',
      );
    }
    await Share.share(buffer.toString(), subject: 'Sale Invoices Export (${_filteredInvoices.length})');
  }

  Future<void> _exportPdf() async {
    if (_filteredInvoices.isEmpty) {
      _showSnack('Nothing to export', isError: true);
      return;
    }
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: 'Sale Invoices Report'),
          pw.Table.fromTextArray(
            headers: ['Date', 'Invoice No', 'Party Name', 'Payment Type', 'Amount', 'Balance', 'Status'],
            data: _filteredInvoices
                .map((inv) => [
              inv.purchaseDate,
              inv.invoiceNo,
              _partyName(inv),
              _paymentType(inv),
              inv.displayAmount.toStringAsFixed(2),
              inv.balanceDue.toStringAsFixed(2),
              inv.effectiveStatus,
            ])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Total Sales Amount: Rs. ${_totalSalesAmount.toStringAsFixed(2)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'sale_invoices_report.pdf');
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: isError ? kRed : kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _navigateToAddInvoice() async {
    final result = await Navigator.push(context,
        MaterialPageRoute(settings: const RouteSettings(name: 'Add Invoice'), builder: (_) => const AddInvoiceScreen()));
    if (result == true) _loadInvoices();
  }

  void _navigateToEditInvoice(Invoice invoice) async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            settings: const RouteSettings(name: 'Add Invoice'),
            builder: (_) => AddInvoiceScreen(invoiceToEdit: invoice)));
    if (result == true) _loadInvoices();
  }

  void _navigateToViewInvoice(Invoice invoice) async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            settings: const RouteSettings(name: 'Invoice View'),
            builder: (_) => InvoiceViewScreen(invoice: invoice)));
    if (result == true) _loadInvoices();
  }

  // ── Payment-In: general (top bar) and per-invoice (row menu) ───────────
  void _navigateToPaymentIn({String? customerName}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Payment-In'),
        builder: (_) => AddPaymentInScreen(initialCustomerName: customerName),
      ),
    );
    // A Payment-In can change an invoice's balance/status, so refresh
    // regardless of the returned value.
    _loadInvoices(forceRefresh: true);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kTextDark,
        elevation: 0.5,
        titleSpacing: 4,
        title: const Text('Sale Invoices',
            style: TextStyle(color: kTextDark, fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadInvoices(forceRefresh: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: kRed,
        onRefresh: () => _loadInvoices(forceRefresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              const SizedBox(height: 14),
              _buildFilterRow(),
              const SizedBox(height: 14),
              _buildTotalSalesCard(),
              const SizedBox(height: 16),
              _buildTransactionsHeader(),
              const SizedBox(height: 10),
              _buildTransactionsBody(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar: search + Payment-In + Add Sale ─────────────────────────────
  Widget _buildTopBar() {
    return Row(
      children: [
        Expanded(
          child: _showSearchBar
              ? Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(fontSize: 14, color: kTextDark),
              decoration: InputDecoration(
                hintText: 'Search Transactions',
                hintStyle: TextStyle(color: kTextMute, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: kTextMute, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close_rounded, color: kTextMute, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _showSearchBar = false);
                  },
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          )
              : GestureDetector(
            onTap: () {
              setState(() => _showSearchBar = true);
              WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocusNode.requestFocus());
            },
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
              ),
              child: const Row(children: [
                Icon(Icons.search_rounded, color: kTextMute, size: 20),
                SizedBox(width: 8),
                Text('Search Transactions', style: TextStyle(color: kTextMute, fontSize: 14)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () => _navigateToPaymentIn(),
          style: OutlinedButton.styleFrom(
            foregroundColor: kBlue,
            side: const BorderSide(color: kBlue),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.currency_rupee_rounded, size: 16),
          label: const Text('Payment-In', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _navigateToAddInvoice,
          style: ElevatedButton.styleFrom(
            backgroundColor: kRed,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Sale', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ],
    );
  }

  // ── Filter chip row ──────────────────────────────────────────────────────
  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _FilterChip(
          icon: Icons.receipt_long_rounded,
          label: _statusFilter == 'All' ? 'All Sale Invoices' : _statusFilter,
          active: _statusFilter != 'All',
          onTap: _showStatusMenu,
        ),
        const SizedBox(width: 8),
        _FilterChip(
          icon: Icons.calendar_today_rounded,
          label: _dateRangeFilter == null
              ? 'Pick a date'
              : '${DateFormat('dd/MM/yy').format(_dateRangeFilter!.start)} – ${DateFormat('dd/MM/yy').format(_dateRangeFilter!.end)}',
          active: _dateRangeFilter != null,
          onTap: _pickDateRange,
        ),
        const SizedBox(width: 8),
        _FilterChip(
          icon: Icons.apartment_rounded,
          label: _branchFilter == 'All' ? 'All Firms' : _branchFilter,
          active: _branchFilter != 'All',
          onTap: () => _showListMenu(
            title: 'Firm / Branch',
            allLabel: 'All Firms',
            options: _branchList,
            current: _branchFilter,
            onSelected: (v) {
              setState(() => _branchFilter = v);
              _applySortAndFilter();
            },
          ),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          icon: Icons.person_outline_rounded,
          label: _userFilter == 'All' ? 'All Users' : _userFilter,
          active: _userFilter != 'All',
          onTap: () => _showListMenu(
            title: 'User',
            allLabel: 'All Users',
            options: _userList,
            current: _userFilter,
            onSelected: (v) {
              setState(() => _userFilter = v);
              _applySortAndFilter();
            },
          ),
        ),
        if (_isFilterActive) ...[
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.filter_alt_off_rounded, size: 16, color: kRed),
            label: const Text('Clear', style: TextStyle(color: kRed, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ],
      ]),
    );
  }

  void _showStatusMenu() async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(24, 200, 24, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: _statusFilterOptions
          .map((opt) => PopupMenuItem(
        value: opt,
        child: Row(children: [
          Icon(
            _statusFilter == opt ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 17,
            color: _statusFilter == opt ? kBlue : Colors.grey,
          ),
          const SizedBox(width: 10),
          Text(opt == 'All' ? 'All Sale Invoices' : opt),
        ]),
      ))
          .toList(),
    );
    if (selected != null) {
      setState(() => _statusFilter = selected);
      _applySortAndFilter();
    }
  }

  void _showListMenu({
    required String title,
    required String allLabel,
    required List<String> options,
    required String current,
    required void Function(String) onSelected,
  }) async {
    final all = ['All', ...options];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextDark)),
              ),
            ),
            if (all.length == 1)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No data yet', style: TextStyle(color: kTextMute)),
              ),
            ...all.map((v) => ListTile(
              title: Text(v == 'All' ? allLabel : v),
              trailing: current == v ? const Icon(Icons.check_rounded, color: kBlue) : null,
              onTap: () => Navigator.pop(ctx, v),
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) onSelected(selected);
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _dateRangeFilter,
    );
    if (picked != null) {
      setState(() => _dateRangeFilter = picked);
      _applySortAndFilter();
    }
  }

  // ── Total Sales Amount card ─────────────────────────────────────────────
  Widget _buildTotalSalesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Sales Amount',
              style: TextStyle(color: kTextSub, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            _isLoading ? '—' : _money2.format(_totalSalesAmount),
            style: const TextStyle(color: kTextDark, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Received: ${_isLoading ? '—' : _money2.format(_totalReceived)}',
                  style: const TextStyle(color: kTextMute, fontSize: 12.5)),
              const Text('|', style: TextStyle(color: kTextMute)),
              Text('Balance: ${_isLoading ? '—' : _money2.format(_totalBalance)}',
                  style: const TextStyle(color: kTextMute, fontSize: 12.5)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Transactions header (title + action icons) ─────────────────────────
  Widget _buildTransactionsHeader() {
    return Row(
      children: [
        const Text('Transactions',
            style: TextStyle(color: kTextDark, fontSize: 15, fontWeight: FontWeight.w700)),
        const Spacer(),
        IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search_rounded, size: 20, color: kTextSub),
          onPressed: () {
            setState(() => _showSearchBar = true);
            WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocusNode.requestFocus());
          },
        ),
        IconButton(
          tooltip: 'Sort / Analyze',
          icon: const Icon(Icons.bar_chart_rounded, size: 20, color: kTextSub),
          onPressed: () {},
        ),
        IconButton(
          tooltip: 'Export to Excel',
          icon: const Icon(Icons.grid_on_rounded, size: 20, color: kGreen),
          onPressed: _exportCsv,
        ),
        IconButton(
          tooltip: 'Print / Export PDF',
          icon: const Icon(Icons.print_rounded, size: 20, color: kTextSub),
          onPressed: _exportPdf,
        ),
      ],
    );
  }

  // ── Transactions body: loading / error / empty / table ─────────────────
  Widget _buildTransactionsBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: kRed)),
      );
    }
    if (_errorMessage.isNotEmpty) {
      return _buildError();
    }
    if (_filteredInvoices.isEmpty) {
      return _buildEmpty();
    }
    return _InvoiceTable(
      invoices: _filteredInvoices,
      partyName: _partyName,
      paymentType: _paymentType,
      money0: _money0,
      onView: _navigateToViewInvoice,
      onEdit: _navigateToEditInvoice,
      onDelete: _showDeleteConfirmDialog,
      onPrint: _printInvoice,
      onShare: _shareInvoice,
      onReceivePayment: (inv) => _navigateToPaymentIn(customerName: _partyName(inv)),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Could not load invoices', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_errorMessage, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => _loadInvoices(forceRefresh: true), child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final hasActiveQuery = _searchController.text.isNotEmpty || _isFilterActive;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            Text(
              hasActiveQuery ? 'No invoices match your search/filters' : 'No sale invoices yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              hasActiveQuery ? 'Try a different search term or clear filters' : 'Tap + Add Sale to create your first invoice',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12.5),
            ),
            if (!hasActiveQuery) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: kRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: _navigateToAddInvoice,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Sale', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ] else if (_isFilterActive) ...[
              const SizedBox(height: 10),
              TextButton(onPressed: _clearFilters, child: const Text('Clear filters')),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FILTER CHIP
// ═══════════════════════════════════════════════════════════════════════════
class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.icon, required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    const blue = _InvoiceListScreenState.kBlue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? blue.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? blue.withOpacity(0.5) : _InvoiceListScreenState.kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? blue : _InvoiceListScreenState.kTextSub),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontSize: 12.5,
                color: active ? blue : _InvoiceListScreenState.kTextDark,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              )),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: active ? blue : _InvoiceListScreenState.kTextMute),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TRANSACTIONS TABLE
// ═══════════════════════════════════════════════════════════════════════════
class _InvoiceTable extends StatelessWidget {
  final List<Invoice> invoices;
  final String Function(Invoice) partyName;
  final String Function(Invoice) paymentType;
  final NumberFormat money0;
  final void Function(Invoice) onView;
  final void Function(Invoice) onEdit;
  final void Function(Invoice) onDelete;
  final void Function(Invoice) onPrint;
  final void Function(Invoice) onShare;
  final void Function(Invoice) onReceivePayment;

  const _InvoiceTable({
    required this.invoices,
    required this.partyName,
    required this.paymentType,
    required this.money0,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onPrint,
    required this.onShare,
    required this.onReceivePayment,
  });

  static const double wDate    = 88;
  static const double wInvNo   = 150;
  static const double wParty   = 150;
  static const double wTxn     = 80;
  static const double wPayType = 130;
  static const double wAmount  = 100;
  static const double wBalance = 90;
  static const double wStatus  = 84;
  static const double wActions = 110;

  // +28 accounts for the 14px horizontal padding on each side of the
  // header/data row Containers, which isn't otherwise included in the
  // fixed-width SizedBox wrapping the table (this was causing a
  // "RIGHT OVERFLOWED BY 28 PIXELS" render error).
  static const double _rowHorizontalPadding = 28;

  double get _totalWidth =>
      wDate + wInvNo + wParty + wTxn + wPayType + wAmount + wBalance + wStatus + wActions +
          _rowHorizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _InvoiceListScreenState.kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _totalWidth,
          child: Column(
            children: [
              _headerRow(),
              ...invoices.asMap().entries.map((e) => _dataRow(context, e.value, e.key)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerRow() {
    const style = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _InvoiceListScreenState.kTextSub);
    return Container(
      color: const Color(0xFFF4F6F9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        SizedBox(width: wDate, child: const Text('Date', style: style)),
        SizedBox(width: wInvNo, child: const Text('Invoice no', style: style)),
        SizedBox(width: wParty, child: const Text('Party Name', style: style)),
        SizedBox(width: wTxn, child: const Text('Transaction', style: style)),
        SizedBox(width: wPayType, child: const Text('Payment Type', style: style)),
        SizedBox(width: wAmount, child: const Text('Amount', style: style, textAlign: TextAlign.right)),
        SizedBox(width: wBalance, child: const Text('Balance', style: style, textAlign: TextAlign.right)),
        SizedBox(width: wStatus, child: const Text('Status', style: style)),
        SizedBox(width: wActions, child: const Text('Actions', style: style)),
      ]),
    );
  }

  Widget _dataRow(BuildContext context, Invoice inv, int index) {
    final status = inv.effectiveStatus;
    final color = statusColor(status);
    final hasBalance = inv.balanceDue > 0.01;
    return InkWell(
      onTap: () => onView(inv),
      child: Container(
        color: index.isOdd ? _InvoiceListScreenState.kRowAlt : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          SizedBox(
            width: wDate,
            child: Text(inv.purchaseDate, style: const TextStyle(fontSize: 12.5, color: _InvoiceListScreenState.kTextDark)),
          ),
          SizedBox(
            width: wInvNo,
            child: Text(
              inv.invoiceNo,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: _InvoiceListScreenState.kTextDark),
            ),
          ),
          SizedBox(
            width: wParty,
            child: Text(
              partyName(inv).isEmpty ? '—' : partyName(inv),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _InvoiceListScreenState.kTextDark),
            ),
          ),
          const SizedBox(
            width: wTxn,
            child: Text('Sale', style: TextStyle(fontSize: 12.5, color: _InvoiceListScreenState.kTextSub)),
          ),
          SizedBox(
            width: wPayType,
            child: Text(
              paymentType(inv),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: _InvoiceListScreenState.kTextSub),
            ),
          ),
          SizedBox(
            width: wAmount,
            child: Text(money0.format(inv.displayAmount),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _InvoiceListScreenState.kTextDark)),
          ),
          SizedBox(
            width: wBalance,
            child: Text(money0.format(inv.balanceDue),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12.5, color: _InvoiceListScreenState.kTextSub)),
          ),
          SizedBox(
            width: wStatus,
            child: Text(status, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
          ),
          SizedBox(
            width: wActions,
            child: Row(children: [
              _rowIcon(Icons.print_rounded, () => onPrint(inv)),
              _rowIcon(Icons.ios_share_rounded, () => onShare(inv)),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: _InvoiceListScreenState.kTextMute),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onSelected: (v) {
                  if (v == 'view') onView(inv);
                  if (v == 'edit') onEdit(inv);
                  if (v == 'delete') onDelete(inv);
                  if (v == 'payment') onReceivePayment(inv);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'view', child: Text('View')),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (hasBalance)
                    const PopupMenuItem(
                      value: 'payment',
                      child: Row(children: [
                        Icon(Icons.currency_rupee_rounded, size: 16, color: _InvoiceListScreenState.kGreen),
                        SizedBox(width: 8),
                        Text('Receive Payment'),
                      ]),
                    ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _rowIcon(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 16, color: _InvoiceListScreenState.kTextSub),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      onPressed: onTap,
    );
  }
}