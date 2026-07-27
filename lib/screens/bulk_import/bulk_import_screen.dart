// lib/screens/bulk_import/bulk_import_screen.dart
//
// Shared bulk-import flow for the New Products, Inventory, and Stock
// Management modules. Flow: pick a .xlsx or .pdf file → parse it →
// commit every row straight to Firestore via the normal
// NewProductService / InventoryService / StockService add calls (so
// activity logging, caching, etc. all behave exactly like a manual add).
// There is no manual review/edit screen — the file is imported the
// moment it's picked. Only each target's one required field (name /
// product name) is enforced, and it's enforced per row, not for the
// whole file: a row missing it is silently skipped (and counted) while
// every other row still imports. Every other column is optional and
// falls back to a safe default, so a file that's missing minor fields
// never blocks anything.
//
// Inventory and New Products already fan out to every other module (see
// InventorySyncService); Stock Management rows get the same treatment via
// InventorySyncService.syncFromStockAdd, so an item added from any of the
// three pages shows up in Search Products / Fixed Assets / Consumables
// too, without re-entering it.
//
// Requires `file_picker` in pubspec.yaml — see bulk_import_service.dart
// for the full list of new dependencies this feature needs.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:cda_inventory/models/new_product.dart';
import 'package:cda_inventory/services/bulk_import_service.dart';
export 'package:cda_inventory/services/bulk_import_service.dart' show BulkImportTarget;
import 'package:cda_inventory/services/new_product_service.dart';
import 'package:cda_inventory/services/inventory_service.dart';
import 'package:cda_inventory/services/stock_service.dart';
import 'package:cda_inventory/services/inventory_sync_service.dart';

class BulkImportScreen extends StatefulWidget {
  final BulkImportTarget target;

  const BulkImportScreen({super.key, required this.target});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  static const _navy = Color(0xFF0A1628);
  static const _accent = Color(0xFF7B5EA7);

  bool _isWorking = false; // parsing OR importing — same full-screen state
  String _statusLabel = '';
  String _defaultBranch = 'CDA Admin';

  String get _title {
    switch (widget.target) {
      case BulkImportTarget.newProducts:
        return 'Bulk Import — New Products';
      case BulkImportTarget.inventory:
        return 'Bulk Import — Inventory';
      case BulkImportTarget.stockManagement:
        return 'Bulk Import — Stock Management';
    }
  }

  String get _requiredField => BulkImportService.requiredField[widget.target]!;

  // ── FILE PICK → PARSE → IMPORT, all in one go ───────────────────────
  Future<void> _pickAndImport() async {
    final result = await FilePicker.pickFiles(
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
      _isWorking = true;
      _statusLabel = 'Reading ${picked.name}…';
    });

    BulkImportResult parsed;
    List<Map<String, String>> rows;
    List<String> unrecognized;
    try {
      parsed = BulkImportService.parse(bytes, picked.name);
      final mapped = BulkImportService.toFieldRows(parsed, widget.target);
      rows = mapped.rows;
      unrecognized = mapped.unrecognized;
    } catch (e) {
      setState(() => _isWorking = false);
      _showSnack('Failed to parse "${picked.name}": $e');
      return;
    }

    if (rows.isEmpty) {
      setState(() => _isWorking = false);
      await _showResultDialog(
        fileName: picked.name,
        totalRows: 0,
        success: 0,
        skippedMissingName: 0,
        failures: const [],
        warnings: parsed.warnings,
        unrecognized: unrecognized,
      );
      return;
    }

    setState(() => _statusLabel = 'Importing ${rows.length} row(s)…');

    var success = 0;
    var skippedMissingName = 0;
    final failures = <String>[];

    for (final row in rows) {
      if ((row[_requiredField] ?? '').trim().isEmpty) {
        skippedMissingName++;
        continue;
      }
      try {
        if (widget.target == BulkImportTarget.newProducts) {
          await NewProductService.addNewProduct(_toNewProduct(row));
        } else if (widget.target == BulkImportTarget.inventory) {
          await _addInventoryItem(row);
        } else {
          await _addStockItem(row);
        }
        success++;
      } catch (e) {
        failures.add('${row[_requiredField]}: $e');
      }
    }

    if (!mounted) return;
    setState(() => _isWorking = false);

    await _showResultDialog(
      fileName: picked.name,
      totalRows: rows.length,
      success: success,
      skippedMissingName: skippedMissingName,
      failures: failures,
      warnings: parsed.warnings,
      unrecognized: unrecognized,
    );

