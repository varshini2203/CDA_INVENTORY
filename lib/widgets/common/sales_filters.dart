// lib/widgets/common/sales_filters.dart
//
// Shared filter toolkit for the sales-side list screens (Sale Invoices,
// Estimate/Quotation, ...):
//
//   • SalesPeriod            – All Time / Today / This Week / This Month /
//                              This Quarter / This Year / Custom → date range
//   • SalesFilterData        – builds the "All Firms" / "All Users" options
//                              (always lists both branches + every user)
//   • showSalesOptionSheet   – themed bottom sheet used by every dropdown chip
//   • showSalesDateRangePicker – light-themed range calendar with quick presets
//   • SalesFilterChip        – the pill used in the filter row
//
// WHY THIS EXISTS
// The old dialogs were built with default Material widgets, which inherit the
// app's dark text theme. On the white sheets that produced WHITE-ON-WHITE
// text, so "All Firms" / "All Users" looked empty and the calendar dates were
// invisible. Everything here sets its colors explicitly so it renders the
// same no matter which app theme is active.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cda_inventory/services/current_user_service.dart';
import 'package:cda_inventory/widgets/reports/branch_filter_bar.dart';

// ── Palette (same tokens as the Vyapar-style list screens) ────────────────
class SfColors {
  SfColors._();
  static const Color navy     = Color(0xFF0A1628);
  static const Color blue     = Color(0xFF2F6FE4);
  static const Color red      = Color(0xFFE94D5F);
  static const Color border   = Color(0xFFE7EAF0);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textSub  = Color(0xFF6B7280);
  static const Color textMute = Color(0xFF9CA3AF);
  static const Color bg       = Color(0xFFF4F6F9);
}

/// Sentinel values used by the filters.
const String kFilterAll  = 'All';
const String kFilterNone = '__none__'; // records with no firm / user stored

/// One selectable entry in a filter dropdown.
class FilterOption {
  final String value;
  final String label;
  const FilterOption(this.value, this.label);
}

// ═══════════════════════════════════════════════════════════════════════════
// PERIOD → DATE RANGE
// ═══════════════════════════════════════════════════════════════════════════
class SalesPeriod {
  SalesPeriod._();

  static const String all         = 'All Time';
  static const String today       = 'Today';
  static const String yesterday   = 'Yesterday';
  static const String thisWeek    = 'This Week';
  static const String thisMonth   = 'This Month';
  static const String lastMonth   = 'Last Month';
  static const String thisQuarter = 'This Quarter';
  static const String thisYear    = 'This Year';
  static const String custom      = 'Custom';

  /// Options shown in the period dropdown.
  static const List<String> options = [
    all, today, thisWeek, thisMonth, lastMonth, thisQuarter, thisYear, custom,
  ];

