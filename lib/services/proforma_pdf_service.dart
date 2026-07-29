// lib/services/proforma_pdf_service.dart
//
// Generates the printable/shareable Proforma Invoice PDF — same navy/teal
// SkyLNK letterhead as InvoicePdfService, but headed "PROFORMA INVOICE"
// with an explicit "This is not a Tax Invoice" disclaimer and a validity
// date instead of a payment/balance block (a proforma isn't paid yet).

import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cda_inventory/models/proforma_invoice.dart';
import 'package:cda_inventory/models/invoice_line_item.dart';

class ProformaPdfService {
  static const _navy  = PdfColor.fromInt(0xFF0A1628);
  static const _teal  = PdfColor.fromInt(0xFF00D4AA);
  static const _amber = PdfColor.fromInt(0xFFFFB800);
  static const _coral = PdfColor.fromInt(0xFFFF6B6B);
  static const _brandBlue = PdfColor.fromInt(0xFF1F6FB2);
  static const _rowTint   = PdfColor.fromInt(0xFFF5F8FB);

  static const _companyName        = 'SKYLYNK';
  static const _companyAddressLine = 'No 63 West Karikalan Street, Adambakkam , Chennai';
  static const _companyPhone       = '9566145003';
  static const _companyEmail       = 'Info@chennaidroneacademy.com';
  static const _companyGstin       = '33FISPK9632P1Z9';
  static const _companyState       = '33-Tamil Nadu';

  static Uint8List? _cachedLogo;

  static Future<Uint8List> _loadLogo() async {
    if (_cachedLogo != null) return _cachedLogo!;
    final data = await rootBundle.load('assets/images/skylynk.jpg');
    _cachedLogo = data.buffer.asUint8List();
    return _cachedLogo!;
  }

