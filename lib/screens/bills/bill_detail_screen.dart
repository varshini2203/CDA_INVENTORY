import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:cda_inventory/services/bills_service.dart';
import 'package:cda_inventory/services/bill_pdf_service.dart';
import 'package:cda_inventory/models/bill_model.dart';
import 'add_edit_bill_screen.dart';

// ── Design tokens (matches Invoice screens) ─────────────────────────────────
const Color kNavy = Color(0xFF0A1628);
const Color kTeal = Color(0xFF00D4AA);
const Color kCoral = Color(0xFFFF6B6B);
const Color kAmber = Color(0xFFFFB800);
const Color kSurface = Color(0xFFF0F4F8);
const Color kGreen = Color(0xFF00B894);
const Color kPurple = Color(0xFF6C63FF);

/// Returned by [BillDetailScreen] when it is popped, so BillsScreen can
/// update its local list without needing Provider/ChangeNotifier.
/// - `deleted: true`            -> caller should remove the bill from its list
/// - `updatedBill: BillModel`   -> caller should replace the bill in its list
/// - both null/false            -> nothing changed
class BillDetailResult {
  final BillModel? updatedBill;
  final bool deleted;
  const BillDetailResult({this.updatedBill, this.deleted = false});
}

class BillDetailScreen extends StatefulWidget {
  final BillModel bill;
  const BillDetailScreen({super.key, required this.bill});

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  late BillModel _bill;
  bool _isSharing = false;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _bill = widget.bill;
  }

  void _returnToList([BillDetailResult? result]) {
    Navigator.pop(context, result);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: isError ? kCoral : kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<void> _shareBill() async {
    setState(() => _isSharing = true);
    try {
      if (_bill.imageBase64.isEmpty) {
        throw Exception('No image available for this bill');
      }
      final bytes = base64Decode(_bill.imageBase64);
      final safeVendor = _bill.vendorName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

      // XFile.fromData works on Web, Android, iOS, and Desktop — no temp
      // directory / path_provider needed, which is what breaks on Web.
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: 'bill_$safeVendor.jpg',
            mimeType: 'image/jpeg',
          ),
        ],
        text:
        'Bill from ${_bill.vendorName} — #${_bill.billNumber} — ₹${_bill.amount.toStringAsFixed(2)}',
      );
    } catch (e) {
      if (mounted) {
        _showSnack('Unable to share bill right now', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // ── PDF generation, reused for both download & share ────────────────────
  Future<Uint8List?> _generatePdfBytes() async {
    setState(() => _isGeneratingPdf = true);
    try {
      return await BillPdfService.generate(_bill);
    } catch (e) {
      if (mounted) _showSnack('Failed to generate PDF: $e', isError: true);
      return null;
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _downloadPdf() async {
    final bytes = await _generatePdfBytes();
    if (bytes == null) return;
    // Printing.sharePdf triggers the browser's save/print dialog on web,
    // and the native share/save sheet on mobile & desktop.
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'bill_${_bill.billNumber}.pdf',
    );
  }

  Future<void> _sharePdfFile() async {
    final bytes = await _generatePdfBytes();
    if (bytes == null) return;
    await Share.shareXFiles(
      [
        XFile.fromData(bytes,
            name: 'bill_${_bill.billNumber}.pdf',
            mimeType: 'application/pdf'),
      ],
      subject: 'Bill ${_bill.billNumber}',
      text: 'Bill from ${_bill.vendorName} — #${_bill.billNumber}',
    );
  }

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Share / Export',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 17, color: kNavy)),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded, color: kCoral),
                title: const Text('Download PDF',
                    style: TextStyle(fontWeight: FontWeight.w600, color: kNavy)),
                subtitle: const Text('Bill details with the scanned receipt'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadPdf();
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: kTeal),
                title: const Text('Share PDF',
                    style: TextStyle(fontWeight: FontWeight.w600, color: kNavy)),
                subtitle: const Text('Send the bill PDF to an app or contact'),
                onTap: () {
                  Navigator.pop(context);
                  _sharePdfFile();
                },
              ),
              ListTile(
                leading: const Icon(Icons.image_rounded, color: kPurple),
                title: const Text('Share Image',
                    style: TextStyle(fontWeight: FontWeight.w600, color: kNavy)),
                subtitle: const Text('Send just the scanned photo'),
                onTap: () {
                  Navigator.pop(context);
                  _shareBill();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editBill() async {
    final updated = await Navigator.push<BillModel>(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'Add Edit Bill'),
        builder: (_) => AddEditBillScreen(existingBill: _bill),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _bill = updated);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: kCoral),
            SizedBox(width: 8),
            Text('Delete Bill',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'This will permanently remove the scanned bill. This cannot be undone.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await BillsService.deleteBill(_bill);
      if (!mounted) return;
      _returnToList(BillDetailResult(deleted: true));
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to delete bill: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Back arrow / system back: propagate any edit that happened.
        _returnToList(
          _bill != widget.bill ? BillDetailResult(updatedBill: _bill) : null,
        );
      },
      child: Scaffold(
        backgroundColor: kSurface,
        appBar: AppBar(
          backgroundColor: kNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () => _returnToList(
              _bill != widget.bill ? BillDetailResult(updatedBill: _bill) : null,
            ),
          ),
          title: const Text('Bill Details',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          actions: [
            IconButton(
              tooltip: 'Share / Export',
              icon: (_isSharing || _isGeneratingPdf)
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.share_rounded),
              onPressed: (_isSharing || _isGeneratingPdf) ? null : _showShareSheet,
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_rounded),
              onPressed: _editBill,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_rounded, color: kCoral),
              onPressed: _confirmDelete,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              height: 320,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: _bill.imageBase64.isNotEmpty
                    ? Image.memory(
                  base64Decode(_bill.imageBase64),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  errorBuilder: (ctx, err, st) => Center(
                      child: Icon(Icons.broken_image_rounded,
                          color: Colors.grey.shade300)),
                )
                    : Center(
                    child: Icon(Icons.broken_image_rounded,
                        color: Colors.grey.shade300)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('Pinch to zoom',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ),
            const SizedBox(height: 20),
            _sectionLabel('BILL SUMMARY'),
            const SizedBox(height: 10),
            _detailCard([
              _detailRow('Vendor / Supplier', _bill.vendorName,
                  Icons.storefront_rounded),
              _detailRow('Bill Number', _bill.billNumber, Icons.tag_rounded),
              _detailRow('Amount', '₹${_bill.amount.toStringAsFixed(2)}',
                  Icons.currency_rupee_rounded, valueColor: kGreen),
              _detailRow('Category', _bill.category, Icons.category_rounded),
              _detailRow(
                  'Bill Date',
                  '${_bill.billDate.day}/${_bill.billDate.month}/${_bill.billDate.year}',
                  Icons.calendar_today_rounded),
              if (_bill.notes.isNotEmpty)
                _detailRow('Notes', _bill.notes, Icons.notes_rounded),
              _detailRow(
                  'Uploaded',
                  '${_bill.createdAt.day}/${_bill.createdAt.month}/${_bill.createdAt.year}',
                  Icons.upload_rounded),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _detailCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _detailRow(String label, String value, IconData icon,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: valueColor ?? kNavy,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}