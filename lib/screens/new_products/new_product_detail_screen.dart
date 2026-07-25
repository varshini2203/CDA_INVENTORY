// lib/screens/new_products/new_product_detail_screen.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cda_inventory/models/new_product.dart';
import 'package:cda_inventory/services/new_product_service.dart';
import 'add_edit_new_product_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  NEW PRODUCT DETAIL SCREEN
//  Full read-only view of a single sale-stock product, grouped into the
//  same sections as the Add/Edit screen. Reachable from the list screen's
//  "View" button / card tap.
// ═══════════════════════════════════════════════════════════════════════════

class NewProductDetailScreen extends StatefulWidget {
  final NewProduct product;
  const NewProductDetailScreen({super.key, required this.product});

  @override
  State<NewProductDetailScreen> createState() =>
      _NewProductDetailScreenState();
}

class _NewProductDetailScreenState extends State<NewProductDetailScreen> {
  static const Color _navy = Color(0xFF0A1628);
  static const Color _accent = Color(0xFF00D4AA);
  static const Color _surface = Color(0xFFF0F4F8);

  late NewProduct _product;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  // These products are sale stock, so "status" here always reflects the
  // current stock position — computed live from Quantity vs Minimum Stock
  // Level, the same logic the list screen's dashboard cards use.
  String get _stockStatus => NewProductService.stockStatus(_product);

