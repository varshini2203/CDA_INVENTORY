// lib/services/estimate_pdf_service.dart
//
// SkyLynk-branded Estimate / Quotation PDF. Same brand blue, logo and
// company details as before, in a modern layout: blue letterhead card,
// soft info cards, zebra item table, highlighted grand total, multi-page
// safe (long estimates continue on extra pages with a slim header).
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cda_inventory/constants/signature_data.dart';
import 'package:cda_inventory/models/estimate.dart';
import 'package:cda_inventory/models/invoice_line_item.dart';

class EstimatePdfService {
// ── SkyLynk brand + company details (same as the tax invoice) ──────────
  static const _brandBlue = PdfColor.fromInt(0xFF1F6FB2);
  static const _rowTint   = PdfColor.fromInt(0xFFEFF7FE);
  static const _amber     = PdfColor.fromInt(0xFFFFB800);
  static const _green     = PdfColor.fromInt(0xFF00B894);
  static const _grey      = PdfColor.fromInt(0xFF9CA3AF);

// Tints of the same brand blue + neutral text colours
  static const _blueTint  = PdfColor.fromInt(0xFFEFF7FE);
  static const _blueLine  = PdfColor.fromInt(0xFFBBD8F2);
  static const _onBlue    = PdfColor.fromInt(0xFFEAF4FD);
  static const _blueDark  = PdfColor.fromInt(0xFF1760AA);
  static const _skyAccent = PdfColor.fromInt(0xFF4FB3F6);
  static const _ink       = PdfColor.fromInt(0xFF1F2937);
  static const _mute      = PdfColor.fromInt(0xFF475569);

  static const _companyName        = 'SKYLYNK';
  static const _companyAddressLine = 'No 63 West Karikalan Street, Adambakkam , Chennai';
  static const _companyPhone       = '9566145003';
  static const _companyEmail       = 'Info@chennaidroneacademy.com';
  static const _companyGstin       = '33FISPK9632P1Z9';
  static const _companyState       = '33-Tamil Nadu';

  static const _bankName          = 'INDIAN BANK, NANDHIVARAM';
  static const _bankAccountNo     = '7192409057';
  static const _bankIfsc          = 'IDIB000N144';
  static const _bankAccountHolder = 'INDIAN BANK';

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
// SINGLE ESTIMATE / QUOTATION
// ═══════════════════════════════════════════════════════════════════════
  static Future<Uint8List> generate(Estimate est) async {
    final logo = pw.MemoryImage(await _loadSkylynkLogo());
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 24),
        ),
// Full letterhead on page 1, slim header on continuation pages.
        header: (ctx) => ctx.pageNumber == 1
            ? _letterhead(logo, est)
            : _continuationHeader(est),
        footer: (ctx) => _footer(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 16),
          _titleStrip(est),
          pw.SizedBox(height: 14),
          _partyAndMeta(est),
          pw.SizedBox(height: 16),
          _itemsTable(est),
          pw.SizedBox(height: 16),
          _summary(est),
          pw.SizedBox(height: 30),
          _bankAndSignatory(est),
        ],
      ),
    );

    return doc.save();
  }

// ── Light-blue gradient letterhead: logo, company, ESTIMATE badge ──────
  static pw.Widget _letterhead(pw.MemoryImage logo, Estimate est) => pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(20, 20, 20, 20),
    decoration: pw.BoxDecoration(
      gradient: const pw.LinearGradient(colors: [_blueDark, _skyAccent]),
      borderRadius: pw.BorderRadius.circular(12),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 74,
          height: 74,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Image(logo, fit: pw.BoxFit.contain),
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(_companyName,
                  style: pw.TextStyle(
                      fontSize: 27,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 1.5)),
              pw.SizedBox(height: 5),
              pw.Text(_companyAddressLine,
                  style: const pw.TextStyle(fontSize: 10, color: _onBlue)),
              pw.Text('Phone: $_companyPhone   |   $_companyEmail',
                  style: const pw.TextStyle(fontSize: 10, color: _onBlue)),
              pw.Text('GSTIN: $_companyGstin   |   State: $_companyState',
                  style: const pw.TextStyle(fontSize: 10, color: _onBlue)),
            ],
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: pw.BoxDecoration(
                color: _brandBlue,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Text('ESTIMATE',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2)),
            ),
            pw.SizedBox(height: 10),
            pw.Text('REFERENCE NO.', style: const pw.TextStyle(color: _onBlue, fontSize: 9)),
            pw.Text(est.referenceNo,
                style: pw.TextStyle(
                    color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text('DATE', style: const pw.TextStyle(color: _onBlue, fontSize: 9)),
            pw.Text(est.estimateDate,
                style: pw.TextStyle(
                    color: PdfColors.white, fontSize: 12.5, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ],
    ),
  );

  static pw.Widget _continuationHeader(Estimate est) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.only(bottom: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _brandBlue, width: 1.2)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(_companyName,
            style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _brandBlue,
                letterSpacing: 1)),
        pw.Text('Estimate / Quotation  ·  ${est.referenceNo}  (continued)',
            style: const pw.TextStyle(fontSize: 10, color: _mute)),
      ],
    ),
  );

