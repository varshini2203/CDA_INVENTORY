// lib/services/inventory_import_parser.dart
//
// Dynamic Excel (.xlsx) / CSV importer for CDA Inventory.
//
// Reads the header row of a supplier / ERP / manually-created spreadsheet
// and matches each column against a set of known aliases (Product Name,
// Category, Quantity, Unit, Branch, Row, Rack, Tray, Price, Description)
// instead of requiring a fixed column layout. Remaining data rows are
// converted into the existing `Product` model.
//
// SCOPE — this file ONLY parses a file into `Product` objects (plus
// per-row validation / additionalData). It intentionally does NOT:
//   - write to Firestore
//   - render any preview UI
//   - sync anything
// Wiring this into a screen/service that actually saves the result is
// left for a separate change.
//
// No new package dependencies are required: Excel parsing reuses the
// `excel` package already used by ExcelExportService / BulkImportService,
// and CSV parsing is a small hand-rolled RFC4180-style reader.

import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;

import '../models/product.dart';

/// One canonical inventory field the importer knows how to recognize.
enum InventoryField {
  name,
  category,
  quantity,
  unit,
  branch,
  row,
  rack,
  tray,
  price,
  description,
}

/// The outcome of importing a single data row.
class InventoryImportRow {
  /// 1-based row number as it appears in the source file, counting the
  /// header as row 1 (so the first data row is row 2). Handy for error
  /// messages like "Row 5: missing product name".
  final int sourceRowNumber;

  /// The parsed Product, or null when [isValid] is false.
  final Product? product;

  final bool isValid;

  /// Why the row was rejected. Empty when [isValid] is true.
  final List<String> errors;

  /// Non-fatal issues (e.g. quantity/price text couldn't be parsed and
  /// was defaulted). The row is still valid/imported.
  final List<String> warnings;

  /// Recognized-but-unmodeled columns (Branch, Unit — the `Product`
  /// model has no fields for these) plus any column that didn't match a
  /// known alias at all, keyed by the *original* header text exactly as
  /// it appeared in the file. Nothing is ever discarded — everything
  /// that isn't written straight onto `Product` ends up here.
  final Map<String, dynamic> additionalData;

  /// The raw header -> cell text for this row, untouched. Useful if a
  /// caller wants to build its own preview/editor later.
  final Map<String, String> rawData;

  const InventoryImportRow({
    required this.sourceRowNumber,
    required this.product,
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.additionalData,
    required this.rawData,
  });
}

/// Full result of importing one file.
class InventoryImportResult {
  /// Raw header text, exactly as found in row 1 of the file.
  final List<String> headers;

  /// raw header text -> matched [InventoryField], for headers that were
  /// recognized (via exact match or alias).
  final Map<String, InventoryField> recognizedHeaders;

  /// raw header text that didn't match any known field/alias.
  final List<String> unrecognizedHeaders;

  /// One entry per non-empty data row, in file order (empty rows are
  /// skipped entirely and never appear here).
  final List<InventoryImportRow> rows;

  /// File-level problems (empty file, no sheets, no header row, ...).
  final List<String> fileWarnings;

  const InventoryImportResult({
    required this.headers,
    required this.recognizedHeaders,
    required this.unrecognizedHeaders,
    required this.rows,
    this.fileWarnings = const [],
  });

  bool get isEmpty => rows.isEmpty;

  /// Successfully parsed products, ready to hand to whatever service
  /// eventually persists them (Firestore, local db, etc). That wiring is
  /// intentionally NOT part of this parser.
  List<Product> get products =>
      rows.where((r) => r.isValid).map((r) => r.product!).toList();

  List<InventoryImportRow> get invalidRows =>
      rows.where((r) => !r.isValid).toList();

  int get validCount => rows.where((r) => r.isValid).length;

  int get invalidCount => rows.length - validCount;
}

class InventoryImportParser {
  InventoryImportParser._();

