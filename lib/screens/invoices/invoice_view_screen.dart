// lib/screens/invoices/invoice_view_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cda_inventory/models/invoice.dart';
import 'package:cda_inventory/services/invoice_service.dart';
import 'package:cda_inventory/services/invoice_pdf_service.dart';
import 'add_invoice_screen.dart';

class InvoiceViewScreen extends StatefulWidget {
  final Invoice invoice;

  const InvoiceViewScreen({super.key, required this.invoice});

  @override
  State<InvoiceViewScreen> createState() => _InvoiceViewScreenState();
}

class _InvoiceViewScreenState extends State<InvoiceViewScreen> {
  late Invoice _invoice;
  final InvoiceService _invoiceService = InvoiceService();
  bool _isLoading = false;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
  }

  Future<void> _refreshInvoice() async {
    if (_invoice.id == null) return;
    setState(() => _isLoading = true);
    try {
      final updated = await _invoiceService.fetchInvoiceById(_invoice.id!);
      setState(() => _invoice = updated);
    } catch (_) {
      // keep existing data if refresh fails
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editInvoice() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(settings: const RouteSettings(name: 'Add Invoice'), builder: (_) => AddInvoiceScreen(invoiceToEdit: _invoice)),
    );
    if (result == true) {
      await _refreshInvoice();
      if (mounted) Navigator.pop(context, true);
    }
  }

  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Delete Invoice'),
        content: Text(
          'Are you sure you want to delete invoice ${_invoice.invoiceNo}? This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteInvoice();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteInvoice() async {
    if (_invoice.id == null) return;
    try {
      await _invoiceService.deleteInvoice(_invoice.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice deleted successfully'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard'), duration: const Duration(seconds: 1)),
    );
  }

  // ── Generate the branded PDF once, reused for both download & share ────
  Future<Uint8List?> _generatePdfBytes() async {
    setState(() => _isGeneratingPdf = true);
    try {
      return await InvoicePdfService.generate(_invoice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _downloadPdf() async {
    final bytes = await _generatePdfBytes();
    if (bytes == null) return;
    // Printing.sharePdf triggers the browser's save/print dialog on web,
    // and on this environment (Windows Chrome) that includes a native
    // Save/Share prompt — same mechanism already working on the list screen.
    await Printing.sharePdf(bytes: bytes, filename: 'invoice_${_invoice.invoiceNo}.pdf');
  }

  Future<void> _sharePdf() async {
    final bytes = await _generatePdfBytes();
    if (bytes == null) return;
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: 'invoice_${_invoice.invoiceNo}.pdf', mimeType: 'application/pdf')],
      subject: 'Invoice ${_invoice.invoiceNo}',
      text: 'Invoice ${_invoice.invoiceNo} from Chennai Drone Academy',
    );
  }

  void _showShareSheet() {
    final content = '''
INVOICE DETAILS
───────────────────────
Invoice No  : ${_invoice.invoiceNo}
Product     : ${_invoice.displayProductName}
Vendor      : ${_invoice.vendorName}
Quantity    : ${_invoice.displayQuantity}
Amount      : ₹${_invoice.displayAmount.toStringAsFixed(2)}
Date        : ${_invoice.purchaseDate}
───────────────────────
    '''.trim();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share / Export',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue.shade900)),
            const Divider(height: 20),
            ListTile(
              leading: Icon(Icons.copy, color: Colors.blue.shade900),
              title: const Text('Copy Invoice Details'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invoice details copied to clipboard'), backgroundColor: Colors.green),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Colors.red.shade700),
              title: const Text('Download PDF'),
              subtitle: const Text('Branded invoice with GST breakdown'),
              onTap: () {
                Navigator.pop(context);
                _downloadPdf();
              },
            ),
            ListTile(
              leading: Icon(Icons.share, color: Colors.green.shade700),
              title: const Text('Share via...'),
              subtitle: const Text('Send the invoice PDF to an app or contact'),
              onTap: () {
                Navigator.pop(context);
                _sharePdf();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        title: const Text('Invoice Details'),
        actions: [
          if (_isGeneratingPdf)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else ...[
            IconButton(icon: const Icon(Icons.share), tooltip: 'Share / Export', onPressed: _showShareSheet),
            IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit Invoice', onPressed: _editInvoice),
            IconButton(icon: const Icon(Icons.delete), tooltip: 'Delete Invoice', onPressed: _showDeleteConfirmDialog),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Theme(
        // This screen's Cards/Text below rely on explicit light colors
        // (white cards, black87 text). Without this override they inherit
        // the app's default dark theme's Card background, which makes the
        // dark text nearly invisible against a dark card.
        data: Theme.of(context).copyWith(
          brightness: Brightness.light,
          cardColor: Colors.white,
          colorScheme: Theme.of(context).colorScheme.copyWith(
            brightness: Brightness.light,
            surface: Colors.white,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                elevation: 4,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Icon(Icons.receipt_long, size: 80, color: Colors.blue.shade900)),
                      const SizedBox(height: 12),
                      Center(
                        child: Text('INVOICE',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                                letterSpacing: 2)),
                      ),
                      const Divider(height: 30),
                      _buildDetailRow('Invoice Number', _invoice.invoiceNo, Icons.tag, copyable: true),
                      _buildDetailRow('Product Name', _invoice.displayProductName, Icons.inventory_2),
                      _buildDetailRow('Vendor Name', _invoice.vendorName, Icons.store),
                      _buildDetailRow('Quantity', _invoice.displayQuantity.toString(), Icons.numbers),
                      _buildDetailRow('Amount', '₹${_invoice.displayAmount.toStringAsFixed(2)}',
                          Icons.currency_rupee, valueColor: Colors.green.shade700),
                      _buildDetailRow('Purchase Date', _invoice.purchaseDate, Icons.calendar_today),
                      if (_invoice.amountPaid > 0)
                        _buildDetailRow('Balance Due', '₹${_invoice.balanceDue.toStringAsFixed(2)}',
                            Icons.account_balance_wallet, valueColor: Colors.red.shade600),
                      const Divider(height: 30),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Amount',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900)),
                            Text(
                              '₹${_invoice.grandTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 3,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Actions',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _actionButton(
                                icon: Icons.edit, label: 'Edit', color: Colors.orange.shade700, onTap: _editInvoice),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _actionButton(
                                icon: Icons.delete,
                                label: 'Delete',
                                color: Colors.red,
                                onTap: _showDeleteConfirmDialog),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _actionButton(
                              icon: Icons.copy,
                              label: 'Copy Details',
                              color: Colors.blue.shade700,
                              onTap: () => _copyToClipboard('Invoice No', _invoice.invoiceNo),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _actionButton(
                              icon: Icons.download,
                              label: 'Download PDF',
                              color: Colors.green,
                              onTap: _downloadPdf,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value, IconData icon, {Color? valueColor, bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blue.shade900),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: valueColor ?? Colors.black87))),
                if (copyable)
                  GestureDetector(
                    onTap: () => _copyToClipboard(title, value),
                    child: Icon(Icons.copy, size: 16, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}