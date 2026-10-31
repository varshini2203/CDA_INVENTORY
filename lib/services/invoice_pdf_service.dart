// lib/services/invoice_pdf_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cda_inventory/models/invoice.dart';
import 'package:cda_inventory/models/invoice_line_item.dart';
import 'package:cda_inventory/constants/signature_data.dart';

class InvoicePdfService {
  static const _navy  = PdfColor.fromInt(0xFF0A1628);
  static const _teal  = PdfColor.fromInt(0xFF00D4AA);
  static const _amber = PdfColor.fromInt(0xFFFFB800);
  static const _coral = PdfColor.fromInt(0xFFFF6B6B);
  static const _green = PdfColor.fromInt(0xFF00B894);
  static const _grey  = PdfColor.fromInt(0xFFF0F4F8);

  // ── SkyLynk brand + company details (from the reference invoice) ─────────
  static const _brandBlue = PdfColor.fromInt(0xFF1F6FB2);
  static const _rowTint   = PdfColor.fromInt(0xFFEFF7FE);
  static const _navyMid   = PdfColor.fromInt(0xFF16345C);
  static const _ink       = PdfColor.fromInt(0xFF1F2937);
  static const _muted     = PdfColor.fromInt(0xFF475569);
  static const _hairline  = PdfColor.fromInt(0xFFBBD8F2);
  static const _onNavy    = PdfColor.fromInt(0xFFC9D6E8);
  // ── Light-blue invoice theme ─────────────────────────────────────────────
  static const _skyBg     = PdfColor.fromInt(0xFFEAF4FD);
  static const _blueDark  = PdfColor.fromInt(0xFF1760AA);
  static const _skyMid    = PdfColor.fromInt(0xFFD2E7F9);
  static const _skyAccent = PdfColor.fromInt(0xFF4FB3F6);
  static const _skyDeep   = PdfColor.fromInt(0xFF0F4C81);
  static const _skyText   = PdfColor.fromInt(0xFF4A6B8A);

  static const _companyName        = 'SKYLYNK';
  static const _companyAddressLine = 'No 63 West Karikalan Street, Adambakkam , Chennai';
  static const _companyPhone       = '9566145003';
  static const _companyEmail       = 'Info@chennaidroneacademy.com';
  static const _companyGstin       = '33FISPK9632P1Z9';
  static const _companyState       = '33-Tamil Nadu';

  static const _bankName            = 'INDIAN BANK, NANDHIVARAM';
  static const _bankAccountNo       = '7192409057';
  static const _bankIfsc            = 'IDIB000N144';
  static const _bankAccountHolder   = 'INDIAN BANK';

  static Uint8List? _cachedLogo;
  static Uint8List? _cachedSkylynkLogo;

  static Future<Uint8List> _loadLogo() async {
    if (_cachedLogo != null) return _cachedLogo!;
    final data = await rootBundle.load('assets/images/logo.png');
    _cachedLogo = data.buffer.asUint8List();
    return _cachedLogo!;
  }

