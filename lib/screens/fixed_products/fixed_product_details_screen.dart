import 'package:flutter/material.dart';
import 'package:cda_inventory/models/fixed_asset.dart';

enum FixedAssetDetailsAction {
  edit,
  delete,
}

class FixedProductDetailsScreen extends StatelessWidget {
  final FixedAsset asset;

  const FixedProductDetailsScreen({
    super.key,
    required this.asset,
  });

  static const Color _navy = Color(0xFF0A1628);
  static const Color _accent = Color(0xFF00B89C);

  static Future<FixedAssetDetailsAction?> show({
    required BuildContext context,
    required FixedAsset asset,
  }) {
    return showModalBottomSheet<FixedAssetDetailsAction>(
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
            child: FixedProductDetailsScreen(asset: asset),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Safe null-handled strings
    final category = (asset.category ?? '').trim();
    final status = (asset.status ?? '').trim().isEmpty ? 'Active' : (asset.status ?? '').trim();
    final branch = (asset.branch ?? '').trim();
    final location = (asset.location ?? '').trim();
    final description = (asset.description ?? '').trim();
    final createdBy = (asset.createdBy ?? '').trim();
    final isLowStock = (asset.quantity) <= 2;

    final statusColor = _statusColor(status);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
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

                // Header row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        color: _accent,
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asset.name,
                            style: const TextStyle(
                              color: _navy,
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
                                label: category.isEmpty ? 'Fixed Asset' : category,
                                icon: Icons.category_rounded,
                                color: _accent,
                              ),
                              _Badge(
                                label: status,
                                icon: Icons.circle,
                                color: statusColor,
                              ),
                              if (isLowStock)
                                _Badge(
                                  label: 'Low Stock',
                                  icon: Icons.warning_amber_rounded,
                                  color: Colors.orange.shade700,
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

                // Metric cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cards = [
                      _MetricCard(
                        icon: Icons.layers_rounded,
                        value: '${asset.quantity}',
                        label: 'Quantity',
                        color: isLowStock ? Colors.orange.shade700 : _accent,
                      ),
                      _MetricCard(
                        icon: Icons.info_rounded,
                        value: status,
                        label: 'Status',
                        color: statusColor,
                      ),
                      _MetricCard(
                        icon: Icons.business_rounded,
                        value: branch.isEmpty ? 'Not assigned' : branch,
                        label: 'Branch',
                        color: const Color(0xFF1565C0),
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

                // Details section
                const Text(
                  'ASSET INFORMATION',
                  style: TextStyle(
                    color: _accent,
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
                        icon: Icons.business_rounded,
                        label: 'Branch',
                        value: branch.isEmpty ? 'Not assigned' : branch,
                      ),
                      const Divider(height: 24),
                      _DetailRow(
                        icon: Icons.location_on_rounded,
                        label: 'Location',
                        value: location.isEmpty ? 'No location' : location,
                      ),
                      const Divider(height: 24),
                      _DetailRow(
                        icon: Icons.category_rounded,
                        label: 'Category',
                        value: category.isEmpty ? 'Fixed Asset' : category,
                      ),
                      const Divider(height: 24),
                      _DetailRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Added By',
                        value: createdBy.isEmpty ? 'Unknown user' : createdBy,
                      ),
                      const Divider(height: 24),
                      _DetailRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Added On',
                        value: asset.createdAt == null ? 'Not available' : _formatDate(asset.createdAt!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Description
                const Text(
                  'DESCRIPTION',
                  style: TextStyle(
                    color: _accent,
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
                    description.isEmpty ? 'No description provided.' : description,
                    style: TextStyle(
                      color: description.isEmpty ? Colors.grey.shade500 : Colors.grey.shade800,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 26),

                // Bottom actions
                LayoutBuilder(
                  builder: (context, constraints) {
                    final editButton = _BottomActionButton(
                      label: 'Edit',
                      icon: Icons.edit_rounded,
                      foregroundColor: _navy,
                      backgroundColor: Colors.white,
                      borderColor: _navy,
                      onPressed: () {
                        Navigator.pop(context, FixedAssetDetailsAction.edit);
                      },
                    );

                    final deleteButton = _BottomActionButton(
                      label: 'Remove',
                      icon: Icons.delete_rounded,
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red.shade500,
                      borderColor: Colors.red.shade500,
                      onPressed: () {
                        Navigator.pop(context, FixedAssetDetailsAction.delete);
                      },
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

  static Color _statusColor(String status) {
    final s = status.toLowerCase();
    switch (s) {
      case 'maintenance':
        return Colors.orange.shade700;
      case 'retired':
        return Colors.red.shade600;
      default:
        return Colors.green.shade600;
    }
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year, $hour:$minute $period';
  }
}

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
        border: Border.all(
          color: color.withValues(alpha: 0.30),
        ),
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
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
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
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
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
        Icon(icon, size: 19, color: const Color(0xFF00A98F)),
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
          side: BorderSide(
            color: borderColor,
            width: 1.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }
}