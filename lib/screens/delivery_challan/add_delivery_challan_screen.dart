// lib/screens/delivery_challan/add_delivery_challan_screen.dart
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:cda_inventory/models/delivery_challan.dart';
import 'package:cda_inventory/models/invoice_line_item.dart';
import 'package:cda_inventory/models/customer_details.dart';
import 'package:cda_inventory/services/delivery_challan_service.dart';
import 'package:cda_inventory/services/delivery_challan_pdf_service.dart';
import 'package:cda_inventory/shared/inventory_ui.dart';

class AddDeliveryChallanScreen extends StatefulWidget {
  final DeliveryChallan? existing;
  const AddDeliveryChallanScreen({super.key, this.existing});
  @override
  State<AddDeliveryChallanScreen> createState() => _AddDeliveryChallanScreenState();
}

class _AddDeliveryChallanScreenState extends State<AddDeliveryChallanScreen> {
  static const kBg = Color(0xFFF4F6F9);
  static const kTabBar = Color(0xFFECEEF1);
  static const kNavy = Color(0xFF0A1628);
  static const kBlue = Color(0xFF2F6FE4);
  static const kBorder = Color(0xFFE3E7EE);
  static const kHeaderBg = Color(0xFFF7F9FC);
  static const kTextDark = Color(0xFF1F2937);
  static const kTextSub = Color(0xFF6B7280);
  static const kTextMute = Color(0xFF9CA3AF);
  static const kGreen = Color(0xFF00B894);
  static const kPurple = Color(0xFF8B5CF6);

  final customerController = TextEditingController();
  final phoneController = TextEditingController();
  final challanDateController = TextEditingController();
  final dueDateController = TextEditingController();
  final notesController = TextEditingController();
  final shippingController = TextEditingController(text: '0');
  final vehicleController = TextEditingController();
  final transportController = TextEditingController();
  final poController = TextEditingController();

  String selectedBranch = kBranches.first;
  String selectedStatus = 'Pending';
  bool gstEnabled = false;
  bool isInterState = false;
  bool roundOffEnabled = true;
  bool _isLoading = false;

