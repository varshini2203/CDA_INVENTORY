// lib/services/bulk_import/dynamic_import_parser.dart
//
// The parsing half of the Dynamic Bulk Import Engine. Reads an Excel
// (.xlsx) or CSV (.csv) file with NO fixed template: the header row is
// matched against whatever `ModuleImportConfig` is passed in, using each
// field's alias list, so "Product", "Name", "Item" and "Item Name" all
// resolve to the same canonical field. Unknown columns are ignored, not
// rejected. Missing optional fields fall back to their configured default.
// Only required fields are validated.
//
// This is a generalized version of the project's existing
// `inventory_import_parser.dart` (same CSV reader, same alias-priority
// matching), reworked to run off a `ModuleImportConfig` instead of being
// hardcoded to the Inventory/`Product` model, so New Products, Stock
// Management and any future module reuse the exact same code path.
//
// No new package dependency: Excel parsing reuses the `excel` package
// already used elsewhere in this project (ExcelExportService,
// BulkImportService); CSV parsing is a small hand-rolled RFC4180 reader.

import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;

import 'import_field_config.dart';

class DynamicImportParser {
  DynamicImportParser._();

  // ── Header normalization / matching ─────────────────────────────────────
  static String _normalize(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-./]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Maps raw header text -> canonical field key, honoring [config.fields]
  /// order as match priority so each field is claimed by at most one
  /// column (e.g. if a sheet has both "Product Name" and "Description",
  /// "Description" won't be stolen by the Name field even though some
  /// modules also accept "Description" as a Name alias).
  static Map<String, String> _mapHeaders(
      List<String> rawHeaders,
      ModuleImportConfig config,
      ) {
    final normalizedAliases = <String, Set<String>>{
      for (final f in config.fields) f.key: f.aliases.map(_normalize).toSet(),
    };

    final claimed = <String>{};
    final result = <String, String>{};

    for (final raw in rawHeaders) {
      final norm = _normalize(raw);
      if (norm.isEmpty) continue;

      for (final field in config.fields) {
        if (claimed.contains(field.key)) continue;
        if (normalizedAliases[field.key]!.contains(norm)) {
          result[raw] = field.key;
          claimed.add(field.key);
          break;
        }
      }
    }

    return result;
  }

  // ── Typed value parsing ─────────────────────────────────────────────────
  static String _cleanNumeric(String raw) =>
      raw.replaceAll(RegExp(r'[^0-9.\-]'), '');

