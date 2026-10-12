// lib/constants/new_product_categories.dart

import 'package:flutter/material.dart';
import 'package:cda_inventory/models/new_product.dart';

/// Icon / colour / normalisation helpers for the New Products category
/// chips (same look as the Inventory dashboard category chips).
class NewProductCategories {
  NewProductCategories._();

  static const String all = 'All';
  static const String other = 'Other';

  static const Map<String, IconData> icons = {
    'All': Icons.apps_rounded,
    'Accessories': Icons.cases_rounded,
    'Action Camera': Icons.videocam,
    'Battery': Icons.battery_charging_full,
    'Drone Accessories': Icons.build_circle,
    'Electronics': Icons.memory,
    'Frames': Icons.architecture,
    'Goggles': Icons.visibility,
    'Motors': Icons.settings,
    'Propeller': Icons.toys,
    'R.T.F Drones': Icons.flight,
    'Remote Controller': Icons.sports_esports,
    'Video Transmitter & Cameras & Antennas': Icons.settings_input_antenna,
    'Other': Icons.category,
  };

  static const Map<String, Color> colors = {
    'All': Color(0xFF1565C0),
    'Accessories': Color(0xFF6A1B9A),
    'Action Camera': Color(0xFFC62828),
    'Battery': Color(0xFF558B2F),
    'Drone Accessories': Color(0xFF4E342E),
    'Electronics': Color(0xFFE65100),
    'Frames': Color(0xFF37474F),
    'Goggles': Color(0xFF4527A0),
    'Motors': Color(0xFF00838F),
    'Propeller': Color(0xFF2E7D32),
    'R.T.F Drones': Color(0xFF1565C0),
    'Remote Controller': Color(0xFF00695C),
    'Video Transmitter & Cameras & Antennas': Color(0xFF283593),
    'Other': Color(0xFF757575),
  };

  // Old category names (previous list + 'General') -> current category.
  // Keys are lower-case. Keeps already-saved products visible under the
  // right chip without touching Firestore.
  static const Map<String, String> _legacy = {
    'general': 'Other',
    'motors & escs': 'Motors',
    'flight controllers': 'Electronics',
    'batteries': 'Battery',
    'cameras & fpv': 'Video Transmitter & Cameras & Antennas',
    'radios & receivers': 'Remote Controller',
    'propellers': 'Propeller',
    'tools & accessories': 'Accessories',
    'complete drone / kit': 'R.T.F Drones',
    'rtf drones': 'R.T.F Drones',
    'rtf drone': 'R.T.F Drones',
  };

  /// Maps any stored / imported category string to one of
  /// [NewProductOptions.categories]. Case and spacing are ignored;
  /// anything unknown becomes 'Other'.
  static String normalize(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return other;
    for (final c in NewProductOptions.categories) {
      if (c.toLowerCase() == v) return c;
    }
    return _legacy[v] ?? other;
  }

  static Color colorOf(String cat) => colors[cat] ?? const Color(0xFF00D4AA);
  static IconData iconOf(String cat) => icons[cat] ?? Icons.category;
}
