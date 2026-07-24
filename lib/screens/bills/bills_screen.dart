import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

import 'package:cda_inventory/services/bills_service.dart';
import 'package:cda_inventory/services/bill_pdf_service.dart';
import 'package:cda_inventory/models/bill_model.dart';
import 'package:cda_inventory/constants/bill_categories.dart';
import 'add_edit_bill_screen.dart';
import 'bill_detail_screen.dart';
import 'package:cda_inventory/widgets/reports/report_date_range_picker.dart';

// ── Design tokens (matches Invoice screens) ─────────────────────────────────
const Color kNavy = Color(0xFF0A1628);
const Color kTeal = Color(0xFF00D4AA);
const Color kCoral = Color(0xFFFF6B6B);
const Color kAmber = Color(0xFFFFB800);
const Color kSurface = Color(0xFFF0F4F8);
const Color kGreen = Color(0xFF00B894);
const Color kPurple = Color(0xFF6C63FF);

enum BillSortOption { dateDesc, dateAsc, amountDesc, amountAsc, vendorAZ, vendorZA }

extension _BillSortLabel on BillSortOption {
  String get label {
    switch (this) {
      case BillSortOption.dateDesc:
        return 'Newest first';
      case BillSortOption.dateAsc:
        return 'Oldest first';
      case BillSortOption.amountDesc:
        return 'Amount: High to Low';
      case BillSortOption.amountAsc:
        return 'Amount: Low to High';
      case BillSortOption.vendorAZ:
        return 'Vendor: A to Z';
      case BillSortOption.vendorZA:
        return 'Vendor: Z to A';
    }
  }
}

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<BillModel> _allBills = [];
  bool _isLoading = false;
  String _errorMessage = '';

  String _searchQuery = '';
  String _selectedCategory = 'All';
  DateTimeRange? _dateRange;
  BillSortOption _sortOption = BillSortOption.dateDesc;

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty || _selectedCategory != 'All' || _dateRange != null;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBills() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final bills = await BillsService.fetchBills();
      if (!mounted) return;
      setState(() => _allBills = _dedupeById(bills));
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to load bills. Please check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Defensive belt-and-suspenders check: collapses any bills sharing the
  /// same id down to a single entry (keeping the first occurrence), so a
  /// duplicate never renders even if something upstream (cache aliasing,
  /// a double network call, etc.) manages to produce one.
  List<BillModel> _dedupeById(List<BillModel> bills) {
    final seen = <String>{};
    final out = <BillModel>[];
    for (final b in bills) {
      if (seen.add(b.id)) out.add(b);
    }
    return out;
  }

  /// Adds [bill] to the local list, or — if a bill with that id is
  /// already present (e.g. because the service's internal cache already
  /// picked it up) — updates the existing entry in place instead of
  /// inserting a second copy.
  void _addOrUpdateLocal(BillModel bill) {
    final idx = _allBills.indexWhere((b) => b.id == bill.id);
    if (idx != -1) {
      _allBills[idx] = bill;
    } else {
      _allBills.insert(0, bill);
    }
  }

  /// Computed, filtered + sorted view — recalculated on every build from
  /// the local search/category/date/sort state (no Provider needed).
  List<BillModel> get _visibleBills {
    final q = _searchQuery.trim().toLowerCase();

    var filtered = _allBills.where((bill) {
      final matchesCategory =
          _selectedCategory == 'All' || bill.category == _selectedCategory;

      final matchesDate = _dateRange == null ||
          (!bill.billDate.isBefore(_dateRange!.start) &&
              !bill.billDate.isAfter(_dateRange!.end
                  .add(const Duration(hours: 23, minutes: 59, seconds: 59))));

      if (!matchesCategory || !matchesDate) return false;
      if (q.isEmpty) return true;

      final dateStr =
          '${bill.billDate.day}/${bill.billDate.month}/${bill.billDate.year}';
      final amountStr = bill.amount.toStringAsFixed(2);

      return bill.vendorName.toLowerCase().contains(q) ||
          bill.billNumber.toLowerCase().contains(q) ||
          bill.category.toLowerCase().contains(q) ||
          bill.notes.toLowerCase().contains(q) ||
          amountStr.contains(q) ||
          dateStr.contains(q);
    }).toList();

    filtered.sort((a, b) {
      switch (_sortOption) {
        case BillSortOption.dateAsc:
          return a.billDate.compareTo(b.billDate);
        case BillSortOption.dateDesc:
          return b.billDate.compareTo(a.billDate);
        case BillSortOption.amountAsc:
          return a.amount.compareTo(b.amount);
        case BillSortOption.amountDesc:
          return b.amount.compareTo(a.amount);
        case BillSortOption.vendorAZ:
          return a.vendorName.toLowerCase().compareTo(b.vendorName.toLowerCase());
        case BillSortOption.vendorZA:
          return b.vendorName.toLowerCase().compareTo(a.vendorName.toLowerCase());
      }
    });

    return filtered;
  }

  double get _totalAmount => _visibleBills.fold(0.0, (sum, b) => sum + b.amount);

  bool _isExportingPdf = false;

  Future<void> _exportPdf() async {
    final visible = _visibleBills;
    if (visible.isEmpty) {
      _showSnack('Nothing to export', isError: true);
      return;
    }
    setState(() => _isExportingPdf = true);
    try {
      final bytes = await BillPdfService.generateReport(visible);
      await Printing.sharePdf(bytes: bytes, filename: 'bills_report.pdf');
    } catch (e) {
      if (mounted) _showSnack('Failed to export PDF: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategory = 'All';
      _dateRange = null;
    });
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

  Future<void> _pickImageAndAdd() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Scan or Upload Bill',
                style: TextStyle(
                    color: kNavy,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: kTeal),
              title: const Text('Scan with Camera',
                  style: TextStyle(color: kNavy, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: kTeal),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: kNavy, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;

    final Uint8List bytes = await picked.readAsBytes();
    if (!mounted) return;

    final newBill = await Navigator.push<BillModel>(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'Add Edit Bill'),
        builder: (_) => AddEditBillScreen(imageBytes: bytes),
      ),
    );

    if (newBill != null && mounted) {
      setState(() => _addOrUpdateLocal(newBill));
    }
  }

  Future<void> _openDetail(BillModel bill) async {
    final result = await Navigator.push<BillDetailResult>(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'Bill Detail'), builder: (_) => BillDetailScreen(bill: bill)),
    );
    if (result == null || !mounted) return;

    setState(() {
      if (result.deleted) {
        _allBills.removeWhere((b) => b.id == bill.id);
      } else if (result.updatedBill != null) {
        final index = _allBills.indexWhere((b) => b.id == bill.id);
        if (index != -1) _allBills[index] = result.updatedBill!;
      }
    });
  }

  Future<void> _editFromCard(BillModel bill) async {
    final updated = await Navigator.push<BillModel>(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'Add Edit Bill'),
        builder: (_) => AddEditBillScreen(existingBill: bill),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        final index = _allBills.indexWhere((b) => b.id == bill.id);
        if (index != -1) _allBills[index] = updated;
      });
    }
  }

  Future<void> _confirmDelete(BillModel bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: kCoral),
            SizedBox(width: 8),
            Text('Delete Bill',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'This will permanently remove the scanned bill for "${bill.vendorName}". This cannot be undone.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await BillsService.deleteBill(bill);
      if (!mounted) return;
      setState(() => _allBills.removeWhere((b) => b.id == bill.id));
      _showSnack('Bill deleted');
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to delete bill: $e', isError: true);
      }
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await ReportDateRangePicker.show(
      context,
      initialRange: _dateRange ?? DateTimeRange(start: now, end: now),
      firstDate: DateTime(2015),
      lastDate: now,
      title: 'Select Bill Date Range',
      accent: kTeal,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  Future<void> _showSortMenu() async {
    final selected = await showModalBottomSheet<BillSortOption>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text('Sort bills by',
                style: TextStyle(
                    color: kNavy,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final option in BillSortOption.values)
              ListTile(
                title: Text(option.label,
                    style: const TextStyle(color: kNavy, fontWeight: FontWeight.w500)),
                trailing: _sortOption == option
                    ? const Icon(Icons.check_rounded, color: kTeal)
                    : null,
                onTap: () => Navigator.pop(ctx, option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) setState(() => _sortOption = selected);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleBills;

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Bills',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'Filter by date',
            icon: Icon(Icons.date_range_rounded,
                color: _dateRange != null ? kTeal : Colors.white),
            onPressed: _pickDateRange,
          ),
          IconButton(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            onPressed: _showSortMenu,
          ),
          IconButton(
            tooltip: 'Export as PDF',
            icon: _isExportingPdf
                ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _isExportingPdf ? null : _exportPdf,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kTeal,
        foregroundColor: Colors.white,
        onPressed: _pickImageAndAdd,
        icon: const Icon(Icons.document_scanner_rounded),
        label: const Text('Scan Bill', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: kTeal,
        onRefresh: _loadBills,
        child: Column(
          children: [
            _buildSearchBar(),
            _buildCategoryFilter(),
            if (_dateRange != null) _buildDateRangeChip(),
            _buildSummaryBar(visible),
            Expanded(child: _buildList(visible)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: kNavy, fontSize: 14),
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Search by vendor, bill no., category, amount, date...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
            suffixIcon: _hasActiveFilters
                ? IconButton(
              icon: Icon(Icons.clear_rounded, color: Colors.grey.shade400),
              onPressed: _clearFilters,
            )
                : null,
            border: InputBorder.none,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: billFilterCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = billFilterCategories[index];
          final selected = _selectedCategory == cat;
          return ChoiceChip(
            label: Text(cat),
            selected: selected,
            onSelected: (_) => setState(() => _selectedCategory = cat),
            backgroundColor: Colors.white,
            selectedColor: kTeal.withOpacity(0.15),
            labelStyle: TextStyle(
              color: selected ? kTeal : Colors.grey.shade600,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
            side: BorderSide(color: selected ? kTeal : Colors.grey.shade300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateRangeChip() {
    final range = _dateRange!;
    String fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          backgroundColor: Colors.white,
          avatar: const Icon(Icons.date_range_rounded, color: kTeal, size: 16),
          label: Text('${fmt(range.start)} – ${fmt(range.end)}',
              style: const TextStyle(color: kNavy, fontSize: 12, fontWeight: FontWeight.w600)),
          deleteIcon: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 16),
          onDeleted: () => setState(() => _dateRange = null),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBar(List<BillModel> visible) {
    if (visible.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${visible.length} bill(s)',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          Text(
            'Total: ₹${_totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
                color: kGreen, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<BillModel> visible) {
    if (_isLoading && _allBills.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: kTeal));
    }

    if (_errorMessage.isNotEmpty && _allBills.isEmpty) {
      return _buildError();
    }

    if (visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_hasActiveFilters ? Icons.search_off_rounded : Icons.receipt_long_rounded,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _hasActiveFilters ? 'No bills match your filters' : 'No bills scanned yet',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              _hasActiveFilters
                  ? 'Try a different search or clear filters'
                  : 'Tap "Scan Bill" to add your first one',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: visible.length,
      itemBuilder: (context, index) => _buildBillCard(visible[index]),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: kCoral.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.cloud_off_rounded, size: 40, color: kCoral),
            ),
            const SizedBox(height: 20),
            const Text('Failed to load',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kNavy)),
            const SizedBox(height: 8),
            Text(_errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadBills,
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

  Widget _buildBillCard(BillModel bill) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(bill),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: bill.imageBase64.isNotEmpty
                    ? Image.memory(
                  base64Decode(bill.imageBase64),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, st) => Container(
                    width: 64,
                    height: 64,
                    color: kSurface,
                    child: Icon(Icons.broken_image_rounded, color: Colors.grey.shade400),
                  ),
                )
                    : Container(
                  width: 64,
                  height: 64,
                  color: kSurface,
                  child: Icon(Icons.receipt_long_rounded, color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bill.vendorName,
                        style: const TextStyle(
                            color: kNavy,
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text('Bill #${bill.billNumber}  ·  ${bill.category}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                      '${bill.billDate.day}/${bill.billDate.month}/${bill.billDate.year}  ·  ₹${bill.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: kGreen, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade400),
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'edit') {
                    _editFromCard(bill);
                  } else if (value == 'delete') {
                    _confirmDelete(bill);
                  } else if (value == 'view') {
                    _openDetail(bill);
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: 'view',
                    child: Text('View',
                        style: TextStyle(color: kNavy, fontWeight: FontWeight.w600)),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit',
                        style: TextStyle(color: kNavy, fontWeight: FontWeight.w600)),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(color: kCoral, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}