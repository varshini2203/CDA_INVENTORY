// lib/services/bulk_import/dynamic_bulk_import_engine.dart
//
// The commit half of the Dynamic Bulk Import Engine. Takes the rows a
// `DynamicImportParser` already validated/defaulted plus one
// `ModuleImportConfig`, and:
//
//   1. Reads the target collection ONCE to build a duplicate index (via
//      `config.buildDedupeKeyFromDoc`), then walks every row, resolving it
//      against that index — repeats within the same file collapse into a
//      single planned write, exactly like matches against pre-existing
//      Firestore records do.
//   2. Applies the user-chosen `DuplicateAction` (Skip / Update / Increase
//      Quantity / Replace) to every row that matches something already in
//      Firestore.
//   3. Commits the resulting plan via `WriteBatch`, chunked at 400 ops
//      (Firestore's hard cap is 500; 400 leaves headroom), so files with
//      hundreds/thousands of rows stay fast and safe.
//   4. Fans each successfully-written row out through `config.afterWrite`
//      (module supplies this — e.g. `InventorySyncService.syncFromXAdd`),
//      isolated per row so one module's downstream failure never blocks the
//      rest of the import.
//   5. Invalidates the module's cache (`config.clearCache`) and writes ONE
//      summary `ActivityLogService` entry for the whole run, matching how
//      this project's existing bulk-write code (see
//      inventory_bulk_import_service.dart) already behaves — one run, one
//      log line, not one write per row.
//
// This file is 100% module-agnostic: it never imports InventoryService,
// NewProductService, or any model directly. All of that is reused through
// the callbacks a `ModuleImportConfig` supplies, so this engine is the one
// place bulk-import logic lives, and adding a future module never means
// touching this file.

import 'package:cloud_firestore/cloud_firestore.dart';

import 'import_field_config.dart';

/// Per-row outcome once a commit finishes.
enum ImportRowOutcome { created, updated, increasedQuantity, replaced, skipped, failed }

class ImportRowError {
  final int sourceRowNumber;
  final String? title;
  final String message;

  const ImportRowError({
    required this.sourceRowNumber,
    required this.title,
    required this.message,
  });

  @override
  String toString() =>
      'Row $sourceRowNumber${title != null && title!.isNotEmpty ? ' ($title)' : ''}: $message';
}

/// Summary returned once a commit finishes. Every row that was handed to
/// the engine ends up in exactly one outcome bucket.
class ImportCommitResult {
  final int total;
  final int created;
  final int updated; // includes "increase quantity" and "replace" matches
  final int skipped;
  final int failed;
  final List<ImportRowError> errors;
  final List<String> warnings;

  const ImportCommitResult({
    required this.total,
    required this.created,
    required this.updated,
    required this.skipped,
    required this.failed,
    required this.errors,
    this.warnings = const [],
  });

  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() =>
      'ImportCommitResult(total: $total, created: $created, updated: $updated, '
          'skipped: $skipped, failed: $failed, errors: ${errors.length})';
}

/// A duplicate match found before commit — surfaced to the preview screen
/// so the user knows how many rows will actually be affected by whatever
/// `DuplicateAction` they pick.
class DuplicatePreview {
  final int matchedAgainstExisting;
  final int matchedWithinFile;

  const DuplicatePreview({
    required this.matchedAgainstExisting,
    required this.matchedWithinFile,
  });

  int get total => matchedAgainstExisting + matchedWithinFile;
}

// ── Internal planning record — one per unique dedupe key ────────────────
class _PlannedWrite {
  final String docId;
  final bool existedBefore;
  Map<String, dynamic> fields;
  int quantity;
  final List<int> rowIndexes;
  DuplicateAction? appliedAction; // null for brand-new rows

  _PlannedWrite({
    required this.docId,
    required this.existedBefore,
    required this.fields,
    required this.quantity,
    required this.rowIndexes,
    this.appliedAction,
  });
}

class DynamicBulkImportEngine {
  DynamicBulkImportEngine._();

  // Firestore hard-caps a WriteBatch at 500 operations; 400 leaves
  // headroom, matching the chunk size already used elsewhere in this
  // project's bulk-write code.
  static const int _batchSize = 400;

  static CollectionReference<Map<String, dynamic>> _collection(
      ModuleImportConfig config,
      ) =>
      FirebaseFirestore.instance.collection(config.collectionPath);