  // ── Known aliases, per canonical field ─────────────────────────────────
  // Header text is normalized (lower-cased, trimmed, punctuation
  // collapsed to spaces) before matching, so "Rack_No", "rack-no" and
  // "Rack No." all match the same alias as "Rack No".
  static const Map<InventoryField, List<String>> _aliases = {
    InventoryField.name: [
      'product',
      'product name',
      'item',
      'item name',
      'material',
      'description',
      'name',
    ],
    InventoryField.category: [
      'category',
      'type',
      'product category',
    ],
    InventoryField.quantity: [
      'qty',
      'quantity',
      'stock',
      'available qty',
    ],
    InventoryField.unit: [
      'unit',
      'uom',
      'units',
    ],
    InventoryField.branch: [
      'branch',
      'location',
      'warehouse',
    ],
    InventoryField.row: [
      'row',
      'shelf row',
    ],
    InventoryField.rack: [
      'rack',
      'rack no',
      'rack number',
    ],
    InventoryField.tray: [
      'tray',
      'bin',
      'drawer',
      'shelf',
    ],
    InventoryField.price: [
      'price',
      'cost',
      'unit price',
      'purchase price',
    ],
    InventoryField.description: [
      'description',
      'remarks',
      'notes',
    ],
  };

  /// Order in which a header is offered to each field when more than one
  /// field's alias list could match it — e.g. "Description" appears
  /// under both Product Name and Description above. Earlier fields get
  /// first pick; once a field has been claimed by one header, later
  /// headers fall through to the next candidate instead of overwriting
  /// it.
  ///
  /// In practice this means: a sheet whose only descriptive column is
  /// "Description" (no explicit "Product Name"/"Item"/... column) treats
  /// it as the product name — a reasonable fallback for suppliers who
  /// only ever fill in one free-text column. A sheet that has *both* a
  /// "Product Name" and a separate "Description" column keeps them
  /// distinct, since "Product Name" claims the name field first and
  /// "Description" then falls through to the description field.
  static const List<InventoryField> _matchPriority = [
    InventoryField.name,
    InventoryField.category,
    InventoryField.quantity,
    InventoryField.unit,
    InventoryField.branch,
    InventoryField.row,
    InventoryField.rack,
    InventoryField.tray,
    InventoryField.price,
    InventoryField.description,
  ];

  static String _normalize(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-./]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Maps raw header text -> [InventoryField], honoring [_matchPriority]
  /// so each field is claimed by at most one column.
  static Map<String, InventoryField> _mapHeaders(List<String> rawHeaders) {
    final normalizedAliases = <InventoryField, Set<String>>{
      for (final e in _aliases.entries) e.key: e.value.map(_normalize).toSet(),
    };

    final claimed = <InventoryField>{};
    final result = <String, InventoryField>{};

    for (final raw in rawHeaders) {
      final norm = _normalize(raw);
      if (norm.isEmpty) continue;

      for (final field in _matchPriority) {
        if (claimed.contains(field)) continue;
        if (normalizedAliases[field]!.contains(norm)) {
          result[raw] = field;
          claimed.add(field);
          break;
        }
      }
    }

    return result;
  }

  // ── Numeric helpers ─────────────────────────────────────────────────────
  // Strips currency symbols / thousands separators before parsing, so
  // "₹1,250.00", "$1250" and "1250" all parse the same way.
  static String _cleanNumeric(String raw) =>
      raw.replaceAll(RegExp(r'[^0-9.\-]'), '');

