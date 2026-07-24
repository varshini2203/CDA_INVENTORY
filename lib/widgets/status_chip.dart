// lib/widgets/status_chip.dart

import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  Color get _color =>
      status == 'IN' ? const Color(0xFF00E5CC) : const Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(
            color: _color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}