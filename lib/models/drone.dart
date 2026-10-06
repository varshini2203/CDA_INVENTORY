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
  final String? uin; // Unique Identification Number (DGCA drone registration ID)
  final String? droneClass; // Nano/Micro/Small/Medium/Large — see kDroneClasses
  String status; // 'IN' | 'OUT'
  String? pilotName; // also doubles as "used by" — last person to toggle IN/OUT
  final String? category;
  final String? gps; // GPS module fitted (from the fleet list), null if none recorded
  final String? linkType; // 'Analog' | 'Digital' video link, null if not recorded
  final bool hasMovement; // true once an IN/OUT movement has been recorded — only these show on the Drone IN/OUT dashboard
  final bool inMasterList; // true for drones that belong to the DRONE_LIST fleet
  final List<String> additionalProducts; // accessories that went out with the drone on its last movement
  final String? condition; // 'Good' | 'Damaged' as recorded on the last movement
  final double flightHours;
  final String? notes;
  final DateTime? maintenanceDue;
  final DateTime? lastUpdated;
  final String? branch; // raw value: 'Branch 1' (CDA Admin) or 'Branch 2' (CDA Ops)
  final String? purpose; // why the drone was taken OUT: Training/Testing/Service/Expo/Workshop/...
  final DateTime? checkedOutAt; // when status last became 'OUT' — used for the 4-hour overdue reminder
  final DateTime? checkedInAt; // when status last became 'IN' — kept alongside checkedOutAt purely for display ("In: ... · Out: ...") so both dates stay visible regardless of current status
  final String? addedBy; // auto-filled from login when the drone is registered — never typed
  final String? updatedBy; // auto-filled from login on every edit / IN-OUT action
  final String? tripInId; // id of the IN history entry that closed this record (null while OUT)
  final String? tripId; // id of the OUT history entry that started this record (null for legacy/no-history drones)
  final bool isPastTrip; // true for an older, completed OUT→IN record — frozen, never edited
  final bool reminderAcknowledged; // true once someone has seen/dismissed the overdue reminder for this OUT session

  Drone({
    required this.id,
    required this.name,
    required this.model,
    required this.serialNumber,
    required this.status,
    this.uin,
    this.droneClass,
    this.pilotName,
    this.category,
    this.gps,
    this.linkType,
    this.inMasterList = false,
    this.hasMovement = false,
    this.additionalProducts = const [],
    this.condition,
    this.flightHours = 0,
    this.notes,
    this.maintenanceDue,
    this.lastUpdated,
    this.branch,
    this.purpose,
    this.checkedOutAt,
    this.checkedInAt,
    this.addedBy,
    this.updatedBy,
    this.reminderAcknowledged = false,
    this.tripId,
    this.tripInId,
    this.isPastTrip = false,
  });

  /// A finished OUT→IN record. Once a drone is back IN the record is frozen:
  /// it can't be edited or deleted, and the next OUT starts a NEW record.
  bool get isLockedRecord =>
      isPastTrip ||
          (status == 'IN' && checkedOutAt != null && checkedInAt != null);

  /// UIN / GPS / link type are shown only for the values that exist.
  bool get hasDetails => uin != null || gps != null || linkType != null;

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

  static String? _clean(dynamic raw) {
    final v = raw?.toString().trim() ?? '';
    return v.isEmpty ? null : v;
  }

  /// Canonicalizes the video-link label to exactly 'Analog' or 'Digital'.
  static String? _normalizeLink(dynamic raw) {
    final v = raw?.toString().trim().toLowerCase() ?? '';
    if (v.isEmpty) return null;
    if (v.startsWith('analog')) return 'Analog';
    if (v.startsWith('digital')) return 'Digital';
    return null;
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
      uin: _clean(j['uin']),
      droneClass: j['drone_class']?.toString(),
      status: _normalizeStatus(j['status']),
      pilotName: j['pilot_name']?.toString(),
      category: j['category']?.toString(),
      gps: _clean(j['gps']),
      linkType: _normalizeLink(j['link_type']),
      inMasterList: j['in_master_list'] as bool? ?? false,
      hasMovement: (j['has_movement'] as bool? ?? false) ||
          j['checked_out_at'] is Timestamp ||
          j['checked_in_at'] is Timestamp,
      additionalProducts: (j['additional_products'] is List)
          ? (j['additional_products'] as List)
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList()
          : const [],
      condition: _clean(j['condition']),
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
      checkedInAt: j['checked_in_at'] is Timestamp
          ? (j['checked_in_at'] as Timestamp).toDate()
          : null,
      addedBy: j['added_by']?.toString(),
      updatedBy: j['updated_by']?.toString(),
      reminderAcknowledged: j['reminder_acknowledged'] as bool? ?? false,
    );
  }

  // ── Dart → Firestore ───────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'model': model,
    'serial_number': serialNumber,
    'uin': uin,
    'drone_class': droneClass,
    'status': status,
    'pilot_name': pilotName,
    'category': category,
    'gps': gps,
    'link_type': linkType,
    'in_master_list': inMasterList,
    'has_movement': hasMovement,
    'additional_products': additionalProducts,
    'condition': condition,
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
    'checked_in_at': checkedInAt != null
        ? Timestamp.fromDate(checkedInAt!)
        : null,
    'added_by': addedBy,
    'updated_by': updatedBy,
    'reminder_acknowledged': reminderAcknowledged,
  };

  // ── copyWith helper ────────────────────────────────────────────────────────

  Drone copyWith({
    String? id,
    String? name,
    String? model,
    String? serialNumber,
    String? uin,
    String? droneClass,
    String? status,
    String? pilotName,
    String? category,
    String? gps,
    String? linkType,
    bool? inMasterList,
    bool? hasMovement,
    List<String>? additionalProducts,
    String? condition,
    double? flightHours,
    String? notes,
    DateTime? maintenanceDue,
    DateTime? lastUpdated,
    String? branch,
    String? purpose,
    DateTime? checkedOutAt,
    DateTime? checkedInAt,
    String? addedBy,
    String? updatedBy,
    bool? reminderAcknowledged,
    String? tripId,
    String? tripInId,
    bool? isPastTrip,
    bool clearCheckedInAt = false,
  }) =>
      Drone(
        id: id ?? this.id,
        name: name ?? this.name,
        model: model ?? this.model,
        serialNumber: serialNumber ?? this.serialNumber,
        uin: uin ?? this.uin,
        droneClass: droneClass ?? this.droneClass,
        status: status ?? this.status,
        pilotName: pilotName ?? this.pilotName,
        category: category ?? this.category,
        gps: gps ?? this.gps,
        linkType: linkType ?? this.linkType,
        inMasterList: inMasterList ?? this.inMasterList,
        hasMovement: hasMovement ?? this.hasMovement,
        additionalProducts: additionalProducts ?? this.additionalProducts,
        condition: condition ?? this.condition,
        flightHours: flightHours ?? this.flightHours,
        notes: notes ?? this.notes,
        maintenanceDue: maintenanceDue ?? this.maintenanceDue,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        branch: branch ?? this.branch,
        purpose: purpose ?? this.purpose,
        checkedOutAt: checkedOutAt ?? this.checkedOutAt,
        checkedInAt: clearCheckedInAt ? null : (checkedInAt ?? this.checkedInAt),
        addedBy: addedBy ?? this.addedBy,
        updatedBy: updatedBy ?? this.updatedBy,
        reminderAcknowledged: reminderAcknowledged ?? this.reminderAcknowledged,
        tripId: tripId ?? this.tripId,
        tripInId: tripInId ?? this.tripInId,
        isPastTrip: isPastTrip ?? this.isPastTrip,
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
  final List<String> additionalProducts;
  final String? condition;

  const DroneHistory({
    required this.id,
    required this.droneId,
    required this.pilot,
    required this.status,
    this.notes,
    this.purpose,
    this.timestamp,
    this.additionalProducts = const [],
    this.condition,
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
      additionalProducts: (j['additional_products'] is List)
          ? (j['additional_products'] as List).map((e) => e.toString()).toList()
          : const [],
      condition: j['condition']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'drone_id': droneId,
    'pilot': pilot,
    'status': status,
    'notes': notes,
    'purpose': purpose,
    'additional_products': additionalProducts,
    'condition': condition,
    'timestamp': FieldValue.serverTimestamp(),
  };
}