// lib/services/pdf_export_service.dart
//
// Builds PDF reports with the `pdf` package and hands them off via the
// `printing` package, which handles browser download / native share
// automatically depending on platform.

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:cda_inventory/models/invoice.dart';
import 'package:cda_inventory/models/stock.dart';
import 'package:cda_inventory/models/purchase.dart';
import 'package:cda_inventory/services/report_service.dart';

class PdfExportService {
  PdfExportService._();

  static final _monthLabel = DateFormat('MMMM yyyy');
  static final _dateTimeLabel = DateFormat('dd MMM yyyy, hh:mm a');
  static final _currency =
  NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

  static const _navy = PdfColor.fromInt(0xFF0D3A80);
  static const _blue = PdfColor.fromInt(0xFF1E5FC8);
  static const _green = PdfColor.fromInt(0xFF00A96E);
  static const _red = PdfColor.fromInt(0xFFD62839);
  static const _muted = PdfColor.fromInt(0xFF60728C);
  static const _border = PdfColor.fromInt(0xFFD8E0EC);

  // ── Logo, cached after first load ────────────────────────────────────────
  static Uint8List? _cachedLogo;

  static Future<Uint8List> _loadLogo() async {
    if (_cachedLogo != null) return _cachedLogo!;
    final data = await rootBundle.load('assets/images/logo.png');
    _cachedLogo = data.buffer.asUint8List();
    return _cachedLogo!;
  }

  // ── Watermark — supplied via PageTheme.buildBackground so it repeats on
  // every page, sitting behind the header/footer/content automatically ────
  static pw.Widget _watermark(Uint8List logoBytes) => pw.Center(
    child: pw.Opacity(
      opacity: 0.06,
      child: pw.Image(
        pw.MemoryImage(logoBytes),
        width: 320,
        height: 320,
        fit: pw.BoxFit.contain,
      ),
    ),
  );

  // Builds the shared PageTheme (format + watermark background) used by
  // every report so we don't repeat this in five places.
  static pw.PageTheme _pageTheme(Uint8List logoBytes) => pw.PageTheme(
    pageFormat: PdfPageFormat.a4,
    buildBackground: (ctx) => _watermark(logoBytes),
  );

  // ── PUBLIC ENTRY POINTS ──────────────────────────────────────────────────

  static Future<void> download(Uint8List bytes, String filename) async {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  static Future<void> preview(Uint8List bytes, String title) async {
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: title,
    );
  }

  // ── FULL MONTHLY REPORT ──────────────────────────────────────────────────

  static Future<Uint8List> buildFullMonthlyReport({
    required DateTime month,
    required MonthlySummary summary,
    required List<DroneReportRow> drones,
    required List<StockTransaction> stock,
    required List<Invoice> invoices,
  }) async {
    final logoBytes = await _loadLogo();
    final doc = pw.Document();

    doc.addPage(pw.MultiPage(
      pageTheme: _pageTheme(logoBytes),
      header: (ctx) => _header('Monthly Consolidated Report', month),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        _summaryGrid(summary),
        pw.SizedBox(height: 18),
        _sectionTitle('Drone In / Out (${drones.length})'),
        pw.SizedBox(height: 6),
        _droneTable(drones),
        pw.SizedBox(height: 18),
        _sectionTitle('Stock / Inventory History (${stock.length})'),
        pw.SizedBox(height: 6),
        _stockTable(stock),
        pw.SizedBox(height: 18),
        _sectionTitle(
            'Invoices (${invoices.length})  —  Total: ${_currency.format(summary.invoiceTotal)}'),
        pw.SizedBox(height: 6),
        _invoiceTable(invoices),
      ],
    ));