  final List<_LineRow> _rows = [];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    challanDateController.text = _fmt(DateTime.now());
    final e = widget.existing;
    if (e != null) {
      customerController.text = e.customer?.name ?? '';
      phoneController.text = e.customer?.phone ?? '';
      challanDateController.text = e.challanDate;
      dueDateController.text = e.dueDate ?? '';
      notesController.text = e.notes;
      shippingController.text = e.shipping.toString();
      vehicleController.text = e.vehicleNo ?? '';
      transportController.text = e.transportName ?? '';
      poController.text = e.poNumber ?? '';
      selectedBranch = e.branch.isNotEmpty ? e.branch : kBranches.first;
      selectedStatus = e.status;
      gstEnabled = e.gstEnabled;
      isInterState = e.isInterState;
      roundOffEnabled = e.roundOffEnabled;
      for (final li in e.lineItems) {
        final row = _LineRow();
        row.descController.text = li.description;
        row.qtyController.text = li.quantity.toString();
        row.priceController.text = li.unitPrice.toString();
        row.discountController.text = li.discountPercent.toString();
        row.taxController.text = li.taxPercent.toString();
        row.unit = li.unit;
        _rows.add(row);
      }
      if (_rows.isEmpty) _addRow();
    } else {
      _addRow();
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  void _addRow() => setState(() => _rows.add(_LineRow()));
  void _removeRow(int i) {
    _rows[i].dispose();
    setState(() => _rows.removeAt(i));
  }

  Future<void> _pickDate(TextEditingController c) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: kNavy, onPrimary: Colors.white)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => c.text = _fmt(picked));
  }

  List<InvoiceLineItem> get _lineItems => _rows
      .where((r) => r.descController.text.trim().isNotEmpty)
      .map((r) => InvoiceLineItem(
    id: r.id,
    description: r.descController.text.trim(),
    quantity: int.tryParse(r.qtyController.text.trim()) ?? 0,
    unit: r.unit,
    unitPrice: double.tryParse(r.priceController.text.trim()) ?? 0,
    discountPercent: double.tryParse(r.discountController.text.trim()) ?? 0,
    taxPercent: gstEnabled ? 0 : (double.tryParse(r.taxController.text.trim()) ?? 0),
  ))
      .toList();

  double get _subtotal => _lineItems.fold(0.0, (s, i) => s + i.taxableAmount);
  double get _shipping => double.tryParse(shippingController.text.trim()) ?? 0;
  double get _lineTax => _lineItems.fold(0.0, (s, i) => s + i.taxAmount);
  double get _cgst => gstEnabled && !isInterState ? _subtotal * 0.09 : 0;
  double get _sgst => gstEnabled && !isInterState ? _subtotal * 0.09 : 0;
  double get _igst => gstEnabled && isInterState ? _subtotal * 0.18 : 0;
  double get _totalTax => gstEnabled ? _cgst + _sgst + _igst : _lineTax;
  double get _preRound => _subtotal + _totalTax + _shipping;
  double get _roundOff => roundOffEnabled ? (_preRound.roundToDouble() - _preRound) : 0;
  double get _grandTotal => _preRound + _roundOff;

  // ── Build a DeliveryChallan object from the current form state. Used by
  //    _printPreview() for a live preview of unsaved changes. ─────────────
  DeliveryChallan _buildDraftChallan() {
    return DeliveryChallan(
      id: widget.existing?.id,
      challanNo: widget.existing?.challanNo ?? 'DRAFT',
      customer: CustomerDetails(name: customerController.text.trim(), phone: phoneController.text.trim()),
      challanDate: challanDateController.text.trim(),
      dueDate: dueDateController.text.trim().isEmpty ? null : dueDateController.text.trim(),
      status: selectedStatus,
      branch: selectedBranch,
      notes: notesController.text.trim(),
      lineItems: _lineItems,
      shipping: _shipping,
      roundOffEnabled: roundOffEnabled,
      gstEnabled: gstEnabled,
      isInterState: isInterState,
      vehicleNo: vehicleController.text.trim().isEmpty ? null : vehicleController.text.trim(),
      transportName: transportController.text.trim().isEmpty ? null : transportController.text.trim(),
      poNumber: poController.text.trim().isEmpty ? null : poController.text.trim(),
      convertedInvoiceId: widget.existing?.convertedInvoiceId,
      convertedInvoiceNo: widget.existing?.convertedInvoiceNo,
      createdAt: widget.existing?.createdAt,
    );
  }

  Future<void> _printPreview() async {
    if (_lineItems.isEmpty) {
      showAppSnack(context, 'Add at least one item to preview', isError: true);
      return;
    }
    final draft = _buildDraftChallan();
    await Printing.layoutPdf(onLayout: (format) => DeliveryChallanPdfService.generate(draft));
  }

  Future<void> _save() async {
    if (customerController.text.trim().isEmpty) {
      showAppSnack(context, 'Customer name is required', isError: true);
      return;
    }
    if (_lineItems.isEmpty) {
      showAppSnack(context, 'Add at least one item', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (_isEdit) {
        final updated = widget.existing!.copyWith(status: selectedStatus);
        final challan = DeliveryChallan(
          id: updated.id,
          challanNo: updated.challanNo,
          customer: CustomerDetails(name: customerController.text.trim(), phone: phoneController.text.trim()),
          challanDate: challanDateController.text.trim(),
          dueDate: dueDateController.text.trim().isEmpty ? null : dueDateController.text.trim(),
          status: selectedStatus,
          branch: selectedBranch,
          notes: notesController.text.trim(),
          lineItems: _lineItems,
          shipping: _shipping,
          roundOffEnabled: roundOffEnabled,
          gstEnabled: gstEnabled,
          isInterState: isInterState,
          vehicleNo: vehicleController.text.trim().isEmpty ? null : vehicleController.text.trim(),
          transportName: transportController.text.trim().isEmpty ? null : transportController.text.trim(),
          poNumber: poController.text.trim().isEmpty ? null : poController.text.trim(),
          convertedInvoiceId: widget.existing!.convertedInvoiceId,
          convertedInvoiceNo: widget.existing!.convertedInvoiceNo,
        );
        await DeliveryChallanService.updateChallan(challan);
        if (!mounted) return;
        setState(() => _isLoading = false);
        showAppSnack(context, 'Delivery challan updated');
        Navigator.pop(context, true);
        return;
      }

      final challanNo = await DeliveryChallanService.generateChallanNo();
      final challan = DeliveryChallan(
        challanNo: challanNo,
        customer: CustomerDetails(
          name: customerController.text.trim(),
          phone: phoneController.text.trim(),
        ),
        challanDate: challanDateController.text.trim(),
        dueDate: dueDateController.text.trim().isEmpty ? null : dueDateController.text.trim(),
        status: selectedStatus,
        branch: selectedBranch,
        notes: notesController.text.trim(),
        lineItems: _lineItems,
        shipping: _shipping,
        roundOffEnabled: roundOffEnabled,
        gstEnabled: gstEnabled,
        isInterState: isInterState,
        vehicleNo: vehicleController.text.trim().isEmpty ? null : vehicleController.text.trim(),
        transportName: transportController.text.trim().isEmpty ? null : transportController.text.trim(),
        poNumber: poController.text.trim().isEmpty ? null : poController.text.trim(),
      );
      await DeliveryChallanService.createChallan(challan);
      if (!mounted) return;
      setState(() => _isLoading = false);
      showSuccessDialog(
        context,
        title: 'Delivery Challan Created!',
        message: 'Challan $challanNo has been saved successfully.',
        onAddMore: () => setState(() {
          customerController.clear();
          phoneController.clear();
          notesController.clear();
          vehicleController.clear();
          transportController.clear();
          poController.clear();
          shippingController.text = '0';
          for (final r in _rows) r.dispose();
          _rows.clear();
          _addRow();
        }),
        onViewList: () => Navigator.pop(context, true),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showAppSnack(context, 'Failed to save challan: $e', isError: true);
    }
  }

  InputDecoration _dec({String? hint, EdgeInsets? padding}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: kTextMute, fontSize: 13),
    isDense: true,
    contentPadding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kBlue)),
    filled: true,
    fillColor: Colors.white,
  );

  @override
  void dispose() {
    customerController.dispose();
    phoneController.dispose();
    challanDateController.dispose();
    dueDateController.dispose();
    notesController.dispose();
    shippingController.dispose();
    vehicleController.dispose();
    transportController.dispose();
    poController.dispose();
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text(_isEdit ? 'Edit Delivery Challan' : 'Delivery Challan', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SafeArea(
        child: Theme(
          data: Theme.of(context).copyWith(
            brightness: Brightness.light,
            colorScheme: Theme.of(context).colorScheme.copyWith(brightness: Brightness.light, onSurface: kTextDark, surface: Colors.white),
            textTheme: Theme.of(context).textTheme.apply(bodyColor: kTextDark, displayColor: kTextDark),
            canvasColor: Colors.white,
          ),
          child: Column(children: [
            Container(height: 44, color: kTabBar, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 10),
                child: Text(_isEdit ? 'Editing ${widget.existing!.challanNo}' : 'New Delivery Challan',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextDark))),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _topRow(),
                  const SizedBox(height: 18),
                  _transportCard(),
                  const SizedBox(height: 18),
                  _itemsCard(),
                  const SizedBox(height: 18),
                  _bottomRow(),
                  const SizedBox(height: 22),
                  _footer(),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _topRow() {
    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 760;
      final customerBlock = Row(children: [
        Expanded(flex: 2, child: TextFormField(controller: customerController, style: const TextStyle(fontSize: 13, color: kTextDark),
            textCapitalization: TextCapitalization.words, decoration: _dec(hint: 'Customer Name *'))),
        const SizedBox(width: 10),
        Expanded(child: TextFormField(controller: phoneController, keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 13, color: kTextDark), decoration: _dec(hint: 'Phone No.'))),
      ]);
      final metaBlock = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _metaRow('Challan Date', InkWell(onTap: () => _pickDate(challanDateController), child: SizedBox(width: 180,
            child: InputDecorator(decoration: _dec(), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(challanDateController.text, style: const TextStyle(fontSize: 13, color: kTextDark)),
              const SizedBox(width: 6), const Icon(Icons.calendar_today_rounded, size: 15, color: kTextMute),
            ]))))),
        const SizedBox(height: 8),
        _metaRow('Due Date', InkWell(onTap: () => _pickDate(dueDateController), child: SizedBox(width: 180,
            child: InputDecorator(decoration: _dec(), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(dueDateController.text.isEmpty ? 'Optional' : dueDateController.text,
                  style: TextStyle(fontSize: 13, color: dueDateController.text.isEmpty ? kTextMute : kTextDark)),
              const SizedBox(width: 6), const Icon(Icons.calendar_today_rounded, size: 15, color: kTextMute),
            ]))))),
        const SizedBox(height: 8),
        _metaRow('Branch', SizedBox(width: 180, child: DropdownButtonFormField<String>(
            initialValue: selectedBranch, isExpanded: true, dropdownColor: Colors.white,
            style: const TextStyle(fontSize: 12.5, color: kTextDark), decoration: _dec(),
            items: kBranches.map((b) => DropdownMenuItem(value: b, child: Text(kBranchLabels[b] ?? b, style: const TextStyle(fontSize: 12.5, color: kTextDark)))).toList(),
            onChanged: (v) => setState(() => selectedBranch = v ?? selectedBranch)))),
        const SizedBox(height: 8),
        _metaRow('Status', SizedBox(width: 180, child: DropdownButtonFormField<String>(
            initialValue: selectedStatus, isExpanded: true, dropdownColor: Colors.white,
            style: const TextStyle(fontSize: 12.5, color: kTextDark), decoration: _dec(),
            items: DeliveryChallan.statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12.5, color: kTextDark)))).toList(),
            onChanged: (v) => setState(() => selectedStatus = v ?? selectedStatus)))),
      ]);
      return narrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [customerBlock, const SizedBox(height: 18), metaBlock])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: customerBlock), const SizedBox(width: 24), Expanded(flex: 3, child: metaBlock)]);
    });
  }

  Widget _metaRow(String label, Widget field) => Row(mainAxisAlignment: MainAxisAlignment.end, children: [
    Text(label, style: const TextStyle(fontSize: 12.5, color: kTextSub, fontWeight: FontWeight.w500)),
    const SizedBox(width: 14), field,
  ]);

  Widget _transportCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.local_shipping_rounded, size: 16, color: kPurple),
          SizedBox(width: 8),
          Text('Transport Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
        ]),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final narrow = c.maxWidth < 700;
          final fields = [
            Expanded(child: TextFormField(controller: vehicleController, style: const TextStyle(fontSize: 13, color: kTextDark),
                textCapitalization: TextCapitalization.characters, decoration: _dec(hint: 'Vehicle No.'))),
            const SizedBox(width: 10, height: 10),
            Expanded(child: TextFormField(controller: transportController, style: const TextStyle(fontSize: 13, color: kTextDark),
                decoration: _dec(hint: 'Transport Name'))),
            const SizedBox(width: 10, height: 10),
            Expanded(child: TextFormField(controller: poController, style: const TextStyle(fontSize: 13, color: kTextDark),
                decoration: _dec(hint: 'PO Number'))),
          ];
          return narrow
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(controller: vehicleController, style: const TextStyle(fontSize: 13, color: kTextDark),
                textCapitalization: TextCapitalization.characters, decoration: _dec(hint: 'Vehicle No.')),
            const SizedBox(height: 10),
            TextFormField(controller: transportController, style: const TextStyle(fontSize: 13, color: kTextDark),
                decoration: _dec(hint: 'Transport Name')),
            const SizedBox(height: 10),
            TextFormField(controller: poController, style: const TextStyle(fontSize: 13, color: kTextDark),
                decoration: _dec(hint: 'PO Number')),
          ])
              : Row(children: fields);
        }),
      ]),
    );
  }

  Widget _itemsCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Row(children: [
            const Text('Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
            const Spacer(),
            Row(children: [
              const Text('GST', style: TextStyle(fontSize: 12, color: kTextSub)),
              Switch(value: gstEnabled, activeThumbColor: kBlue, onChanged: (v) => setState(() => gstEnabled = v)),
              if (gstEnabled) ...[
                const SizedBox(width: 6),
                const Text('Inter-state', style: TextStyle(fontSize: 12, color: kTextSub)),
                Switch(value: isInterState, activeThumbColor: kBlue, onChanged: (v) => setState(() => isInterState = v)),
              ],
            ]),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 900,
            child: Column(children: [
              Container(color: kHeaderBg, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: const Row(children: [
                    SizedBox(width: 260, child: Text('Item', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kTextSub))),
                    SizedBox(width: 90, child: Text('Qty', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kTextSub))),
                    SizedBox(width: 90, child: Text('Unit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kTextSub))),
                    SizedBox(width: 110, child: Text('Price', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kTextSub))),
                    SizedBox(width: 90, child: Text('Disc %', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kTextSub))),
                    SizedBox(width: 90, child: Text('Tax %', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kTextSub))),
                    SizedBox(width: 110, child: Text('Amount', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kTextSub))),
                    SizedBox(width: 40, child: Text('')),
                  ])),
              for (int i = 0; i < _rows.length; i++) _itemRow(i),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                    onPressed: _addRow, icon: const Icon(Icons.add_rounded, size: 16, color: kBlue),
                    label: const Text('Add Row', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kBlue)))),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _itemRow(int i) {
    final r = _rows[i];
    final qty = int.tryParse(r.qtyController.text.trim()) ?? 0;
    final price = double.tryParse(r.priceController.text.trim()) ?? 0;
    final disc = double.tryParse(r.discountController.text.trim()) ?? 0;
    final tax = gstEnabled ? 0 : (double.tryParse(r.taxController.text.trim()) ?? 0);
    final gross = qty * price;
    final taxable = gross - (gross * disc / 100);
    final amount = taxable + (taxable * tax / 100);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 260, child: TextFormField(controller: r.descController, style: const TextStyle(fontSize: 12.5, color: kTextDark),
            onChanged: (_) => setState(() {}), decoration: _dec(hint: 'Item / service name', padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)))),
        const SizedBox(width: 8),
        SizedBox(width: 82, child: TextFormField(controller: r.qtyController, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12.5, color: kTextDark),
            onChanged: (_) => setState(() {}), decoration: _dec(hint: '1', padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)))),
        const SizedBox(width: 8),
        SizedBox(width: 82, child: DropdownButtonFormField<String>(initialValue: r.unit, isExpanded: true, dropdownColor: Colors.white,
            style: const TextStyle(fontSize: 11.5, color: kTextDark), decoration: _dec(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
            items: const ['NONE', 'PCS', 'KG', 'BOX', 'HRS'].map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 11.5)))).toList(),
            onChanged: (v) => setState(() => r.unit = v ?? r.unit))),
        const SizedBox(width: 8),
        SizedBox(width: 102, child: TextFormField(controller: r.priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontSize: 12.5, color: kTextDark),
            onChanged: (_) => setState(() {}), decoration: _dec(hint: '0.00', padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)))),
        const SizedBox(width: 8),
        SizedBox(width: 82, child: TextFormField(controller: r.discountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontSize: 12.5, color: kTextDark),
            onChanged: (_) => setState(() {}), decoration: _dec(hint: '0', padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)))),
        const SizedBox(width: 8),
        SizedBox(width: 82, child: TextFormField(controller: r.taxController, enabled: !gstEnabled, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontSize: 12.5, color: kTextDark),
            onChanged: (_) => setState(() {}), decoration: _dec(hint: '0', padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)))),
        const SizedBox(width: 8),
        SizedBox(width: 102, child: Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextDark))),
        SizedBox(width: 40, child: IconButton(icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFE94D5F)), onPressed: _rows.length > 1 ? () => _removeRow(i) : null)),
      ]),
    );
  }

  Widget _bottomRow() {
    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 760;
      final notesCard = Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Notes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
            const SizedBox(height: 12),
            TextFormField(controller: notesController, maxLines: 4, style: const TextStyle(fontSize: 13, color: kTextDark),
                decoration: _dec(hint: 'Terms, delivery instructions, etc.')),
          ]));
      final totalsCard = Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [const Text('Shipping (₹)', style: TextStyle(fontSize: 12.5, color: kTextSub)), const Spacer(),
              SizedBox(width: 100, child: TextFormField(controller: shippingController, textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontSize: 13, color: kTextDark),
                  onChanged: (_) => setState(() {}), decoration: _dec(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6))))]),
            const SizedBox(height: 10),
            Row(children: [const Text('Round Off', style: TextStyle(fontSize: 12.5, color: kTextSub)), const Spacer(),
              Switch(value: roundOffEnabled, activeThumbColor: kBlue, onChanged: (v) => setState(() => roundOffEnabled = v))]),
            const Divider(height: 20, color: kBorder),
            _sumLine('Subtotal', _subtotal),
            if (gstEnabled && !isInterState) ...[_sumLine('CGST (9%)', _cgst), _sumLine('SGST (9%)', _sgst)],
            if (gstEnabled && isInterState) _sumLine('IGST (18%)', _igst),
            if (!gstEnabled && _lineTax > 0) _sumLine('Tax', _lineTax),
            if (_shipping > 0) _sumLine('Shipping', _shipping),
            if (roundOffEnabled && _roundOff != 0) _sumLine('Round Off', _roundOff),
            const Divider(height: 20, color: kBorder),
            Row(children: [
              const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kTextDark)),
              const Spacer(),
              Text('₹${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kGreen)),
            ]),
          ]));
      return narrow
          ? Column(children: [notesCard, const SizedBox(height: 18), totalsCard])
          : IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 5, child: notesCard), const SizedBox(width: 18), Expanded(flex: 4, child: totalsCard)]));
    });
  }

  Widget _sumLine(String label, double value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 12.5, color: kTextSub)),
      const Spacer(),
      Text('₹${value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextDark)),
    ]),
  );

  Widget _footer() => Row(children: [
    const Spacer(),
    OutlinedButton.icon(
      onPressed: _printPreview,
      style: OutlinedButton.styleFrom(
        foregroundColor: kTextDark,
        side: const BorderSide(color: kBorder),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(6)),
        ),
      ),
      icon: const Icon(Icons.print_outlined, size: 16),
      label: const Text('Print', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ),
    Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(color: kBorder),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
      ),
      child: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: kTextSub),
    ),
    const SizedBox(width: 10),
    ElevatedButton(
      onPressed: _isLoading ? null : _save,
      style: ElevatedButton.styleFrom(backgroundColor: kBlue, foregroundColor: Colors.white, elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
      child: _isLoading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
          : Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.save_rounded, size: 16, color: Colors.white), const SizedBox(width: 8),
        Text(_isEdit ? 'Update Delivery Challan' : 'Save Delivery Challan', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
      ]),
    ),
  ]);
}

class _LineRow {
  final String id = DateTime.now().microsecondsSinceEpoch.toString() + (100 + (DateTime.now().millisecond)).toString();
  final descController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final priceController = TextEditingController();
  final discountController = TextEditingController(text: '0');
  final taxController = TextEditingController(text: '0');
  String unit = 'NONE';

  void dispose() {
    descController.dispose();
    qtyController.dispose();
    priceController.dispose();
    discountController.dispose();
    taxController.dispose();
  }
}