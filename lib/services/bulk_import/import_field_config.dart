// lib/services/bulk_import/import_field_config.dart
//
// Shared types for the Dynamic Bulk Import Engine (dynamic_import_parser.dart
// + dynamic_bulk_import_engine.dart). This file has NO Firestore / UI code —
// it only describes the *shape* of a module's import contract, so a new
// module (Consumables, Fixed Assets, Purchase Orders, ...) can plug into the
// same engine by writing one `ModuleImportConfig`, nothing else.
//
// Per the requirements, each module configures exactly three things:
//   1. Required fields  -> ImportFieldConfig(required: true)
//   2. Optional fields   -> ImportFieldConfig(required: false, default...)
//   3. Firestore collection -> ModuleImportConfig.collectionPath
// Everything else (alias matching, defaulting, dedupe, batching) lives in
// the engine and is shared by every module.

/// How a cell's raw text should be interpreted/parsed.
enum ImportValueType { text, integer, decimal, date }

/// One canonical field a module wants recognized from an uploaded file.
///
/// [aliases] should include every header spelling a real-world file might
/// use for this field (the matching itself is case/punctuation-insensitive,
/// so 'Qty', 'qty', 'Qty.' and 'QTY' all match the alias 'qty' automatically
/// — you don't need to list every casing/format variant).
class ImportFieldConfig {
  /// Internal key used everywhere downstream (parsed row maps, dedupe keys,
  /// `buildFields`). Never shown to the user.
  final String key;

  /// Human-readable label used in the preview screen and in error/warning
  /// messages (e.g. "Product Name is required").
  final String label;

  /// Header aliases this field should match, e.g. for Product Name:
  /// ['product name', 'product', 'name', 'item', 'item name'].
  /// Matching normalizes case/whitespace/punctuation, so entries here can be
  /// written in plain lower-case with spaces.
  final List<String> aliases;

  /// Required fields block a row from being imported when blank.
  /// Optional fields silently fall back to [defaultValue] /
  /// [defaultValueBuilder].
  final bool required;

  final ImportValueType type;

  /// Static fallback used when the column is missing entirely, or the cell
  /// is blank, and [required] is false. Leave null to defer defaulting to
  /// the module's `buildFields` (useful when the right default depends on
  /// another field in the same row, e.g. "Available Qty" defaulting to
  /// "Quantity").
  final dynamic defaultValue;

  /// Same as [defaultValue] but computed fresh per row (e.g.
  /// `() => DateTime.now()`), for defaults that can't be a compile-time
  /// constant. Takes priority over [defaultValue] when both are set.
  final dynamic Function()? defaultValueBuilder;

  const ImportFieldConfig({
    required this.key,
    required this.label,
    required this.aliases,
    this.required = false,
    this.type = ImportValueType.text,
    this.defaultValue,
    this.defaultValueBuilder,
  });

  dynamic resolveDefault() {
    if (defaultValueBuilder != null) return defaultValueBuilder!();
    return defaultValue;
  }
}

/// One parsed data row, keyed by canonical [ImportFieldConfig.key] — never
/// by raw header text. Unknown columns never make it into [values]; they're
/// surfaced separately by the parser as "unrecognized headers".
class ParsedImportRow {
  /// 1-based row number as it appeared in the source file (header counts as
  /// row 1, so the first data row is row 2) — used in error messages.
  final int sourceRowNumber;

  /// canonical field key -> typed value (String / int / double / DateTime),
  /// already defaulted for any optional field that was missing or blank.
  final Map<String, dynamic> values;

  final bool isValid;

  /// Populated only when [isValid] is false — always a missing/blank
  /// required field.
  final List<String> errors;

  /// Non-fatal issues (e.g. "Quantity" cell wasn't a number, defaulted to
  /// 0). The row is still imported.
  final List<String> warnings;

  /// Raw header -> raw cell text, untouched, exactly as read from the file.
  /// Kept so the preview screen can show/edit the original text.
  final Map<String, String> rawData;

  /// Data for every column in the uploaded file that did NOT match any of
  /// the module's configured field aliases, keyed by a Firestore-safe
  /// camelCase slug derived from the raw header (e.g. "Serial No" ->
  /// "serialNo"). Nothing from the file is ever silently dropped: a
  /// recognized column ends up in [values]; anything else ends up here and
  /// is written to Firestore under an `extraFields` map by
  /// `DynamicBulkImportEngine`, instead of being ignored.
  final Map<String, dynamic> extraFields;

  const ParsedImportRow({
    required this.sourceRowNumber,
    required this.values,
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.rawData,
    this.extraFields = const {},
  });

  ParsedImportRow copyWithValues(Map<String, dynamic> newValues) =>
      ParsedImportRow(
        sourceRowNumber: sourceRowNumber,
        values: newValues,
        isValid: isValid,
        errors: errors,
        warnings: warnings,
        rawData: rawData,
        extraFields: extraFields,
      );
}

/// Full result of parsing one file against one [ModuleImportConfig].
class ImportParseResult {
  /// Raw header text, exactly as found in row 1 of the file.
  final List<String> headers;

  /// raw header text -> matched canonical field key, for headers that were
  /// recognized (directly or via alias).
  final Map<String, String> recognizedHeaders;

