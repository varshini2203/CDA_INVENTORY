// lib/widgets/reports/report_date_range_picker.dart
//
// Drop-in replacement for Flutter's built-in showDateRangePicker(), used
// across every Report screen. The stock picker forces you to scroll/tap
// through a two-month calendar grid and drag between start/end days, which
// is slow and error-prone for a business-report date range. This widget
// gives quick presets (Today, Last 7 days, This month, etc.) for the 90%
// case, plus two simple single-date pickers for a custom range.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportDateRangePicker {
  ReportDateRangePicker._();

  /// Shows the picker as a bottom sheet and returns the chosen range,
  /// or null if the user cancelled.
  static Future<DateTimeRange?> show(
      BuildContext context, {
        required DateTimeRange initialRange,
        DateTime? firstDate,
        DateTime? lastDate,
        String title = 'Select Date Range',
        Color accent = const Color(0xFF00D4AA),
      }) {
    final now = DateTime.now();
    return showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReportDateRangeSheet(
        initialRange: initialRange,
        firstDate: firstDate ?? DateTime(now.year - 5),
        lastDate: lastDate ?? DateTime(now.year + 1),
        title: title,
        accent: accent,
      ),
    );
  }
}

class _ReportDateRangeSheet extends StatefulWidget {
  final DateTimeRange initialRange;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final Color accent;

  const _ReportDateRangeSheet({
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.accent,
  });

  @override
  State<_ReportDateRangeSheet> createState() => _ReportDateRangeSheetState();
}

class _ReportDateRangeSheetState extends State<_ReportDateRangeSheet> {
  late DateTime _start;
  late DateTime _end;
  String? _activePreset;

  static const _sheetBg = Color(0xFF0A1428);
  static const _fieldBg = Color(0xFF0F1C35);
  static const _border = Color(0xFF1A2E50);

  @override
  void initState() {
    super.initState();
    _start = _d(widget.initialRange.start);
    _end = _d(widget.initialRange.end);
  }

  DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

  void _applyPreset(String key) {
    final now = DateTime.now();
    late DateTime s, e;
    switch (key) {
      case 'today':
        s = _d(now);
        e = _d(now);
        break;
      case 'yesterday':
        final y = now.subtract(const Duration(days: 1));
        s = _d(y);
        e = _d(y);
        break;
      case 'last7':
        s = _d(now.subtract(const Duration(days: 6)));
        e = _d(now);
        break;
      case 'last30':
        s = _d(now.subtract(const Duration(days: 29)));
        e = _d(now);
        break;
      case 'thismonth':
        s = DateTime(now.year, now.month, 1);
        e = _d(now);
        break;
      case 'lastmonth':
        final lastMonthEnd = DateTime(now.year, now.month, 0);
        s = DateTime(lastMonthEnd.year, lastMonthEnd.month, 1);
        e = lastMonthEnd;
        break;
      case 'thisyear':
        s = DateTime(now.year, 1, 1);
        e = _d(now);
        break;
      default:
        return;
    }
    setState(() {
      _start = s;
      _end = e;
      _activePreset = key;
    });
  }

  Future<void> _pickSingle({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: widget.accent,
            onPrimary: Colors.white,
            surface: _fieldBg,
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: _sheetBg,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _activePreset = null;
        if (isStart) {
          _start = picked;
          if (_end.isBefore(_start)) _end = _start;
        } else {
          _end = picked;
          if (_start.isAfter(_end)) _start = _end;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    const presets = [
      MapEntry('today', 'Today'),
      MapEntry('yesterday', 'Yesterday'),
      MapEntry('last7', 'Last 7 days'),
      MapEntry('last30', 'Last 30 days'),
      MapEntry('thismonth', 'This month'),
      MapEntry('lastmonth', 'Last month'),
      MapEntry('thisyear', 'This year'),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: _sheetBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(widget.title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Pick a quick range, or set custom dates below',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11.5)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((p) {
                  final selected = _activePreset == p.key;
                  return GestureDetector(
                    onTap: () => _applyPreset(p.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected ? widget.accent : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selected ? widget.accent : _border),
                      ),
                      child: Text(
                        p.value,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              Text('CUSTOM RANGE',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _dateField('From', fmt.format(_start), () => _pickSingle(isStart: true))),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white24, size: 16),
                const SizedBox(width: 10),
                Expanded(child: _dateField('To', fmt.format(_end), () => _pickSingle(isStart: false))),
              ]),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, DateTimeRange(start: _start, end: _end)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateField(String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _fieldBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}