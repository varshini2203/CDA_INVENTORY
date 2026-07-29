// lib/screens/bulk_import/bulk_import_screen.dart
//
// Shared bulk-import entry screen for New Products, Inventory, and Stock
// Management. Public API is unchanged from before this change
// (`BulkImportScreen({required BulkImportTarget target})`,
// `BulkImportTarget` enum with the same 3 values) so all 4 existing call
// sites keep compiling and behaving as before, with no changes on their
// end.
//
// Flow for Inventory / New Products (the modules migrated onto the new
// Dynamic Bulk Import Engine — see services/bulk_import/):
//   pick a .xlsx, .csv or .pdf file
//     -> DynamicImportParser.parse()            (dynamic header/alias
//                                                 matching, per-module
//                                                 config, no fixed
//                                                 template, only required
//                                                 fields validated — same
//                                                 code path for all three
//                                                 file types; PDF just
//                                                 arrives at rows via
//                                                 pdf_table_extractor.dart
//                                                 instead of the `excel`
//                                                 package)
//     -> BulkImportPreviewScreen                (editable-status preview,
//                                                 duplicate detection +
//                                                 Skip/Update/Increase
//                                                 Quantity/Replace choice)
//     -> DynamicBulkImportEngine.commit()        (batched Firestore
//                                                 writes, cross-module
//                                                 sync reused via
//                                                 InventorySyncService,
//                                                 one ActivityLogService
//                                                 summary line)
//
// Flow for Stock Management (kept on its existing behavior — see the
// note above `stockManagementImportConfig` in module_import_configs.dart
// for why): pick a file -> parse with the same dynamic parser -> import
// immediately row-by-row through the existing `StockService.addStockIn`
// + `InventorySyncService.syncFromStockAdd`, exactly like before. This is
// a natural candidate to migrate onto the full engine in a follow-up.
//
// PDF support: text-based, table-formatted PDFs only. A scanned/
// image-only PDF parses to zero rows with a dedicated warning message
// (see pdf_table_extractor.dart's `ScannedPdfException`), which surfaces
// through the same "Nothing to import" dialog every other empty-file case
// already uses below — no separate PDF UI flow.

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:cda_inventory/services/inventory_sync_service.dart';
import 'package:cda_inventory/services/stock_service.dart';
import 'package:cda_inventory/services/bulk_import/dynamic_bulk_import_engine.dart';
import 'package:cda_inventory/services/bulk_import/dynamic_import_parser.dart';
import 'package:cda_inventory/services/bulk_import/import_field_config.dart';
import 'package:cda_inventory/services/bulk_import/module_import_configs.dart';

import 'bulk_import_preview_screen.dart';

enum BulkImportTarget { newProducts, inventory, stockManagement }

class BulkImportScreen extends StatefulWidget {
  final BulkImportTarget target;

  const BulkImportScreen({super.key, required this.target});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  static const _navy = Color(0xFF0A1628);
  static const _teal = Color(0xFF00D4AA);
  static const _surface = Color(0xFFF4F6FA);

  bool _isWorking = false;
  String _statusLabel = '';

  // Only used by the legacy Stock Management path below — Inventory/New
  // Products get their branch handling from each row via the engine.
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

  /// Non-null for modules migrated onto the Dynamic Bulk Import Engine.
  ModuleImportConfig? get _engineConfig {
    switch (widget.target) {
      case BulkImportTarget.inventory:
        return inventoryImportConfig;
      case BulkImportTarget.newProducts:
        return newProductsImportConfig;
      case BulkImportTarget.stockManagement:
        return null;
    }
  }

  String get _requiredFieldLabel {
    final config = _engineConfig ?? stockManagementImportConfig;
    final required = config.requiredFields;
    return required.isEmpty ? 'name' : required.first.label;
  }

  // ── FILE PICK → PARSE → (preview & commit) OR (legacy immediate import)
  Future<void> _pickAndImport() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    Uint8List bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (_) {
      _showSnack('Could not read that file — please try again.');
      return;
    }

    final config = _engineConfig;
    if (config == null) {
      await _legacyStockImport(bytes, picked.name);
      return;
    }

    setState(() {
      _isWorking = true;
      _statusLabel = 'Reading ${picked.name}…';
    });

    ImportParseResult parsed;
    try {
      parsed = DynamicImportParser.parse(bytes, picked.name, config);
    } catch (e) {
      setState(() => _isWorking = false);
      _showSnack('Failed to parse "${picked.name}": $e');
      return;
    }

    if (!mounted) return;
    setState(() => _isWorking = false);