  /// Quick presets shown inside the calendar dialog.
  static const List<String> calendarPresets = [
    today, yesterday, thisWeek, thisMonth, lastMonth, thisQuarter, thisYear,
  ];

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Whole-period range (e.g. This Week = Mon..Sun, This Month = 1st..last
  /// day) so the label shown to the user is exactly what is filtered.
  /// Returns null for [all] and [custom].
  static DateTimeRange? rangeFor(String period, {DateTime? now}) {
    final n = dateOnly(now ?? DateTime.now());
    switch (period) {
      case today:
        return DateTimeRange(start: n, end: n);
      case yesterday:
        final y = n.subtract(const Duration(days: 1));
        return DateTimeRange(start: dateOnly(y), end: dateOnly(y));
      case thisWeek:
        final monday = DateTime(n.year, n.month, n.day - (n.weekday - 1));
        return DateTimeRange(
            start: monday,
            end: DateTime(monday.year, monday.month, monday.day + 6));
      case thisMonth:
        return DateTimeRange(
            start: DateTime(n.year, n.month, 1),
            end: DateTime(n.year, n.month + 1, 0));
      case lastMonth:
        return DateTimeRange(
            start: DateTime(n.year, n.month - 1, 1),
            end: DateTime(n.year, n.month, 0));
      case thisQuarter:
        final qStart = ((n.month - 1) ~/ 3) * 3 + 1;
        return DateTimeRange(
            start: DateTime(n.year, qStart, 1),
            end: DateTime(n.year, qStart + 3, 0));
      case thisYear:
        return DateTimeRange(
            start: DateTime(n.year, 1, 1), end: DateTime(n.year, 12, 31));
      default:
        return null;
    }
  }

  /// Inclusive, date-only containment check. A null [range] means "no date
  /// filter" and matches everything; a null [d] never matches a real range.
  static bool inRange(DateTime? d, DateTimeRange? range) {
    if (range == null) return true;
    if (d == null) return false;
    final day = dateOnly(d);
    return !day.isBefore(dateOnly(range.start)) &&
        !day.isAfter(dateOnly(range.end));
  }

  /// "14/08/2026 – 17/08/2026" style label for the date chip.
  static String rangeLabel(DateTimeRange r) {
    final f = DateFormat('dd/MM/yy');
    if (dateOnly(r.start) == dateOnly(r.end)) return f.format(r.start);
    return '${f.format(r.start)} – ${f.format(r.end)}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FIRM / USER OPTIONS
// ═══════════════════════════════════════════════════════════════════════════
class SalesFilterData {
  SalesFilterData._();

  static List<String>? _userNameCache;

  /// Names of every registered (non-rejected) user, so "All Users" lists
  /// people even before they've created their first invoice. Failures
  /// (offline / rules) just return an empty list — the filter then falls
  /// back to the names found on the records themselves.
  static Future<List<String>> loadUserNames({bool forceRefresh = false}) async {
    if (!forceRefresh && _userNameCache != null) return _userNameCache!;
    final names = <String>[];
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase();
        if (status == 'rejected' || status == 'removed') continue;
        final name = (data['name'] ?? '').toString().trim();
        if (name.isNotEmpty) names.add(name);
      }
      _userNameCache = names;
    } catch (_) {
      // keep whatever we have; do not cache a failure
    }
    return names;
  }

  /// Both branches are ALWAYS offered (CDA Admin / CDA Ops), plus any other
  /// distinct value found on records. A "Not assigned" entry appears only when
  /// some records have no firm stored (older data).
  static List<FilterOption> branchOptions(Iterable<String?> recordBranches) {
    final options = <FilterOption>[
      FilterOption(kBranch1, branchDisplayName(kBranch1)),
      FilterOption(kBranch2, branchDisplayName(kBranch2)),
    ];
    final known = <String>{kBranch1, kBranch2};
    var hasNone = false;
    final extras = <String>{};
    for (final raw in recordBranches) {
      final norm = normalizeBranch(raw);
      if (norm == null) {
        hasNone = true;
      } else if (!known.contains(norm)) {
        extras.add(norm);
      }
    }
    for (final e in (extras.toList()..sort())) {
      options.add(FilterOption(e, e));
    }
    if (hasNone) options.add(const FilterOption(kFilterNone, 'Not assigned'));
    return options;
  }

  /// Users = registered users ∪ names on the records ∪ the signed-in user.
  static List<FilterOption> userOptions(
      Iterable<String?> recordUsers, {
        Iterable<String> registeredUsers = const [],
      }) {
    final byKey = <String, String>{};
    void add(String? raw) {
      final n = (raw ?? '').trim();
      if (n.isEmpty || n == 'Unknown') return;
      byKey.putIfAbsent(n.toLowerCase(), () => n);
    }

    registeredUsers.forEach(add);
    recordUsers.forEach(add);
    try {
      add(CurrentUserService.nameSync);
    } catch (_) {/* no signed-in user */}

    final names = byKey.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final options = names.map((n) => FilterOption(n, n)).toList();
    final hasNone = recordUsers.any((u) => (u ?? '').trim().isEmpty);
    if (hasNone) options.add(const FilterOption(kFilterNone, 'Not assigned'));
    return options;
  }

  /// Distinct party (customer) names found on the records, A–Z, de-duplicated
  /// case-insensitively. This is what the "All Users" dropdown lists.
  static List<FilterOption> partyOptions(Iterable<String?> partyNames) {
    final byKey = <String, String>{};
    for (final raw in partyNames) {
      final n = (raw ?? '').trim();
      if (n.isEmpty) continue;
      byKey.putIfAbsent(n.toLowerCase(), () => n);
    }
    final names = byKey.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names.map((n) => FilterOption(n, n)).toList();
  }

  static bool branchMatches(String filter, String? recordBranch) {
    if (filter == kFilterAll) return true;
    final norm = normalizeBranch(recordBranch);
    if (filter == kFilterNone) return norm == null;
    return norm == normalizeBranch(filter);
  }

  static bool userMatches(String filter, String? recordUser) {
    if (filter == kFilterAll) return true;
    final u = (recordUser ?? '').trim();
    if (filter == kFilterNone) return u.isEmpty;
    return u.toLowerCase() == filter.trim().toLowerCase();
  }

  /// Chip label for the currently selected value.
  static String labelFor(
      List<FilterOption> options, String value, String allLabel) {
    if (value == kFilterAll) return allLabel;
    for (final o in options) {
      if (o.value == value) return o.label;
    }
    return value == kFilterNone ? 'Not assigned' : value;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FILTER CHIP
// ═══════════════════════════════════════════════════════════════════════════
class SalesFilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const SalesFilterChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    const blue = SfColors.blue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? blue.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? blue.withOpacity(0.5) : SfColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? blue : SfColors.textSub),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontSize: 12.5,
                color: active ? blue : SfColors.textDark,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              )),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: active ? blue : SfColors.textMute),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// OPTION SHEET (Firms / Users / Status / Period)
