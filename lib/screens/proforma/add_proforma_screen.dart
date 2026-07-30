// lib/screens/proforma/add_proforma_screen.dart
//
// "Add Proforma" — full itemized proforma-invoice builder (party search,
// proforma no/date/valid-till, GST + inter-state toggle, an editable item
// table with product autocomplete, discount/tax per row, shipping,
// round-off, terms & conditions, live total, Print + Save) styled to match
// this app's own navy/teal design language (same tokens as Add Invoice).

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:cda_inventory/models/proforma_invoice.dart';
import 'package:cda_inventory/models/invoice_line_item.dart';
import 'package:cda_inventory/models/customer_details.dart';
import 'package:cda_inventory/models/product.dart';
import 'package:cda_inventory/services/proforma_service.dart';
import 'package:cda_inventory/services/proforma_pdf_service.dart';
import 'package:cda_inventory/services/product_service.dart';
import 'package:cda_inventory/services/invoice_service.dart';
import 'package:cda_inventory/services/auth_service.dart';

class AddProformaScreen extends StatefulWidget {
  final ProformaInvoice? proformaToEdit;
  const AddProformaScreen({super.key, this.proformaToEdit});

  @override
  State<AddProformaScreen> createState() => _AddProformaScreenState();
}

// ── One editable row in the item table ────────────────────────────────────
class _ItemRow {
  final String id;
  final TextEditingController itemController = TextEditingController();
  final TextEditingController hsnController = TextEditingController();
  final TextEditingController skuController = TextEditingController();
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
    hsnCode: hsnController.text.trim().isEmpty ? null : hsnController.text.trim(),
    skuCode: skuController.text.trim().isEmpty ? null : skuController.text.trim(),
    quantity: qty.round(),
    unit: unit,
    unitPrice: price,
    discountPercent: discPercent,
    taxPercent: taxPercent,
  );

  void dispose() {
    itemController.dispose();
    hsnController.dispose();
    skuController.dispose();
    qtyController.dispose();
    priceController.dispose();
    discController.dispose();
  }
}

