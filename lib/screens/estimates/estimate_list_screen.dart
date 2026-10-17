// lib/screens/estimates/estimate_list_screen.dart
//
// "Estimate/Quotation" screen — styled to match the Vyapar desktop layout:
// title dropdown, search + Add Sale/Add Purchase/+ bar, filter chips
// (This Month / date range / firm / user), a Total Quotations summary
// card with a vs-last-month % badge and Converted/Open breakdown, and a
// full Transactions table with a per-row "Convert" action.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cda_inventory/services/estimate_service.dart';
import 'package:cda_inventory/services/estimate_pdf_service.dart';
import 'package:cda_inventory/models/estimate.dart';
import 'package:cda_inventory/screens/estimates/add_estimate_screen.dart';
import 'package:cda_inventory/screens/invoices/add_invoice_screen.dart';
import 'package:cda_inventory/screens/purchases/add_purchase_screen.dart';
import 'package:cda_inventory/widgets/common/sales_filters.dart';

class EstimateListScreen extends StatefulWidget {
  const EstimateListScreen({super.key});

  @override
  State<EstimateListScreen> createState() => _EstimateListScreenState();
}

class _EstimateListScreenState extends State<EstimateListScreen> {
  final EstimateService _estimateService = EstimateService();

  List<Estimate> _allEstimates      = [];
  List<Estimate> _filteredEstimates = [];

  bool _isLoading      = true;
  String _errorMessage = '';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSearchBar = false;

  // ── Filters: "This Month / Pick a date / All Firms / All Users" row,
  //    mirroring the reference design exactly ───────────────────────────
  String _periodFilter = SalesPeriod.thisMonth;
  String _statusFilter = kFilterAll;
  String _branchFilter = kFilterAll;
  String _userFilter   = kFilterAll;
  DateTimeRange? _dateRangeFilter;

  List<FilterOption> _branchOptions = SalesFilterData.branchOptions(const []);
  List<FilterOption> _userOptions   = [];

  bool get _isFilterActive =>
      _statusFilter != kFilterAll ||
          _branchFilter != kFilterAll ||
          _userFilter != kFilterAll ||
          _periodFilter != SalesPeriod.thisMonth;

  // ── Design tokens (same palette as the rest of the app's Vyapar-style
  //    screens — Sale Invoices / Purchases) ────────────────────────────
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

