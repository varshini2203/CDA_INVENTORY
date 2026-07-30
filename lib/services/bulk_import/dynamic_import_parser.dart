// lib/services/bulk_import/dynamic_import_parser.dart
//
// The parsing half of the Dynamic Bulk Import Engine. Reads an Excel
// (.xlsx), CSV (.csv), or table-based PDF (.pdf) file with NO fixed
// template: the header row is matched against whatever
// `ModuleImportConfig` is passed in, using each field's alias list, so
// "Product", "Name", "Item" and "Item Name" all resolve to the same
// canonical field. Unknown columns are ignored, not rejected. Missing
// optional fields fall back to their configured default. Only required
// fields are validated.
//
// This is a generalized version of the project's existing
// `inventory_import_parser.dart` (same CSV reader, same alias-priority
// matching), reworked to run off a `ModuleImportConfig` instead of being
// hardcoded to the Inventory/`Product` model, so New Products, Stock
// Management and any future module reuse the exact same code path.
//
// Excel parsing reuses the `excel` package already used elsewhere in this
// project (ExcelExportService, BulkImportService); CSV parsing is a small
// hand-rolled RFC4180 reader. PDF parsing (`parsePdf` below) is the ONE
// new addition: `pdf_table_extractor.dart` turns a text-based PDF's pages
// into the exact same `List<List<String>>` shape Excel/CSV already
// produce, so header detection (`_findHeaderRowIndex`), alias matching
// (`_mapHeaders`) and row building (`_buildRow`) below are 100% reused —
// PDF gets no parsing logic of its own, only a different way of arriving
// at rows of cell text. Image-only/scanned PDFs are rejected with a
// dedicated message; see `parsePdf`.

import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/foundation.dart' show debugPrint;

import 'import_field_config.dart';
import 'pdf_table_extractor.dart';

class DynamicImportParser {
  DynamicImportParser._();

  // ── TEMPORARY debug logging ─────────────────────────────────────────────
  // Requirement #5: total worksheets, worksheet name, rows detected, every
  // row read, header row selected, header map generated. Safe to delete
  // once header detection is verified in the field — gated behind one flag
  // so it's a single-line removal.
  static const bool _debugLoggingEnabled = true;

  static void _debugLog(String message) {
    if (_debugLoggingEnabled) {
      debugPrint('[DynamicImportParser] $message');
    }
  }

  // How many leading rows to search for the header row. Requirement #4:
  // don't assume the header is always at a fixed row index.
  static const int _headerScanLimit = 20;

  /// Trims trailing empty cells off a row (kept as its own step from
  /// leading-empty cells, which must NOT be stripped — doing so would
  /// misalign column positions with [headers]/[cells] indices used
  /// downstream in `_buildRow`).
  static List<String> _trimTrailingEmpty(List<String> row) {
    final out = List<String>.from(row);
    while (out.isNotEmpty && out.last.isEmpty) {
      out.removeLast();
    }
    return out;
  }

  /// Scans the first [_headerScanLimit] rows of [allRows] for the header
  /// row (requirement #2 + #4): blank rows before the real header are
  /// skipped, and the row chosen is the first one whose cells actually
  /// match at least one of [config]'s field aliases — not merely "the
  /// first row with any text", which would wrongly grab a title/banner
  /// row sitting above the real headers. If no row matches any alias
  /// (e.g. a completely unfamiliar file), falls back to the first
  /// non-blank row so unrecognized columns still surface instead of a
  /// hard failure.
  ///
  /// Returns -1 if nothing usable was found at all.
  static int _findHeaderRowIndex(
      List<List<String>> allRows,
      ModuleImportConfig config,
      ) {
    final scanLimit =
    allRows.length < _headerScanLimit ? allRows.length : _headerScanLimit;

    for (var r = 0; r < scanLimit; r++) {
      final candidate = _trimTrailingEmpty(allRows[r]);
      if (candidate.isEmpty) continue; // skip empty rows before the header
      if (_mapHeaders(candidate, config).isNotEmpty) return r;
    }

    // Fallback: no row matched a known alias within the scan window — use
    // the first non-blank row so the file still parses (columns will show
    // up as "unrecognized" rather than the import failing outright).
    for (var r = 0; r < scanLimit; r++) {
      if (_trimTrailingEmpty(allRows[r]).isNotEmpty) return r;
    }

    return -1;
  }