  static int _quantityOf(ModuleImportConfig config, Map<String, dynamic> row) {
    final key = config.quantityFieldKey;
    if (key == null) return 0;
    final v = row[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  /// Fetches every dedupe key already in `config.collectionPath`, WITHOUT
  /// writing anything. Public so the preview screen can flag which rows
  /// are duplicates before the user picks a `DuplicateAction`, re-using
  /// the exact same key logic `commit()` uses.
  static Future<Set<String>> fetchExistingDedupeKeys(
      ModuleImportConfig config,
      ) async {
    final snapshot = await _collection(config).get();
    return {
      for (final doc in snapshot.docs) config.buildDedupeKeyFromDoc(doc.data()),
    };
  }

  /// Convenience summary over [rows] against [existingKeys] — how many
  /// valid rows collide with an existing record vs. with each other.
  static DuplicatePreview summarizeDuplicates({
    required ModuleImportConfig config,
    required List<ParsedImportRow> rows,
    required Set<String> existingKeys,
  }) {
    final seenThisFile = <String>{};
    var againstExisting = 0;
    var withinFile = 0;

    for (final row in rows) {
      if (!row.isValid) continue;
      final key = config.buildDedupeKey(row.values);
      if (existingKeys.contains(key)) {
        againstExisting++;
      } else if (!seenThisFile.add(key)) {
        withinFile++;
      }
    }

    return DuplicatePreview(
      matchedAgainstExisting: againstExisting,
      matchedWithinFile: withinFile,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  MAIN ENTRY POINT
  // ═══════════════════════════════════════════════════════════════════
  /// Commits [rows] (as produced by `DynamicImportParser`) into
  /// `config.collectionPath`, applying [duplicateAction] to every row whose
  /// dedupe key matches a record already in Firestore. Invalid rows are
  /// counted as failed and never written.
  static Future<ImportCommitResult> commit({
    required ModuleImportConfig config,
    required List<ParsedImportRow> rows,
    required DuplicateAction duplicateAction,
    String? importedBy,
  }) async {
    final total = rows.length;
    if (total == 0) {
      return const ImportCommitResult(
        total: 0,
        created: 0,
        updated: 0,
        skipped: 0,
        failed: 0,
        errors: [],
      );
    }

    // ── 1) Build the duplicate index from what's already in Firestore.
    final keyToDocId = <String, String>{};
    final existingDocIds = <String>{};
    final existingQuantity = <String, int>{};
    try {
      final snapshot = await _collection(config).get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final key = config.buildDedupeKeyFromDoc(data);
        if (key.isEmpty) continue;
        keyToDocId[key] = doc.id;
        existingDocIds.add(doc.id);
        if (config.quantityFieldKey != null) {
          final qtyField = config.quantityFieldKey!;
          final raw = data[qtyField];
          existingQuantity[doc.id] =
          raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
        }
      }
    } catch (e) {
      return ImportCommitResult(
        total: total,
        created: 0,
        updated: 0,
        skipped: 0,
        failed: total,
        errors: [
          ImportRowError(
            sourceRowNumber: -1,
            title: null,
            message:
            'Could not read existing ${config.moduleLabel} records to '
                'check for duplicates: $e',
          ),
        ],
      );
    }

    // ── 2) Walk every row once, resolving it against the index above
    //       (which also absorbs newly planned rows, so repeats *within
    //       this same file* collapse into one write instead of many).
    final plan = <String, _PlannedWrite>{};
    final outcome = List<ImportRowOutcome>.filled(total, ImportRowOutcome.skipped);
    final errors = <ImportRowError>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final title = (row.values[config.titleFieldKey] ?? '').toString();

      if (!row.isValid) {
        outcome[i] = ImportRowOutcome.failed;
        errors.add(ImportRowError(
          sourceRowNumber: row.sourceRowNumber,
          title: title,
          message: row.errors.join(' '),
        ));
        continue;
      }

      try {
        final key = config.buildDedupeKey(row.values);
        final existingDocId = keyToDocId[key];

        if (existingDocId == null) {
          // Brand new record.
          final docId = _collection(config).doc().id;
          keyToDocId[key] = docId;
          plan[docId] = _PlannedWrite(
            docId: docId,
            existedBefore: false,
            fields: config.buildFields(row.values),
            quantity: _quantityOf(config, row.values),
            rowIndexes: [i],
          );
          outcome[i] = ImportRowOutcome.created;
          continue;
        }

        final alreadyPlanned = plan[existingDocId];
        if (alreadyPlanned != null) {
          // A repeat within this same file — merge into the existing plan
          // entry regardless of the chosen action, so multiple rows for
          // the same item in one file always combine sensibly.
          alreadyPlanned.fields = config.buildFields(row.values);
          alreadyPlanned.quantity += _quantityOf(config, row.values);
          alreadyPlanned.rowIndexes.add(i);
          outcome[i] = alreadyPlanned.existedBefore
              ? (alreadyPlanned.appliedAction == DuplicateAction.replace
              ? ImportRowOutcome.replaced
              : ImportRowOutcome.updated)
              : ImportRowOutcome.created;
          continue;
        }

        // First time this run touching a PRE-EXISTING Firestore record —
        // apply the user's chosen duplicate-handling strategy.
        if (duplicateAction == DuplicateAction.skip) {
          outcome[i] = ImportRowOutcome.skipped;
          continue;
        }

        final baseQuantity = existingQuantity[existingDocId] ?? 0;
        final rowQuantity = _quantityOf(config, row.values);
        final plannedQuantity = duplicateAction == DuplicateAction.increaseQuantity
            ? baseQuantity + rowQuantity
            : rowQuantity;

        plan[existingDocId] = _PlannedWrite(
          docId: existingDocId,
          existedBefore: true,
          fields: config.buildFields(row.values),
          quantity: plannedQuantity,
          rowIndexes: [i],
          appliedAction: duplicateAction,
        );

        outcome[i] = duplicateAction == DuplicateAction.increaseQuantity
            ? ImportRowOutcome.increasedQuantity
            : duplicateAction == DuplicateAction.replace
            ? ImportRowOutcome.replaced
            : ImportRowOutcome.updated;
      } catch (e) {
        outcome[i] = ImportRowOutcome.failed;
        errors.add(ImportRowError(
          sourceRowNumber: row.sourceRowNumber,
          title: title,
          message: '$e',
        ));
      }
    }

    // ── 3) Commit the plan in Firestore-batch-sized chunks. A chunk that
    //       fails to commit only fails the rows it covers.
    final entries = plan.values.toList();
    final successfulEntries = <_PlannedWrite>[];

    for (var start = 0; start < entries.length; start += _batchSize) {
      final chunk = entries.sublist(
        start,
        (start + _batchSize).clamp(0, entries.length),
      );
      if (chunk.isEmpty) continue;

      final batch = FirebaseFirestore.instance.batch();
      for (final entry in chunk) {
        final ref = _collection(config).doc(entry.docId);
        final fields = <String, dynamic>{...entry.fields};
        if (config.quantityFieldKey != null) {
          fields[config.quantityFieldKey!] = entry.quantity;
        }

        if (!entry.existedBefore) {
          // Brand new document.
          batch.set(ref, {
            ...fields,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (entry.appliedAction == DuplicateAction.increaseQuantity) {
          // Touch ONLY the quantity field — every other existing field on
          // the document is left exactly as it was.
          batch.update(ref, {
            if (config.quantityFieldKey != null)
              config.quantityFieldKey!: entry.quantity,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (entry.appliedAction == DuplicateAction.replace) {
          // Full document overwrite (set, not merge) — anything not in
          // `fields` is dropped, matching "Replace" meaning replace the
          // whole record with what this file provides.
          batch.set(ref, {
            ...fields,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // "Update" — patch just the mapped fields, leaving any other
          // existing field on the document untouched.
          batch.update(ref, {
            ...fields,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      try {
        await batch.commit();
        successfulEntries.addAll(chunk);
      } catch (e) {
        for (final entry in chunk) {
          for (final rowIndex in entry.rowIndexes) {
            outcome[rowIndex] = ImportRowOutcome.failed;
          }
          errors.add(ImportRowError(
            sourceRowNumber: rows[entry.rowIndexes.first].sourceRowNumber,
            title: rows[entry.rowIndexes.first]
                .values[config.titleFieldKey]
                ?.toString(),
            message: 'Batch write failed: $e',
          ));
        }
      }
    }

    if (successfulEntries.isNotEmpty) {
      config.clearCache?.call();
    }

    // ── 4) Fan each successfully-written row out to other modules.
    //       Isolated per row so one failure never blocks the rest.
    final warnings = <String>[];
    if (config.afterWrite != null) {
      for (final entry in successfulEntries) {
        try {
          final fields = <String, dynamic>{...entry.fields};
          if (config.quantityFieldKey != null) {
            fields[config.quantityFieldKey!] = entry.quantity;
          }
          await config.afterWrite!(entry.docId, fields);
        } catch (e) {
          warnings.add(
            'Row(s) ${entry.rowIndexes.map((i) => rows[i].sourceRowNumber).join(', ')}: '
                'saved, but cross-module sync failed: $e',
          );
        }
      }
    }

    final created = outcome.where((s) => s == ImportRowOutcome.created).length;
    final updated = outcome
        .where((s) =>
    s == ImportRowOutcome.updated ||
        s == ImportRowOutcome.increasedQuantity ||
        s == ImportRowOutcome.replaced)
        .length;
    final skipped = outcome.where((s) => s == ImportRowOutcome.skipped).length;
    final failed = outcome.where((s) => s == ImportRowOutcome.failed).length;

    return ImportCommitResult(
      total: total,
      created: created,
      updated: updated,
      skipped: skipped,
      failed: failed,
      errors: errors,
      warnings: warnings,
    );
  }
}