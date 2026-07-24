// lib/screens/purchases/add_purchase_screen.dart
//
// "Add Purchase" — rebuilt to match the Vyapar desktop "Purchase" bill
// entry screen pixel-for-pixel: workspace tab strip, Party search +
// Phone, Bill Number / Bill Date / State of supply, an itemized table
// (Item / Serial No. / Description / Qty / Unit / Price-per-unit /
// Discount % + Amount / Tax % + Amount / Amount), Terms & Conditions,
// Payment Type, Shipping, Round Off, Total, Upload Bill, Print + Save.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:cda_inventory/models/purchase.dart';
import 'package:cda_inventory/models/invoice_line_item.dart';
import 'package:cda_inventory/models/customer_details.dart';
import 'package:cda_inventory/services/purchase_service.dart';
import 'package:cda_inventory/services/purchase_pdf_service.dart';

// ── One editable row in the item table ────────────────────────────────────
class _ItemRow {
  final String id;
  final TextEditingController itemController = TextEditingController();
  final TextEditingController serialController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController discPercentController = TextEditingController();
  final TextEditingController discAmountController = TextEditingController();
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
    discAmountController.dispose();
  }
}

class AddPurchaseScreen extends StatefulWidget {
  final Purchase? purchaseToEdit;
  const AddPurchaseScreen({super.key, this.purchaseToEdit});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();

  final _partyNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _billNumberController = TextEditingController();
  final _shippingController = TextEditingController(text: '0');
  final _termsNotesController = TextEditingController(text: 'Thanks for doing business with us!');
  final _descriptionController = TextEditingController();
  final _roundOffAmountController = TextEditingController(text: '0');
  final _totalOverrideController = TextEditingController();

  DateTime _billDate = DateTime.now();
  String _stateOfSupply = 'Tamil Nadu';
  String _paymentType = 'Cash';
  String _termsTitle = 'Purchase Bill';
  bool _roundOffEnabled = true;
  bool _showDescriptionField = false;

  // Raw value stored/filtered on ('Branch 1' / 'Branch 2')
  static const List<String> _branchOptions = ['Branch 1', 'Branch 2'];
  static const Map<String, String> _branchLabels = {
    'Branch 1': 'CDA Admin',
    'Branch 2': 'CDA Ops',
  };
  String _selectedBranch = _branchOptions.first;

  final List<_ItemRow> _rows = [];
  int _rowSeq = 0;

  bool _isSaving = false;
  bool get _isEditMode => widget.purchaseToEdit != null;

  // ── Uploaded/scanned bill image (stored as Base64 in Firestore, same
  //    pattern as BillsService — no Firebase Storage/Blaze plan needed) ──
  Uint8List? _newBillImageBytes;
  String? _existingBillImageBase64;
  bool get _hasBillImage => _newBillImageBytes != null || (_existingBillImageBase64 ?? '').isNotEmpty;

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