    if (success > 0 && mounted) {
      Navigator.pop(context, true);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── RESULT DIALOG ────────────────────────────────────────────────────
  // Everything the old preview screen used to show up front (parse
  // warnings, ignored columns) now shows here instead, alongside the
  // actual outcome — since there's no review step to show it on before
  // the write happens.
  Future<void> _showResultDialog({
    required String fileName,
    required int totalRows,
    required int success,
    required int skippedMissingName,
    required List<String> failures,
    required List<String> warnings,
    required List<String> unrecognized,
  }) async {
    if (!mounted) return;
    final requiredLabel = BulkImportService.fieldLabels[_requiredField] ?? _requiredField;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(success > 0 ? 'Import complete' : 'Nothing imported'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fileName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              if (totalRows == 0)
                const Text('No data rows were found in this file.')
              else
                Text('$success of $totalRows row(s) imported.'),
              if (skippedMissingName > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '$skippedMissingName row(s) skipped — no "$requiredLabel" value could be found for them.',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              // Every row was skipped for the same reason — that's almost
              // always a header mismatch (e.g. a sheet laid out with
              // category names as column headers instead of one product
              // per row), not 300 genuinely blank rows. Call it out
              // directly instead of leaving that to guesswork.
              if (totalRows > 0 && success == 0 && skippedMissingName == totalRows) ...[
                const SizedBox(height: 10),
                Text(
                  'None of the rows had a recognizable "$requiredLabel" column. '
                      'This usually means the file\'s headers are category names '
                      '(e.g. ONFIELD, RPTO, TOOL KITS…) rather than one product per '
                      'row — check the ignored columns below and make sure there\'s '
                      'a plain "Name" / "Product Name" column with one product per row.',
                  style: TextStyle(fontSize: 12.5, color: Colors.amber.shade900),
                ),
              ],
              if (failures.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Failed:', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                ...failures.map((f) => Text('• $f', style: const TextStyle(fontSize: 13))),
              ],
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Warnings:', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                ...warnings.map((w) => Text('• $w', style: const TextStyle(fontSize: 12.5))),
              ],
              if (unrecognized.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Ignored unrecognized column(s): ${unrecognized.join(', ')}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
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
  }

  // ── ROW → MODEL MAPPERS ──────────────────────────────────────────────
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

  Future<void> _addStockItem(Map<String, String> row) async {
    final name = row['name'] ?? '';
    final branch = _normalizeNewProductBranch(row['branch']) ?? _defaultBranch;
    final quantity = int.tryParse(row['quantity'] ?? '') ?? 1;
    final rawCategory = (row['category'] ?? '').trim().toLowerCase();
    // Any value other than a recognizable "fixed asset" reading defaults
    // to consumable — matches Add Stock Item's own two-choice picker, so
    // a blank/unrecognized cell never blocks the import.
    final category = (rawCategory.contains('fixed') || rawCategory.contains('asset'))
        ? 'fixed_asset'
        : 'consumable';

    await StockService.addStockIn(
      productName: name,
      quantity: quantity,
      receivedBy: 'Bulk Import',
      branch: branch,
      date: DateTime.now().toIso8601String(),
      remarks: 'Bulk import',
      category: category,
    );

    // Fan out to Search Products / Branch module / Fixed Assets or
    // Consumables — same cross-module propagation a manual Inventory or
    // New Products add already gets, so this item shows up everywhere
    // without having to be entered twice.
    await InventorySyncService.syncFromStockAdd(
      name: name,
      category: category,
      quantity: quantity,
      branchLabel: branch,
      location: row['location'] ?? '',
      addedBy: 'Bulk Import',
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
    final numbers = parts.map((p) => int.tryParse(p.trim())).toList();
    if (numbers.any((n) => n == null)) return null;
    // Assume day/month/year, the common non-US spreadsheet convention.
    try {
      return DateTime(numbers[2]!, numbers[1]!, numbers[0]!);
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
      body: _buildPicker(),
    );
  }

  Widget _buildPicker() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isWorking ? Icons.cloud_upload_rounded : Icons.upload_file_rounded,
              size: 56,
              color: _accent,
            ),
            const SizedBox(height: 16),
            Text(
              _isWorking
                  ? _statusLabel
                  : 'Upload an Excel (.xlsx) or PDF file — products are added '
                  'the moment the file finishes reading, no review step.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            if (!_isWorking) ...[
              const SizedBox(height: 8),
              Text(
                'Put one product per row with a header row like Name, '
                    'Category, Quantity, Branch. Only "${BulkImportService.fieldLabels[_requiredField] ?? _requiredField}" '
                    'is required — a row missing everything else still imports '
                    'with safe defaults; a row missing that one field is skipped '
                    'and reported, not blocked.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Default branch:', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
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
              Text(
                'Used only for rows whose Branch cell is blank or unrecognized.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
              ),
            ],
            const SizedBox(height: 24),
            _isWorking
                ? const CircularProgressIndicator()
                : FilledButton.icon(
              onPressed: _pickAndImport,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Choose file & import'),
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
}
