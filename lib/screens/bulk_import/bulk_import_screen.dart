// lib/screens/bulk_import/bulk_import_screen.dart
//
// Shared bulk-import flow for both the New Products and Inventory
// modules. Flow: pick a .xlsx or .pdf file → parse it into rows
// (BulkImportService) → show every row in an editable preview so nothing
// bad gets written silently → commit the selected rows one at a time via
// the normal NewProductService / InventoryService add calls (so activity
// logging, caching, etc. all behave exactly like a manual add).
//
// Requires `file_picker` in pubspec.yaml — see bulk_import_service.dart
// for the full list of new dependencies this feature needs.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:cda_inventory/models/new_product.dart';
import 'package:cda_inventory/services/bulk_import_service.dart';
export 'package:cda_inventory/services/bulk_import_service.dart' show BulkImportTarget;
import 'package:cda_inventory/services/new_product_service.dart';
import 'package:cda_inventory/services/inventory_service.dart';

class BulkImportScreen extends StatefulWidget {
  final BulkImportTarget target;

  const BulkImportScreen({super.key, required this.target});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  static const _navy = Color(0xFF0A1628);
  static const _accent = Color(0xFF7B5EA7);

  String? _fileName;
  List<Map<String, String>> _rows = []; // internal-field-keyed
  List<bool> _selected = [];
  List<String> _warnings = [];
  List<String> _unrecognizedColumns = [];
  bool _isParsing = false;
  bool _isImporting = false;
  String _defaultBranch = 'CDA Admin';

  String get _title => widget.target == BulkImportTarget.newProducts
      ? 'Bulk Import — New Products'
      : 'Bulk Import — Inventory';

  List<String> get _fieldsInOrder => BulkImportService.fieldOrder[widget.target]!;

  String get _requiredField => BulkImportService.requiredField[widget.target]!;