  /// raw header text that didn't match any configured field. These are no
  /// longer dropped — every row's cell data for these columns is preserved
  /// in [ParsedImportRow.extraFields] and written to Firestore under an
  /// `extraFields` map by the engine. Surfaced here purely so the preview
  /// screen can show the user which columns were auto-mapped vs. saved as
  /// custom fields; never blocks the import.
  final List<String> unrecognizedHeaders;

  /// One entry per non-empty data row, in file order.
  final List<ParsedImportRow> rows;

  /// File-level problems (empty file, no sheets, no header row, ...).
  final List<String> fileWarnings;

  const ImportParseResult({
    required this.headers,
    required this.recognizedHeaders,
    required this.unrecognizedHeaders,
    required this.rows,
    this.fileWarnings = const [],
  });

  bool get isEmpty => rows.isEmpty;

  List<ParsedImportRow> get validRows => rows.where((r) => r.isValid).toList();

  List<ParsedImportRow> get invalidRows =>
      rows.where((r) => !r.isValid).toList();

  int get validCount => rows.where((r) => r.isValid).length;

  int get invalidCount => rows.length - validCount;
}

/// What to do when an incoming row's dedupe key matches a record that
/// already exists in Firestore.
enum DuplicateAction { skip, update, increaseQuantity, replace }

extension DuplicateActionLabel on DuplicateAction {
  String get label {
    switch (this) {
      case DuplicateAction.skip:
        return 'Skip';
      case DuplicateAction.update:
        return 'Update';
      case DuplicateAction.increaseQuantity:
        return 'Increase Quantity';
      case DuplicateAction.replace:
        return 'Replace';
    }
  }

  String get description {
    switch (this) {
      case DuplicateAction.skip:
        return 'Leave the existing record untouched; ignore this row.';
      case DuplicateAction.increaseQuantity:
        return 'Add this row\'s quantity on top of the existing quantity.';
      case DuplicateAction.update:
        return 'Overwrite the matched fields with the values from this file.';
      case DuplicateAction.replace:
        return 'Fully replace the existing record with this row.';
    }
  }
}

/// The single per-module contract the Dynamic Bulk Import Engine runs
/// against. A new module is added by writing ONE of these — no engine code
/// changes required.
class ModuleImportConfig {
  /// Stable identifier, e.g. 'inventory', 'newProducts'. Used as a map key
  /// and in log messages — never shown verbatim in the UI (see
  /// [moduleLabel]).
  final String moduleKey;

  /// Display name, e.g. "Inventory", "New Products".
  final String moduleLabel;

  /// Target Firestore collection, e.g. 'inventory', 'new_products'.
  final String collectionPath;

  /// Every field this module recognizes from an uploaded file. Order here
  /// is also the order fields appear in the preview.
  final List<ImportFieldConfig> fields;

  /// Canonical key of the field used as each row's headline in the preview
  /// list (e.g. 'name' / 'productName').
  final String titleFieldKey;

  /// Canonical key of the quantity field, or null if this module has no
  /// quantity concept. Required for the "Increase Quantity" duplicate
  /// action to be meaningful.
  final String? quantityFieldKey;

  /// Builds the dedupe identity for an incoming row (already-typed
  /// canonical values). Two rows/documents with the same key are treated
  /// as the same record.
  final String Function(Map<String, dynamic> row) buildDedupeKey;

  /// Builds the same dedupe identity from a raw Firestore document map, so
  /// incoming rows can be matched against what's already stored.
  final String Function(Map<String, dynamic> docData) buildDedupeKeyFromDoc;

  /// Converts a canonical row into the exact Firestore field map the
  /// module's own model/service would write (re-using the model's field
  /// names/shape). Must NOT include `createdAt`/`updatedAt` — the engine
  /// stamps those uniformly.
  final Map<String, dynamic> Function(Map<String, dynamic> row) buildFields;

  /// Optional hook run once per successfully-written row, after the batch
  /// commit succeeds — this is where existing cross-module services
  /// (InventorySyncService, ActivityLogService, cache invalidation, ...)
  /// get reused instead of reimplemented. Failures here are caught by the
  /// engine and reported as warnings; they never fail the import.
  final Future<void> Function(String docId, Map<String, dynamic> fields)?
  afterWrite;

  /// Reuses the module's existing in-memory cache invalidation
  /// (`InventoryService.clearCache`, `NewProductService.clearCache`, ...)
  /// so screens refresh correctly after a bulk import, exactly like they do
  /// after a normal single-item add.
  final void Function()? clearCache;

  const ModuleImportConfig({
    required this.moduleKey,
    required this.moduleLabel,
    required this.collectionPath,
    required this.fields,
    required this.titleFieldKey,
    required this.buildDedupeKey,
    required this.buildDedupeKeyFromDoc,
    required this.buildFields,
    this.quantityFieldKey,
    this.afterWrite,
    this.clearCache,
  });

  ImportFieldConfig? fieldByKey(String key) {
    for (final f in fields) {
      if (f.key == key) return f;
    }
    return null;
  }

  List<ImportFieldConfig> get requiredFields =>
      fields.where((f) => f.required).toList();
}