// ── Title + status pill ─────────────────────────────────────────────────
  static pw.Widget _titleStrip(Estimate est) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('ESTIMATE / QUOTATION',
              style: pw.TextStyle(
                  fontSize: 19,
                  fontWeight: pw.FontWeight.bold,
                  color: _brandBlue,
                  letterSpacing: 1)),
          pw.SizedBox(height: 4),
          pw.Container(width: 48, height: 3, color: _brandBlue),
        ],
      ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: pw.BoxDecoration(
          color: _statusColor(est.effectiveStatus),
          borderRadius: pw.BorderRadius.circular(12),
        ),
        child: pw.Text(est.effectiveStatus,
            style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold)),
      ),
    ],
  );

// ── "Quotation To" + "Estimate Details" cards ───────────────────────────
  static pw.Widget _partyAndMeta(Estimate est) {
    final name = est.customer?.name.isNotEmpty == true
        ? est.customer!.name
        : est.partyName;
    final phone = est.customer?.phone ?? est.partyPhone ?? '';
    final address = est.customer?.billingAddress ?? '';
    final state = est.customer?.placeOfSupply ?? '';
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 3,
          child: _infoCard('QUOTATION TO', [
            pw.Text(name,
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink)),
            if (address.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(address,
                    style: const pw.TextStyle(fontSize: 10.5, color: _ink)),
              ),
            if (phone.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text('Contact No. : $phone',
                    style: const pw.TextStyle(fontSize: 10.5, color: _ink)),
              ),
            if (state.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text('State : $state',
                    style: const pw.TextStyle(fontSize: 10.5, color: _ink)),
              ),
          ], minHeight: 88),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          flex: 2,
          child: _infoCard('ESTIMATE DETAILS', [
            _kv('Reference No.', est.referenceNo),
            pw.SizedBox(height: 3),
            _kv('Date', est.estimateDate),
            if ((est.validTill ?? '').isNotEmpty) ...[
              pw.SizedBox(height: 3),
              _kv('Valid Till', est.validTill!),
            ],
          ], minHeight: 88),
        ),
      ],
    );
  }

  static pw.Widget _infoCard(String title, List<pw.Widget> body, {double minHeight = 0}) => pw.Container(
    width: double.infinity,
    constraints: pw.BoxConstraints(minHeight: minHeight),
    padding: const pw.EdgeInsets.all(11),
    decoration: pw.BoxDecoration(
      color: _blueTint,
      borderRadius: pw.BorderRadius.circular(8),
      border: pw.Border.all(color: _blueLine, width: 0.7),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _brandBlue,
                letterSpacing: 0.9)),
        pw.SizedBox(height: 6),
        ...body,
      ],
    ),
  );

  static pw.Widget _kv(String k, String v) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(k, style: const pw.TextStyle(fontSize: 10, color: _mute)),
      pw.Text(v,
          style: pw.TextStyle(
              fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink)),
    ],
  );

// ── Items table ─────────────────────────────────────────────────────────
  static pw.Widget _itemsTable(Estimate est) {
    const heads = ['#', 'Item name', 'HSN/ SAC', 'Qty', 'Price / Unit', 'Amount'];
    const aligns = [
      pw.TextAlign.left, pw.TextAlign.left, pw.TextAlign.left,
      pw.TextAlign.center, pw.TextAlign.right, pw.TextAlign.right,
    ];
    final totalQty = est.lineItems.fold<int>(0, (s, li) => s + li.quantity);
    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _blueLine, width: 0.5),
        bottom: pw.BorderSide(color: _brandBlue, width: 1),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.45),
        1: const pw.FlexColumnWidth(3.2),
        2: const pw.FlexColumnWidth(1.1),
        3: const pw.FlexColumnWidth(0.9),
        4: const pw.FlexColumnWidth(1.4),
        5: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _brandBlue),
          children: [
            for (int c = 0; c < heads.length; c++)
              _cell(heads[c],
                  align: aligns[c], bold: true, color: PdfColors.white, size: 10),
          ],
        ),
        for (int i = 0; i < est.lineItems.length; i++)
          _lineItemRow(i + 1, est.lineItems[i], i.isEven),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _blueTint),
          children: [
            _cell(''),
            _cell('Total', bold: true),
            _cell(''),
            _cell('$totalQty', align: pw.TextAlign.center, bold: true),
            _cell(''),
            _cell('Rs. ${est.subtotal.toStringAsFixed(2)}',
                align: pw.TextAlign.right, bold: true, color: _brandBlue),
          ],
        ),
      ],
    );
  }

  static pw.Widget _cell(
      String text, {
        pw.TextAlign align = pw.TextAlign.left,
        bool bold = false,
        PdfColor color = _ink,
        double size = 10.5,
      }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 11, horizontal: 7),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(
                fontSize: size,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color)),
      );

  static pw.TableRow _lineItemRow(int index, InvoiceLineItem li, bool even) =>
      pw.TableRow(
        decoration: pw.BoxDecoration(color: even ? PdfColors.white : _blueTint),
        children: [
          _cell('$index'),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 11, horizontal: 7),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(li.description,
                    style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink)),
                if ((li.skuCode ?? '').isNotEmpty)
                  pw.Text('SKU: ${li.skuCode}',
                      style: const pw.TextStyle(fontSize: 8.5, color: _mute)),
              ],
            ),
          ),
          _cell(li.hsnCode ?? ''),
          _cell('${li.quantity}', align: pw.TextAlign.center),
          _cell('Rs. ${li.unitPrice.toStringAsFixed(2)}', align: pw.TextAlign.right),
          _cell('Rs. ${li.taxableAmount.toStringAsFixed(2)}',
              align: pw.TextAlign.right, bold: true),
        ],
      );

