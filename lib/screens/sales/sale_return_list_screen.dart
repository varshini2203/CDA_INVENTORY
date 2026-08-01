import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cda_inventory/models/sale_return.dart';
import 'package:cda_inventory/services/sale_return_service.dart';
import 'package:cda_inventory/services/sale_return_pdf_service.dart';
import 'package:cda_inventory/shared/inventory_ui.dart';
import 'add_sale_return_screen.dart';

class SaleReturnListScreen extends StatefulWidget {
  const SaleReturnListScreen({super.key});

  @override
  State<SaleReturnListScreen> createState() => _SaleReturnListScreenState();
}

class _SaleReturnListScreenState extends State<SaleReturnListScreen> {
  List<SaleReturn> _all = [];
  List<SaleReturn> _filtered = [];
  bool _isLoading = true;
  String? _error;
  String _search = '';
  String _branchFilter = 'All';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await SaleReturnService.getAllSaleReturns();
      if (!mounted) return;
      setState(() {
        _all = data;
        _isLoading = false;
        _applyFilter();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _applyFilter() {
    _filtered = _all.where((s) {
      final q = _search.toLowerCase();
      final matchSearch = q.isEmpty ||
          s.productName.toLowerCase().contains(q) ||
          s.customerName.toLowerCase().contains(q) ||
          s.referenceInvoice.toLowerCase().contains(q);
      final matchBranch = _branchFilter == 'All' || s.branch == _branchFilter;
      return matchSearch && matchBranch;
    }).toList();
  }

  Future<void> _delete(String id) async {
    final confirm = await showConfirmDeleteDialog(
      context,
      title: 'Delete Return',
      message: 'Are you sure you want to delete this sale return / credit note?',
    );
    if (!confirm) return;
    final result = await SaleReturnService.deleteSaleReturn(id);
    if (result['success'] == true) {
      setState(() {
        _all.removeWhere((s) => s.id == id);
        _applyFilter();
      });
      if (mounted) showAppSnack(context, 'Sale return deleted successfully');
    } else if (mounted) {
      showAppSnack(context, result['message'] ?? 'Delete failed', isError: true);
    }
  }

  // ── Edit an existing return ──────────────────────────────────────────────
  Future<void> _editReturn(SaleReturn s) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Edit Sale Return'),
        builder: (_) => AddSaleReturnScreen(returnToEdit: s),
      ),
    );
    if (result == true) _fetch();
  }

  // ── Share return details as text ─────────────────────────────────────────
  Future<void> _shareReturn(SaleReturn s) async {
    final buffer = StringBuffer()
      ..writeln('Sale Return / Credit Note')
      ..writeln('Product: ${s.productName}')
      ..writeln('Customer: ${s.customerName}')
      ..writeln('Quantity: ${s.quantity}')
      ..writeln('Amount: ₹${s.amount.toStringAsFixed(2)}')
      ..writeln('Reason: ${s.reason}')
      ..writeln('Reference Invoice: ${s.referenceInvoice.isEmpty ? '—' : s.referenceInvoice}')
      ..writeln('Branch: ${kBranchLabels[s.branch] ?? s.branch}')
      ..writeln('Return Date: ${s.returnDate}');
    await Share.share(buffer.toString(), subject: 'Sale Return — ${s.productName}');
  }

  // ── Print — SkyLynk-branded credit note PDF, opened in the browser's
  // print/preview dialog ───────────────────────────────────────────────
  Future<void> _printReturn(SaleReturn s) async {
    try {
      await Printing.layoutPdf(onLayout: (format) => SaleReturnPdfService.generate(s));
    } catch (e) {
      if (mounted) showAppSnack(context, 'Failed to generate PDF: $e', isError: true);
    }
  }

  // ── Share as PDF — sends the generated credit note PDF straight to
  // WhatsApp/Email/etc via the native share sheet ────────────────────────
  Future<void> _sharePdf(SaleReturn s) async {
    try {
      final bytes = await SaleReturnPdfService.generate(s);
      await Printing.sharePdf(bytes: bytes, filename: 'sale_return_${s.id ?? s.productName}.pdf');
    } catch (e) {
      if (mounted) showAppSnack(context, 'Failed to share PDF: $e', isError: true);
    }
  }

  // ── Bulk export — all filtered returns as a single PDF report ──────────
  Future<void> _exportPdf() async {
    if (_filtered.isEmpty) {
      showAppSnack(context, 'Nothing to export', isError: true);
      return;
    }
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: 'Sale Returns / Credit Notes Report'),
          pw.Table.fromTextArray(
            headers: ['Date', 'Product', 'Customer', 'Qty', 'Reason', 'Reference Inv.', 'Amount'],
            data: _filtered
                .map((s) => [
              s.returnDate,
              s.productName,
              s.customerName,
              '${s.quantity}',
              s.reason,
              s.referenceInvoice.isEmpty ? '-' : s.referenceInvoice,
              s.amount.toStringAsFixed(2),
            ])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Total Credit Value: Rs. ${_totalValue.toStringAsFixed(2)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'sale_returns_report.pdf');
  }

  // ── View full return details ─────────────────────────────────────────────
  void _viewReturn(SaleReturn s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.assignment_return_rounded, color: AppColors.teal, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.productName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.navy)),
                      const SizedBox(height: 2),
                      Text(s.customerName, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                Text('₹${s.amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navy)),
              ]),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _detailRow('Quantity', '${s.quantity}'),
              _detailRow('Reason', s.reason.isEmpty ? '—' : s.reason),
              _detailRow('Reference Invoice', s.referenceInvoice.isEmpty ? '—' : s.referenceInvoice),
              _detailRow('Branch', kBranchLabels[s.branch] ?? s.branch),
              _detailRow('Return Date', s.returnDate),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _printReturn(s),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(color: AppColors.navy),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _sharePdf(s),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.teal,
                      side: const BorderSide(color: AppColors.teal),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Share PDF'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _shareReturn(s),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.teal,
                      side: const BorderSide(color: AppColors.teal),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Share Text'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _editReturn(s);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(color: AppColors.navy),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: AppColors.navy, fontSize: 13.5, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );

  double get _totalValue => _filtered.fold(0.0, (sum, s) => sum + s.amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Sale Return / Credit Note',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf_outlined), tooltip: 'Print / Export PDF', onPressed: _exportPdf),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetch),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.navy,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              children: [
                const HeroBanner(
                  icon: Icons.assignment_return_rounded,
                  title: 'Sale Returns',
                  subtitle: 'Track goods returned by customers',
                ),
                const SizedBox(height: 14),
                Row(children: [
                  StatChip(icon: Icons.list_alt_rounded, label: 'Returns', value: '${_filtered.length}'),
                  const SizedBox(width: 12),
                  StatChip(
                      icon: Icons.currency_rupee_rounded,
                      label: 'Total Value',
                      value: '₹${_totalValue.toStringAsFixed(0)}'),
                ]),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: TextField(
                    style: const TextStyle(
                        color: AppColors.navy, fontWeight: FontWeight.w500, fontSize: 14),
                    onChanged: (v) => setState(() {
                      _search = v;
                      _applyFilter();
                    }),
                    decoration: InputDecoration(
                      hintText: 'Search product, customer, invoice...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.teal),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                          onPressed: () => setState(() {
                            _search = '';
                            _applyFilter();
                          }))
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: kBranchFilters.map((b) {
                      final sel = _branchFilter == b;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _branchFilter = b;
                            _applyFilter();
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.teal : Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: sel ? AppColors.teal : Colors.white.withOpacity(0.3)),
                            ),
                            child: Text(kBranchLabels[b] ?? b,
                                style: TextStyle(
                                    color: sel ? AppColors.navy : Colors.white,
                                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
                : _error != null
                ? _buildErrorState()
                : _filtered.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _fetch,
              color: AppColors.teal,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                itemCount: _filtered.length,
                itemBuilder: (ctx, i) => _buildCard(_filtered[i], i),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Return', style: TextStyle(fontWeight: FontWeight.w600)),
        onPressed: () async {
          final result = await Navigator.push<bool>(
              context, MaterialPageRoute(settings: const RouteSettings(name: 'Add Sale Return'), builder: (_) => const AddSaleReturnScreen()));
          if (result == true) _fetch();
        },
      ),
    );
  }

  Widget _buildErrorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            padding: const EdgeInsets.all(20),
            decoration:
            BoxDecoration(color: AppColors.coral.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.cloud_off_rounded, size: 52, color: AppColors.coral)),
        const SizedBox(height: 20),
        const Text('Failed to Load',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 10),
        Text(_error ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _fetch,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ]),
    ),
  );

  Widget _buildEmptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
          padding: const EdgeInsets.all(24),
          decoration:
          BoxDecoration(color: AppColors.teal.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.assignment_return_outlined, size: 60, color: AppColors.teal)),
      const SizedBox(height: 20),
      const Text('No returns found',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
      const SizedBox(height: 8),
      Text(
        _search.isNotEmpty ? 'Try adjusting your search' : 'Tap + to add your first return',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      ),
    ]),
  );

  Widget _buildCard(SaleReturn s, int index) {
    const accents = [AppColors.navy, AppColors.teal, AppColors.green, AppColors.amber];
    final accent = accents[index % accents.length];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration:
              BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.assignment_return_rounded, color: accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.productName,
                      style:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
                  const SizedBox(height: 2),
                  Text(s.customerName, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            Text('₹${s.amount.toStringAsFixed(0)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: accent)),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (v) {
                switch (v) {
                  case 'print': _printReturn(s); break;
                  case 'pdf': _sharePdf(s); break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'print', child: Row(children: [Icon(Icons.print_outlined, size: 18, color: AppColors.navy), SizedBox(width: 10), Text('Print')])),
                PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.teal), SizedBox(width: 10), Text('Share as PDF')])),
              ],
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(children: [
            Row(children: [
              InfoChip(Icons.format_list_numbered_rounded, 'Qty: ${s.quantity}'),
              const SizedBox(width: 8),
              InfoChip(Icons.report_problem_rounded, s.reason),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              InfoChip(Icons.receipt_long_rounded,
                  s.referenceInvoice.isEmpty ? 'No reference' : s.referenceInvoice),
              const SizedBox(width: 8),
              InfoChip(Icons.location_city_rounded, kBranchLabels[s.branch] ?? s.branch),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: InfoChip(Icons.calendar_today_rounded, s.returnDate)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _viewReturn(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.navy.withOpacity(0.18)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_outlined, color: AppColors.navy, size: 16),
                        SizedBox(width: 4),
                        Text('View',
                            style: TextStyle(
                                color: AppColors.navy, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _editReturn(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.amber.withOpacity(0.35)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, color: AppColors.amber, size: 16),
                        SizedBox(width: 4),
                        Text('Edit',
                            style: TextStyle(
                                color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _shareReturn(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.teal.withOpacity(0.35)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.ios_share_rounded, color: AppColors.teal, size: 16),
                        SizedBox(width: 4),
                        Text('Share',
                            style: TextStyle(
                                color: AppColors.teal, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              if (s.id != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _delete(s.id!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.coral.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.coral.withOpacity(0.35)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline_rounded, color: AppColors.coral, size: 16),
                          SizedBox(width: 4),
                          Text('Delete',
                              style: TextStyle(
                                  color: AppColors.coral, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}