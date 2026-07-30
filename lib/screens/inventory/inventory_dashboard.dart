// lib/screens/inventory/product_details_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/inventory_model.dart';

enum ProductDetailsAction { edit, delete }

class ProductDetailsScreen extends StatelessWidget {
  final InventoryItem item;

  const ProductDetailsScreen({
    super.key,
    required this.item,
  });

  // ── Design tokens (same as InventoryDashboard) ──────────────────────────
  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kCoral = Color(0xFFFF6B6B);
  static const Color kAmber = Color(0xFFFFB800);
  static const Color kGreen = Color(0xFF00B894);
  static const Color kPurple = Color(0xFF6C63FF);

  static const Map<String, IconData> categoryIcons = {
    "ONFIELD": Icons.flight_takeoff,
    "RPTO": Icons.verified_user,
    "STATIONARY": Icons.edit_note,
    "ELECTRICAL": Icons.electrical_services,
    "TOOL KITS": Icons.construction,
    "LAB ROOM": Icons.science,
    "CHARGING STATION": Icons.battery_charging_full,
    "NAVIN KIT": Icons.backpack,
    "FPV DRONES": Icons.videocam,
    "REMOTE CONTROLLER": Icons.sports_esports,
    "ADDITIONAL DRONE SPARE": Icons.build_circle,
    "3D PRINTER": Icons.print,
    "HOUSEKEEPING SUPPLIES": Icons.cleaning_services,
    "MANAGER ROOM": Icons.meeting_room,
    "INSTRUCTOR ROOM": Icons.school,
    "CORRIDOR THINGS": Icons.door_sliding,
    "REST ROOM THING": Icons.wc,
  };

  static const Map<String, Color> categoryColors = {
    "ONFIELD": Color(0xFF2E7D32),
    "RPTO": Color(0xFF6A1B9A),
    "STATIONARY": Color(0xFFE65100),
    "ELECTRICAL": Color(0xFFF9A825),
    "TOOL KITS": Color(0xFF37474F),
    "LAB ROOM": Color(0xFF00838F),
    "CHARGING STATION": Color(0xFF558B2F),
    "NAVIN KIT": Color(0xFF4527A0),
    "FPV DRONES": Color(0xFFC62828),
    "REMOTE CONTROLLER": Color(0xFF00695C),
    "ADDITIONAL DRONE SPARE": Color(0xFF4E342E),
    "3D PRINTER": Color(0xFF1565C0),
    "HOUSEKEEPING SUPPLIES": Color(0xFF00838F),
    "MANAGER ROOM": Color(0xFF283593),
    "INSTRUCTOR ROOM": Color(0xFF1B5E20),
    "CORRIDOR THINGS": Color(0xFF4A148C),
    "REST ROOM THING": Color(0xFF880E4F),
  };

