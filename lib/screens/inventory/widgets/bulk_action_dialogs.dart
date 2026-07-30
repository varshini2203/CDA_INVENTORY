// lib/screens/inventory/widgets/bulk_action_dialogs.dart
//
// Shared confirmation / progress / input dialogs used by
// BulkOperationsScreen. Kept in their own file (rather than inline in the
// screen) purely for readability — none of these hold any Firestore or
// business logic of their own, they only collect input and hand it back
// to the screen, which calls InventoryBulkOperationsService itself.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cda_inventory/services/inventory_bulk_operations_service.dart';

const Color kBulkNavy = Color(0xFF0A1628);
const Color kBulkTeal = Color(0xFF00D4AA);
const Color kBulkCoral = Color(0xFFFF6B6B);
const Color kBulkAmber = Color(0xFFFFB800);
const Color kBulkSurface = Color(0xFFF0F4F8);
const Color kBulkPurple = Color(0xFF6C63FF);

// ═══════════════════════════════════════════════════════════════════════
//  GENERIC CONFIRM DIALOG
// ═══════════════════════════════════════════════════════════════════════
Future<bool> showBulkConfirmDialog(
    BuildContext context, {
      required String title,
      required String message,
      String confirmLabel = 'Confirm',
      bool isDestructive = false,
      IconData icon = Icons.help_outline_rounded,
    }) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(icon, color: isDestructive ? kBulkCoral : kBulkTeal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ),
        ],
      ),
      content: Text(message, style: const TextStyle(fontSize: 14, height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: isDestructive ? kBulkCoral : kBulkNavy,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ═══════════════════════════════════════════════════════════════════════
//  PROGRESS DIALOG
// ═══════════════════════════════════════════════════════════════════════
/// Shows a non-dismissible progress dialog and returns a controller with
/// `update(done, total)` / `close()`. Usage:
///
///   final progress = showBulkProgressDialog(context, title: 'Deleting…');
///   final result = await InventoryBulkOperationsService.bulkDelete(
///     items: selected,
///     onProgress: (done, total) => progress.update(done, total),
///   );
///   progress.close();
class BulkProgressController {
  final ValueNotifier<int> _done = ValueNotifier(0);
  final ValueNotifier<int> _total = ValueNotifier(1);
  final BuildContext _dialogContext;
  bool _closed = false;

  BulkProgressController(this._dialogContext);

  void update(int done, int total) {
    _done.value = done;
    _total.value = total <= 0 ? 1 : total;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    Navigator.of(_dialogContext, rootNavigator: true).pop();
  }
}

BulkProgressController showBulkProgressDialog(
    BuildContext context, {
      required String title,
    }) {
  late BulkProgressController controller;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      controller = BulkProgressController(ctx);
      return PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: ValueListenableBuilder<int>(
            valueListenable: controller._done,
            builder: (_, done, __) {
              return ValueListenableBuilder<int>(
                valueListenable: controller._total,
                builder: (_, total, __) {
                  final progress = total == 0 ? 0.0 : done / total;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16, color: kBulkNavy)),
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: kBulkSurface,
                          valueColor: const AlwaysStoppedAnimation(kBulkTeal),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$done of $total processed',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      );
    },
  );

  return controller;
}

// ═══════════════════════════════════════════════════════════════════════
//  RESULT SUMMARY DIALOG
// ═══════════════════════════════════════════════════════════════════════
Future<void> showBulkResultDialog(
    BuildContext context, {
      required String title,
      required BulkOperationResult result,
    }) {
  final ok = result.failed == 0 && result.succeeded > 0;
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: ok ? const Color(0xFF00B894) : kBulkAmber,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${result.succeeded} of ${result.total} item(s) succeeded'
                  '${result.failed > 0 ? ', ${result.failed} failed' : ''}.',
              style: const TextStyle(fontSize: 14),
            ),
            if (result.hasErrors) ...[
              const SizedBox(height: 10),
              const Text('Errors:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              const SizedBox(height: 4),
              ...result.errors.take(10).map(
                    (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('• $e',
                      style: const TextStyle(fontSize: 12, color: kBulkCoral)),
                ),
              ),
              if (result.errors.length > 10)
                Text('…and ${result.errors.length - 10} more.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          style: FilledButton.styleFrom(backgroundColor: kBulkNavy),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════
//  PRICE UPDATE DIALOG
// ═══════════════════════════════════════════════════════════════════════
class PriceUpdateSpec {
  final PriceAdjustMode mode;
  final double value;
  const PriceUpdateSpec(this.mode, this.value);
}

Future<PriceUpdateSpec?> showBulkPriceUpdateDialog(
    BuildContext context, {
      required int selectedCount,
    }) {
  return showDialog<PriceUpdateSpec>(
    context: context,
    builder: (ctx) => _PriceUpdateDialog(selectedCount: selectedCount),
  );
}

class _PriceUpdateDialog extends StatefulWidget {
  final int selectedCount;
  const _PriceUpdateDialog({required this.selectedCount});

  @override
  State<_PriceUpdateDialog> createState() => _PriceUpdateDialogState();
}

class _PriceUpdateDialogState extends State<_PriceUpdateDialog> {
  PriceAdjustMode _mode = PriceAdjustMode.percentageIncrease;
  final _valueController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _valueController.text.trim();
    final value = double.tryParse(raw);
    if (value == null || value < 0) {
      setState(() => _error = 'Enter a valid non-negative number.');
      return;
    }
    if ((_mode == PriceAdjustMode.percentageIncrease ||
        _mode == PriceAdjustMode.percentageDecrease) &&
        value > 1000) {
      setState(() => _error = 'Percentage looks too large — double-check the value.');
      return;
    }
    Navigator.pop(context, PriceUpdateSpec(_mode, value));
  }

  @override
  Widget build(BuildContext context) {
    final isPercentage = _mode == PriceAdjustMode.percentageIncrease ||
        _mode == PriceAdjustMode.percentageDecrease;
    final isExact = _mode == PriceAdjustMode.setExact;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.currency_rupee_rounded, color: kBulkTeal),
          SizedBox(width: 10),
          Text('Bulk Update Prices', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.selectedCount} item(s) selected',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            const SizedBox(height: 14),
            ...PriceAdjustMode.values.map(
                  (m) => RadioListTile<PriceAdjustMode>(
                value: m,
                groupValue: _mode,
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: kBulkTeal,
                title: Text(m.label, style: const TextStyle(fontSize: 13.5)),
                onChanged: (v) => setState(() => _mode = v ?? _mode),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _valueController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: isExact
                    ? 'New price (Rs.)'
                    : isPercentage
                    ? 'Percentage (%)'
                    : 'Amount (Rs.)',
                prefixIcon: Icon(isPercentage ? Icons.percent_rounded : Icons.currency_rupee_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: kBulkNavy),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  CATEGORY PICKER DIALOG
// ═══════════════════════════════════════════════════════════════════════
Future<String?> showBulkCategoryPickerDialog(
    BuildContext context, {
      required List<String> categories,
      required int selectedCount,
    }) {
  String? chosen = categories.isNotEmpty ? categories.first : null;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.category_rounded, color: kBulkTeal),
            SizedBox(width: 10),
            Text('Bulk Category Change', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$selectedCount item(s) will move to:',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: chosen,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => chosen = v),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: chosen == null ? null : () => Navigator.pop(ctx, chosen),
            style: FilledButton.styleFrom(backgroundColor: kBulkNavy),
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════
//  BRANCH TRANSFER DIALOG
// ═══════════════════════════════════════════════════════════════════════
Future<int?> showBulkBranchPickerDialog(
    BuildContext context, {
      required int selectedCount,
    }) {
  int chosen = 1;
  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.compare_arrows_rounded, color: kBulkTeal),
            SizedBox(width: 10),
            Text('Bulk Branch Transfer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Move $selectedCount item(s) to:',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            RadioListTile<int>(
              value: 1,
              groupValue: chosen,
              dense: true,
              activeColor: kBulkTeal,
              title: const Text('CDA Admin (Branch 1)'),
              onChanged: (v) => setState(() => chosen = v ?? chosen),
            ),
            RadioListTile<int>(
              value: 2,
              groupValue: chosen,
              dense: true,
              activeColor: kBulkTeal,
              title: const Text('CDA Ops (Branch 2)'),
              onChanged: (v) => setState(() => chosen = v ?? chosen),
            ),
            RadioListTile<int>(
              value: 0,
              groupValue: chosen,
              dense: true,
              activeColor: kBulkTeal,
              title: const Text('Unassigned'),
              onChanged: (v) => setState(() => chosen = v ?? chosen),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, chosen),
            style: FilledButton.styleFrom(backgroundColor: kBulkNavy),
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════
//  EXPORT FORMAT PICKER (bottom sheet)
// ═══════════════════════════════════════════════════════════════════════
Future<BulkExportFormat?> showBulkExportFormatSheet(
    BuildContext context, {
      required int selectedCount,
    }) {
  return showModalBottomSheet<BulkExportFormat>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.file_download_rounded, color: kBulkNavy),
                  const SizedBox(width: 10),
                  Text('Export $selectedCount item(s)',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.grid_on_rounded, color: Color(0xFF1D6F42)),
              title: const Text('Excel (.xlsx)'),
              onTap: () => Navigator.pop(ctx, BulkExportFormat.excel),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded, color: kBulkCoral),
              title: const Text('PDF (.pdf)'),
              onTap: () => Navigator.pop(ctx, BulkExportFormat.pdf),
            ),
            ListTile(
              leading: const Icon(Icons.table_rows_rounded, color: kBulkPurple),
              title: const Text('CSV (.csv)'),
              onTap: () => Navigator.pop(ctx, BulkExportFormat.csv),
            ),
          ],
        ),
      ),
    ),
  );
}