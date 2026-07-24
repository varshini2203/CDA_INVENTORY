// lib/screens/stock/stock_adjust_screen.dart

import 'package:flutter/material.dart';
import 'package:cda_inventory/models/stock.dart';
import 'package:cda_inventory/services/stock_service.dart';

class StockAdjustScreen extends StatefulWidget {
  final StockItem item;

  const StockAdjustScreen({super.key, required this.item});

  @override
  State<StockAdjustScreen> createState() => _StockAdjustScreenState();
}

class _StockAdjustScreenState extends State<StockAdjustScreen> {
  final _formKey             = GlobalKey<FormState>();
  final _newQuantityController = TextEditingController();
  final _adjustedByController  = TextEditingController();

  String _reason = 'Physical count correction';
  bool _saving = false;

  static const List<String> _reasons = [
    'Physical count correction',
    'Damaged / expired',
    'Lost / theft',
    'Data entry correction',
    'Other',
  ];

  static const Color kNavy   = Color(0xFF0A1628);
  static const Color kAmber  = Color(0xFFFFB800);
  static const Color kCoral  = Color(0xFFFF6B6B);
  static const Color kTeal   = Color(0xFF00D4AA);

  @override
  void initState() {
    super.initState();
    _newQuantityController.text = widget.item.quantity.toString();
  }

  @override
  void dispose() {
    _newQuantityController.dispose();
    _adjustedByController.dispose();
    super.dispose();
  }

  int? get _newQuantity => int.tryParse(_newQuantityController.text.trim());
  int get _delta => (_newQuantity ?? widget.item.quantity) - widget.item.quantity;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.item.id == null) return;
    setState(() => _saving = true);
    try {
      await StockService.adjustStock(
        itemId:      widget.item.id!,
        newQuantity: _newQuantity!,
        reason:      _reason,
        adjustedBy:  _adjustedByController.text.trim(),
      );
      if (mounted) {
        _showSnack('Stock adjusted successfully');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString(), isError: true);
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
    ));
  }

  @override
  Widget build(BuildContext context) {
    final delta = _delta;
    final deltaColor = delta == 0
        ? Colors.grey
        : delta > 0
        ? const Color(0xFF00B894)
        : kCoral;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: const Text('Adjust Stock',
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE6A817), kAmber],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  const Icon(Icons.tune_rounded, color: Colors.white, size: 28),
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
                        Text('${widget.item.branch}  •  Current qty: ${widget.item.quantity}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              _card(children: [
                TextFormField(
                  controller: _newQuantityController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDecoration('New Quantity', Icons.numbers_rounded),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 0) return 'Enter a valid quantity';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: deltaColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(
                      delta == 0
                          ? Icons.remove_rounded
                          : delta > 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: deltaColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      delta == 0
                          ? 'No change'
                          : delta > 0
                          ? 'Increase by $delta'
                          : 'Decrease by ${delta.abs()}',
                      style: TextStyle(color: deltaColor, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                Text('Reason', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _reason,
                  isExpanded: true,
                  decoration: _inputDecoration('Reason', Icons.info_outline_rounded),
                  items: _reasons
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => _reason = v ?? _reason),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _adjustedByController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration('Adjusted By', Icons.person_rounded),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ]),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAmber,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Confirm Adjustment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

  Widget _card({required List<Widget> children}) => Container(
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

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
    prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade400),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kAmber, width: 1.5)),
    filled: true,
    fillColor: Colors.grey.shade50,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}