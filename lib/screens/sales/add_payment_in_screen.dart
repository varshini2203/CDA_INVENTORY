// lib/screens/sales/add_payment_in_screen.dart
//
// "Add Payment-In" — same visual language as AddPaymentOutScreen /
// AddPurchaseOrderScreen (navy AppBar, light workspace tab strip, white
// bordered cards, kBlue accents) but modelled on Vyapar's real Payment-In
// screen: customer search, outstanding-invoice settlement (multi-select,
// per-invoice editable amount, live balance sync via InvoiceService),
// payment mode with contextual reference label, notes, attachments and
// advance-amount tracking. No paywall — every feature is live.

import 'package:flutter/material.dart';
import 'package:cda_inventory/models/payment_in.dart';
import 'package:cda_inventory/models/invoice.dart';
import 'package:cda_inventory/services/payment_in_service.dart';
import 'package:cda_inventory/services/invoice_service.dart';
import 'package:cda_inventory/shared/inventory_ui.dart';

class AddPaymentInScreen extends StatefulWidget {
  final String? initialCustomerName;
  const AddPaymentInScreen({super.key, this.initialCustomerName});

  @override
  State<AddPaymentInScreen> createState() => _AddPaymentInScreenState();
}
class _AddPaymentInScreenState extends State<AddPaymentInScreen> {
  final _formKey = GlobalKey<FormState>();
  final customerController = TextEditingController();
  final phoneController = TextEditingController();
  final amountController = TextEditingController();
  final referenceController = TextEditingController();
  final notesController = TextEditingController();
  final dateController = TextEditingController();

  String selectedBranch = kBranches.first;
  String selectedMode = 'Cash';
  bool _isLoading = false;
  bool _isLoadingInvoices = true;
  String? _attachmentName;

  static const modes = ['Cash', 'Bank Transfer', 'UPI', 'Cheque', 'Card'];

  final InvoiceService _invoiceService = InvoiceService();
  List<Invoice> _allInvoices = [];
  List<String> _customerSuggestions = [];
  List<Invoice> _outstandingInvoices = [];
  final Set<String> _selectedInvoiceIds = {};
  final Map<String, TextEditingController> _allocationControllers = {};

