// lib/screens/proforma/proforma_list_screen.dart
//
// "Proforma Invoice" screen — styled to match the Vyapar desktop layout
// (filter row, a Total Proforma summary card with a vs-last-month % badge
// and Converted/Open breakdown, and a full transactions list with
// per-row actions), fully wired up: no subscription paywall, every action
// hits real Firestore data through ProformaService.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cda_inventory/services/proforma_service.dart';
import 'package:cda_inventory/services/proforma_pdf_service.dart';
import 'package:cda_inventory/models/proforma_invoice.dart';
import 'package:cda_inventory/screens/proforma/add_proforma_screen.dart';

class ProformaListScreen extends StatefulWidget {
  const ProformaListScreen({super.key});

  @override
  State<ProformaListScreen> createState() => _ProformaListScreenState();
}

class _ProformaListScreenState extends State<ProformaListScreen> {
  final ProformaService _service = ProformaService();

  List<ProformaInvoice> _all = [];
  List<ProformaInvoice> _filtered = [];

  bool _isLoading = true;
  String _errorMessage = '';

  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;

  static const List<String> _periodOptions = [
    'Today', 'This Week', 'This Month', 'This Quarter', 'This Year', 'All Time', 'Custom'
  ];
  String _periodFilter = 'This Month';
  String _statusFilter = 'All';
  String _branchFilter = 'All';
  DateTimeRange? _dateRangeFilter;

  List<String> _branchList = [];

  bool get _isFilterActive => _statusFilter != 'All' || _branchFilter != 'All';

  // ── Design tokens (same palette as Estimate/Sale Invoice list screens) ──
  static const Color kBg       = Color(0xFFF4F6F9);
  static const Color kNavy     = Color(0xFF0A1628);
  static const Color kRed      = Color(0xFFE94D5F);
  static const Color kBlue     = Color(0xFF2F6FE4);
  static const Color kTeal     = Color(0xFF00D4AA);
  static const Color kGreen    = Color(0xFF00B894);
  static const Color kAmber    = Color(0xFFFFB800);
  static const Color kBorder   = Color(0xFFE7EAF0);
  static const Color kTextDark = Color(0xFF1F2937);
  static const Color kTextSub  = Color(0xFF6B7280);
  static const Color kTextMute = Color(0xFF9CA3AF);
  static const Color kRowAlt   = Color(0xFFF7F9FC);

