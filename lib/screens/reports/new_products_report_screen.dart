// lib/screens/reports/new_products_report_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cda_inventory/core/access/access_scope.dart';
import 'package:cda_inventory/models/new_product.dart';
import 'package:cda_inventory/services/new_product_service.dart';
import 'package:cda_inventory/services/excel_export_service.dart'
    hide MonthlySummary, DroneReportRow, ReportService;
import 'package:cda_inventory/services/pdf_export_service.dart';
import 'package:cda_inventory/widgets/reports/report_date_range_picker.dart';
import 'package:cda_inventory/widgets/reports/branch_filter_bar.dart';

class NewProductsReportScreen extends StatefulWidget {
  final DateTimeRange initialRange;
  final String? initialBranch; // null = All Branches
  const NewProductsReportScreen({super.key, required this.initialRange, this.initialBranch});

  @override
  State<NewProductsReportScreen> createState() => _NewProductsReportScreenState();
}

class _NewProductsReportScreenState extends State<NewProductsReportScreen> {
  late DateTimeRange _range;
  List<NewProduct> _allProducts = [];
  List<NewProduct> _rowsAll = []; // date-filtered, before branch filtering
  String? _selectedBranch;
  List<NewProduct> get _rows =>
      filterByBranch(_rowsAll, _selectedBranch, (r) => r.branch);
  bool _loading = true;
  bool _busy = false;
  String? _error;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  // ── Design tokens (matches other Report screens' theme) ────────────────────
  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kCoral = Color(0xFFFF6B6B);
  static const Color kSurface = Color(0xFFF0F4F8);
  static const Color kGreen = Color(0xFF00B894);
  static const Color kIndigo = Color(0xFF6366F1);

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
    _selectedBranch = widget.initialBranch;
    _load();
  }

  bool _dateInRange(DateTime d, DateTimeRange range) {
    final day = DateTime(d.year, d.month, d.day);
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await NewProductService.getNewProducts();
      setState(() {
        _allProducts = all;
        _rowsAll = _filterByRange(all, _range);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<NewProduct> _filterByRange(List<NewProduct> source, DateTimeRange range) {
    return source.where((p) => _dateInRange(p.purchaseDate, range)).toList()
      ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await ReportDateRangePicker.show(
      context,
      initialRange: _range,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      title: 'Select Report Range',
      accent: kIndigo,
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _rowsAll = _filterByRange(_allProducts, _range);
      });
    }
  }

  Future<void> _export({required bool pdf}) async {
    setState(() => _busy = true);
    try {
      final branchSuffix =
      _selectedBranch == null ? '' : '_${branchDisplayName(_selectedBranch).replaceAll(' ', '')}';
      final label =
          '${DateFormat('ddMMMyyyy').format(_range.start)}_to_${DateFormat('ddMMMyyyy').format(_range.end)}$branchSuffix';
      if (pdf) {
        final bytes = await PdfExportService.buildNewProductsReport(_rows, _range.start);
        await PdfExportService.download(bytes, 'New_Products_Report_$label.pdf');
      } else {
        final bytes = ExcelExportService.buildNewProductsReport(_rows, _range.start);
        ExcelExportService.download(bytes, 'New_Products_Report_$label.xlsx');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: $e'), backgroundColor: kCoral));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _previewPdf() async {
    setState(() => _busy = true);
    try {
      final bytes = await PdfExportService.buildNewProductsReport(_rows, _range.start);
      await PdfExportService.preview(bytes, 'New_Products_Report');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Out of Stock':
        return kCoral;
      case 'Low Stock':
        return const Color(0xFFFFB800);
      default:
        return kGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Non-admins (e.g. a CDA Ops employee) are pinned to their own branch
    // on this screen too — reached either from the dashboard or by direct
    // navigation, so the lock is enforced independently here as well.
    final lockedBranch = lockedReportBranch(context);
    if (lockedBranch != null && _selectedBranch != lockedBranch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedBranch = lockedBranch);
      });
    }

    final totalValue = _rows.fold<double>(0, (s, p) => s + p.stockValue);
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('New Products Report',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      body: Column(children: [
        _rangeBar(),
        _branchBar(),
        if (!_loading && _error == null) _statsBar(totalValue),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kIndigo))
              : _error != null
              ? _errorState()
              : _rows.isEmpty
              ? _emptyState()
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
            itemCount: _rows.length,
            itemBuilder: (_, i) => _card(_rows[i]),
          ),
        ),
      ]),
      bottomNavigationBar: _rows.isEmpty ? null : _exportBar(),
    );
  }

  Widget _rangeBar() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0A1628), Color(0xFF162944)],
      ),
    ),
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
    child: GestureDetector(
      onTap: _pickRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.date_range_rounded, color: kIndigo, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${DateFormat('dd MMM yyyy').format(_range.start)}  →  ${DateFormat('dd MMM yyyy').format(_range.end)}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.expand_more_rounded, color: Colors.white.withOpacity(0.6), size: 18),
        ]),
      ),
    ),
  );

  Widget _branchBar() => Container(
    color: kNavy,
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
    child: BranchFilterBar(
      selected: _selectedBranch,
      accent: kIndigo,
      lockedBranch: lockedReportBranch(context),
      onChanged: (branch) => setState(() => _selectedBranch = branch),
    ),
  );

  Widget _statsBar(double totalValue) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        _pill('${_rows.length} Products', Colors.grey.shade600, kSurface),
        const SizedBox(width: 8),
        _pill(_currency.format(totalValue), kIndigo, kIndigo.withOpacity(0.14)),
      ]),
    );
  }

  Widget _pill(String label, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
  );

  Widget _card(NewProduct p) {
    final statusColor = _statusColor(p.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
          BoxDecoration(color: kIndigo.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.inventory_2_rounded, color: kIndigo, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.productName.isEmpty ? 'Unnamed product' : p.productName,
                style: const TextStyle(color: kNavy, fontWeight: FontWeight.w700, fontSize: 14),
                overflow: TextOverflow.ellipsis),
            Text(p.category,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                overflow: TextOverflow.ellipsis),
            Text(
                '${branchDisplayName(p.branch)}  •  ${DateFormat('dd MMM yyyy').format(p.purchaseDate)}',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 10.5)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_currency.format(p.stockValue),
              style: const TextStyle(color: kGreen, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(p.status,
                style: TextStyle(color: statusColor, fontSize: 9.5, fontWeight: FontWeight.w700)),
          ),
        ]),
      ]),
    );
  }

  Widget _exportBar() => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
    decoration: BoxDecoration(
        color: kNavy, border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08)))),
    child: SafeArea(
      top: false,
      child: Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _previewPdf,
            icon: const Icon(Icons.visibility_rounded, size: 16, color: Colors.white),
            label: const Text('Preview', style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _busy ? null : () => _export(pdf: true),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: const Text('PDF'),
            style: ElevatedButton.styleFrom(
                backgroundColor: kIndigo,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _busy ? null : () => _export(pdf: false),
            icon: const Icon(Icons.grid_on_rounded, size: 16),
            label: const Text('Excel'),
            style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
      ]),
    ),
  );

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, color: kCoral, size: 40),
        const SizedBox(height: 12),
        Text(_error!, style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _load,
          style: ElevatedButton.styleFrom(
              backgroundColor: kNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Retry'),
        ),
      ]),
    ),
  );

  Widget _emptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade300),
      const SizedBox(height: 10),
      Text(
        'No new products from ${DateFormat('dd MMM yyyy').format(_range.start)} to ${DateFormat('dd MMM yyyy').format(_range.end)}',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade500),
      ),
    ]),
  );
}