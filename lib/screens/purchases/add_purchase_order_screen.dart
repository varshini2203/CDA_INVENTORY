// lib/screens/purchases/add_purchase_order_screen.dart
//
// "Add Purchase Order" — same Vyapar-style theme as Add Purchase:
// workspace tab strip, Vendor search + Phone, PO Number / Order Date /
// Expected Delivery Date / Order Status / Firm-Branch, an itemized table
// (Item / Serial No. / Description / Qty / Unit / Price-per-unit /
// Discount % + Amount / Tax % + Amount / Amount), Notes, Shipping,
// Round Off, Total, and a footer with Print + Save Order.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:cda_inventory/models/purchase_order.dart';
import 'package:cda_inventory/models/invoice_line_item.dart';
import 'package:cda_inventory/services/purchase_order_service.dart';

// ── One editable row in the item table ────────────────────────────────────
class _ItemRow {
  final String id;
  final TextEditingController itemController = TextEditingController();
  final TextEditingController serialController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController discPercentController = TextEditingController();
  String unit;
  double? taxPercent; // null == 'Select'

  _ItemRow({required this.id, this.unit = 'NONE', this.taxPercent});

  double get qty => double.tryParse(qtyController.text.trim()) ?? 0;
  double get price => double.tryParse(priceController.text.trim()) ?? 0;
  double get gross => qty * price;

  double get discPercent => double.tryParse(discPercentController.text.trim()) ?? 0;
  double get discAmount => gross * (discPercent / 100);
  double get taxable => gross - discAmount;
  double get taxAmount => taxable * ((taxPercent ?? 0) / 100);
  double get amount => taxable + taxAmount;

  bool get isEmpty => itemController.text.trim().isEmpty && qty == 0 && price == 0;

  InvoiceLineItem toLineItem() => InvoiceLineItem(
    id: id,
    description: itemController.text.trim(),
    hsnCode: serialController.text.trim().isEmpty ? null : serialController.text.trim(),
    quantity: qty.round(),
    unit: unit,
    unitPrice: price,
    discountPercent: discPercent,
    taxPercent: taxPercent ?? 0,
  );

  void dispose() {
    itemController.dispose();
    serialController.dispose();
    descController.dispose();
    qtyController.dispose();
    priceController.dispose();
    discPercentController.dispose();
  }
}

class AddPurchaseOrderScreen extends StatefulWidget {
  final PurchaseOrder? orderToEdit;
  const AddPurchaseOrderScreen({super.key, this.orderToEdit});

  @override
  State<AddPurchaseOrderScreen> createState() => _AddPurchaseOrderScreenState();
}