  static int _parseQuantity(String raw, List<String> warnings) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 0; // "If Quantity is empty, default to 0."
    final cleaned = _cleanNumeric(trimmed);
    final asDouble = cleaned.isEmpty ? null : double.tryParse(cleaned);
    if (asDouble == null) {
      warnings.add('Quantity "$raw" is not a number — defaulted to 0.');
      return 0;
    }
    return asDouble.round();
  }

  static double _parsePrice(String raw, List<String> warnings) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 0.0;
    final cleaned = _cleanNumeric(trimmed);
    final value = cleaned.isEmpty ? null : double.tryParse(cleaned);
    if (value == null) {
      warnings.add('Price "$raw" is not a number — defaulted to 0.');
      return 0.0;
    }
    return value;
  }

  // ── Row builder (shared by Excel + CSV) ─────────────────────────────────
  // [cells] is already aligned to [headers] positionally (missing
  // trailing cells are treated as empty strings, extra trailing cells
  // beyond the header count are ignored — same behaviour as the header
  // row itself).
  static InventoryImportRow _buildRow({
    required int sourceRowNumber,
    required List<String> headers,
    required List<String> cells,
    required Map<String, InventoryField> headerFieldMap,
  }) {
    final rawData = <String, String>{};
    for (var c = 0; c < headers.length; c++) {
      rawData[headers[c]] = c < cells.length ? cells[c] : '';
    }

    final warnings = <String>[];
    final additionalData = <String, dynamic>{};

    String? name;
    String category = '';
    String quantityRaw = '';
    String priceRaw = '';
    String? notes;
    String? row;
    String? rack;
    String? tray;

    rawData.forEach((header, value) {
      final field = headerFieldMap[header];
      if (field == null) {
        // Truly unknown column — preserved verbatim, never discarded.
        if (value.trim().isNotEmpty) additionalData[header] = value.trim();
        return;
      }
      switch (field) {
        case InventoryField.name:
          name = value.trim();
          break;
        case InventoryField.category:
          category = value.trim();
          break;
        case InventoryField.quantity:
          quantityRaw = value.trim();
          break;
        case InventoryField.unit:
        // Recognized, but `Product` has no `unit` field — preserved.
          if (value.trim().isNotEmpty) additionalData['unit'] = value.trim();
          break;
        case InventoryField.branch:
        // Recognized, but `Product` has no `branch` field — preserved.
          if (value.trim().isNotEmpty) {
            additionalData['branch'] = value.trim();
          }
          break;
        case InventoryField.row:
          row = value.trim();
          break;
        case InventoryField.rack:
          rack = value.trim();
          break;
        case InventoryField.tray:
          tray = value.trim();
          break;
        case InventoryField.price:
          priceRaw = value.trim();
          break;
        case InventoryField.description:
          notes = value.trim();
          break;
      }
    });

    final errors = <String>[];
    if (name == null || name!.isEmpty) {
      errors.add('Product Name is missing.');
    }

    if (errors.isNotEmpty) {
      return InventoryImportRow(
        sourceRowNumber: sourceRowNumber,
        product: null,
        isValid: false,
        errors: errors,
        warnings: warnings,
        additionalData: additionalData,
        rawData: rawData,
      );
    }

    final quantity = _parseQuantity(quantityRaw, warnings);
    final price = _parsePrice(priceRaw, warnings);

    final product = Product(
      id: '', // not persisted here — assigned by whatever saves it later
      name: name!,
      category: category,
      quantity: quantity,
      price: price,
      notes: (notes != null && notes!.isNotEmpty) ? notes : null,
      row: (row != null && row!.isNotEmpty) ? row : null,
      rack: (rack != null && rack!.isNotEmpty) ? rack : null,
      tray: (tray != null && tray!.isNotEmpty) ? tray : null,
    );

    return InventoryImportRow(
      sourceRowNumber: sourceRowNumber,
      product: product,
      isValid: true,
      errors: errors,
      warnings: warnings,
      additionalData: additionalData,
      rawData: rawData,
    );
  }

  static bool _isBlankRow(List<String> cells) =>
      cells.every((c) => c.trim().isEmpty);

  // ── EXCEL (.xlsx) ────────────────────────────────────────────────────────
  static InventoryImportResult parseExcel(Uint8List bytes) {
    late final xls.Excel book;
    try {
      book = xls.Excel.decodeBytes(bytes);
    } catch (e) {
      return InventoryImportResult(
        headers: const [],
        recognizedHeaders: const {},
        unrecognizedHeaders: const [],
        rows: const [],
        fileWarnings: ['Could not read this Excel file: $e'],
      );
    }

    if (book.tables.isEmpty) {
      return const InventoryImportResult(
        headers: [],
        recognizedHeaders: {},
        unrecognizedHeaders: [],
        rows: [],
        fileWarnings: ['The workbook has no sheets.'],
      );
    }

    final sheet = book.tables[book.tables.keys.first]!;
    if (sheet.maxRows == 0) {
      return const InventoryImportResult(
        headers: [],
        recognizedHeaders: {},
        unrecognizedHeaders: [],
        rows: [],
        fileWarnings: ['The first sheet is empty.'],
      );
    }

    final headerRow =
    sheet.row(0).map((c) => (c?.value ?? '').toString().trim()).toList();

    // Drop trailing completely-empty header cells (common in exports
    // that carry extra formatted-but-unused columns).
    while (headerRow.isNotEmpty && headerRow.last.isEmpty) {
      headerRow.removeLast();
    }

    if (headerRow.isEmpty) {
      return const InventoryImportResult(
        headers: [],
        recognizedHeaders: {},
        unrecognizedHeaders: [],
        rows: [],
        fileWarnings: ['No header row could be found.'],
      );
    }

    final headerFieldMap = _mapHeaders(headerRow);
    final unrecognized =
    headerRow.where((h) => !headerFieldMap.containsKey(h)).toList();

    final rows = <InventoryImportRow>[];
    for (var r = 1; r < sheet.maxRows; r++) {
      final cells = sheet
          .row(r)
          .map((c) => (c?.value ?? '').toString().trim())
          .toList();

      if (_isBlankRow(cells)) continue; // ignore empty rows

      rows.add(_buildRow(
        sourceRowNumber: r + 1, // header occupies row 1
        headers: headerRow,
        cells: cells,
        headerFieldMap: headerFieldMap,
      ));
    }

    return InventoryImportResult(
      headers: headerRow,
      recognizedHeaders: headerFieldMap,
      unrecognizedHeaders: unrecognized,
      rows: rows,
    );
  }

  // ── CSV ────────────────────────────────────────────────────────────────
  // Hand-rolled RFC4180-style reader (quoted fields, commas/newlines
  // inside quotes, escaped "" quotes, CRLF/LF line endings, optional
  // UTF-8 BOM) so this importer doesn't need an extra `csv` package
  // dependency on top of what the project already ships with.
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

    // Last field/record when the file doesn't end with a newline.
    if (field.isNotEmpty || record.isNotEmpty) {
      endRecord();
    }

    return rows;
  }

  static InventoryImportResult parseCsvString(String content) {
    final table = _parseCsvContent(content)
        .where((r) => r.isNotEmpty && r.any((c) => c.trim().isNotEmpty))
        .toList();

    if (table.isEmpty) {
      return const InventoryImportResult(
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
      return const InventoryImportResult(
        headers: [],
        recognizedHeaders: {},
        unrecognizedHeaders: [],
        rows: [],
        fileWarnings: ['No header row could be found.'],
      );
    }

    final headerFieldMap = _mapHeaders(headerRow);
    final unrecognized =
    headerRow.where((h) => !headerFieldMap.containsKey(h)).toList();

    final rows = <InventoryImportRow>[];
    for (var r = 1; r < table.length; r++) {
      final cells = table[r].map((c) => c.trim()).toList();
      if (_isBlankRow(cells)) continue; // ignore empty rows

      rows.add(_buildRow(
        sourceRowNumber: r + 1,
        headers: headerRow,
        cells: cells,
        headerFieldMap: headerFieldMap,
      ));
    }

    return InventoryImportResult(
      headers: headerRow,
      recognizedHeaders: headerFieldMap,
      unrecognizedHeaders: unrecognized,
      rows: rows,
    );
  }

  static InventoryImportResult parseCsvBytes(Uint8List bytes) {
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      // Fall back for CSVs saved in a legacy locale encoding.
      content = latin1.decode(bytes);
    }
    return parseCsvString(content);
  }

  // ── Entry point — picks the right parser from the file extension ───────
  static InventoryImportResult parse(Uint8List bytes, String filename) {
    final ext = filename.toLowerCase().split('.').last;
    if (ext == 'xlsx' || ext == 'xls') return parseExcel(bytes);
    if (ext == 'csv') return parseCsvBytes(bytes);
    return const InventoryImportResult(
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