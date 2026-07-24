// lib/services/invoice_pdf_service.dart
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cda_inventory/models/invoice.dart';
import 'package:cda_inventory/models/invoice_line_item.dart';

class InvoicePdfService {
  static const _navy  = PdfColor.fromInt(0xFF0A1628);
  static const _teal  = PdfColor.fromInt(0xFF00D4AA);
  static const _amber = PdfColor.fromInt(0xFFFFB800);
  static const _coral = PdfColor.fromInt(0xFFFF6B6B);
  static const _green = PdfColor.fromInt(0xFF00B894);
  static const _grey  = PdfColor.fromInt(0xFFF0F4F8);

  // ── SkyLynk brand + company details (from the reference invoice) ─────────
  static const _brandBlue = PdfColor.fromInt(0xFF1F6FB2);
  static const _rowTint   = PdfColor.fromInt(0xFFF5F8FB);

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
              child: pw.Text('Tax Invoice',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _brandBlue)),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.grey400, thickness: 1),
            pw.SizedBox(height: 14),

            // ── Bill To / Invoice details ───────────────────────────────
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
                      pw.Text(inv.customer?.name ?? inv.vendorName,
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      if ((inv.customer?.billingAddress ?? '').isNotEmpty)
                        pw.Text(inv.customer!.billingAddress!, style: const pw.TextStyle(fontSize: 9)),
                      if ((inv.customer?.phone ?? '').isNotEmpty)
                        pw.Text('Contact No. : ${inv.customer!.phone}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Invoice Details', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text('Invoice No. : ${inv.invoiceNo}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Date : ${inv.purchaseDate}', style: const pw.TextStyle(fontSize: 9)),
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
                if (inv.usesLineItems)
                  for (int i = 0; i < inv.lineItems.length; i++)
                    _skylynkLineItemRow(i + 1, inv.lineItems[i], i.isEven)
                else
                  _skylynkLineItemRowLegacy(inv),
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
                        '${inv.usesLineItems ? inv.lineItems.fold<int>(0, (s, li) => s + li.quantity) : inv.quantity}',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.SizedBox(),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: pw.Text('Rs. ${inv.subtotal.toStringAsFixed(2)}',
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
                      pw.Text('Invoice Amount In Words',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text(_amountInWords(inv.grandTotal), style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 14),
                      pw.Text('Terms and Conditions',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text(inv.termsNotes ?? 'Thanks for doing business with us!',
                          style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    children: [
                      _skylynkTotalRow('Sub Total', 'Rs. ${inv.subtotal.toStringAsFixed(2)}'),
                      pw.Container(
                        margin: const pw.EdgeInsets.symmetric(vertical: 4),
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        color: _brandBlue,
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                            pw.Text('Rs. ${inv.grandTotal.toStringAsFixed(2)}',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          ],
                        ),
                      ),
                      _skylynkTotalRow('Received', 'Rs. ${inv.amountPaid.toStringAsFixed(2)}'),
                      _skylynkTotalRow('Balance', 'Rs. ${inv.balanceDue.toStringAsFixed(2)}'),
                      _skylynkTotalRow('Payment mode', inv.paymentMode),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 26),

            // ── Bank details / signatory ────────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Pay To:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text('Bank Name : $_bankName', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Bank Account No. : $_bankAccountNo', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Bank IFSC code : $_bankIfsc', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text("Account holder's name : $_bankAccountHolder", style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('For :$_companyName', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 34),
                      pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

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
            if ((li.hsnCode ?? '').isNotEmpty)
              pw.Text('Serial No.: ${li.hsnCode}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          ],
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Text('', style: const pw.TextStyle(fontSize: 9)),
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

  static pw.TableRow _skylynkLineItemRowLegacy(Invoice inv) => pw.TableRow(
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Text('1', style: const pw.TextStyle(fontSize: 9)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Text(inv.productName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Text('', style: const pw.TextStyle(fontSize: 9)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Text('${inv.quantity}', style: const pw.TextStyle(fontSize: 9)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Text('Rs. ${inv.amount.toStringAsFixed(2)}',
            textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Text('Rs. ${(inv.amount * inv.quantity).toStringAsFixed(2)}',
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ),
    ],
  );

  static pw.Widget _skylynkTotalRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
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
}