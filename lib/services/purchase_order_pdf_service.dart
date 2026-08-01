// lib/services/purchase_order_pdf_service.dart
//
// Branded PDF for a Purchase Order — mirrors PurchasePdfService /
// SaleOrderPdfService so PDFs stay visually consistent across the app.
// Used by Print / Share as PDF / Export PDF on the Purchase Order screens.

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cda_inventory/models/purchase_order.dart';

class PurchaseOrderPdfService {
  static const _navy = PdfColor.fromInt(0xFF0A1628);
  static const _teal = PdfColor.fromInt(0xFF00D4AA);
  static const _grey = PdfColor.fromInt(0xFFF0F4F8);
  static const _amber = PdfColor.fromInt(0xFFFFB800);
  static const _green = PdfColor.fromInt(0xFF00B894);
  static const _red = PdfColor.fromInt(0xFFFF6B6B);

  static const Map<String, String> _branchLabels = {
    'Branch 1': 'CDA Admin',
    'Branch 2': 'CDA Ops',
  };

  static PdfColor _statusColor(String s) {
    switch (s) {
      case 'Received':
        return _green;
      case 'Cancelled':
        return _red;
      default:
        return _amber;
    }
  }

  static pw.Widget _letterhead(String rightTitle, String rightSubtitle) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(colors: [_navy, PdfColor.fromInt(0xFF162944)]),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('CHENNAI DRONE ACADEMY',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('SkyLNK Unmanned Pvt. Ltd.',
                  style: const pw.TextStyle(color: _teal, fontSize: 9)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(rightTitle,
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text(rightSubtitle, style: const pw.TextStyle(color: _teal, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaRow(String label, String value, {PdfColor? valueColor}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: valueColor)),
      ],
    ),
  );

  static pw.Widget _cell(String text, {bool bold = false, PdfColor? color}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
    child: pw.Text(text,
        style: pw.TextStyle(
            fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
  );

  static pw.TableRow _headerRow() => pw.TableRow(
    decoration: const pw.BoxDecoration(color: _navy),
    children: ['Item', 'Serial No.', 'Qty', 'Unit', 'Price/Unit', 'Disc%', 'Tax%', 'Amount']
        .map((h) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: pw.Text(h,
          style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
    ))
        .toList(),
  );

  static pw.TableRow _lineItemRow(dynamic li, bool even) => pw.TableRow(
    decoration: pw.BoxDecoration(color: even ? PdfColors.white : _grey),
    children: [
      _cell(li.description),
      _cell((li.hsnCode == null || li.hsnCode.toString().isEmpty) ? '-' : li.hsnCode.toString()),
      _cell('${li.quantity}'),
      _cell('${li.unit}'),
      _cell('Rs. ${li.unitPrice.toStringAsFixed(2)}'),
      _cell('${li.discountPercent}%'),
      _cell('${li.taxPercent}%'),
      _cell('Rs. ${li.lineTotal.toStringAsFixed(2)}', bold: true),
    ],
  );

  static pw.TableRow _legacyRow(PurchaseOrder p) => pw.TableRow(
    children: [
      _cell(p.productName),
      _cell('-'),
      _cell('${p.quantity}'),
      _cell('NONE'),
      _cell('Rs. ${p.expectedCost.toStringAsFixed(2)}'),
      _cell('0%'),
      _cell('0%'),
      _cell('Rs. ${(p.expectedCost * p.quantity).toStringAsFixed(2)}', bold: true),
    ],
  );

  static pw.Widget _totalRow(String label, double value, {bool bold = false, PdfColor? color}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text('Rs. ${value.toStringAsFixed(2)}',
            style: pw.TextStyle(
                fontSize: bold ? 11 : 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color)),
      ],
    ),
  );

  static bool _usesLineItems(PurchaseOrder p) => p.lineItems.isNotEmpty;

  static double _subtotal(PurchaseOrder p) => _usesLineItems(p)
      ? p.lineItems.fold(0.0, (sum, li) => sum + li.taxableAmount)
      : p.expectedCost * p.quantity;

  static double _totalTax(PurchaseOrder p) =>
      p.lineItems.fold(0.0, (sum, li) => sum + li.taxAmount);

  static double _totalDiscount(PurchaseOrder p) =>
      p.lineItems.fold(0.0, (sum, li) => sum + li.discountAmount);

  static double _grandTotal(PurchaseOrder p) =>
      _subtotal(p) + _totalTax(p);

  /// Builds a one-page Purchase Order PDF from the given [order].
  static Future<Uint8List> generate(PurchaseOrder order) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _letterhead('Purchase Order',
                (order.poNumber == null || order.poNumber!.isEmpty) ? '' : '#${order.poNumber}'),
            pw.SizedBox(height: 18),

            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(color: _grey, borderRadius: pw.BorderRadius.circular(8)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('VENDOR',
                            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text(order.vendorName,
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        if ((order.vendorPhone ?? '').isNotEmpty)
                          pw.Text('Ph: ${order.vendorPhone}', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      _metaRow('Order Date', order.orderDate),
                      _metaRow('Expected Delivery',
                          order.expectedDeliveryDate.isEmpty ? '-' : order.expectedDeliveryDate),
                      _metaRow('State of Supply', order.stateOfSupply),
                      _metaRow('Branch', _branchLabels[order.branch] ?? order.branch),
                      _metaRow('Status', order.status, valueColor: _statusColor(order.status)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            pw.Table(
              border: pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.6),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(0.7),
                3: const pw.FlexColumnWidth(0.9),
                4: const pw.FlexColumnWidth(1.2),
                5: const pw.FlexColumnWidth(0.8),
                6: const pw.FlexColumnWidth(0.8),
                7: const pw.FlexColumnWidth(1.3),
              },
              children: [
                _headerRow(),
                if (_usesLineItems(order))
                  for (int i = 0; i < order.lineItems.length; i++)
                    _lineItemRow(order.lineItems[i], i.isEven)
                else
                  _legacyRow(order),
              ],
            ),
            pw.SizedBox(height: 16),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(color: _grey, borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Column(
                    children: [
                      _totalRow('Subtotal', _subtotal(order) + _totalDiscount(order)),
                      if (_totalDiscount(order) > 0) _totalRow('Discount', -_totalDiscount(order)),
                      if (_totalTax(order) > 0) _totalRow('Tax', _totalTax(order)),
                      pw.Divider(color: PdfColors.grey400),
                      _totalRow('Grand Total', _grandTotal(order), bold: true, color: _navy),
                    ],
                  ),
                ),
              ],
            ),

            if (order.notes.trim().isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text('Notes', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text(order.notes, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],

            pw.SizedBox(height: 16),
            pw.Text('Generated by CDA Inventory System', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ),
    );

    return doc.save();
  }
}