  // ── Amount-in-words (Indian numbering: Crore/Lakh/Thousand) ──────────────
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
      case 'Converted':
      case 'Converted to Invoice':
      case 'Accepted':
        return _teal;
      case 'Expired':
      case 'Rejected':
        return _coral;
      case 'Sent':
        return _brandBlue;
      case 'Draft':
        return PdfColor.fromInt(0xFF8A94A6);
      default:
        return _amber;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SINGLE PROFORMA INVOICE PDF
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Uint8List> generate(ProformaInvoice p) async {
    final logo = await _loadLogo();
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Company letterhead ────────────────────────────────────
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
                  child: pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.grey400, thickness: 1),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Column(children: [
                pw.Text('PROFORMA INVOICE',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _brandBlue)),
                pw.SizedBox(height: 2),
                pw.Text('This is not a Tax Invoice — for reference / advance payment purposes only',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ]),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.grey400, thickness: 1),
            pw.SizedBox(height: 14),

            // ── Bill To / Proforma details ──────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Bill To', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text(p.customer?.name ?? p.partyName,
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      if ((p.customer?.billingAddress ?? '').isNotEmpty)
                        pw.Text(p.customer!.billingAddress!, style: const pw.TextStyle(fontSize: 9)),
                      if ((p.customer?.phone ?? '').isNotEmpty)
                        pw.Text('Contact No. : ${p.customer!.phone}', style: const pw.TextStyle(fontSize: 9)),
                      if ((p.customer?.email ?? '').isNotEmpty)
                        pw.Text('Email : ${p.customer!.email}', style: const pw.TextStyle(fontSize: 9)),
                      if ((p.customer?.gstin ?? '').isNotEmpty)
                        pw.Text('GSTIN : ${p.customer!.gstin}', style: const pw.TextStyle(fontSize: 9)),
                      if ((p.customer?.shippingAddress ?? '').isNotEmpty &&
                          p.customer!.shippingAddress != p.customer!.billingAddress) ...[
                        pw.SizedBox(height: 6),
                        pw.Text('Ship To', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 3),
                        pw.Text(p.customer!.shippingAddress!, style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Proforma Details', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text('Proforma No. : ${p.proformaNo}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Date : ${p.proformaDate}', style: const pw.TextStyle(fontSize: 9)),
                      if ((p.validTill ?? '').isNotEmpty)
                        pw.Text('Valid Till : ${p.validTill}', style: const pw.TextStyle(fontSize: 9)),
                      if ((p.expectedDelivery ?? '').isNotEmpty)
                        pw.Text('Exp. Delivery : ${p.expectedDelivery}', style: const pw.TextStyle(fontSize: 9)),
                      if ((p.customerRefNo ?? '').isNotEmpty)
                        pw.Text('PO / Ref No. : ${p.customerRefNo}', style: const pw.TextStyle(fontSize: 9)),
                      if ((p.addedBy ?? '').isNotEmpty)
                        pw.Text('Prepared By : ${p.addedBy}', style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 3),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: _statusColor(p.proformaStatus),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(p.proformaStatus,
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // ── Items table ────────────────────────────────────────────
            pw.Table(
              border: pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.4),
                1: const pw.FlexColumnWidth(2.6),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(0.8),
                4: const pw.FlexColumnWidth(1.2),
                5: const pw.FlexColumnWidth(0.8),
                6: const pw.FlexColumnWidth(1.2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _brandBlue),
                  children: ['#', 'Item name', 'HSN/SAC', 'Qty', 'Price/ Unit', 'Tax', 'Amount']
                      .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: pw.Text(h,
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ))
                      .toList(),
                ),
                for (int i = 0; i < p.lineItems.length; i++) _lineItemRow(i + 1, p.lineItems[i], i.isEven),
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
                      child: pw.Text('${p.totalQty}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.SizedBox(),
                    pw.SizedBox(),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: pw.Text('Rs. ${p.subtotal.toStringAsFixed(2)}',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // ── Amount in words / totals ─────────────────────────────────
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
                      pw.Text(_amountInWords(p.grandTotal), style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 14),
                      pw.Text('Terms and Conditions',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text(p.termsNotes ?? 'Thanks for doing business with us!',
                          style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    children: [
                      _totalRow('Sub Total', 'Rs. ${p.subtotal.toStringAsFixed(2)}'),
                      if (p.totalTax > 0) _totalRow('Tax', 'Rs. ${p.totalTax.toStringAsFixed(2)}'),
                      if (p.shipping > 0) _totalRow('Shipping', 'Rs. ${p.shipping.toStringAsFixed(2)}'),
                      if (p.roundOffEnabled) _totalRow('Round Off', 'Rs. ${p.roundOffAmount.toStringAsFixed(2)}'),
                      pw.Container(
                        margin: const pw.EdgeInsets.symmetric(vertical: 4),
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        color: _brandBlue,
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Estimated Total',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                            pw.Text('Rs. ${p.grandTotal.toStringAsFixed(2)}',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // ── Signatory ──────────────────────────────────────────────
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

  static pw.TableRow _lineItemRow(int index, InvoiceLineItem li, bool isEven) => pw.TableRow(
    decoration: pw.BoxDecoration(color: isEven ? _rowTint : PdfColors.white),
    children: [
      _cell('$index'),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(li.description, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            if ((li.skuCode ?? '').isNotEmpty)
              pw.Text('SKU: ${li.skuCode}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          ],
        ),
      ),
      _cell((li.hsnCode ?? '').isNotEmpty ? li.hsnCode! : '—'),
      _cell('${li.quantity} ${li.unit == 'NONE' ? '' : li.unit}'),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: pw.Text('Rs. ${li.unitPrice.toStringAsFixed(2)}',
            textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
      ),
      _cell(li.taxPercent > 0 ? '${li.taxPercent.toStringAsFixed(0)}%' : '—'),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: pw.Text('Rs. ${li.lineTotal.toStringAsFixed(2)}',
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

  static pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
    child: pw.Text(text,
        style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
  );
}