  // ── SkyLynk letterhead logo, used on the tax invoice itself ──────────────
  static Future<Uint8List> _loadSkylynkLogo() async {
    if (_cachedSkylynkLogo != null) return _cachedSkylynkLogo!;
    final data = await rootBundle.load('assets/images/skylynk.jpg');
    _cachedSkylynkLogo = data.buffer.asUint8List();
    return _cachedSkylynkLogo!;
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
      case 'Paid': return _green;
      case 'Overdue': return _coral;
      case 'Partially Paid': return PdfColor.fromInt(0xFF6C63FF);
      default: return _amber;
    }
  }

  // ── Logo watermark — centered, faint, behind all content on the page ────
  static pw.Widget _watermark(Uint8List logoBytes) => pw.Positioned.fill(
    child: pw.Center(
      child: pw.Opacity(
        opacity: 0.07,
        child: pw.Image(
          pw.MemoryImage(logoBytes),
          width: 320,
          height: 320,
          fit: pw.BoxFit.contain,
        ),
      ),
    ),
  );

  static pw.Widget _letterhead(Uint8List logoBytes, {required String rightTitle, required String rightSubtitle}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(colors: [_navy, PdfColor.fromInt(0xFF162944)]),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 42,
                height: 42,
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                padding: const pw.EdgeInsets.all(4),
                child: pw.Image(pw.MemoryImage(logoBytes)),
              ),
              pw.SizedBox(width: 12),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CHENNAI DRONE ACADEMY',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text('SkyLNK Unmanned Pvt. Ltd.',
                      style: const pw.TextStyle(color: _teal, fontSize: 9)),
                ],
              ),
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

  // ═══════════════════════════════════════════════════════════════════════
  // SINGLE INVOICE — SkyLynk tax invoice, matching the reference layout
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Uint8List> generate(Invoice inv) async {
    final skylynkLogo = await _loadSkylynkLogo();
    final signature = base64Decode(kSignatureBase64);
    final doc = pw.Document();
    final party = inv.customer?.name ?? inv.vendorName;
    final status = inv.effectiveStatus;
    final hasBank = (inv.bankDetails ?? '').trim().isNotEmpty;

    pw.Widget cap(String t) => pw.Text(t,
        style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: _brandBlue,
            letterSpacing: 1.3));

    pw.Widget body(String t, {bool bold = false, double size = 10, PdfColor color = _ink}) =>
        pw.Text(t,
            style: pw.TextStyle(
                fontSize: size,
                color: color,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal));

    pw.Widget head(String t, {bool right = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      child: pw.Text(t,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1)),
    );

    pw.Widget detailRow(String k, pw.Widget v) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(children: [
        pw.SizedBox(width: 56, child: body(k, color: _muted)),
        v,
      ]),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Blue header ────────────────────────────────────────────
            pw.Container(
              width: double.infinity,
              color: _skyDeep,
              padding: const pw.EdgeInsets.fromLTRB(40, 30, 40, 26),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 62,
                    height: 62,
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Image(pw.MemoryImage(skylynkLogo), fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(_companyName,
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 22,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 2)),
                        pw.SizedBox(height: 4),
                        body(_companyAddressLine, size: 9, color: _onNavy),
                        body('Phone: $_companyPhone  |  $_companyEmail', size: 9, color: _onNavy),
                        body('GSTIN: $_companyGstin', size: 9, color: _onNavy),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 3)),
                      pw.SizedBox(height: 8),
                      body('No. ${inv.invoiceNo}', bold: true, size: 10.5, color: PdfColors.white),
                      pw.SizedBox(height: 2),
                      body(inv.purchaseDate, size: 10, color: _onNavy),
                    ],
                  ),
                ],
              ),
            ),
            pw.Container(height: 5, width: double.infinity, color: _skyAccent),

            // ── Body ───────────────────────────────────────────────────
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(40, 26, 40, 0),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Billed to + details in one soft blue panel
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        color: _skyBg,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 3,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                cap('BILLED TO'),
                                pw.SizedBox(height: 7),
                                body(party, bold: true, size: 13),
                                pw.SizedBox(height: 3),
                                if ((inv.customer?.billingAddress ?? '').isNotEmpty)
                                  body(inv.customer!.billingAddress!, color: _muted),
                                if ((inv.customer?.shippingAddress ?? '').isNotEmpty &&
                                    inv.customer!.shippingAddress != inv.customer!.billingAddress)
                                  body('Ship to: ${inv.customer!.shippingAddress}', color: _muted),
                                if ((inv.customer?.phone ?? '').isNotEmpty)
                                  body(inv.customer!.phone!, color: _muted),
                                if ((inv.customer?.email ?? '').isNotEmpty)
                                  body(inv.customer!.email!, color: _muted),
                                if ((inv.customer?.gstin ?? '').isNotEmpty)
                                  body('GSTIN: ${inv.customer!.gstin}', color: _muted),
                              ],
                            ),
                          ),
                          pw.Container(width: 1, height: 60, color: _skyMid),
                          pw.SizedBox(width: 18),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                cap('DETAILS'),
                                pw.SizedBox(height: 7),
                                detailRow(
                                  'Status',
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: pw.BoxDecoration(
                                      color: _statusColor(status),
                                      borderRadius: pw.BorderRadius.circular(8),
                                    ),
                                    child: pw.Text(status.toUpperCase(),
                                        style: pw.TextStyle(
                                            fontSize: 8,
                                            color: PdfColors.white,
                                            fontWeight: pw.FontWeight.bold,
                                            letterSpacing: 0.6)),
                                  ),
                                ),
                                detailRow('Payment', body(inv.paymentMode, bold: true)),
                                if (inv.customer != null)
                                  detailRow('Supply', body(inv.customer!.placeOfSupply, bold: true)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 22),

                    // Items
                    pw.Table(
                      border: const pw.TableBorder(
                        bottom: pw.BorderSide(color: _skyMid, width: 0.8),
                        horizontalInside: pw.BorderSide(color: _skyMid, width: 0.8),
                      ),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(0.4),
                        1: const pw.FlexColumnWidth(3.2),
                        2: const pw.FlexColumnWidth(1.1),
                        3: const pw.FlexColumnWidth(0.7),
                        4: const pw.FlexColumnWidth(1.3),
                        5: const pw.FlexColumnWidth(1.4),
                      },
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: _blueDark,
                            borderRadius: const pw.BorderRadius.only(
                              topLeft: pw.Radius.circular(6),
                              topRight: pw.Radius.circular(6),
                            ),
                          ),
                          children: [
                            head('#'),
                            head('ITEM'),
                            head('HSN/SAC'),
                            head('QTY'),
                            head('PRICE', right: true),
                            head('AMOUNT', right: true),
                          ],
                        ),
                        if (inv.usesLineItems)
                          for (int i = 0; i < inv.lineItems.length; i++)
                            _skylynkLineItemRow(i + 1, inv.lineItems[i], true)
                        else
                          _skylynkLineItemRowLegacy(inv),
                      ],
                    ),
                    pw.SizedBox(height: 20),

                    // Words / notes  |  totals
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 5,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              cap('AMOUNT IN WORDS'),
                              pw.SizedBox(height: 4),
                              body(_amountInWords(inv.grandTotal), bold: true),
                              if (inv.notes != null && inv.notes!.trim().isNotEmpty) ...[
                                pw.SizedBox(height: 14),
                                cap('NOTES'),
                                pw.SizedBox(height: 4),
                                body(inv.notes!.trim(), color: _muted),
                              ],
                              pw.SizedBox(height: 14),
                              cap('TERMS & CONDITIONS'),
                              pw.SizedBox(height: 4),
                              body(inv.termsNotes ?? 'Thanks for doing business with us!',
                                  color: _muted),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 30),
                        pw.Expanded(
                          flex: 4,
                          child: pw.Column(
                            children: [
                              _skylynkTotalRow('Sub Total', 'Rs. ${inv.subtotal.toStringAsFixed(2)}'),
                              if (inv.gstEnabled && inv.isInterState)
                                _skylynkTotalRow('IGST (${_trimPercent(inv.igstPercent)}%)',
                                    'Rs. ${inv.igstAmount.toStringAsFixed(2)}'),
                              if (inv.gstEnabled && !inv.isInterState) ...[
                                _skylynkTotalRow('CGST (${_trimPercent(inv.cgstPercent)}%)',
                                    'Rs. ${inv.cgstAmount.toStringAsFixed(2)}'),
                                _skylynkTotalRow('SGST (${_trimPercent(inv.sgstPercent)}%)',
                                    'Rs. ${inv.sgstAmount.toStringAsFixed(2)}'),
                              ],
                              if (inv.usesLineItems && inv.lineTaxTotal > 0 && !inv.gstEnabled)
                                _skylynkTotalRow('Tax', 'Rs. ${inv.lineTaxTotal.toStringAsFixed(2)}'),
                              if (inv.shipping > 0)
                                _skylynkTotalRow('Shipping Charge', 'Rs. ${inv.shipping.toStringAsFixed(2)}'),
                              if (inv.shippingTaxAmount > 0)
                                _skylynkTotalRow('Shipping Tax (${_trimPercent(inv.shippingTaxRate)}%)',
                                    'Rs. ${inv.shippingTaxAmount.toStringAsFixed(2)}'),
                              if (inv.roundOffEnabled && inv.roundOffAmount != 0)
                                _skylynkTotalRow('Round Off',
                                    '${inv.roundOffAmount >= 0 ? '+' : '-'}Rs. ${inv.roundOffAmount.abs().toStringAsFixed(2)}'),
                              pw.SizedBox(height: 6),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: pw.BoxDecoration(
                                  color: _skyDeep,
                                  borderRadius: pw.BorderRadius.circular(6),
                                ),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text('TOTAL',
                                        style: pw.TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: pw.FontWeight.bold,
                                            color: PdfColors.white,
                                            letterSpacing: 1)),
                                    pw.Text('Rs. ${inv.grandTotal.toStringAsFixed(2)}',
                                        style: pw.TextStyle(
                                            fontSize: 14,
                                            fontWeight: pw.FontWeight.bold,
                                            color: PdfColors.white)),
                                  ],
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              _skylynkTotalRow('Received', 'Rs. ${inv.amountPaid.toStringAsFixed(2)}'),
                              _skylynkTotalRow('Balance', 'Rs. ${inv.balanceDue.toStringAsFixed(2)}'),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.Spacer(),

                    // Bank details  |  signatory
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Expanded(
                          flex: 5,
                          child: pw.Container(
                            padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
                            decoration: const pw.BoxDecoration(
                              color: _skyBg,
                              border: pw.Border(
                                left: pw.BorderSide(color: _brandBlue, width: 3),
                              ),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                cap('BANK DETAILS'),
                                pw.SizedBox(height: 5),
                                if (hasBank)
                                  body(inv.bankDetails!.trim())
                                else ...[
                                  body('Bank Name : $_bankName'),
                                  body('Account No. : $_bankAccountNo'),
                                  body('IFSC code : $_bankIfsc'),
                                  body("Account holder's name : $_bankAccountHolder"),
                                ],
                              ],
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 30),
                        pw.Expanded(
                          flex: 4,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              body('For $_companyName', bold: true),
                              pw.Container(
                                width: 150,
                                height: 44,
                                alignment: pw.Alignment.center,
                                child: pw.Image(pw.MemoryImage(signature),
                                    fit: pw.BoxFit.contain),
                              ),
                              pw.Container(width: 150, height: 0.8, color: _muted),
                              pw.SizedBox(height: 4),
                              body('Authorized Signatory', size: 9, color: _muted),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Footer ─────────────────────────────────────────────────
            pw.Container(
              width: double.infinity,
              color: _skyDeep,
              padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Thank you for your business!',
                      style: pw.TextStyle(
                          color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  body(_companyEmail, size: 9.5, color: _onNavy),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  // Tinted rounded card with a small blue caption (Bill To / Payment / Pay To).
  static pw.Widget _infoCard(String title, List<pw.Widget> children) => pw.Container(
    width: double.infinity,
    constraints: const pw.BoxConstraints(minHeight: 88),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: _rowTint,
      borderRadius: pw.BorderRadius.circular(8),
      border: pw.Border.all(color: _hairline, width: 0.8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _brandBlue,
                letterSpacing: 1.0)),
        pw.SizedBox(height: 6),
        ...children,
      ],
    ),
  );

  static pw.Widget _smallHeading(String text) => pw.Text(text,
      style: pw.TextStyle(
          fontSize: 9, fontWeight: pw.FontWeight.bold, color: _brandBlue, letterSpacing: 0.8));

  // ═══════════════════════════════════════════════════════════════════════
  // REPORT — multi-invoice summary (used by the Invoices list "Export as PDF")
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Uint8List> generateReport(
      List<Invoice> invoices, {
        required double totalAmount,
        required int paidCount,
        required int pendingCount,
        required int overdueCount,
      }) async {
    final logoBytes = await _loadLogo();
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 16),
          child: _letterhead(logoBytes,
              rightTitle: 'INVOICES REPORT',
              rightSubtitle: 'Generated: ${DateTime.now().toString().split('.').first}'),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ),
        build: (context) => [
          pw.Stack(
            children: [
              _watermark(logoBytes),
              pw.Column(
                children: [
                  pw.Row(
                    children: [
                      _statCard('Total Invoices', '${invoices.length}', _navy),
                      pw.SizedBox(width: 8),
                      _statCard('Paid', '$paidCount', _green),
                      pw.SizedBox(width: 8),
                      _statCard('Pending', '$pendingCount', _amber),
                      pw.SizedBox(width: 8),
                      _statCard('Overdue', '$overdueCount', _coral),
                    ],
                  ),
                  pw.SizedBox(height: 18),
                  pw.Table(
                    border: pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.6),
                      1: const pw.FlexColumnWidth(1.8),
                      2: const pw.FlexColumnWidth(1.6),
                      3: const pw.FlexColumnWidth(0.8),
                      4: const pw.FlexColumnWidth(1.3),
                      5: const pw.FlexColumnWidth(1.3),
                      6: const pw.FlexColumnWidth(1.1),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: _navy),
                        children: ['Invoice No', 'Product', 'Vendor', 'Qty', 'Amount', 'Date', 'Status']
                            .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          child: pw.Text(h,
                              style: pw.TextStyle(
                                  color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ))
                            .toList(),
                      ),
                      for (int i = 0; i < invoices.length; i++)
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _grey),
                          children: [
                            _cell(invoices[i].invoiceNo, bold: true),
                            _cell(invoices[i].displayProductName),
                            _cell(invoices[i].vendorName),
                            _cell('${invoices[i].displayQuantity}'),
                            _cell('Rs. ${invoices[i].displayAmount.toStringAsFixed(2)}', color: _green, bold: true),
                            _cell(invoices[i].purchaseDate),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                              child: pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: pw.BoxDecoration(
                                  color: _statusColor(invoices[i].effectiveStatus),
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                                child: pw.Text(invoices[i].effectiveStatus,
                                    style: pw.TextStyle(
                                        fontSize: 7.5, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  pw.Container(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.circular(8)),
                      child: pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text('TOTAL VALUE   ', style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                          pw.Text('Rs. ${totalAmount.toStringAsFixed(2)}',
                              style: pw.TextStyle(color: _teal, fontSize: 15, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ── Shared helpers ────────────────────────────────────────────────────
  static pw.Widget _statCard(String label, String value, PdfColor accent) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: _grey, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: accent)),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ],
      ),
    ),
  );

  // ── SkyLynk tax-invoice item row: #, item name (+ serial no.), HSN/SAC,
  // qty, price/unit, amount — matches the reference invoice's columns ──────
  static pw.TableRow _skylynkLineItemRow(int index, InvoiceLineItem li, bool even) => pw.TableRow(
    decoration: const pw.BoxDecoration(color: PdfColors.white),
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        child: pw.Text('$index', style: const pw.TextStyle(fontSize: 10.5)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(li.description, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
            if ((li.hsnCode ?? '').isNotEmpty)
              pw.Text('Serial No.: ${li.hsnCode}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          ],
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        child: pw.Text('', style: const pw.TextStyle(fontSize: 10.5)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        child: pw.Text('${li.quantity}', style: const pw.TextStyle(fontSize: 10.5)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        child: pw.Text('Rs. ${li.unitPrice.toStringAsFixed(2)}',
            textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10.5)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        child: pw.Text('Rs. ${li.taxableAmount.toStringAsFixed(2)}',
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
      ),
    ],
  );

  static pw.TableRow _skylynkLineItemRowLegacy(Invoice inv) => pw.TableRow(
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        child: pw.Text('1', style: const pw.TextStyle(fontSize: 10.5)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        child: pw.Text(inv.productName, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        child: pw.Text('', style: const pw.TextStyle(fontSize: 10.5)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        child: pw.Text('${inv.quantity}', style: const pw.TextStyle(fontSize: 10.5)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        child: pw.Text('Rs. ${inv.amount.toStringAsFixed(2)}',
            textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10.5)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        child: pw.Text('Rs. ${(inv.amount * inv.quantity).toStringAsFixed(2)}',
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
      ),
    ],
  );

  static pw.Widget _skylynkTotalRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10.5, color: _muted)),
        pw.Text(value, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _ink)),
      ],
    ),
  );

  // Drops a trailing '.0' (9.0 -> '9') but keeps real decimals (9.5 -> '9.5'),
  // for tax-percentage labels like 'CGST (9%)'.
  static String _trimPercent(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();

  static pw.Widget _cell(String text, {bool bold = false, PdfColor? color}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
    child: pw.Text(text,
        style: pw.TextStyle(
            fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
  );
}