  static final NumberFormat _money2 =
  NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final NumberFormat _money0 =
  NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _dateRangeFilter = SalesPeriod.rangeFor(SalesPeriod.thisMonth);
    _searchController.addListener(_applySortAndFilter);
    _loadEstimates();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applySortAndFilter);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadEstimates({bool forceRefresh = false}) async {
    setState(() {
      _isLoading    = true;
      _errorMessage = '';
    });
    try {
      final estimates = await _estimateService.fetchEstimates(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _allEstimates = estimates;
        _branchOptions =
            SalesFilterData.branchOptions(estimates.map((e) => e.branch));
        // "All Users" lists the PARTY (customer) names, not app users.
        _userOptions = SalesFilterData.partyOptions(estimates.map((e) => e.partyName));
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
    final filtered = _allEstimates.where((est) {
      final matchesQuery = query.isEmpty ||
          est.referenceNo.toLowerCase().contains(query) ||
          est.partyName.toLowerCase().contains(query);
      final matchesStatus = _statusFilter == kFilterAll || est.effectiveStatus == _statusFilter;
      final matchesBranch = SalesFilterData.branchMatches(_branchFilter, est.branch);
      final matchesUser   = SalesFilterData.userMatches(_userFilter, est.partyName);
      final matchesDate   = SalesPeriod.inRange(est.estimateDateTime, _dateRangeFilter);

      return matchesQuery && matchesStatus && matchesBranch && matchesUser && matchesDate;
    }).toList()
      ..sort((a, b) => (b.estimateDateTime ?? DateTime(2000))
          .compareTo(a.estimateDateTime ?? DateTime(2000)));

    setState(() => _filteredEstimates = filtered);
  }

  void _clearFilters() {
    setState(() {
      _statusFilter = kFilterAll;
      _branchFilter = kFilterAll;
      _userFilter   = kFilterAll;
      _periodFilter = SalesPeriod.thisMonth;
      _dateRangeFilter = SalesPeriod.rangeFor(SalesPeriod.thisMonth);
    });
    _applySortAndFilter();
  }

  // ── Totals for the summary card ─────────────────────────────────────
  double get _totalQuotations =>
      _filteredEstimates.fold(0.0, (sum, e) => sum + e.grandTotal);
  double get _totalConverted => _filteredEstimates
      .where((e) => e.isConverted)
      .fold(0.0, (sum, e) => sum + e.grandTotal);
  double get _totalOpen => _filteredEstimates
      .where((e) => !e.isConverted)
      .fold(0.0, (sum, e) => sum + e.grandTotal);

  // % change vs last month, computed from the full (unfiltered-by-date) list
  double? get _percentVsLastMonth {
    final now = DateTime.now();
    final thisStart = DateTime(now.year, now.month, 1);
    final lastStart = DateTime(now.year, now.month - 1, 1);
    final lastEnd = DateTime(now.year, now.month, 0);

    double sumInRange(DateTime start, DateTime end) => _allEstimates
        .where((e) {
      final d = e.estimateDateTime;
      return d != null && !d.isBefore(start) && !d.isAfter(end);
    })
        .fold(0.0, (sum, e) => sum + e.grandTotal);

    final thisMonthTotal = sumInRange(thisStart, now);
    final lastMonthTotal = sumInRange(lastStart, lastEnd);
    if (lastMonthTotal <= 0) return null;
    return ((thisMonthTotal - lastMonthTotal) / lastMonthTotal) * 100;
  }

  // ── Delete ───────────────────────────────────────────────────────────
  void _showDeleteConfirmDialog(Estimate estimate) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.delete_outline_rounded, color: kRed),
          SizedBox(width: 8),
          Text('Delete Estimate', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        content: Text(
          'Delete estimate #${estimate.referenceNo}? This action cannot be undone.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteEstimate(estimate);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEstimate(Estimate estimate) async {
    try {
      await _estimateService.deleteEstimate(estimate.id!);
      setState(() => _allEstimates.removeWhere((e) => e.id == estimate.id));
      _applySortAndFilter();
      if (mounted) _showSnack('Estimate #${estimate.referenceNo} deleted');
    } catch (e) {
      if (mounted) _showSnack('Failed to delete: $e', isError: true);
    }
  }

  // ── Convert to Sale Invoice ─────────────────────────────────────────
  Future<void> _convertToInvoice(Estimate estimate) async {
    if (estimate.isConverted) {
      _showSnack('Already converted to invoice ${estimate.convertedInvoiceNo ?? ''}');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Convert to Sale Invoice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          'Convert estimate #${estimate.referenceNo} (${_money2.format(estimate.grandTotal)}) into a Sale Invoice?',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final nextInvNo = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      final invoice = await _estimateService.convertToInvoice(estimate, newInvoiceNo: nextInvNo);
      _showSnack('Converted to invoice ${invoice.invoiceNo}');
      _loadEstimates(forceRefresh: true);
    } catch (e) {
      _showSnack('Conversion failed: $e', isError: true);
    }
  }

  Future<void> _duplicateAsProforma(Estimate estimate) async {
    try {
      final nextRef = await _estimateService.suggestNextReferenceNumber(forceRefresh: true);
      final clone = estimate.copyWith(
        clearId: true,
        referenceNo: nextRef,
        status: 'Open',
        convertedInvoiceId: null,
        convertedInvoiceNo: null,
      );
      await _estimateService.createEstimate(clone);
      _showSnack('Duplicated as estimate #$nextRef');
      _loadEstimates(forceRefresh: true);
    } catch (e) {
      _showSnack('Failed to duplicate: $e', isError: true);
    }
  }

  // ── Print — SkyLynk-branded PDF, same letterhead/pattern as the Tax
  // Invoice, opened in the browser's print/preview dialog ────────────────
  Future<void> _printEstimate(Estimate estimate) async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) => EstimatePdfService.generate(estimate),
        name: 'estimate_${estimate.referenceNo}.pdf',
      );
    } catch (e) {
      if (mounted) _showSnack('Failed to generate PDF: $e', isError: true);
    }
  }

  // ── Share — sends the generated PDF straight to WhatsApp/Email/etc via
  // the native share sheet (Print above just opens the print/preview
  // dialog, which isn't the same as directly sharing the file) ───────────
  Future<void> _shareEstimate(Estimate estimate) async {
    try {
      final bytes = await EstimatePdfService.generate(estimate);
      await Printing.sharePdf(bytes: bytes, filename: 'estimate_${estimate.referenceNo}.pdf');
    } catch (e) {
      if (mounted) _showSnack('Failed to share estimate: $e', isError: true);
    }
  }

  // ── Export (bulk) ─────────────────────────────────────────────────────
  Future<void> _exportCsv() async {
    if (_filteredEstimates.isEmpty) {
      _showSnack('Nothing to export', isError: true);
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('Date,Reference No,Party Name,Amount,Balance,Status');
    for (final e in _filteredEstimates) {
      buffer.writeln(
        '${e.estimateDate},${e.referenceNo},${e.partyName},'
            '${e.grandTotal.toStringAsFixed(2)},${e.balanceDue.toStringAsFixed(2)},${e.effectiveStatus}',
      );
    }
    await Share.share(buffer.toString(), subject: 'Estimate/Quotation Export (${_filteredEstimates.length})');
  }

  Future<void> _exportPdf() async {
    if (_filteredEstimates.isEmpty) {
      _showSnack('Nothing to export', isError: true);
      return;
    }
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: 'Estimate / Quotation Report'),
          pw.Table.fromTextArray(
            headers: ['Date', 'Reference no', 'Party Name', 'Amount', 'Balance', 'Status'],
            data: _filteredEstimates
                .map((e) => [
              e.estimateDate,
              e.referenceNo,
              e.partyName,
              e.grandTotal.toStringAsFixed(2),
              e.balanceDue.toStringAsFixed(2),
              e.effectiveStatus,
            ])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Total Quotations: Rs. ${_totalQuotations.toStringAsFixed(2)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'estimate_quotation_report.pdf');
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

  // ── Navigation ───────────────────────────────────────────────────────
  void _navigateToAddEstimate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'Add Estimate'), builder: (_) => const AddEstimateScreen()),
    );
    if (result == true) _loadEstimates(forceRefresh: true);
  }

  void _navigateToEditEstimate(Estimate estimate) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Add Estimate'),
        builder: (_) => AddEstimateScreen(estimateToEdit: estimate),
      ),
    );
    if (result == true) _loadEstimates(forceRefresh: true);
  }

  void _navigateToAddSale() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'Add Invoice'), builder: (_) => const AddInvoiceScreen()),
    );
    if (result == true) _loadEstimates(forceRefresh: true);
  }

  void _navigateToAddPurchase() async {
    await Navigator.push(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'Add Purchase'), builder: (_) => const AddPurchaseScreen()),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: kRed,
        onRefresh: () => _loadEstimates(forceRefresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              const SizedBox(height: 14),
              _buildEstimateTitleRow(),
              const SizedBox(height: 12),
              _buildFilterRow(),
              const SizedBox(height: 14),
              _buildTotalQuotationsCard(),
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: kTextDark,
      elevation: 0.5,
      titleSpacing: 4,
      title: const Text('Estimate / Quotation',
          style: TextStyle(color: kTextDark, fontWeight: FontWeight.w700, fontSize: 17)),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => _loadEstimates(forceRefresh: true),
        ),
      ],
    );
  }

  // ── Top bar: search + Add Sale + Add Purchase + quick-add + print ──────
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
                hintStyle: const TextStyle(color: kTextMute, fontSize: 14),
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
                Expanded(
                  child: Text('Search Transactions',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: kTextMute, fontSize: 14)),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: _navigateToAddSale,
          style: OutlinedButton.styleFrom(
            foregroundColor: kRed,
            side: const BorderSide(color: kRed),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Sale', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _navigateToAddPurchase,
          style: OutlinedButton.styleFrom(
            foregroundColor: kBlue,
            side: const BorderSide(color: kBlue),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Purchase', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: kNavy,
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            tooltip: 'Quick Add',
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            onPressed: () => _showQuickAddMenu(),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Print',
          icon: const Icon(Icons.print_rounded, color: kTextSub),
          onPressed: _exportPdf,
        ),
      ],
    );
  }

  void _showQuickAddMenu() async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 80, 12, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: const [
        PopupMenuItem(value: 'estimate', child: Text('Add Estimate')),
        PopupMenuItem(value: 'sale', child: Text('Add Sale')),
        PopupMenuItem(value: 'purchase', child: Text('Add Purchase')),
      ],
    );
    if (selected == 'estimate') _navigateToAddEstimate();
    if (selected == 'sale') _navigateToAddSale();
    if (selected == 'purchase') _navigateToAddPurchase();
  }

  // ── Title row: "Estimate/Quotation ⌄" + "+ Add Estimate" ───────────────
  Widget _buildEstimateTitleRow() {
    return Row(
      children: [
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(8),
          child: Row(children: const [
            Text('Estimate/Quotation',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextDark)),
            SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, color: kTextSub),
          ]),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _navigateToAddEstimate,
          style: ElevatedButton.styleFrom(
            backgroundColor: kRed,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Estimate', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ],
    );
  }

  // ── Filter chip row: period / date range / firm / user / status ───────
  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        const Text('Filter by :',
            style: TextStyle(fontSize: 12.5, color: kTextSub, fontWeight: FontWeight.w600)),
        const SizedBox(width: 10),
        SalesFilterChip(
          icon: Icons.calendar_month_rounded,
          label: _periodFilter,
          active: _periodFilter != SalesPeriod.thisMonth,
          onTap: _showPeriodMenu,
        ),
        const SizedBox(width: 8),
        SalesFilterChip(
          icon: Icons.calendar_today_rounded,
          label: _dateRangeFilter == null
              ? 'Pick a date'
              : SalesPeriod.rangeLabel(_dateRangeFilter!),
          active: _dateRangeFilter != null,
          onTap: _pickDateRange,
        ),
        const SizedBox(width: 8),
        SalesFilterChip(
          icon: Icons.apartment_rounded,
          label: SalesFilterData.labelFor(_branchOptions, _branchFilter, 'All Firms'),
          active: _branchFilter != kFilterAll,
          onTap: () async {
            final v = await showSalesOptionSheet(
              context,
              title: 'Firm / Branch',
              allLabel: 'All Firms',
              options: _branchOptions,
              current: _branchFilter,
            );
            if (v == null) return;
            setState(() => _branchFilter = v);
            _applySortAndFilter();
          },
        ),
        const SizedBox(width: 8),
        SalesFilterChip(
          icon: Icons.person_outline_rounded,
          label: SalesFilterData.labelFor(_userOptions, _userFilter, 'All Users'),
          active: _userFilter != kFilterAll,
          onTap: () async {
            final v = await showSalesOptionSheet(
              context,
              title: 'Party',
              allLabel: 'All Users',
              options: _userOptions,
              current: _userFilter,
              emptyText: 'No parties yet',
            );
            if (v == null) return;
            setState(() => _userFilter = v);
            _applySortAndFilter();
          },
        ),
        const SizedBox(width: 8),
        SalesFilterChip(
          icon: Icons.filter_list_rounded,
          label: _statusFilter == kFilterAll ? 'All Status' : _statusFilter,
          active: _statusFilter != kFilterAll,
          onTap: _showStatusMenu,
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

  Future<void> _showPeriodMenu() async {
    final v = await showSalesOptionSheet(
      context,
      title: 'Select period',
      options: SalesPeriod.options.map((o) => FilterOption(o, o)).toList(),
      current: _periodFilter,
    );
    if (v == null) return;
    if (v == SalesPeriod.custom) {
      await _pickDateRange();
      return;
    }
    setState(() {
      _periodFilter = v;
      _dateRangeFilter = SalesPeriod.rangeFor(v); // null for "All Time"
    });
    _applySortAndFilter();
  }

  Future<void> _showStatusMenu() async {
    final v = await showSalesOptionSheet(
      context,
      title: 'Estimate status',
      allLabel: 'All Status',
      options: Estimate.statusOptions.map((o) => FilterOption(o, o)).toList(),
      current: _statusFilter,
    );
    if (v == null) return;
    setState(() => _statusFilter = v);
    _applySortAndFilter();
  }

  Future<void> _pickDateRange() async {
    final picked = await showSalesDateRangePicker(
      context,
      initial: _dateRangeFilter,
    );
    if (picked == null) return;
    setState(() {
      _dateRangeFilter = picked;
      _periodFilter = SalesPeriod.custom;
    });
    _applySortAndFilter();
  }

  // ── Total Quotations summary card ───────────────────────────────────
  Widget _buildTotalQuotationsCard() {
    final pct = _percentVsLastMonth;
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
          Row(children: [
            const Text('Total Quotations',
                style: TextStyle(color: kTextSub, fontSize: 12.5, fontWeight: FontWeight.w600)),
            if (pct != null) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (pct >= 0 ? kGreen : kRed).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(pct >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 12, color: pct >= 0 ? kGreen : kRed),
                  const SizedBox(width: 2),
                  Text('${pct.abs().toStringAsFixed(2)}%',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: pct >= 0 ? kGreen : kRed)),
                ]),
              ),
            ],
          ]),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              _isLoading ? '—' : _money2.format(_totalQuotations),
              style: const TextStyle(color: kTextDark, fontSize: 24, fontWeight: FontWeight.w800),
            ),
            if (pct != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('vs last month', style: TextStyle(color: kTextMute, fontSize: 11.5)),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Converted: ${_isLoading ? '—' : _money2.format(_totalConverted)}',
                  style: const TextStyle(color: kTextMute, fontSize: 12.5)),
              const Text('|', style: TextStyle(color: kTextMute)),
              Text('Open: ${_isLoading ? '—' : _money2.format(_totalOpen)}',
                  style: const TextStyle(color: kTextMute, fontSize: 12.5)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Transactions header ─────────────────────────────────────────────
  Widget _buildTransactionsHeader() {
    return Row(
      children: [
        const Text('Transactions', style: TextStyle(color: kTextDark, fontSize: 15, fontWeight: FontWeight.w700)),
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

  // ── Transactions body: loading / error / empty / table ──────────────
  Widget _buildTransactionsBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: kRed)),
      );
    }
    if (_errorMessage.isNotEmpty) return _buildError();
    if (_filteredEstimates.isEmpty) return _buildEmpty();

    return _EstimateTable(
      estimates: _filteredEstimates,
      money0: _money0,
      onView: _navigateToEditEstimate,
      onEdit: _navigateToEditEstimate,
      onDelete: _showDeleteConfirmDialog,
      onConvert: _convertToInvoice,
      onDuplicate: _duplicateAsProforma,
      onPrint: _printEstimate,
      onShare: _shareEstimate,
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
            Text('Could not load estimates', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_errorMessage, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => _loadEstimates(forceRefresh: true), child: const Text('Retry')),
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
            Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            Text(
              hasActiveQuery ? 'No estimates match your search/filters' : 'No estimates/quotations yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              hasActiveQuery ? 'Try a different search term or clear filters' : 'Tap + Add Estimate to create your first quotation',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12.5),
            ),
            if (!hasActiveQuery) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: kRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: _navigateToAddEstimate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Estimate', style: TextStyle(fontWeight: FontWeight.w700)),
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
// TRANSACTIONS TABLE
// ═══════════════════════════════════════════════════════════════════════════
class _EstimateTable extends StatelessWidget {
  final List<Estimate> estimates;
  final NumberFormat money0;
  final void Function(Estimate) onView;
  final void Function(Estimate) onEdit;
  final void Function(Estimate) onDelete;
  final void Function(Estimate) onConvert;
  final void Function(Estimate) onDuplicate;
  final void Function(Estimate) onPrint;
  final void Function(Estimate) onShare;

  const _EstimateTable({
    required this.estimates,
    required this.money0,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onConvert,
    required this.onDuplicate,
    required this.onPrint,
    required this.onShare,
  });

  static const double wDate    = 88;
  static const double wRefNo   = 90;
  static const double wParty   = 180;
  static const double wAmount  = 110;
  static const double wBalance = 100;
  static const double wStatus  = 90;
  static const double wConvert = 100;
  static const double wActions = 60;

  static const double _colGap = 8; // gap between adjacent columns
  static const double _rowHorizontalPadding = 28; // 14px each side, added by header/data row Containers

  double get _totalWidth =>
      wDate + wRefNo + wParty + wAmount + wBalance + wStatus + wConvert + wActions +
          (_colGap * 7) + _rowHorizontalPadding;

  static const Color kBorder   = Color(0xFFE7EAF0);
  static const Color kTextDark = Color(0xFF1F2937);
  static const Color kTextSub  = Color(0xFF6B7280);
  static const Color kTextMute = Color(0xFF9CA3AF);
  static const Color kRowAlt   = Color(0xFFF7F9FC);
  static const Color kBlue     = Color(0xFF2F6FE4);
  static const Color kGreen    = Color(0xFF00B894);
  static const Color kAmber    = Color(0xFFFFB800);
  static const Color kGrey     = Color(0xFF9CA3AF);

  Color _statusColor(String status) {
    switch (status) {
      case 'Converted':
        return kGreen;
      case 'Expired':
        return kGrey;
      case 'Open':
      default:
        return kAmber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _totalWidth,
          child: Column(children: [
            _headerRow(),
            ...estimates.asMap().entries.map((e) => _dataRow(context, e.value, e.key)),
          ]),
        ),
      ),
    );
  }

  Widget _headerRow() {
    const style = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kTextSub);
    return Container(
      color: const Color(0xFFF4F6F9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        SizedBox(width: wDate, child: const Text('Date', style: style)),
        const SizedBox(width: _colGap),
        SizedBox(width: wRefNo, child: const Text('Reference no', style: style)),
        const SizedBox(width: _colGap),
        SizedBox(width: wParty, child: const Text('Party Name', style: style)),
        const SizedBox(width: _colGap),
        SizedBox(width: wAmount, child: const Text('Amount', style: style, textAlign: TextAlign.right)),
        const SizedBox(width: _colGap),
        SizedBox(width: wBalance, child: const Text('Balance', style: style, textAlign: TextAlign.right)),
        const SizedBox(width: _colGap),
        SizedBox(width: wStatus, child: const Text('Status', style: style)),
        const SizedBox(width: _colGap),
        SizedBox(width: wConvert, child: const Text('Actions', style: style)),
        const SizedBox(width: _colGap),
        SizedBox(width: wActions, child: const Text('', style: style)),
      ]),
    );
  }

  Widget _dataRow(BuildContext context, Estimate est, int index) {
    final status = est.effectiveStatus;
    final color = _statusColor(status);
    return InkWell(
      onTap: () => onView(est),
      child: Container(
        color: index.isOdd ? kRowAlt : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          SizedBox(width: wDate, child: Text(est.estimateDate, style: const TextStyle(fontSize: 12.5, color: kTextDark))),
          const SizedBox(width: _colGap),
          SizedBox(width: wRefNo, child: Text(est.referenceNo, style: const TextStyle(fontSize: 12.5, color: kTextDark))),
          const SizedBox(width: _colGap),
          SizedBox(
            width: wParty,
            child: Text(
              est.partyName.isEmpty ? '—' : est.partyName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextDark),
            ),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: wAmount,
            child: Text(money0.format(est.grandTotal),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextDark)),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: wBalance,
            child: Text(money0.format(est.balanceDue),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12.5, color: kTextSub)),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: wStatus,
            child: Text(status, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: wConvert,
            child: est.isConverted
                ? Text('Converted', style: const TextStyle(fontSize: 12.5, color: kGreen, fontWeight: FontWeight.w600))
                : InkWell(
              onTap: () => _showConvertMenu(context, est),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Text('Convert', style: TextStyle(fontSize: 12.5, color: kBlue, fontWeight: FontWeight.w700)),
                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: kBlue),
              ]),
            ),
          ),
          const SizedBox(width: _colGap),
          SizedBox(
            width: wActions,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18, color: kTextMute),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (v) {
                if (v == 'view') onView(est);
                if (v == 'edit') onEdit(est);
                if (v == 'print') onPrint(est);
                if (v == 'share') onShare(est);
                if (v == 'duplicate') onDuplicate(est);
                if (v == 'delete') onDelete(est);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'view', child: Text('View')),
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'print', child: Text('Print')),
                PopupMenuItem(value: 'share', child: Text('Share')),
                PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  void _showConvertMenu(BuildContext context, Estimate est) async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 300, 24, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: const [
        PopupMenuItem(value: 'invoice', child: Text('Convert to Sale Invoice')),
      ],
    );
    if (selected == 'invoice') onConvert(est);
  }
}