    if (parsed.isEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nothing to import'),
          content: Text(
            parsed.fileWarnings.isNotEmpty
                ? parsed.fileWarnings.join('\n')
                : 'No data rows were found in "${picked.name}".',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final commitResult = await Navigator.push<ImportCommitResult>(
      context,
      MaterialPageRoute(
        builder: (_) => BulkImportPreviewScreen(
          config: config,
          parseResult: parsed,
          fileName: picked.name,
          importedBy: 'Bulk Import',
        ),
      ),
    );

    if (!mounted) return;
    if (commitResult != null && (commitResult.created + commitResult.updated) > 0) {
      Navigator.pop(context, true);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ═══════════════════════════════════════════════════════════════════
  //  LEGACY STOCK MANAGEMENT PATH — unchanged behavior from before this
  //  change: pick a file, import every row immediately (no preview step),
  //  show a result dialog. Only the parser underneath is new (dynamic
  //  Excel/CSV alias matching instead of the old fixed alias table) —
  //  the write path (`StockService.addStockIn` +
  //  `InventorySyncService.syncFromStockAdd`) is 100% untouched.
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _legacyStockImport(Uint8List bytes, String fileName) async {
    setState(() {
      _isWorking = true;
      _statusLabel = 'Reading $fileName…';
    });

    ImportParseResult parsed;
    try {
      parsed = DynamicImportParser.parse(
        bytes,
        fileName,
        stockManagementImportConfig,
      );
    } catch (e) {
      setState(() => _isWorking = false);
      _showSnack('Failed to parse "$fileName": $e');
      return;
    }

    final rows = parsed.validRows;
    if (rows.isEmpty) {
      setState(() => _isWorking = false);
      await _showLegacyResultDialog(
        fileName: fileName,
        totalRows: parsed.rows.length,
        success: 0,
        skippedInvalid: parsed.invalidCount,
        failures: const [],
        warnings: parsed.fileWarnings,
        unrecognized: parsed.unrecognizedHeaders,
      );
      return;
    }

    setState(() => _statusLabel = 'Importing ${rows.length} row(s)…');

    var success = 0;
    final failures = <String>[];

    for (final row in rows) {
      final name = (row.values['name'] ?? '').toString();
      final branch = _normalizeStockBranch(row.values['branch']?.toString());
      final quantity = (row.values['quantity'] as int?) ?? 1;
      final rawCategory = (row.values['category'] ?? '').toString().toLowerCase();
      final category = (rawCategory.contains('fixed') || rawCategory.contains('asset'))
          ? 'fixed_asset'
          : 'consumable';

      try {
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
        // Consumables — same cross-module propagation a manual Stock add
        // already gets.
        await InventorySyncService.syncFromStockAdd(
          name: name,
          category: category,
          quantity: quantity,
          branchLabel: branch,
          location: (row.values['location'] ?? '').toString(),
          addedBy: 'Bulk Import',
        );
        success++;
      } catch (e) {
        failures.add('$name: $e');
      }
    }

    if (!mounted) return;
    setState(() => _isWorking = false);

    await _showLegacyResultDialog(
      fileName: fileName,
      totalRows: parsed.rows.length,
      success: success,
      skippedInvalid: parsed.invalidCount,
      failures: failures,
      warnings: parsed.fileWarnings,
      unrecognized: parsed.unrecognizedHeaders,
    );

    if (success > 0 && mounted) {
      Navigator.pop(context, true);
    }
  }

  String _normalizeStockBranch(String? raw) {
    if (raw == null || raw.trim().isEmpty) return _defaultBranch;
    final norm = raw.trim().toLowerCase();
    if (norm.contains('admin')) return 'CDA Admin';
    if (norm.contains('ops')) return 'CDA Ops';
    return raw.trim();
  }

  Future<void> _showLegacyResultDialog({
    required String fileName,
    required int totalRows,
    required int success,
    required int skippedInvalid,
    required List<String> failures,
    required List<String> warnings,
    required List<String> unrecognized,
  }) async {
    if (!mounted) return;
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
              if (skippedInvalid > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '$skippedInvalid row(s) skipped — missing "$_requiredFieldLabel".',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              if (unrecognized.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Ignored columns: ${unrecognized.join(', ')}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...warnings.map((w) => Text(w, style: TextStyle(fontSize: 12, color: Colors.orange[800]))),
              ],
              if (failures.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Failures:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ...failures.take(10).map((f) => Text('• $f', style: const TextStyle(fontSize: 11.5, color: Colors.red))),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: _buildPicker(),
    );
  }

  Widget _buildPicker() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _isWorking ? Icons.cloud_upload_rounded : Icons.upload_file_rounded,
                    size: 34,
                    color: _teal,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _isWorking
                      ? _statusLabel
                      : 'Upload an Excel (.xlsx), CSV (.csv), or text-based PDF (.pdf) '
                      'report. Column headers can be named however your file already '
                      'has them — similar names (e.g. "Qty", "Stock", "Item Name") '
                      'are matched automatically. Scanned/image PDFs aren\'t supported.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _navy, height: 1.4),
                ),
                if (!_isWorking) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Only "$_requiredFieldLabel" is required — every other column is '
                        'optional and falls back to a safe default. '
                        '${_engineConfig != null ? "You'll get a preview before anything is saved." : ""}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.business_rounded, size: 16, color: _navy),
                            const SizedBox(width: 8),
                            const Text('Default branch',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
                            const SizedBox(width: 10),
                            DropdownButton<String>(
                              value: _defaultBranch,
                              isDense: true,
                              underline: const SizedBox.shrink(),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _teal),
                              items: const [
                                DropdownMenuItem(value: 'CDA Admin', child: Text('CDA Admin')),
                                DropdownMenuItem(value: 'CDA Ops', child: Text('CDA Ops')),
                              ],
                              onChanged: (v) => setState(() => _defaultBranch = v ?? 'CDA Admin'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Used only for rows whose Branch cell is blank or unrecognized.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _isWorking
                    ? const CircularProgressIndicator(color: _teal)
                    : SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _pickAndImport,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Choose file & import',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}