  // ── Vyapar-style light theme tokens ─────────────────────────────────
  static const Color kBg        = Color(0xFFF4F6F9);
  static const Color kTabBar    = Color(0xFFECEEF1);
  static const Color kNavy      = Color(0xFF0A1628);
  static const Color kRed       = Color(0xFFE94D5F);
  static const Color kBlue      = Color(0xFF2F6FE4);
  static const Color kGreen     = Color(0xFF00B894);
  static const Color kBorder    = Color(0xFFE3E7EE);
  static const Color kHeaderBg  = Color(0xFFF7F9FC);
  static const Color kTextDark  = Color(0xFF1F2937);
  static const Color kTextSub   = Color(0xFF6B7280);
  static const Color kTextMute  = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final p = widget.purchaseToEdit!;
      _partyNameController.text = p.displayVendorName;
      _phoneController.text = p.partyPhone ?? p.party?.phone ?? '';
      _billNumberController.text = p.invoiceNumber;
      _shippingController.text = p.shipping.toStringAsFixed(0);
      _termsNotesController.text = p.termsNotes ?? '';
      _termsTitle = p.termsTitle;
      _paymentType = p.paymentType;
      _stateOfSupply = p.stateOfSupply;
      _roundOffEnabled = p.roundOffEnabled;
      _selectedBranch = p.branch.isNotEmpty ? p.branch : _branchOptions.first;
      _descriptionController.text = p.description ?? '';
      _showDescriptionField = (p.description ?? '').isNotEmpty;
      _existingBillImageBase64 = p.imageUrl;
      for (final li in p.lineItems) {
        final row = _ItemRow(id: li.id, unit: li.unit, taxPercent: li.taxPercent);
        row.itemController.text = li.description;
        row.serialController.text = li.hsnCode ?? '';
        row.qtyController.text = li.quantity.toString();
        row.priceController.text = li.unitPrice.toString();
        row.discPercentController.text = li.discountPercent.toString();
        _rows.add(row);
      }
      if (_rows.isEmpty && p.productName.isNotEmpty) {
        final row = _ItemRow(id: 'row_${_rowSeq++}');
        row.itemController.text = p.productName;
        row.qtyController.text = p.quantity.toString();
        row.priceController.text = p.cost.toString();
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

  @override
  void dispose() {
    _partyNameController.dispose();
    _phoneController.dispose();
    _billNumberController.dispose();
    _shippingController.dispose();
    _termsNotesController.dispose();
    _descriptionController.dispose();
    _roundOffAmountController.dispose();
    _totalOverrideController.dispose();
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

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _fmtDateStore(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  Future<void> _pickBillDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _billDate = picked);
  }

  // ── Upload Bill / Add Image ─────────────────────────────────────────
  Future<void> _pickBillImage() async {
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
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: kBlue),
              title: const Text('Scan with Camera',
                  style: TextStyle(color: kTextDark, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: kBlue),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: kTextDark, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    // readAsBytes() works identically on Web, mobile, and desktop.
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _newBillImageBytes = bytes;
      _existingBillImageBase64 = null; // replaced by the new capture
    });
    _showSnack('Bill image attached');
  }

  void _removeBillImage() {
    setState(() {
      _newBillImageBytes = null;
      _existingBillImageBase64 = null;
    });
  }

  // ── Build a Purchase object from the current form state. Used by both
  //    _save() (persist) and _printPreview() (live preview of unsaved
  //    changes) so the two never drift out of sync. ──────────────────
  Purchase _buildDraftPurchase(List<_ItemRow> validRows) {
    final totalQty = validRows.fold(0, (s, r) => s + r.qty.round());
    final avgCost = totalQty > 0 ? _grandTotal / totalQty : _grandTotal;
    final billImageBase64 = _newBillImageBytes != null
        ? base64Encode(_newBillImageBytes!)
        : _existingBillImageBase64;

    return Purchase(
      id: widget.purchaseToEdit?.id,
      productName: validRows.length == 1 ? validRows.first.itemController.text.trim() : '${validRows.length} items',
      vendorName: _partyNameController.text.trim(),
      quantity: totalQty,
      cost: avgCost,
      invoiceNumber: _billNumberController.text.trim(),
      branch: _selectedBranch,
      purchaseDate: _fmtDateStore(_billDate),
      addedBy: widget.purchaseToEdit?.addedBy,
      createdAt: widget.purchaseToEdit?.createdAt ?? DateTime.now(),
      lineItems: validRows.map((r) => r.toLineItem()).toList(),
      party: CustomerDetails(
        name: _partyNameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        placeOfSupply: _stateOfSupply,
      ),
      partyPhone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      stateOfSupply: _stateOfSupply,
      paymentType: _paymentType,
      shipping: _shipping,
      roundOffEnabled: _roundOffEnabled,
      termsTitle: _termsTitle,
      termsNotes: _termsNotesController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      imageUrl: billImageBase64,
    );
  }

  Future<void> _save() async {
    final validRows = _rows.where((r) => !r.isEmpty).toList();
    if (validRows.isEmpty) {
      _showSnack('Add at least one item', isError: true);
      return;
    }
    if (_partyNameController.text.trim().isEmpty) {
      _showSnack('Party name is required', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final purchase = _buildDraftPurchase(validRows);

      final result = await PurchaseService.addPurchase(purchase);
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
    final validRows = _rows.where((r) => !r.isEmpty).toList();
    if (validRows.isEmpty) {
      _showSnack('Add at least one item to preview', isError: true);
      return;
    }
    final draft = _buildDraftPurchase(validRows);
    await Printing.layoutPdf(onLayout: (format) => PurchasePdfService.generate(draft));
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
        title: Text(_isEditMode ? 'Edit Purchase' : 'Add Purchase',
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
                        const Text('Purchase',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextDark)),
                        const SizedBox(height: 18),
                        _buildPartyAndBillRow(),
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

  // ── Workspace tab strip: "Purchase #1  ×  ⊕ … ⚙ ⓧ" ───────────────────
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
            Text(_isEditMode ? 'Edit Purchase' : 'Purchase #1',
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

  Widget _label(String text, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSub),
        children: required ? const [TextSpan(text: ' *', style: TextStyle(color: kRed))] : null,
      ),
    ),
  );

  // ── Party search / phone  +  Bill No. / Bill Date / State of supply ────
  Widget _buildPartyAndBillRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Row(children: [
            Expanded(
              flex: 2,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextFormField(
                  controller: _partyNameController,
                  style: const TextStyle(color: kTextDark, fontSize: 13),
                  decoration: _fieldDecoration(hint: 'Search by Name/Phone *').copyWith(
                    suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, color: kTextMute, size: 20),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ]),
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
            _metaRow('Bill Number', SizedBox(
              width: 200,
              child: TextFormField(
                controller: _billNumberController,
                textAlign: TextAlign.right,
                style: const TextStyle(color: kTextDark, fontSize: 13),
                decoration: _fieldDecoration(hint: 'Bill number', padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              ),
            )),
            const SizedBox(height: 8),
            _metaRow('Bill Date', SizedBox(
              width: 200,
              child: InkWell(
                onTap: _pickBillDate,
                child: InputDecorator(
                  decoration: _fieldDecoration(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(_fmtDate(_billDate), style: const TextStyle(fontSize: 13, color: kTextDark)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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

  // ── Terms & Conditions / Payment / Shipping / Round Off / Total ─────
  Widget _buildBottomSection() {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 760;
      final children = [
        Expanded(flex: 4, child: _termsCard()),
        const SizedBox(width: 18, height: 18),
        Expanded(flex: 3, child: _paymentAndAttachmentsCard()),
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

  Widget _termsCard() {
    return _cardWrap(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Terms & Conditions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
        const SizedBox(height: 12),
        _label('Title'),
        DropdownButtonFormField<String>(
          initialValue: _termsTitle,
          dropdownColor: Colors.white,
          style: const TextStyle(fontSize: 13, color: kTextDark),
          decoration: _fieldDecoration(),
          items: Purchase.termsTitles.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13, color: kTextDark)))).toList(),
          onChanged: (v) => setState(() => _termsTitle = v ?? _termsTitle),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _termsNotesController,
          maxLines: 3,
          style: const TextStyle(fontSize: 13, color: kTextDark),
          decoration: _fieldDecoration(),
        ),
      ]),
    );
  }

  Widget _paymentAndAttachmentsCard() {
    return _cardWrap(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('Payment Type'),
        DropdownButtonFormField<String>(
          initialValue: _paymentType,
          dropdownColor: Colors.white,
          style: const TextStyle(fontSize: 13, color: kTextDark),
          decoration: _fieldDecoration(),
          items: Purchase.paymentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13, color: kTextDark)))).toList(),
          onChanged: (v) => setState(() => _paymentType = v ?? _paymentType),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () {},
          child: const Row(children: [
            Icon(Icons.add_rounded, size: 15, color: kBlue),
            SizedBox(width: 4),
            Text('Add Payment type', style: TextStyle(color: kBlue, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => setState(() => _showDescriptionField = !_showDescriptionField),
          style: OutlinedButton.styleFrom(
            foregroundColor: kTextSub,
            side: const BorderSide(color: kBorder),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            minimumSize: const Size(double.infinity, 0),
          ),
          icon: const Icon(Icons.description_outlined, size: 16),
          label: const Text('ADD DESCRIPTION', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
        ),
        if (_showDescriptionField) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: _descriptionController,
            maxLines: 2,
            style: const TextStyle(fontSize: 13, color: kTextDark),
            decoration: _fieldDecoration(hint: 'Add a note about this purchase'),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _pickBillImage,
          style: OutlinedButton.styleFrom(
            foregroundColor: kTextSub,
            side: const BorderSide(color: kBorder),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            minimumSize: const Size(double.infinity, 0),
          ),
          icon: const Icon(Icons.image_outlined, size: 16),
          label: const Text('ADD IMAGE', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
        ),
        if (_hasBillImage) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: kHeaderBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kBorder),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, size: 15, color: kGreen),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Bill image attached', style: TextStyle(fontSize: 12, color: kTextDark)),
              ),
              InkWell(
                onTap: _removeBillImage,
                child: const Icon(Icons.close_rounded, size: 15, color: kTextMute),
              ),
            ]),
          ),
        ],
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
        const Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTextDark)),
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

  // ── Footer bar: Upload Bill ⟷ Print ▾  Save ───────────────────────────
  Widget _buildFooterBar() {
    return Row(children: [
      OutlinedButton.icon(
        onPressed: _pickBillImage,
        style: OutlinedButton.styleFrom(
          foregroundColor: _hasBillImage ? kGreen : kTextDark,
          side: BorderSide(color: _hasBillImage ? kGreen.withValues(alpha: 0.4) : kBorder),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: Icon(_hasBillImage ? Icons.check_circle_rounded : Icons.sync_alt_rounded, size: 16),
        label: Text(_hasBillImage ? 'Bill Attached' : 'Upload Bill', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
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
            : const Text('Save', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}