// lib/screens/sales/add_sale_return_screen.dart
//
// "Add Sale Return / Credit Note" — styled to match the Vyapar-style
// Add Purchase Return theme: navy AppBar, light workspace tab strip,
// white bordered cards, kBlue accents, same field decoration / spacing
// / typography. Full Firebase/Firestore business logic (SaleReturn
// model, SaleReturnService, validation, branch list, success dialog).

import 'package:flutter/material.dart';
import 'package:cda_inventory/models/sale_return.dart';
import 'package:cda_inventory/services/sale_return_service.dart';
import 'package:cda_inventory/shared/inventory_ui.dart';

class AddSaleReturnScreen extends StatefulWidget {
  const AddSaleReturnScreen({super.key});

  @override
  State<AddSaleReturnScreen> createState() => _AddSaleReturnScreenState();
}

class _AddSaleReturnScreenState extends State<AddSaleReturnScreen> {
  final _formKey = GlobalKey<FormState>();
  final productController = TextEditingController();
  final customerController = TextEditingController();
  final quantityController = TextEditingController();
  final amountController = TextEditingController();
  final referenceInvoiceController = TextEditingController();
  final dateController = TextEditingController();

  String selectedBranch = kBranches.first;
  String selectedReason = 'Damaged Goods';
  bool _isLoading = false;

  static const reasons = [
    'Damaged Goods',
    'Wrong Item Delivered',
    'Excess Quantity',
    'Quality Issue',
    'Customer Not Satisfied',
    'Size/ Fit Issue',
    'Other',
  ];

