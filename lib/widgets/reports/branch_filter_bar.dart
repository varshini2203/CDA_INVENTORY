// lib/widgets/reports/branch_filter_bar.dart
//
// Segmented chip control that lets an admin scope any report to a single
// branch instead of always seeing Branch 1 + Branch 2 combined.
// Raw branch values match what's stored on the Purchase / Invoice / Stock /
// Drone documents: 'Branch 1' (shown to the admin as "CDA Admin") and
// 'Branch 2' (shown as "CDA Ops"). Only the label shown to the admin
// changes here — the raw 'Branch 1' / 'Branch 2' string stored in
// Firestore and used for filtering stays exactly the same.
//
// FIX: some write paths (bulk import / Godown Stock Import in particular)
// save the branch field as the display label itself ('CDA Admin',
// 'CDA ADMIN', 'cda ops', ...) instead of the canonical 'Branch 1' /
// 'Branch 2' code. Comparing raw values directly meant selecting the
// "CDA ADMIN" chip only matched rows stored with the exact code, silently
// dropping every row stored as a label variant (they still showed up under
// "All Branches" because that path skips filtering entirely). branchOf
// values are now run through normalizeBranch() before comparing, so any
// stored form resolves to the same canonical branch.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cda_inventory/core/access/access_scope.dart';

const String kBranch1 = 'Branch 1';
const String kBranch2 = 'Branch 2';

const Map<String?, String> kBranchOptions = {
  null: 'All Branches',
  kBranch1: 'CDA Admin',
  kBranch2: 'CDA Ops',
};

/// Normalizes any raw branch value seen across Firestore documents — the
/// canonical code ('Branch 1' / 'Branch 2') as well as legacy/import paths
/// that wrote the display label directly ('CDA Admin', 'CDA ADMIN',
/// 'cda ops', etc., in any casing/spacing) — down to the canonical
/// 'Branch 1' / 'Branch 2' code. Returns null for null/empty input, and
/// returns the trimmed original value unchanged if it doesn't recognize it
/// (so it simply won't match either chip instead of throwing).
String? normalizeBranch(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final v = trimmed.toLowerCase();
  if (v == kBranch1.toLowerCase() || v.contains('admin')) return kBranch1;
  if (v == kBranch2.toLowerCase() || v.contains('ops')) return kBranch2;
  return trimmed;
}

/// Friendly display name for a raw branch value — use this anywhere a
/// branch is shown to the admin (chips, card details, filenames, snackbars)
/// instead of printing the raw 'Branch 1' / 'Branch 2' string directly.
String branchDisplayName(String? raw) {
  if (raw == null) return kBranchOptions[null]!;
  final norm = normalizeBranch(raw);
  return kBranchOptions[norm] ?? raw;
}

/// Filters [source] down to rows matching [branch]. Returns [source]
/// unchanged when [branch] is null (meaning "All Branches"). Both the
/// requested [branch] and each row's branch value are normalized before
/// comparing, so rows stored as either the raw code or a display-label
/// variant are matched consistently.
List<T> filterByBranch<T>(
    List<T> source, String? branch, String? Function(T row) branchOf) {
  if (branch == null) return source;
  final target = normalizeBranch(branch);
  return source
      .where((row) => normalizeBranch(branchOf(row)) == target)
      .toList();
}

/// Returns the branch a NON-ADMIN user is locked to on every report screen,
/// or null for admins (who may view/export any single branch or all
/// branches combined, unrestricted).
///
/// Call this from build() — it uses context.watch<CurrentAccess>() so the
/// screen rebuilds and re-locks itself the instant the access-control
/// stream resolves after login, instead of leaving all-branch data visible
/// for a frame while the access doc is still loading.
///
/// Returns null if the access doc hasn't loaded yet — callers pair this
/// with the auto-correct block in each screen's build() (see
/// InvoiceReportScreen for the reference implementation) so the lock snaps
/// into place the moment `access` arrives, without a setState-during-build
/// error.
String? lockedReportBranch(BuildContext context) {
  final access = context.watch<CurrentAccess>().access;
  if (access == null) return null; // still loading
  if (access.isAdmin) return null; // admins are never branch-locked
  return normalizeBranch(access.branch);
}

class BranchFilterBar extends StatelessWidget {
  final String? selected; // null = All Branches
  final ValueChanged<String?> onChanged;
  final Color accent;

  /// true when placed on a dark/navy background (e.g. the report header),
  /// false when placed on a white card background.
  final bool dark;

  /// Non-null for a branch-locked (non-admin) user: only that branch's chip
  /// is rendered, it's always shown selected, and it can't be tapped away
  /// from. Pass the value returned by [lockedReportBranch]. Null (the
  /// default) means unrestricted — every chip renders and behaves as before.
  final String? lockedBranch;

  const BranchFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.accent = const Color(0xFF00D4AA),
    this.dark = true,
    this.lockedBranch,
  });

  @override
  Widget build(BuildContext context) {
    final unselectedBg = dark ? Colors.white.withOpacity(0.12) : Colors.grey.shade100;
    final unselectedFg = dark ? Colors.white.withOpacity(0.85) : Colors.grey.shade700;
    final unselectedSide = dark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300;
    final locked = lockedBranch != null;

    final entries = locked
        ? kBranchOptions.entries.where((e) => e.key == lockedBranch).toList()
        : kBranchOptions.entries.toList();
    final effectiveSelected = locked ? lockedBranch : selected;

    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        children: entries.map((e) {
          final isSelected = effectiveSelected == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: locked ? null : () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? accent : unselectedBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? accent : unselectedSide),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (locked) ...[
                    Icon(Icons.lock_rounded,
                        size: 11, color: isSelected ? Colors.white : unselectedFg),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    e.value,
                    style: TextStyle(
                      color: isSelected ? Colors.white : unselectedFg,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}