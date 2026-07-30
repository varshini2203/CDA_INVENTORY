// lib/services/inventory_bulk_operations_service.dart
//
// Bulk-operations backend for the CDA Inventory module: bulk price update,
// bulk delete, bulk category change, bulk branch transfer, and bulk export
// (Excel / PDF / CSV) over a multi-selected set of `InventoryItem`s.
//
// Design notes (mirrors the conventions already established by
// InventoryService / ProductService / InventoryBulkImportService — see
// those files for the same patterns in use elsewhere in this app):
//
//   * All writes go through Firestore `WriteBatch`, chunked at 400 ops
//     (comfortably under Firestore's 500-writes-per-batch hard limit —
//     same chunk size InventoryService._seedProductsBatch already uses).
//   * Every write path clears `InventoryService`'s static in-memory cache
//     afterwards so the dashboard's next `getInventory()` call re-reads
//     fresh data instead of serving stale cached items.
//   * Every bulk action writes exactly ONE `ActivityLogService.logAction`
//     summary line for the whole run (not one log entry per item) — the
//     same reasoning `InventoryBulkImportService` already documents: a
//     500-item bulk action writing 500 individual activity-log docs would
//     swamp both Firestore and the Activity Feed UI for no real benefit.
//   * `InventoryItem` (models/inventory_model.dart) is NOT modified. Price
//     is not a field that model knows about, so it's read/written as a
//     plain extra Firestore field ('price') the exact same way
//     InventoryBulkImportService already stores 'row'/'rack'/'tray' as
//     extra fields alongside what InventoryItem recognizes —
//     `InventoryItem.fromDoc` simply ignores keys it doesn't parse, so
//     this is purely additive and never conflicts with existing reads.
//   * One item failing (e.g. a rejected write) never aborts the rest of
//     the batch — failures are collected into the returned result.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../models/inventory_model.dart';
import 'inventory_service.dart';
import 'activity_log_service.dart';
import 'excel_export_service.dart';
import 'pdf_export_service.dart';
import 'csv_export_service.dart';

// ── Price adjustment mode ─────────────────────────────────────────────────
enum PriceAdjustMode {
  percentageIncrease,
  percentageDecrease,
  fixedIncrease,
  fixedDecrease,
  setExact,
}

extension PriceAdjustModeLabel on PriceAdjustMode {
  String get label {
    switch (this) {
      case PriceAdjustMode.percentageIncrease:
        return 'Increase by %';
      case PriceAdjustMode.percentageDecrease:
        return 'Decrease by %';
      case PriceAdjustMode.fixedIncrease:
        return 'Increase by fixed amount';
      case PriceAdjustMode.fixedDecrease:
        return 'Decrease by fixed amount';
      case PriceAdjustMode.setExact:
        return 'Set exact price';
    }
  }
}

// ── Export format ──────────────────────────────────────────────────────────
enum BulkExportFormat { excel, pdf, csv }

// ── One failure inside a bulk run ──────────────────────────────────────────
class BulkOperationError {
  final String itemId;
  final String itemName;
  final String message;

  const BulkOperationError({
    required this.itemId,
    required this.itemName,
    required this.message,
  });

  @override
  String toString() => '$itemName: $message';
}

// ── Result returned by every bulk write operation below ───────────────────
class BulkOperationResult {
  final int total;
  final int succeeded;
  final int failed;
  final List<BulkOperationError> errors;