  static final NumberFormat _money2 =
  NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _dateRangeFilter = _rangeForThisMonth();
    _searchController.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  DateTimeRange _rangeForThisMonth() {
    final now = DateTime.now();
    return DateTimeRange(start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month + 1, 0));
  }

  DateTimeRange? _rangeForPeriod(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'Today':
        return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now);
      case 'This Week':
        final start = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(start: DateTime(start.year, start.month, start.day), end: now);
      case 'This Month':
        return _rangeForThisMonth();
      case 'This Quarter':
        final qStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return DateTimeRange(start: DateTime(now.year, qStartMonth, 1), end: now);
      case 'This Year':
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
      case 'All Time':
        return null;
      default:
        return _dateRangeFilter;
    }
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final list = await _service.fetchProformas(forceRefresh: forceRefresh);
      setState(() {
        _all = list;
        _branchList = list.map((p) => p.branch ?? '').where((v) => v.isNotEmpty).toSet().toList()..sort();
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    final filtered = _all.where((p) {
      final matchesQuery = query.isEmpty ||
          p.proformaNo.toLowerCase().contains(query) ||
          p.partyName.toLowerCase().contains(query);
      final matchesStatus = _statusFilter == 'All' || p.effectiveStatus == _statusFilter;
      final matchesBranch = _branchFilter == 'All' || (p.branch ?? '') == _branchFilter;

      bool matchesDate = true;
      if (_dateRangeFilter != null) {
        final d = p.proformaDateTime;
        matchesDate = d != null &&
            !d.isBefore(_dateRangeFilter!.start) &&
            !d.isAfter(_dateRangeFilter!.end);
      }
      return matchesQuery && matchesStatus && matchesBranch && matchesDate;
    }).toList()
      ..sort((a, b) => (b.proformaDateTime ?? DateTime(2000)).compareTo(a.proformaDateTime ?? DateTime(2000)));

    setState(() => _filtered = filtered);
  }

  void _onPeriodChanged(String period) {
    setState(() {
      _periodFilter = period;
      _dateRangeFilter = _rangeForPeriod(period);
    });
    _applyFilter();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _dateRangeFilter,
    );
    if (picked != null) {
      setState(() {
        _periodFilter = 'Custom';
        _dateRangeFilter = picked;
      });
      _applyFilter();
    }
  }

  // ── Totals for the summary card ─────────────────────────────────────
  double get _totalProforma => _filtered.fold(0.0, (sum, p) => sum + p.grandTotal);
  double get _totalConverted => _filtered.where((p) => p.isConverted).fold(0.0, (sum, p) => sum + p.grandTotal);
  double get _totalOpen => _filtered.where((p) => !p.isConverted).fold(0.0, (sum, p) => sum + p.grandTotal);

  double? get _percentVsLastMonth {
    final now = DateTime.now();
    final thisStart = DateTime(now.year, now.month, 1);
    final lastStart = DateTime(now.year, now.month - 1, 1);
    final lastEnd = DateTime(now.year, now.month, 0);

    double sumInRange(DateTime start, DateTime end) => _all.where((p) {
      final d = p.proformaDateTime;
      return d != null && !d.isBefore(start) && !d.isAfter(end);
    }).fold(0.0, (sum, p) => sum + p.grandTotal);

    final thisMonthTotal = sumInRange(thisStart, now);
    final lastMonthTotal = sumInRange(lastStart, lastEnd);
    if (lastMonthTotal <= 0) return null;
    return ((thisMonthTotal - lastMonthTotal) / lastMonthTotal) * 100;
  }

  // ── Actions ──────────────────────────────────────────────────────────
  void _showDeleteConfirm(ProformaInvoice p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.delete_outline_rounded, color: kRed),
          SizedBox(width: 8),
          Text('Delete Proforma', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        content: Text(
          'Delete proforma #${p.proformaNo}? This action cannot be undone.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx);
              await _delete(p);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(ProformaInvoice p) async {
    try {
      await _service.deleteProforma(p.id!);
      setState(() => _all.removeWhere((e) => e.id == p.id));
      _applyFilter();
      if (mounted) _showSnack('Proforma #${p.proformaNo} deleted');
    } catch (e) {
      if (mounted) _showSnack('Failed to delete: $e', isError: true);
    }
  }

  Future<void> _convertToInvoice(ProformaInvoice p) async {
    if (p.isConverted) {
      _showSnack('Already converted to invoice ${p.convertedInvoiceNo ?? ''}');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Convert to Sale Invoice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          'Convert proforma #${p.proformaNo} (${_money2.format(p.grandTotal)}) into a Sale Invoice?',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final nextInvNo = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      final invoice = await _service.convertToInvoice(p, newInvoiceNo: nextInvNo);
      _showSnack('Converted to invoice ${invoice.invoiceNo}');
      _load(forceRefresh: true);
    } catch (e) {
      _showSnack('Conversion failed: $e', isError: true);
    }
  }

  Future<void> _duplicate(ProformaInvoice p) async {
    try {
      final nextNo = await _service.suggestNextProformaNumber(forceRefresh: true);
      final clone = p.copyWith(
        clearId: true,
        proformaNo: nextNo,
        status: 'Open',
        convertedInvoiceId: null,
        convertedInvoiceNo: null,
        proformaDate:
        '${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().year}',
      );
      await _service.createProforma(clone);
      _showSnack('Duplicated as proforma #$nextNo');
      _load(forceRefresh: true);
    } catch (e) {
      _showSnack('Failed to duplicate: $e', isError: true);
    }
  }

  Future<void> _sharePdf(ProformaInvoice p) async {
    final bytes = await ProformaPdfService.generate(p);
    await Printing.sharePdf(bytes: bytes, filename: 'proforma_${p.proformaNo}.pdf');
  }

  Future<void> _printPdf(ProformaInvoice p) async {
    await Printing.layoutPdf(onLayout: (format) => ProformaPdfService.generate(p));
  }

  Future<void> _exportCsv() async {
    if (_filtered.isEmpty) {
      _showSnack('Nothing to export', isError: true);
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('Date,Proforma No,Party Name,Amount,Status');
    for (final p in _filtered) {
      buffer.writeln('${p.proformaDate},${p.proformaNo},${p.partyName},${p.grandTotal.toStringAsFixed(2)},${p.effectiveStatus}');
    }
    await Share.share(buffer.toString(), subject: 'Proforma Invoice Export (${_filtered.length})');
  }

  Future<void> _exportPdf() async {
    if (_filtered.isEmpty) {
      _showSnack('Nothing to export', isError: true);
      return;
    }
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: 'Proforma Invoice Report'),
          pw.Table.fromTextArray(
            headers: ['Date', 'Proforma No', 'Party Name', 'Amount', 'Status'],
            data: _filtered
                .map((p) => [p.proformaDate, p.proformaNo, p.partyName, p.grandTotal.toStringAsFixed(2), p.effectiveStatus])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Total Proforma: Rs. ${_totalProforma.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'proforma_invoice_report.pdf');
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

  void _navigateToAdd() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'Add Proforma'), builder: (_) => const AddProformaScreen()),
    );
    if (result == true) _load(forceRefresh: true);
  }

  void _navigateToEdit(ProformaInvoice p) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'Add Proforma'), builder: (_) => AddProformaScreen(proformaToEdit: p)),
    );
    if (result == true) _load(forceRefresh: true);
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: kTextDark,
        titleSpacing: 16,
        title: Row(children: [
          const Text('Proforma Invoice', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: kTextDark)),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down_rounded, color: kTextMute),
        ]),
        actions: [
          IconButton(
            icon: Icon(_showSearchBar ? Icons.close_rounded : Icons.search_rounded, color: kTextDark),
            onPressed: () => setState(() => _showSearchBar = !_showSearchBar),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: kTextDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'csv') _exportCsv();
              if (v == 'pdf') _exportPdf();
              if (v == 'refresh') _load(forceRefresh: true);
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'refresh', child: Text('Refresh')),
              PopupMenuItem(value: 'csv', child: Text('Export as Excel/CSV')),
              PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAdd,
        backgroundColor: kRed,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Proforma', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(forceRefresh: true),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
            ? _errorState()
            : ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            if (_showSearchBar) ...[_searchBar(), const SizedBox(height: 12)],
            _filterRow(),
            const SizedBox(height: 14),
            _summaryCard(),
            const SizedBox(height: 16),
            if (_filtered.isEmpty) _emptyState() else ..._filtered.map(_proformaCard),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: kRed),
          const SizedBox(height: 12),
          Text('Failed to load: $_errorMessage', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => _load(forceRefresh: true), child: const Text('Retry')),
        ]),
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search by proforma no. or party name',
          prefixIcon: const Icon(Icons.search_rounded, color: kTextMute),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _filterRow() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Filter by :', style: TextStyle(fontSize: 13, color: kTextSub, fontWeight: FontWeight.w600)),
        _dropdownChip(
          label: _periodFilter,
          onTap: () async {
            final selected = await showModalBottomSheet<String>(
              context: context,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (ctx) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: _periodOptions
                    .map((p) => ListTile(title: Text(p), onTap: () => Navigator.pop(ctx, p)))
                    .toList()),
              ),
            );
            if (selected == 'Custom') {
              _onPeriodChanged('Custom');
              await _pickCustomRange();
            } else if (selected != null) {
              _onPeriodChanged(selected);
            }
          },
        ),
        if (_dateRangeFilter != null)
          _dropdownChip(
            label: '${DateFormat('dd/MM/yyyy').format(_dateRangeFilter!.start)} – ${DateFormat('dd/MM/yyyy').format(_dateRangeFilter!.end)}',
            onTap: _pickCustomRange,
            icon: Icons.calendar_today_rounded,
          ),
        _dropdownChip(
          label: _branchFilter == 'All' ? 'All Firms' : _branchFilter,
          onTap: () async {
            final selected = await showModalBottomSheet<String>(
              context: context,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (ctx) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: ['All', ..._branchList]
                    .map((b) => ListTile(title: Text(b == 'All' ? 'All Firms' : b), onTap: () => Navigator.pop(ctx, b)))
                    .toList()),
              ),
            );
            if (selected != null) {
              setState(() => _branchFilter = selected);
              _applyFilter();
            }
          },
        ),
        _dropdownChip(
          label: _statusFilter == 'All' ? 'All Status' : _statusFilter,
          onTap: () async {
            final selected = await showModalBottomSheet<String>(
              context: context,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (ctx) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: ['All', ...ProformaInvoice.statusOptions]
                    .map((s) => ListTile(title: Text(s == 'All' ? 'All Status' : s), onTap: () => Navigator.pop(ctx, s)))
                    .toList()),
              ),
            );
            if (selected != null) {
              setState(() => _statusFilter = selected);
              _applyFilter();
            }
          },
        ),
        if (_isFilterActive)
          TextButton(
            onPressed: () {
              setState(() {
                _statusFilter = 'All';
                _branchFilter = 'All';
              });
              _applyFilter();
            },
            child: const Text('Clear', style: TextStyle(color: kRed, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  Widget _dropdownChip({required String label, required VoidCallback onTap, IconData? icon}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: kTextSub), const SizedBox(width: 6)],
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextDark)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: kTextMute),
        ]),
      ),
    );
  }

  Widget _summaryCard() {
    final pct = _percentVsLastMonth;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Total Proforma', style: TextStyle(fontSize: 13.5, color: kTextSub, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (pct != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: (pct >= 0 ? kGreen : kRed).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(pct >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 12, color: pct >= 0 ? kGreen : kRed),
                const SizedBox(width: 2),
                Text('${pct.abs().toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: pct >= 0 ? kGreen : kRed)),
              ]),
            ),
        ]),
        const SizedBox(height: 4),
        Text(_money2.format(_totalProforma), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kTextDark)),
        Text('vs last month', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Row(children: [
          _breakdownItem('Converted', _totalConverted, kGreen),
          const SizedBox(width: 20),
          _breakdownItem('Open', _totalOpen, kAmber),
        ]),
      ]),
    );
  }

  Widget _breakdownItem(String label, double amount, Color color) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text('$label: ', style: TextStyle(fontSize: 12.5, color: kTextSub)),
      Text(_money2.format(amount), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextDark)),
    ]);
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(children: [
        Container(
          width: 84, height: 84,
          decoration: BoxDecoration(color: kBlue.withOpacity(0.08), shape: BoxShape.circle),
          child: const Icon(Icons.description_outlined, size: 40, color: kBlue),
        ),
        const SizedBox(height: 18),
        const Text('No Transactions to show', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextDark)),
        const SizedBox(height: 6),
        Text("You haven't added any proforma invoices yet.", style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _navigateToAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Proforma'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
        ),
      ]),
    );
  }

  Widget _proformaCard(ProformaInvoice p) {
    final statusColor = switch (p.effectiveStatus) {
      'Converted' => kGreen,
      'Expired' => kRed,
      _ => kAmber,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _navigateToEdit(p),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.partyName.isEmpty ? '(No party name)' : p.partyName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextDark)),
                  const SizedBox(height: 2),
                  Text('#${p.proformaNo}  •  ${p.proformaDate}', style: TextStyle(fontSize: 12, color: kTextSub)),
                  if ((p.validTill ?? '').isNotEmpty)
                    Text('Valid till ${p.validTill}', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade400)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_money2.format(p.grandTotal), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kTextDark)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(p.effectiveStatus, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ]),
            ]),
            const Divider(height: 20),
            Row(children: [
              _actionBtn(Icons.picture_as_pdf_outlined, 'PDF', () => _printPdf(p)),
              _actionBtn(Icons.share_outlined, 'Share', () => _sharePdf(p)),
              _actionBtn(Icons.copy_all_outlined, 'Duplicate', () => _duplicate(p)),
              if (!p.isConverted) _actionBtn(Icons.sync_alt_rounded, 'Convert', () => _convertToInvoice(p), color: kBlue),
              _actionBtn(Icons.delete_outline_rounded, 'Delete', () => _showDeleteConfirm(p), color: kRed),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap, {Color color = kTextSub}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