  /// Converts one Excel cell's typed value into the plain string this
  /// parser works with everywhere else.
  ///
  /// `excel: ^4.0.6` (see pubspec.yaml) represents cell contents as a
  /// **sealed `CellValue` class** — `TextCellValue`, `IntCellValue`,
  /// `DoubleCellValue`, `BoolCellValue`, `DateCellValue`, `TimeCellValue`,
  /// `DateTimeCellValue`, `FormulaCellValue` — not a plain Dart
  /// String/int/double the way older versions of this package did.
  /// `CellValue.toString()` is only documented/overridden for some of
  /// those subtypes (`TextCellValue` happens to forward to its text); for
  /// the rest it isn't a guaranteed contract, so relying on `.toString()`
  /// silently produces garbage for numeric/date/bool cells instead of
  /// their actual value. Each subtype's real payload is extracted
  /// explicitly instead, exactly the way the `excel` package's own docs
  /// recommend doing via an exhaustive switch.
  static String _cellText(xls.CellValue? value) {
    switch (value) {
      case null:
        return '';
      case xls.TextCellValue():
        return value.value.toString().trim();
      case xls.IntCellValue():
        return value.value.toString();
      case xls.DoubleCellValue():
        return value.value.toString();
      case xls.BoolCellValue():
        return value.value.toString();
      case xls.DateCellValue():
        final y = value.year.toString().padLeft(4, '0');
        final m = value.month.toString().padLeft(2, '0');
        final d = value.day.toString().padLeft(2, '0');
        return '$y-$m-$d';
      case xls.DateTimeCellValue():
        return value.asDateTimeLocal().toIso8601String();
      case xls.TimeCellValue():
        final h = value.hour.toString().padLeft(2, '0');
        final min = value.minute.toString().padLeft(2, '0');
        final s = value.second.toString().padLeft(2, '0');
        return '$h:$min:$s';
      case xls.FormulaCellValue():
      // No cached/computed result is exposed on CellValue — best we can
      // surface is the formula text itself.
        return value.formula;
      default:
        return value.toString().trim();
    }
  }

  // ── Header normalization / matching ─────────────────────────────────────
  static String _normalize(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-./]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Converts a raw column header into a Firestore-safe camelCase field
  /// name, e.g. "Serial No" -> "serialNo", " Price " -> "price". Used as
  /// the key under which an unrecognized column's data is stored in
  /// [ParsedImportRow.extraFields] (and, in turn, under the `extraFields`
  /// map the engine writes to Firestore) — public so the preview screen
  /// can show the exact key a given column will be saved under.
  static String slugifyHeader(String rawHeader) {
    final norm = _normalize(rawHeader);
    final parts = norm.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'field';
    final first = parts.first;
    final rest = parts
        .skip(1)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join();
    return '$first$rest';
  }

  /// Best-effort typed value for a cell going into `extraFields` — numbers
  /// stay numbers instead of every unrecognized column becoming a string,
  /// without imposing a full [ImportValueType] on a column the module
  /// never declared. Returns null for a blank cell (nothing to preserve).
  static dynamic _inferExtraFieldValue(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final asInt = int.tryParse(trimmed);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(trimmed);
    if (asDouble != null) return asDouble;
    return trimmed;
  }

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

    // ── Pass 1: exact match ────────────────────────────────────────────
    // A header cell's normalized text equals one of the field's aliases
    // exactly. This is the strict, previously-only behavior and stays the
    // priority match for well-formed Excel/CSV headers.
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

