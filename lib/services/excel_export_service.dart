// lib/services/excel_export_service.dart
//
// Builds .xlsx workbooks with the `excel` package. The actual "hand the
// bytes to the user" step is platform-specific (browser download vs.
// save-to-file + share sheet), so it's delegated to a conditional import:
// `excel_export_io.dart` on Android/iOS/Desktop, `excel_export_web.dart`
// on Flutter Web. This file itself never imports dart:html, so it
// compiles cleanly for every platform.

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import 'package:cda_inventory/models/invoice.dart';
import 'package:cda_inventory/models/stock.dart';
import 'package:cda_inventory/models/purchase.dart';
import 'package:cda_inventory/services/report_service.dart';

import 'excel_export_io.dart'
if (dart.library.html) 'excel_export_web.dart' as platform;

class ExcelExportService {
  ExcelExportService._();

  static final _dateTimeLabel = DateFormat('dd MMM yyyy, hh:mm a');
  static final _monthLabel = DateFormat('MMMM yyyy');

  // ── DOWNLOAD / SAVE ───────────────────────────────────────────────────────

  /// On Web: triggers a browser file download.
  /// On Android/iOS/Desktop: saves to a temp file and opens the share sheet
  /// (see excel_export_io.dart).
  static Future<void> download(List<int> bytes, String filename) {
    return platform.saveOrDownload(bytes, filename);
  }

  // ── FULL MONTHLY REPORT (multi-sheet workbook) ───────────────────────────

  static List<int> buildFullMonthlyReport({
    required DateTime month,
    required MonthlySummary summary,
    required List<DroneReportRow> drones,
    required List<StockTransaction> stock,
    required List<Invoice> invoices,
  }) {
    final excel = Excel.createExcel();

    _writeSummarySheet(excel, month, summary);
    _writeDroneSheet(excel, month, drones);
    _writeStockSheet(excel, month, stock);
    _writeInvoiceSheet(excel, month, invoices);

    // The excel package creates a default 'Sheet1' — remove it once our
    // named sheets exist.
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    return bytes ?? <int>[];
  }

  // ── DRONE REPORT ──────────────────────────────────────────────────────────

  static List<int> buildDroneReport(List<DroneReportRow> rows, DateTime month) {
    final excel = Excel.createExcel();
    _writeDroneSheet(excel, month, rows);
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
    return excel.encode() ?? <int>[];
  }

  // ── STOCK REPORT ──────────────────────────────────────────────────────────

  static List<int> buildStockReport(List<StockTransaction> rows, DateTime month) {
    final excel = Excel.createExcel();
    _writeStockSheet(excel, month, rows);
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
    return excel.encode() ?? <int>[];
  }

  // ── INVOICE REPORT ───────────────────────────────────────────────────────

  static List<int> buildInvoiceReport(List<Invoice> rows, DateTime month) {
    final excel = Excel.createExcel();
    _writeInvoiceSheet(excel, month, rows);
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
    return excel.encode() ?? <int>[];
  }

  // ── PURCHASE REPORT ───────────────────────────────────────────────────────

  static List<int> buildPurchaseReport(List<Purchase> rows, DateTime month) {
    final excel = Excel.createExcel();
    _writePurchaseSheet(excel, month, rows);
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
    return excel.encode() ?? <int>[];
  }

  // ── SHEET BUILDERS ───────────────────────────────────────────────────────

  static CellStyle get _headerStyle => CellStyle(
    bold: true,
    fontColorHex: ExcelColor.white,
    backgroundColorHex: ExcelColor.fromHexString('#0D3A80'),
    horizontalAlign: HorizontalAlign.Center,
  );

  static CellStyle get _titleStyle => CellStyle(
    bold: true,
    fontSize: 14,
    fontColorHex: ExcelColor.fromHexString('#0D3A80'),
  );