// ═══════════════════════════════════════════════════════════════════════════

/// Themed single-choice bottom sheet. Returns the picked option's `value`
/// (or null if dismissed). When [allLabel] is given, an "All …" entry whose
/// value is [kFilterAll] is added on top.
Future<String?> showSalesOptionSheet(
    BuildContext context, {
      required String title,
      required List<FilterOption> options,
      required String current,
      String? allLabel,
      String emptyText = 'Nothing to show yet',
    }) {
  final items = <FilterOption>[
    if (allLabel != null) FilterOption(kFilterAll, allLabel),
    ...options,
  ];
  final maxHeight = MediaQuery.of(context).size.height * 0.6;

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 520),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: SfColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: SfColors.textDark)),
            ),
          ),
          const Divider(height: 1, color: SfColors.border),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Text(emptyText,
                  style: const TextStyle(color: SfColors.textMute, fontSize: 13.5)),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final o = items[i];
                  final selected = o.value == current;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(ctx, o.value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: selected
                              ? SfColors.blue.withOpacity(0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Text(o.label,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? SfColors.blue
                                      : SfColors.textDark,
                                )),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle_rounded,
                                size: 20, color: SfColors.blue)
                          else
                            const Icon(Icons.radio_button_unchecked_rounded,
                                size: 20, color: SfColors.border),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// DATE RANGE PICKER (custom, light theme)
// ═══════════════════════════════════════════════════════════════════════════

/// Light-themed date-range calendar with quick presets. Returns the chosen
/// range (start/end are date-only), or null if cancelled.
Future<DateTimeRange?> showSalesDateRangePicker(
    BuildContext context, {
      DateTimeRange? initial,
      DateTime? firstDate,
      DateTime? lastDate,
    }) {
  return showDialog<DateTimeRange>(
    context: context,
    builder: (_) => _SalesRangeDialog(
      initial: initial,
      firstDate: SalesPeriod.dateOnly(firstDate ?? DateTime(2020)),
      lastDate: SalesPeriod.dateOnly(lastDate ?? DateTime(2100)),
    ),
  );
}

class _SalesRangeDialog extends StatefulWidget {
  final DateTimeRange? initial;
  final DateTime firstDate;
  final DateTime lastDate;
  const _SalesRangeDialog({
    required this.initial,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_SalesRangeDialog> createState() => _SalesRangeDialogState();
}

class _SalesRangeDialogState extends State<_SalesRangeDialog> {
  DateTime? _start;
  DateTime? _end;
  late DateTime _month; // first day of the visible month

  static const double _cellH = 40;
  static const List<String> _dow = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _start = SalesPeriod.dateOnly(init.start);
      _end = SalesPeriod.dateOnly(init.end);
    }
    final anchor = _start ?? SalesPeriod.dateOnly(DateTime.now());
    _month = DateTime(anchor.year, anchor.month, 1);
  }

  bool _same(DateTime? a, DateTime? b) =>
      a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;

  bool _enabled(DateTime d) =>
      !d.isBefore(widget.firstDate) && !d.isAfter(widget.lastDate);

  void _tap(DateTime d) {
    setState(() {
      if (_start == null || _end != null) {
        _start = d;
        _end = null;
      } else if (d.isBefore(_start!)) {
        _end = _start;
        _start = d;
      } else {
        _end = d;
      }
    });
  }

