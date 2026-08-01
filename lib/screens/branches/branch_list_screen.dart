import 'package:flutter/material.dart';
import 'package:cda_inventory/screens/branches/branch_inventory_screen.dart';

class BranchListScreen extends StatelessWidget {
  const BranchListScreen({super.key});

  static const Color kNavy = Color(0xFF0A1628);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kSurface = Color(0xFFF0F4F8);

  @override
  Widget build(BuildContext context) {
    final branches = <_BranchEntry>[
      const _BranchEntry(
        id: 1,
        label: 'CDA ADMIN',
        subtitle: 'Branch 1 inventory ',
        icon: Icons.location_city_rounded,
        color: Color(0xFF6C63FF),
      ),
      const _BranchEntry(
        id: 2,
        label: 'CDA OPS',
        subtitle: 'Branch 2 inventory ',
        icon: Icons.business_rounded,
        color: Color(0xFF00B894),
      ),
    ];

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text('Branch Inventory',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: branches.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final b = branches[i];
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: RouteSettings(name: 'Branch Inventory (${b.label})'),
                    builder: (_) => b.id == 1
                        ? const Branch1InventoryScreen()
                        : const Branch2InventoryScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: b.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(b.icon, color: b.color, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: kNavy)),
                          const SizedBox(height: 3),
                          Text(b.subtitle,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BranchEntry {
  final int id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _BranchEntry({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}