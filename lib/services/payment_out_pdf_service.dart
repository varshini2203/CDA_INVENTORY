// lib/services/payment_out_pdf_service.dart
//
// SkyLynk-branded Payment-Out / Payment Voucher PDF — same letterhead,
// logo and visual pattern as EstimatePdfService / DeliveryChallanPdfService
// / SaleReturnPdfService, adapted for a vendor payment voucher (payment
// mode/reference, amount paid, optional attachment). Mirrors the content
// layout of PaymentInPdfService so Payment-Out and Payment-In receipts
// feel consistent, but uses the SkyLynk logo letterhead used by the newer
// PDF services.
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cda_inventory/models/payment_out.dart';

class PaymentOutPdfService {
  // ── SkyLynk brand + company details (same as estimate/delivery challan) ─
  static const _brandBlue = PdfColor.fromInt(0xFF1F6FB2);
  static const _rowTint   = PdfColor.fromInt(0xFFF5F8FB);

  static const _companyName        = 'SKYLYNK';
  static const _companyAddressLine = 'No 63 West Karikalan Street, Adambakkam , Chennai';
  static const _companyPhone       = '9566145003';
  static const _companyEmail       = 'Info@chennaidroneacademy.com';
  static const _companyGstin       = '33FISPK9632P1Z9';
  static const _companyState       = '33-Tamil Nadu';

  static Uint8List? _cachedSkylynkLogo;

  // ── SkyLynk letterhead logo, same asset used on the estimate/invoice ────
  static Future<Uint8List> _loadSkylynkLogo() async {
    if (_cachedSkylynkLogo != null) return _cachedSkylynkLogo!;
    final data = await rootBundle.load('assets/images/skylynk.jpg');
    _cachedSkylynkLogo = data.buffer.asUint8List();
    return _cachedSkylynkLogo!;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PAYMENT OUT / PAYMENT VOUCHER — matches the SkyLynk Estimate layout
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Uint8List> generate(PaymentOut payment) async {
    final skylynkLogo = await _loadSkylynkLogo();
    final doc = pw.Document();

    pw.MemoryImage? attachmentImage;
    if ((payment.attachmentBase64 ?? '').isNotEmpty) {
      try {
        attachmentImage = pw.MemoryImage(base64Decode(payment.attachmentBase64!));
      } catch (_) {
        attachmentImage = null; // Not base64 image data (e.g. a PDF) — skip gracefully.
      }
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Company letterhead ──────────────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_companyName,
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(_companyAddressLine, style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Phone no. : $_companyPhone', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Email : $_companyEmail', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('GSTIN : $_companyGstin', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('State: $_companyState', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.SizedBox(
                  width: 90,
                  height: 90,
                  child: pw.Image(pw.MemoryImage(skylynkLogo), fit: pw.BoxFit.contain),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.grey400, thickness: 1),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text('Payment Out / Payment Voucher',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _brandBlue)),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.grey400, thickness: 1),
            pw.SizedBox(height: 14),

            // ── Vendor / Payment details ─────────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Paid To', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text(payment.vendorName.isEmpty ? '-' : payment.vendorName,
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Payment Details',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      _metaRow('Payment Date', payment.paymentDate.isEmpty ? '-' : payment.paymentDate),
                      _metaRow('Payment Mode', payment.paymentMode),
                      if (payment.referenceNumber.isNotEmpty) _metaRow('Reference No.', payment.referenceNumber),
                      _metaRow('Branch', payment.branch),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // ── Total ─────────────────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  color: _brandBlue,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Amount Paid',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                      pw.Text('Rs. ${payment.amount.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    ],
                  ),
                ),
              ],
            ),

            if (payment.notes.trim().isNotEmpty) ...[
              pw.SizedBox(height: 18),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(color: _rowTint, borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Notes', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 3),
                    pw.Text(payment.notes, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ],

            if (attachmentImage != null) ...[
              pw.SizedBox(height: 20),
              pw.Text('Attachment', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _brandBlue)),
              pw.SizedBox(height: 8),
              pw.Container(
                height: 300,
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Center(child: pw.Image(attachmentImage, fit: pw.BoxFit.contain)),
              ),
            ],

            pw.SizedBox(height: 26),

            // ── Signatory ────────────────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('For :$_companyName', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 34),
                    pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _metaRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Text('$label: $value', style: const pw.TextStyle(fontSize: 9)),
  );
}