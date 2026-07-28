// lib/screens/bulk_import/bulk_import_preview_screen.dart
//
// Generic Preview step for the Dynamic Bulk Import Engine. Works for ANY
// module — it only knows about `ModuleImportConfig` + `ImportParseResult`,
// never Inventory/New-Products specifics directly. Shows:
//   - how many rows are valid / invalid, and why the invalid ones failed
//   - which columns in the file weren't recognized (ignored, not blocking)
//   - how many rows collide with an existing record vs. with each other
//   - a Skip / Update / Increase Quantity / Replace picker for those
//     collisions
// then commits via `DynamicBulkImportEngine.commit` only once the user
// confirms — nothing is written to Firestore before this screen's "Import"
// button is pressed.

import 'package:flutter/material.dart';

import '../../services/bulk_import/dynamic_bulk_import_engine.dart';
import '../../services/bulk_import/import_field_config.dart';
import '../../services/bulk_import/module_import_configs.dart';

class BulkImportPreviewScreen extends StatefulWidget {
  final ModuleImportConfig config;
  final ImportParseResult parseResult;
  final String fileName;
  final String? importedBy;

  const BulkImportPreviewScreen({
    super.key,
    required this.config,
    required this.parseResult,
    required this.fileName,
    this.importedBy,
  });

  @override
  State<BulkImportPreviewScreen> createState() =>
      _BulkImportPreviewScreenState();
}

class _BulkImportPreviewScreenState extends State<BulkImportPreviewScreen> {
  static const _navy = Color(0xFF0A1628);
  static const _accent = Color(0xFF7B5EA7);