// ── Amount in words / terms (left) + totals (right) ─────────────────────
  static pw.Widget _summary(Estimate est) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        flex: 3,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _infoCard('AMOUNT IN WORDS', [
              pw.Text(_amountInWords(est.grandTotal),
                  style: pw.TextStyle(
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink)),
            ]),
            pw.SizedBox(height: 12),
            pw.Text('TERMS AND CONDITIONS',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _brandBlue,
                    letterSpacing: 0.9)),
            pw.SizedBox(height: 4),
            pw.Text(est.termsNotes ?? 'Thanks for doing business with us!',
                style: const pw.TextStyle(fontSize: 10.5, color: _ink)),
          ],
        ),
      ),
      pw.SizedBox(width: 20),
      pw.Expanded(
        flex: 2,
        child: pw.Column(
          children: [
            _totalRow('Sub Total', 'Rs. ${est.subtotal.toStringAsFixed(2)}'),
            if (est.totalTax > 0)
              _totalRow('Tax', 'Rs. ${est.totalTax.toStringAsFixed(2)}'),
            if (est.shipping > 0)
              _totalRow('Shipping', 'Rs. ${est.shipping.toStringAsFixed(2)}'),
            if (est.roundOffEnabled && est.roundOffAmount != 0)
              _totalRow('Round Off', 'Rs. ${est.roundOffAmount.toStringAsFixed(2)}'),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: pw.BoxDecoration(
                gradient: const pw.LinearGradient(colors: [_brandBlue, _skyAccent]),
                borderRadius: pw.BorderRadius.circular(8),
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
                  pw.Text('Rs. ${est.grandTotal.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  static pw.Widget _totalRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10.5, color: _mute)),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _ink)),
      ],
    ),
  );

// ── Bank details (left) + signatory (right) ─────────────────────────────
  static pw.Widget _bankAndSignatory(Estimate est) {
    final hasBank = (est.bankDetails ?? '').trim().isNotEmpty;
    const t = pw.TextStyle(fontSize: 10.5, color: _ink);
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          flex: 3,
          child: _infoCard('PAY TO', [
            if (hasBank)
              pw.Text(est.bankDetails!.trim(), style: t)
            else ...[
              pw.Text('Bank Name : $_bankName', style: t),
              pw.Text('Account No. : $_bankAccountNo', style: t),
              pw.Text('IFSC code : $_bankIfsc', style: t),
              pw.Text("Account holder's name : $_bankAccountHolder", style: t),
            ],
          ]),
        ),
        pw.SizedBox(width: 22),
        pw.Expanded(flex: 2, child: _signatory()),
      ],
    );
  }

// ── Signatory ───────────────────────────────────────────────────────────
  static pw.Widget _signatory() => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text('For $_companyName',
              style: pw.TextStyle(
                  fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _ink)),
          pw.Container(
            width: 130,
            height: 36,
            alignment: pw.Alignment.center,
            child: pw.Image(
                pw.MemoryImage(base64Decode(kSignatureBase64)),
                fit: pw.BoxFit.contain),
          ),
          pw.Container(width: 140, height: 0.8, color: _mute),
          pw.SizedBox(height: 4),
          pw.Text('Authorized Signatory',
              style: const pw.TextStyle(fontSize: 10, color: _mute)),
        ],
      ),
    ],
  );

// ── Footer on every page: solid blue band ───────────────────────────────
  static pw.Widget _footer(pw.Context ctx) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 8),
    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    decoration: pw.BoxDecoration(
      color: _blueDark,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Thank you for your interest in $_companyName',
            style: pw.TextStyle(
                fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9.5, color: _onBlue)),
      ],
    ),
  );
}