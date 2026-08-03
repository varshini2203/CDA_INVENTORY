// lib/screens/purchases/add_payment_out_screen.dart
//
// "Add Payment Out" — restyled to match the Add Purchase Order theme:
// navy AppBar, light workspace tab strip, white bordered cards, kBlue
// accents, same field decoration / spacing / typography. All existing
// Firebase/Firestore business logic (PaymentOut model, PaymentOutService,
// validation, branch list, success dialog) is preserved unchanged.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:cda_inventory/models/payment_out.dart';
import 'package:cda_inventory/services/payment_out_service.dart';
import 'package:cda_inventory/shared/inventory_ui.dart';

class AddPaymentOutScreen extends StatefulWidget {
  final PaymentOut? paymentToEdit;
  const AddPaymentOutScreen({super.key, this.paymentToEdit});

  @override
  State<AddPaymentOutScreen> createState() => _AddPaymentOutScreenState();
}

class _AddPaymentOutScreenState extends State<AddPaymentOutScreen> {
  final _formKey = GlobalKey<FormState>();
  final vendorController = TextEditingController();
  final phoneController = TextEditingController();
  final amountController = TextEditingController();
  final referenceController = TextEditingController();
  final notesController = TextEditingController();
  final dateController = TextEditingController();

  String selectedBranch = kBranches.first;
  String selectedMode = 'Cash';
  bool _isLoading = false;
  String? _attachmentName;
  Uint8List? _attachmentBytes;
  String? _existingAttachmentBase64;

  bool get _isEditMode => widget.paymentToEdit != null;

  static const modes = ['Cash', 'Bank Transfer', 'UPI', 'Cheque'];