  // ── FILE PICK + PARSE ────────────────────────────────────────────────
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null) {
      _showSnack('Could not read that file — please try again.');
      return;
    }

    setState(() {
      _isParsing = true;
      _fileName = picked.name;
      _rows = [];
      _selected = [];
      _warnings = [];
      _unrecognizedColumns = [];
    });

    try {
      final parsed = BulkImportService.parse(bytes, picked.name);
      final mapped = BulkImportService.toFieldRows(parsed, widget.target);

      setState(() {
        _rows = mapped.rows;
        _selected = List.filled(mapped.rows.length, true);
        _warnings = parsed.warnings;
        _unrecognizedColumns = mapped.unrecognized;
        _isParsing = false;
      });

      if (_rows.isEmpty && _warnings.isEmpty) {
        _warnings = ['No data rows were found in this file.'];
      }
    } catch (e) {
      setState(() => _isParsing = false);
      _showSnack('Failed to parse "${picked.name}": $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _removeRow(int i) {
    setState(() {
      _rows.removeAt(i);
      _selected.removeAt(i);
    });
  }

  // ── COMMIT ────────────────────────────────────────────────────────────
  Future<void> _import() async {
    final toImport = <int>[
      for (var i = 0; i < _rows.length; i++)
        if (_selected[i]) i,
    ];

    if (toImport.isEmpty) {
      _showSnack('Select at least one row to import.');
      return;
    }

    // Validate the required field up front so we don't partially import.
    final missing = toImport
        .where((i) => (_rows[i][_requiredField] ?? '').trim().isEmpty)
        .toList();
    if (missing.isNotEmpty) {
      _showSnack(
          '${missing.length} row(s) are missing "${BulkImportService.fieldLabels[_requiredField]}" — fill it in or deselect those rows.');
      return;
    }

    setState(() => _isImporting = true);

    var success = 0;
    final failures = <String>[];

    for (final i in toImport) {
      final row = _rows[i];
      try {
        if (widget.target == BulkImportTarget.newProducts) {
          await NewProductService.addNewProduct(_toNewProduct(row));
        } else {
          await _addInventoryItem(row);
        }
        success++;
      } catch (e) {
        failures.add('${row[_requiredField]}: $e');
      }
    }

    if (!mounted) return;
    setState(() => _isImporting = false);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(success > 0 ? 'Import complete' : 'Import failed'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$success of ${toImport.length} row(s) imported successfully.'),
              if (failures.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Failed:', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                ...failures.map((f) => Text('• $f', style: const TextStyle(fontSize: 13))),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (success > 0 && mounted) {
      Navigator.pop(context, true);
    }
  }

  NewProduct _toNewProduct(Map<String, String> row) {
    DateTime purchaseDate;
    final rawDate = row['purchaseDate'];
    purchaseDate = rawDate == null
        ? DateTime.now()
        : (DateTime.tryParse(rawDate) ?? _tryParseLooseDate(rawDate) ?? DateTime.now());

    final branch = _normalizeNewProductBranch(row['branch']) ?? _defaultBranch;
    final quantity = int.tryParse(row['quantity'] ?? '') ?? 1;

    return NewProduct(
      productId: '',
      productName: row['productName'] ?? '',
      productCode: row['productCode'] ?? '',
      category: row['category']?.isNotEmpty == true ? row['category']! : 'General',
      brand: row['brand'] ?? '',
      modelNumber: row['modelNumber'] ?? '',
      description: row['description'] ?? '',
      vendorName: row['vendorName'] ?? '',
      vendorContact: row['vendorContact'] ?? '',
      vendorEmail: row['vendorEmail'] ?? '',
      purchaseDate: purchaseDate,
      purchaseCost: double.tryParse(row['purchaseCost'] ?? '') ?? 0,
      quantity: quantity,
      unit: row['unit']?.isNotEmpty == true ? row['unit']! : 'Pcs',
      salePrice: double.tryParse(row['salePrice'] ?? '') ?? 0,
      // Falls back to Quantity when the file doesn't have its own
      // "Available Quantity for Sale" column — same as a fresh row on the
      // Stock Summary Report, where the two start out equal.
      availableQuantityForSale:
      int.tryParse(row['availableQuantityForSale'] ?? '') ?? quantity,
      reservedQuantity: int.tryParse(row['reservedQuantity'] ?? '') ?? 0,
      stockValue: double.tryParse(row['stockValue'] ?? '') ?? 0,
      branch: branch,
      storageLocation: row['storageLocation'] ?? '',
      minimumStockLevel: int.tryParse(row['minimumStockLevel'] ?? '') ?? 0,
      status: row['status']?.isNotEmpty == true ? row['status']! : 'In Stock',
      addedBy: row['addedBy']?.isNotEmpty == true ? row['addedBy']! : 'Bulk Import',
      employeeId: row['employeeId'] ?? '',
      department: row['department'] ?? '',
      remarks: row['remarks'] ?? '',
    );
  }

  Future<void> _addInventoryItem(Map<String, String> row) async {
    await InventoryService().addProduct(
      name: row['name'] ?? '',
      category: row['category']?.isNotEmpty == true ? row['category']! : 'ONFIELD',
      location: row['location'] ?? '',
      quantity: int.tryParse(row['quantity'] ?? '') ?? 1,
      description: row['description'] ?? '',
      branch: _normalizeInventoryBranch(row['branch']) ?? (_defaultBranch == 'CDA Admin' ? 1 : 2),
      addedBy: row['addedBy']?.isNotEmpty == true ? row['addedBy']! : 'Bulk Import',
    );
  }

  String? _normalizeNewProductBranch(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final norm = raw.trim().toLowerCase();
    if (norm.contains('admin')) return 'CDA Admin';
    if (norm.contains('ops')) return 'CDA Ops';
    return null;
  }

  int? _normalizeInventoryBranch(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final norm = raw.trim().toLowerCase();
    if (norm.contains('admin')) return 1;
    if (norm.contains('ops')) return 2;
    return int.tryParse(norm);
  }

  DateTime? _tryParseLooseDate(String raw) {
    // Handles common spreadsheet formats like "24/07/2026" or "24-07-2026"
    // that DateTime.tryParse (ISO-8601 only) doesn't understand.
    final parts = raw.split(RegExp(r'[/\-.]'));
    if (parts.length != 3) return null;
    final nums = parts.map((p) => int.tryParse(p.trim())).toList();
    if (nums.any((n) => n == null)) return null;
    // Assume day/month/year, the common non-US spreadsheet convention.
    try {
      return DateTime(nums[2]!, nums[1]!, nums[0]!);
    } catch (_) {
      return null;
    }
  }

  // ── BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: _fileName == null ? _buildPicker() : _buildPreview(),
    );
  }

  Widget _buildPicker() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.upload_file_rounded, size: 56, color: _accent),
            const SizedBox(height: 16),
            const Text(
              'Upload an Excel (.xlsx) or PDF file to add products in bulk.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Excel works best — put one product per row with a header row '
                  'like Name, Category, Quantity, Branch. PDF tables are read '
                  'heuristically and need careful review before saving.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            _isParsing
                ? const CircularProgressIndicator()
                : FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Choose file'),
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final selectedCount = _selected.where((s) => s).length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _fileName!,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isParsing ? null : _pickFile,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Change file'),
                  ),
                ],
              ),
              if (_warnings.isNotEmpty) _buildBanner(_warnings, Colors.amber.shade50, Colors.amber.shade800, Icons.warning_amber_rounded),
              if (_unrecognizedColumns.isNotEmpty)
                _buildBanner(
                  ['Ignored unrecognized column(s): ${_unrecognizedColumns.join(', ')}'],
                  Colors.grey.shade100,
                  Colors.grey.shade700,
                  Icons.info_outline_rounded,
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('${_rows.length} row(s) found · $selectedCount selected',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                  const Spacer(),
                  const Text('Default branch:', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  DropdownButton<String>(
                    value: _defaultBranch,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'CDA Admin', child: Text('CDA Admin')),
                      DropdownMenuItem(value: 'CDA Ops', child: Text('CDA Ops')),
                    ],
                    onChanged: (v) => setState(() => _defaultBranch = v ?? 'CDA Admin'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _rows.length; i++) _buildRowCard(i),
            ],
          ),
        ),
        _buildBottomBar(selectedCount),
      ],
    );
  }

  Widget _buildBanner(List<String> lines, Color bg, Color fg, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines
                  .map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(l, style: TextStyle(color: fg, fontSize: 12.5)),
              ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowCard(int i) {
    final row = _rows[i];
    final missingRequired = (row[_requiredField] ?? '').trim().isEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: missingRequired ? Colors.red.shade200 : Colors.transparent),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _selected[i],
                  onChanged: (v) => setState(() => _selected[i] = v ?? false),
                ),
                Expanded(
                  child: Text('Row ${i + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                if (missingRequired)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text('Missing ${BulkImportService.fieldLabels[_requiredField]}',
                        style: const TextStyle(color: Colors.red, fontSize: 11)),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  tooltip: 'Remove row',
                  onPressed: () => _removeRow(i),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final field in _fieldsInOrder)
                  SizedBox(
                    width: 220,
                    child: TextFormField(
                      key: ValueKey('row-$i-$field'),
                      initialValue: row[field] ?? '',
                      decoration: InputDecoration(
                        labelText: BulkImportService.fieldLabels[field] ?? field,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) => row[field] = v,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(int selectedCount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isImporting || _rows.isEmpty ? null : _import,
            icon: _isImporting
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.cloud_upload_rounded),
            label: Text(_isImporting ? 'Importing…' : 'Import $selectedCount product(s)'),
            style: FilledButton.styleFrom(
              backgroundColor: _navy,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }
}