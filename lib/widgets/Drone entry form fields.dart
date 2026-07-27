// lib/widgets/drone_entry_form_fields.dart
//
// Two drop-in widgets for the Drone In/Out entry screen:
//   1. BranchDropdown   — All Branch / CDA Admin / CDA Ops
//   2. DateTimePickerField — tap-to-open calendar + clock, combined into
//      one DateTime you can pass straight into
//      DroneService.updateStatus(..., actionTime: pickedDateTime)
//
// Neither widget touches Firestore directly — they just return values via
// onChanged, so they slot into whatever form/state management you're
// already using on the entry screen.

import 'package:flutter/material.dart';
import '../services/drone_service.dart';

// ─── 1. BRANCH DROPDOWN ───────────────────────────────────────────────────

class BranchDropdown extends StatelessWidget {
  final String value; // DroneService.branchAll, 'CDA Admin', or 'CDA Ops'
  final ValueChanged<String> onChanged;
  final bool includeAllOption;

  const BranchDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.includeAllOption = true,
  });

  @override
  Widget build(BuildContext context) {
    final options = <String>[
      if (includeAllOption) DroneService.branchAll,
      ...DroneService.branches,
    ];

    return DropdownButtonFormField<String>(
      initialValue: options.contains(value) ? value : options.first,
      decoration: const InputDecoration(
        labelText: 'Branch',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.apartment_outlined),
      ),
      items: options.map((b) {
        return DropdownMenuItem<String>(
          value: b,
          child: Text(b == DroneService.branchAll ? 'All Branch' : b),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ─── 2. DATE + TIME PICKER FIELD ──────────────────────────────────────────

class DateTimePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const DateTimePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = value ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(now.year - 1),
      lastDate: lastDate ?? DateTime(now.year + 1),
    );
    if (pickedDate == null) return;
    if (!context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (pickedTime == null) return;

    onChanged(DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    ));
  }

  String _formatted(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}  ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.calendar_month_outlined),
          suffixIcon: const Icon(Icons.access_time),
        ),
        child: Text(
          value != null ? _formatted(value!) : 'Select date & time',
          style: value == null
              ? TextStyle(color: Theme.of(context).hintColor)
              : null,
        ),
      ),
    );
  }
}