  void _applyPreset(String key) {
    final r = SalesPeriod.rangeFor(key);
    if (r == null) return;
    setState(() {
      _start = r.start;
      _end = r.end;
      _month = DateTime(r.start.year, r.start.month, 1);
    });
  }

  bool _presetSelected(String key) {
    final r = SalesPeriod.rangeFor(key);
    if (r == null || _start == null) return false;
    return _same(r.start, _start) && _same(r.end, _end ?? _start);
  }

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta, 1));

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    final summary = _start == null
        ? 'Start date – End date'
        : '${fmt.format(_start!)} – ${_end == null ? 'End date' : fmt.format(_end!)}';

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Navy header ────────────────────────────────────────────
              Container(
                color: SfColors.navy,
                padding: const EdgeInsets.fromLTRB(20, 18, 8, 16),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SELECT DATE RANGE',
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1)),
                        const SizedBox(height: 6),
                        Text(summary,
                            style: TextStyle(
                                color: _start == null ? Colors.white38 : Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
              ),

              // ── Quick presets ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SalesPeriod.calendarPresets.map((p) {
                    final sel = _presetSelected(p);
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _applyPreset(p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel ? SfColors.blue : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: sel ? SfColors.blue : SfColors.border),
                        ),
                        child: Text(p,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : SfColors.textDark,
                            )),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── Month navigation ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded,
                        color: SfColors.textDark),
                    onPressed: () => _shiftMonth(-1),
                  ),
                  Expanded(
                    child: Text(DateFormat('MMMM yyyy').format(_month),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: SfColors.textDark)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded,
                        color: SfColors.textDark),
                    onPressed: () => _shiftMonth(1),
                  ),
                ]),
              ),

              // ── Weekday header ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: List.generate(
                    7,
                        (i) => Expanded(
                      child: Center(
                        child: Text(_dow[i],
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: SfColors.textMute)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // ── Day grid (always 6 rows so the dialog never jumps) ─────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _buildGrid(),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: SfColors.border),

              // ── Actions ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SfColors.textSub,
                        side: const BorderSide(color: SfColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _start == null
                          ? null
                          : () => Navigator.pop(
                        context,
                        DateTimeRange(start: _start!, end: _end ?? _start!),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SfColors.blue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: SfColors.border,
                        disabledForegroundColor: SfColors.textMute,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Apply',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday % 7; // Sunday = 0
    final rows = <Widget>[];
    for (var r = 0; r < 6; r++) {
      final cells = <Widget>[];
      for (var c = 0; c < 7; c++) {
        final dayNum = r * 7 + c - lead + 1;
        if (dayNum < 1 || dayNum > daysInMonth) {
          cells.add(const Expanded(child: SizedBox(height: _cellH)));
        } else {
          cells.add(Expanded(
              child: _dayCell(DateTime(_month.year, _month.month, dayNum))));
        }
      }
      rows.add(Row(children: cells));
    }
    return Column(children: rows);
  }

  Widget _dayCell(DateTime d) {
    final enabled = _enabled(d);
    final isStart = _same(d, _start);
    final isEnd = _same(d, _end);
    final selected = isStart || isEnd;
    final hasRange = _start != null && _end != null && !_same(_start, _end);
    final band = SfColors.blue.withOpacity(0.12);

    final leftBand = hasRange && d.isAfter(_start!) && !d.isAfter(_end!);
    final rightBand = hasRange && !d.isBefore(_start!) && d.isBefore(_end!);
    final isToday = _same(d, DateTime.now());

    Color textColor;
    if (!enabled) {
      textColor = SfColors.border;
    } else if (selected) {
      textColor = Colors.white;
    } else {
      textColor = SfColors.textDark;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => _tap(d) : null,
      child: SizedBox(
        height: _cellH,
        child: Stack(alignment: Alignment.center, children: [
          Row(children: [
            Expanded(child: Container(color: leftBand ? band : Colors.transparent)),
            Expanded(child: Container(color: rightBand ? band : Colors.transparent)),
          ]),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? SfColors.blue : Colors.transparent,
              border: (!selected && isToday)
                  ? Border.all(color: SfColors.blue, width: 1.4)
                  : null,
            ),
            child: Text('${d.day}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected || isToday ? FontWeight.w800 : FontWeight.w500,
                  color: textColor,
                )),
          ),
        ]),
      ),
    );
  }
}