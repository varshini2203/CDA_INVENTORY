// lib/services/estimate_pdf_service.dart
//
// SkyLynk-branded Estimate / Quotation PDF — same letterhead, logo and
// visual pattern as InvoicePdfService's Tax Invoice, adapted for
// estimates (reference no. / valid-till instead of received/balance).
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cda_inventory/models/estimate.dart';
import 'package:cda_inventory/models/invoice_line_item.dart';

class EstimatePdfService {
  // ── SkyLynk brand + company details (same as the tax invoice) ──────────
  static const _brandBlue = PdfColor.fromInt(0xFF1F6FB2);
  static const _rowTint   = PdfColor.fromInt(0xFFF5F8FB);
  static const _amber     = PdfColor.fromInt(0xFFFFB800);
  static const _green     = PdfColor.fromInt(0xFF00B894);
  static const _grey      = PdfColor.fromInt(0xFF9CA3AF);

  static const _companyName        = 'SKYLYNK';
  static const _companyAddressLine = 'No 63 West Karikalan Street, Adambakkam , Chennai';
  static const _companyPhone       = '9566145003';
  static const _companyEmail       = 'Info@chennaidroneacademy.com';
  static const _companyGstin       = '33FISPK9632P1Z9';
  static const _companyState       = '33-Tamil Nadu';

  static Uint8List? _cachedSkylynkLogo;

  // ── SkyLynk letterhead logo, same asset used on the tax invoice ────────
  static Future<Uint8List> _loadSkylynkLogo() async {
    if (_cachedSkylynkLogo != null) return _cachedSkylynkLogo!;
    final data = await rootBundle.load('assets/images/skylynk.jpg');
    _cachedSkylynkLogo = data.buffer.asUint8List();
    return _cachedSkylynkLogo!;
  }

