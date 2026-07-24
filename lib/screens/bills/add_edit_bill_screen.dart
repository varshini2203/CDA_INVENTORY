import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cda_inventory/services/bills_service.dart';
import 'package:cda_inventory/models/bill_model.dart';
import 'package:cda_inventory/constants/bill_categories.dart';

// ── Design tokens (matches Invoice screens) ─────────────────────────────────
const Color kNavy = Color(0xFF0A1628);
const Color kTeal = Color(0xFF00D4AA);
const Color kCoral = Color(0xFFFF6B6B);
const Color kAmber = Color(0xFFFFB800);
const Color kSurface = Color(0xFFF0F4F8);
const Color kGreen = Color(0xFF00B894);
const Color kPurple = Color(0xFF6C63FF);

/// Add a new bill (pass `imageBytes`) or edit an existing one (pass
/// `existingBill`). Uses raw image bytes (Uint8List) instead of dart:io
/// File so the same screen works on Web, Android, iOS, and Desktop.
///
/// Saves directly via [BillsService] and pops with the resulting
/// [BillModel] so the caller (BillsScreen / BillDetailScreen) can update
/// its own local list without needing a shared Provider.
class AddEditBillScreen extends StatefulWidget {
  final Uint8List? imageBytes;
  final BillModel? existingBill;

  const AddEditBillScreen({super.key, this.imageBytes, this.existingBill})
      : assert(imageBytes != null || existingBill != null,
  'Provide either a new image or an existing bill to edit');

  @override
  State<AddEditBillScreen> createState() => _AddEditBillScreenState();
}