    // ── Pass 2: whole-word substring fallback ───────────────────────────
    // PDF table reconstruction is geometry-based (see
    // `PdfTableExtractor`): when two adjacent columns' text ends up
    // bucketed into the same cell (narrow price/quantity columns merging,
    // a company letterhead line polluting column-span detection, etc.) a
    // header like "Item Name" can arrive as "Item Name Sale Price
    // Purchase Price Stock Quantity" — a single cell containing several
    // real header labels. Pass 1's exact-equality check would never match
    // that, leaving the whole file's required field unmapped. This pass
    // only runs for headers/fields Pass 1 left unclaimed, and requires the
    // alias to appear as a whole word/phrase (not a random substring) so
    // it doesn't grab unrelated text.
    for (final raw in rawHeaders) {
      if (result.containsKey(raw)) continue;
      final norm = _normalize(raw);
      if (norm.isEmpty) continue;
      final paddedNorm = ' $norm ';

      for (final field in config.fields) {
        if (claimed.contains(field.key)) continue;
        final match = normalizedAliases[field.key]!.any(
              (alias) => alias.isNotEmpty && paddedNorm.contains(' $alias '),
        );
        if (match) {
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

    // Requirement: preserve every column the module didn't explicitly map
    // — instead of dropping it, keyed by a Firestore-safe slug of its raw
    // header. Collisions (two headers slugifying the same, e.g. "Serial
    // No" and "Serial-No") get a numeric suffix so nothing overwrites
    // another column's data.
    final extraFields = <String, dynamic>{};
    final usedSlugs = <String>{};
    for (var c = 0; c < headers.length && c < cells.length; c++) {
      final header = headers[c];
      if (header.isEmpty || headerFieldMap.containsKey(header)) continue;
      final value = _inferExtraFieldValue(cells[c]);
      if (value == null) continue; // blank cell — nothing to preserve

      final baseSlug = slugifyHeader(header);
      var slug = baseSlug;
      var suffix = 2;
      while (!usedSlugs.add(slug)) {
        slug = '$baseSlug$suffix';
        suffix++;
      }
      extraFields[slug] = value;
    }

    return ParsedImportRow(
      sourceRowNumber: sourceRowNumber,
      values: valuesByField,
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      rawData: rawData,
      extraFields: extraFields,
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

    _debugLog(
      'Total worksheets: ${book.tables.length} -> ${book.tables.keys.toList()}',
    );

    if (book.tables.isEmpty) {
      return const ImportParseResult(
        headers: [],
        recognizedHeaders: {},
        unrecognizedHeaders: [],
        rows: [],
        fileWarnings: ['The workbook has no sheets.'],
      );
    }

    // Requirement #1: always the first worksheet, by its actual position
    // in the workbook (Map insertion order == sheet order as decoded by
    // the `excel` package), not by name.
    final sheetName = book.tables.keys.first;
    final sheet = book.tables[sheetName]!;
    _debugLog('Worksheet selected: "$sheetName"');
    _debugLog(
      'Rows detected: maxRows=${sheet.maxRows}, maxColumns=${sheet.maxColumns}',
    );

    if (sheet.maxRows == 0) {
      return const ImportParseResult(
        headers: [],
        recognizedHeaders: {},
        unrecognizedHeaders: [],
        rows: [],
        fileWarnings: ['The first sheet is empty.'],
      );
    }

    // Read every row once, up front, as trimmed strings. This is what lets
    // us both scan multiple candidate header rows (requirement #4) and log
    // every row (requirement #5) without re-reading the sheet repeatedly.
    final allRows = <List<String>>[];
    for (var r = 0; r < sheet.maxRows; r++) {
      final cells = sheet.row(r).map((c) => _cellText(c?.value)).toList();
      allRows.add(cells);
      _debugLog('Row $r: $cells');
    }

    final headerRowIndex = _findHeaderRowIndex(allRows, config);
    _debugLog('Header row selected: index=$headerRowIndex');

    if (headerRowIndex == -1) {
      final scanned =
      allRows.length < _headerScanLimit ? allRows.length : _headerScanLimit;
      return ImportParseResult(
        headers: const [],
        recognizedHeaders: const {},
        unrecognizedHeaders: const [],
        rows: const [],
        fileWarnings: [
          'No header row could be found in the first $scanned row(s) of '
              '"$sheetName".',
        ],
      );
    }

    final headerRow = _trimTrailingEmpty(allRows[headerRowIndex]);
    final headerFieldMap = _mapHeaders(headerRow, config);
    _debugLog('Header map generated: $headerFieldMap');
    final unrecognized =
    headerRow.where((h) => !headerFieldMap.containsKey(h)).toList();

    final rows = <ParsedImportRow>[];
    for (var r = headerRowIndex + 1; r < allRows.length; r++) {
      final cells = allRows[r];
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

    _debugLog('Total worksheets: n/a (CSV)');
    _debugLog('Rows detected: ${table.length}');
    for (var r = 0; r < table.length; r++) {
      _debugLog('Row $r: ${table[r].map((c) => c.trim()).toList()}');
    }

    if (table.isEmpty) {
      return const ImportParseResult(
        headers: [],
        recognizedHeaders: {},
        unrecognizedHeaders: [],
        rows: [],
        fileWarnings: ['The CSV file is empty.'],
      );
    }

    final allRows =
    table.map((r) => r.map((c) => c.trim()).toList()).toList();

    final headerRowIndex = _findHeaderRowIndex(allRows, config);
    _debugLog('Header row selected: index=$headerRowIndex');

    if (headerRowIndex == -1) {
      final scanned =
      allRows.length < _headerScanLimit ? allRows.length : _headerScanLimit;
      return ImportParseResult(
        headers: const [],
        recognizedHeaders: const {},
        unrecognizedHeaders: const [],
        rows: const [],
        fileWarnings: [
          'No header row could be found in the first $scanned row(s).',
        ],
      );
    }

    final headerRow = _trimTrailingEmpty(allRows[headerRowIndex]);
    final headerFieldMap = _mapHeaders(headerRow, config);
    _debugLog('Header map generated: $headerFieldMap');
    final unrecognized =
    headerRow.where((h) => !headerFieldMap.containsKey(h)).toList();

    final rows = <ParsedImportRow>[];
    for (var r = headerRowIndex + 1; r < allRows.length; r++) {
      final cells = allRows[r];
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

  // ── PDF (text-based, table-formatted) ────────────────────────────────────
  // `PdfTableExtractor.extractRows` (see pdf_table_extractor.dart) does all
  // the PDF-specific work — reading every page's text geometry, detecting
  // table columns, merging wrapped multi-line product names, and dropping
  // page-number/Total footer lines — and hands back plain
  // `List<List<String>>` rows, merged across every page into one dataset,
  // in the exact shape `_findHeaderRowIndex` / `_mapHeaders` / `_buildRow`
  // already consume for Excel and CSV. Nothing below this point is
  // PDF-specific parsing logic; it's the same pipeline Excel/CSV run
  // through, plus ONE extra step multi-page PDFs need that a single Excel
  // sheet or CSV file never does: dropping the column header when it
  // repeats on page 2, 3, 4....
  static ImportParseResult parsePdf(
      Uint8List bytes,
      ModuleImportConfig config,
      ) {
    List<List<String>> allRows;
    try {
      allRows = PdfTableExtractor.extractRows(bytes);
    } on ScannedPdfException catch (e) {
      // Requirement: scanned/image-only PDFs get this exact message,
      // surfaced through `fileWarnings` exactly like any other
      // file-level problem (empty workbook, empty CSV, ...).
      return ImportParseResult(
        headers: const [],
        recognizedHeaders: const {},
        unrecognizedHeaders: const [],
        rows: const [],
        fileWarnings: [e.message],
      );
    } catch (e) {
      return ImportParseResult(
        headers: const [],
        recognizedHeaders: const {},
        unrecognizedHeaders: const [],
        rows: const [],
        fileWarnings: ['Could not read this PDF file: $e'],
      );
    }

    _debugLog('Total rows extracted from PDF (all pages merged): ${allRows.length}');
    for (var r = 0; r < allRows.length; r++) {
      _debugLog('Row $r: ${allRows[r]}');
    }

    if (allRows.isEmpty) {
      return const ImportParseResult(
        headers: [],
        recognizedHeaders: {},
        unrecognizedHeaders: [],
        rows: [],
        fileWarnings: ['No table content could be found in this PDF.'],
      );
    }

    // Same header search Excel/CSV use — scans for the first row whose
    // cells match at least one configured field alias, so the header is
    // found automatically regardless of how many title/letterhead lines
    // sit above it on page 1.
    final headerRowIndex = _findHeaderRowIndex(allRows, config);
    _debugLog('Header row selected: index=$headerRowIndex');

    if (headerRowIndex == -1) {
      final scanned =
      allRows.length < _headerScanLimit ? allRows.length : _headerScanLimit;
      return ImportParseResult(
        headers: const [],
        recognizedHeaders: const {},
        unrecognizedHeaders: const [],
        rows: const [],
        fileWarnings: [
          'No table header row could be found in the first $scanned row(s) '
              'of this PDF.',
        ],
      );
    }

    final headerRow = _trimTrailingEmpty(allRows[headerRowIndex]);
    final headerFieldMap = _mapHeaders(headerRow, config);
    _debugLog('Header map generated: $headerFieldMap');
    final unrecognized =
    headerRow.where((h) => !headerFieldMap.containsKey(h)).toList();

    // Normalized header content — used only to recognize the SAME header
    // repeating on page 2, 3, 4... of the PDF, so it's ignored as data
    // rather than becoming a row full of validation errors.
    final normalizedHeaderSignature =
    headerRow.map(_normalize).join('|');

    final rows = <ParsedImportRow>[];
    for (var r = headerRowIndex + 1; r < allRows.length; r++) {
      final cells = allRows[r];
      if (_isBlankRow(cells)) continue;

      final signature =
      _trimTrailingEmpty(cells).map(_normalize).join('|');
      if (signature == normalizedHeaderSignature) {
        continue; // repeated per-page column header — not a data row
      }

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

  /// Entry point — picks the right parser from the file extension.
  /// Excel (.xlsx / .xls), CSV (.csv) and table-based PDF (.pdf) are
  /// supported; all three funnel into the same header-detection,
  /// alias-matching and row-building pipeline above, and all three
  /// produce the same `ImportParseResult` that Preview, Validation,
  /// Duplicate Detection and the Import Engine already consume.
  static ImportParseResult parse(
      Uint8List bytes,
      String filename,
      ModuleImportConfig config,
      ) {
    final ext = filename.toLowerCase().split('.').last;
    if (ext == 'xlsx' || ext == 'xls') return parseExcel(bytes, config);
    if (ext == 'csv') return parseCsvBytes(bytes, config);
    if (ext == 'pdf') return parsePdf(bytes, config);
    return const ImportParseResult(
      headers: [],
      recognizedHeaders: {},
      unrecognizedHeaders: [],
      rows: [],
      fileWarnings: [
        'Unsupported file type — please upload a .xlsx, .csv or .pdf file.',
      ],
    );
  }
}