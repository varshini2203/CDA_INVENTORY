// lib/screens/estimates/add_estimate_screen.dart
//
// "Add Estimate" form — Vyapar-style itemized estimate/quotation builder.

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:cda_inventory/models/estimate.dart';
import 'package:cda_inventory/models/invoice_line_item.dart';
import 'package:cda_inventory/models/customer_details.dart';
import 'package:cda_inventory/models/new_product.dart';
import 'package:cda_inventory/services/new_product_service.dart';
import 'package:cda_inventory/services/estimate_service.dart';
import 'package:cda_inventory/services/current_user_service.dart';
import 'package:cda_inventory/widgets/reports/branch_filter_bar.dart';
import 'package:cda_inventory/services/estimate_pdf_service.dart';

class _ItemRow {
  final String id;
  final TextEditingController itemController = TextEditingController();
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController discController = TextEditingController(text: '0');
  double taxPercent;
  String unit;

  /// The New Products item this row was picked from (null until picked).
  NewProduct? product;

  /// Item name of a row loaded from an already-saved estimate (typed before
  /// products had to be picked). It stays valid as long as it is unchanged.
  String? legacyName;

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
  // Reference No. is auto-generated and locked; only unlocked if generation fails (e.g. offline).
  bool _refNoAutoFailed = false;
  final _partyNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstinController = TextEditingController();
  final _billingAddressController = TextEditingController();
  final _shippingAddressController = TextEditingController();
  final _partyFocus = FocusNode();
  String _placeOfSupply = 'Tamil Nadu';
  List<CustomerDetails> _customerSuggestions = [];
  final _shippingController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  final _termsNotesController =
  TextEditingController(text: 'Thanks for doing business with us!');
  final _bankDetailsController = TextEditingController();

  DateTime _estimateDate = DateTime.now();
  DateTime? _validTill;

  // Firm this estimate belongs to (feeds the "All Firms" filter + reports).
  String _selectedBranch = kBranch1;

  bool _gstEnabled = false;
  bool _isInterState = false;
  bool _roundOffEnabled = true;
  bool _isSaving = false;

  final List<_ItemRow> _rows = [];
  int _rowSeq = 0;

  // Products come ONLY from the New Products module (new_products).
  List<NewProduct> _products = [];
  bool _productsLoading = true;
  String? _productsError;