class _AddProformaScreenState extends State<AddProformaScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProformaService _service = ProformaService();

  final _proformaNoController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstinController = TextEditingController();
  final _billingAddressController = TextEditingController();
  final _shippingAddressController = TextEditingController();
  final _refNoController = TextEditingController();
  final _preparedByController = TextEditingController();
  final _shippingController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  final _termsNotesController =
  TextEditingController(text: 'Thanks for doing business with us!');

  DateTime _proformaDate = DateTime.now();
  DateTime? _validTill;
  DateTime? _expectedDelivery;
  String _proformaStatus = 'Draft';

  String _partyName = '';
  List<CustomerDetails> _customerSuggestions = [];
  List<Product> _productSuggestions = [];

  bool _gstEnabled = false;
  bool _isInterState = false;
  bool _roundOffEnabled = true;
  bool _isSaving = false;

  final List<_ItemRow> _rows = [];
  int _rowSeq = 0;

  bool _proformaNoAutoGenerating = false;
  bool _proformaNoAutoFailed = false;

  bool get _isEditMode => widget.proformaToEdit != null;

  static const List<String> _units = [
    'NONE', 'PCS', 'BOX', 'KG', 'GM', 'LITRE', 'ML', 'DOZEN', 'PACK', 'METER', 'SET',
  ];
  static const List<double> _taxRates = [0, 5, 12, 18, 28];

  // ── Design tokens (matches Add Invoice / the rest of the app) ───────────
  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kCoral = Color(0xFFFF6B6B);
  static const Color kAmber = Color(0xFFFFB800);
  static const Color kSurface = Color(0xFFF0F4F8);

  Color get _accent => _isEditMode ? kAmber : kTeal;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final p = widget.proformaToEdit!;
      _proformaNoController.text = p.proformaNo;
      _partyName = p.customer?.name ?? p.partyName;
      _phoneController.text = p.customer?.phone ?? '';
      _emailController.text = p.customer?.email ?? '';
      _gstinController.text = p.customer?.gstin ?? '';
      _billingAddressController.text = p.customer?.billingAddress ?? '';
      _shippingAddressController.text = p.customer?.shippingAddress ?? '';
      _refNoController.text = p.customerRefNo ?? '';
      _preparedByController.text = p.addedBy ?? _currentUserName();
      _notesController.text = p.notes ?? '';
      _termsNotesController.text = p.termsNotes ?? _termsNotesController.text;
      _shippingController.text = p.shipping.toStringAsFixed(2);
      _roundOffEnabled = p.roundOffEnabled;
      _proformaDate = p.proformaDateTime ?? DateTime.now();
      _validTill = p.validTillDate;
      _expectedDelivery = p.expectedDeliveryDate;
      _proformaStatus = ProformaInvoice.proformaStatusOptions.contains(p.proformaStatus)
          ? p.proformaStatus
          : 'Draft';
      _gstEnabled = p.gstEnabled;
      _isInterState = p.isInterState;
      for (final li in p.lineItems) {
        final row = _ItemRow(id: li.id, unit: li.unit, taxPercent: li.taxPercent);
        row.itemController.text = li.description;
        row.hsnController.text = li.hsnCode ?? '';
        row.skuController.text = li.skuCode ?? '';
        row.qtyController.text = li.quantity.toString();
        row.priceController.text = li.unitPrice.toStringAsFixed(2);
        row.discController.text = li.discountPercent.toStringAsFixed(0);
        _rows.add(row);
      }
    } else {
      _proformaNoAutoGenerating = true;
      _preparedByController.text = _currentUserName();
    }
    while (_rows.length < 1) {
      _rows.add(_ItemRow(id: 'row_${_rowSeq++}'));
    }
    _loadSuggestions();
  }

  // ── Logged-in user's display name, used to auto-fill "Prepared By" ─────
  String _currentUserName() {
    final user = AuthService.currentUser;
    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    return AuthService.currentUserEmail ?? 'CDA User';
  }

  Future<void> _loadSuggestions() async {
    try {
      final customers = await _service.fetchCustomerSuggestions();
      final products = await ProductService.getProducts();
      if (!_isEditMode) {
        final nextNo = await _service.suggestNextProformaNumber();
        if (mounted) _proformaNoController.text = nextNo;
      }
      if (mounted) {
        setState(() {
          _customerSuggestions = customers;
          _productSuggestions = products;
          _proformaNoAutoGenerating = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _proformaNoAutoGenerating = false;
          _proformaNoAutoFailed = true;
        });
      }
    }
  }

  Future<void> _regenerateProformaNo() async {
    setState(() {
      _proformaNoAutoGenerating = true;
      _proformaNoAutoFailed = false;
    });
    try {
      final nextNo = await _service.suggestNextProformaNumber(forceRefresh: true);
      if (mounted) {
        setState(() {
          _proformaNoController.text = nextNo;
          _proformaNoAutoGenerating = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _proformaNoAutoGenerating = false;
          _proformaNoAutoFailed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _proformaNoController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstinController.dispose();
    _billingAddressController.dispose();
    _shippingAddressController.dispose();
    _refNoController.dispose();
    _preparedByController.dispose();
    _shippingController.dispose();
    _notesController.dispose();
    _termsNotesController.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  // ── Totals ────────────────────────────────────────────────────────────
  List<_ItemRow> get _validRows => _rows.where((r) => !r.isEmpty).toList();
  double get _itemsTotalQty => _validRows.fold(0.0, (s, r) => s + r.qty);
  double get _subtotal => _validRows.fold(0.0, (s, r) => s + r.taxable);
  double get _taxTotal => _validRows.fold(0.0, (s, r) => s + r.taxAmount);
  double get _shipping => double.tryParse(_shippingController.text.trim()) ?? 0;
  double get _preRoundTotal => _subtotal + _taxTotal + _shipping;
  double get _roundOffAmount =>
      _roundOffEnabled ? (_preRoundTotal.roundToDouble() - _preRoundTotal) : 0.0;
  double get _grandTotal => _preRoundTotal + _roundOffAmount;

  void _addRow() {
    setState(() => _rows.add(_ItemRow(id: 'row_${_rowSeq++}')));
  }

  void _removeRow(_ItemRow row) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows.remove(row);
      row.dispose();
    });
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  Future<void> _pickDate({required bool isValidTill, bool isExpectedDelivery = false}) async {
    final initial = isExpectedDelivery
        ? (_expectedDelivery ?? _proformaDate.add(const Duration(days: 7)))
        : (isValidTill ? (_validTill ?? _proformaDate.add(const Duration(days: 15))) : _proformaDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: kNavy, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isExpectedDelivery) {
          _expectedDelivery = picked;
        } else if (isValidTill) {
          _validTill = picked;
        } else {
          _proformaDate = picked;
        }
      });
    }
  }

  ProformaInvoice _buildFromForm() {
    final lineItems = _validRows.map((r) => r.toLineItem()).toList();
    return ProformaInvoice(
      id: widget.proformaToEdit?.id,
      proformaNo: _proformaNoController.text.trim(),
      partyName: _partyName.trim(),
      customer: CustomerDetails(
        name: _partyName.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        gstin: _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim(),
        billingAddress: _billingAddressController.text.trim().isEmpty ? null : _billingAddressController.text.trim(),
        shippingAddress: _shippingAddressController.text.trim().isEmpty ? null : _shippingAddressController.text.trim(),
      ),
      lineItems: lineItems,
      proformaDate: _fmtDate(_proformaDate),
      validTill: _validTill != null ? _fmtDate(_validTill!) : null,
      expectedDelivery: _expectedDelivery != null ? _fmtDate(_expectedDelivery!) : null,
      customerRefNo: _refNoController.text.trim().isEmpty ? null : _refNoController.text.trim(),
      gstEnabled: _gstEnabled,
      isInterState: _isInterState,
      shipping: _shipping,
      roundOffEnabled: _roundOffEnabled,
      status: widget.proformaToEdit?.status ?? 'Open',
      convertedInvoiceId: widget.proformaToEdit?.convertedInvoiceId,
      convertedInvoiceNo: widget.proformaToEdit?.convertedInvoiceNo,
      proformaStatus: _proformaStatus,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      termsNotes: _termsNotesController.text.trim(),
      addedBy: _preparedByController.text.trim().isEmpty ? widget.proformaToEdit?.addedBy : _preparedByController.text.trim(),
      addedAt: _isEditMode ? widget.proformaToEdit!.addedAt : DateTime.now(),
      branch: widget.proformaToEdit?.branch,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_partyName.trim().isEmpty) {
      _showSnack('Party name is required', isError: true);
      return;
    }
    if (_validRows.isEmpty) {
      _showSnack('Add at least one item', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final proformaNo = _proformaNoController.text.trim();
      final noChanged = !_isEditMode || proformaNo != widget.proformaToEdit!.proformaNo;
      if (noChanged) {
        final exists = await _service.proformaNoExists(
          proformaNo,
          excludeId: widget.proformaToEdit?.id,
        );
        if (exists) {
          if (mounted) {
            setState(() => _isSaving = false);
            _showSnack('Proforma number "$proformaNo" already exists', isError: true);
          }
          return;
        }
      }

      final proforma = _buildFromForm();
      if (_isEditMode) {
        await _service.updateProforma(proforma);
      } else {
        await _service.createProforma(proforma);
      }

      if (mounted) {
        _showSnack(_isEditMode ? 'Proforma invoice updated' : 'Proforma invoice created');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── "Save as Draft" — forces status to Draft, then reuses the normal
  // save/validate flow so behaviour stays identical to the existing Save.
  Future<void> _saveAsDraft() async {
    setState(() => _proformaStatus = 'Draft');
    await _save();
  }

  // ── "Convert to Sales Invoice" — saves/updates the proforma first (so a
  // record always exists), then mirrors the same conversion the Proforma
  // list screen already performs via ProformaService.convertToInvoice.
  Future<void> _convertToSalesInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_partyName.trim().isEmpty) {
      _showSnack('Party name is required', isError: true);
      return;
    }
    if (_validRows.isEmpty) {
      _showSnack('Add at least one item', isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Convert to Sales Invoice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Save this proforma and convert it into a Sale Invoice for ₹${_grandTotal.toStringAsFixed(2)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kNavy, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      var proforma = _buildFromForm();

      if (proforma.id != null) {
        proforma = await _service.updateProforma(proforma);
      } else {
        final proformaNo = proforma.proformaNo;
        final exists = await _service.proformaNoExists(proformaNo);
        if (exists) {
          if (mounted) {
            setState(() => _isSaving = false);
            _showSnack('Proforma number "$proformaNo" already exists', isError: true);
          }
          return;
        }
        proforma = await _service.createProforma(proforma);
      }

      final newInvoiceNo = await InvoiceService().suggestNextInvoiceNumber();
      final invoice = await _service.convertToInvoice(proforma, newInvoiceNo: newInvoiceNo);

      if (mounted) {
        setState(() => _proformaStatus = 'Converted to Invoice');
        _showSnack('Converted to invoice ${invoice.invoiceNo}');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _printProforma() async {
    if (_validRows.isEmpty) {
      _showSnack('Add at least one item before printing', isError: true);
      return;
    }
    final proforma = _buildFromForm();
    await Printing.layoutPdf(onLayout: (format) => ProformaPdfService.generate(proforma));
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: isError ? kCoral : const Color(0xFF00B894),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final accentColor = _accent;

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? 'Edit Proforma' : 'Add Proforma',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            enabled: !_isSaving,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'draft') _saveAsDraft();
              if (value == 'convert') _convertToSalesInvoice();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'draft',
                child: Row(children: [
                  Icon(Icons.edit_note_rounded, size: 18, color: kNavy),
                  SizedBox(width: 10),
                  Text('Save as Draft'),
                ]),
              ),
              const PopupMenuItem(
                value: 'convert',
                child: Row(children: [
                  Icon(Icons.sync_alt_rounded, size: 18, color: kNavy),
                  SizedBox(width: 10),
                  Text('Convert to Sales Invoice'),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          children: [
            _headerBanner(),
            const SizedBox(height: 20),

            _sectionLabel('PARTY'),
            const SizedBox(height: 10),
            _card(children: [
              _partyAutocomplete(accentColor),
              const SizedBox(height: 14),
              _field(
                controller: _phoneController,
                label: 'Phone No.',
                hint: 'e.g. 98765 43210',
                icon: Icons.call_outlined,
                keyboardType: TextInputType.phone,
                accentColor: accentColor,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _emailController,
                label: 'Customer Email',
                hint: 'e.g. customer@email.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                accentColor: accentColor,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _gstinController,
                label: 'Customer GSTIN',
                hint: 'e.g. 33ABCDE1234F1Z5',
                icon: Icons.badge_outlined,
                accentColor: accentColor,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _billingAddressController,
                label: 'Billing Address',
                hint: 'Street, City, State, PIN',
                icon: Icons.location_on_outlined,
                accentColor: accentColor,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _shippingAddressController,
                label: 'Shipping Address (optional)',
                hint: 'Leave blank if same as billing',
                icon: Icons.local_shipping_outlined,
                accentColor: accentColor,
              ),
            ]),

            const SizedBox(height: 20),
            _sectionLabel('PROFORMA DETAILS'),
            const SizedBox(height: 10),
            _card(children: [
              _field(
                controller: _proformaNoController,
                label: _isEditMode ? 'Proforma Number' : 'Proforma Number (auto-generated)',
                hint: _proformaNoAutoGenerating ? 'Generating…' : 'e.g. PI-0001',
                icon: Icons.tag_rounded,
                accentColor: accentColor,
                readOnly: !_isEditMode && !_proformaNoAutoFailed,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                suffixIcon: _isEditMode
                    ? null
                    : (_proformaNoAutoGenerating
                    ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                    : IconButton(
                  icon: Icon(Icons.refresh_rounded, size: 20, color: Colors.grey.shade500),
                  tooltip: 'Regenerate number',
                  onPressed: _regenerateProformaNo,
                )),
              ),
              if (!_isEditMode && _proformaNoAutoFailed)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Could not auto-generate a number — enter one manually.',
                    style: TextStyle(fontSize: 12, color: kCoral),
                  ),
                ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _dateTile('Proforma Date', _proformaDate, accentColor, () => _pickDate(isValidTill: false))),
                const SizedBox(width: 12),
                Expanded(child: _dateTile('Valid Till', _validTill, accentColor, () => _pickDate(isValidTill: true), placeholder: 'Optional')),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Checkbox(value: _gstEnabled, activeColor: accentColor, onChanged: (v) => setState(() => _gstEnabled = v ?? false)),
                const Text('GST', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNavy)),
                const SizedBox(width: 16),
                Checkbox(value: _isInterState, activeColor: accentColor, onChanged: (v) => setState(() => _isInterState = v ?? false)),
                const Text('Inter-state', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNavy)),
              ]),
              const SizedBox(height: 14),
              _field(
                controller: _refNoController,
                label: 'Customer PO / Reference No. (optional)',
                hint: 'e.g. PO-4521',
                icon: Icons.confirmation_number_outlined,
                accentColor: accentColor,
              ),
              const SizedBox(height: 14),
              _dateTile('Expected Delivery Date', _expectedDelivery, accentColor, () => _pickDate(isValidTill: false, isExpectedDelivery: true), placeholder: 'Optional'),
              const SizedBox(height: 14),
              _statusDropdown(accentColor),
              const SizedBox(height: 14),
              _field(
                controller: _preparedByController,
                label: 'Prepared By',
                hint: 'Auto-filled with logged-in user',
                icon: Icons.person_pin_outlined,
                accentColor: accentColor,
                readOnly: true,
              ),
            ]),

            const SizedBox(height: 20),
            Row(children: [
              _sectionLabel('ITEMS'),
              const Spacer(),
              Text('${_validRows.length} item(s)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 10),
            ..._rows.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _itemRowCard(e.value, e.key + 1, accentColor),
            )),
            OutlinedButton.icon(
              onPressed: _addRow,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('ADD ITEM'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accentColor,
                side: BorderSide(color: accentColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            _itemsTotalsBar(),

            const SizedBox(height: 20),
            _sectionLabel('TERMS & NOTES'),
            const SizedBox(height: 10),
            _card(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextFormField(
                  controller: _termsNotesController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kNavy),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    labelText: 'Terms & Conditions',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _field(
                controller: _notesController,
                label: 'Internal Note (optional)',
                hint: 'Not shown on the printed PDF',
                icon: Icons.notes_rounded,
                accentColor: accentColor,
              ),
            ]),

            const SizedBox(height: 20),
            _sectionLabel('PAYMENT SUMMARY'),
            const SizedBox(height: 10),
            _card(children: [
              _field(
                controller: _shippingController,
                label: 'Shipping',
                hint: '0.00',
                icon: Icons.local_shipping_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                accentColor: accentColor,
              ),
              const SizedBox(height: 14),
              Row(children: [
                Checkbox(
                  value: _roundOffEnabled,
                  activeColor: accentColor,
                  onChanged: (v) => setState(() => _roundOffEnabled = v ?? false),
                ),
                const Text('Round Off', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNavy)),
                const Spacer(),
                Text(
                  '${_roundOffAmount >= 0 ? '+' : ''}${_roundOffAmount.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                ),
              ]),
              const Divider(height: 28),
              _totalPreview(),
            ]),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(accentColor),
    );
  }

  // ── Header banner (mirrors the navy "Sale" bar on Add Invoice) ─────────
  Widget _headerBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        const Icon(Icons.description_outlined, color: kTeal, size: 22),
        const SizedBox(width: 10),
        const Text('Proforma Invoice',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: kTeal.withOpacity(0.16), borderRadius: BorderRadius.circular(20)),
          child: const Text('Not a Tax Invoice',
              style: TextStyle(color: kTeal, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _dateTile(String label, DateTime? value, Color accentColor, VoidCallback onTap, {String placeholder = '—'}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor, width: 1.5),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded, size: 16, color: accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                Text(value != null ? _fmtDate(value) : placeholder,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNavy)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _statusDropdown(Color accentColor) {
    return DropdownButtonFormField<String>(
      value: ProformaInvoice.proformaStatusOptions.contains(_proformaStatus) ? _proformaStatus : 'Draft',
      isExpanded: true,
      dropdownColor: Colors.white,
      icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey.shade400),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kNavy),
      decoration: InputDecoration(
        labelText: 'Proforma Status',
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: Icon(Icons.flag_outlined, size: 20, color: Colors.grey.shade400),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor, width: 1.5)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      items: ProformaInvoice.proformaStatusOptions
          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14))))
          .toList(),
      onChanged: (v) => setState(() => _proformaStatus = v ?? _proformaStatus),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 1.4),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color accentColor,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onChanged: (_) => setState(() {}),
      validator: validator,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: readOnly ? Colors.grey.shade600 : kNavy),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade400),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kCoral)),
        filled: true,
        fillColor: readOnly ? Colors.grey.shade100 : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _partyAutocomplete(Color accentColor) {
    return Autocomplete<CustomerDetails>(
      initialValue: TextEditingValue(text: _partyName),
      displayStringForOption: (c) => c.name,
      optionsBuilder: (value) {
        if (value.text.trim().isEmpty) return const Iterable<CustomerDetails>.empty();
        final q = value.text.toLowerCase();
        return _customerSuggestions.where((c) => c.name.toLowerCase().contains(q) || (c.phone ?? '').contains(q));
      },
      onSelected: (selection) {
        setState(() {
          _partyName = selection.name;
          _phoneController.text = selection.phone ?? '';
        });
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 340),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline_rounded, size: 18),
                    title: Text(option.name, style: const TextStyle(fontSize: 14)),
                    subtitle: option.phone == null ? null : Text(option.phone!, style: const TextStyle(fontSize: 11)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => _partyName = v,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kNavy),
          decoration: InputDecoration(
            labelText: 'Search by Name/Phone *',
            hintText: 'e.g. Ravi Kumar',
            labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.grey.shade400),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kCoral)),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        );
      },
    );
  }

  // ── One item row card ────────────────────────────────────────────────
  Widget _itemRowCard(_ItemRow row, int index, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 22, height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: kNavy.withOpacity(0.06), borderRadius: BorderRadius.circular(6)),
            child: Text('$index', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kNavy)),
          ),
          const SizedBox(width: 8),
          const Text('ITEM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 1)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: kCoral),
            onPressed: () => _removeRow(row),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
        const SizedBox(height: 8),
        _itemAutocomplete(row, accentColor),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _smallField(
              controller: row.hsnController,
              label: 'HSN/SAC Code',
              keyboardType: TextInputType.text,
              accentColor: accentColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _smallField(
              controller: row.skuController,
              label: 'SKU/Item Code (optional)',
              keyboardType: TextInputType.text,
              accentColor: accentColor,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _smallField(
              controller: row.qtyController,
              label: 'Qty',
              keyboardType: TextInputType.number,
              accentColor: accentColor,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _unitDropdown(row, accentColor)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _smallField(
              controller: row.priceController,
              label: 'Price/Unit',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              accentColor: accentColor,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _smallField(
              controller: row.discController,
              label: 'Disc %',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              accentColor: accentColor,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        _taxDropdown(row, accentColor),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Text('Amount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const Spacer(),
            Text('₹${row.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kNavy)),
          ]),
        ),
      ]),
    );
  }

  Widget _itemAutocomplete(_ItemRow row, Color accentColor) {
    return Autocomplete<Product>(
      initialValue: TextEditingValue(text: row.itemController.text),
      displayStringForOption: (p) => p.name,
      optionsBuilder: (value) {
        if (value.text.trim().isEmpty) return const Iterable<Product>.empty();
        final q = value.text.toLowerCase();
        return _productSuggestions.where((p) => p.name.toLowerCase().contains(q));
      },
      onSelected: (selection) {
        setState(() {
          row.itemController.text = selection.name;
          if (row.priceController.text.trim().isEmpty || row.priceController.text.trim() == '0') {
            row.priceController.text = selection.price.toStringAsFixed(2);
          }
        });
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 340),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.inventory_2_outlined, size: 18),
                    title: Text(option.name, style: const TextStyle(fontSize: 14)),
                    trailing: Text('₹${option.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        if (controller.text != row.itemController.text) {
          controller.text = row.itemController.text;
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => setState(() => row.itemController.text = v),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kNavy),
          decoration: InputDecoration(
            labelText: 'Item / Service',
            hintText: 'Search or type item name',
            labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 13),
            prefixIcon: Icon(Icons.inventory_2_outlined, size: 18, color: Colors.grey.shade400),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accentColor, width: 1.5)),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        );
      },
    );
  }

  Widget _smallField({
    required TextEditingController controller,
    required String label,
    required Color accentColor,
    TextInputType keyboardType = TextInputType.text,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNavy),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accentColor, width: 1.5)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }

  Widget _unitDropdown(_ItemRow row, Color accentColor) {
    return DropdownButtonFormField<String>(
      value: row.unit,
      isExpanded: true,
      dropdownColor: Colors.white,
      icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey.shade400),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNavy),
      decoration: InputDecoration(
        labelText: 'Unit',
        isDense: true,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accentColor, width: 1.5)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12)))).toList(),
      onChanged: (v) => setState(() => row.unit = v ?? row.unit),
    );
  }

  Widget _taxDropdown(_ItemRow row, Color accentColor) {
    return DropdownButtonFormField<double>(
      value: _taxRates.contains(row.taxPercent) ? row.taxPercent : 0,
      isExpanded: true,
      dropdownColor: Colors.white,
      icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey.shade400),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNavy),
      decoration: InputDecoration(
        labelText: 'Tax',
        isDense: true,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 11),
        prefixIcon: Icon(Icons.percent_rounded, size: 16, color: Colors.grey.shade400),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accentColor, width: 1.5)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: _taxRates
          .map((t) => DropdownMenuItem(value: t, child: Text(t == 0 ? 'Without Tax' : 'GST ${t.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12))))
          .toList(),
      onChanged: (v) => setState(() => row.taxPercent = v ?? 0),
    );
  }

  Widget _itemsTotalsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(children: [
        const Text('TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 1)),
        const Spacer(),
        Text('Qty: ${_itemsTotalQty.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(width: 16),
        Text('₹${(_subtotal + _taxTotal).toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kNavy)),
      ]),
    );
  }

  Widget _totalPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Icon(Icons.calculate_rounded, color: kTeal, size: 22),
        const SizedBox(width: 12),
        const Text('Estimated Total', style: TextStyle(color: Colors.white70, fontSize: 14)),
        const Spacer(),
        Text('₹${_grandTotal.toStringAsFixed(2)}',
            style: const TextStyle(color: kTeal, fontWeight: FontWeight.w800, fontSize: 20)),
      ]),
    );
  }

  Widget _bottomBar(Color accentColor) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isSaving ? null : _printProforma,
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Print'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kNavy,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEditMode ? kAmber : kNavy,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isEditMode ? Icons.save_rounded : Icons.add_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(_isEditMode ? 'Update Proforma' : 'Save Proforma',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
