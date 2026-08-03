// lib/screens/sales/add_sale_order_screen.dart
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:cda_inventory/models/sale_order.dart';
import 'package:cda_inventory/models/invoice_line_item.dart';
import 'package:cda_inventory/models/customer_details.dart';
import 'package:cda_inventory/services/sale_order_service.dart';
import 'package:cda_inventory/services/sale_order_pdf_service.dart';
import 'package:cda_inventory/shared/inventory_ui.dart';

class AddSaleOrderScreen extends StatefulWidget {
  final SaleOrder? orderToEdit;
  const AddSaleOrderScreen({super.key, this.orderToEdit});
  @override
  State<AddSaleOrderScreen> createState() => _AddSaleOrderScreenState();
}

class _AddSaleOrderScreenState extends State<AddSaleOrderScreen> {
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

  final customerController = TextEditingController();
  final phoneController = TextEditingController();
  final orderDateController = TextEditingController();
  final deliveryDateController = TextEditingController();
  final notesController = TextEditingController();
  final shippingController = TextEditingController(text: '0');

  String selectedBranch = kBranches.first;
  bool gstEnabled = false;
  bool isInterState = false;
  bool roundOffEnabled = true;
  bool _isLoading = false;

  final List<_LineRow> _rows = [];

  bool get _isEditMode => widget.orderToEdit != null;

