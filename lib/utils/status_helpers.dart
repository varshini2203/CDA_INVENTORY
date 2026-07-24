// lib/utils/status_helpers.dart
//
// Shared status → color mapping so the list, view, and form screens all
// render "Paid" / "Pending" / "Overdue" consistently.

import 'package:flutter/material.dart';

const Color kStatusPaid    = Color(0xFF00B894);
const Color kStatusPending = Color(0xFFFFB800);
const Color kStatusOverdue = Color(0xFFFF6B6B);

Color statusColor(String status) {
  switch (status) {
    case 'Paid':
      return kStatusPaid;
    case 'Overdue':
      return kStatusOverdue;
    case 'Pending':
    default:
      return kStatusPending;
  }
}

IconData statusIcon(String status) {
  switch (status) {
    case 'Paid':
      return Icons.check_circle_rounded;
    case 'Overdue':
      return Icons.warning_rounded;
    case 'Pending':
    default:
      return Icons.schedule_rounded;
  }
}