  bool _loadingDuplicates = true;
  bool _isImporting = false;
  Set<String> _existingKeys = {};
  DuplicatePreview? _duplicatePreview;
  DuplicateAction _duplicateAction = DuplicateAction.update;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadDuplicates();
  }

  Future<void> _loadDuplicates() async {
    try {
      final keys = await DynamicBulkImportEngine.fetchExistingDedupeKeys(
        widget.config,
      );
      final preview = DynamicBulkImportEngine.summarizeDuplicates(
        config: widget.config,
        rows: widget.parseResult.rows,
        existingKeys: keys,
      );
      if (!mounted) return;
      setState(() {
        _existingKeys = keys;
        _duplicatePreview = preview;
        _loadingDuplicates = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not check for duplicates: $e';
        _loadingDuplicates = false;
      });
    }
  }

  bool _rowMatchesExisting(ParsedImportRow row) {
    if (!row.isValid) return false;
    final key = widget.config.buildDedupeKey(row.values);
    return _existingKeys.contains(key);
  }

  Future<void> _confirmImport() async {
    setState(() => _isImporting = true);

    final result = await DynamicBulkImportEngine.commit(
      config: widget.config,
      rows: widget.parseResult.validRows,
      duplicateAction: _duplicateAction,
      importedBy: widget.importedBy,
    );

    await logBulkImportSummary(
      config: widget.config,
      total: widget.parseResult.rows.length,
      created: result.created,
      updated: result.updated,
      skipped: result.skipped +
          (widget.parseResult.rows.length - widget.parseResult.validCount),
      failed: result.failed,
      importedBy: widget.importedBy,
    );

    if (!mounted) return;
    setState(() => _isImporting = false);
    await _showResultDialog(result);
    if (!mounted) return;
    Navigator.pop(context, result);
  }

  Future<void> _showResultDialog(ImportCommitResult result) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(result.created + result.updated > 0
            ? 'Import complete'
            : 'Nothing imported'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.config.moduleLabel} — ${widget.fileName}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('${result.created} created'),
              Text('${result.updated} updated'),
              if (result.skipped > 0) Text('${result.skipped} skipped'),
              if (result.failed > 0) Text('${result.failed} failed'),
              if (result.warnings.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Warnings:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                ...result.warnings.take(10).map(
                      (w) => Text('• $w', style: const TextStyle(fontSize: 12)),
                ),
              ],
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Errors:',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
                ...result.errors.take(10).map(
                      (e) => Text('• $e',
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
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

  @override
  Widget build(BuildContext context) {
    final parse = widget.parseResult;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text('Preview — ${widget.config.moduleLabel}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: _isImporting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(parse),
          const SizedBox(height: 12),
          if (parse.unrecognizedHeaders.isNotEmpty)
            _buildUnrecognizedCard(parse),
          const SizedBox(height: 12),
          _buildDuplicateCard(),
          const SizedBox(height: 12),
          _buildRowsCard(parse),
          const SizedBox(height: 90),
        ],
      ),
      bottomNavigationBar: _isImporting
          ? null
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: parse.validCount == 0 ? null : _confirmImport,
            icon: const Icon(Icons.cloud_upload_rounded),
            label: Text('Import ${parse.validCount} row(s)'),
            style: FilledButton.styleFrom(
              backgroundColor: _navy,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ImportParseResult parse) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.fileName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            Text('${parse.rows.length} row(s) found — '
                '${parse.validCount} ready to import, '
                '${parse.invalidCount} need attention.'),
            if (parse.fileWarnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...parse.fileWarnings.map(
                    (w) => Text(w, style: TextStyle(color: Colors.orange[800], fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUnrecognizedCard(ImportParseResult parse) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ignored columns',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              'These columns didn\'t match any known field for '
                  '${widget.config.moduleLabel} and were left out — nothing else '
                  'is affected.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: parse.unrecognizedHeaders
                  .map((h) => Chip(label: Text(h, style: const TextStyle(fontSize: 11))))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDuplicateCard() {
    if (_loadingDuplicates) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Checking for duplicates…'),
            ],
          ),
        ),
      );
    }

    if (_loadError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_loadError!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    final preview = _duplicatePreview!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Duplicates',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              preview.total == 0
                  ? 'No duplicates found — every row will be created as a new record.'
                  : '${preview.matchedAgainstExisting} row(s) match an existing record; '
                  '${preview.matchedWithinFile} row(s) repeat within this file. '
                  'Choose what to do with them:',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (preview.total > 0) ...[
              const SizedBox(height: 10),
              ...DuplicateAction.values.map(
                    (action) => RadioListTile<DuplicateAction>(
                  value: action,
                  groupValue: _duplicateAction,
                  onChanged: (v) => setState(() => _duplicateAction = v!),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: _accent,
                  title: Text(action.label,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(action.description, style: const TextStyle(fontSize: 11.5)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRowsCard(ImportParseResult parse) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rows',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            ...parse.rows.take(200).map(_buildRowTile),
            if (parse.rows.length > 200)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Showing the first 200 of ${parse.rows.length} rows — every row '
                      'is still imported when you confirm.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowTile(ParsedImportRow row) {
    final title = (row.values[widget.config.titleFieldKey] ?? '').toString();
    final isDuplicate = _rowMatchesExisting(row);

    Color statusColor;
    String statusLabel;
    if (!row.isValid) {
      statusColor = Colors.red;
      statusLabel = 'Invalid';
    } else if (isDuplicate) {
      statusColor = Colors.orange;
      statusLabel = 'Duplicate';
    } else {
      statusColor = Colors.green;
      statusLabel = 'New';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.isEmpty ? 'Row ${row.sourceRowNumber}' : title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Row ${row.sourceRowNumber}',
              style: TextStyle(fontSize: 10.5, color: Colors.grey[500])),
          if (!row.isValid)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(row.errors.join(' '),
                  style: const TextStyle(fontSize: 11.5, color: Colors.red)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 10,
                runSpacing: 2,
                children: widget.config.fields
                    .where((f) =>
                f.key != widget.config.titleFieldKey &&
                    row.values[f.key] != null &&
                    row.values[f.key].toString().trim().isNotEmpty)
                    .take(6)
                    .map(
                      (f) => Text(
                    '${f.label}: ${row.values[f.key]}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                )
                    .toList(),
              ),
            ),
          if (row.warnings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(row.warnings.join(' '),
                  style: TextStyle(fontSize: 10.5, color: Colors.orange[800])),
            ),
        ],
      ),
    );
  }
}