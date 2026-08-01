// lib/services/sale_order_pdf_service.dart
//
// SkyLynk-branded Sale Order PDF — same letterhead, logo and visual
// pattern as EstimatePdfService / DeliveryChallanPdfService, adapted for
// sale orders (order/delivery date instead of received/balance, optional
// GST breakdown, order status badge).
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cda_inventory/models/sale_order.dart';
import 'package:cda_inventory/models/invoice_line_item.dart';

class SaleOrderPdfService {
  // ── SkyLynk brand + company details (same as the tax invoice/estimate) ──
  static const _brandBlue = PdfColor.fromInt(0xFF1F6FB2);
  static const _rowTint   = PdfColor.fromInt(0xFFF5F8FB);
  static const _amber     = PdfColor.fromInt(0xFFFFB800);
  static const _green     = PdfColor.fromInt(0xFF00B894);
  static const _red       = PdfColor.fromInt(0xFFFF6B6B);

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

  static PdfColor _statusColor(String s) {
    switch (s) {
      case 'Closed':
        return _green;
      case 'Cancelled':
        return _red;
      default:
        return _amber;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SALE ORDER — matches the SkyLynk Estimate/Tax Invoice layout
  // ═══════════════════════════════════════════════════════════════════════
  static Future<Uint8List> generate(SaleOrder order) async {
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
              child: pw.Text('Sale Order',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _brandBlue)),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.grey400, thickness: 1),
            pw.SizedBox(height: 14),

            // ── Customer / Order details ─────────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Order For', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        (order.customer?.name ?? '').isNotEmpty ? order.customer!.name : '-',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      if ((order.customer?.billingAddress ?? '').isNotEmpty)
                        pw.Text(order.customer!.billingAddress!, style: const pw.TextStyle(fontSize: 9)),
                      if ((order.customer?.phone ?? '').isNotEmpty)
                        pw.Text('Contact No. : ${order.customer?.phone}',
                            style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Order Details',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      _metaRow('Order No.', order.orderNo.isEmpty ? '-' : order.orderNo),
                      _metaRow('Order Date', order.orderDate),
                      if ((order.deliveryDate ?? '').isNotEmpty) _metaRow('Delivery Date', order.deliveryDate!),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: _statusColor(order.status),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(order.status,
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // ── Item table ────────────────────────────────────────────
            pw.Table(
              border: pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
              columnWidths: order.gstEnabled
                  ? {
                0: const pw.FlexColumnWidth(0.4),
                1: const pw.FlexColumnWidth(2.6),
                2: const pw.FlexColumnWidth(0.9),
                3: const pw.FlexColumnWidth(1.3),
                4: const pw.FlexColumnWidth(1.3),
              }
                  : {
                0: const pw.FlexColumnWidth(0.4),
                1: const pw.FlexColumnWidth(2.6),
                2: const pw.FlexColumnWidth(0.9),
                3: const pw.FlexColumnWidth(0.9),
                4: const pw.FlexColumnWidth(1.3),
                5: const pw.FlexColumnWidth(1.3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _brandBlue),
                  children: (order.gstEnabled
                      ? ['#', 'Item name', 'Quantity', 'Price/ Unit', 'Amount']
                      : ['#', 'Item name', 'Quantity', 'Tax %', 'Price/ Unit', 'Amount'])
                      .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: pw.Text(h,
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ))
                      .toList(),
                ),
                for (int i = 0; i < order.lineItems.length; i++)
                  _lineItemRow(i + 1, order.lineItems[i], i.isEven, order.gstEnabled),
              ],
            ),
            pw.SizedBox(height: 16),

            // ── Notes / totals ───────────────────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Notes',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      pw.Text(order.notes.isEmpty ? 'Terms, delivery instructions, etc.' : order.notes,
                          style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    children: [
                      _totalRow('Subtotal', 'Rs. ${order.subtotal.toStringAsFixed(2)}'),
                      if (order.gstEnabled && !order.isInterState) ...[
                        _totalRow('CGST (${order.cgstPercent.toStringAsFixed(0)}%)', 'Rs. ${order.cgstAmount.toStringAsFixed(2)}'),
                        _totalRow('SGST (${order.sgstPercent.toStringAsFixed(0)}%)', 'Rs. ${order.sgstAmount.toStringAsFixed(2)}'),
                      ],
                      if (order.gstEnabled && order.isInterState)
                        _totalRow('IGST (${order.igstPercent.toStringAsFixed(0)}%)', 'Rs. ${order.igstAmount.toStringAsFixed(2)}'),
                      if (!order.gstEnabled && order.lineTaxTotal > 0)
                        _totalRow('Tax', 'Rs. ${order.lineTaxTotal.toStringAsFixed(2)}'),
                      if (order.shipping > 0) _totalRow('Shipping', 'Rs. ${order.shipping.toStringAsFixed(2)}'),
                      if (order.roundOffEnabled && order.roundOffAmount != 0)
                        _totalRow('Round Off', 'Rs. ${order.roundOffAmount.toStringAsFixed(2)}'),
                      pw.Container(
                        margin: const pw.EdgeInsets.symmetric(vertical: 4),
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        color: _brandBlue,
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                            pw.Text('Rs. ${order.grandTotal.toStringAsFixed(2)}',
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

  static pw.Widget _metaRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Text('$label: $value', style: const pw.TextStyle(fontSize: 9)),
  );

  // ── SkyLynk-style item row: #, item name, qty, [tax%], price/unit,
  // amount — matches the reference estimate/invoice columns ──────────────
  static pw.TableRow _lineItemRow(int index, InvoiceLineItem li, bool even, bool gstEnabled) => pw.TableRow(
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
              pw.Text('HSN: ${li.hsnCode}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          ],
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Text('${li.quantity} ${li.unit == 'NONE' ? '' : li.unit}', style: const pw.TextStyle(fontSize: 9)),
      ),
      if (!gstEnabled)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: pw.Text('${li.taxPercent.toStringAsFixed(0)}%', style: const pw.TextStyle(fontSize: 9)),
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
