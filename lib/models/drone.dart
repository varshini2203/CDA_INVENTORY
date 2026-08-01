// lib/models/drone.dart
//
// Firestore version — uses String document IDs instead of int IDs.
// All Firestore-specific factory constructors live here so the UI
// and service layers stay clean.

import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DRONE
// ─────────────────────────────────────────────────────────────────────────────

class Drone {
  /// Firestore document ID (empty string for new, unsaved drones).
  final String id;

  String name;
  final String model;
  final String serialNumber;
  String status; // 'IN' | 'OUT'
  String? pilotName; // also doubles as "used by" — last person to toggle IN/OUT
  final String? category;
  final int batteryLevel;
  final double flightHours;
  final String? notes;
  final DateTime? maintenanceDue;
  final DateTime? lastUpdated;
  final String? branch; // raw value: 'Branch 1' (CDA Admin) or 'Branch 2' (CDA Ops)
  final String? purpose; // why the drone was taken OUT: Training/Testing/Service/Expo/Workshop/...
  final DateTime? checkedOutAt; // when status last became 'OUT' — used for the 4-hour overdue reminder
  final bool reminderAcknowledged; // true once someone has seen/dismissed the overdue reminder for this OUT session

  Drone({
    required this.id,
    required this.name,
    required this.model,
    required this.serialNumber,
    required this.status,
    this.pilotName,
    this.category,
    this.batteryLevel = 100,
    this.flightHours = 0,
    this.notes,
    this.maintenanceDue,
    this.lastUpdated,
    this.branch,
    this.purpose,
    this.checkedOutAt,
    this.reminderAcknowledged = false,
  });

  // ── Normalization helpers ───────────────────────────────────────────────
  // Firestore data (especially seeded/imported data) doesn't always use the
  // exact canonical strings the rest of the app filters on. Rather than
  // requiring every writer to get the raw value byte-for-byte right, we
  // normalize on the way IN here — once, in one place — so the branch/status
  // filter chips (drone_in_out_screen.dart) always match regardless of how
  // the document was written.

  /// Canonicalizes any branch label variant to exactly 'Branch 1' or
  /// 'Branch 2' — the only two raw values kBranchOptions
  /// (constants/drone_categories.dart) and the branch filter chips compare
  /// against. Handles: the canonical values themselves, the CDA Admin/CDA
  /// Ops display labels, and free-text spreadsheet locations like
  /// "BRANCH 1 - ADAMBAKKAM" or "CDA Ops - Storage Facility". Unrecognized
  /// non-empty values are preserved as-is rather than discarded, and empty
  /// values stay null.
  static String? _normalizeBranch(dynamic raw) {
    final v = raw?.toString().trim() ?? '';
    if (v.isEmpty) return null;
    final lower = v.toLowerCase();
    if (lower == 'branch 1' ||
        lower.startsWith('branch 1 ') ||
        lower.startsWith('branch 1-') ||
        lower.contains('admin')) {
      return 'Branch 1';
    }
    if (lower == 'branch 2' ||
        lower.startsWith('branch 2 ') ||
        lower.startsWith('branch 2-') ||
        lower.contains('ops')) {
      return 'Branch 2';
    }
    return v; // unrecognized label — keep it visible rather than dropping it
  }

  /// Canonicalizes any status label variant to exactly 'IN' or 'OUT' — the
  /// only two values compared against by the status filter chips, IN/OUT
  /// counters, and the toggle button. Handles case differences and common
  /// synonyms like "In Stock" / "Checked Out". Defaults to 'IN' for
  /// anything else (including 'Retired', empty, or unrecognized values),
  /// matching this factory's pre-existing fallback behavior.
  static String _normalizeStatus(dynamic raw) {
    final v = raw?.toString().trim().toUpperCase() ?? '';
    if (v == 'OUT' || v == 'CHECKED OUT' || v == 'CHECKED_OUT') return 'OUT';
    return 'IN';
  }

  // ── Firestore → Dart ───────────────────────────────────────────────────────