  const BulkOperationResult({
    required this.total,
    required this.succeeded,
    required this.failed,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isFullSuccess => failed == 0 && total > 0;

  static const empty =
  BulkOperationResult(total: 0, succeeded: 0, failed: 0, errors: []);
}

class InventoryBulkOperationsService {
  InventoryBulkOperationsService._();

  static const String _module = 'Inventory';
  static const int _batchSize = 400; // Firestore hard-caps a batch at 500
  static const int _whereInChunk = 10; // Firestore `whereIn` query limit

  static final CollectionReference<Map<String, dynamic>> _col =
  FirebaseFirestore.instance.collection('inventory');

  // ═══════════════════════════════════════════════════════════════════
  //  SELECT ALL HELPER — server-truth doc-id list, used by "Select All"
  //  when the caller wants to select across the *entire* collection
  //  rather than just what's currently loaded client-side.
  // ═══════════════════════════════════════════════════════════════════
  static Future<List<String>> getAllDocIds() async {
    final snap = await _col.get();
    return snap.docs.map((d) => d.id).toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  PRICE — read current prices for a set of items (chunked `whereIn`)
  // ═══════════════════════════════════════════════════════════════════
  /// Reads the current `price` field (raw, extra Firestore field — see
  /// file header) for each id in [ids]. Missing/absent prices default to
  /// 0.0 so callers never have to null-check.
  static Future<Map<String, double>> fetchPrices(List<String> ids) async {
    final result = <String, double>{};
    if (ids.isEmpty) return result;

    for (var i = 0; i < ids.length; i += _whereInChunk) {
      final chunk = ids.sublist(i, (i + _whereInChunk).clamp(0, ids.length));
      try {
        final snap = await _col
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final data = doc.data();
          result[doc.id] = (data['price'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (_) {
        // If a chunk's read fails, its items simply default to 0.0 below.
      }
    }
    for (final id in ids) {
      result.putIfAbsent(id, () => 0.0);
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BULK UPDATE PRICES
  // ═══════════════════════════════════════════════════════════════════
  /// Applies [mode] + [value] to every item in [items]. [currentPrices]
  /// must contain each item's current price (fetch via [fetchPrices]
  /// first) — required for percentage/fixed adjustments; ignored for
  /// [PriceAdjustMode.setExact].
  static Future<BulkOperationResult> bulkUpdatePrices({
    required List<InventoryItem> items,
    required PriceAdjustMode mode,
    required double value,
    required Map<String, double> currentPrices,
    String? performedBy,
    void Function(int done, int total)? onProgress,
  }) async {
    if (items.isEmpty) return BulkOperationResult.empty;

    final errors = <BulkOperationError>[];
    var succeeded = 0;
    var processed = 0;

    for (var start = 0; start < items.length; start += _batchSize) {
      final chunk = items.sublist(
        start,
        (start + _batchSize).clamp(0, items.length),
      );
      final batch = FirebaseFirestore.instance.batch();
      final chunkTargets = <InventoryItem>[];

      for (final item in chunk) {
        try {
          final current = currentPrices[item.id] ?? 0.0;
          final newPrice = _applyPriceMode(current, mode, value);
          batch.update(_col.doc(item.id), {
            'price': newPrice,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          chunkTargets.add(item);
        } catch (e) {
          errors.add(BulkOperationError(
            itemId: item.id,
            itemName: item.name,
            message: '$e',
          ));
        }
      }

      try {
        await batch.commit();
        succeeded += chunkTargets.length;
      } catch (e) {
        for (final item in chunkTargets) {
          errors.add(BulkOperationError(
            itemId: item.id,
            itemName: item.name,
            message: 'Batch write failed: $e',
          ));
        }
      }

      processed += chunk.length;
      onProgress?.call(processed, items.length);
    }

    InventoryService.clearCache();

    await _logSummary(
      action: 'Bulk price update (${mode.label}, value: $value)',
      total: items.length,
      succeeded: succeeded,
      failed: errors.length,
      performedBy: performedBy,
    );

    return BulkOperationResult(
      total: items.length,
      succeeded: succeeded,
      failed: errors.length,
      errors: errors,
    );
  }

  static double _applyPriceMode(double current, PriceAdjustMode mode, double value) {
    double result;
    switch (mode) {
      case PriceAdjustMode.percentageIncrease:
        result = current + (current * value / 100);
        break;
      case PriceAdjustMode.percentageDecrease:
        result = current - (current * value / 100);
        break;
      case PriceAdjustMode.fixedIncrease:
        result = current + value;
        break;
      case PriceAdjustMode.fixedDecrease:
        result = current - value;
        break;
      case PriceAdjustMode.setExact:
        result = value;
        break;
    }
    if (result < 0) result = 0;
    // Round to 2 decimal places to avoid floating-point noise like
    // 199.99999999998 showing up in the UI.
    return double.parse(result.toStringAsFixed(2));
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BULK DELETE
  // ═══════════════════════════════════════════════════════════════════
  static Future<BulkOperationResult> bulkDelete({
    required List<InventoryItem> items,
    String? performedBy,
    void Function(int done, int total)? onProgress,
  }) async {
    if (items.isEmpty) return BulkOperationResult.empty;

    final errors = <BulkOperationError>[];
    var succeeded = 0;
    var processed = 0;

    for (var start = 0; start < items.length; start += _batchSize) {
      final chunk = items.sublist(
        start,
        (start + _batchSize).clamp(0, items.length),
      );
      final batch = FirebaseFirestore.instance.batch();
      for (final item in chunk) {
        batch.delete(_col.doc(item.id));
      }

      try {
        await batch.commit();
        succeeded += chunk.length;
      } catch (e) {
        for (final item in chunk) {
          errors.add(BulkOperationError(
            itemId: item.id,
            itemName: item.name,
            message: 'Delete failed: $e',
          ));
        }
      }

      processed += chunk.length;
      onProgress?.call(processed, items.length);
    }

    InventoryService.clearCache();

    await _logSummary(
      action: 'Bulk delete',
      total: items.length,
      succeeded: succeeded,
      failed: errors.length,
      performedBy: performedBy,
    );

    return BulkOperationResult(
      total: items.length,
      succeeded: succeeded,
      failed: errors.length,
      errors: errors,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BULK CATEGORY CHANGE
  // ═══════════════════════════════════════════════════════════════════
  static Future<BulkOperationResult> bulkChangeCategory({
    required List<InventoryItem> items,
    required String newCategory,
    String? performedBy,
    void Function(int done, int total)? onProgress,
  }) async {
    if (items.isEmpty) return BulkOperationResult.empty;

    final errors = <BulkOperationError>[];
    var succeeded = 0;
    var processed = 0;

    for (var start = 0; start < items.length; start += _batchSize) {
      final chunk = items.sublist(
        start,
        (start + _batchSize).clamp(0, items.length),
      );
      final batch = FirebaseFirestore.instance.batch();
      for (final item in chunk) {
        batch.update(_col.doc(item.id), {
          'category': newCategory,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      try {
        await batch.commit();
        succeeded += chunk.length;
      } catch (e) {
        for (final item in chunk) {
          errors.add(BulkOperationError(
            itemId: item.id,
            itemName: item.name,
            message: 'Category update failed: $e',
          ));
        }
      }

      processed += chunk.length;
      onProgress?.call(processed, items.length);
    }

    InventoryService.clearCache();

    await _logSummary(
      action: 'Bulk category change -> "$newCategory"',
      total: items.length,
      succeeded: succeeded,
      failed: errors.length,
      performedBy: performedBy,
    );

    return BulkOperationResult(
      total: items.length,
      succeeded: succeeded,
      failed: errors.length,
      errors: errors,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BULK BRANCH TRANSFER
  // ═══════════════════════════════════════════════════════════════════
  static Future<BulkOperationResult> bulkTransferBranch({
    required List<InventoryItem> items,
    required int newBranch,
    String? performedBy,
    void Function(int done, int total)? onProgress,
  }) async {
    if (items.isEmpty) return BulkOperationResult.empty;

    final errors = <BulkOperationError>[];
    var succeeded = 0;
    var processed = 0;

    for (var start = 0; start < items.length; start += _batchSize) {
      final chunk = items.sublist(
        start,
        (start + _batchSize).clamp(0, items.length),
      );
      final batch = FirebaseFirestore.instance.batch();
      for (final item in chunk) {
        batch.update(_col.doc(item.id), {
          'branch': newBranch,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      try {
        await batch.commit();
        succeeded += chunk.length;
      } catch (e) {
        for (final item in chunk) {
          errors.add(BulkOperationError(
            itemId: item.id,
            itemName: item.name,
            message: 'Branch transfer failed: $e',
          ));
        }
      }

      processed += chunk.length;
      onProgress?.call(processed, items.length);
    }

    InventoryService.clearCache();

    final branchLabel = newBranch == 1
        ? 'CDA Admin'
        : newBranch == 2
        ? 'CDA Ops'
        : 'Unassigned';

    await _logSummary(
      action: 'Bulk branch transfer -> "$branchLabel"',
      total: items.length,
      succeeded: succeeded,
      failed: errors.length,
      performedBy: performedBy,
    );

    return BulkOperationResult(
      total: items.length,
      succeeded: succeeded,
      failed: errors.length,
      errors: errors,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  ACTIVITY LOG — one summary line per bulk run
  // ═══════════════════════════════════════════════════════════════════
  static Future<void> _logSummary({
    required String action,
    required int total,
    required int succeeded,
    required int failed,
    String? performedBy,
  }) async {
    try {
      await ActivityLogService.logAction(
        '$action — $succeeded of $total item(s) updated'
            '${failed > 0 ? ' ($failed failed)' : ''}',
        module: _module,
        details: performedBy != null && performedBy.trim().isNotEmpty
            ? 'Performed by $performedBy'
            : null,
      );
    } catch (_) {
      // Logging must never fail the bulk operation itself.
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BULK EXPORT — Excel / PDF / CSV
  // ═══════════════════════════════════════════════════════════════════
  static const List<String> _exportHeaders = [
    'Name',
    'Category',
    'Branch',
    'Location',
    'Quantity',
    'Stock Status',
    'Price',
    'Description',
    'Added By',
    'Created At',
    'Updated At',
  ];

  static final DateFormat _dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

  static List<Object?> _rowFor(InventoryItem item, Map<String, double> prices) {
    return [
      item.name,
      item.category,
      item.branchLabel,
      item.location,
      item.quantity,
      item.stockLabel,
      (prices[item.id] ?? 0.0).toStringAsFixed(2),
      item.description,
      item.addedBy ?? '',
      item.createdAt != null ? _dateFmt.format(item.createdAt!) : '',
      item.updatedAt != null ? _dateFmt.format(item.updatedAt!) : '',
    ];
  }

  /// Builds the export bytes/content for [format] and hands it straight to
  /// the matching platform download/share entry point (the same
  /// `ExcelExportService.download` / `PdfExportService.download` plumbing
  /// already used by every other export in this app, plus the new,
  /// symmetric `CsvExportService.download`).
  static Future<void> exportItems({
    required List<InventoryItem> items,
    required BulkExportFormat format,
    bool includePrices = true,
  }) async {
    final prices = includePrices
        ? await fetchPrices(items.map((i) => i.id).toList())
        : <String, double>{};

    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

    switch (format) {
      case BulkExportFormat.excel:
        final bytes = _buildExcel(items, prices);
        await ExcelExportService.download(bytes, 'inventory_export_$timestamp.xlsx');
        break;
      case BulkExportFormat.pdf:
        final bytes = await _buildPdf(items, prices);
        await PdfExportService.download(bytes, 'inventory_export_$timestamp.pdf');
        break;
      case BulkExportFormat.csv:
        final csv = CsvExportService.build(
          headers: _exportHeaders,
          rows: items.map((i) => _rowFor(i, prices)).toList(),
        );
        await CsvExportService.download(csv, 'inventory_export_$timestamp.csv');
        break;
    }
  }

  static List<int> _buildExcel(List<InventoryItem> items, Map<String, double> prices) {
    final excel = xls.Excel.createExcel();
    final sheet = excel['Inventory Export'];

    final titleCell =
    sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = xls.TextCellValue(
        'Inventory Export — ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}');
    titleCell.cellStyle = xls.CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: xls.ExcelColor.fromHexString('#0A1628'),
    );

    final headerStyle = xls.CellStyle(
      bold: true,
      fontColorHex: xls.ExcelColor.white,
      backgroundColorHex: xls.ExcelColor.fromHexString('#0A1628'),
      horizontalAlign: xls.HorizontalAlign.Center,
    );

    for (var c = 0; c < _exportHeaders.length; c++) {
      final cell =
      sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2));
      cell.value = xls.TextCellValue(_exportHeaders[c]);
      cell.cellStyle = headerStyle;
    }

    var r = 3;
    for (final item in items) {
      final row = _rowFor(item, prices);
      for (var c = 0; c < row.length; c++) {
        final value = row[c];
        final cell =
        sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
        if (value is int) {
          cell.value = xls.IntCellValue(value);
        } else {
          cell.value = xls.TextCellValue(value?.toString() ?? '');
        }
      }
      r++;
    }

    for (var c = 0; c < _exportHeaders.length; c++) {
      sheet.setColumnWidth(c, 20);
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    return excel.encode() ?? <int>[];
  }

  static Future<Uint8List> _buildPdf(
      List<InventoryItem> items, Map<String, double> prices) async {
    const navy = PdfColor.fromInt(0xFF0A1628);
    const border = PdfColor.fromInt(0xFFD8E0EC);
    const muted = PdfColor.fromInt(0xFF60728C);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        header: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: border, width: 1)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('CDA Inventory — Bulk Export',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold, color: navy)),
              pw.Text(DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                  style: pw.TextStyle(fontSize: 9, color: muted)),
            ],
          ),
        ),
        footer: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: border, width: 0.6)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('${items.length} item(s)',
                  style: pw.TextStyle(fontSize: 7.5, color: muted)),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(fontSize: 7.5, color: muted)),
            ],
          ),
        ),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headers: _exportHeaders,
            data: items.map((i) => _rowFor(i, prices).map((v) => '$v').toList()).toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: navy),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            cellHeight: 18,
            border: pw.TableBorder.all(color: border, width: 0.5),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F7FB)),
          ),
        ],
      ),
    );

    return doc.save();
  }
}