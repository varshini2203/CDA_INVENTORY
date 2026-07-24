import 'package:flutter/material.dart';
import 'package:cda_inventory/services/stock_service.dart';

class StockInScreen extends StatefulWidget {
  final String? initialProductName;
  final String? initialBranch;
  final String? initialCategory;

  const StockInScreen({
    super.key,
    this.initialProductName,
    this.initialBranch,
    this.initialCategory,
  });

  @override
  State<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends State<StockInScreen> {
  final _formKey           = GlobalKey<FormState>();
  final _productController  = TextEditingController();
  final _quantityController = TextEditingController();
  final _personController   = TextEditingController();
  final _remarksController  = TextEditingController();

  String    _selectedBranch   = 'CDA Admin';
  String    _selectedCategory = 'consumable';
  DateTime? _selectedDate;
  bool      _saving = false;
  bool get _isProductLocked => widget.initialProductName != null;

  static const List<String> _branches   = ['CDA Admin', 'CDA Ops'];
  static const List<String> _categories = ['consumable', 'fixed_asset'];

  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);

  @override
  void initState() {
    super.initState();
    if (widget.initialProductName != null) {
      _productController.text = widget.initialProductName!;
    }
    if (widget.initialBranch != null) {
      _selectedBranch = widget.initialBranch!;
    }
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
  }

  String get _formattedDate {
    if (_selectedDate == null) return '';
    return '${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
          const ColorScheme.light(primary: kNavy, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      _showSnack('Please select a date', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      // StockService.addStockIn writes to Firestore directly — no HTTP call.
      await StockService.addStockIn(
        productName: _productController.text.trim(),
        quantity:    int.parse(_quantityController.text.trim()),
        receivedBy:  _personController.text.trim(),
        branch:      _selectedBranch,
        date:        _formattedDate,
        remarks:     _remarksController.text.trim(),
        category:    _selectedCategory,
      );
      if (!mounted) return;
      _showSnack('Stock IN recorded successfully!');
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
            isError
                ? Icons.error_outline
                : Icons.check_circle_outline,
            color: Colors.white,
            size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor:
      isError ? const Color(0xFFFF6B6B) : const Color(0xFF00B894),
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }

  @override
  void dispose() {
    _productController.dispose();
    _quantityController.dispose();
    _personController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: const Text('Stock IN',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header banner ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00B894), Color(0xFF00D4AA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(children: [
                  Icon(Icons.arrow_downward_rounded,
                      color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Stock',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17)),
                      Text('Record incoming inventory',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ]),
              ),

              const SizedBox(height: 20),
              _sectionLabel('PRODUCT DETAILS'),
              const SizedBox(height: 10),

              _card(children: [
                _field(
                  controller: _productController,
                  label: 'Product Name',
                  icon: Icons.inventory_2_rounded,
                  enabled: !_isProductLocked,
                  capitalization: TextCapitalization.words,
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _field(
                  controller: _quantityController,
                  label: 'Quantity',
                  icon: Icons.add_circle_outline_rounded,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final n = int.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Enter a valid quantity';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                const Text('Category',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey)),
                const SizedBox(height: 8),
                Row(children: _categories.map((cat) {
                  final selected = _selectedCategory == cat;
                  final label =
                  cat == 'consumable' ? 'Consumable' : 'Fixed Asset';
                  final icon = cat == 'consumable'
                      ? Icons.category_rounded
                      : Icons.business_center_rounded;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: _isProductLocked
                            ? null
                            : () => setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding:
                          const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? kNavy
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(children: [
                            Icon(icon,
                                size: 18,
                                color: selected
                                    ? Colors.white
                                    : Colors.grey),
                            const SizedBox(height: 4),
                            Text(label,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : Colors.grey)),
                          ]),
                        ),
                      ),
                    ),
                  );
                }).toList()),
              ]),

              const SizedBox(height: 20),
              _sectionLabel('RECEIPT INFO'),
              const SizedBox(height: 10),

              _card(children: [
                _field(
                  controller: _personController,
                  label: 'Received By',
                  icon: Icons.person_rounded,
                  capitalization: TextCapitalization.words,
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                _dropdownField(
                  label: 'Branch',
                  icon: Icons.store_rounded,
                  value: _selectedBranch,
                  items: _branches,
                  enabled: !_isProductLocked,
                  onChanged: (v) =>
                      setState(() => _selectedBranch = v!),
                ),
                const SizedBox(height: 14),
                _datePicker(),
              ]),

              const SizedBox(height: 20),
              _sectionLabel('REMARKS (OPTIONAL)'),
              const SizedBox(height: 10),

              _card(children: [
                TextFormField(
                  controller: _remarksController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add any notes or remarks…',
                    hintStyle: TextStyle(
                        color: Colors.grey.shade400, fontSize: 14),
                    border: InputBorder.none,
                  ),
                ),
              ]),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B894),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Save Stock IN',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reusable form widgets ─────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(text,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 1.4));

  Widget _card({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2))
      ],
    ),
    child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children),
  );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF0A1628)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
        TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon:
        Icon(icon, size: 20, color: Colors.grey.shade400),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kTeal, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            const BorderSide(color: Color(0xFFFF6B6B))),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Color(0xFFFF6B6B), width: 1.5)),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
      ),
      validator: validator,
    );
  }

  Widget _dropdownField({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    bool enabled = true,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: enabled ? onChanged : null,
      style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF0A1628)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
        TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon:
        Icon(icon, size: 20, color: Colors.grey.shade400),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kTeal, width: 1.5)),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
      ),
      dropdownColor: Colors.white,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kNavy),
      items: items
          .map((b) => DropdownMenuItem(
          value: b,
          child: Text(b,
              style: const TextStyle(
                  color: kNavy, fontWeight: FontWeight.w500))))
          .toList(),
    );
  }

  Widget _datePicker() {
    final selected = _selectedDate != null;
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kTeal : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded,
              size: 20,
              color: selected ? kTeal : Colors.grey.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              selected ? _formattedDate : 'Select Date',
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected
                    ? FontWeight.w500
                    : FontWeight.w400,
                color: selected
                    ? const Color(0xFF0A1628)
                    : Colors.grey.shade500,
              ),
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: Colors.grey.shade400),
        ]),
      ),
    );
  }
}