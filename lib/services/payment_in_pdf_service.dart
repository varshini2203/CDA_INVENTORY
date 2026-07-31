// lib/services/payment_in_pdf_service.dart
//
// Generates a branded PDF receipt for a Payment-In — customer details,
// payment mode/reference, any invoices it was applied against (with
// per-invoice amount applied), and the advance/unused balance. Mirrors
// the structure of PurchasePdfService so PDFs feel consistent across
// the app. Used by the "Print" button on the Add/Edit Payment-In screen.

import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cda_inventory/models/payment_in.dart';

class PaymentInPdfService {
  static const _navy = PdfColor.fromInt(0xFF0A1628);
  static const _teal = PdfColor.fromInt(0xFF00D4AA);
  static const _grey = PdfColor.fromInt(0xFFF0F4F8);

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
    children: ['Invoice No.', 'Amount Applied']
        .map((h) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: pw.Text(h,
          style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
    ))
        .toList(),
  );

  static pw.TableRow _allocationRow(PaymentInInvoiceAllocation a, bool even) => pw.TableRow(
    decoration: pw.BoxDecoration(color: even ? PdfColors.white : _grey),
    children: [
      _cell(a.invoiceNo.isEmpty ? '-' : a.invoiceNo),
      _cell('Rs. ${a.amountApplied.toStringAsFixed(2)}', bold: true),
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

  /// Builds a one-page Payment-In receipt PDF from the given [payment].
  /// Works for both a saved record and an in-progress (unsaved) draft
  /// built from the Add/Edit Payment-In screen's current form state.
  static Future<Uint8List> generate(PaymentIn payment) async {
    final doc = pw.Document();

    pw.MemoryImage? attachmentImage;
    if (payment.attachmentBase64 != null && payment.attachmentBase64!.isNotEmpty) {
      try {
        attachmentImage = pw.MemoryImage(base64Decode(payment.attachmentBase64!));
      } catch (_) {
        attachmentImage = null; // Not base64 image data (e.g. a PDF) — skip gracefully.
      }
    }

    final allocatedTotal = payment.invoiceAllocations.fold<double>(0, (s, a) => s + a.amountApplied);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _letterhead('Payment-In Receipt',
                payment.referenceNumber.isEmpty ? '' : '#${payment.referenceNumber}'),
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
                        pw.Text('RECEIVED FROM',
                            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text(payment.customerName.isEmpty ? '-' : payment.customerName,
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        if (payment.phone.isNotEmpty)
                          pw.Text('Ph: ${payment.phone}', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      _metaRow('Payment Date', payment.paymentDate),
                      _metaRow('Payment Mode', payment.paymentMode),
                      if (payment.referenceNumber.isNotEmpty) _metaRow('Reference No.', payment.referenceNumber),
                      _metaRow('Branch', payment.branch),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            if (payment.invoiceAllocations.isNotEmpty) ...[
              pw.Text('Settled Against Invoices',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _navy)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.4),
                },
                children: [
                  _headerRow(),
                  for (int i = 0; i < payment.invoiceAllocations.length; i++)
                    _allocationRow(payment.invoiceAllocations[i], i.isEven),
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(color: _grey, borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Column(
                    children: [
                      if (payment.invoiceAllocations.isNotEmpty) _totalRow('Applied to Invoices', allocatedTotal),
                      if (payment.advanceAmount > 0) _totalRow('Advance / Unused', payment.advanceAmount),
                      pw.Divider(color: PdfColors.grey400),
                      _totalRow('Total Received', payment.amount, bold: true, color: _navy),
                    ],
                  ),
                ),
              ],
            ),

            if (payment.notes.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text('Notes', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text(payment.notes, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],

            if (attachmentImage != null) ...[
              pw.SizedBox(height: 20),
              pw.Text('Attachment', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _navy)),
              pw.SizedBox(height: 8),
              pw.Container(
                height: 320,
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Center(child: pw.Image(attachmentImage, fit: pw.BoxFit.contain)),
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
