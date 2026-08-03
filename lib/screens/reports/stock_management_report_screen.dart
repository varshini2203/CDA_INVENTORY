// lib/screens/reports/stock_management_report_screen.dart
//
// "Stock Management" report — unlike the Stock / Inventory History report
// (which lists IN/OUT/ADJUST/TRANSFER transactions over a date range),
// this shows the CURRENT stock position: every item in `stock_items`
// with its live quantity, minimum threshold, and low-stock flag. It's a
// point-in-time snapshot, not date-ranged, so there's no date picker —
// just branch + category filters and a low-stock-only toggle.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cda_inventory/core/access/access_scope.dart';
import 'package:cda_inventory/models/stock.dart';
import 'package:cda_inventory/services/stock_service.dart';
import 'package:cda_inventory/services/excel_export_service.dart'
    hide MonthlySummary, DroneReportRow, ReportService;
import 'package:cda_inventory/services/pdf_export_service.dart';
import 'package:cda_inventory/widgets/reports/branch_filter_bar.dart';

class StockManagementReportScreen extends StatefulWidget {
  final String? initialBranch; // null = All Branches
  const StockManagementReportScreen({super.key, this.initialBranch});

  @override
  State<StockManagementReportScreen> createState() => _StockManagementReportScreenState();
}

class _StockManagementReportScreenState extends State<StockManagementReportScreen> {
  List<StockItem> _allItems = [];
  String? _selectedBranch;
  String? _selectedCategory; // null = All, 'consumable', 'fixed_asset'
  bool _lowStockOnly = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  List<StockItem> get _rows {
    var list = filterByBranch(_allItems, _selectedBranch, (r) => r.branch);
    if (_selectedCategory != null) {
      list = list.where((i) => i.category == _selectedCategory).toList();
    }
    if (_lowStockOnly) {
      list = list.where((i) => i.isLowStock).toList();
    }
    return list;
  }

  // ── Design tokens (matches other Report screens' theme) ────────────────────
  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kCoral = Color(0xFFFF6B6B);
  static const Color kSurface = Color(0xFFF0F4F8);
  static const Color kGreen = Color(0xFF00B894);
  static const Color kPink = Color(0xFFEC4899);

  @override
  void initState() {
    super.initState();
    _selectedBranch = widget.initialBranch;
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await StockService.fetchItems(forceRefresh: forceRefresh);
      setState(() {
        _allItems = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _export({required bool pdf}) async {
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final branchSuffix =
      _selectedBranch == null ? '' : '_${branchDisplayName(_selectedBranch).replaceAll(' ', '')}';
      final label = '${DateFormat('ddMMMyyyy_HHmm').format(now)}$branchSuffix';
      if (pdf) {
        final bytes = await PdfExportService.buildStockItemsReport(_rows, now);
        await PdfExportService.download(bytes, 'Stock_Management_Report_$label.pdf');
      } else {
        final bytes = ExcelExportService.buildStockItemsReport(_rows, now);
        ExcelExportService.download(bytes, 'Stock_Management_Report_$label.xlsx');
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
      final bytes = await PdfExportService.buildStockItemsReport(_rows, DateTime.now());
      await PdfExportService.preview(bytes, 'Stock_Management_Report');
    } finally {
      if (mounted) setState(() => _busy = false);
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

    final lowCount = _rows.where((i) => i.isLowStock).length;
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Stock Management Report',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _load(forceRefresh: true),
          ),
        ],
      ),
      body: Column(children: [
        _filterHeader(),
        if (!_loading && _error == null) _statsBar(lowCount),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kPink))
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

  Widget _filterHeader() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0A1628), Color(0xFF162944)],
      ),
    ),
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.today_rounded, color: kPink, size: 14),
        const SizedBox(width: 6),
        Text('Live snapshot — ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11.5)),
      ]),
      const SizedBox(height: 10),
      BranchFilterBar(
        selected: _selectedBranch,
        accent: kPink,
        lockedBranch: lockedReportBranch(context),
        onChanged: (branch) => setState(() => _selectedBranch = branch),
      ),
      const SizedBox(height: 8),
      Row(children: [
        _categoryChip('All', null),
        const SizedBox(width: 8),
        _categoryChip('Consumables', 'consumable'),
        const SizedBox(width: 8),
        _categoryChip('Fixed Assets', 'fixed_asset'),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _lowStockOnly = !_lowStockOnly),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _lowStockOnly ? kCoral : Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _lowStockOnly ? kCoral : Colors.white.withOpacity(0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.warning_amber_rounded,
                  size: 13, color: _lowStockOnly ? Colors.white : Colors.white.withOpacity(0.85)),
              const SizedBox(width: 4),
              Text('Low Stock',
                  style: TextStyle(
                      color: _lowStockOnly ? Colors.white : Colors.white.withOpacity(0.85),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ]),
    ]),
  );

  Widget _categoryChip(String label, String? value) {
    final isSelected = _selectedCategory == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? kPink : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? kPink : Colors.white.withOpacity(0.2)),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.85),
                fontSize: 11.5,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _statsBar(int lowCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        _pill('${_rows.length} Items', Colors.grey.shade600, kSurface),
        const SizedBox(width: 8),
        _pill('$lowCount Low Stock', lowCount > 0 ? kCoral : kGreen,
            (lowCount > 0 ? kCoral : kGreen).withOpacity(0.14)),
      ]),
    );
  }

  Widget _pill(String label, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
  );

  Widget _card(StockItem item) {
    final low = item.isLowStock;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: low ? Border.all(color: kCoral.withOpacity(0.4)) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: (low ? kCoral : kPink).withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.warehouse_rounded, color: low ? kCoral : kPink, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.productName,
                style: const TextStyle(color: kNavy, fontWeight: FontWeight.w700, fontSize: 14),
                overflow: TextOverflow.ellipsis),
            Text(item.category == 'fixed_asset' ? 'Fixed Asset' : 'Consumable',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            Text('${branchDisplayName(item.branch)}${item.location != null && item.location!.isNotEmpty ? '  •  ${item.location}' : ''}',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 10.5)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${item.quantity} ${item.unit}',
              style: TextStyle(
                  color: low ? kCoral : kGreen, fontWeight: FontWeight.w800, fontSize: 14)),
          Text('Min ${item.minStock}', style: TextStyle(color: Colors.grey.shade400, fontSize: 10.5)),
          if (low)
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration:
              BoxDecoration(color: kCoral.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: const Text('LOW',
                  style: TextStyle(color: kCoral, fontSize: 9.5, fontWeight: FontWeight.w700)),
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
                backgroundColor: kPink,
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
          onPressed: () => _load(forceRefresh: true),
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
      Icon(Icons.warehouse_outlined, size: 56, color: Colors.grey.shade300),
      const SizedBox(height: 10),
      Text(
        _lowStockOnly ? 'No low-stock items match these filters' : 'No stock items match these filters',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade500),
      ),
    ]),
  );
}