  // ── Purchase-Return-style light theme tokens ───────────────────────────
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
  void dispose() {
    productController.dispose();
    customerController.dispose();
    quantityController.dispose();
    amountController.dispose();
    referenceInvoiceController.dispose();
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

  void _clearForm() {
    productController.clear();
    customerController.clear();
    quantityController.clear();
    amountController.clear();
    referenceInvoiceController.clear();
    dateController.clear();
    setState(() {
      selectedBranch = kBranches.first;
      selectedReason = 'Damaged Goods';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (dateController.text.isEmpty) {
      showAppSnack(context, 'Please select a return date', isError: true);
      return;
    }
    setState(() => _isLoading = true);

    final ret = SaleReturn(
      productName: productController.text.trim(),
      customerName: customerController.text.trim(),
      quantity: int.parse(quantityController.text.trim()),
      amount: double.parse(amountController.text.trim()),
      reason: selectedReason,
      referenceInvoice: referenceInvoiceController.text.trim(),
      branch: selectedBranch,
      returnDate: dateController.text.trim(),
    );

    final result = await SaleReturnService.addSaleReturn(ret);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      showSuccessDialog(
        context,
        title: 'Return Recorded!',
        message: 'The sale return / credit note has been recorded successfully.',
        onAddMore: _clearForm,
        onViewList: () => Navigator.pop(context, true),
      );
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

  Color get _reasonColor => switch (selectedReason) {
    'Damaged Goods' => kRed,
    'Customer Not Satisfied' => kRed,
    'Quality Issue' => const Color(0xFFE8A33D),
    _ => kBlue,
  };

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
        title: const Text('Sale Return / Credit Note',
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
                        const Text('Sale Return / Credit Note',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextDark)),
                        const SizedBox(height: 18),
                        _buildProductAndMetaRow(),
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
            const Text('Credit Note #1',
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

  // ── Product / Customer  +  Reference / Reason / Branch / Return Date ──
  Widget _buildProductAndMetaRow() {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 760;
      final productBlock = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _label('Product Name'),
        TextFormField(
          controller: productController,
          style: const TextStyle(color: kTextDark, fontSize: 13),
          textCapitalization: TextCapitalization.words,
          decoration: _fieldDecoration(hint: 'e.g. Drone Battery, Propeller Set'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Product name is required' : null,
        ),
        const SizedBox(height: 14),
        _label('Customer Name'),
        TextFormField(
          controller: customerController,
          style: const TextStyle(color: kTextDark, fontSize: 13),
          textCapitalization: TextCapitalization.words,
          decoration: _fieldDecoration(hint: 'e.g. John Doe Enterprises').copyWith(
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, color: kTextMute, size: 20),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Customer name is required' : null,
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _label('Quantity'),
              TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: kTextDark, fontSize: 13),
                decoration: _fieldDecoration(hint: '0'),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (int.tryParse(v.trim()) == null) return 'Numbers only';
                  if (int.parse(v.trim()) <= 0) return 'Must be > 0';
                  return null;
                },
              ),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _label('Amount (₹)'),
              TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: kTextDark, fontSize: 13),
                decoration: _fieldDecoration(hint: '0.00').copyWith(
                  prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 16, color: kTextMute),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) return 'Numbers only';
                  if (double.parse(v.trim()) <= 0) return 'Must be > 0';
                  return null;
                },
              ),
            ]),
          ),
        ]),
      ]);

      final metaBlock = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _metaRow('Return Date', SizedBox(
          width: 200,
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
        _metaRow('Reason for Return', SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
            initialValue: selectedReason,
            isExpanded: true,
            dropdownColor: Colors.white,
            style: const TextStyle(fontSize: 12.5, color: kTextDark),
            decoration: _fieldDecoration(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
            items: reasons
                .map((r) => DropdownMenuItem(
              value: r,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: _reasonColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Flexible(child: Text(r, style: const TextStyle(fontSize: 12.5, color: kTextDark), overflow: TextOverflow.ellipsis)),
              ]),
            ))
                .toList(),
            onChanged: (v) => setState(() => selectedReason = v ?? selectedReason),
          ),
        )),
        const SizedBox(height: 8),
        _metaRow('Reference Invoice', SizedBox(
          width: 200,
          child: TextFormField(
            controller: referenceInvoiceController,
            textAlign: TextAlign.right,
            style: const TextStyle(color: kTextDark, fontSize: 13),
            decoration: _fieldDecoration(hint: 'e.g. INV-2025-001', padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
          ),
        )),
        const SizedBox(height: 8),
        _metaRow('Branch', SizedBox(
          width: 200,
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
        productBlock,
        const SizedBox(height: 18),
        metaBlock,
      ])
          : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: productBlock),
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
      field,
    ]);
  }

  // ── Reason badge / Total summary ──────────────────────────────────────
  Widget _buildBottomSection() {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 760;
      final children = [
        Expanded(flex: 4, child: _reasonCard()),
        const SizedBox(width: 18, height: 18),
        Expanded(flex: 3, child: _summaryCard()),
      ];
      return isNarrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
          : IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: children));
    });
  }

  Widget _reasonCard() {
    return _cardWrap(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Return Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _reasonColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _reasonColor.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: _reasonColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(selectedReason, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _reasonColor)),
          ]),
        ),
        const SizedBox(height: 12),
        const Text('Change the reason from the "Reason for Return" dropdown above.',
            style: TextStyle(fontSize: 11.5, color: kTextMute)),
      ]),
    );
  }

  Widget _summaryCard() {
    final qty = int.tryParse(quantityController.text.trim()) ?? 0;
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Text('Quantity', style: TextStyle(fontSize: 12.5, color: kTextSub, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('$qty', style: const TextStyle(fontSize: 13, color: kTextDark, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const Text('Credit Note Amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTextDark)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: kHeaderBg,
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('₹${amount.toStringAsFixed(2)}',
              textAlign: TextAlign.right, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kTextDark)),
        ),
      ]),
    ]);
  }

  // ── Footer bar: Save Return ───────────────────────────────────────────
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
            : const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.save_rounded, size: 16, color: Colors.white),
            SizedBox(width: 8),
            Text('Save Return', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ]);
  }
}