  // ── Purchase-Order-style light theme tokens ───────────────────────────
  static const Color kBg        = Color(0xFFF4F6F9);
  static const Color kTabBar    = Color(0xFFECEEF1);
  static const Color kNavy      = Color(0xFF0A1628);
  static const Color kRed       = Color(0xFFE94D5F);
  static const Color kBlue      = Color(0xFF2F6FE4);
  static const Color kGreen     = Color(0xFF00B894);
  static const Color kBorder    = Color(0xFFE3E7EE);
  static const Color kHeaderBg  = Color(0xFFF7F9FC);
  static const Color kTextDark  = Color(0xFF1F2937);
  static const Color kTextSub   = Color(0xFF6B7280);
  static const Color kTextMute  = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    final p = widget.paymentToEdit;
    if (p != null) {
      vendorController.text = p.vendorName;
      amountController.text = p.amount % 1 == 0 ? p.amount.toStringAsFixed(0) : p.amount.toString();
      referenceController.text = p.referenceNumber;
      notesController.text = p.notes;
      dateController.text = p.paymentDate;
      selectedBranch = kBranches.contains(p.branch) ? p.branch : kBranches.first;
      selectedMode = modes.contains(p.paymentMode) ? p.paymentMode : 'Cash';
      _attachmentName = p.attachmentName;
      _existingAttachmentBase64 = p.attachmentBase64;
    }
  }

  @override
  void dispose() {
    vendorController.dispose();
    phoneController.dispose();
    amountController.dispose();
    referenceController.dispose();
    notesController.dispose();
    dateController.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme:
            const ColorScheme.light(primary: AppColors.navy, onPrimary: Colors.white)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        dateController.text = _fmtDate(picked);
      });
    }
  }

  // ── Add Attachment — lets the user actually pick a photo/scan instead
  // of fabricating a placeholder filename. ─────────────────────────────
  Future<void> _pickAttachment() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: kBlue),
              title: const Text('Scan with Camera',
                  style: TextStyle(color: kTextDark, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: kBlue),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: kTextDark, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    final compressed = _compressAttachment(bytes);
    setState(() {
      _attachmentBytes = compressed;
      _existingAttachmentBase64 = null; // replaced by the new capture
      _attachmentName = picked.name.isNotEmpty
          ? picked.name
          : 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
    });
  }

  // Same 500KB budget / downscale strategy as the Add Purchase bill photo,
  // so a Base64-encoded receipt never blows past Firestore's 1MB doc cap.
  static const int _maxRawAttachmentBytes = 500000;
  static const int _maxAttachmentDimension = 1600;

  static Uint8List _compressAttachment(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    img.Image working = decoded;
    if (working.width > _maxAttachmentDimension || working.height > _maxAttachmentDimension) {
      working = img.copyResize(
        working,
        width: working.width >= working.height ? _maxAttachmentDimension : null,
        height: working.height > working.width ? _maxAttachmentDimension : null,
      );
    }

    var quality = 85;
    Uint8List out = Uint8List.fromList(img.encodeJpg(working, quality: quality));

    while (out.length > _maxRawAttachmentBytes && quality > 30) {
      quality -= 10;
      out = Uint8List.fromList(img.encodeJpg(working, quality: quality));
    }
    while (out.length > _maxRawAttachmentBytes && working.width > 400 && working.height > 400) {
      working = img.copyResize(working, width: (working.width * 0.8).round());
      out = Uint8List.fromList(img.encodeJpg(working, quality: quality));
    }

    return out;
  }

  void _removeAttachment() {
    setState(() {
      _attachmentBytes = null;
      _existingAttachmentBase64 = null;
      _attachmentName = null;
    });
  }

  void _clearForm() {
    vendorController.clear();
    phoneController.clear();
    amountController.clear();
    referenceController.clear();
    notesController.clear();
    dateController.clear();
    setState(() {
      selectedBranch = kBranches.first;
      selectedMode = 'Cash';
      _attachmentName = null;
      _attachmentBytes = null;
      _existingAttachmentBase64 = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (dateController.text.isEmpty) {
      showAppSnack(context, 'Please select a payment date', isError: true);
      return;
    }
    setState(() => _isLoading = true);

    final payment = PaymentOut(
      vendorName: vendorController.text.trim(),
      amount: double.parse(amountController.text.trim()),
      paymentMode: selectedMode,
      referenceNumber: referenceController.text.trim(),
      branch: selectedBranch,
      paymentDate: dateController.text.trim(),
      notes: notesController.text.trim(),
      attachmentName: _attachmentName,
      attachmentBase64: _attachmentBytes != null
          ? base64Encode(_attachmentBytes!)
          : _existingAttachmentBase64,
    );

    final result = _isEditMode
        ? await PaymentOutService.updatePaymentOut(widget.paymentToEdit!.id!, payment)
        : await PaymentOutService.addPaymentOut(payment);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (_isEditMode) {
        showAppSnack(context, 'Payment updated successfully');
        Navigator.pop(context, true);
      } else {
        showSuccessDialog(
          context,
          title: 'Payment Recorded!',
          message: 'The payment-out has been recorded successfully.',
          onAddMore: _clearForm,
          onViewList: () => Navigator.pop(context, true),
        );
      }
    } else {
      showAppSnack(context, result['message'] ?? 'Something went wrong', isError: true);
    }
  }

  InputDecoration _fieldDecoration({String? hint, EdgeInsets? padding}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: kTextMute, fontSize: 13),
    isDense: true,
    contentPadding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kBlue)),
    filled: true,
    fillColor: Colors.white,
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 12.5, color: kTextSub, fontWeight: FontWeight.w600)),
  );

  Widget _cardWrap({required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: kBorder),
    ),
    child: child,
  );

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditMode ? 'Edit Payment' : 'Payment-Out',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Clear form',
              onPressed: _isLoading ? null : _clearForm),
        ],
      ),
      body: SafeArea(
        child: Theme(
          data: Theme.of(context).copyWith(
            brightness: Brightness.light,
            colorScheme: Theme.of(context).colorScheme.copyWith(
              brightness: Brightness.light,
              onSurface: kTextDark,
              surface: Colors.white,
            ),
            textTheme: Theme.of(context).textTheme.apply(
              bodyColor: kTextDark,
              displayColor: kTextDark,
            ),
            iconTheme: const IconThemeData(color: kTextSub),
            canvasColor: Colors.white,
            inputDecorationTheme: const InputDecorationTheme(
              hintStyle: TextStyle(color: kTextMute),
            ),
          ),
          child: Column(
            children: [
              _buildTabStrip(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Payment Out',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextDark)),
                        const SizedBox(height: 18),
                        _buildVendorAndMetaRow(),
                        const SizedBox(height: 22),
                        _buildBottomSection(),
                        const SizedBox(height: 22),
                        _buildFooterBar(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Workspace tab strip ────────────────────────────────────────────
  Widget _buildTabStrip() {
    return Container(
      height: 44,
      color: kTabBar,
      child: Row(children: [
        Container(
          margin: const EdgeInsets.only(left: 8, top: 6, bottom: 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('Payment Out #1',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextDark)),
            const SizedBox(width: 10),
            InkWell(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close_rounded, size: 15, color: kTextMute),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 6, top: 6),
          child: InkWell(
            onTap: () {},
            child: const Icon(Icons.add_circle, size: 20, color: kBlue),
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Save layout',
          icon: const Icon(Icons.dashboard_customize_outlined, size: 18, color: kTextSub),
          onPressed: () {},
        ),
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined, size: 18, color: kTextSub),
          onPressed: () {},
        ),
        IconButton(
          tooltip: 'Close',
          icon: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: kTextMute, shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 6),
      ]),
    );
  }

  // ── Vendor search / phone  +  Payment Date / Mode / Reference / Branch ──
  Widget _buildVendorAndMetaRow() {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 760;
      final vendorBlock = Row(children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: vendorController,
            style: const TextStyle(color: kTextDark, fontSize: 13),
            textCapitalization: TextCapitalization.words,
            decoration: _fieldDecoration(hint: 'Search Vendor by Name/Phone *').copyWith(
              suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, color: kTextMute, size: 20),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Vendor name is required' : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 1,
          child: TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: kTextDark, fontSize: 13),
            decoration: _fieldDecoration(hint: 'Phone No.'),
          ),
        ),
      ]);

      final metaBlock = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _metaRow('Payment Date', ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: _fieldDecoration(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(dateController.text.isEmpty ? 'Select date' : dateController.text,
                    style: TextStyle(fontSize: 13, color: dateController.text.isEmpty ? kTextMute : kTextDark)),
                const SizedBox(width: 6),
                const Icon(Icons.calendar_today_rounded, size: 15, color: kTextMute),
              ]),
            ),
          ),
        )),
        const SizedBox(height: 8),
        _metaRow('Payment Mode', ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: DropdownButtonFormField<String>(
            initialValue: selectedMode,
            isExpanded: true,
            dropdownColor: Colors.white,
            style: const TextStyle(fontSize: 12.5, color: kTextDark),
            decoration: _fieldDecoration(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
            items: modes
                .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12.5, color: kTextDark))))
                .toList(),
            onChanged: (v) => setState(() => selectedMode = v ?? selectedMode),
          ),
        )),
        const SizedBox(height: 8),
        _metaRow('Reference No.', ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: TextFormField(
            controller: referenceController,
            textAlign: TextAlign.right,
            style: const TextStyle(color: kTextDark, fontSize: 13),
            decoration: _fieldDecoration(hint: 'e.g. TXN12345', padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          ),
        )),
        const SizedBox(height: 8),
        _metaRow('Branch', ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: DropdownButtonFormField<String>(
            initialValue: selectedBranch,
            isExpanded: true,
            dropdownColor: Colors.white,
            style: const TextStyle(fontSize: 12.5, color: kTextDark),
            decoration: _fieldDecoration(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
            items: kBranches
                .map((b) => DropdownMenuItem(value: b, child: Text(kBranchLabels[b] ?? b, style: const TextStyle(fontSize: 12.5, color: kTextDark))))
                .toList(),
            onChanged: (v) => setState(() => selectedBranch = v ?? selectedBranch),
          ),
        )),
      ]);

      return isNarrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        vendorBlock,
        const SizedBox(height: 18),
        metaBlock,
      ])
          : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: vendorBlock),
          const SizedBox(width: 24),
          Expanded(flex: 3, child: metaBlock),
        ],
      );
    });
  }

  Widget _metaRow(String label, Widget field) {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Text(label, style: const TextStyle(fontSize: 12.5, color: kTextSub, fontWeight: FontWeight.w500)),
      const SizedBox(width: 14),
      Flexible(child: field),
    ]);
  }

  // ── Notes / Attachments / Amount card row ────────────────────────────
  Widget _buildBottomSection() {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 760;
      final children = [
        Expanded(flex: 4, child: _notesCard()),
        const SizedBox(width: 18, height: 18),
        Expanded(flex: 3, child: _attachmentsCard()),
        const SizedBox(width: 18, height: 18),
        Expanded(flex: 3, child: _amountCard()),
      ];
      return isNarrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
          : IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: children));
    });
  }

  Widget _notesCard() {
    return _cardWrap(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Notes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
        const SizedBox(height: 12),
        TextFormField(
          controller: notesController,
          maxLines: 4,
          style: const TextStyle(fontSize: 13, color: kTextDark),
          decoration: _fieldDecoration(hint: 'Any additional details about this payment'),
        ),
      ]),
    );
  }

  Widget _attachmentsCard() {
    return _cardWrap(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Attachments', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickAttachment,
          style: OutlinedButton.styleFrom(
            foregroundColor: kTextSub,
            side: const BorderSide(color: kBorder),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            minimumSize: const Size(double.infinity, 0),
          ),
          icon: const Icon(Icons.attach_file_rounded, size: 16),
          label: const Text('ADD ATTACHMENT', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
        ),
        if (_attachmentName != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: kHeaderBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kBorder),
            ),
            child: Row(children: [
              const Icon(Icons.insert_drive_file_outlined, size: 15, color: kTextSub),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_attachmentName!,
                    style: const TextStyle(fontSize: 12, color: kTextDark), overflow: TextOverflow.ellipsis),
              ),
              InkWell(
                onTap: _removeAttachment,
                child: const Icon(Icons.close_rounded, size: 15, color: kTextMute),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _amountCard() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label('Amount (₹)'),
      TextFormField(
        controller: amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: kTextDark, fontSize: 14, fontWeight: FontWeight.w700),
        decoration: _fieldDecoration(hint: '0.00').copyWith(
          prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 16, color: kTextMute),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Required';
          if (double.tryParse(v.trim()) == null) return 'Numbers only';
          if (double.parse(v.trim()) <= 0) return 'Must be > 0';
          return null;
        },
      ),
      const SizedBox(height: 18),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const Text('Total Payment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTextDark)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: kHeaderBg,
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '₹${(double.tryParse(amountController.text.trim()) ?? 0).toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kTextDark),
          ),
        ),
      ]),
    ]);
  }

  // ── Footer bar: Save Payment ──────────────────────────────────────────
  Widget _buildFooterBar() {
    return Row(children: [
      const Spacer(),
      ElevatedButton(
        onPressed: _isLoading ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: kBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: _isLoading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.save_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(_isEditMode ? 'Update Payment' : 'Save Payment',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ]);
  }
}