  @override
  void initState() {
    super.initState();
    final o = widget.orderToEdit;
    if (o != null) {
      customerController.text = o.customer?.name ?? '';
      phoneController.text = o.customer?.phone ?? '';
      orderDateController.text = o.orderDate;
      deliveryDateController.text = o.deliveryDate ?? '';
      notesController.text = o.notes;
      shippingController.text = o.shipping % 1 == 0 ? o.shipping.toStringAsFixed(0) : o.shipping.toString();
      selectedBranch = kBranches.contains(o.branch) ? o.branch : kBranches.first;
      gstEnabled = o.gstEnabled;
      isInterState = o.isInterState;
      roundOffEnabled = o.roundOffEnabled;
      if (o.lineItems.isEmpty) {
        _addRow();
      } else {
        for (final item in o.lineItems) {
          _rows.add(_LineRow.fromItem(item));
        }
      }
    } else {
      orderDateController.text = _fmt(DateTime.now());
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

  // ── Build a SaleOrder object from the current form state. Used by
  //    _printPreview() for a live preview of unsaved changes. ─────────────
  SaleOrder _buildDraftOrder() {
    return SaleOrder(
      id: widget.orderToEdit?.id,
      orderNo: widget.orderToEdit?.orderNo ?? 'DRAFT',
      customer: CustomerDetails(name: customerController.text.trim(), phone: phoneController.text.trim()),
      orderDate: orderDateController.text.trim(),
      deliveryDate: deliveryDateController.text.trim().isEmpty ? null : deliveryDateController.text.trim(),
      status: widget.orderToEdit?.status ?? 'Open',
      branch: selectedBranch,
      notes: notesController.text.trim(),
      lineItems: _lineItems,
      shipping: _shipping,
      roundOffEnabled: roundOffEnabled,
      gstEnabled: gstEnabled,
      isInterState: isInterState,
      createdAt: widget.orderToEdit?.createdAt,
    );
  }

  Future<void> _printPreview() async {
    if (_lineItems.isEmpty) {
      showAppSnack(context, 'Add at least one item before printing', isError: true);
      return;
    }
    final draft = _buildDraftOrder();
    await Printing.layoutPdf(onLayout: (format) => SaleOrderPdfService.generate(draft));
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
    final orderNo = _isEditMode ? widget.orderToEdit!.orderNo : await SaleOrderService.generateOrderNo();
    final order = SaleOrder(
      id: _isEditMode ? widget.orderToEdit!.id : null,
      orderNo: orderNo,
      customer: CustomerDetails(
        name: customerController.text.trim(),
        phone: phoneController.text.trim(),
      ),
      orderDate: orderDateController.text.trim(),
      deliveryDate: deliveryDateController.text.trim().isEmpty ? null : deliveryDateController.text.trim(),
      status: _isEditMode ? widget.orderToEdit!.status : 'Open',
      branch: selectedBranch,
      notes: notesController.text.trim(),
      lineItems: _lineItems,
      shipping: _shipping,
      roundOffEnabled: roundOffEnabled,
      gstEnabled: gstEnabled,
      isInterState: isInterState,
    );
    try {
      if (_isEditMode) {
        await SaleOrderService.updateOrder(order);
        if (!mounted) return;
        setState(() => _isLoading = false);
        showAppSnack(context, 'Sale order updated successfully');
        Navigator.pop(context, true);
      } else {
        await SaleOrderService.createOrder(order);
        if (!mounted) return;
        setState(() => _isLoading = false);
        showSuccessDialog(
          context,
          title: 'Sale Order Created!',
          message: 'Order $orderNo has been saved successfully.',
          onAddMore: () => setState(() {
            customerController.clear();
            phoneController.clear();
            notesController.clear();
            shippingController.text = '0';
            for (final r in _rows) r.dispose();
            _rows.clear();
            _addRow();
          }),
          onViewList: () => Navigator.pop(context, true),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showAppSnack(context, 'Failed to save order: $e', isError: true);
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
    orderDateController.dispose();
    deliveryDateController.dispose();
    notesController.dispose();
    shippingController.dispose();
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
        title: Text(_isEditMode ? 'Edit Sale Order' : 'Sale Order', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
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
                child: Text(_isEditMode ? 'Edit Sale Order' : 'New Sale Order', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextDark))),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _topRow(),
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
        _metaRow('Order Date', InkWell(onTap: () => _pickDate(orderDateController), child: SizedBox(width: 180,
            child: InputDecorator(decoration: _dec(), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(orderDateController.text, style: const TextStyle(fontSize: 13, color: kTextDark)),
              const SizedBox(width: 6), const Icon(Icons.calendar_today_rounded, size: 15, color: kTextMute),
            ]))))),
        const SizedBox(height: 8),
        _metaRow('Delivery Date', InkWell(onTap: () => _pickDate(deliveryDateController), child: SizedBox(width: 180,
            child: InputDecorator(decoration: _dec(), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(deliveryDateController.text.isEmpty ? 'Optional' : deliveryDateController.text,
                  style: TextStyle(fontSize: 13, color: deliveryDateController.text.isEmpty ? kTextMute : kTextDark)),
              const SizedBox(width: 6), const Icon(Icons.calendar_today_rounded, size: 15, color: kTextMute),
            ]))))),
        const SizedBox(height: 8),
        _metaRow('Branch', SizedBox(width: 180, child: DropdownButtonFormField<String>(
            initialValue: selectedBranch, isExpanded: true, dropdownColor: Colors.white,
            style: const TextStyle(fontSize: 12.5, color: kTextDark), decoration: _dec(),
            items: kBranches.map((b) => DropdownMenuItem(value: b, child: Text(kBranchLabels[b] ?? b, style: const TextStyle(fontSize: 12.5, color: kTextDark)))).toList(),
            onChanged: (v) => setState(() => selectedBranch = v ?? selectedBranch)))),
      ]);
      return narrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [customerBlock, const SizedBox(height: 18), metaBlock])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: customerBlock), const SizedBox(width: 24), Expanded(flex: 3, child: metaBlock)]);
    });
  }

  Widget _metaRow(String label, Widget field) => Row(mainAxisAlignment: MainAxisAlignment.end, children: [
    Text(label, style: const TextStyle(fontSize: 12.5, color: kTextSub, fontWeight: FontWeight.w500)),
    const SizedBox(width: 14), Flexible(child: field),
  ]);

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: const Icon(Icons.print_outlined, size: 16),
      label: const Text('Print', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
        Text(_isEditMode ? 'Update Sale Order' : 'Save Sale Order', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
      ]),
    ),
  ]);
}

class _LineRow {
  String id = DateTime.now().microsecondsSinceEpoch.toString() + (100 + (DateTime.now().millisecond)).toString();
  final descController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final priceController = TextEditingController();
  final discountController = TextEditingController(text: '0');
  final taxController = TextEditingController(text: '0');
  String unit = 'NONE';

  _LineRow();

  factory _LineRow.fromItem(InvoiceLineItem item) {
    final row = _LineRow();
    row.id = item.id.isNotEmpty ? item.id : row.id;
    row.descController.text = item.description;
    row.qtyController.text = item.quantity.toString();
    row.priceController.text = item.unitPrice % 1 == 0
        ? item.unitPrice.toStringAsFixed(0)
        : item.unitPrice.toString();
    row.discountController.text = item.discountPercent % 1 == 0
        ? item.discountPercent.toStringAsFixed(0)
        : item.discountPercent.toString();
    row.taxController.text = item.taxPercent % 1 == 0
        ? item.taxPercent.toStringAsFixed(0)
        : item.taxPercent.toString();
    row.unit = item.unit;
    return row;
  }

  void dispose() {
    descController.dispose();
    qtyController.dispose();
    priceController.dispose();
    discountController.dispose();
    taxController.dispose();
  }
}