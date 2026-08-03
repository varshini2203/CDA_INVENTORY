// lib/screens/invoices/add_invoice_screen.dart
//
// "New Sale" invoice builder — a Vyapar-style itemized invoice form
// (customer search, invoice no/date, an editable item table with Add Row,
// terms & conditions, shipping, round-off and a live total) reworked to
// match this app's own navy/teal design language instead of copying the
// reference app's white/blue theme.

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:cda_inventory/models/invoice.dart';
import 'package:cda_inventory/models/invoice_line_item.dart';
import 'package:cda_inventory/models/customer_details.dart';
import 'package:cda_inventory/models/product.dart';
import 'package:cda_inventory/services/invoice_service.dart';
import 'package:cda_inventory/services/invoice_pdf_service.dart';
import 'package:cda_inventory/services/product_service.dart';
import 'package:cda_inventory/widgets/reports/branch_filter_bar.dart';

class AddInvoiceScreen extends StatefulWidget {
  final Invoice? invoiceToEdit;

  const AddInvoiceScreen({super.key, this.invoiceToEdit});

  @override
  State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

// ── One editable row in the item table ────────────────────────────────────
class _ItemRow {
  final String id;
  final TextEditingController itemController = TextEditingController();
  final TextEditingController serialController = TextEditingController();
  final TextEditingController descController = TextEditingController();
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

  bool get isEmpty =>
      itemController.text.trim().isEmpty && qty == 0 && price == 0;

  InvoiceLineItem toLineItem() => InvoiceLineItem(
    id: id,
    description: itemController.text.trim(),
    hsnCode: serialController.text.trim().isEmpty
        ? null
        : serialController.text.trim(),
    quantity: qty.round(),
    unit: unit,
    unitPrice: price,
    discountPercent: discPercent,
    taxPercent: taxPercent,
  );

  void dispose() {
    itemController.dispose();
    serialController.dispose();
    descController.dispose();
    qtyController.dispose();
    priceController.dispose();
    discController.dispose();
  }
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final InvoiceService _invoiceService = InvoiceService();

  final _invoiceNoController = TextEditingController();
  final _phoneController = TextEditingController();
  final _shippingController = TextEditingController(text: '0');
  final _termsNotesController =
  TextEditingController(text: 'Thanks for doing business with us!');
  final _descriptionController = TextEditingController();
  DateTime _invoiceDate = DateTime.now();

  String _customerName = '';
  List<CustomerDetails> _customerSuggestions = [];
  List<Product> _productSuggestions = [];

  String _paymentMode = 'Credit'; // 'Credit' | 'Cash'
  // Which branch this invoice belongs to. Previously there was no field for
  // this at all, so every new invoice silently saved branch: null — which
  // is why filtering Reports by "CDA Admin" or "CDA Ops" always showed 0
  // invoices even though "All Branches" showed the real count.
  String _selectedBranch = kBranch1;
  String _stateOfSupply = 'Tamil Nadu';
  String _termsTitle = 'Sale Invoice';
  bool _roundOffEnabled = true;
  bool _showDescriptionField = false;

  final List<_ItemRow> _rows = [];
  int _rowSeq = 0;

  bool _isSaving = false;
  bool get _isEditMode => widget.invoiceToEdit != null;

  // Invoice numbers are auto-generated per new invoice (sequential, based on
  // the highest existing number) so the field is locked while that's in
  // progress and stays locked afterwards — unless generation fails, in
  // which case we fall back to letting the user type one in manually.
  bool _invoiceNoAutoGenerating = false;
  bool _invoiceNoAutoFailed = false;

  static const List<String> _termsTitles = [
    'Sale Invoice',
    'Quotation',
    'Proforma Invoice',
    'Estimate',
  ];

  static const List<String> _units = [
    'NONE', 'PCS', 'BOX', 'KG', 'GM', 'LITRE', 'ML', 'DOZEN', 'PACK', 'METER', 'SET',
  ];

  static const List<String> _indianStates = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
    'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim',
    'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand',
    'West Bengal', 'Delhi', 'Jammu and Kashmir', 'Ladakh', 'Puducherry',
    'Chandigarh', 'Andaman and Nicobar Islands',
  ];

  static const List<double> _taxRates = [0, 5, 12, 18, 28];

