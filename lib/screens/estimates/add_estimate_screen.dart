// lib/screens/estimates/add_estimate_screen.dart
//
// "Add Estimate" form — Vyapar-style itemized estimate/quotation builder.

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:cda_inventory/models/estimate.dart';
import 'package:cda_inventory/models/invoice_line_item.dart';
import 'package:cda_inventory/models/customer_details.dart';
import 'package:cda_inventory/services/estimate_service.dart';
import 'package:cda_inventory/services/estimate_pdf_service.dart';

class _ItemRow {
  final String id;
  final TextEditingController itemController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController discController = TextEditingController(text: '0');
  double taxPercent;
  String unit;

  _ItemRow({required this.id, this.unit = 'NONE', this.taxPercent = 0});

  double get qty => double.tryParse(qtyController.text.trim()) ?? 0;
  double get price => double.tryParse(priceController.text.trim()) ?? 0;
  double get discPercent => double.tryParse(discController.text.trim()) ?? 0;
  double get gross => qty * price;
  double get discAmount => gross * (discPercent / 100);
  double get taxable => gross - discAmount;
  double get taxAmount => taxable * (taxPercent / 100);
  double get amount => taxable + taxAmount;

  bool get isEmpty => itemController.text.trim().isEmpty && qty == 0 && price == 0;

  InvoiceLineItem toLineItem() => InvoiceLineItem(
    id: id,
    description: itemController.text.trim(),
    quantity: qty.round(),
    unit: unit,
    unitPrice: price,
    discountPercent: discPercent,
    taxPercent: taxPercent,
  );

  void dispose() {
    itemController.dispose();
    qtyController.dispose();
    priceController.dispose();
    discController.dispose();
  }
}

class AddEstimateScreen extends StatefulWidget {
  final Estimate? estimateToEdit;
  const AddEstimateScreen({super.key, this.estimateToEdit});

  @override
  State<AddEstimateScreen> createState() => _AddEstimateScreenState();
}

class _AddEstimateScreenState extends State<AddEstimateScreen> {
  static const Color kBg = Color(0xFFF4F6F9);
  static const Color kRed = Color(0xFFE94D5F);
  static const Color kBlue = Color(0xFF2F6FE4);
  static const Color kBorder = Color(0xFFE7EAF0);
  static const Color kTextDark = Color(0xFF1F2937);
  static const Color kTextSub = Color(0xFF6B7280);
  static const Color kTextMute = Color(0xFF9CA3AF);

  static const List<String> _units = [
    'NONE', 'PCS', 'BOX', 'KG', 'GM', 'LITRE', 'ML', 'DOZEN', 'PACK', 'METER', 'SET',
  ];

  final _formKey = GlobalKey<FormState>();
  final EstimateService _service = EstimateService();

  final _refNoController = TextEditingController();
  final _partyNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _shippingController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  final _termsNotesController =
  TextEditingController(text: 'Thanks for doing business with us!');

  DateTime _estimateDate = DateTime.now();
  DateTime? _validTill;

  bool _gstEnabled = false;
  bool _isInterState = false;
  bool _roundOffEnabled = true;
  bool _isSaving = false;

  final List<_ItemRow> _rows = [];
  int _rowSeq = 0;

