// lib/screens/stock/add_stock_item_screen.dart

import 'package:flutter/material.dart';
import 'package:cda_inventory/services/stock_service.dart';

class AddStockItemScreen extends StatefulWidget {
  const AddStockItemScreen({super.key});

  @override
  State<AddStockItemScreen> createState() => _AddStockItemScreenState();
}

class _AddStockItemScreenState extends State<AddStockItemScreen> {
  final _formKey             = GlobalKey<FormState>();
  final _productController   = TextEditingController();
  final _minStockController  = TextEditingController(text: '10');
  final _skuController       = TextEditingController();
  final _locationController  = TextEditingController();

  String _selectedBranch   = 'CDA Admin';
  String _selectedCategory = 'consumable';
  String _selectedUnit     = 'pcs';
  bool   _saving = false;

  static const List<String> _branches   = ['CDA Admin', 'CDA Ops'];
  static const List<String> _categories = ['consumable', 'fixed_asset'];
  static const List<String> _units      = ['pcs', 'box', 'kg', 'litre', 'set', 'pack'];

  static const Color kNavy  = Color(0xFF0A1628);
  static const Color kTeal  = Color(0xFF00D4AA);
  static const Color kCoral = Color(0xFFFF6B6B);

  @override
  void dispose() {
    _productController.dispose();
    _minStockController.dispose();
    _skuController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await StockService.createItem(
        productName: _productController.text.trim(),
        branch:      _selectedBranch,
        category:    _selectedCategory,
        minStock:    int.parse(_minStockController.text.trim()),
        sku:         _skuController.text.trim(),
        unit:        _selectedUnit,
        location:    _locationController.text.trim(),
      );
      if (!mounted) return;
      _showSnack('Item added to catalog!');
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        final raw = e.toString();
        final msg = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
        _showSnack(msg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
      duration: Duration(seconds: isError ? 4 : 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: const Text('Add New Item',
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
                    colors: [kNavy, Color(0xFF162944)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(children: [
                  Icon(Icons.add_box_rounded, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Register New Product',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 17)),
                        Text('Adds to the catalog with zero starting quantity',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 20),
              _sectionLabel('PRODUCT INFO'),
              const SizedBox(height: 10),

              _card(children: [
                _field(
                  controller: _productController,
                  label: 'Product Name',
                  icon: Icons.inventory_2_rounded,
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
                  onChanged: (v) => setState(() => _selectedBranch = v!),
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
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? kNavy : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(children: [
                            Icon(icon,
                                size: 18,
                                color: selected ? Colors.white : Colors.grey),
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
              _sectionLabel('STOCK SETTINGS'),
              const SizedBox(height: 10),

              _card(children: [
                Row(children: [
                  Expanded(
                    child: _field(
                      controller: _minStockController,
                      label: 'Minimum Stock',
                      icon: Icons.rule_rounded,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final n = int.tryParse(v.trim());
                        if (n == null || n < 0) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dropdownField(
                      label: 'Unit',
                      icon: Icons.straighten_rounded,
                      value: _selectedUnit,
                      items: _units,
                      onChanged: (v) => setState(() => _selectedUnit = v!),
                    ),
                  ),
                ]),
              ]),

              const SizedBox(height: 20),
              _sectionLabel('ADDITIONAL DETAILS (OPTIONAL)'),
              const SizedBox(height: 10),

              _card(children: [
                _field(
                    controller: _skuController,
                    label: 'SKU / Code',
                    icon: Icons.qr_code_rounded),
                const SizedBox(height: 14),
                _field(
                    controller: _locationController,
                    label: 'Shelf / Location',
                    icon: Icons.place_outlined),
              ]),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTeal,
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
                      Text('Add Item',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
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
        crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF0A1628)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade400),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kTeal, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kCoral)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kCoral, width: 1.5)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: validator,
    );
  }

  Widget _dropdownField({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF0A1628)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade400),
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
        fillColor: Colors.grey.shade50,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
}