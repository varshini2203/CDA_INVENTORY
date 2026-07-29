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
//
// ── Theme note ────────────────────────────────────────────────────────
// Every color on this screen is set explicitly (via `AppColors` + the
// local constants below) instead of relying on inherited `Theme`/`Card`
// defaults. Text widgets with no explicit color pull whatever the
// ambient Theme's default text color is — invisible if this screen is
// ever pushed under a dark ThemeData while its own background stays
// light (or vice versa). Explicit colors make this screen look the same
// regardless of what theme the rest of the app is using at the time.

import 'package:flutter/material.dart';

import '../../shared/inventory_ui.dart';
import '../../services/bulk_import/dynamic_bulk_import_engine.dart';
import '../../services/bulk_import/dynamic_import_parser.dart';
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
  // ── Explicit design tokens for this screen ──────────────────────────
  // Reuses the app's shared AppColors (navy/teal/coral/amber/green) so
  // this screen matches the Purchases/Bills/etc. visual language, plus a
  // couple of local shades for text hierarchy on white cards.
  static const _navy = AppColors.navy;
  static const _accent = AppColors.teal;
  static const _cardBg = Colors.white;
  static const _textPrimary = AppColors.navy;
  static const _textSecondary = Color(0xFF6B7686);
  static const _border = Color(0xFFE3E8EF);

  bool _loadingDuplicates = true;
  bool _isImporting = false;
  int _fanOutDone = 0;
  int _fanOutTotal = 0;
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
    setState(() {
      _isImporting = true;
      _fanOutDone = 0;
      _fanOutTotal = 0;
    });

    final result = await DynamicBulkImportEngine.commit(
      config: widget.config,
      rows: widget.parseResult.validRows,
      duplicateAction: _duplicateAction,
      importedBy: widget.importedBy,
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() {
          _fanOutDone = done;
          _fanOutTotal = total;
        });
      },
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
        backgroundColor: _cardBg,
        title: Text(
          result.created + result.updated > 0
              ? 'Import complete'
              : 'Nothing imported',
          style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.config.moduleLabel} — ${widget.fileName}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: _textPrimary)),
              const SizedBox(height: 8),
              Text('${result.created} created', style: const TextStyle(color: _textPrimary)),
              Text('${result.updated} updated', style: const TextStyle(color: _textPrimary)),
              if (result.skipped > 0)
                Text('${result.skipped} skipped', style: const TextStyle(color: _textPrimary)),
              if (result.failed > 0)
                Text('${result.failed} failed', style: const TextStyle(color: _textPrimary)),
              if (result.warnings.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Warnings:',
                    style: TextStyle(fontWeight: FontWeight.w600, color: _textPrimary)),
                ...result.warnings.take(10).map(
                      (w) => Text('• $w',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900)),
                ),
              ],
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Errors:',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.coral)),
                ...result.errors.take(10).map(
                      (e) => Text('• $e',
                      style: const TextStyle(fontSize: 12, color: AppColors.coral)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: _accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parse = widget.parseResult;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Preview — ${widget.config.moduleLabel}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white)),
      ),
      body: _isImporting
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _accent),
            const SizedBox(height: 16),
            Text(
              _fanOutTotal > 0
                  ? 'Syncing across modules — $_fanOutDone / $_fanOutTotal'
                  : 'Importing…',
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ],
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(parse),
          const SizedBox(height: 12),
          if (parse.recognizedHeaders.isNotEmpty || parse.unrecognizedHeaders.isNotEmpty)
            _buildColumnMappingCard(parse),
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
              foregroundColor: Colors.white,
              disabledBackgroundColor: _navy.withOpacity(0.35),
              disabledForegroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: _cardBg,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: _border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  Widget _buildSummaryCard(ImportParseResult parse) {
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.fileName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _textPrimary)),
          const SizedBox(height: 8),
          Text(
            '${parse.rows.length} row(s) found — '
                '${parse.validCount} ready to import, '
                '${parse.invalidCount} need attention.',
            style: const TextStyle(color: _textPrimary),
          ),
          if (parse.fileWarnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...parse.fileWarnings.map(
                  (w) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(w,
                    style: TextStyle(color: Colors.amber.shade900, fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColumnMappingCard(ImportParseResult parse) {
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Column mapping',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _textPrimary)),
          const SizedBox(height: 4),
          Text(
            'Every column in this file is kept — recognized columns map '
                'to ${widget.config.moduleLabel} fields; everything else is '
                'still saved, as a custom field on each record.',
            style: const TextStyle(fontSize: 12, color: _textSecondary),
          ),
          if (parse.recognizedHeaders.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Mapped to known fields',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: parse.recognizedHeaders.entries.map((e) {
                final label = widget.config.fieldByKey(e.value)?.label ?? e.value;
                return Chip(
                  backgroundColor: AppColors.green.withOpacity(0.12),
                  side: BorderSide(color: AppColors.green.withOpacity(0.3)),
                  label: Text('${e.key} → $label',
                      style: const TextStyle(fontSize: 11, color: _textPrimary)),
                );
              }).toList(),
            ),
          ],
          if (parse.unrecognizedHeaders.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Saved as custom fields',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: parse.unrecognizedHeaders.map((h) {
                final slug = DynamicImportParser.slugifyHeader(h);
                return Chip(
                  backgroundColor: _accent.withOpacity(0.10),
                  side: BorderSide(color: _accent.withOpacity(0.3)),
                  label: Text('$h → extraFields.$slug',
                      style: const TextStyle(fontSize: 11, color: _textPrimary)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDuplicateCard() {
    if (_loadingDuplicates) {
      return Container(
        decoration: _cardDecoration,
        padding: const EdgeInsets.all(16),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
            ),
            SizedBox(width: 12),
            Text('Checking for duplicates…', style: TextStyle(color: _textPrimary)),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return Container(
        decoration: _cardDecoration,
        padding: const EdgeInsets.all(16),
        child: Text(_loadError!, style: const TextStyle(color: AppColors.coral)),
      );
    }

    final preview = _duplicatePreview!;
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Duplicates',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _textPrimary)),
          const SizedBox(height: 4),
          Text(
            preview.total == 0
                ? 'No duplicates found — every row will be created as a new record.'
                : '${preview.matchedAgainstExisting} row(s) match an existing record; '
                '${preview.matchedWithinFile} row(s) repeat within this file. '
                'Choose what to do with them:',
            style: const TextStyle(fontSize: 12, color: _textSecondary),
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
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
                subtitle: Text(action.description,
                    style: const TextStyle(fontSize: 11.5, color: _textSecondary)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRowsCard(ImportParseResult parse) {
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rows',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _textPrimary)),
          const SizedBox(height: 8),
          ...parse.rows.take(200).map(_buildRowTile),
          if (parse.rows.length > 200)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Showing the first 200 of ${parse.rows.length} rows — every row '
                    'is still imported when you confirm.',
                style: const TextStyle(fontSize: 11.5, color: _textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRowTile(ParsedImportRow row) {
    final title = (row.values[widget.config.titleFieldKey] ?? '').toString();
    final isDuplicate = _rowMatchesExisting(row);

    Color statusColor;
    String statusLabel;
    if (!row.isValid) {
      statusColor = AppColors.coral;
      statusLabel = 'Invalid';
    } else if (isDuplicate) {
      statusColor = AppColors.amber;
      statusLabel = 'Duplicate';
    } else {
      statusColor = AppColors.green;
      statusLabel = 'New';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _border),
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
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
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
              style: const TextStyle(fontSize: 10.5, color: _textSecondary)),
          if (!row.isValid)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(row.errors.join(' '),
                  style: const TextStyle(fontSize: 11.5, color: AppColors.coral)),
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
                    style: const TextStyle(fontSize: 11, color: _textSecondary),
                  ),
                )
                    .toList(),
              ),
            ),
          if (row.warnings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(row.warnings.join(' '),
                  style: TextStyle(fontSize: 10.5, color: Colors.amber.shade900)),
            ),
          if (row.isValid && row.extraFields.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 10,
                runSpacing: 2,
                children: row.extraFields.entries
                    .map(
                      (e) => Text(
                    '${e.key}: ${e.value}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: _accent),
                  ),
                )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}