  // ── Design tokens (matches the rest of the app's screens) ───────────────
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
      final inv = widget.invoiceToEdit!;
      _invoiceNoController.text = inv.invoiceNo;
      _customerName = inv.customer?.name ?? inv.vendorName;
      _phoneController.text = inv.customer?.phone ?? '';
      _stateOfSupply = inv.customer?.placeOfSupply ?? 'Tamil Nadu';
      _paymentMode = inv.paymentMode;
      _selectedBranch = normalizeBranch(inv.branch) ?? kBranch1;
      _termsTitle = inv.termsTitle;
      _termsNotesController.text = inv.termsNotes ?? _termsNotesController.text;
      _shippingController.text = inv.shipping.toStringAsFixed(2);
      _roundOffEnabled = inv.roundOffEnabled;
      _invoiceDate = inv.purchaseDateTime ?? DateTime.now();

      if (inv.usesLineItems) {
        for (final li in inv.lineItems) {
          final row = _ItemRow(id: li.id, unit: li.unit, taxPercent: li.taxPercent);
          row.itemController.text = li.description;
          row.serialController.text = li.hsnCode ?? '';
          row.qtyController.text = li.quantity.toString();
          row.priceController.text = li.unitPrice.toStringAsFixed(2);
          row.discController.text = li.discountPercent.toStringAsFixed(0);
          _rows.add(row);
        }
      } else if (inv.productName.isNotEmpty) {
        final row = _ItemRow(id: 'row_${_rowSeq++}');
        row.itemController.text = inv.productName;
        row.qtyController.text = inv.quantity.toString();
        row.priceController.text = inv.amount.toStringAsFixed(2);
        _rows.add(row);
      }
    }
    while (_rows.length < 2) {
      _rows.add(_ItemRow(id: 'row_${_rowSeq++}'));
    }
    if (!_isEditMode) _invoiceNoAutoGenerating = true;
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    try {
      final customers = await _invoiceService.fetchCustomerSuggestions();
      final products = await ProductService.getProducts();
      if (!_isEditMode) {
        final nextNo = await _invoiceService.suggestNextInvoiceNumber();
        if (mounted) _invoiceNoController.text = nextNo;
      }
      if (mounted) {
        setState(() {
          _customerSuggestions = customers;
          _productSuggestions = products;
          _invoiceNoAutoGenerating = false;
        });
      }
    } catch (_) {
      // Auto-generation failed (e.g. offline) — fall back to manual entry
      // for this field instead of leaving it stuck and empty.
      if (mounted) {
        setState(() {
          _invoiceNoAutoGenerating = false;
          _invoiceNoAutoFailed = true;
        });
      }
    }
  }

  Future<void> _regenerateInvoiceNo() async {
    setState(() {
      _invoiceNoAutoGenerating = true;
      _invoiceNoAutoFailed = false;
    });
    try {
      final nextNo = await _invoiceService.suggestNextInvoiceNumber(forceRefresh: true);
      if (mounted) {
        setState(() {
          _invoiceNoController.text = nextNo;
          _invoiceNoAutoGenerating = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _invoiceNoAutoGenerating = false;
          _invoiceNoAutoFailed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _invoiceNoController.dispose();
    _phoneController.dispose();
    _shippingController.dispose();
    _termsNotesController.dispose();
    _descriptionController.dispose();
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

  Future<void> _pickInvoiceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: kNavy, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _invoiceDate = picked);
  }

  Invoice _buildInvoiceFromForm() {
    final lineItems = _validRows.map((r) => r.toLineItem()).toList();
    return Invoice(
      id: widget.invoiceToEdit?.id,
      invoiceNo: _invoiceNoController.text.trim(),
      vendorName: _customerName.trim(),
      purchaseDate:
      '${_invoiceDate.day.toString().padLeft(2, '0')}-${_invoiceDate.month.toString().padLeft(2, '0')}-${_invoiceDate.year}',
      status: _isEditMode ? widget.invoiceToEdit!.status : 'Pending',
      lineItems: lineItems,
      customer: CustomerDetails(
        name: _customerName.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        placeOfSupply: _stateOfSupply,
      ),
      gstEnabled: false,
      payments: _isEditMode ? widget.invoiceToEdit!.payments : const [],
      addedBy: widget.invoiceToEdit?.addedBy,
      addedAt: _isEditMode ? widget.invoiceToEdit!.addedAt : DateTime.now(),
      branch: _selectedBranch,
      paymentMode: _paymentMode,
      shipping: _shipping,
      roundOffEnabled: _roundOffEnabled,
      termsTitle: _termsTitle,
      termsNotes: _termsNotesController.text.trim().isEmpty
          ? null
          : _termsNotesController.text.trim(),
    );
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerName.trim().isEmpty) {
      _showSnack('Customer name is required', isError: true);
      return;
    }
    if (_validRows.isEmpty) {
      _showSnack('Add at least one item', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final invoiceNo = _invoiceNoController.text.trim();
      final noChanged = !_isEditMode || invoiceNo != widget.invoiceToEdit!.invoiceNo;
      if (noChanged) {
        final exists = await _invoiceService.invoiceNumberExists(
          invoiceNo,
          excludeId: widget.invoiceToEdit?.id,
        );
        if (exists) {
          if (mounted) {
            setState(() => _isSaving = false);
            _showSnack('Invoice number "$invoiceNo" already exists', isError: true);
          }
          return;
        }
      }

      final invoice = _buildInvoiceFromForm();
      if (_isEditMode) {
        await _invoiceService.updateInvoice(invoice);
      } else {
        await _invoiceService.createInvoice(invoice);
      }

      if (mounted) {
        _showSnack(_isEditMode ? 'Invoice updated successfully' : 'Invoice created successfully');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _printInvoice() async {
    if (_validRows.isEmpty) {
      _showSnack('Add at least one item before printing', isError: true);
      return;
    }
    final invoice = _buildInvoiceFromForm();
    await Printing.layoutPdf(onLayout: (format) => InvoicePdfService.generate(invoice));
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white, size: 18),
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
          _isEditMode ? 'Edit Invoice' : 'New Sale',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          children: [
            _paymentModeToggle(),
            const SizedBox(height: 12),
            _branchSelector(),
            const SizedBox(height: 20),

            _sectionLabel('CUSTOMER'),
            const SizedBox(height: 10),
            _card(children: [
              _customerAutocomplete(accentColor),
              const SizedBox(height: 14),
              _field(
                controller: _phoneController,
                label: 'Phone No.',
                hint: 'e.g. 98765 43210',
                icon: Icons.call_outlined,
                keyboardType: TextInputType.phone,
                accentColor: accentColor,
              ),
            ]),

            const SizedBox(height: 20),
            _sectionLabel('INVOICE DETAILS'),
            const SizedBox(height: 10),
            _card(children: [
              _field(
                controller: _invoiceNoController,
                label: _isEditMode ? 'Invoice Number' : 'Invoice Number (auto-generated)',
                hint: _invoiceNoAutoGenerating ? 'Generating…' : 'e.g. INV-230726-4F2K',
                icon: Icons.tag_rounded,
                accentColor: accentColor,
                readOnly: !_isEditMode && !_invoiceNoAutoFailed,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                suffixIcon: _isEditMode
                    ? null
                    : (_invoiceNoAutoGenerating
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
                  onPressed: _regenerateInvoiceNo,
                )),
              ),
              if (!_isEditMode && _invoiceNoAutoFailed)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Could not auto-generate a number — enter one manually.',
                    style: TextStyle(fontSize: 12, color: kCoral),
                  ),
                ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _pickInvoiceDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor, width: 1.5),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_rounded, size: 18, color: accentColor),
                    const SizedBox(width: 10),
                    Text(
                      'Invoice Date: ${_invoiceDate.day.toString().padLeft(2, '0')}-${_invoiceDate.month.toString().padLeft(2, '0')}-${_invoiceDate.year}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNavy),
                    ),
                    const Spacer(),
                    Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade400),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              _stateDropdown(accentColor),
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
              label: const Text('ADD ROW'),
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
            _sectionLabel('TERMS & CONDITIONS'),
            const SizedBox(height: 10),
            _card(children: [
              _termsTitleDropdown(accentColor),
              const SizedBox(height: 14),
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
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                ),
              ),
              const SizedBox(height: 14),
              _attachmentButtons(accentColor),
              if (_showDescriptionField) ...[
                const SizedBox(height: 14),
                _field(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Add extra invoice description…',
                  icon: Icons.notes_rounded,
                  accentColor: accentColor,
                ),
              ],
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

  // ── Payment mode: Credit / Cash toggle (mirrors the reference screen) ───
  // Lets the user tag this invoice as CDA Admin or CDA Ops. Without this,
  // every invoice saved branch: null, so Reports' branch filter (which
  // matches on this exact field) could never find it under either branch.
  Widget _branchSelector() {
    const options = [kBranch1, kBranch2];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Icon(Icons.location_city_rounded, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text('Branch',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
        const Spacer(),
        ...options.map((b) {
          final isSelected = _selectedBranch == b;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedBranch = b),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? kTeal : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? kTeal : Colors.grey.shade300),
                ),
                child: Text(
                  branchDisplayName(b),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          );
        }),
      ]),
    );
  }

  Widget _paymentModeToggle() {
    final isCash = _paymentMode == 'Cash';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kNavy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        const Text('Sale',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        const Spacer(),
        Text('Credit',
            style: TextStyle(
              color: isCash ? Colors.white38 : kTeal,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            )),
        Switch(
          value: isCash,
          activeColor: kTeal,
          inactiveThumbColor: kTeal,
          inactiveTrackColor: kTeal.withOpacity(0.35),
          onChanged: (v) => setState(() => _paymentMode = v ? 'Cash' : 'Credit'),
        ),
        Text('Cash',
            style: TextStyle(
              color: isCash ? kTeal : Colors.white38,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            )),
      ]),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
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
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      readOnly: readOnly,
      onChanged: (v) {
        setState(() {});
        onChanged?.call(v);
      },
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: readOnly ? Colors.grey.shade600 : kNavy,
      ),
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
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kCoral, width: 1.5)),
        filled: true,
        fillColor: readOnly ? Colors.grey.shade100 : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: validator,
    );
  }

  Widget _customerAutocomplete(Color accentColor) {
    return Autocomplete<CustomerDetails>(
      initialValue: TextEditingValue(text: _customerName),
      displayStringForOption: (c) => c.name,
      optionsBuilder: (value) {
        if (value.text.trim().isEmpty) return const Iterable<CustomerDetails>.empty();
        final q = value.text.toLowerCase();
        return _customerSuggestions.where(
              (c) => c.name.toLowerCase().contains(q) || (c.phone ?? '').contains(q),
        );
      },
      onSelected: (selection) {
        setState(() {
          _customerName = selection.name;
          _phoneController.text = selection.phone ?? '';
          _stateOfSupply = selection.placeOfSupply;
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
          onChanged: (v) => _customerName = v,
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

  Widget _stateDropdown(Color accentColor) {
    return DropdownButtonFormField<String>(
      value: _stateOfSupply,
      isExpanded: true,
      dropdownColor: Colors.white,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade400),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kNavy),
      decoration: InputDecoration(
        labelText: 'State of Supply',
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: Icon(Icons.map_outlined, size: 20, color: Colors.grey.shade400),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor, width: 1.5)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      items: _indianStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: (v) => setState(() => _stateOfSupply = v ?? _stateOfSupply),
    );
  }

  // ── One item row card: item name + serial/HSN + qty/unit/price/disc/tax ─
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
          Expanded(flex: 3, child: _smallField(controller: row.serialController, label: 'Serial/HSN No.', accentColor: accentColor)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _unitDropdown(row, accentColor)),
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
        // Keep Autocomplete's internal controller in sync with the row's.
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
            labelText: 'Item',
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

  Widget _termsTitleDropdown(Color accentColor) {
    return DropdownButtonFormField<String>(
      value: _termsTitle,
      isExpanded: true,
      dropdownColor: Colors.white,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade400),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kNavy),
      decoration: InputDecoration(
        labelText: 'Title',
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor, width: 1.5)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: _termsTitles.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
      onChanged: (v) => setState(() => _termsTitle = v ?? _termsTitle),
    );
  }

  Widget _attachmentButtons(Color accentColor) {
    Widget btn(IconData icon, String label, VoidCallback onTap, {bool active = false}) {
      return Expanded(
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 16, color: active ? accentColor : Colors.grey.shade400),
          label: Text(label, style: TextStyle(fontSize: 11, color: active ? accentColor : Colors.grey.shade400)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: active ? accentColor : Colors.grey.shade300),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }

    return Row(children: [
      btn(Icons.description_outlined, 'DESCRIPTION', () => setState(() => _showDescriptionField = !_showDescriptionField), active: _showDescriptionField),
      const SizedBox(width: 8),
      btn(Icons.image_outlined, 'IMAGE', () => _showSnack('Attachments coming soon')),
      const SizedBox(width: 8),
      btn(Icons.insert_drive_file_outlined, 'DOCUMENT', () => _showSnack('Attachments coming soon')),
    ]);
  }

  Widget _totalPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Icon(Icons.calculate_rounded, color: kTeal, size: 22),
        const SizedBox(width: 12),
        const Text('Total', style: TextStyle(color: Colors.white70, fontSize: 14)),
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
              onPressed: _isSaving ? null : _printInvoice,
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
              onPressed: _isSaving ? null : _saveInvoice,
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
                  Text(_isEditMode ? 'Update Invoice' : 'Save Invoice',
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