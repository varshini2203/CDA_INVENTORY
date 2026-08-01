// lib/services/purchase_return_pdf_service.dart
//
// SkyLynk-branded Purchase Return / Debit Note PDF — same letterhead, logo
// and visual pattern as EstimatePdfService / DeliveryChallanPdfService /
// SaleReturnPdfService, adapted for a single-product debit note (reason
// for return, reference invoice, debit note amount) against a vendor.
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cda_inventory/models/purchase_return.dart';

class PurchaseReturnPdfService {
  // ── SkyLynk brand + company details (same as estimate/delivery challan) ─
  static const _brandBlue = PdfColor.fromInt(0xFF1F6FB2);
  static const _rowTint   = PdfColor.fromInt(0xFFF5F8FB);
  static const _red       = PdfColor.fromInt(0xFFE94D5F);
  static const _amber     = PdfColor.fromInt(0xFFE8A33D);

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

  static PdfColor _reasonColor(String reason) {
    switch (reason) {
      case 'Damaged Goods':
      case 'Wrong Item Delivered':
        return _red;
      case 'Quality Issue':
        return _amber;
      default:
        return _brandBlue;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PURCHASE RETURN / DEBIT NOTE — matches the SkyLynk Estimate layout
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Uint8List> generate(PurchaseReturn ret) async {
    final skylynkLogo = await _loadSkylynkLogo();
    final doc = pw.Document();

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
              child: pw.Text('Purchase Return / Debit Note',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _brandBlue)),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.grey400, thickness: 1),
            pw.SizedBox(height: 14),

            // ── Vendor / Return details ────────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Vendor', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text(ret.vendorName.isEmpty ? '-' : ret.vendorName,
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 10),
                      pw.Text('Return Status',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFFDECEC),
                          border: pw.Border.all(color: _reasonColor(ret.reason), width: 0.6),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(ret.reason,
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _reasonColor(ret.reason))),
                      ),
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Return Details',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      _metaRow('Return Date', ret.returnDate.isEmpty ? '-' : ret.returnDate),
                      _metaRow('Reason', ret.reason),
                      if (ret.referenceInvoice.isNotEmpty) _metaRow('Reference Invoice', ret.referenceInvoice),
                      _metaRow('Branch', ret.branch),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // ── Item table ────────────────────────────────────────────
            pw.Table(
              border: pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _brandBlue),
                  children: ['Product Name', 'Quantity', 'Amount']
                      .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: pw.Text(h,
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ))
                      .toList(),
                ),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _rowTint),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: pw.Text(ret.productName.isEmpty ? '-' : ret.productName,
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: pw.Text('${ret.quantity}', style: const pw.TextStyle(fontSize: 9)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: pw.Text('Rs. ${ret.amount.toStringAsFixed(2)}',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
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
                      pw.Text('Debit Note Amount',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                      pw.Text('Rs. ${ret.amount.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    ],
                  ),
                ),
              ],
            ),
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