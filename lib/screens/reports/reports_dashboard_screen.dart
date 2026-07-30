// lib/screens/reports/reports_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'drone_inout_report_screen.dart';
import 'invoice_report_screen.dart';
import 'stock_history_report_screen.dart';
import 'purchase_report_screen.dart';
import 'package:cda_inventory/models/purchase.dart';
import 'package:cda_inventory/services/purchase_service.dart';
import 'package:cda_inventory/services/report_service.dart';
import 'package:cda_inventory/services/excel_export_service.dart'
    hide MonthlySummary, DroneReportRow, ReportService;
import 'package:cda_inventory/services/pdf_export_service.dart';
import 'package:cda_inventory/widgets/reports/report_date_range_picker.dart';
import 'package:cda_inventory/widgets/reports/branch_filter_bar.dart';

class ReportsDashboardScreen extends StatefulWidget {
  const ReportsDashboardScreen({super.key});

  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen>
    with SingleTickerProviderStateMixin {
  // ── Date range (replaces the old single "month" selector) ────────────────
  late DateTimeRange _range;

  // Raw rows fetched for the current date range, BEFORE branch filtering
  // (kept so export can reuse them instead of re-fetching, and so switching
  // branches doesn't require another Firestore round trip).
  List<DroneReportRow> _droneRowsAll = [];
  List<dynamic> _stockRowsAll = []; // StockTransaction, kept dynamic to avoid extra import churn
  List<dynamic> _invoiceRowsAll = []; // Invoice
  List<Purchase> _purchasesAll = [];

  // Which branch the dashboard is currently scoped to. null = All Branches
  // (both Branch 1 / CDA Admin and Branch 2 / CDA Ops combined).
  String? _selectedBranch;

  // ── Branch-filtered views used everywhere in the UI/export below ────────
  List<DroneReportRow> get _droneRows =>
      filterByBranch(_droneRowsAll, _selectedBranch, (r) => r.branch);
  List<dynamic> get _stockRows =>
      filterByBranch(_stockRowsAll, _selectedBranch, (r) => (r.branch as String?));
  List<dynamic> get _invoiceRows =>
      filterByBranch(_invoiceRowsAll, _selectedBranch, (r) => (r.branch as String?));
  List<Purchase> get _purchasesInRange =>
      filterByBranch(_purchasesAll, _selectedBranch, (p) => p.branch);

  bool _loading = true;
  String? _exportingType;
  String? _error;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ── Design tokens (matches Invoice List screen theme) ──────────────────────
  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kCoral = Color(0xFFFF6B6B);
  static const Color kAmber = Color(0xFFFFB800);
  static const Color kSurface = Color(0xFFF0F4F8);
  static const Color kGreen = Color(0xFF00B894);
  static const Color kPurple = Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day),
    );
    _loadSummary();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Date range helpers ────────────────────────────────────────────────────
  List<DateTime> _monthsSpanned(DateTimeRange range) {
    final months = <DateTime>[];
    var cursor = DateTime(range.start.year, range.start.month);
    final end = DateTime(range.end.year, range.end.month);
    while (!cursor.isAfter(end)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return months;
  }

  bool _dateInRange(DateTime d, DateTimeRange range) {
    final day = DateTime(d.year, d.month, d.day);
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  // purchaseDate / invoice date / stock date are stored as 'dd-MM-yyyy'
  DateTime? _parseDdMmYyyy(String raw) {
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  List<Purchase> _filterPurchasesByRange(List<Purchase> source, DateTimeRange range) {
    return source.where((p) {
      final d = _parseDdMmYyyy(p.purchaseDate);
      if (d == null) return false;
      return _dateInRange(d, range);
    }).toList();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Previously this looped every month spanned by the selected range
      // and called fetchDroneInOutReport()/fetchStockHistoryReport() once
      // PER month — for a 12-month range that meant 12 separate Firestore
      // round trips for drones and 12 for stock, even though the data
      // needed is really just "everything between _range.start and
      // _range.end". Now each report type is fetched ONCE for the whole
      // range and trimmed to the exact from/to dates below, regardless of
      // how many months the picked range spans.
      //
      // The end bound is exclusive server-side, so it's pushed one day
      // past _range.end to make sure the last day of the range is
      // included (matches the inclusive, day-level comparison _dateInRange
      // already does for the client-side trim below).
      final rangeStart = DateTime(_range.start.year, _range.start.month, _range.start.day);
      final rangeEndExclusive =
      DateTime(_range.end.year, _range.end.month, _range.end.day).add(const Duration(days: 1));

      final droneAll = await ReportService.fetchDroneInOutReportRange(
          rangeStart, rangeEndExclusive);
      final stockAll = await ReportService.fetchStockHistoryReportRange(
          rangeStart, rangeEndExclusive);
      // fetchAllInvoices() only pays for a real Firestore read the first
      // time it's called in a session (see ReportService's internal
      // cache) — every call after that, including this one, is free.
      final invoiceAll = await ReportService.fetchAllInvoices();

      final droneFiltered = droneAll
          .where((r) => r.timestamp != null && _dateInRange(r.timestamp!, _range))
          .toList();
      final stockFiltered = stockAll.where((r) {
        final d = _parseDdMmYyyy(r.date as String);
        return d != null && _dateInRange(d, _range);
      }).toList();
      final invoiceFiltered = invoiceAll.where((inv) {
        final d = _parseDdMmYyyy(inv.purchaseDate);
        return d != null && _dateInRange(d, _range);
      }).toList();

      final allPurchases = await PurchaseService.getAllPurchases();
      final purchasesFiltered = _filterPurchasesByRange(allPurchases, _range);

      setState(() {
        _droneRowsAll = droneFiltered;
        _stockRowsAll = stockFiltered;
        _invoiceRowsAll = invoiceFiltered;
        _purchasesAll = purchasesFiltered;
        _loading = false;
      });
      _animController.forward(from: 0);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await ReportDateRangePicker.show(
      context,
      initialRange: _range,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      title: 'Select Report Range',
      accent: kTeal,
    );
    if (picked != null) {
      setState(() => _range = picked);
      _loadSummary();
    }
  }

  // Consolidated PDF/Excel export still runs against a single calendar
  // month (the month the "From" date falls in) since it's built from the
  // backend's monthly summary. If you need it to honour the exact range,
  // ReportService/PdfExportService/ExcelExportService would need a
  // date-range-aware summary endpoint.
  Future<void> _exportFull({required bool pdf}) async {
    setState(() => _exportingType = pdf ? 'pdf' : 'excel');
    try {
      final month = DateTime(_range.start.year, _range.start.month);
      final rawDrones = await ReportService.fetchDroneInOutReport(month.year, month.month);
      final rawStock = await ReportService.fetchStockHistoryReport(month.year, month.month);
      final rawInvoices = await ReportService.fetchInvoiceReport(month.year, month.month);

      // Scope the export to the branch currently selected on the dashboard
      // (null = both branches, unchanged behaviour).
      final drones = filterByBranch(rawDrones, _selectedBranch, (r) => r.branch);
      final stock = filterByBranch(rawStock, _selectedBranch, (r) => (r.branch as String?));
      final invoices = filterByBranch(rawInvoices, _selectedBranch, (r) => (r.branch as String?));

      // MonthlySummary is recomputed here (rather than via
      // ReportService.fetchMonthlySummary) so its totals match the
      // branch-filtered drones/stock/invoices above.
      final stockIn = stock.where((t) => t.type == 'IN').toList();
      final stockOut = stock.where((t) => t.type == 'OUT').toList();
      final summary = MonthlySummary(
        droneInCount: drones.where((d) => d.status == 'IN').length,
        droneOutCount: drones.where((d) => d.status == 'OUT').length,
        stockInCount: stockIn.length,
        stockOutCount: stockOut.length,
        stockInQty: stockIn.fold<int>(0, (s, t) => s + t.quantity),
        stockOutQty: stockOut.fold<int>(0, (s, t) => s + t.quantity),
        invoiceCount: invoices.length,
        invoiceTotal: invoices.fold<double>(0, (s, i) => s + i.amount),
      );

      final branchSuffix =
      _selectedBranch == null ? '' : '_${branchDisplayName(_selectedBranch).replaceAll(' ', '')}';
      final label = '${DateFormat('MMM_yyyy').format(month)}$branchSuffix';

      if (pdf) {
        final bytes = await PdfExportService.buildFullMonthlyReport(
          month: month,
          summary: summary,
          drones: drones,
          stock: stock,
          invoices: invoices,
        );
        await PdfExportService.download(bytes, 'Monthly_Report_$label.pdf');
      } else {
        final bytes = ExcelExportService.buildFullMonthlyReport(
          month: month,
          summary: summary,
          drones: drones,
          stock: stock,
          invoices: invoices,
        );
        ExcelExportService.download(bytes, 'Monthly_Report_$label.xlsx');
      }
      if (mounted) {
        final scope = _selectedBranch == null ? '' : ' — ${branchDisplayName(_selectedBranch)}';
        _showSnack(
            '${pdf ? "PDF" : "Excel"} report downloaded (for ${DateFormat('MMMM yyyy').format(month)}$scope)');
      }
    } catch (e) {
      if (mounted) _showSnack('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _exportingType = null);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: isError ? kCoral : kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: RefreshIndicator(
        onRefresh: _loadSummary,
        color: kTeal,
        child: CustomScrollView(
          slivers: [
            // ── Sliver App Bar (matches Invoice List hero header) ──────────
            SliverAppBar(
              expandedHeight: 150,
              floating: false,
              pinned: true,
              backgroundColor: kNavy,
              foregroundColor: Colors.white,
              title: const Text(
                'Reports',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              titleSpacing: 0,
              actions: [
                IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadSummary),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0A1628), Color(0xFF162944)],
                    ),
                  ),
                  child: ClipRect(
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text(
                              'Reports',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'CDA Inventory System',
                              style: TextStyle(
                                  color: kTeal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                collapseMode: CollapseMode.parallax,
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: kTeal)),
              )
            else if (_error != null)
              SliverFillRemaining(child: _errorCard())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _rangeSelector(),
                    const SizedBox(height: 10),
                    _branchSelector(),
                    const SizedBox(height: 14),
                    FadeTransition(opacity: _fadeAnim, child: _summaryGrid()),
                    const SizedBox(height: 16),
                    FadeTransition(opacity: _fadeAnim, child: _fullReportCard()),
                    const SizedBox(height: 20),
                    _sectionLabel('DETAILED REPORTS'),
                    const SizedBox(height: 8),
                    _ReportListTile(
                      icon: Icons.flight_takeoff_rounded,
                      title: 'Drone In / Out',
                      subtitle:
                      '${_droneRows.where((r) => r.status == 'IN').length} in  ·  ${_droneRows.where((r) => r.status == 'OUT').length} out',
                      color: kPurple,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(settings: const RouteSettings(name: 'Drone In Out Report'),
                            builder: (_) => DroneInOutReportScreen(
                                initialRange: _range, initialBranch: _selectedBranch)),
                      ),
                    ),
                    _ReportListTile(
                      icon: Icons.history_rounded,
                      title: 'Stock / Inventory History',
                      subtitle: '${_stockRows.length} transactions',
                      color: kGreen,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(settings: const RouteSettings(name: 'Stock History Report'),
                            builder: (_) => StockHistoryReportScreen(
                                initialRange: _range, initialBranch: _selectedBranch)),
                      ),
                    ),
                    _ReportListTile(
                      icon: Icons.receipt_long_rounded,
                      title: 'Invoice List',
                      subtitle: '${_invoiceRows.length} invoices',
                      color: kTeal,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(settings: const RouteSettings(name: 'Invoice Report'),
                            builder: (_) => InvoiceReportScreen(
                                initialRange: _range, initialBranch: _selectedBranch)),
                      ),
                    ),
                    _ReportListTile(
                      icon: Icons.shopping_cart_rounded,
                      title: 'Purchases',
                      subtitle: '${_purchasesInRange.length} purchases',
                      color: kAmber,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(settings: const RouteSettings(name: 'Purchase Report'),
                            builder: (_) => PurchaseReportScreen(
                                initialRange: _range, initialBranch: _selectedBranch)),
                      ),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _rangeSelector() {
    return GestureDetector(
      onTap: _pickRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration:
            BoxDecoration(color: kTeal.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.date_range_rounded, color: kTeal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('REPORT DATE RANGE',
                  style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 9,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700)),
              Text(
                '${DateFormat('dd MMM yyyy').format(_range.start)}  →  ${DateFormat('dd MMM yyyy').format(_range.end)}',
                style: const TextStyle(color: kNavy, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ]),
          ),
          Icon(Icons.expand_more_rounded, color: Colors.grey.shade400),
        ]),
      ),
    );
  }

  Widget _branchSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Text('BRANCH',
            style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 9,
                letterSpacing: 1,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 10),
        Expanded(
          child: BranchFilterBar(
            selected: _selectedBranch,
            dark: false,
            accent: kTeal,
            onChanged: (branch) => setState(() => _selectedBranch = branch),
          ),
        ),
      ]),
    );
  }

  Widget _summaryGrid() {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final droneIn = _droneRows.where((r) => r.status == 'IN').length;
    final droneOut = _droneRows.where((r) => r.status == 'OUT').length;
    final stockInQty = _stockRows
        .where((r) => r.type == 'IN')
        .fold<int>(0, (s, r) => s + (r.quantity as int));
    final stockOutQty = _stockRows
        .where((r) => r.type == 'OUT')
        .fold<int>(0, (s, r) => s + (r.quantity as int));
    final invoiceTotal =
    _invoiceRows.fold<double>(0, (s, inv) => s + (inv.amount as double));
    final purchaseTotal = _purchasesInRange.fold<double>(
        0, (sum, p) => sum + (p.cost * p.quantity));

    final items = [
      ('Drone IN', '$droneIn', kGreen, Icons.flight_land_rounded),
      ('Drone OUT', '$droneOut', kCoral, Icons.flight_takeoff_rounded),
      ('Stock IN qty', '$stockInQty', kGreen, Icons.arrow_downward_rounded),
      ('Stock OUT qty', '$stockOutQty', kCoral, Icons.arrow_upward_rounded),
      ('Invoices', '${_invoiceRows.length}', kPurple, Icons.receipt_long_rounded),
      ('Invoice Total', currency.format(invoiceTotal), kTeal, Icons.currency_rupee_rounded),
      ('Purchases', '${_purchasesInRange.length}', kAmber, Icons.shopping_cart_rounded),
      ('Purchase Total', currency.format(purchaseTotal), kAmber, Icons.currency_rupee_rounded),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 78,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(it.$4, color: it.$3, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(it.$1,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 6),
              Text(it.$2, style: TextStyle(color: it.$3, fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
        );
      },
    );
  }

  Widget _fullReportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0A1628), Color(0xFF162944)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kTeal.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.summarize_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Monthly Consolidated Report',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
        const SizedBox(height: 4),
        Text(
          _selectedBranch == null
              ? 'Drone, stock & invoice data for ${DateFormat('MMMM yyyy').format(_range.start)} — everything, one file.'
              : 'Drone, stock & invoice data for ${DateFormat('MMMM yyyy').format(_range.start)} — ${branchDisplayName(_selectedBranch)} only.',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11.5),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: _exportButton('PDF', Icons.picture_as_pdf_rounded,
                  _exportingType == 'pdf', () => _exportFull(pdf: true))),
          const SizedBox(width: 10),
          Expanded(
              child: _exportButton('Excel', Icons.grid_on_rounded,
                  _exportingType == 'excel', () => _exportFull(pdf: false))),
        ]),
      ]),
    );
  }

  Widget _exportButton(String label, IconData icon, bool busy, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: _exportingType == null ? onTap : null,
      icon: busy
          ? const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: kTeal,
        foregroundColor: Colors.white,
        disabledBackgroundColor: busy ? kTeal : kTeal.withOpacity(0.5),
        disabledForegroundColor: busy ? Colors.white : Colors.white.withOpacity(0.85),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }

  Widget _sectionLabel(String text) => Row(children: [
    Container(width: 6, height: 6, decoration: const BoxDecoration(color: kTeal, shape: BoxShape.circle)),
    const SizedBox(width: 7),
    Text(text,
        style: TextStyle(
            color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
    const SizedBox(width: 8),
    Expanded(child: Divider(color: Colors.grey.shade300)),
  ]);

  Widget _errorCard() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: kCoral.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.cloud_off_rounded, size: 40, color: kCoral),
          ),
          const SizedBox(height: 20),
          const Text('Failed to load',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kNavy)),
          const SizedBox(height: 8),
          Text(_error ?? '',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadSummary,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReportListTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ReportListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                color: _ReportsDashboardScreenState.kNavy, fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5)),
        trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
      ),
    );
  }
}