  static DateTime? _tryParseLooseDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;
    // Handles common spreadsheet formats like "24/07/2026" or "24-07-2026"
    // that DateTime.tryParse (ISO-8601 only) doesn't understand. Assumes
    // day/month/year, the common non-US spreadsheet convention used
    // throughout this app's other bulk-import code.
    final parts = trimmed.split(RegExp(r'[/\-.]'));
    if (parts.length != 3) return null;
    final numbers = parts.map((p) => int.tryParse(p.trim())).toList();
    if (numbers.any((n) => n == null)) return null;
    try {
      return DateTime(numbers[2]!, numbers[1]!, numbers[0]!);
    } catch (_) {
      return null;
    }
  }

  /// Parses one raw cell against [field]'s type, falling back to
  /// [field]'s configured default when the cell is blank/unparseable and
  /// the field isn't required. Appends a warning (not an error) when a
  /// non-blank cell couldn't be parsed and had to fall back to a default.
  static dynamic _parseCell(
      String raw,
      ImportFieldConfig field,
      List<String> warnings,
      ) {
    final trimmed = raw.trim();

    switch (field.type) {
      case ImportValueType.text:
        if (trimmed.isNotEmpty) return trimmed;
        return field.resolveDefault();

      case ImportValueType.integer:
        if (trimmed.isEmpty) return field.resolveDefault();
        final cleaned = _cleanNumeric(trimmed);
        final asDouble = cleaned.isEmpty ? null : double.tryParse(cleaned);
        if (asDouble == null) {
          warnings.add(
            '"${field.label}" value "$raw" is not a number — used the default instead.',
          );
          return field.resolveDefault();
        }
        return asDouble.round();

      case ImportValueType.decimal:
        if (trimmed.isEmpty) return field.resolveDefault();
        final cleaned = _cleanNumeric(trimmed);
        final asDouble = cleaned.isEmpty ? null : double.tryParse(cleaned);
        if (asDouble == null) {
          warnings.add(
            '"${field.label}" value "$raw" is not a number — used the default instead.',
          );
          return field.resolveDefault();
        }
        return asDouble;

      case ImportValueType.date:
        if (trimmed.isEmpty) return field.resolveDefault();
        final parsed = _tryParseLooseDate(trimmed);
        if (parsed == null) {
          warnings.add(
            '"${field.label}" value "$raw" could not be read as a date — used the default instead.',
          );
          return field.resolveDefault();
        }
        return parsed;
    }
  }

  static bool _isBlank(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    return false;
  }

  /// Builds one [ParsedImportRow] from a raw cell-text row, validating
  /// only [config.requiredFields] and defaulting every other configured
  /// field automatically.
  static ParsedImportRow _buildRow({
    required int sourceRowNumber,
    required List<String> headers,
    required List<String> cells,
    required Map<String, String> headerFieldMap,
    required ModuleImportConfig config,
  }) {
    final rawData = <String, String>{};
    for (var c = 0; c < headers.length && c < cells.length; c++) {
      rawData[headers[c]] = cells[c];
    }

    // raw header -> matched field key, restricted to headers present on
    // this row so we know which raw cell feeds which field.
    final valuesByField = <String, dynamic>{};
    final warnings = <String>[];

    for (final entry in headerFieldMap.entries) {
      final field = config.fieldByKey(entry.value);
      if (field == null) continue;
      final raw = rawData[entry.key] ?? '';
      valuesByField[field.key] = _parseCell(raw, field, warnings);
    }

    // Any configured field with no matching column at all (not just a
    // blank cell) still needs its default applied.
    for (final field in config.fields) {
      if (!valuesByField.containsKey(field.key)) {
        valuesByField[field.key] = field.resolveDefault();
      }
    }

    final errors = <String>[];
    for (final field in config.requiredFields) {
      if (_isBlank(valuesByField[field.key])) {
        errors.add('${field.label} is required.');
      }
    }

    return ParsedImportRow(
      sourceRowNumber: sourceRowNumber,
      values: valuesByField,
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      rawData: rawData,
    );
  }

  static bool _isBlankRow(List<String> cells) =>
      cells.every((c) => c.trim().isEmpty);

  // ── EXCEL (.xlsx) ────────────────────────────────────────────────────────
  static ImportParseResult parseExcel(
      Uint8List bytes,
      ModuleImportConfig config,
      ) {
    late final xls.Excel book;
    try {
      book = xls.Excel.decodeBytes(bytes);
    } catch (e) {
      return ImportParseResult(
        headers: const [],
        recognizedHeaders: const {},
        unrecognizedHeaders: const [],
        rows: const [],
        fileWarnings: ['Could not read this Excel file: $e'],
      );
    }

    if (book.tables.isEmpty) {
      return const ImportParseResult(
        headers: [],
        recognizedHeaders: {},
        unrecognizedHeaders: [],
        rows: [],
        fileWarnings: ['The workbook has no sheets.'],
      );
    }

    final sheet = book.tables[book.tables.keys.first]!;
    if (sheet.maxRows == 0) {
      return const ImportParseResult(
        headers: [],
        recognizedHeaders: {},
        unrecognizedHeaders: [],
        rows: [],
        fileWarnings: ['The first sheet is empty.'],
      );
    }

    final headerRow =
    sheet.row(0).map((c) => (c?.value ?? '').toString().trim()).toList();
    while (headerRow.isNotEmpty && headerRow.last.isEmpty) {
      headerRow.removeLast();
    }

    if (headerRow.isEmpty) {
      return const ImportParseResult(
        headers: [],
        recognizedHeaders: {},
        unrecognizedHeaders: [],
        rows: [],
        fileWarnings: ['No header row could be found.'],
      );
    }

    final headerFieldMap = _mapHeaders(headerRow, config);
    final unrecognized =
    headerRow.where((h) => !headerFieldMap.containsKey(h)).toList();

    final rows = <ParsedImportRow>[];
    for (var r = 1; r < sheet.maxRows; r++) {
      final cells = sheet
          .row(r)
          .map((c) => (c?.value ?? '').toString().trim())
          .toList();
      if (_isBlankRow(cells)) continue;

      rows.add(_buildRow(
        sourceRowNumber: r + 1,
        headers: headerRow,
        cells: cells,
        headerFieldMap: headerFieldMap,
        config: config,
      ));
    }

    return ImportParseResult(
      headers: headerRow,
      recognizedHeaders: headerFieldMap,
      unrecognizedHeaders: unrecognized,
      rows: rows,
    );
  }

  // ── CSV ────────────────────────────────────────────────────────────────
  // Hand-rolled RFC4180-style reader (quoted fields, commas/newlines inside
  // quotes, escaped "" quotes, CRLF/LF line endings, optional UTF-8 BOM) so
  // this parser doesn't need an extra `csv` package dependency.
  static List<List<String>> _parseCsvContent(String content) {
    final text =
    content.startsWith('\ufeff') ? content.substring(1) : content;
    final rows = <List<String>>[];
    var field = StringBuffer();
    var record = <String>[];
    var inQuotes = false;
    var i = 0;
    final len = text.length;

    void endField() {
      record.add(field.toString());
      field = StringBuffer();
    }

    void endRecord() {
      endField();
      rows.add(record);
      record = <String>[];
    }

    while (i < len) {
      final ch = text[i];

      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < len && text[i + 1] == '"') {
            field.write('"');
            i += 2;
            continue;
          }
          inQuotes = false;
          i++;
          continue;
        }
        field.write(ch);
        i++;
        continue;
      }

      if (ch == '"') {
        inQuotes = true;
        i++;
        continue;
      }
      if (ch == ',') {
        endField();
        i++;
        continue;
      }
      if (ch == '\r') {
        if (i + 1 < len && text[i + 1] == '\n') {
          endRecord();
          i += 2;
          continue;
        }
        endRecord();
        i++;
        continue;
      }
      if (ch == '\n') {
        endRecord();
        i++;
        continue;
      }
      field.write(ch);
      i++;
    }

    if (field.isNotEmpty || record.isNotEmpty) {
      endRecord();
    }

    return rows;
  }

  static ImportParseResult parseCsvString(
      String content,
      ModuleImportConfig config,
      ) {
    final table = _parseCsvContent(content)
        .where((r) => r.isNotEmpty && r.any((c) => c.trim().isNotEmpty))
        .toList();

    if (table.isEmpty) {
      return const ImportParseResult(
        headers: [],
        recognizedHeaders: {},
        unrecognizedHeaders: [],
        rows: [],
        fileWarnings: ['The CSV file is empty.'],
      );
    }

    final headerRow = table.first.map((h) => h.trim()).toList();
    while (headerRow.isNotEmpty && headerRow.last.isEmpty) {
      headerRow.removeLast();
    }
    if (headerRow.isEmpty) {
      return const ImportParseResult(
        headers: [],
        recognizedHeaders: {},
        unrecognizedHeaders: [],
        rows: [],
        fileWarnings: ['No header row could be found.'],
      );
    }

    final headerFieldMap = _mapHeaders(headerRow, config);
    final unrecognized =
    headerRow.where((h) => !headerFieldMap.containsKey(h)).toList();

    final rows = <ParsedImportRow>[];
    for (var r = 1; r < table.length; r++) {
      final cells = table[r].map((c) => c.trim()).toList();
      if (_isBlankRow(cells)) continue;

      rows.add(_buildRow(
        sourceRowNumber: r + 1,
        headers: headerRow,
        cells: cells,
        headerFieldMap: headerFieldMap,
        config: config,
      ));
    }

    return ImportParseResult(
      headers: headerRow,
      recognizedHeaders: headerFieldMap,
      unrecognizedHeaders: unrecognized,
      rows: rows,
    );
  }

  static ImportParseResult parseCsvBytes(
      Uint8List bytes,
      ModuleImportConfig config,
      ) {
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      // Fall back for CSVs saved in a legacy locale encoding.
      content = latin1.decode(bytes);
    }
    return parseCsvString(content, config);
  }

  /// Entry point — picks the right parser from the file extension.
  /// Only Excel (.xlsx / .xls) and CSV (.csv) are supported.
  static ImportParseResult parse(
      Uint8List bytes,
      String filename,
      ModuleImportConfig config,
      ) {
    final ext = filename.toLowerCase().split('.').last;
    if (ext == 'xlsx' || ext == 'xls') return parseExcel(bytes, config);
    if (ext == 'csv') return parseCsvBytes(bytes, config);
    return const ImportParseResult(
      headers: [],
      recognizedHeaders: {},
      unrecognizedHeaders: [],
      rows: [],
      fileWarnings: [
        'Unsupported file type — please upload a .xlsx or .csv file.',
      ],
    );
  }
}