  Color _stockColor(String status) {
    switch (status) {
      case NewProductService.stockOutOfStock:
        return const Color(0xFFC62828);
      case NewProductService.stockLow:
        return const Color(0xFFF9A825);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  IconData _stockIcon(String status) {
    switch (status) {
      case NewProductService.stockOutOfStock:
        return Icons.remove_shopping_cart_rounded;
      case NewProductService.stockLow:
        return Icons.warning_amber_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  Uint8List? _decode(String base64) {
    if (base64.isEmpty) return null;
    try {
      return const Base64Decoder().convert(base64);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final fresh = await NewProductService.getNewProductById(_product.productId);
      if (fresh != null && mounted) setState(() => _product = fresh);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Edit New Product'),
        builder: (_) => AddEditNewProductScreen(existing: _product),
      ),
    );
    if (updated == true) await _refresh();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Product',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Delete "${_product.productName}" from New Products? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await NewProductService.deleteNewProduct(_product);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_product.productName} deleted'),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Delete failed: $e'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stockStatus = _stockStatus;
    final stockColor = _stockColor(stockStatus);
    final productImageBytes = _decode(_product.productImage);
    final invoiceFileBytes = _decode(_product.invoiceFile);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_product.productName.isEmpty ? 'Product Detail' : _product.productName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit',
            onPressed: _busy ? null : _edit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete',
            onPressed: _busy ? null : _delete,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerCard(stockStatus, stockColor),
                const SizedBox(height: 16),
                _sectionLabel('Basic Information'),
                _card([
                  _row('Product Name', _product.productName),
                  _row('Product Code', _product.productCode),
                  _row('Category', _product.category),
                  _row('Brand', _product.brand),
                  _row('Model Number', _product.modelNumber),
                  _row('Description', _product.description, isLast: true),
                ]),
                const SizedBox(height: 16),
                _sectionLabel('Purchase Information'),
                _card([
                  _row('Vendor Name', _product.vendorName),
                  _row('Vendor Contact', _product.vendorContact),
                  _row('Vendor Email', _product.vendorEmail),
                  _row('Purchase Date', _formatDate(_product.purchaseDate)),
                  _row('Purchase Cost',
                      _product.purchaseCost > 0
                          ? '₹${_product.purchaseCost.toStringAsFixed(2)}'
                          : '—'),
                  _row('Quantity', '${_product.quantity}'),
                  _row('Unit', _product.unit, isLast: true),
                ]),
                const SizedBox(height: 16),
                _sectionLabel('Stock & Pricing'),
                _card([
                  _row('Sale Price',
                      _product.salePrice > 0
                          ? '₹${_product.salePrice.toStringAsFixed(2)}'
                          : '—'),
                  _row('Available Quantity for Sale',
                      '${_product.availableQuantityForSale}'),
                  _row('Reserved Quantity', '${_product.reservedQuantity}'),
                  _row('Stock Value',
                      _product.stockValue > 0
                          ? '₹${_product.stockValue.toStringAsFixed(2)}'
                          : '—',
                      isLast: true),
                ]),
                const SizedBox(height: 16),
                _sectionLabel('Stock Information'),
                _card([
                  _row('Branch', _product.branch),
                  _row('Storage Location', _product.storageLocation),
                  _row('Minimum Stock Level', '${_product.minimumStockLevel}'),
                  _stockStatusRow(stockStatus, stockColor, isLast: true),
                ]),
                const SizedBox(height: 16),
                _sectionLabel('Added By'),
                _card([
                  _row('Added By', _product.addedBy),
                  _row('Employee ID', _product.employeeId),
                  _row('Department', _product.department, isLast: true),
                ]),
                const SizedBox(height: 16),
                _sectionLabel('Attachments'),
                _card([
                  _attachmentPreview('Product Image', productImageBytes),
                  const SizedBox(height: 14),
                  _attachmentPreview('Invoice / Bill', invoiceFileBytes,
                      isLast: true),
                ]),
                const SizedBox(height: 16),
                _sectionLabel('Notes'),
                _card([
                  _row('Additional Notes', _product.notes, isLast: true),
                ]),
                const SizedBox(height: 16),
                _sectionLabel('Record Info'),
                _card([
                  _row('Created', _formatDate(_product.createdAt)),
                  _row('Last Updated', _formatDate(_product.updatedAt),
                      isLast: true),
                ]),
              ],
            ),
          ),
          if (_busy)
            Container(
              color: Colors.black.withValues(alpha: 0.05),
              child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────
  Widget _headerCard(String stockStatus, Color stockColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _navy.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _product.productName.isEmpty
                          ? 'Untitled Product'
                          : _product.productName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800),
                    ),
                    if (_product.productCode.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(_product.productCode,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12.5)),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: stockColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: stockColor.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_stockIcon(stockStatus), size: 13, color: stockColor),
                    const SizedBox(width: 5),
                    Text(
                      stockStatus,
                      style: TextStyle(
                          color: stockColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _headerPill(Icons.business_rounded, _product.branch),
              _headerPill(Icons.storefront_rounded,
                  _product.vendorName.isEmpty ? 'No vendor' : _product.vendorName),
              _headerPill(Icons.layers_rounded, 'Qty: ${_product.quantity}'),
              _headerPill(Icons.category_rounded, _product.category),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerPill(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white60),
        const SizedBox(width: 5),
        Text(text,
            style: const TextStyle(
                color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ── Sections ──────────────────────────────────────────────────────────
  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _accent,
            letterSpacing: 1.2),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _row(String label, String value, {bool isLast = false}) {
    final display = value.trim().isEmpty ? '—' : value;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: Text(
                  display,
                  style: TextStyle(
                      fontSize: 14,
                      color: value.trim().isEmpty
                          ? Colors.grey.shade400
                          : Colors.black87,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }

  // Same layout as _row, but the value is a colored stock-status badge
  // instead of plain text — this is a derived value, not stored input.
  Widget _stockStatusRow(String status, Color color, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 140,
                child: Text('Stock Status',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_stockIcon(status), size: 13, color: color),
                      const SizedBox(width: 5),
                      Text(status,
                          style: TextStyle(
                              color: color,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }

  Widget _attachmentPreview(String label, Uint8List? bytes, {bool isLast = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (bytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(bytes,
                height: 160, width: double.infinity, fit: BoxFit.cover),
          )
        else
          Container(
            width: double.infinity,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Text('No attachment',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade400)),
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}