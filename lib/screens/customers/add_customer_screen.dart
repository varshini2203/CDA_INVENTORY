// lib/screens/customers/add_customer_screen.dart

import 'package:flutter/material.dart';
import 'package:cda_inventory/models/customer_details.dart';
import 'package:cda_inventory/services/customer_service.dart';

class AddCustomerScreen extends StatefulWidget {
  final CustomerDetails? customerToEdit;
  const AddCustomerScreen({super.key, this.customerToEdit});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kCoral = Color(0xFFFF6B6B);
  static const Color kAmber = Color(0xFFFFB800);
  static const Color kSurface = Color(0xFFF0F4F8);

  static const List<String> _indianStates = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
    'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim',
    'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand',
    'West Bengal', 'Delhi', 'Jammu and Kashmir', 'Ladakh', 'Puducherry',
    'Chandigarh', 'Andaman and Nicobar Islands',
  ];

  final _formKey = GlobalKey<FormState>();
  final _service = CustomerService();

  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _emailC = TextEditingController();
  final _gstinC = TextEditingController();
  final _billingC = TextEditingController();
  final _shippingC = TextEditingController();
  String _state = 'Tamil Nadu';
  bool _sameAsBilling = false;
  bool _saving = false;

  bool get _isEdit => widget.customerToEdit != null;
  Color get _accent => _isEdit ? kAmber : kTeal;

  @override
  void initState() {
    super.initState();
    final c = widget.customerToEdit;
    if (c != null) {
      _nameC.text = c.name;
      _phoneC.text = c.phone ?? '';
      _emailC.text = c.email ?? '';
      _gstinC.text = c.gstin ?? '';
      _billingC.text = c.billingAddress ?? '';
      _shippingC.text = c.shippingAddress ?? '';
      _state = _indianStates.contains(c.placeOfSupply) ? c.placeOfSupply : 'Tamil Nadu';
      _sameAsBilling = (c.billingAddress ?? '').isNotEmpty &&
          c.billingAddress == c.shippingAddress;
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    _emailC.dispose();
    _gstinC.dispose();
    _billingC.dispose();
    _shippingC.dispose();
    super.dispose();
  }

  String? _nz(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final name = _nameC.text.trim();
      final phone = _nz(_phoneC);

      final dup = await _service.findExisting(
        name: name,
        phone: phone,
        excludeId: widget.customerToEdit?.id,
      );
      if (dup != null) {
        if (mounted) {
          setState(() => _saving = false);
          _snack('Customer "${dup.name}" already exists with this ${(phone ?? '').isNotEmpty ? 'phone number' : 'name'}', isError: true);
        }
        return;
      }

      final billing = _nz(_billingC);
      final customer = CustomerDetails(
        id: widget.customerToEdit?.id,
        name: name,
        phone: phone,
        email: _nz(_emailC),
        gstin: _nz(_gstinC)?.toUpperCase(),
        billingAddress: billing,
        shippingAddress: _sameAsBilling ? billing : _nz(_shippingC),
        placeOfSupply: _state,
      );

      if (_isEdit) {
        await _service.updateCustomer(customer);
      } else {
        await _service.addCustomer(customer);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Could not save customer: $e', isError: true);
      }
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? kCoral : kNavy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_isEdit ? 'Edit Customer' : 'Add Customer',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _label('BASIC DETAILS'),
            const SizedBox(height: 10),
            _card([
              _field(
                controller: _nameC,
                label: 'Customer Name *',
                hint: 'e.g. Ravi Kumar',
                icon: Icons.person_outline_rounded,
                capitalization: TextCapitalization.words,
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _phoneC,
                label: 'Phone No.',
                hint: 'e.g. 98765 43210',
                icon: Icons.call_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _emailC,
                label: 'Email',
                hint: 'e.g. customer@email.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                      ? null
                      : 'Enter a valid email';
                },
              ),
            ]),
            const SizedBox(height: 20),
            _label('GST & ADDRESS'),
            const SizedBox(height: 10),
            _card([
              _field(
                controller: _gstinC,
                label: 'GSTIN',
                hint: '15-character GST number',
                icon: Icons.badge_outlined,
                capitalization: TextCapitalization.characters,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  return t.length == 15 ? null : 'GSTIN must be 15 characters';
                },
              ),
              const SizedBox(height: 14),
              _stateDropdown(),
              const SizedBox(height: 14),
              _field(
                controller: _billingC,
                label: 'Billing Address',
                hint: 'Street, city, pincode',
                icon: Icons.home_outlined,
                capitalization: TextCapitalization.sentences,
                maxLines: 3,
                onChanged: (v) {
                  if (_sameAsBilling) _shippingC.text = v;
                },
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                value: _sameAsBilling,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: _accent,
                title: const Text('Shipping address same as billing',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kNavy)),
                onChanged: (v) => setState(() {
                  _sameAsBilling = v ?? false;
                  if (_sameAsBilling) _shippingC.text = _billingC.text;
                }),
              ),
              const SizedBox(height: 6),
              _field(
                controller: _shippingC,
                label: 'Shipping Address',
                hint: 'Street, city, pincode',
                icon: Icons.local_shipping_outlined,
                capitalization: TextCapitalization.sentences,
                maxLines: 3,
                readOnly: _sameAsBilling,
              ),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: Text(_isEdit ? 'UPDATE CUSTOMER' : 'SAVE CUSTOMER',
                    style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: kNavy,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Text(
    t,
    style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
        letterSpacing: 1.4),
  );

  Widget _card(List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2)),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  InputDecoration _decoration(String label, String hint, IconData icon,
      {bool readOnly = false}) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 14),
      prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade400),
      border: b(Colors.grey.shade200),
      enabledBorder: b(Colors.grey.shade200),
      focusedBorder: b(_accent, 1.5),
      errorBorder: b(kCoral),
      focusedErrorBorder: b(kCoral, 1.5),
      filled: true,
      fillColor: readOnly ? Colors.grey.shade100 : Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool readOnly = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
      textCapitalization: capitalization,
      readOnly: readOnly,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: readOnly ? Colors.grey.shade600 : kNavy),
      decoration: _decoration(label, hint, icon, readOnly: readOnly),
      validator: validator,
    );
  }

  Widget _stateDropdown() {
    return DropdownButtonFormField<String>(
      value: _state,
      isExpanded: true,
      dropdownColor: Colors.white,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade400),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kNavy),
      decoration: _decoration('State of Supply', '', Icons.map_outlined),
      items: _indianStates
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: (v) => setState(() => _state = v ?? _state),
    );
  }
}