  static void _writeHeaderRow(Sheet sheet, int rowIndex, List<String> headers) {
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex));
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = _headerStyle;
    }
  }

  static void _writeTitleRow(Sheet sheet, String title, DateTime month) {
    final cell =
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    cell.value = TextCellValue('$title — ${_monthLabel.format(month)}');
    cell.cellStyle = _titleStyle;
  }

  static void _writeSummarySheet(
      Excel excel, DateTime month, MonthlySummary s) {
    final sheet = excel['Summary'];
    _writeTitleRow(sheet, 'Monthly Consolidated Report', month);

    _writeHeaderRow(sheet, 2, ['Metric', 'Value']);
    final rows = <List<CellValue?>>[
      [TextCellValue('Drone IN'), IntCellValue(s.droneInCount)],
      [TextCellValue('Drone OUT'), IntCellValue(s.droneOutCount)],
      [TextCellValue('Stock IN transactions'), IntCellValue(s.stockInCount)],
      [TextCellValue('Stock OUT transactions'), IntCellValue(s.stockOutCount)],
      [TextCellValue('Stock IN quantity'), IntCellValue(s.stockInQty)],
      [TextCellValue('Stock OUT quantity'), IntCellValue(s.stockOutQty)],
      [TextCellValue('Invoice count'), IntCellValue(s.invoiceCount)],
      [TextCellValue('Invoice total (Rs.)'), DoubleCellValue(s.invoiceTotal)],
    ];
    var r = 3;
    for (final row in rows) {
      for (var c = 0; c < row.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .value = row[c];
      }
      r++;
    }

    sheet.setColumnWidth(0, 26);
    sheet.setColumnWidth(1, 16);
  }

  static void _writeDroneSheet(
      Excel excel, DateTime month, List<DroneReportRow> rows) {
    final sheet = excel['Drone In-Out'];
    _writeTitleRow(sheet, 'Drone In / Out Report', month);
    _writeHeaderRow(
        sheet, 2, ['Drone', 'Model', 'Used By', 'Status', 'Notes', 'Date / Time']);

    var r = 3;
    for (final row in rows) {
      final cells = <CellValue?>[
        TextCellValue(row.droneName),
        TextCellValue(row.droneModel),
        TextCellValue(row.pilot),
        TextCellValue(row.status),
        TextCellValue(row.notes ?? ''),
        TextCellValue(
            row.timestamp != null ? _dateTimeLabel.format(row.timestamp!) : ''),
      ];
      for (var c = 0; c < cells.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .value = cells[c];
      }
      r++;
    }

    for (var c = 0; c < 6; c++) {
      sheet.setColumnWidth(c, 20);
    }
  }

  static void _writeStockSheet(
      Excel excel, DateTime month, List<StockTransaction> rows) {
    final sheet = excel['Stock History'];
    _writeTitleRow(sheet, 'Stock / Inventory History Report', month);
    _writeHeaderRow(sheet, 2, [
      'Product',
      'Type',
      'Qty',
      'Branch',
      'Person',
      'Department / Purpose',
      'Date',
      'Time',
      'Remarks',
    ]);

    var r = 3;
    for (final t in rows) {
      final cells = <CellValue?>[
        TextCellValue(t.productName),
        TextCellValue(t.type),
        IntCellValue(t.quantity),
        TextCellValue(t.branch),
        TextCellValue(t.person),
        TextCellValue(t.departmentOrPurpose),
        TextCellValue(t.date),
        TextCellValue(t.time),
        TextCellValue(t.remarks ?? ''),
      ];
      for (var c = 0; c < cells.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .value = cells[c];
      }
      r++;
    }

    for (var c = 0; c < 9; c++) {
      sheet.setColumnWidth(c, 18);
    }
  }

  static void _writeInvoiceSheet(
      Excel excel, DateTime month, List<Invoice> rows) {
    final sheet = excel['Invoices'];
    _writeTitleRow(sheet, 'Invoice Report', month);
    _writeHeaderRow(sheet, 2,
        ['Invoice No', 'Product', 'Vendor', 'Qty', 'Amount (Rs.)', 'Purchase Date']);

    var r = 3;
    for (final i in rows) {
      final cells = <CellValue?>[
        TextCellValue(i.invoiceNo),
        TextCellValue(i.productName),
        TextCellValue(i.vendorName),
        IntCellValue(i.quantity),
        DoubleCellValue(i.amount),
        TextCellValue(i.purchaseDate),
      ];
      for (var c = 0; c < cells.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .value = cells[c];
      }
      r++;
    }

    final total = rows.fold<double>(0, (s, i) => s + i.amount);
    final totalRow = r + 1;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: totalRow))
        .value = TextCellValue('TOTAL');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: totalRow))
        .value = DoubleCellValue(total);

    for (var c = 0; c < 6; c++) {
      sheet.setColumnWidth(c, 20);
    }
  }

  static void _writePurchaseSheet(
      Excel excel, DateTime month, List<Purchase> rows) {
    final sheet = excel['Purchases'];
    _writeTitleRow(sheet, 'Purchase Report', month);
    _writeHeaderRow(sheet, 2, [
      'Product',
      'Vendor',
      'Invoice #',
      'Branch',
      'Qty',
      'Cost (Rs.)',
      'Total (Rs.)',
      'Purchase Date',
    ]);

    var r = 3;
    for (final p in rows) {
      final cells = <CellValue?>[
        TextCellValue(p.productName),
        TextCellValue(p.vendorName),
        TextCellValue(p.invoiceNumber),
        TextCellValue(p.branch),
        IntCellValue(p.quantity),
        DoubleCellValue(p.cost),
        DoubleCellValue(p.cost * p.quantity),
        TextCellValue(p.purchaseDate),
      ];
      for (var c = 0; c < cells.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .value = cells[c];
      }
      r++;
    }

    final total = rows.fold<double>(0, (s, p) => s + (p.cost * p.quantity));
    final totalRow = r + 1;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: totalRow))
        .value = TextCellValue('TOTAL');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: totalRow))
        .value = DoubleCellValue(total);

    for (var c = 0; c < 8; c++) {
      sheet.setColumnWidth(c, 20);
    }
  }
}