  bool get _isEditMode => widget.estimateToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final e = widget.estimateToEdit!;
      _refNoController.text = e.referenceNo;
      _partyNameController.text = e.partyName;
      _phoneController.text = e.customer?.phone ?? '';
      _shippingController.text = e.shipping.toStringAsFixed(0);
      _notesController.text = e.notes ?? '';
      _termsNotesController.text = e.termsNotes ?? '';
      _estimateDate = e.estimateDateTime ?? DateTime.now();
      _validTill = e.validTillDate;
      _gstEnabled = e.gstEnabled;
      _isInterState = e.isInterState;
      _roundOffEnabled = e.roundOffEnabled;
      for (final li in e.lineItems) {
        final row = _ItemRow(id: li.id, unit: li.unit, taxPercent: li.taxPercent);
        row.itemController.text = li.description;
        row.qtyController.text = li.quantity.toString();
        row.priceController.text = li.unitPrice.toString();
        row.discController.text = li.discountPercent.toString();
        _rows.add(row);
      }
    } else {
      _service.suggestNextReferenceNumber().then((n) {
        if (mounted) setState(() => _refNoController.text = n);
      });
    }
    if (_rows.isEmpty) _addRow();
  }

  @override
  void dispose() {
    _refNoController.dispose();
    _partyNameController.dispose();
    _phoneController.dispose();
    _shippingController.dispose();
    _notesController.dispose();
    _termsNotesController.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() => _rows.add(_ItemRow(id: 'row_${_rowSeq++}')));
  }

  void _removeRow(int index) {
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
      if (_rows.isEmpty) _addRow();
    });
  }

  double get _shipping => double.tryParse(_shippingController.text.trim()) ?? 0;
  double get _subtotal => _rows.fold(0.0, (s, r) => s + r.taxable);
  double get _totalTax => _rows.fold(0.0, (s, r) => s + r.taxAmount);
  double get _preRoundTotal => _subtotal + _totalTax + _shipping;
  double get _roundOff =>
      _roundOffEnabled ? (_preRoundTotal.roundToDouble() - _preRoundTotal) : 0.0;
  double get _grandTotal => _preRoundTotal + _roundOff;

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  Future<void> _pickDate({required bool isValidTill}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isValidTill ? (_validTill ?? DateTime.now()) : _estimateDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isValidTill) {
          _validTill = picked;
        } else {
          _estimateDate = picked;
        }
      });
    }
  }

  Estimate _buildEstimateFromForm() {
    final validRows = _rows.where((r) => !r.isEmpty).toList();
    return Estimate(
      id: widget.estimateToEdit?.id,
      referenceNo: _refNoController.text.trim(),
      partyName: _partyNameController.text.trim(),
      customer: CustomerDetails(
        name: _partyNameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      ),
      lineItems: validRows.map((r) => r.toLineItem()).toList(),
      estimateDate: _fmtDate(_estimateDate),
      validTill: _validTill != null ? _fmtDate(_validTill!) : null,
      gstEnabled: _gstEnabled,
      isInterState: _isInterState,
      shipping: _shipping,
      roundOffEnabled: _roundOffEnabled,
      status: widget.estimateToEdit?.status ?? 'Open',
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      termsNotes: _termsNotesController.text.trim(),
      branch: widget.estimateToEdit?.branch,
      addedBy: widget.estimateToEdit?.addedBy,
    );
  }

  // ── Print — SkyLynk-branded PDF preview/print of the current form,
  // same letterhead and layout as the Tax Invoice ─────────────────────────
  Future<void> _print() async {
    final validRows = _rows.where((r) => !r.isEmpty).toList();
    if (validRows.isEmpty) {
      _showSnack('Add at least one item before printing', isError: true);
      return;
    }
    final estimate = _buildEstimateFromForm();
    try {
      await Printing.layoutPdf(
        onLayout: (format) => EstimatePdfService.generate(estimate),
        name: 'estimate_${estimate.referenceNo}.pdf',
      );
    } catch (e) {
      _showSnack('Failed to generate PDF: $e', isError: true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final validRows = _rows.where((r) => !r.isEmpty).toList();
    if (validRows.isEmpty) {
      _showSnack('Add at least one item', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final estimate = _buildEstimateFromForm();

      if (_isEditMode) {
        await _service.updateEstimate(estimate);
      } else {
        await _service.createEstimate(estimate);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Failed to save: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? kRed : const Color(0xFF00B894),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kTextDark,
        elevation: 0.5,
        title: Text(_isEditMode ? 'Edit Estimate' : 'Add Estimate',
            style: const TextStyle(color: kTextDark, fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: Theme(
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
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            children: [
              _sectionCard(child: _partyAndMetaSection()),
              const SizedBox(height: 14),
              _sectionCard(child: _itemsSection()),
              const SizedBox(height: 14),
              _sectionCard(child: _totalsSection()),
              const SizedBox(height: 14),
              _sectionCard(child: _notesSection()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _print,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kTextDark,
                      side: const BorderSide(color: kBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Print', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : Text(_isEditMode ? 'Update Estimate' : 'Save Estimate',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: child,
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSub)),
  );

  InputDecoration _fieldDecoration({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: kTextMute, fontSize: 13.5),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: kBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: kBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: kBlue)),
  );

  Widget _partyAndMetaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Reference No.'),
              TextFormField(
                controller: _refNoController,
                decoration: _fieldDecoration(hint: 'e.g. 20'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Estimate Date'),
              InkWell(
                onTap: () => _pickDate(isValidTill: false),
                child: InputDecorator(
                  decoration: _fieldDecoration(),
                  child: Text(_fmtDate(_estimateDate), style: const TextStyle(fontSize: 13.5, color: kTextDark)),
                ),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Party Name'),
              TextFormField(
                controller: _partyNameController,
                decoration: _fieldDecoration(hint: 'Customer / Party name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Phone (optional)'),
              TextFormField(controller: _phoneController, decoration: _fieldDecoration(hint: '10-digit number'), keyboardType: TextInputType.phone),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Valid Till (optional)'),
              InkWell(
                onTap: () => _pickDate(isValidTill: true),
                child: InputDecorator(
                  decoration: _fieldDecoration(hint: 'Select date'),
                  child: Text(_validTill != null ? _fmtDate(_validTill!) : '—',
                      style: const TextStyle(fontSize: 13.5, color: kTextDark)),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(children: [
              Checkbox(value: _gstEnabled, activeColor: kBlue, onChanged: (v) => setState(() => _gstEnabled = v ?? false)),
              const Text('GST', style: TextStyle(fontSize: 13, color: kTextDark)),
              const SizedBox(width: 10),
              Checkbox(value: _isInterState, activeColor: kBlue, onChanged: (v) => setState(() => _isInterState = v ?? false)),
              const Text('Inter-state', style: TextStyle(fontSize: 13, color: kTextDark)),
            ]),
          ),
        ]),
      ],
    );
  }

  Widget _itemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Items', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: kTextDark)),
        const SizedBox(height: 10),
        ...List.generate(_rows.length, (i) => _itemRowWidget(i)),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _addRow,
          icon: const Icon(Icons.add_rounded, size: 18, color: kBlue),
          label: const Text('Add Row', style: TextStyle(color: kBlue, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _itemRowWidget(int index) {
    final row = _rows[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: row.itemController,
                decoration: _fieldDecoration(hint: 'Item / Service name'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _removeRow(index),
              icon: const Icon(Icons.close_rounded, size: 18, color: kTextMute),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: row.qtyController,
                keyboardType: TextInputType.number,
                decoration: _fieldDecoration(hint: 'Qty'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: row.unit,
                decoration: _fieldDecoration(),
                items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12.5)))).toList(),
                onChanged: (v) => setState(() => row.unit = v ?? 'NONE'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: row.priceController,
                keyboardType: TextInputType.number,
                decoration: _fieldDecoration(hint: 'Price'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: row.discController,
                keyboardType: TextInputType.number,
                decoration: _fieldDecoration(hint: 'Discount %'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<double>(
                value: row.taxPercent,
                decoration: _fieldDecoration(),
                items: const [0.0, 5.0, 12.0, 18.0, 28.0]
                    .map((t) => DropdownMenuItem(value: t, child: Text('GST $t%', style: const TextStyle(fontSize: 12.5))))
                    .toList(),
                onChanged: (v) => setState(() => row.taxPercent = v ?? 0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('₹${row.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextDark)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _totalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Shipping / Other Charges'),
              TextFormField(
                controller: _shippingController,
                keyboardType: TextInputType.number,
                decoration: _fieldDecoration(hint: '0'),
                onChanged: (_) => setState(() {}),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(children: [
              Checkbox(value: _roundOffEnabled, activeColor: kBlue, onChanged: (v) => setState(() => _roundOffEnabled = v ?? false)),
              const Text('Round Off', style: TextStyle(fontSize: 13, color: kTextDark)),
            ]),
          ),
        ]),
        const Divider(height: 26),
        _totalRow('Subtotal', _subtotal),
        if (_totalTax > 0) _totalRow('Tax', _totalTax),
        if (_shipping > 0) _totalRow('Shipping', _shipping),
        if (_roundOffEnabled) _totalRow('Round Off', _roundOff),
        const Divider(height: 20),
        _totalRow('Grand Total', _grandTotal, bold: true),
      ],
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: kTextDark)),
          Text('₹${value.toStringAsFixed(2)}',
              style: TextStyle(fontSize: bold ? 17 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: kTextDark)),
        ],
      ),
    );
  }

  Widget _notesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Notes (optional)'),
        TextFormField(controller: _notesController, maxLines: 2, decoration: _fieldDecoration(hint: 'Internal note')),
        const SizedBox(height: 12),
        _label('Terms & Conditions'),
        TextFormField(controller: _termsNotesController, maxLines: 2, decoration: _fieldDecoration()),
      ],
    );
  }
}