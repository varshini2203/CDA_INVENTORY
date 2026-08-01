// lib/screens/delivery_challan/delivery_challan_view_screen.dart
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cda_inventory/models/delivery_challan.dart';
import 'package:cda_inventory/services/delivery_challan_service.dart';
import 'package:cda_inventory/services/delivery_challan_pdf_service.dart';
import 'package:cda_inventory/services/invoice_service.dart';
import 'package:cda_inventory/shared/inventory_ui.dart';
import 'add_delivery_challan_screen.dart';

class DeliveryChallanViewScreen extends StatefulWidget {
  final DeliveryChallan challan;
  const DeliveryChallanViewScreen({super.key, required this.challan});

  @override
  State<DeliveryChallanViewScreen> createState() => _DeliveryChallanViewScreenState();
}

class _DeliveryChallanViewScreenState extends State<DeliveryChallanViewScreen> {
  static const kBg = Color(0xFFF4F6F9);
  static const kNavy = Color(0xFF0A1628);
  static const kBlue = Color(0xFF2F6FE4);
  static const kGreen = Color(0xFF00B894);
  static const kRed = Color(0xFFE94D5F);
  static const kOrange = Color(0xFFFFB800);
  static const kPurple = Color(0xFF8B5CF6);
  static const kBorder = Color(0xFFE3E7EE);
  static const kTextDark = Color(0xFF1F2937);
  static const kTextSub = Color(0xFF6B7280);

  late DeliveryChallan _challan;
  bool _isLoading = false;
  bool _resultChanged = false;

  @override
  void initState() {
    super.initState();
    _challan = widget.challan;
  }

  Future<void> _refresh() async {
    if (_challan.id == null) return;
    setState(() => _isLoading = true);
    try {
      final updated = await DeliveryChallanService.fetchChallanById(_challan.id!);
      if (!mounted) return;
      setState(() => _challan = updated);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Delivered': return kBlue;
      case 'Converted': return kGreen;
      case 'Cancelled': return kRed;
      default: return kOrange;
    }
  }

  Future<void> _editChallan() async {
    final result = await Navigator.push(context, MaterialPageRoute(
        settings: const RouteSettings(name: 'Edit Delivery Challan'),
        builder: (_) => AddDeliveryChallanScreen(existing: _challan)));
    if (result == true) {
      _resultChanged = true;
      _refresh();
    }
  }