  // ── Amount-in-words (Indian numbering: Crore/Lakh/Thousand) ─────────────
  static const List<String> _ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen',
  ];
  static const List<String> _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety',
  ];

  static String _twoDigitsInWords(int n) {
    if (n < 20) return _ones[n];
    final tens = _tens[n ~/ 10];
    final ones = n % 10;
    return ones == 0 ? tens : '$tens ${_ones[ones]}';
  }

  static String _threeDigitsInWords(int n) {
    final hundred = n ~/ 100;
    final rest = n % 100;
    final parts = <String>[];
    if (hundred > 0) parts.add('${_ones[hundred]} Hundred');
    if (rest > 0) parts.add(_twoDigitsInWords(rest));
    return parts.join(' ');
  }

  static String _integerToWords(int n) {
    if (n == 0) return 'Zero';
    final crore = n ~/ 10000000; n %= 10000000;
    final lakh = n ~/ 100000; n %= 100000;
    final thousand = n ~/ 1000; n %= 1000;
    final hundred = n;

    final parts = <String>[];
    if (crore > 0) parts.add('${_threeDigitsInWords(crore)} Crore');
    if (lakh > 0) parts.add('${_threeDigitsInWords(lakh)} Lakh');
    if (thousand > 0) parts.add('${_threeDigitsInWords(thousand)} Thousand');
    if (hundred > 0) parts.add(_threeDigitsInWords(hundred));
    return parts.join(' ');
  }

  static String _amountInWords(double amount) {
    final rupees = amount.floor();
    final paise = ((amount - rupees) * 100).round();
    var words = '${_integerToWords(rupees)} Rupees';
    if (paise > 0) words += ' and ${_integerToWords(paise)} Paise';
    return '$words only';
  }

  static PdfColor _statusColor(String s) {
    switch (s) {
      case 'Converted': return _green;
      case 'Expired': return _grey;
      default: return _amber;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SINGLE ESTIMATE / QUOTATION — matches the SkyLynk Tax Invoice layout
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Uint8List> generate(Estimate est) async {
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
              child: pw.Text('Estimate / Quotation',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _brandBlue)),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.grey400, thickness: 1),
            pw.SizedBox(height: 14),

            // ── Bill To / Estimate details ───────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Quotation To', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        est.customer?.name.isNotEmpty == true ? est.customer!.name : est.partyName,
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      if ((est.customer?.billingAddress ?? '').isNotEmpty)
                        pw.Text(est.customer!.billingAddress!, style: const pw.TextStyle(fontSize: 9)),
                      if ((est.customer?.phone ?? est.partyPhone ?? '').isNotEmpty)
                        pw.Text('Contact No. : ${est.customer?.phone ?? est.partyPhone}',
                            style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Estimate Details', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text('Reference No. : ${est.referenceNo}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Date : ${est.estimateDate}', style: const pw.TextStyle(fontSize: 9)),
                      if ((est.validTill ?? '').isNotEmpty)
                        pw.Text('Valid Till : ${est.validTill}', style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 3),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: _statusColor(est.effectiveStatus),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(est.effectiveStatus,
                            style: pw.TextStyle(fontSize: 8, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // ── Items table ──────────────────────────────────────────────
            pw.Table(
              border: pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.4),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1.1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1.3),
                5: const pw.FlexColumnWidth(1.3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _brandBlue),
                  children: ['#', 'Item name', 'HSN/ SAC', 'Quantity', 'Price/ Unit', 'Amount']
                      .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: pw.Text(h,
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ))
                      .toList(),
                ),
                for (int i = 0; i < est.lineItems.length; i++)
                  _lineItemRow(i + 1, est.lineItems[i], i.isEven),
                pw.TableRow(
                  children: [
                    pw.SizedBox(),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: pw.Text('Total', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.SizedBox(),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: pw.Text(
                        '${est.lineItems.fold<int>(0, (s, li) => s + li.quantity)}',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.SizedBox(),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: pw.Text('Rs. ${est.subtotal.toStringAsFixed(2)}',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // ── Amount in words / totals ────────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Amount In Words',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text(_amountInWords(est.grandTotal), style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 14),
                      pw.Text('Terms and Conditions',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text(est.termsNotes ?? 'Thanks for doing business with us!',
                          style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    children: [
                      _totalRow('Sub Total', 'Rs. ${est.subtotal.toStringAsFixed(2)}'),
                      if (est.totalTax > 0) _totalRow('Tax', 'Rs. ${est.totalTax.toStringAsFixed(2)}'),
                      if (est.shipping > 0) _totalRow('Shipping', 'Rs. ${est.shipping.toStringAsFixed(2)}'),
                      if (est.roundOffEnabled && est.roundOffAmount != 0)
                        _totalRow('Round Off', 'Rs. ${est.roundOffAmount.toStringAsFixed(2)}'),
                      pw.Container(
                        margin: const pw.EdgeInsets.symmetric(vertical: 4),
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        color: _brandBlue,
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                            pw.Text('Rs. ${est.grandTotal.toStringAsFixed(2)}',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          ],
                        ),
                      ),
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

  // ── SkyLynk-style item row: #, item name, HSN/SAC, qty, price/unit,
  // amount — matches the reference tax invoice's columns ──────────────────
  static pw.TableRow _lineItemRow(int index, InvoiceLineItem li, bool even) => pw.TableRow(
    decoration: pw.BoxDecoration(color: even ? PdfColors.white : _rowTint),
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Text('$index', style: const pw.TextStyle(fontSize: 9)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(li.description, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            if ((li.skuCode ?? '').isNotEmpty)
              pw.Text('SKU: ${li.skuCode}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          ],
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Text(li.hsnCode ?? '', style: const pw.TextStyle(fontSize: 9)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Text('${li.quantity}', style: const pw.TextStyle(fontSize: 9)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Text('Rs. ${li.unitPrice.toStringAsFixed(2)}',
            textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Text('Rs. ${li.taxableAmount.toStringAsFixed(2)}',
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ),
    ],
  );

  static pw.Widget _totalRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}