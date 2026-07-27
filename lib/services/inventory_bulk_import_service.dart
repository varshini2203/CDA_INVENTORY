// lib/services/inventory_bulk_import_service.dart
//
// Commits the `List<Product>` produced by `InventoryImportParser` into the
// app's data model:
//
//   1. Dedupe every row against Product Name + Branch + Row + Rack + Tray.
//      A match updates that document's quantity; no match creates a new
//      Inventory document.
//   2. Writes go through the SAME `inventory` collection / document shape
//      `InventoryService` already uses (built from the existing
//      `InventoryItem` model in models/inventory_model.dart), batched via
//      Firestore `WriteBatch` (chunks of 400 ops) so 1,000+ row files stay
//      fast and stay under Firestore's per-batch write limit.
//   3. After each batch commits, `InventorySyncService.syncFromInventoryAdd`
//      fans the item out to Search Products, the Branch module, Stock
//      Management and Fixed Assets/Consumables — exactly the same
//      cross-module propagation a normal single-item Inventory add gets.
//   4. `ActivityLogService` records one summary entry for the whole run
//      (a 1,000-row import writing 1,000 individual activity-log docs on
//      top of the import itself would swamp both Firestore and the
//      Activity Feed UI for no real benefit).
//   5. One row failing (bad data, a rejected write, ...) never stops the
//      rest of the import — every failure is caught, recorded in
//      `ImportResult.errors`, and the import continues.
//
// SCOPE — this file does NOT touch `InventoryImportParser` (parsing is
// already done by the time a `List<Product>` reaches this service), does
// not render any UI, and does not implement a preview step. The `Product`
// model itself is also left untouched — see the "why branch/row/rack/tray
// are stored as raw extra fields" note above `_PlannedWrite` below.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import '../models/inventory_model.dart';
import 'inventory_service.dart';
import 'inventory_sync_service.dart';
import 'activity_log_service.dart';

// ── Per-row outcome tag ─────────────────────────────────────────────────
enum ImportRowStatus { imported, updated, skipped, failed }

/// One row-level problem surfaced back to the caller. `index` is the row's
/// position in the `List<Product>` that was passed in, so callers can map
/// an error back to the original file row if they want to.
class ImportRowError {
  final int index;
  final String? productName;
  final String message;

  const ImportRowError({
    required this.index,
    required this.productName,
    required this.message,
  });

  @override
  String toString() =>
      'Row $index${productName != null && productName!.isNotEmpty ? ' ($productName)' : ''}: $message';
}

/// Summary returned to the caller once an import finishes. Every input row
/// ends up in exactly one bucket, so `imported + updated + skipped + failed
/// == total`.
class ImportResult {
  final int total;
  final int imported; // brand-new Inventory documents created
  final int updated; // existing documents whose quantity was incremented
  final int skipped; // rows that couldn't be processed at all (e.g. blank name)
  final int failed; // rows whose write attempt threw/was rejected
  final List<ImportRowError> errors;