  Future<void> _convert() async {
    if (_challan.status == 'Converted') {
      showAppSnack(context, 'Already converted to invoice ${_challan.convertedInvoiceNo ?? ''}', isError: true);
      return;
    }
    final confirm = await showConfirmDeleteDialog(
      context,
      title: 'Convert to Sale Invoice?',
      message: 'This will create a new Sale Invoice from ${_challan.challanNo} with all its items.',
    );
    if (!confirm) return;
    setState(() => _isLoading = true);
    try {
      final invoiceService = InvoiceService();
      final newNo = await invoiceService.suggestNextInvoiceNumber(forceRefresh: true);
      final invoice = await DeliveryChallanService.convertToInvoice(_challan, newInvoiceNo: newNo);
      if (!mounted) return;
      showAppSnack(context, 'Converted to Sale Invoice ${invoice.invoiceNo}');
      _resultChanged = true;
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'Conversion failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showConfirmDeleteDialog(
      context,
      title: 'Delete Delivery Challan',
      message: 'Are you sure you want to delete ${_challan.challanNo}?',
    );
    if (!confirm || _challan.id == null) return;
    try {
      await DeliveryChallanService.deleteChallan(_challan.id!);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'Delete failed: $e', isError: true);
    }
  }

  Future<void> _share() async {
    final b = StringBuffer();
    b.writeln('DELIVERY CHALLAN');
    b.writeln(_challan.challanNo);
    b.writeln('Date: ${_challan.challanDate}');
    if (_challan.customer != null) b.writeln('Customer: ${_challan.customer!.name}');
    if (_challan.vehicleNo?.isNotEmpty == true) b.writeln('Vehicle No: ${_challan.vehicleNo}');
    if (_challan.transportName?.isNotEmpty == true) b.writeln('Transport: ${_challan.transportName}');
    b.writeln('');
    for (final li in _challan.lineItems) {
      b.writeln('${li.description}  x${li.quantity} ${li.unit}  @ ₹${li.unitPrice.toStringAsFixed(2)}  = ₹${li.lineTotal.toStringAsFixed(2)}');
    }
    b.writeln('');
    b.writeln('Total: ₹${_challan.grandTotal.toStringAsFixed(2)}');
    await Share.share(b.toString(), subject: 'Delivery Challan ${_challan.challanNo}');
  }

  // ── Print — SkyLynk-branded PDF, opened in the browser's print/preview
  // dialog ───────────────────────────────────────────────────────────────
  Future<void> _print() async {
    try {
      await Printing.layoutPdf(onLayout: (format) => DeliveryChallanPdfService.generate(_challan));
    } catch (e) {
      if (mounted) showAppSnack(context, 'Failed to generate PDF: $e', isError: true);
    }
  }

  // ── Download / Share the generated PDF straight to WhatsApp/Email/etc
  // via the native share sheet ─────────────────────────────────────────
  Future<void> _sharePdf() async {
    try {
      final bytes = await DeliveryChallanPdfService.generate(_challan);
      await Printing.sharePdf(bytes: bytes, filename: 'delivery_challan_${_challan.challanNo}.pdf');
    } catch (e) {
      if (mounted) showAppSnack(context, 'Failed to share PDF: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _resultChanged);
        return false;
      },
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, size: 20), onPressed: () => Navigator.pop(context, _resultChanged)),
          title: Text(_challan.challanNo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          actions: [
            IconButton(icon: const Icon(Icons.print_outlined), tooltip: 'Print', onPressed: _print),
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _editChallan),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                switch (v) {
                  case 'pdf': _sharePdf(); break;
                  case 'share_text': _share(); break;
                  case 'delete': _delete(); break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf_outlined, size: 18, color: kBlue), SizedBox(width: 10), Text('Share as PDF')])),
                PopupMenuItem(value: 'share_text', child: Row(children: [Icon(Icons.ios_share_rounded, size: 18, color: kBlue), SizedBox(width: 10), Text('Share as Text')])),
                PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: kRed), SizedBox(width: 10), Text('Delete')])),
              ],
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kBlue))
            : RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _statusCard(),
              const SizedBox(height: 14),
              _detailsCard(),
              const SizedBox(height: 14),
              _itemsCard(),
              const SizedBox(height: 14),
              _totalsCard(),
              if (_challan.notes.isNotEmpty) ...[const SizedBox(height: 14), _notesCard()],
              const SizedBox(height: 22),
              _actionsRow(),
              const SizedBox(height: 12),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(color: kPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.local_shipping_rounded, color: kPurple, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_challan.customer?.name.isNotEmpty == true ? _challan.customer!.name : 'Walk-in Customer',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextDark)),
            const SizedBox(height: 2),
            Text(_challan.challanDate, style: const TextStyle(fontSize: 12.5, color: kTextSub)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: _statusColor(_challan.status).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Text(_challan.status, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _statusColor(_challan.status))),
        ),
      ]),
    );
  }

  Widget _detailsCard() {
    final rows = <MapEntry<String, String>>[
      if (_challan.customer?.phone?.isNotEmpty == true) MapEntry('Phone', _challan.customer!.phone!),
      MapEntry('Branch', _challan.branch),
      if (_challan.dueDate?.isNotEmpty == true) MapEntry('Due Date', _challan.dueDate!),
      if (_challan.vehicleNo?.isNotEmpty == true) MapEntry('Vehicle No.', _challan.vehicleNo!),
      if (_challan.transportName?.isNotEmpty == true) MapEntry('Transport', _challan.transportName!),
      if (_challan.poNumber?.isNotEmpty == true) MapEntry('PO Number', _challan.poNumber!),
      if (_challan.convertedInvoiceNo?.isNotEmpty == true) MapEntry('Converted Invoice', _challan.convertedInvoiceNo!),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
        const SizedBox(height: 10),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 130, child: Text(r.key, style: const TextStyle(fontSize: 12.5, color: kTextSub))),
              Expanded(child: Text(r.value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextDark))),
            ]),
          ),
      ]),
    );
  }

  Widget _itemsCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Align(alignment: Alignment.centerLeft,
              child: Text('Items (${_challan.lineItems.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark))),
        ),
        for (int i = 0; i < _challan.lineItems.length; i++) _itemTile(i),
      ]),
    );
  }

  Widget _itemTile(int i) {
    final li = _challan.lineItems[i];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: kBorder.withOpacity(i == 0 ? 0 : 1)))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(li.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextDark)),
            const SizedBox(height: 2),
            Text('${li.quantity} ${li.unit} × ₹${li.unitPrice.toStringAsFixed(2)}${li.discountPercent > 0 ? '  (-${li.discountPercent}%)' : ''}',
                style: const TextStyle(fontSize: 11.5, color: kTextSub)),
          ]),
        ),
        Text('₹${li.lineTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextDark)),
      ]),
    );
  }

  Widget _totalsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _sumLine('Subtotal', _challan.subtotal),
        if (_challan.gstEnabled && !_challan.isInterState) ...[
          _sumLine('CGST (${_challan.cgstPercent}%)', _challan.cgstAmount),
          _sumLine('SGST (${_challan.sgstPercent}%)', _challan.sgstAmount),
        ],
        if (_challan.gstEnabled && _challan.isInterState) _sumLine('IGST (${_challan.igstPercent}%)', _challan.igstAmount),
        if (!_challan.gstEnabled && _challan.lineTaxTotal > 0) _sumLine('Tax', _challan.lineTaxTotal),
        if (_challan.shipping > 0) _sumLine('Shipping', _challan.shipping),
        if (_challan.roundOffEnabled && _challan.roundOffAmount != 0) _sumLine('Round Off', _challan.roundOffAmount),
        const Divider(height: 20, color: kBorder),
        Row(children: [
          const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kTextDark)),
          const Spacer(),
          Text('₹${_challan.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kGreen)),
        ]),
      ]),
    );
  }

  Widget _sumLine(String label, double value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 12.5, color: kTextSub)),
      const Spacer(),
      Text('₹${value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextDark)),
    ]),
  );

  Widget _notesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Notes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
        const SizedBox(height: 8),
        Text(_challan.notes, style: const TextStyle(fontSize: 13, color: kTextSub)),
      ]),
    );
  }

  Widget _actionsRow() {
    final canConvert = _challan.status != 'Converted' && _challan.status != 'Cancelled';
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _delete,
          style: OutlinedButton.styleFrom(foregroundColor: kRed, side: const BorderSide(color: kRed),
              padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: ElevatedButton.icon(
          onPressed: canConvert ? _convert : null,
          style: ElevatedButton.styleFrom(backgroundColor: kGreen, foregroundColor: Colors.white, elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          icon: const Icon(Icons.sync_alt_rounded, size: 18),
          label: Text(canConvert ? 'Convert to Sale' : 'Converted', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }
}