  // ── Purchase-Order-style light theme tokens (same as Payment-Out) ─────
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
    _loadInvoices().then((_) {
      final prefill = widget.initialCustomerName?.trim();
      if (prefill != null && prefill.isNotEmpty && mounted) {
        customerController.text = prefill;
        _onCustomerChanged(prefill);
      }
    });
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoadingInvoices = true);
    try {
      final invoices = await _invoiceService.fetchInvoices();
      final names = <String>{};
      for (final inv in invoices) {
        final n = inv.customer?.name.trim() ?? '';
        if (n.isNotEmpty) names.add(n);
      }
      if (!mounted) return;
      setState(() {
        _allInvoices = invoices;
        _customerSuggestions = names.toList()..sort();
        _isLoadingInvoices = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingInvoices = false);
    }
  }

  @override
  void dispose() {
    customerController.dispose();
    phoneController.dispose();
    amountController.dispose();
    referenceController.dispose();
    notesController.dispose();
    dateController.dispose();
    for (final c in _allocationControllers.values) {
      c.dispose();
    }
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
      setState(() => dateController.text = _fmtDate(picked));
    }
  }

  void _clearForm() {
    customerController.clear();
    phoneController.clear();
    amountController.clear();
    referenceController.clear();
    notesController.clear();
    dateController.clear();
    for (final c in _allocationControllers.values) {
      c.dispose();
    }
    _allocationControllers.clear();
    setState(() {
      selectedBranch = kBranches.first;
      selectedMode = 'Cash';
      _attachmentName = null;
      _outstandingInvoices = [];
      _selectedInvoiceIds.clear();
    });
  }

  // ── Customer typing → filter outstanding invoices for that customer ────
  void _onCustomerChanged(String value) {
    final q = value.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _outstandingInvoices = [];
        _selectedInvoiceIds.clear();
      });
      return;
    }
    final matches = _allInvoices.where((inv) {
      final name = inv.customer?.name.trim().toLowerCase() ?? '';
      return name.isNotEmpty && name.contains(q) && inv.balanceDue > 0.01;
    }).toList();
    setState(() {
      _outstandingInvoices = matches;
      // Drop selections for invoices no longer in the filtered list.
      _selectedInvoiceIds.removeWhere(
              (id) => !matches.any((inv) => inv.id == id));
    });
  }

  void _selectSuggestion(String name) {
    customerController.text = name;
    final match = _allInvoices.firstWhere(
          (inv) => (inv.customer?.name.trim().toLowerCase() ?? '') == name.toLowerCase(),
      orElse: () => _allInvoices.first,
    );
    if (phoneController.text.trim().isEmpty) {
      phoneController.text = match.customer?.phone ?? '';
    }
    _onCustomerChanged(name);
    FocusScope.of(context).unfocus();
  }

  TextEditingController _allocationController(Invoice inv) {
    final id = inv.id ?? '';
    return _allocationControllers.putIfAbsent(
      id,
          () => TextEditingController(text: inv.balanceDue.toStringAsFixed(2)),
    );
  }

  void _toggleInvoice(Invoice inv, bool? checked) {
    final id = inv.id;
    if (id == null) return;
    setState(() {
      if (checked == true) {
        _selectedInvoiceIds.add(id);
        _allocationController(inv); // ensure controller exists / resets default
        _allocationControllers[id]!.text = inv.balanceDue.toStringAsFixed(2);
      } else {
        _selectedInvoiceIds.remove(id);
      }
    });
  }

  void _selectAll(bool selectAll) {
    setState(() {
      _selectedInvoiceIds.clear();
      if (selectAll) {
        for (final inv in _outstandingInvoices) {
          if (inv.id == null) continue;
          _selectedInvoiceIds.add(inv.id!);
          _allocationController(inv).text = inv.balanceDue.toStringAsFixed(2);
        }
      }
    });
  }

  double get _allocatedTotal {
    double sum = 0;
    for (final inv in _outstandingInvoices) {
      final id = inv.id;
      if (id == null || !_selectedInvoiceIds.contains(id)) continue;
      sum += double.tryParse(_allocationControllers[id]?.text.trim() ?? '') ?? 0;
    }
    return sum;
  }

  double get _enteredAmount => double.tryParse(amountController.text.trim()) ?? 0;

  double get _advanceAmount => (_enteredAmount - _allocatedTotal).clamp(0, double.infinity);

  void _useOutstandingTotal() {
    setState(() {
      amountController.text = _allocatedTotal.toStringAsFixed(2);
    });
  }

  String _refLabel() {
    switch (selectedMode) {
      case 'Cheque':
        return 'Cheque No.';
      case 'UPI':
        return 'UPI Txn ID';
      case 'Bank Transfer':
        return 'Transaction ID';
      case 'Card':
        return 'Card / Auth Ref';
      default:
        return 'Reference No. (optional)';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (dateController.text.isEmpty) {
      showAppSnack(context, 'Please select a payment date', isError: true);
      return;
    }
    if (customerController.text.trim().isEmpty) {
      showAppSnack(context, 'Please enter the customer name', isError: true);
      return;
    }

    final allocations = <PaymentInInvoiceAllocation>[];
    for (final inv in _outstandingInvoices) {
      final id = inv.id;
      if (id == null || !_selectedInvoiceIds.contains(id)) continue;
      final applied = double.tryParse(_allocationControllers[id]?.text.trim() ?? '') ?? 0;
      if (applied <= 0) continue;
      if (applied > inv.balanceDue + 0.01) {
        showAppSnack(
          context,
          'Amount for ${inv.invoiceNo} exceeds its balance due (₹${inv.balanceDue.toStringAsFixed(2)})',
          isError: true,
        );
        return;
      }
      allocations.add(PaymentInInvoiceAllocation(
        invoiceId: id,
        invoiceNo: inv.invoiceNo,
        amountApplied: applied,
      ));
    }

    final allocatedSum = allocations.fold(0.0, (s, a) => s + a.amountApplied);
    final totalAmount = double.parse(amountController.text.trim());
    if (allocatedSum > totalAmount + 0.01) {
      showAppSnack(
        context,
        'Amount applied to invoices (₹${allocatedSum.toStringAsFixed(2)}) exceeds amount received (₹${totalAmount.toStringAsFixed(2)})',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    final payment = PaymentIn(
      customerName: customerController.text.trim(),
      phone: phoneController.text.trim(),
      amount: totalAmount,
      paymentMode: selectedMode,
      referenceNumber: referenceController.text.trim(),
      branch: selectedBranch,
      paymentDate: dateController.text.trim(),
      notes: notesController.text.trim(),
      invoiceAllocations: allocations,
      advanceAmount: (totalAmount - allocatedSum).clamp(0, double.infinity),
    );

    final result = await PaymentInService.addPaymentIn(payment);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      showSuccessDialog(
        context,
        title: 'Payment Received!',
        message: allocations.isEmpty
            ? 'The payment-in has been recorded successfully.'
            : 'The payment-in has been recorded and applied to ${allocations.length} invoice${allocations.length == 1 ? '' : 's'}.',
        onAddMore: () {
          _clearForm();
          _loadInvoices();
        },
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
        title: const Text('Payment-In',
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
                        const Text('Payment In',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextDark)),
                        const SizedBox(height: 18),
                        _buildCustomerAndMetaRow(),
                        const SizedBox(height: 22),
                        _buildOutstandingInvoicesCard(),
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
            const Text('Payment In #1',
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

  // ── Customer search / phone  +  Payment Date / Mode / Reference / Branch ──
  Widget _buildCustomerAndMetaRow() {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 760;

      final matchingSuggestions = customerController.text.trim().isEmpty
          ? const <String>[]
          : _customerSuggestions
          .where((n) => n.toLowerCase().contains(customerController.text.trim().toLowerCase()))
          .take(6)
          .toList();

      final customerBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: customerController,
              style: const TextStyle(color: kTextDark, fontSize: 13),
              textCapitalization: TextCapitalization.words,
              onChanged: _onCustomerChanged,
              decoration: _fieldDecoration(hint: 'Search Customer by Name/Phone *').copyWith(
                suffixIcon: _isLoadingInvoices
                    ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                )
                    : const Icon(Icons.person_search_rounded, color: kTextMute, size: 20),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Customer name is required' : null,
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
        ]),
        if (matchingSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: matchingSuggestions
                .map((name) => InkWell(
              onTap: () => _selectSuggestion(name),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kHeaderBg,
                  border: Border.all(color: kBorder),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.person_rounded, size: 12, color: kBlue),
                  const SizedBox(width: 4),
                  Text(name, style: const TextStyle(fontSize: 11.5, color: kTextDark)),
                ]),
              ),
            ))
                .toList(),
          ),
        ],
      ]);

      final metaBlock = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _metaRow('Payment Date', SizedBox(
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
        _metaRow('Payment Mode', SizedBox(
          width: 200,
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
        _metaRow(_refLabel(), SizedBox(
          width: 200,
          child: TextFormField(
            controller: referenceController,
            textAlign: TextAlign.right,
            style: const TextStyle(color: kTextDark, fontSize: 13),
            decoration: _fieldDecoration(hint: 'e.g. TXN12345', padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
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
        customerBlock,
        const SizedBox(height: 18),
        metaBlock,
      ])
          : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: customerBlock),
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

  // ── Outstanding Invoices — multi-select settlement ─────────────────────
  Widget _buildOutstandingInvoicesCard() {
    final allSelected = _outstandingInvoices.isNotEmpty &&
        _outstandingInvoices.every((inv) => _selectedInvoiceIds.contains(inv.id));

    return _cardWrap(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Settle Against Invoices',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
          const SizedBox(width: 8),
          if (_outstandingInvoices.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: kHeaderBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
              child: Text('${_outstandingInvoices.length} outstanding',
                  style: const TextStyle(fontSize: 11, color: kTextSub, fontWeight: FontWeight.w600)),
            ),
          const Spacer(),
          if (_outstandingInvoices.isNotEmpty)
            TextButton(
              onPressed: () => _selectAll(!allSelected),
              style: TextButton.styleFrom(foregroundColor: kBlue, padding: EdgeInsets.zero),
              child: Text(allSelected ? 'Clear All' : 'Select All',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 10),
        if (customerController.text.trim().isEmpty)
          _emptyInvoiceState('Enter a customer name to view their outstanding invoices')
        else if (_isLoadingInvoices)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (_outstandingInvoices.isEmpty)
            _emptyInvoiceState('No outstanding invoices for this customer — this receipt will be recorded as an advance')
          else
            Column(children: [
              for (final inv in _outstandingInvoices) _invoiceRow(inv),
              const Divider(height: 20, color: kBorder),
              Row(children: [
                const Spacer(),
                const Text('Total to settle: ', style: TextStyle(fontSize: 12.5, color: kTextSub, fontWeight: FontWeight.w600)),
                Text('₹${_allocatedTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14, color: kTextDark, fontWeight: FontWeight.w800)),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _allocatedTotal <= 0 ? null : _useOutstandingTotal,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kBlue,
                    side: const BorderSide(color: kBlue),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Use as Amount Received', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
      ]),
    );
  }

  Widget _emptyInvoiceState(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
    decoration: BoxDecoration(color: kHeaderBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: kBorder)),
    child: Row(children: [
      const Icon(Icons.info_outline_rounded, size: 16, color: kTextMute),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: const TextStyle(fontSize: 12.5, color: kTextSub))),
    ]),
  );

  Widget _invoiceRow(Invoice inv) {
    final id = inv.id ?? '';
    final selected = _selectedInvoiceIds.contains(id);
    final ctrl = _allocationController(inv);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEFF4FE) : kHeaderBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: selected ? kBlue.withOpacity(0.4) : kBorder),
      ),
      child: Row(children: [
        Checkbox(
          value: selected,
          activeColor: kBlue,
          onChanged: (v) => _toggleInvoice(inv, v),
        ),
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(inv.invoiceNo, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextDark)),
            const SizedBox(height: 2),
            Text(inv.purchaseDate, style: const TextStyle(fontSize: 11, color: kTextMute)),
          ]),
        ),
        Expanded(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Balance Due', style: TextStyle(fontSize: 10.5, color: kTextMute)),
            Text('₹${inv.balanceDue.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kRed)),
          ]),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: TextFormField(
            controller: ctrl,
            enabled: selected,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 12.5, color: kTextDark, fontWeight: FontWeight.w600),
            onChanged: (_) => setState(() {}),
            decoration: _fieldDecoration(
              hint: '0.00',
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ),
      ]),
    );
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
          onPressed: () => setState(() => _attachmentName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg'),
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
                onTap: () => setState(() => _attachmentName = null),
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
      _label('Amount Received (₹)'),
      TextFormField(
        controller: amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: kTextDark, fontSize: 14, fontWeight: FontWeight.w700),
        onChanged: (_) => setState(() {}),
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
      const SizedBox(height: 14),
      _summaryLine('Applied to Invoices', '₹${_allocatedTotal.toStringAsFixed(2)}', kTextDark),
      const SizedBox(height: 6),
      _summaryLine('Advance / Unused', '₹${_advanceAmount.toStringAsFixed(2)}',
          _advanceAmount > 0 ? kGreen : kTextMute),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const Text('Total Received', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kTextDark)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: kHeaderBg,
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '₹${_enteredAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kGreen),
          ),
        ),
      ]),
    ]);
  }

  Widget _summaryLine(String label, String value, Color valueColor) => Row(children: [
    Text(label, style: const TextStyle(fontSize: 12, color: kTextSub, fontWeight: FontWeight.w500)),
    const Spacer(),
    Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: valueColor)),
  ]);

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
            : const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.save_rounded, size: 16, color: Colors.white),
            SizedBox(width: 8),
            Text('Save Payment-In', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ]);
  }
}