  /// Shows the details sheet and returns which action the user picked
  /// (edit / delete), or null if they just closed it.
  static Future<ProductDetailsAction?> show({
    required BuildContext context,
    required InventoryItem item,
  }) {
    return showModalBottomSheet<ProductDetailsAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) {
        final screenHeight = MediaQuery.sizeOf(context).height;

        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 850,
              maxHeight: screenHeight * 0.90,
            ),
            child: ProductDetailsScreen(item: item),
          ),
        );
      },
    );
  }

  // ── Derived values (all null-safe) ──────────────────────────────────────
  Color get _categoryColor => categoryColors[item.category] ?? kTeal;

  IconData get _categoryIcon =>
      categoryIcons[item.category] ?? Icons.inventory_2_rounded;

  String get _branchLabel {
    switch (item.branch) {
      case 1:
        return 'CDA Admin';
      case 2:
        return 'CDA Ops';
      default:
        return 'Unassigned';
    }
  }

  Color get _stockColor {
    if (item.quantity == 0) return kCoral;
    if (item.quantity <= 2) return kAmber;
    return kGreen;
  }

  String get _stockLabel {
    if (item.quantity == 0) return 'Out of Stock';
    if (item.quantity <= 2) return 'Low Stock';
    return 'In Stock';
  }

  String _formatDate(DateTime date) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(date);

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor;
    final addedBy = (item.addedBy ?? '').trim();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 14, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 52,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ── Header ────────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(_categoryIcon, color: color, size: 34),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              color: kNavy,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _Badge(
                                label: item.category,
                                icon: _categoryIcon,
                                color: color,
                              ),
                              _Badge(
                                label: _stockLabel,
                                icon: Icons.circle,
                                color: _stockColor,
                              ),
                              if (item.branch != 0)
                                _Badge(
                                  label: _branchLabel,
                                  icon: Icons.business_rounded,
                                  color: kPurple,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 26),

                // ── Metric cards ──────────────────────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cards = [
                      _MetricCard(
                        icon: Icons.layers_rounded,
                        value: '${item.quantity}',
                        label: 'Available',
                        color: _stockColor,
                      ),
                      _MetricCard(
                        icon: Icons.info_rounded,
                        value: _stockLabel,
                        label: 'Status',
                        color: _stockColor,
                      ),
                      _MetricCard(
                        icon: Icons.business_rounded,
                        value: _branchLabel,
                        label: 'Branch',
                        color: kPurple,
                      ),
                    ];

                    if (constraints.maxWidth < 600) {
                      return Column(
                        children: [
                          cards[0],
                          const SizedBox(height: 10),
                          cards[1],
                          const SizedBox(height: 10),
                          cards[2],
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 12),
                        Expanded(child: cards[1]),
                        const SizedBox(width: 12),
                        Expanded(child: cards[2]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // ── Item information ──────────────────────────────────────
                const Text(
                  'ITEM INFORMATION',
                  style: TextStyle(
                    color: kTeal,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Icons.category_rounded,
                        label: 'Category',
                        value: item.category,
                      ),
                      const Divider(height: 24),
                      _DetailRow(
                        icon: Icons.location_on_rounded,
                        label: 'Location',
                        value: item.location.trim().isEmpty
                            ? 'No location'
                            : item.location,
                      ),
                      const Divider(height: 24),
                      _DetailRow(
                        icon: Icons.business_rounded,
                        label: 'Branch',
                        value: _branchLabel,
                      ),
                      const Divider(height: 24),
                      _DetailRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Added By',
                        value: addedBy.isEmpty ? 'Unknown user' : addedBy,
                      ),
                      if (item.createdAt != null) ...[
                        const Divider(height: 24),
                        _DetailRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Created',
                          value: _formatDate(item.createdAt!),
                        ),
                      ],
                      if (item.updatedAt != null) ...[
                        const Divider(height: 24),
                        _DetailRow(
                          icon: Icons.update_rounded,
                          label: 'Updated',
                          value: _formatDate(item.updatedAt!),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Description ───────────────────────────────────────────
                const Text(
                  'DESCRIPTION',
                  style: TextStyle(
                    color: kTeal,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 95),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    item.description.trim().isEmpty
                        ? 'No description provided.'
                        : item.description,
                    style: TextStyle(
                      color: item.description.trim().isEmpty
                          ? Colors.grey.shade500
                          : Colors.grey.shade800,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 26),

                // ── Actions ───────────────────────────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final editButton = _BottomActionButton(
                      label: 'Edit',
                      icon: Icons.edit_rounded,
                      foregroundColor: kNavy,
                      backgroundColor: Colors.white,
                      borderColor: kNavy,
                      onPressed: () => Navigator.pop(
                        context,
                        ProductDetailsAction.edit,
                      ),
                    );

                    final deleteButton = _BottomActionButton(
                      label: 'Delete',
                      icon: Icons.delete_rounded,
                      foregroundColor: Colors.white,
                      backgroundColor: kCoral,
                      borderColor: kCoral,
                      onPressed: () => Navigator.pop(
                        context,
                        ProductDetailsAction.delete,
                      ),
                    );

                    if (constraints.maxWidth < 500) {
                      return Column(
                        children: [
                          SizedBox(width: double.infinity, child: editButton),
                          const SizedBox(height: 10),
                          SizedBox(width: double.infinity, child: deleteButton),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: editButton),
                        const SizedBox(width: 14),
                        Expanded(child: deleteButton),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PRIVATE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _Badge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: const Color(0xFF1565C0)),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onPressed;

  const _BottomActionButton({
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor, width: 1.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }
}