    return doc.save();
  }

  // ── DRONE REPORT ──────────────────────────────────────────────────────────

  static Future<Uint8List> buildDroneReport(
      List<DroneReportRow> rows, DateTime month) async {
    final logoBytes = await _loadLogo();
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageTheme: _pageTheme(logoBytes),
      header: (ctx) => _header('Drone In / Out Report', month),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        pw.Text('${rows.length} entries',
            style: pw.TextStyle(color: _muted, fontSize: 10)),
        pw.SizedBox(height: 10),
        _droneTable(rows),
      ],
    ));
    return doc.save();
  }

  // ── STOCK REPORT ──────────────────────────────────────────────────────────

  static Future<Uint8List> buildStockReport(
      List<StockTransaction> rows, DateTime month) async {
    final logoBytes = await _loadLogo();
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageTheme: _pageTheme(logoBytes),
      header: (ctx) => _header('Stock History Report', month),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        pw.Text('${rows.length} records',
            style: pw.TextStyle(color: _muted, fontSize: 10)),
        pw.SizedBox(height: 10),
        _stockTable(rows),
      ],
    ));
    return doc.save();
  }

  // ── INVOICE REPORT ───────────────────────────────────────────────────────

  static Future<Uint8List> buildInvoiceReport(
      List<Invoice> rows, DateTime month) async {
    final logoBytes = await _loadLogo();
    final total = rows.fold<double>(0, (s, i) => s + i.amount);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageTheme: _pageTheme(logoBytes),
      header: (ctx) => _header('Invoice Report', month),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        pw.Text('${rows.length} invoices  —  Total: ${_currency.format(total)}',
            style: pw.TextStyle(color: _muted, fontSize: 10)),
        pw.SizedBox(height: 10),
        _invoiceTable(rows),
      ],
    ));
    return doc.save();
  }

  // ── PURCHASE REPORT ───────────────────────────────────────────────────────

  static Future<Uint8List> buildPurchaseReport(
      List<Purchase> rows, DateTime month) async {
    final logoBytes = await _loadLogo();
    final total = rows.fold<double>(0, (s, p) => s + (p.cost * p.quantity));
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageTheme: _pageTheme(logoBytes),
      header: (ctx) => _header('Purchase Report', month),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        pw.Text(
            '${rows.length} purchases  —  Total: ${_currency.format(total)}',
            style: pw.TextStyle(color: _muted, fontSize: 10)),
        pw.SizedBox(height: 10),
        _purchaseTable(rows),
      ],
    ));
    return doc.save();
  }

  // ── SHARED LAYOUT PIECES ─────────────────────────────────────────────────

  static pw.Widget _header(String title, DateTime month) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _border, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Chennai Drone Academy',
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy)),
              pw.Text('SkyLNK Unmanned Pvt. Ltd.',
                  style: pw.TextStyle(fontSize: 8, color: _muted)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: _blue)),
              pw.Text(_monthLabel.format(month),
                  style: pw.TextStyle(fontSize: 9, color: _muted)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 0.6)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated ${_dateTimeLabel.format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 7.5, color: _muted)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 7.5, color: _muted)),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String text) => pw.Text(
    text.toUpperCase(),
    style: pw.TextStyle(
        fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _navy),
  );

  static pw.Widget _summaryGrid(MonthlySummary s) {
    pw.Widget cell(String label, String value, PdfColor color) {
      return pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 6),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _border, width: 0.7),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(fontSize: 7.5, color: _muted)),
              pw.SizedBox(height: 3),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
            ],
          ),
        ),
      );
    }

    return pw.Column(children: [
      pw.Row(children: [
        cell('DRONE IN', '${s.droneInCount}', _green),
        cell('DRONE OUT', '${s.droneOutCount}', _red),
        cell('INVOICES', '${s.invoiceCount}', _blue),
      ]),
      pw.SizedBox(height: 6),
      pw.Row(children: [
        cell('STOCK IN QTY', '${s.stockInQty}', _green),
        cell('STOCK OUT QTY', '${s.stockOutQty}', _red),
        cell('INVOICE TOTAL', _currency.format(s.invoiceTotal), _blue),
      ]),
    ]);
  }

  static pw.Widget _droneTable(List<DroneReportRow> rows) {
    if (rows.isEmpty) return _emptyNote('No drone activity in this period.');
    return pw.TableHelper.fromTextArray(
      headers: const ['Drone', 'Model', 'Pilot', 'Status', 'Date / Time'],
      data: rows
          .map((r) => [
        r.droneName,
        r.droneModel,
        r.pilot,
        r.status,
        r.timestamp != null ? _dateTimeLabel.format(r.timestamp!) : '-',
      ])
          .toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: _navy),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellHeight: 20,
      cellAlignments: const {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
      },
      border: pw.TableBorder.all(color: _border, width: 0.5),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F7FB)),
    );
  }

  static pw.Widget _stockTable(List<StockTransaction> rows) {
    if (rows.isEmpty) return _emptyNote('No stock transactions in this period.');
    return pw.TableHelper.fromTextArray(
      headers: const ['Product', 'Type', 'Qty', 'Branch', 'Person', 'Date'],
      data: rows
          .map((t) => [
        t.productName,
        t.type,
        '${t.quantity}',
        t.branch,
        t.person,
        '${t.date} ${t.time}'.trim(),
      ])
          .toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: _navy),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellHeight: 20,
      cellAlignments: const {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerLeft,
        5: pw.Alignment.centerRight,
      },
      border: pw.TableBorder.all(color: _border, width: 0.5),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F7FB)),
    );
  }

  static pw.Widget _invoiceTable(List<Invoice> rows) {
    if (rows.isEmpty) return _emptyNote('No invoices in this period.');
    return pw.TableHelper.fromTextArray(
      headers: const ['Invoice No', 'Product', 'Vendor', 'Qty', 'Amount', 'Date'],
      data: rows
          .map((i) => [
        i.invoiceNo,
        i.productName,
        i.vendorName,
        '${i.quantity}',
        _currency.format(i.amount),
        i.purchaseDate,
      ])
          .toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: _navy),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellHeight: 20,
      cellAlignments: const {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
      border: pw.TableBorder.all(color: _border, width: 0.5),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F7FB)),
    );
  }

  static pw.Widget _purchaseTable(List<Purchase> rows) {
    if (rows.isEmpty) return _emptyNote('No purchases in this period.');
    return pw.TableHelper.fromTextArray(
      headers: const [
        'Product', 'Vendor', 'Invoice #', 'Branch', 'Qty', 'Cost', 'Total', 'Date'
      ],
      data: rows
          .map((p) => [
        p.productName,
        p.vendorName,
        p.invoiceNumber,
        p.branch,
        '${p.quantity}',
        _currency.format(p.cost),
        _currency.format(p.cost * p.quantity),
        p.purchaseDate,
      ])
          .toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: _navy),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellHeight: 20,
      cellAlignments: const {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.center,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
      },
      border: pw.TableBorder.all(color: _border, width: 0.5),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F7FB)),
    );
  }

  static pw.Widget _emptyNote(String text) => pw.Container(
    padding: const pw.EdgeInsets.all(10),
    child: pw.Text(text, style: pw.TextStyle(color: _muted, fontSize: 9)),
  );
}