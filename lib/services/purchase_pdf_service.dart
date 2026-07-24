// lib/services/purchase_pdf_service.dart
//
// Generates a branded PDF for a Purchase bill — party details, itemized
// table, discount/tax/shipping/round-off totals, terms & conditions, and
// (if attached) the scanned/uploaded bill image. Mirrors the structure
// of InvoicePdfService / BillPdfService so PDFs feel consistent across
// the app. Used by the "Print" button on the Add/Edit Purchase screen.

import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cda_inventory/models/purchase.dart';

class PurchasePdfService {
  static const _navy  = PdfColor.fromInt(0xFF0A1628);
  static const _teal  = PdfColor.fromInt(0xFF00D4AA);
  static const _grey  = PdfColor.fromInt(0xFFF0F4F8);

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

  static pw.Widget _metaRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
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

  static pw.TableRow _legacyRow(Purchase p) => pw.TableRow(
    children: [
      _cell(p.productName),
      _cell('-'),
      _cell('${p.quantity}'),
      _cell('NONE'),
      _cell('Rs. ${p.cost.toStringAsFixed(2)}'),
      _cell('0%'),
      _cell('0%'),
      _cell('Rs. ${(p.cost * p.quantity).toStringAsFixed(2)}', bold: true),
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

  /// Builds a one-page Purchase Bill PDF from the given [purchase].
  /// Works for both a saved record and an in-progress (unsaved) draft
  /// built from the Add/Edit Purchase screen's current form state.
  static Future<Uint8List> generate(Purchase purchase) async {
    final doc = pw.Document();

    pw.MemoryImage? billImage;
    if (purchase.imageUrl != null && purchase.imageUrl!.isNotEmpty) {
      try {
        billImage = pw.MemoryImage(base64Decode(purchase.imageUrl!));
      } catch (_) {
        billImage = null; // Not base64 image data — skip gracefully.
      }
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _letterhead(purchase.termsTitle.isEmpty ? 'Purchase Bill' : purchase.termsTitle,
                purchase.invoiceNumber.isEmpty ? '' : '#${purchase.invoiceNumber}'),
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
                        pw.Text(purchase.displayVendorName,
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        if ((purchase.partyPhone ?? '').isNotEmpty)
                          pw.Text('Ph: ${purchase.partyPhone}', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      _metaRow('Bill Date', purchase.purchaseDate),
                      _metaRow('State of Supply', purchase.stateOfSupply),
                      _metaRow('Payment Type', purchase.paymentType),
                      _metaRow('Branch', purchase.branch),
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
                if (purchase.usesLineItems)
                  for (int i = 0; i < purchase.lineItems.length; i++)
                    _lineItemRow(purchase.lineItems[i], i.isEven)
                else
                  _legacyRow(purchase),
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
                      _totalRow('Subtotal', purchase.subtotal + purchase.totalDiscount),
                      if (purchase.totalDiscount > 0) _totalRow('Discount', -purchase.totalDiscount),
                      if (purchase.totalTax > 0) _totalRow('Tax', purchase.totalTax),
                      if (purchase.shipping > 0) _totalRow('Shipping', purchase.shipping),
                      if (purchase.roundOffAmount != 0) _totalRow('Round Off', purchase.roundOffAmount),
                      pw.Divider(color: PdfColors.grey400),
                      _totalRow('Grand Total', purchase.grandTotal, bold: true, color: _navy),
                    ],
                  ),
                ),
              ],
            ),

            if ((purchase.termsNotes ?? '').isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text('Terms & Conditions', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text(purchase.termsNotes!, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],

            if ((purchase.description ?? '').isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text('Notes', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text(purchase.description!, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],

            if (billImage != null) ...[
              pw.SizedBox(height: 20),
              pw.Text('Uploaded Bill', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _navy)),
              pw.SizedBox(height: 8),
              pw.Container(
                height: 320,
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Center(child: pw.Image(billImage, fit: pw.BoxFit.contain)),
              ),
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