  bool get _isEditMode => widget.estimateToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final e = widget.estimateToEdit!;
      _refNoController.text = e.referenceNo;
      _partyNameController.text = e.partyName;
      _phoneController.text = e.customer?.phone ?? '';
      _emailController.text = e.customer?.email ?? '';
      _gstinController.text = e.customer?.gstin ?? '';
      _billingAddressController.text = e.customer?.billingAddress ?? '';
      _shippingAddressController.text = e.customer?.shippingAddress ?? '';
      _placeOfSupply = e.customer?.placeOfSupply ?? 'Tamil Nadu';
      _shippingController.text = e.shipping.toStringAsFixed(0);
      _notesController.text = e.notes ?? '';
      _termsNotesController.text = e.termsNotes ?? '';
      _bankDetailsController.text = e.bankDetails ?? '';
      _estimateDate = e.estimateDateTime ?? DateTime.now();
      _validTill = e.validTillDate;
      _selectedBranch = normalizeBranch(e.branch) ?? kBranch1;
      _gstEnabled = e.gstEnabled;
      _isInterState = e.isInterState;
      _roundOffEnabled = e.roundOffEnabled;
      for (final li in e.lineItems) {
        final row = _ItemRow(id: li.id, unit: li.unit, taxPercent: li.taxPercent);
        row.itemController.text = li.description;
        row.qtyController.text = li.quantity.toString();
        row.priceController.text = li.unitPrice.toString();
        row.discController.text = li.discountPercent.toString();
        row.legacyName = li.description;
        _rows.add(row);
      }
    } else {
      _service.suggestNextReferenceNumber().then((n) {
        if (mounted) setState(() => _refNoController.text = n);
      }).catchError((_) {
        if (mounted) setState(() => _refNoAutoFailed = true);
      });
    }
    if (_rows.isEmpty) _addRow();
    _loadProducts();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final customers = await _service.fetchCustomerSuggestions();
      if (mounted) setState(() => _customerSuggestions = customers);
    } catch (_) {}
  }

  bool get _isKnownCustomer {
    final n = _partyNameController.text.trim().toLowerCase();
    return n.isNotEmpty &&
        _customerSuggestions.any((c) => c.name.trim().toLowerCase() == n);
  }

  Widget _partyAutocomplete() {
    return RawAutocomplete<CustomerDetails>(
      textEditingController: _partyNameController,
      focusNode: _partyFocus,
      displayStringForOption: (c) => c.name,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<CustomerDetails>.empty();
        return _customerSuggestions.where(
              (c) => c.name.toLowerCase().contains(q) || (c.phone ?? '').contains(q),
        );
      },
      onSelected: (c) {
        setState(() {
          _phoneController.text = c.phone ?? '';
          _emailController.text = c.email ?? '';
          _gstinController.text = c.gstin ?? '';
          _billingAddressController.text = c.billingAddress ?? '';
          _shippingAddressController.text = c.shippingAddress ?? '';
          _placeOfSupply = c.placeOfSupply;
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: _fieldDecoration(hint: 'Search by Name/Phone'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        );
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
                  final o = options.elementAt(index);
                  final sub = [
                    if (o.phone != null) o.phone!,
                    if (o.gstin != null) o.gstin!,
                  ].join('  •  ');
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline_rounded, size: 18),
                    title: Text(o.name, style: const TextStyle(fontSize: 14)),
                    subtitle: sub.isEmpty ? null : Text(sub, style: const TextStyle(fontSize: 11)),
                    onTap: () => onSelected(o),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ── New Products (the only product source for Estimate) ───────────────
  Future<void> _loadProducts() async {
    if (!_productsLoading) {
      setState(() {
        _productsLoading = true;
        _productsError = null;
      });
    }
    try {
      // forceRefresh so the stock quantities shown are current.
      final all = await NewProductService.getNewProducts(forceRefresh: true);
      if (!mounted) return;
      final byId = {for (final p in all) p.productId: p};
      final byName = {for (final p in all) p.productName.trim().toLowerCase(): p};
      // Like Invoice: only products that still have stock are offered.
      final list = all.where((p) => p.quantity > 0).toList()
        ..sort((a, b) =>
            a.productName.toLowerCase().compareTo(b.productName.toLowerCase()));
      setState(() {
        _products = list;
        for (final r in _rows) {
          final linked = r.product;
          if (linked != null) {
            r.product = byId[linked.productId] ?? linked; // refresh stock
          } else if (r.legacyName != null) {
            r.product = byName[r.itemController.text.trim().toLowerCase()];
          }
        }
        _productsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _productsLoading = false;
        _productsError = e.toString();
      });
    }
  }

  static String _fmtNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  String _unitFor(String raw) {
    final u = raw.trim().toUpperCase();
    return _units.contains(u) ? u : 'NONE';
  }

  /// Fills the row from the chosen product. Price is auto-listed from the
  /// product's sale price but stays a normal editable field.
  void _applyProduct(_ItemRow row, NewProduct p) {
    setState(() {
      row.product = p;
      row.itemController.text = p.productName;
      row.priceController.text = p.salePrice > 0 ? _fmtNum(p.salePrice) : '';
      if (row.qty == 0) row.qtyController.text = '1';
      row.unit = _unitFor(p.unit);
    });
  }

  /// A filled-in row must be a product picked from New Products. Rows from
  /// an already-saved estimate stay valid while their name is unchanged.
  bool _rowNeedsProduct(_ItemRow r) {
    if (r.isEmpty || r.product != null) return false;
    final legacy = r.legacyName;
    return !(legacy != null && r.itemController.text.trim() == legacy);
  }

  Color _stockColor(NewProduct p) {
    final s = NewProductService.stockStatus(p);
    if (s == NewProductService.stockOutOfStock) return kRed;
    if (s == NewProductService.stockLow) return const Color(0xFFF59E0B);
    return const Color(0xFF00B894);
  }

  @override
  void dispose() {
    _refNoController.dispose();
    _partyNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstinController.dispose();
    _billingAddressController.dispose();
    _shippingAddressController.dispose();
    _partyFocus.dispose();
    _shippingController.dispose();
    _notesController.dispose();
    _termsNotesController.dispose();
    _bankDetailsController.dispose();
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
    if (!isValidTill) return; // Record date is automatic; only this other date stays manual.
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
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        gstin: _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim().toUpperCase(),
        billingAddress: _billingAddressController.text.trim().isEmpty ? null : _billingAddressController.text.trim(),
        shippingAddress: _shippingAddressController.text.trim().isEmpty ? null : _shippingAddressController.text.trim(),
        placeOfSupply: _placeOfSupply,
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
      bankDetails: _bankDetailsController.text.trim().isEmpty
          ? null
          : _bankDetailsController.text.trim(),
      branch: _selectedBranch,
      addedBy: widget.estimateToEdit?.addedBy ?? CurrentUserService.nameSync,
      addedAt: widget.estimateToEdit?.addedAt ?? DateTime.now(),
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
    if (validRows.any(_rowNeedsProduct)) {
      _showSnack('Select every item from New Products before printing', isError: true);
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

  // Firm / branch picker — same two choices as Sale Invoices (CDA Admin /
  // CDA Ops). Previously estimates never stored a branch, so the list's
  // "All Firms" filter had nothing to show.
  Widget _branchChooser() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Firm / Branch'),
      Row(children: [kBranch1, kBranch2].map((b) {
        final selected = _selectedBranch == b;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _selectedBranch = b),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? kBlue : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? kBlue : kBorder),
              ),
              child: Text(branchDisplayName(b),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : kTextDark,
                  )),
            ),
          ),
        );
      }).toList()),
    ]);
  }

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
                readOnly: !_refNoAutoFailed,
                style: const TextStyle(fontWeight: FontWeight.w700, color: kTextDark),
                decoration: _fieldDecoration(hint: _refNoAutoFailed ? 'e.g. EST-001' : 'Generating…').copyWith(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  suffixIcon: _refNoAutoFailed
                      ? null
                      : const Icon(Icons.lock_outline_rounded, size: 18, color: kTextMute),
                ),
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
              _partyAutocomplete(),
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
        if (_partyNameController.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              _isKnownCustomer
                  ? 'Saved customer — details auto-filled'
                  : 'New customer — will be saved automatically',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _isKnownCustomer ? const Color(0xFF00896F) : Colors.grey.shade500,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Email (optional)'),
              TextFormField(
                controller: _emailController,
                decoration: _fieldDecoration(hint: 'customer@email.com'),
                keyboardType: TextInputType.emailAddress,
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('GSTIN (optional)'),
              TextFormField(
                controller: _gstinController,
                decoration: _fieldDecoration(hint: '15-character GST number'),
                textCapitalization: TextCapitalization.characters,
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Billing Address (optional)'),
              TextFormField(
                controller: _billingAddressController,
                decoration: _fieldDecoration(hint: 'Street, city, pincode'),
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                maxLines: 2,
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Shipping Address (optional)'),
              TextFormField(
                controller: _shippingAddressController,
                decoration: _fieldDecoration(hint: 'Street, city, pincode'),
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                maxLines: 2,
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        _branchChooser(),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              const Expanded(child: SizedBox()),
            ]),
            const SizedBox(height: 14),
            Row(mainAxisSize: MainAxisSize.min, children: [
              InkWell(
                onTap: () => setState(() => _gstEnabled = !_gstEnabled),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Checkbox(
                    value: _gstEnabled,
                    activeColor: kBlue,
                    side: const BorderSide(color: kBorder, width: 1.5),
                    onChanged: (v) => setState(() => _gstEnabled = v ?? false),
                  ),
                  const Text('GST', style: TextStyle(fontSize: 13, color: kTextDark)),
                ]),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: () => setState(() => _isInterState = !_isInterState),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Checkbox(
                    value: _isInterState,
                    activeColor: kBlue,
                    side: const BorderSide(color: kBorder, width: 1.5),
                    onChanged: (v) => setState(() => _isInterState = v ?? false),
                  ),
                  const Text('Inter-state', style: TextStyle(fontSize: 13, color: kTextDark)),
                ]),
              ),
            ]),
          ]),
        ),
      ],
    );
  }

  Widget _itemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Items', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: kTextDark)),
          const SizedBox(width: 8),
          const Text('from New Products', style: TextStyle(fontSize: 11.5, color: kTextMute)),
          const Spacer(),
          if (_productsLoading)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          else
            IconButton(
              tooltip: 'Refresh products & stock',
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh_rounded, size: 18, color: kTextSub),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
        ]),
        if (_productsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Could not load products: $_productsError',
                style: const TextStyle(fontSize: 12, color: kRed)),
          )
        else if (!_productsLoading && _products.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('No products found. Add products in the New Products module first.',
                style: TextStyle(fontSize: 12, color: kTextSub)),
          ),
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
              child: _itemAutocomplete(row),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _removeRow(index),
              icon: const Icon(Icons.close_rounded, size: 18, color: kTextMute),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
          ]),
          if (row.product != null) _stockLine(row),
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

  /// Type-ahead item field: suggestions come ONLY from New Products and
  /// show each product's quantity and price. Typed text that isn't picked
  /// from the list is rejected on save.
  Widget _itemAutocomplete(_ItemRow row) {
    return LayoutBuilder(builder: (context, constraints) {
      return Autocomplete<NewProduct>(
        key: ValueKey('item_${row.id}'),
        initialValue: TextEditingValue(text: row.itemController.text),
        displayStringForOption: (p) => p.productName,
        optionsBuilder: (value) {
          final q = value.text.trim().toLowerCase();
          final usedElsewhere = _rows
              .where((r) => !identical(r, row) && r.product != null)
              .map((r) => r.product!.productId)
              .toSet();
          final pool = _products.where((p) => !usedElsewhere.contains(p.productId));
          if (q.isEmpty) return pool;
          return pool.where((p) =>
          p.productName.toLowerCase().contains(q) ||
              p.productCode.toLowerCase().contains(q) ||
              p.brand.toLowerCase().contains(q) ||
              p.modelNumber.toLowerCase().contains(q));
        },
        onSelected: (p) => _applyProduct(row, p),
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: Colors.white,
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: 280, maxWidth: constraints.maxWidth),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: kBorder),
                  itemBuilder: (context, i) {
                    final p = options.elementAt(i);
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.inventory_2_outlined,
                          size: 20, color: kTextSub),
                      title: Text(p.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kTextDark)),
                      subtitle: Text('Qty: ${p.quantity} ${p.unit}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _stockColor(p))),
                      trailing: Text('₹${_fmtNum(p.salePrice)}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kTextDark)),
                      onTap: () => onSelected(p),
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
            style: const TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w600, color: kTextDark),
            decoration: _fieldDecoration(hint: 'Search or type product name')
                .copyWith(
              prefixIcon: const Icon(Icons.inventory_2_outlined,
                  size: 18, color: kTextMute),
            ),
            validator: (_) => _rowNeedsProduct(row)
                ? 'Pick a product from the list (New Products)'
                : null,
            onChanged: (v) {
              setState(() {
                row.itemController.text = v;
                final linked = row.product;
                if (linked != null && linked.productName != v) {
                  row.product = null; // edited away from the picked product
                }
              });
            },
          );
        },
      );
    });
  }

  /// Available quantity shown right next to the chosen product.
  Widget _stockLine(_ItemRow row) {
    final p = row.product!;
    final status = NewProductService.stockStatus(p);
    final color = status == NewProductService.stockOutOfStock
        ? kRed
        : status == NewProductService.stockLow
        ? const Color(0xFFF59E0B)
        : const Color(0xFF00B894);
    final over = row.qty > p.quantity;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Stock: ${p.quantity} ${p.unit} · $status',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
          ),
          if (over)
            Text('Qty is more than available stock',
                style: TextStyle(fontSize: 11.5, color: Colors.orange.shade800)),
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
        const SizedBox(height: 12),
        _label('Bank Details'),
        TextFormField(
          controller: _bankDetailsController,
          maxLines: 4,
          textCapitalization: TextCapitalization.characters,
          decoration: _fieldDecoration(hint: 'Bank name, A/C no., IFSC, account holder'),
        ),
      ],
    );
  }
}