  factory Drone.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Drone.fromMap(doc.id, doc.data() ?? {});
  }

  /// Same field mapping as [fromFirestore], but works off a plain map the
  /// caller already has in memory (e.g. a doc read moments earlier merged
  /// with the fields it just wrote) instead of requiring a fresh Firestore
  /// read just to see what was just sent.
  factory Drone.fromMap(String id, Map<String, dynamic> j) {
    return Drone(
      id: id,
      name: j['name']?.toString() ?? '',
      model: j['model']?.toString() ?? '',
      serialNumber: j['serial_number']?.toString() ?? '',
      status: _normalizeStatus(j['status']),
      pilotName: j['pilot_name']?.toString(),
      category: j['category']?.toString(),
      batteryLevel: (j['battery_level'] as num?)?.toInt() ?? 100,
      flightHours: (j['flight_hours'] as num?)?.toDouble() ?? 0.0,
      notes: j['notes']?.toString(),
      maintenanceDue: j['maintenance_due'] is Timestamp
          ? (j['maintenance_due'] as Timestamp).toDate()
          : null,
      lastUpdated: j['last_updated'] is Timestamp
          ? (j['last_updated'] as Timestamp).toDate()
          : null,
      branch: _normalizeBranch(j['branch']),
      purpose: j['purpose']?.toString(),
      checkedOutAt: j['checked_out_at'] is Timestamp
          ? (j['checked_out_at'] as Timestamp).toDate()
          : null,
      reminderAcknowledged: j['reminder_acknowledged'] as bool? ?? false,
    );
  }

  // ── Dart → Firestore ───────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'model': model,
    'serial_number': serialNumber,
    'status': status,
    'pilot_name': pilotName,
    'category': category,
    'battery_level': batteryLevel,
    'flight_hours': flightHours,
    'notes': notes,
    'maintenance_due': maintenanceDue != null
        ? Timestamp.fromDate(maintenanceDue!)
        : null,
    'last_updated': FieldValue.serverTimestamp(),
    'branch': branch,
    'purpose': purpose,
    'checked_out_at': checkedOutAt != null
        ? Timestamp.fromDate(checkedOutAt!)
        : null,
    'reminder_acknowledged': reminderAcknowledged,
  };

  // ── copyWith helper ────────────────────────────────────────────────────────

  Drone copyWith({
    String? id,
    String? name,
    String? model,
    String? serialNumber,
    String? status,
    String? pilotName,
    String? category,
    int? batteryLevel,
    double? flightHours,
    String? notes,
    DateTime? maintenanceDue,
    DateTime? lastUpdated,
    String? branch,
    String? purpose,
    DateTime? checkedOutAt,
    bool? reminderAcknowledged,
  }) =>
      Drone(
        id: id ?? this.id,
        name: name ?? this.name,
        model: model ?? this.model,
        serialNumber: serialNumber ?? this.serialNumber,
        status: status ?? this.status,
        pilotName: pilotName ?? this.pilotName,
        category: category ?? this.category,
        batteryLevel: batteryLevel ?? this.batteryLevel,
        flightHours: flightHours ?? this.flightHours,
        notes: notes ?? this.notes,
        maintenanceDue: maintenanceDue ?? this.maintenanceDue,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        branch: branch ?? this.branch,
        purpose: purpose ?? this.purpose,
        checkedOutAt: checkedOutAt ?? this.checkedOutAt,
        reminderAcknowledged: reminderAcknowledged ?? this.reminderAcknowledged,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// DRONE HISTORY
// Stored as a sub-collection:  drones/{droneId}/history/{historyId}
// ─────────────────────────────────────────────────────────────────────────────

class DroneHistory {
  final String id;
  final String droneId;
  final String pilot;
  final String status; // 'IN' | 'OUT'
  final String? notes;
  final String? purpose;
  final DateTime? timestamp;

  const DroneHistory({
    required this.id,
    required this.droneId,
    required this.pilot,
    required this.status,
    this.notes,
    this.purpose,
    this.timestamp,
  });

  /// Human-readable time string (matches the old REST `time` field).
  String get time {
    if (timestamp == null) return '';
    final dt = timestamp!.toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
    return '$d $h:$m';
  }

  factory DroneHistory.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc, String droneId) {
    final j = doc.data() ?? {};
    return DroneHistory(
      id: doc.id,
      droneId: droneId,
      pilot: j['pilot']?.toString() ?? 'Unknown',
      status: j['status']?.toString() ?? '',
      notes: j['notes']?.toString(),
      purpose: j['purpose']?.toString(),
      timestamp: (j['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'drone_id': droneId,
    'pilot': pilot,
    'status': status,
    'notes': notes,
    'purpose': purpose,
    'timestamp': FieldValue.serverTimestamp(),
  };
}