class _AddEditBillScreenState extends State<AddEditBillScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _vendorController;
  late TextEditingController _billNumberController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  late DateTime _billDate;
  late String _category;

  /// Non-null only when the user picks a NEW image (either creating a
  /// bill, or replacing the image while editing). When editing and this
  /// stays null, the existing image on the bill is kept untouched.
  Uint8List? _newImageBytes;
  bool _isSaving = false;
  String _errorMessage = '';

  bool get isEditing => widget.existingBill != null;

  Color get _accentColor => isEditing ? kAmber : kTeal;

  @override
  void initState() {
    super.initState();
    final bill = widget.existingBill;
    _vendorController = TextEditingController(text: bill?.vendorName ?? '');
    _billNumberController = TextEditingController(text: bill?.billNumber ?? '');
    _amountController =
        TextEditingController(text: bill != null ? bill.amount.toString() : '');
    _notesController = TextEditingController(text: bill?.notes ?? '');
    _billDate = bill?.billDate ?? DateTime.now();
    _category = bill?.category ?? billCategories.first;
    _newImageBytes = widget.imageBytes;
  }

  @override
  void dispose() {
    _vendorController.dispose();
    _billNumberController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _replaceImage() async {
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
              leading: Icon(Icons.camera_alt_rounded, color: _accentColor),
              title: const Text('Re-scan with Camera',
                  style: TextStyle(color: kNavy, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: _accentColor),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: kNavy, fontWeight: FontWeight.w600)),
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
    setState(() => _newImageBytes = bytes);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: _accentColor, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _billDate = picked);
  }

  Future<void> _save() async {
    // Synchronous guard against double-submit: the button below only
    // disables itself once Flutter rebuilds with _isSaving == true, which
    // happens *after* this function is entered. Two rapid taps (e.g. an
    // accidental double-click) can both slip past that before the first
    // rebuild lands, each firing BillsService.addBill() and creating a
    // duplicate document. Setting the plain field immediately — before
    // validation, before any async gap, and without waiting on setState —
    // closes that window completely.
    if (_isSaving) return;
    _isSaving = true;

    if (!_formKey.currentState!.validate()) {
      _isSaving = false;
      if (mounted) setState(() {});
      return;
    }

    if (!isEditing && _newImageBytes == null) {
      _isSaving = false;
      if (mounted) setState(() {});
      _showSnack('Please attach a bill image first', isError: true);
      return;
    }

    setState(() {
      _errorMessage = '';
    });

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    try {
      BillModel savedBill;

      if (isEditing) {
        savedBill = await BillsService.updateBill(
          bill: widget.existingBill!,
          newImageBytes: _newImageBytes,
          vendorName: _vendorController.text.trim(),
          billNumber: _billNumberController.text.trim(),
          amount: amount,
          billDate: _billDate,
          category: _category,
          notes: _notesController.text.trim(),
        );
      } else {
        savedBill = await BillsService.addBill(
          imageBytes: _newImageBytes!,
          vendorName: _vendorController.text.trim(),
          billNumber: _billNumberController.text.trim(),
          amount: amount,
          billDate: _billDate,
          category: _category,
          notes: _notesController.text.trim(),
        );
      }

      if (!mounted) return;
      // Return the saved bill so BillsScreen / BillDetailScreen can
      // update their local lists immediately.
      Navigator.pop(context, savedBill);
      _showSnack(isEditing ? 'Bill updated' : 'Bill saved');
    } catch (e) {
      if (!mounted) return;
      debugPrint('Bill save error: $e');
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save bill. Please try again.';
      });
      _showSnack(_errorMessage, isError: true);
    }
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
        backgroundColor: isError ? kCoral : kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isEditing ? 'Edit Bill' : 'New Bill',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildImagePreview(),
            const SizedBox(height: 20),
            _sectionLabel('BILL DETAILS'),
            const SizedBox(height: 10),
            _card(children: [
              _buildTextField(_vendorController, 'Vendor / Supplier Name',
                  icon: Icons.storefront_rounded, validator: true),
              const SizedBox(height: 14),
              _buildTextField(_billNumberController, 'Bill / Invoice Number',
                  icon: Icons.tag_rounded, validator: true),
              const SizedBox(height: 14),
              _buildTextField(_amountController, 'Amount (₹)',
                  icon: Icons.currency_rupee_rounded,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: true),
            ]),
            const SizedBox(height: 20),
            _sectionLabel('CATEGORY & DATE'),
            const SizedBox(height: 10),
            _card(children: [
              _buildDateField(),
              const SizedBox(height: 14),
              _buildCategoryDropdown(),
            ]),
            const SizedBox(height: 20),
            _sectionLabel('NOTES'),
            const SizedBox(height: 10),
            _card(children: [
              _buildTextField(_notesController, 'Notes (optional)',
                  icon: Icons.notes_rounded, maxLines: 3),
            ]),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isEditing ? Icons.save_rounded : Icons.add_rounded,
                        size: 20),
                    const SizedBox(width: 8),
                    Text(isEditing ? 'Update Bill' : 'Save Bill',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
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
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildImagePreview() {
    return GestureDetector(
      onTap: _replaceImage,
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_newImageBytes != null)
            // Image.memory works on Web + mobile + desktop, unlike
            // Image.file which throws on Flutter Web.
              Image.memory(_newImageBytes!, fit: BoxFit.cover)
            else if (widget.existingBill != null &&
                widget.existingBill!.imageBase64.isNotEmpty)
              Image.memory(
                base64Decode(widget.existingBill!.imageBase64),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                    child: Icon(Icons.broken_image_rounded,
                        size: 48, color: Colors.grey.shade300)),
              )
            else
              Center(
                  child: Icon(Icons.receipt_long_rounded,
                      size: 48, color: Colors.grey.shade300)),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accentColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: _accentColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label, {
        IconData? icon,
        TextInputType? keyboardType,
        int maxLines = 1,
        bool validator = false,
      }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(
          color: kNavy, fontSize: 15, fontWeight: FontWeight.w500),
      validator: validator
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: Colors.grey.shade400)
            : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accentColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kCoral),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kCoral, width: 1.5),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 18, color: Colors.grey.shade400),
                const SizedBox(width: 10),
                Text(
                    'Bill Date: ${_billDate.day}/${_billDate.month}/${_billDate.year}',
                    style: const TextStyle(
                        color: kNavy,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _category,
          isExpanded: true,
          dropdownColor: Colors.white,
          iconEnabledColor: Colors.grey.shade400,
          style: const TextStyle(
              color: kNavy, fontSize: 14, fontWeight: FontWeight.w500),
          items: billCategories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _category = v!),
        ),
      ),
    );
  }
}