// lib/screens/stock/stock_transfer_screen.dart

import 'package:flutter/material.dart';
import 'package:cda_inventory/models/stock.dart';
import 'package:cda_inventory/services/stock_service.dart';

class StockTransferScreen extends StatefulWidget {
  final StockItem item;

  const StockTransferScreen({super.key, required this.item});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  final _formKey             = GlobalKey<FormState>();
  final _quantityController  = TextEditingController();
  final _personController    = TextEditingController();
  final _remarksController   = TextEditingController();

  late String _toBranch;
  bool _saving = false;

  // Keep this list in sync with the branches used across the rest of the app.
  static const List<String> _allBranches = ['CDA Admin', 'CDA Ops'];

  static const Color kNavy   = Color(0xFF0A1628);
  static const Color kTeal   = Color(0xFF00D4AA);
  static const Color kCoral  = Color(0xFFFF6B6B);
  static const Color kPurple = Color(0xFF6C63FF);

  List<String> get _destinationOptions =>
      _allBranches.where((b) => b != widget.item.branch).toList();

  @override
  void initState() {
    super.initState();
    _toBranch = _destinationOptions.isNotEmpty
        ? _destinationOptions.first
        : widget.item.branch;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _personController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_toBranch == widget.item.branch) {
      _showSnack('Choose a different destination branch', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await StockService.transferStock(
        productName:   widget.item.productName,
        fromBranch:    widget.item.branch,
        toBranch:      _toBranch,
        quantity:      int.parse(_quantityController.text.trim()),
        transferredBy: _personController.text.trim(),
        remarks:       _remarksController.text.trim(),
      );
      if (!mounted) return;
      _showSnack('Stock transferred successfully!');
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
    final maxQty = widget.item.quantity;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: const Text('Transfer Stock',
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
                    colors: [kPurple, Color(0xFF8A82FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  const Icon(Icons.swap_horiz_rounded,
                      color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.item.productName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 17),
                            overflow: TextOverflow.ellipsis),
                        Text(
                            'From ${widget.item.branch}  •  Available: $maxQty ${widget.item.unit}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 20),
              _sectionLabel('TRANSFER DETAILS'),
              const SizedBox(height: 10),

              _card(children: [
                if (_destinationOptions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: kCoral.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded,
                          color: kCoral, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            'No other branch available to transfer to.',
                            style: TextStyle(
                                color: Colors.grey.shade700, fontSize: 12)),
                      ),
                    ]),
                  )
                else
                  _dropdownField(
                    label: 'Destination Branch',
                    icon: Icons.store_rounded,
                    value: _toBranch,
                    items: _destinationOptions,
                    onChanged: (v) => setState(() => _toBranch = v!),
                  ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0A1628)),
                  decoration:
                  _inputDecoration('Quantity to Transfer', Icons.numbers_rounded),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final n = int.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Enter a valid quantity';
                    if (n > maxQty) return 'Cannot exceed available stock ($maxQty)';
                    return null;
                  },
                ),
              ]),

              const SizedBox(height: 20),
              _sectionLabel('TRANSFER INFO'),
              const SizedBox(height: 10),

              _card(children: [
                TextFormField(
                  controller: _personController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0A1628)),
                  decoration: _inputDecoration('Transferred By', Icons.person_rounded),
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
                ),
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
                    hintStyle:
                    TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    border: InputBorder.none,
                  ),
                ),
              ]),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed:
                  (_saving || _destinationOptions.isEmpty) ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPurple,
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
                      Icon(Icons.swap_horiz_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Confirm Transfer',
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

  InputDecoration _inputDecoration(String label, IconData icon) =>
      InputDecoration(
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
            borderSide: const BorderSide(color: kPurple, width: 1.5)),
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
      );

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
      decoration: _inputDecoration(label, icon),
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