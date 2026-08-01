import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cda_inventory/models/payment_in.dart';
import 'package:cda_inventory/services/payment_in_service.dart';
import 'package:cda_inventory/services/payment_in_pdf_service.dart';
import 'package:cda_inventory/shared/inventory_ui.dart';
import 'add_payment_in_screen.dart';

class PaymentInListScreen extends StatefulWidget {
  const PaymentInListScreen({super.key});

  @override
  State<PaymentInListScreen> createState() => _PaymentInListScreenState();
}

class _PaymentInListScreenState extends State<PaymentInListScreen> {
  List<PaymentIn> _all = [];
  List<PaymentIn> _filtered = [];
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
      final data = await PaymentInService.getAllPaymentIns();
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
    _filtered = _all.where((p) {
      final q = _search.toLowerCase();
      final matchSearch = q.isEmpty ||
          p.customerName.toLowerCase().contains(q) ||
          p.referenceNumber.toLowerCase().contains(q);
      final matchBranch = _branchFilter == 'All' || p.branch == _branchFilter;
      return matchSearch && matchBranch;
    }).toList();
  }

  Future<void> _delete(String id) async {
    final confirm = await showConfirmDeleteDialog(
      context,
      title: 'Delete Payment',
      message: 'Are you sure you want to delete this payment record?',
    );
    if (!confirm) return;
    final result = await PaymentInService.deletePaymentIn(id);
    if (result['success'] == true) {
      setState(() {
        _all.removeWhere((p) => p.id == id);
        _applyFilter();
      });
      if (mounted) showAppSnack(context, 'Payment deleted successfully');
    } else if (mounted) {
      showAppSnack(context, result['message'] ?? 'Delete failed', isError: true);
    }
  }

  double get _totalValue => _filtered.fold(0.0, (sum, p) => sum + p.amount);

  // ── Edit an existing payment ────────────────────────────────────────────
  Future<void> _editPayment(PaymentIn p) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Edit Payment In'),
        builder: (_) => AddPaymentInScreen(paymentToEdit: p),
      ),
    );
    if (result == true) _fetch();
  }

  // ── Share payment details as text ───────────────────────────────────────
  Future<void> _sharePayment(PaymentIn p) async {
    final buffer = StringBuffer()
      ..writeln('Payment-In Receipt')
      ..writeln('Customer: ${p.customerName}')
      ..writeln('Amount: ₹${p.amount.toStringAsFixed(2)}')
      ..writeln('Payment Date: ${p.paymentDate}')
      ..writeln('Payment Mode: ${p.paymentMode}')
      ..writeln('Reference No.: ${p.referenceNumber.isEmpty ? '—' : p.referenceNumber}')
      ..writeln('Branch: ${kBranchLabels[p.branch] ?? p.branch}');
    if (p.invoiceAllocations.isNotEmpty) {
      buffer.writeln('Applied To: ${p.invoiceAllocations.map((a) => '${a.invoiceNo} (₹${a.amountApplied.toStringAsFixed(0)})').join(', ')}');
    }
    if (p.advanceAmount > 0) buffer.writeln('Advance / Unused: ₹${p.advanceAmount.toStringAsFixed(2)}');
    if (p.notes.trim().isNotEmpty) buffer.writeln('Notes: ${p.notes}');
    await Share.share(buffer.toString(), subject: 'Payment from ${p.customerName}');
  }

  // ── Print — SkyLynk-branded PDF receipt, opened in the browser's
  // print/preview dialog ───────────────────────────────────────────────
  Future<void> _printPayment(PaymentIn p) async {
    try {
      await Printing.layoutPdf(onLayout: (format) => PaymentInPdfService.generate(p));
    } catch (e) {
      if (mounted) showAppSnack(context, 'Failed to generate PDF: $e', isError: true);
    }
  }

  // ── Share as PDF — sends the generated PDF receipt straight to
  // WhatsApp/Email/etc via the native share sheet ────────────────────────
  Future<void> _sharePdf(PaymentIn p) async {
    try {
      final bytes = await PaymentInPdfService.generate(p);
      await Printing.sharePdf(bytes: bytes, filename: 'payment_in_${p.referenceNumber.isEmpty ? p.id ?? 'receipt' : p.referenceNumber}.pdf');
    } catch (e) {
      if (mounted) showAppSnack(context, 'Failed to share PDF: $e', isError: true);
    }
  }

  // ── Bulk export — all filtered payments as a single PDF report ─────────
  Future<void> _exportPdf() async {
    if (_filtered.isEmpty) {
      showAppSnack(context, 'Nothing to export', isError: true);
      return;
    }
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: 'Payment-In Report'),
          pw.Table.fromTextArray(
            headers: ['Date', 'Customer', 'Mode', 'Reference', 'Branch', 'Amount'],
            data: _filtered
                .map((p) => [
              p.paymentDate,
              p.customerName,
              p.paymentMode,
              p.referenceNumber.isEmpty ? '-' : p.referenceNumber,
              kBranchLabels[p.branch] ?? p.branch,
              p.amount.toStringAsFixed(2),
            ])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Total Received: Rs. ${_totalValue.toStringAsFixed(2)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'payment_in_report.pdf');
  }

  // ── View full payment details ───────────────────────────────────────────
  void _viewPayment(PaymentIn p) {
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
                  child: const Icon(Icons.payments_rounded, color: AppColors.teal, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.customerName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.navy)),
                      const SizedBox(height: 2),
                      Text(p.paymentMode, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                Text('₹${p.amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navy)),
              ]),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              if (p.phone.trim().isNotEmpty) _detailRow('Phone', p.phone),
              _detailRow('Reference No.', p.referenceNumber.isEmpty ? '—' : p.referenceNumber),
              _detailRow('Branch', kBranchLabels[p.branch] ?? p.branch),
              _detailRow('Payment Date', p.paymentDate),
              _detailRow('Payment Mode', p.paymentMode),
              if (p.invoiceAllocations.isNotEmpty)
                _detailRow('Applied To', p.invoiceAllocations
                    .map((a) => '${a.invoiceNo} (₹${a.amountApplied.toStringAsFixed(0)})')
                    .join(', ')),
              if (p.advanceAmount > 0)
                _detailRow('Advance / Unused', '₹${p.advanceAmount.toStringAsFixed(2)}'),
              if (p.notes.trim().isNotEmpty) _detailRow('Notes', p.notes),
              if ((p.attachmentName ?? '').isNotEmpty) _detailRow('Attachment', p.attachmentName!),
              if ((p.attachmentBase64 ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(base64Decode(p.attachmentBase64!), fit: BoxFit.cover),
                ),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _printPayment(p),
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
                    onPressed: () => _sharePdf(p),
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
                    onPressed: () => _sharePayment(p),
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
                      _editPayment(p);
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
              Row(children: [
                Expanded(
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
              ]),
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
          width: 110,
          child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: AppColors.navy, fontSize: 13.5, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );

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
        title: const Text('Payment-In',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
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
                  icon: Icons.payments_rounded,
                  title: 'Payment-In Records',
                  subtitle: 'Track all customer receipts',
                ),
                const SizedBox(height: 14),
                Row(children: [
                  StatChip(
                      icon: Icons.receipt_rounded,
                      label: 'Payments',
                      value: '${_filtered.length}'),
                  const SizedBox(width: 12),
                  StatChip(
                      icon: Icons.currency_rupee_rounded,
                      label: 'Total Received',
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
                      hintText: 'Search customer, reference...',
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
        label: const Text('Add Payment', style: TextStyle(fontWeight: FontWeight.w600)),
        onPressed: () async {
          final result = await Navigator.push<bool>(
              context, MaterialPageRoute(settings: const RouteSettings(name: 'Add Payment In'), builder: (_) => const AddPaymentInScreen()));
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
          child: const Icon(Icons.payments_outlined, size: 60, color: AppColors.teal)),
      const SizedBox(height: 20),
      const Text('No payments found',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy)),
      const SizedBox(height: 8),
      Text(
        _search.isNotEmpty ? 'Try adjusting your search' : 'Tap + to add your first payment',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      ),
    ]),
  );

  Widget _buildCard(PaymentIn p, int index) {
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
              child: Icon(Icons.payments_rounded, color: accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.customerName,
                      style:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
                  const SizedBox(height: 2),
                  Text(p.paymentMode, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            Text('₹${p.amount.toStringAsFixed(0)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: accent)),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (v) {
                switch (v) {
                  case 'print': _printPayment(p); break;
                  case 'pdf': _sharePdf(p); break;
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
            if (p.invoiceAllocations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  InfoChip(Icons.link_rounded,
                      'Applied to ${p.invoiceAllocations.length} invoice(s)'),
                  if (p.advanceAmount > 0) ...[
                    const SizedBox(width: 8),
                    InfoChip(Icons.savings_rounded,
                        'Advance ₹${p.advanceAmount.toStringAsFixed(0)}'),
                  ],
                ]),
              ),
            Row(children: [
              InfoChip(Icons.receipt_long_rounded,
                  p.referenceNumber.isEmpty ? 'No reference' : p.referenceNumber),
              const SizedBox(width: 8),
              InfoChip(Icons.location_city_rounded, kBranchLabels[p.branch] ?? p.branch),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: InfoChip(Icons.calendar_today_rounded, p.paymentDate)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _viewPayment(p),
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
                  onTap: () => _editPayment(p),
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
                  onTap: () => _sharePayment(p),
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
              if (p.id != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _delete(p.id!),
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