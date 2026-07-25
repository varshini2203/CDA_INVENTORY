// lib/screens/new_products/add_edit_new_product_screen.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cda_inventory/models/new_product.dart';
import 'package:cda_inventory/services/new_product_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  ADD / EDIT NEW PRODUCT SCREEN
//  Same screen/class handles both Add (existing == null) and Edit
//  (existing != null), matching the app's Fixed Assets pattern.
// ═══════════════════════════════════════════════════════════════════════════

class AddEditNewProductScreen extends StatefulWidget {
  final NewProduct? existing;
  const AddEditNewProductScreen({super.key, this.existing});

  @override
  State<AddEditNewProductScreen> createState() =>
      _AddEditNewProductScreenState();
}

class _AddEditNewProductScreenState extends State<AddEditNewProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Basic Information
  late final TextEditingController _productName;
  late final TextEditingController _productCode;
  late final TextEditingController _brand;
  late final TextEditingController _modelNumber;
  late final TextEditingController _description;
  String _category = 'General';

  // Purchase Information
  late final TextEditingController _vendorName;
  late final TextEditingController _vendorContact;
  late final TextEditingController _vendorEmail;
  late final TextEditingController _purchaseCost;
  late final TextEditingController _quantity;
  String _unit = 'Pcs';
  late DateTime _purchaseDate;

  // Stock & Pricing Information (mirrors the Stock Summary Report columns:
  // Sale Price, Available Quantity for Sale, Reserved Quantity, Stock Value)
  late final TextEditingController _salePrice;
  late final TextEditingController _availableQuantityForSale;
  late final TextEditingController _reservedQuantity;
  late final TextEditingController _stockValue;

  // Inventory / Stock Information
  String _branch = 'CDA Admin';
  late final TextEditingController _storageLocation;
  late final TextEditingController _minimumStockLevel;

  // Added By (who logged / restocked this item)
  late final TextEditingController _addedBy;
  late final TextEditingController _employeeId;
  late final TextEditingController _department;

  // Attachments — non-null only when the user picks a NEW file (either
  // creating a product, or replacing the attachment while editing). When
  // editing and this stays null, the existing attachment is kept as-is.
  Uint8List? _newProductImageBytes;
  Uint8List? _newInvoiceFileBytes;
  late String _existingProductImage;
  late String _existingInvoiceFile;

  // Notes
  late final TextEditingController _notes;

  bool _saving = false;

  static const Color _navy = Color(0xFF0D1B4B);
  static const Color _accent = Color(0xFF00D4AA);

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    _productName = TextEditingController(text: e?.productName ?? '');
    _productCode = TextEditingController(text: e?.productCode ?? '');
    _brand = TextEditingController(text: e?.brand ?? '');
    _modelNumber = TextEditingController(text: e?.modelNumber ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _category = (e != null && NewProductOptions.categories.contains(e.category))
        ? e.category
        : 'General';

    _vendorName = TextEditingController(text: e?.vendorName ?? '');
    _vendorContact = TextEditingController(text: e?.vendorContact ?? '');
    _vendorEmail = TextEditingController(text: e?.vendorEmail ?? '');
    _purchaseCost = TextEditingController(
        text: e == null || e.purchaseCost == 0
            ? ''
            : e.purchaseCost.toStringAsFixed(2));
    _quantity = TextEditingController(text: e == null ? '1' : '${e.quantity}');
    _unit = (e != null && NewProductOptions.units.contains(e.unit))
        ? e.unit
        : 'Pcs';
    _purchaseDate = e?.purchaseDate ?? DateTime.now();

    _salePrice = TextEditingController(
        text: e == null || e.salePrice == 0
            ? ''
            : e.salePrice.toStringAsFixed(2));
    // Available Quantity for Sale defaults to Quantity (same as a fresh row
    // on the Stock Summary Report, where the two start out equal).
    _availableQuantityForSale = TextEditingController(
        text: e == null ? '' : '${e.availableQuantityForSale}');
    _reservedQuantity = TextEditingController(
        text: e == null || e.reservedQuantity == 0
            ? ''
            : '${e.reservedQuantity}');
    _stockValue = TextEditingController(
        text: e == null || e.stockValue == 0
            ? ''
            : e.stockValue.toStringAsFixed(2));

    _branch = (e != null && NewProductOptions.branches.contains(e.branch))
        ? e.branch
        : 'CDA Admin';
    _storageLocation = TextEditingController(text: e?.storageLocation ?? '');
    _minimumStockLevel = TextEditingController(
        text: e == null || e.minimumStockLevel == 0
            ? ''
            : '${e.minimumStockLevel}');

    _addedBy = TextEditingController(text: e?.addedBy ?? '');
    _employeeId = TextEditingController(text: e?.employeeId ?? '');
    _department = TextEditingController(text: e?.department ?? '');

    _existingProductImage = e?.productImage ?? '';
    _existingInvoiceFile = e?.invoiceFile ?? '';

    _notes = TextEditingController(text: e?.notes ?? '');

    // Recompute the live stock-status preview whenever quantity or the
    // minimum stock level changes, so the badge below those fields always
    // reflects what the user is currently typing.
    _quantity.addListener(_refreshStockPreview);
    _minimumStockLevel.addListener(_refreshStockPreview);
  }

  @override
  void dispose() {
    _productName.dispose();
    _productCode.dispose();
    _brand.dispose();
    _modelNumber.dispose();
    _description.dispose();
    _vendorName.dispose();
    _vendorContact.dispose();
    _vendorEmail.dispose();
    _purchaseCost.dispose();
    _quantity.removeListener(_refreshStockPreview);
    _quantity.dispose();
    _salePrice.dispose();
    _availableQuantityForSale.dispose();
    _reservedQuantity.dispose();
    _stockValue.dispose();
    _storageLocation.dispose();
    _minimumStockLevel.removeListener(_refreshStockPreview);
    _minimumStockLevel.dispose();
    _addedBy.dispose();
    _employeeId.dispose();
    _department.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _refreshStockPreview() => setState(() {});

  // ── Live stock-status preview ────────────────────────────────────────
  // These products are sale stock: bought in, sold to customers, and
  // reordered once quantity runs down to (or below) the minimum stock
  // level — there's no separate approval workflow to pick a status from,
  // it's simply derived from what's typed into Quantity / Minimum Stock.
  int get _previewQuantity => int.tryParse(_quantity.text.trim()) ?? 0;
  int get _previewMinStock => int.tryParse(_minimumStockLevel.text.trim()) ?? 0;

  String get _previewStockStatus {
    if (_previewQuantity <= 0) return NewProductService.stockOutOfStock;
    if (_previewQuantity <= _previewMinStock) return NewProductService.stockLow;
    return NewProductService.stockIn;
  }

  Color get _previewStockColor {
    switch (_previewStockStatus) {
      case NewProductService.stockOutOfStock:
        return const Color(0xFFC62828);
      case NewProductService.stockLow:
        return const Color(0xFFF9A825);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  IconData get _previewStockIcon {
    switch (_previewStockStatus) {
      case NewProductService.stockOutOfStock:
        return Icons.remove_shopping_cart_rounded;
      case NewProductService.stockLow:
        return Icons.warning_amber_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  // ── Date picker ───────────────────────────────────────────────────────
  Future<void> _pickPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _purchaseDate = picked);
  }

  // ── Attachments ───────────────────────────────────────────────────────
  Future<void> _pickImage({required bool isInvoice}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _imageSourceSheet(),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: source, imageQuality: 85);
    if (xfile == null) return;

    final bytes = await xfile.readAsBytes();
    setState(() {
      if (isInvoice) {
        _newInvoiceFileBytes = bytes;
      } else {
        _newProductImageBytes = bytes;
      }
    });
  }

  Widget _imageSourceSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded, color: _accent),
            title: const Text('Take Photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: _accent),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────
  String _autoGenerateProductCode() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return 'PRD-${ts.substring(ts.length - 6)}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please fix the highlighted fields'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    setState(() => _saving = true);

    try {
      final productImage = _newProductImageBytes != null
          ? NewProductService.encodeImageForFirestore(_newProductImageBytes!)
          : _existingProductImage;
      final invoiceFile = _newInvoiceFileBytes != null
          ? NewProductService.encodeImageForFirestore(_newInvoiceFileBytes!)
          : _existingInvoiceFile;

      final code = _productCode.text.trim().isEmpty
          ? (_isEdit && widget.existing!.productCode.isNotEmpty
          ? widget.existing!.productCode
          : _autoGenerateProductCode())
          : _productCode.text.trim();

      final product = NewProduct(
        productId: widget.existing?.productId ?? '',
        productName: _productName.text.trim(),
        productCode: code,
        category: _category,
        brand: _brand.text.trim(),
        modelNumber: _modelNumber.text.trim(),
        description: _description.text.trim(),
        vendorName: _vendorName.text.trim(),
        vendorContact: _vendorContact.text.trim(),
        vendorEmail: _vendorEmail.text.trim(),
        purchaseDate: _purchaseDate,
        purchaseCost: double.tryParse(_purchaseCost.text.trim()) ?? 0,
        quantity: int.tryParse(_quantity.text.trim()) ?? 0,
        unit: _unit,
        salePrice: double.tryParse(_salePrice.text.trim()) ?? 0,
        availableQuantityForSale:
        int.tryParse(_availableQuantityForSale.text.trim()) ??
            (int.tryParse(_quantity.text.trim()) ?? 0),
        reservedQuantity: int.tryParse(_reservedQuantity.text.trim()) ?? 0,
        stockValue: double.tryParse(_stockValue.text.trim()) ?? 0,
        branch: _branch,
        storageLocation: _storageLocation.text.trim(),
        minimumStockLevel: int.tryParse(_minimumStockLevel.text.trim()) ?? 0,
        // Stock status is derived, not chosen — kept on the record purely
        // as a convenient, queryable snapshot of the status at save time.
        status: _previewStockStatus,
        addedBy: _addedBy.text.trim(),
        employeeId: _employeeId.text.trim(),
        department: _department.text.trim(),
        productImage: productImage,
        invoiceFile: invoiceFile,
        notes: _notes.text.trim(),
      );

      if (_isEdit) {
        await NewProductService.updateNewProduct(
            widget.existing!.productId, widget.existing!, product);
      } else {
        await NewProductService.addNewProduct(product);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Product updated' : 'New product added'),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Product' : 'Add Product',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        backgroundColor: _navy,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('Basic Information'),
                _buildCard([
                  _field(
                    controller: _productName,
                    label: 'Product Name *',
                    icon: Icons.inventory_2_rounded,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Product name is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _productCode,
                    label: 'Product Code (auto-generated if empty)',
                    icon: Icons.qr_code_rounded,
                  ),
                  const SizedBox(height: 14),
                  _dropdown(
                    label: 'Category',
                    icon: Icons.category_rounded,
                    value: _category,
                    items: NewProductOptions.categories,
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _brand,
                    label: 'Brand',
                    icon: Icons.branding_watermark_rounded,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _modelNumber,
                    label: 'Model Number',
                    icon: Icons.tag_rounded,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _description,
                    label: 'Description',
                    icon: Icons.description_outlined,
                    maxLines: 3,
                  ),
                ]),
                const SizedBox(height: 16),
                _sectionLabel('Purchase Information'),
                _buildCard([
                  _field(
                    controller: _vendorName,
                    label: 'Vendor Name *',
                    icon: Icons.storefront_rounded,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Vendor name is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _vendorContact,
                    label: 'Vendor Contact Number',
                    icon: Icons.call_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _vendorEmail,
                    label: 'Vendor Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(v.trim());
                      return ok ? null : 'Enter a valid email';
                    },
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: _pickPurchaseDate,
                    borderRadius: BorderRadius.circular(10),
                    child: _dateBox(
                        label: 'Purchase Date *', date: _purchaseDate),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: _purchaseCost,
                          label: 'Purchase Cost',
                          icon: Icons.currency_rupee_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = double.tryParse(v.trim());
                            if (n == null || n < 0) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          controller: _quantity,
                          label: 'Quantity *',
                          icon: Icons.layers_rounded,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 0) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _dropdown(
                    label: 'Unit',
                    icon: Icons.straighten_rounded,
                    value: _unit,
                    items: NewProductOptions.units,
                    onChanged: (v) => setState(() => _unit = v!),
                  ),
                ]),
                const SizedBox(height: 16),
                _sectionLabel('Stock & Pricing'),
                _buildCard([
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: _salePrice,
                          label: 'Sale Price',
                          icon: Icons.sell_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = double.tryParse(v.trim());
                            if (n == null || n < 0) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          controller: _stockValue,
                          label: 'Stock Value',
                          icon: Icons.account_balance_wallet_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = double.tryParse(v.trim());
                            if (n == null || n < 0) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: _availableQuantityForSale,
                          label: 'Available Qty for Sale',
                          icon: Icons.inventory_rounded,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = int.tryParse(v.trim());
                            if (n == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          controller: _reservedQuantity,
                          label: 'Reserved Quantity',
                          icon: Icons.lock_clock_rounded,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 0) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ]),
                const SizedBox(height: 16),
                _sectionLabel('Stock Information'),
                _buildCard([
                  _dropdown(
                    label: 'Branch *',
                    icon: Icons.business_rounded,
                    value: _branch,
                    items: NewProductOptions.branches,
                    onChanged: (v) => setState(() => _branch = v!),
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _storageLocation,
                    label: 'Storage Location',
                    icon: Icons.warehouse_rounded,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _minimumStockLevel,
                    label: 'Minimum Stock Level (reorder point)',
                    icon: Icons.low_priority_rounded,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 0) return 'Invalid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _stockStatusPreview(),
                ]),
                const SizedBox(height: 16),
                _sectionLabel('Added By'),
                _buildCard([
                  _field(
                    controller: _addedBy,
                    label: 'Added By *',
                    icon: Icons.person_outline,
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _employeeId,
                    label: 'Employee ID',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _department,
                    label: 'Department',
                    icon: Icons.apartment_rounded,
                  ),
                ]),
                const SizedBox(height: 16),
                _sectionLabel('Attachments'),
                _buildCard([
                  _attachmentTile(
                    label: 'Product Image',
                    icon: Icons.image_outlined,
                    newBytes: _newProductImageBytes,
                    existingBase64: _existingProductImage,
                    onPick: () => _pickImage(isInvoice: false),
                    onClear: () => setState(() {
                      _newProductImageBytes = null;
                      _existingProductImage = '';
                    }),
                  ),
                  const SizedBox(height: 14),
                  _attachmentTile(
                    label: 'Invoice / Bill Upload',
                    icon: Icons.receipt_long_rounded,
                    newBytes: _newInvoiceFileBytes,
                    existingBase64: _existingInvoiceFile,
                    onPick: () => _pickImage(isInvoice: true),
                    onClear: () => setState(() {
                      _newInvoiceFileBytes = null;
                      _existingInvoiceFile = '';
                    }),
                  ),
                ]),
                const SizedBox(height: 16),
                _sectionLabel('Notes'),
                _buildCard([
                  _field(
                    controller: _notes,
                    label: 'Additional Notes (optional)',
                    icon: Icons.notes_rounded,
                    maxLines: 3,
                  ),
                ]),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : Icon(
                        _isEdit ? Icons.save_rounded : Icons.add_circle_outline,
                        color: Colors.white),
                    label: Text(
                      _saving
                          ? 'Saving…'
                          : _isEdit
                          ? 'Save Changes'
                          : 'ADD PRODUCT',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Small building blocks ────────────────────────────────────────────

  // Live badge showing what Quantity / Minimum Stock Level currently
  // resolve to. Auto-updates as the user types — nothing to pick manually.
  Widget _stockStatusPreview() {
    final color = _previewStockColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(_previewStockIcon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stock Status',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(
                  _previewStockStatus,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
          ),
          Text(
            'Qty $_previewQuantity / Min $_previewMinStock',
            style: TextStyle(
                fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: _accent, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _dateBox({
    required String label,
    required DateTime? date,
    String placeholder = 'Select date',
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded, size: 20, color: _accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(
                  date == null ? placeholder : _formatDate(date),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: date == null ? Colors.grey.shade400 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.edit_rounded, size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _attachmentTile({
    required String label,
    required IconData icon,
    required Uint8List? newBytes,
    required String existingBase64,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final hasAttachment = newBytes != null || existingBase64.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        if (hasAttachment)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                newBytes != null
                    ? Image.memory(newBytes,
                    height: 140, width: double.infinity, fit: BoxFit.cover)
                    : Image.memory(
                    _decode(existingBase64),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover),
                Positioned(
                  top: 6,
                  right: 6,
                  child: InkWell(
                    onTap: onClear,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.grey.shade300, style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade400),
                  const SizedBox(height: 6),
                  Text('Tap to add',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ),
        if (hasAttachment) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: const Text('Replace'),
          ),
        ],
      ],
    );
  }

  Uint8List _decode(String base64) {
    try {
      return const Base64Decoder().convert(base64);
    } catch (_) {
      return Uint8List(0);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    return '$day $month ${date.year}';
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.words,
      validator: validator,
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        floatingLabelStyle: const TextStyle(color: _accent),
        prefixIcon: Icon(icon, color: _accent, size: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _accent, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      dropdownColor: Colors.white,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        floatingLabelStyle: const TextStyle(color: _accent),
        prefixIcon: Icon(icon, color: _accent, size: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _accent, width: 1.5)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: items
          .map((i) => DropdownMenuItem(
        value: i,
        child: Text(i, style: const TextStyle(fontSize: 14, color: Colors.black87)),
      ))
          .toList(),
      onChanged: onChanged,
    );
  }
}