  const ImportResult({
    required this.total,
    required this.imported,
    required this.updated,
    required this.skipped,
    required this.failed,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() =>
      'ImportResult(total: $total, imported: $imported, updated: $updated, '
          'skipped: $skipped, failed: $failed, errors: ${errors.length})';
}

// ── Internal planning record ────────────────────────────────────────────
// One entry per *unique* (name, branch, row, rack, tray) combination seen
// either already in Firestore or across this import's own rows. Several
// input rows can collapse into a single entry (e.g. the same SKU appearing
// twice in one supplier file, or a row that matches something already in
// Inventory) — exactly one Firestore write happens per entry, never one
// per row, which is what keeps a duplicate-heavy 1,000+ row file cheap.
//
// Why `branch`/`row`/`rack`/`tray` are written as plain extra fields on the
// Firestore document instead of new `Product`/`InventoryItem` fields: the
// task requires the `Product` model stay untouched, and `InventoryItem`
// (models/inventory_model.dart) already has its own stable schema used
// elsewhere in the app. Firestore documents are schemaless, so adding
// `row`/`rack`/`tray`/plain `branch` alongside the fields `InventoryItem`
// already knows about is additive and harmless — `InventoryItem.fromDoc`
// simply ignores keys it doesn't recognize — while still giving this
// service (and any future import) something durable to match against.
class _PlannedWrite {
  final String docId;
  final bool isNew;
  final String name;
  final String category;
  final String? notes;
  final String? row;
  final String? rack;
  final String? tray;
  final int branch;
  int quantity;
  final List<int> rowIndexes;

  _PlannedWrite({
    required this.docId,
    required this.isNew,
    required this.name,
    required this.category,
    required this.notes,
    required this.row,
    required this.rack,
    required this.tray,
    required this.branch,
    required this.quantity,
    required this.rowIndexes,
  });

  String get locationLabel {
    final parts = <String>[
      if ((row ?? '').trim().isNotEmpty) 'Row ${row!.trim()}',
      if ((rack ?? '').trim().isNotEmpty) 'Rack ${rack!.trim()}',
      if ((tray ?? '').trim().isNotEmpty) 'Tray ${tray!.trim()}',
    ];
    return parts.join(' · ');
  }

  Map<String, dynamic> toCreateMap({String? importedBy}) => {
    'name': name,
    'category': category,
    'location': locationLabel,
    'quantity': quantity,
    'description': notes ?? '',
    'branch': branch,
    'addedBy': importedBy,
    'row': row ?? '',
    'rack': rack ?? '',
    'tray': tray ?? '',
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  // Update path intentionally touches ONLY quantity (+ the timestamp) —
  // "If product exists: Update quantity." An existing document's other
  // metadata is left exactly as it was.
  Map<String, dynamic> toUpdateMap() => {
    'quantity': quantity,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class InventoryBulkImportService {
  InventoryBulkImportService._();

  static const String _module = 'Inventory';

  // Firestore hard-caps a WriteBatch at 500 operations; 400 leaves
  // headroom and matches the chunk size InventoryService's own
  // _seedProductsBatch already uses elsewhere in this app.
  static const int _batchSize = 400;

  static final CollectionReference<Map<String, dynamic>> _col =
  FirebaseFirestore.instance.collection('inventory');

  static String _norm(String? s) => (s ?? '').trim().toLowerCase();

  static String _dedupeKey({
    required String name,
    required int branch,
    required String? row,
    required String? rack,
    required String? tray,
  }) =>
      '${_norm(name)}|$branch|${_norm(row)}|${_norm(rack)}|${_norm(tray)}';

  // ═══════════════════════════════════════════════════════════════════
  //  MAIN ENTRY POINT
  // ═══════════════════════════════════════════════════════════════════
  /// Imports [products] (as produced by `InventoryImportParser`) into
  /// Inventory, deduping on Product Name + Branch + Row + Rack + Tray.
  ///
  /// [branch] is required because `Product` itself carries no branch
  /// field (see the note above `_PlannedWrite`) — a single import file
  /// always belongs to one branch, supplied by whatever screen/flow
  /// invokes the import.
  ///
  /// [importedBy] is stored as the `addedBy` field on any newly created
  /// document (existing documents are left untouched on update, per the
  /// "update quantity only" rule above).
  static Future<ImportResult> importProducts(
      List<Product> products, {
        required int branch,
        String? importedBy,
      }) async {
    final total = products.length;
    if (total == 0) {
      return const ImportResult(
        total: 0,
        imported: 0,
        updated: 0,
        skipped: 0,
        failed: 0,
        errors: [],
      );
    }

    // ── 1) Load existing Inventory docs once, up front, and index them
    //       by the same dedupe key we'll use for incoming rows. A single
    //       collection read here is far cheaper than one query per row
    //       for a 1,000+ row import.
    final keyToDocId = <String, String>{};
    final existingQuantity = <String, int>{};
    try {
      final existingSnap = await _col.get();
      for (final doc in existingSnap.docs) {
        final d = doc.data();
        final key = _dedupeKey(
          name: (d['name'] as String?) ?? '',
          branch: (d['branch'] as num?)?.toInt() ?? 0,
          row: d['row'] as String?,
          rack: d['rack'] as String?,
          tray: d['tray'] as String?,
        );
        keyToDocId[key] = doc.id;
        existingQuantity[doc.id] = (d['quantity'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      // Can't safely dedupe without the existing index — fail the whole
      // import up front rather than risk creating 1,000 duplicate docs.
      return ImportResult(
        total: total,
        imported: 0,
        updated: 0,
        skipped: 0,
        failed: total,
        errors: [
          ImportRowError(
            index: -1,
            productName: null,
            message: 'Could not read existing inventory to check for '
                'duplicates: $e',
          ),
        ],
      );
    }

    // ── 2) Walk every row once, resolving it against the index above
    //       (which also absorbs new rows as they're planned, so repeats
    //       *within this same file* correctly become "updated" instead
    //       of separate documents).
    final plan = <String, _PlannedWrite>{};
    final rowStatus = List<ImportRowStatus>.filled(
      total,
      ImportRowStatus.skipped,
    );
    final errors = <ImportRowError>[];

    for (var i = 0; i < products.length; i++) {
      final product = products[i];
      final name = product.name.trim();

      if (name.isEmpty) {
        // Defensive — InventoryImportParser already rejects rows with no
        // Product Name, but a caller could hand this service a raw list
        // built some other way.
        rowStatus[i] = ImportRowStatus.skipped;
        errors.add(ImportRowError(
          index: i,
          productName: null,
          message: 'Skipped — no product name.',
        ));
        continue;
      }

      try {
        final key = _dedupeKey(
          name: name,
          branch: branch,
          row: product.row,
          rack: product.rack,
          tray: product.tray,
        );

        final existingDocId = keyToDocId[key];
        if (existingDocId != null) {
          final entry = plan[existingDocId];
          if (entry != null) {
            // Already queued earlier in THIS import — merge quantity.
            entry.quantity += product.quantity;
            entry.rowIndexes.add(i);
          } else {
            // Matches a document already sitting in Firestore.
            plan[existingDocId] = _PlannedWrite(
              docId: existingDocId,
              isNew: false,
              name: name,
              category: product.category,
              notes: product.notes,
              row: product.row,
              rack: product.rack,
              tray: product.tray,
              branch: branch,
              quantity:
              (existingQuantity[existingDocId] ?? 0) + product.quantity,
              rowIndexes: [i],
            );
          }
          rowStatus[i] = ImportRowStatus.updated;
        } else {
          final newDocId = _col.doc().id; // client-generated, no round trip
          keyToDocId[key] = newDocId;
          plan[newDocId] = _PlannedWrite(
            docId: newDocId,
            isNew: true,
            name: name,
            category: product.category,
            notes: product.notes,
            row: product.row,
            rack: product.rack,
            tray: product.tray,
            branch: branch,
            quantity: product.quantity,
            rowIndexes: [i],
          );
          rowStatus[i] = ImportRowStatus.imported;
        }
      } catch (e) {
        rowStatus[i] = ImportRowStatus.failed;
        errors.add(ImportRowError(index: i, productName: name, message: '$e'));
      }
    }

    // ── 3) Commit the plan in Firestore-batch-sized chunks. A chunk that
    //       fails to commit only fails the rows it covers — every other
    //       chunk still runs.
    final entries = plan.values.toList();
    final syncQueue = <_PlannedWrite>[];

    for (var start = 0; start < entries.length; start += _batchSize) {
      final chunk = entries.sublist(
        start,
        (start + _batchSize).clamp(0, entries.length),
      );
      if (chunk.isEmpty) continue;

      final batch = FirebaseFirestore.instance.batch();
      for (final entry in chunk) {
        final ref = _col.doc(entry.docId);
        if (entry.isNew) {
          batch.set(ref, entry.toCreateMap(importedBy: importedBy));
        } else {
          batch.update(ref, entry.toUpdateMap());
        }
      }

      try {
        await batch.commit();
        syncQueue.addAll(chunk);
      } catch (e) {
        // Whole chunk failed — flip every row it covers to failed and
        // move on to the next chunk instead of aborting the import.
        for (final entry in chunk) {
          for (final rowIndex in entry.rowIndexes) {
            rowStatus[rowIndex] = ImportRowStatus.failed;
          }
          errors.add(ImportRowError(
            index: entry.rowIndexes.first,
            productName: entry.name,
            message: 'Batch write failed: $e',
          ));
        }
      }
    }

    if (syncQueue.isNotEmpty) {
      InventoryService.clearCache();
    }

    // ── 4) Fan each successfully-written item out to every other module.
    //       Isolated per item so one module's failure for one item never
    //       blocks the rest — InventorySyncService already does the same
    //       internal isolation per downstream module.
    for (final entry in syncQueue) {
      try {
        await InventorySyncService.syncFromInventoryAdd(
          InventoryItem(
            id: entry.docId,
            name: entry.name,
            category: entry.category,
            location: entry.locationLabel,
            quantity: entry.quantity,
            description: entry.notes ?? '',
            branch: entry.branch,
            addedBy: importedBy,
          ),
        );
      } catch (e) {
        errors.add(ImportRowError(
          index: entry.rowIndexes.first,
          productName: entry.name,
          message: 'Imported, but cross-module sync failed: $e',
        ));
      }
    }

    // ── 5) One summary log entry for the whole run (not one per row —
    //       see file header for why).
    final imported =
        rowStatus.where((s) => s == ImportRowStatus.imported).length;
    final updated =
        rowStatus.where((s) => s == ImportRowStatus.updated).length;
    final skipped =
        rowStatus.where((s) => s == ImportRowStatus.skipped).length;
    final failed = rowStatus.where((s) => s == ImportRowStatus.failed).length;

    try {
      await ActivityLogService.logAction(
        'Bulk import: $total row(s) — $imported created, $updated updated, '
            '$skipped skipped, $failed failed',
        module: _module,
        details: importedBy != null ? 'Imported by $importedBy' : null,
      );
    } catch (_) {
      // Logging must never fail the import itself.
    }

    return ImportResult(
      total: total,
      imported: imported,
      updated: updated,
      skipped: skipped,
      failed: failed,
      errors: errors,
    );
  }
}