class _AddPurchaseOrderScreenState extends State<AddPurchaseOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  final _vendorNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _poNumberController = TextEditingController();
  final _shippingController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  DateTime _orderDate = DateTime.now();
  DateTime? _deliveryDate;
  String _stateOfSupply = 'Tamil Nadu';
  String _status = 'Pending';
  bool _roundOffEnabled = true;

  static const List<String> _branchOptions = ['Branch 1', 'Branch 2'];
  static const Map<String, String> _branchLabels = {
    'Branch 1': 'CDA Admin',
    'Branch 2': 'CDA Ops',
  };
  String _selectedBranch = _branchOptions.first;

  static const List<String> _statusOptions = ['Pending', 'Received', 'Cancelled'];

  final List<_ItemRow> _rows = [];
  int _rowSeq = 0;

  bool _isSaving = false;
  bool get _isEditMode => widget.orderToEdit != null;

  static const List<String> _units = [
    'NONE', 'PCS', 'BOX', 'KG', 'GM', 'LITRE', 'ML', 'DOZEN', 'PACK', 'METER', 'SET',
  ];

  static const List<double> _taxRates = [0, 5, 12, 18, 28];

  static const List<String> _indianStates = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
    'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim',
    'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand',
    'West Bengal', 'Delhi',
  ];

  // ── Vyapar-style light theme tokens (same as Add Purchase) ────────────
  static const Color kBg        = Color(0xFFF4F6F9);
  static const Color kTabBar    = Color(0xFFECEEF1);
  static const Color kNavy      = Color(0xFF0A1628);
  static const Color kRed       = Color(0xFFE94D5F);
  static const Color kBlue      = Color(0xFF2F6FE4);
  static const Color kGreen     = Color(0xFF00B894);
  static const Color kAmber     = Color(0xFFE8A33D);
  static const Color kBorder    = Color(0xFFE3E7EE);
  static const Color kHeaderBg  = Color(0xFFF7F9FC);
  static const Color kTextDark  = Color(0xFF1F2937);
  static const Color kTextSub   = Color(0xFF6B7280);
  static const Color kTextMute  = Color(0xFF9CA3AF);

  Color get _statusColor => switch (_status) {
    'Received' => kGreen,
    'Cancelled' => kRed,
    _ => kAmber,
  };

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final o = widget.orderToEdit!;
      _vendorNameController.text = o.vendorName;
      _phoneController.text = o.vendorPhone ?? '';
      _poNumberController.text = o.poNumber ?? '';
      _notesController.text = o.notes;
      _status = o.status;
      _stateOfSupply = o.stateOfSupply;
      _selectedBranch = o.branch.isNotEmpty ? o.branch : _branchOptions.first;
      _orderDate = _tryParseStore(o.orderDate) ?? DateTime.now();
      _deliveryDate = _tryParseStore(o.expectedDeliveryDate);
      for (final li in o.lineItems) {
        final row = _ItemRow(id: li.id, unit: li.unit, taxPercent: li.taxPercent);
        row.itemController.text = li.description;
        row.serialController.text = li.hsnCode ?? '';
        row.qtyController.text = li.quantity.toString();
        row.priceController.text = li.unitPrice.toString();
        row.discPercentController.text = li.discountPercent.toString();
        _rows.add(row);
      }
      if (_rows.isEmpty && o.productName.isNotEmpty) {
        final row = _ItemRow(id: 'row_${_rowSeq++}');
        row.itemController.text = o.productName;
        row.qtyController.text = o.quantity.toString();
        row.priceController.text = o.expectedCost.toString();
        _rows.add(row);
      }
    }
    while (_rows.length < 2) {
      _addRow();
    }
    for (final r in _rows) {
      r.qtyController.addListener(_recalc);
      r.priceController.addListener(_recalc);
      r.discPercentController.addListener(_recalc);
    }
  }

  DateTime? _tryParseStore(String s) {
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  @override
  void dispose() {
    _vendorNameController.dispose();
    _phoneController.dispose();
    _poNumberController.dispose();
    _shippingController.dispose();
    _notesController.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _recalc() => setState(() {});

  void _addRow() {
    final row = _ItemRow(id: 'row_${_rowSeq++}');
    row.qtyController.addListener(_recalc);
    row.priceController.addListener(_recalc);
    row.discPercentController.addListener(_recalc);
    setState(() => _rows.add(row));
  }

  void _removeRow(int index) {
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  // ── Totals ───────────────────────────────────────────────────────────
  double get _totalQty => _rows.fold(0.0, (s, r) => s + r.qty);
  double get _totalDiscountAmount => _rows.fold(0.0, (s, r) => s + r.discAmount);
  double get _totalTaxAmount => _rows.fold(0.0, (s, r) => s + r.taxAmount);
  double get _totalAmount => _rows.fold(0.0, (s, r) => s + r.amount);

  double get _shipping => double.tryParse(_shippingController.text.trim()) ?? 0;
  double get _preRoundTotal => _totalAmount + _shipping;
  double get _roundOff =>
      _roundOffEnabled ? (_preRoundTotal.roundToDouble() - _preRoundTotal) : 0.0;
  double get _grandTotal => _preRoundTotal + _roundOff;

  String _fmtDate(DateTime? d) => d == null
      ? ''
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _fmtDateStore(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  Future<void> _pickOrderDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _orderDate = picked);
  }

  Future<void> _pickDeliveryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate ?? _orderDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _deliveryDate = picked);
  }

  Future<void> _save() async {
    final validRows = _rows.where((r) => !r.isEmpty).toList();
    if (validRows.isEmpty) {
      _showSnack('Add at least one item', isError: true);
      return;
    }
    if (_vendorNameController.text.trim().isEmpty) {
      _showSnack('Vendor name is required', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final totalQty = validRows.fold(0, (s, r) => s + r.qty.round());
      final avgCost = totalQty > 0 ? _grandTotal / totalQty : _grandTotal;

      final order = PurchaseOrder(
        id: widget.orderToEdit?.id,
        productName: validRows.length == 1 ? validRows.first.itemController.text.trim() : '${validRows.length} items',
        vendorName: _vendorNameController.text.trim(),
        vendorPhone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        quantity: totalQty,
        expectedCost: avgCost,
        branch: _selectedBranch,
        orderDate: _fmtDateStore(_orderDate),
        expectedDeliveryDate: _deliveryDate == null ? '' : _fmtDateStore(_deliveryDate!),
        status: _status,
        notes: _notesController.text.trim(),
        poNumber: _poNumberController.text.trim().isEmpty ? null : _poNumberController.text.trim(),
        stateOfSupply: _stateOfSupply,
        lineItems: validRows.map((r) => r.toLineItem()).toList(),
        createdAt: widget.orderToEdit?.createdAt ?? DateTime.now(),
      );

      final result = _isEditMode
          ? await PurchaseOrderService.updatePurchaseOrder(widget.orderToEdit!.id!, order)
          : await PurchaseOrderService.addPurchaseOrder(order);
      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.pop(context, true);
      } else {
        _showSnack(result['message'] ?? 'Something went wrong', isError: true);
      }
    } catch (e) {
      _showSnack('Failed to save: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _printPreview() async {
    await Printing.layoutPdf(onLayout: (format) async => Uint8List(0));
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? kRed : kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditMode ? 'Edit Purchase Order' : 'Add Purchase Order',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SafeArea(
        // Force a light text/icon theme locally so this Vyapar-style light
        // card UI stays legible even when the app's ambient Theme is dark
        // (which was making unstyled Text/TextFormField/Dropdown labels
        // render white-on-white). Dropdown *menu popups* additionally need
        // an explicit `dropdownColor` per-widget — see each Dropdown below.
        child: Theme(
          data: Theme.of(context).copyWith(
            brightness: Brightness.light,
            colorScheme: Theme.of(context).colorScheme.copyWith(
              brightness: Brightness.light,
              onSurface: kTextDark,
              surface: Colors.white,
            ),
            textTheme: Theme.of(context).textTheme.apply(
              bodyColor: kTextDark,
              displayColor: kTextDark,
            ),
            iconTheme: const IconThemeData(color: kTextSub),
            canvasColor: Colors.white,
            inputDecorationTheme: const InputDecorationTheme(
              hintStyle: TextStyle(color: kTextMute),
            ),
          ),
          child: Column(
            children: [
              _buildTabStrip(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Purchase Order',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextDark)),
                        const SizedBox(height: 18),
                        _buildVendorAndOrderRow(),
                        const SizedBox(height: 22),
                        _buildItemTable(),
                        const SizedBox(height: 8),
                        _buildAddRowAndTotal(),
                        const SizedBox(height: 22),
                        _buildBottomSection(),
                        const SizedBox(height: 22),
                        _buildFooterBar(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Workspace tab strip: "Purchase Order #1  ×  ⊕ … ⚙ ⓧ" ──────────────
  Widget _buildTabStrip() {
    return Container(
      height: 44,
      color: kTabBar,
      child: Row(children: [
        Container(
          margin: const EdgeInsets.only(left: 8, top: 6, bottom: 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_isEditMode ? 'Edit PO' : 'Purchase Order #1',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextDark)),
            const SizedBox(width: 10),
            InkWell(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close_rounded, size: 15, color: kTextMute),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 6, top: 6),
          child: InkWell(
            onTap: () {},
            child: const Icon(Icons.add_circle, size: 20, color: kBlue),
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Save layout',
          icon: const Icon(Icons.dashboard_customize_outlined, size: 18, color: kTextSub),
          onPressed: () {},
        ),
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined, size: 18, color: kTextSub),
          onPressed: () {},
        ),
        IconButton(
          tooltip: 'Close',
          icon: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: kTextMute, shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 6),
      ]),
    );
  }

  InputDecoration _fieldDecoration({String? hint, EdgeInsets? padding}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: kTextMute, fontSize: 13),
    isDense: true,
    contentPadding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kBlue)),
    filled: true,
    fillColor: Colors.white,
  );

  // ── Vendor search / phone  +  PO No. / Order Date / Delivery Date / Status / Branch ──
  Widget _buildVendorAndOrderRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Row(children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _vendorNameController,
                style: const TextStyle(color: kTextDark, fontSize: 13),
                decoration: _fieldDecoration(hint: 'Search Vendor by Name/Phone *').copyWith(
                  suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, color: kTextMute, size: 20),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: kTextDark, fontSize: 13),
                decoration: _fieldDecoration(hint: 'Phone No.'),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _metaRow('PO Number', SizedBox(
              width: 200,
              child: TextFormField(
                controller: _poNumberController,
                textAlign: TextAlign.right,
                style: const TextStyle(color: kTextDark, fontSize: 13),
                decoration: _fieldDecoration(hint: 'PO number', padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              ),
            )),
            const SizedBox(height: 8),
            _metaRow('Order Date', SizedBox(
              width: 200,
              child: InkWell(
                onTap: _pickOrderDate,
                child: InputDecorator(
                  decoration: _fieldDecoration(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(_fmtDate(_orderDate), style: const TextStyle(fontSize: 13, color: kTextDark)),
                    const SizedBox(width: 6),
                    const Icon(Icons.calendar_today_rounded, size: 15, color: kTextMute),
                  ]),
                ),
              ),
            )),
            const SizedBox(height: 8),
            _metaRow('Expected Delivery', SizedBox(
              width: 200,
              child: InkWell(
                onTap: _pickDeliveryDate,
                child: InputDecorator(
                  decoration: _fieldDecoration(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(_deliveryDate == null ? 'Select date' : _fmtDate(_deliveryDate),
                        style: TextStyle(fontSize: 13, color: _deliveryDate == null ? kTextMute : kTextDark)),
                    const SizedBox(width: 6),
                    const Icon(Icons.calendar_today_rounded, size: 15, color: kTextMute),
                  ]),
                ),
              ),
            )),
            const SizedBox(height: 8),
            _metaRow('State of supply', SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                initialValue: _stateOfSupply,
                isExpanded: true,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 12.5, color: kTextDark),
                decoration: _fieldDecoration(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                items: _indianStates
                    .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12.5, color: kTextDark), overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _stateOfSupply = v ?? _stateOfSupply),
              ),
            )),
            const SizedBox(height: 8),
            _metaRow('Order Status', SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                initialValue: _status,
                isExpanded: true,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 12.5, color: kTextDark),
                decoration: _fieldDecoration(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                items: _statusOptions
                    .map((s) => DropdownMenuItem(
                  value: s,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: _dotColor(s), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(s, style: const TextStyle(fontSize: 12.5, color: kTextDark)),
                  ]),
                ))
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
            )),
            const SizedBox(height: 8),
            _metaRow('Firm / Branch', SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedBranch,
                isExpanded: true,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 12.5, color: kTextDark),
                decoration: _fieldDecoration(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                items: _branchOptions
                    .map((b) => DropdownMenuItem(value: b, child: Text(_branchLabels[b] ?? b, style: const TextStyle(fontSize: 12.5, color: kTextDark))))
                    .toList(),
                onChanged: (v) => setState(() => _selectedBranch = v ?? _selectedBranch),
              ),
            )),
          ]),
        ),
      ],
    );
  }

  Color _dotColor(String s) => switch (s) {
    'Received' => kGreen,
    'Cancelled' => kRed,
    _ => kAmber,
  };

  Widget _metaRow(String label, Widget field) {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Text(label, style: const TextStyle(fontSize: 12.5, color: kTextSub, fontWeight: FontWeight.w500)),
      const SizedBox(width: 14),
      field,
    ]);
  }

  // ── Item table ───────────────────────────────────────────────────────
  static const double cIcon    = 34;
  static const double cItem    = 220;
  static const double cSerial  = 110;
  static const double cDesc    = 130;
  static const double cQty     = 70;
  static const double cUnit    = 90;
  static const double cPrice   = 120;
  static const double cDiscPct = 64;
  static const double cDiscAmt = 90;
  static const double cTaxPct  = 92;
  static const double cTaxAmt  = 90;
  static const double cAmount  = 110;
  static const double cDelete  = 34;
  static const double kRowHPad = 10; // horizontal padding used inside header/row/footer containers

  double get _tableWidth =>
      cIcon + cItem + cSerial + cDesc + cQty + cUnit + cPrice + cDiscPct + cDiscAmt + cTaxPct + cTaxAmt + cAmount + cDelete + (kRowHPad * 2);

  Widget _buildItemTable() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(4)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _tableWidth,
          child: Column(children: [
            _tableHeader(),
            ...List.generate(_rows.length, (i) => _tableRow(i)),
          ]),
        ),
      ),
    );
  }

  Widget _th(double w, String text, {TextAlign align = TextAlign.left}) => SizedBox(
    width: w,
    child: Text(text,
        textAlign: align,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub, letterSpacing: 0.2)),
  );

  Widget _tableHeader() {
    return Container(
      color: kHeaderBg,
      padding: const EdgeInsets.symmetric(horizontal: kRowHPad, vertical: 10),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const SizedBox(width: cIcon, child: Icon(Icons.view_list_rounded, size: 16, color: kTextMute)),
          _th(cItem, 'ITEM'),
          _th(cSerial, 'SERIAL NO.'),
          _th(cDesc, 'DESCRIPTION'),
          _th(cQty, 'QTY'),
          _th(cUnit, 'UNIT'),
          SizedBox(
            width: cPrice,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text('PRICE/UNIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub)),
              Text('Without Tax', style: TextStyle(fontSize: 10, color: kTextMute)),
            ]),
          ),
          SizedBox(
            width: cDiscPct + cDiscAmt,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('DISCOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub)),
              Row(children: [
                SizedBox(width: cDiscPct, child: const Text('%', style: TextStyle(fontSize: 10, color: kTextMute))),
                SizedBox(width: cDiscAmt, child: const Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: kTextMute))),
              ]),
            ]),
          ),
          SizedBox(
            width: cTaxPct + cTaxAmt,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TAX', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub)),
              Row(children: [
                SizedBox(width: cTaxPct, child: const Text('%', style: TextStyle(fontSize: 10, color: kTextMute))),
                SizedBox(width: cTaxAmt, child: const Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: kTextMute))),
              ]),
            ]),
          ),
          _th(cAmount, 'AMOUNT', align: TextAlign.right),
          SizedBox(width: cDelete, child: const Icon(Icons.add_circle_outline_rounded, size: 16, color: kTextMute)),
        ]),
      ]),
    );
  }

  Widget _tableRow(int index) {
    final row = _rows[index];
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBorder))),
      padding: const EdgeInsets.symmetric(horizontal: kRowHPad, vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(
          width: cIcon,
          child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: kTextMute)),
        ),
        SizedBox(
          width: cItem,
          child: _cellField(row.itemController, hint: 'Search item'),
        ),
        SizedBox(
          width: cSerial,
          child: Row(children: [
            const Icon(Icons.reorder_rounded, size: 14, color: kTextMute),
            const SizedBox(width: 4),
            Expanded(child: _cellField(row.serialController, hint: '')),
          ]),
        ),
        SizedBox(width: cDesc, child: _cellField(row.descController, hint: '')),
        SizedBox(width: cQty, child: _cellField(row.qtyController, hint: '', numeric: true)),
        SizedBox(
          width: cUnit,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: row.unit,
              isDense: true,
              isExpanded: true,
              dropdownColor: Colors.white,
              style: const TextStyle(fontSize: 12.5, color: kTextDark),
              items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(color: kTextDark)))).toList(),
              onChanged: (v) => setState(() => row.unit = v ?? 'NONE'),
            ),
          ),
        ),
        SizedBox(width: cPrice, child: _cellField(row.priceController, hint: '0', numeric: true)),
        SizedBox(width: cDiscPct, child: _cellField(row.discPercentController, hint: '0', numeric: true)),
        SizedBox(
          width: cDiscAmt,
          child: Text('₹${row.discAmount.toStringAsFixed(2)}',
              textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, color: kTextSub)),
        ),
        SizedBox(
          width: cTaxPct,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<double?>(
              value: row.taxPercent,
              isDense: true,
              isExpanded: true,
              dropdownColor: Colors.white,
              hint: const Text('Select', style: TextStyle(fontSize: 12, color: kTextMute)),
              style: const TextStyle(fontSize: 12.5, color: kTextDark),
              items: _taxRates.map((t) => DropdownMenuItem(value: t, child: Text('GST $t%', style: const TextStyle(color: kTextDark)))).toList(),
              onChanged: (v) => setState(() => row.taxPercent = v),
            ),
          ),
        ),
        SizedBox(
          width: cTaxAmt,
          child: Text('₹${row.taxAmount.toStringAsFixed(2)}',
              textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, color: kTextSub)),
        ),
        SizedBox(
          width: cAmount,
          child: Text('₹${row.amount.toStringAsFixed(2)}',
              textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextDark)),
        ),
        SizedBox(
          width: cDelete,
          child: IconButton(
            icon: const Icon(Icons.close_rounded, size: 16, color: kTextMute),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => _removeRow(index),
          ),
        ),
      ]),
    );
  }

  Widget _cellField(TextEditingController controller, {required String hint, bool numeric = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontSize: 12.5, color: kTextDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kTextMute, fontSize: 12.5),
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
      ),
    );
  }

  // ── "ADD ROW" + TOTAL summary line ──────────────────────────────────
  Widget _buildAddRowAndTotal() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(4)),
      padding: const EdgeInsets.symmetric(horizontal: kRowHPad, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _tableWidth,
          child: Row(children: [
            SizedBox(
              width: cIcon + cItem,
              child: TextButton.icon(
                onPressed: _addRow,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                icon: const Icon(Icons.add_rounded, size: 16, color: kBlue),
                label: const Text('ADD ROW', style: TextStyle(color: kBlue, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
            SizedBox(
              width: cSerial + cDesc,
              child: const Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextDark)),
            ),
            SizedBox(width: cQty, child: Text(_totalQty.toStringAsFixed(0), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextDark))),
            SizedBox(width: cUnit, child: const SizedBox()),
            SizedBox(width: cPrice, child: const SizedBox()),
            SizedBox(width: cDiscPct, child: const SizedBox()),
            SizedBox(width: cDiscAmt, child: Text('₹${_totalDiscountAmount.toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextDark))),
            SizedBox(width: cTaxPct, child: const SizedBox()),
            SizedBox(width: cTaxAmt, child: Text('₹${_totalTaxAmount.toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextDark))),
            SizedBox(width: cAmount, child: Text('₹${_totalAmount.toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kTextDark))),
            SizedBox(width: cDelete, child: const SizedBox()),
          ]),
        ),
      ),
    );
  }

  // ── Notes / Status badge / Shipping / Round Off / Total ─────────────
  Widget _buildBottomSection() {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 760;
      final children = [
        Expanded(flex: 4, child: _notesCard()),
        const SizedBox(width: 18, height: 18),
        Expanded(flex: 3, child: _statusCard()),
        const SizedBox(width: 18, height: 18),
        Expanded(flex: 3, child: _shippingAndTotalCard()),
      ];
      return isNarrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
          : IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: children));
    });
  }

  Widget _cardWrap({required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: kBorder),
    ),
    child: child,
  );

  Widget _notesCard() {
    return _cardWrap(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Notes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesController,
          maxLines: 4,
          style: const TextStyle(fontSize: 13, color: kTextDark),
          decoration: _fieldDecoration(hint: 'Any additional details about this order'),
        ),
      ]),
    );
  }

  Widget _statusCard() {
    return _cardWrap(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Order Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _statusColor.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(_status, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _statusColor)),
          ]),
        ),
        const SizedBox(height: 12),
        const Text('Change the status from the "Order Status" dropdown above.',
            style: TextStyle(fontSize: 11.5, color: kTextMute)),
      ]),
    );
  }

  Widget _shippingAndTotalCard() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Text('Shipping', style: TextStyle(fontSize: 12.5, color: kTextSub, fontWeight: FontWeight.w600)),
        const Spacer(),
        SizedBox(
          width: 130,
          child: TextFormField(
            controller: _shippingController,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: kTextDark, fontSize: 13),
            onChanged: (_) => setState(() {}),
            decoration: _fieldDecoration(hint: '0', padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          ),
        ),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Checkbox(value: _roundOffEnabled, activeColor: kBlue, onChanged: (v) => setState(() => _roundOffEnabled = v ?? false)),
        const Text('Round Off', style: TextStyle(fontSize: 12.5, color: kTextDark, fontWeight: FontWeight.w600)),
        const Spacer(),
        SizedBox(
          width: 90,
          child: Text(_roundOff.toStringAsFixed(2),
              textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: kTextSub)),
        ),
      ]),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const Text('Expected Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTextDark)),
        const Spacer(),
        Container(
          width: 130,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: kHeaderBg,
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('₹${_grandTotal.toStringAsFixed(2)}',
              textAlign: TextAlign.right, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kTextDark)),
        ),
      ]),
    ]);
  }

  // ── Footer bar: Print ▾  Save Order ───────────────────────────────────
  Widget _buildFooterBar() {
    return Row(children: [
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
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: kBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: _isSaving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
            : const Text('Save Order', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}