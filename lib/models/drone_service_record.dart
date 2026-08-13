// lib/models/drone_service_record.dart
//
// Firestore-backed model for the "Drone Services" module (service &
// maintenance bookings — distinct from the Drone In/Out flight-log module).
//
// Firestore structure:
//   drone_services/                 ← collection
//     {serviceId}/                  ← document

import 'package:cloud_firestore/cloud_firestore.dart';

class DroneServiceRecord {
  /// Firestore document ID (empty string for new, unsaved records).
  final String id;

  final String droneName;      // e.g. "Alpha-01" or a free-text asset name
  final String? droneId;       // linked drones/{id} document, if picked from fleet
  final String serviceType;    // e.g. "Battery Service"
  final String branch;         // raw value: 'Branch 1' (CDA Admin) / 'Branch 2' (CDA Ops)
  final String status;         // 'Scheduled' | 'In Progress' | 'Completed' | 'Cancelled'
  final String priority;       // 'Low' | 'Normal' | 'High' | 'Urgent'
  final DateTime scheduledAt;
  final DateTime? completedAt;
  final String technician;
  final String? notes;
  final double? cost;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  // ── Drone In/Out tracking ────────────────────────────────────────────
  // When the drone/asset physically arrived at the service center (In)
  // and when it was handed back (Out). Independent of `status` — a
  // service can be "Scheduled" and still not checked in yet, or
  // "Completed" but not yet physically handed back.
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;

  const DroneServiceRecord({
    required this.id,
    required this.droneName,
    this.droneId,
    required this.serviceType,
    required this.branch,
    required this.status,
    this.priority = 'Normal',
    required this.scheduledAt,
    this.completedAt,
    required this.technician,
    this.notes,
    this.cost,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.checkedInAt,
    this.checkedOutAt,
  });

  // ── Firestore → Dart ───────────────────────────────────────────────────

  factory DroneServiceRecord.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    return DroneServiceRecord.fromMap(doc.id, doc.data() ?? {});
  }

  factory DroneServiceRecord.fromMap(String id, Map<String, dynamic> j) {
    return DroneServiceRecord(
      id: id,
      droneName: j['drone_name']?.toString() ?? '',
      droneId: j['drone_id']?.toString(),
      serviceType: j['service_type']?.toString() ?? 'Other',
      branch: j['branch']?.toString() ?? '',
      status: j['status']?.toString() ?? 'Scheduled',
      priority: j['priority']?.toString() ?? 'Normal',
      scheduledAt: j['scheduled_at'] is Timestamp
          ? (j['scheduled_at'] as Timestamp).toDate()
          : DateTime.now(),
      completedAt: j['completed_at'] is Timestamp
          ? (j['completed_at'] as Timestamp).toDate()
          : null,
      technician: j['technician']?.toString() ?? '',
      notes: j['notes']?.toString(),
      cost: (j['cost'] as num?)?.toDouble(),
      createdAt: j['created_at'] is Timestamp
          ? (j['created_at'] as Timestamp).toDate()
          : null,
      updatedAt: j['updated_at'] is Timestamp
          ? (j['updated_at'] as Timestamp).toDate()
          : null,
      createdBy: j['created_by']?.toString(),
      checkedInAt: j['checked_in_at'] is Timestamp
          ? (j['checked_in_at'] as Timestamp).toDate()
          : null,
      checkedOutAt: j['checked_out_at'] is Timestamp
          ? (j['checked_out_at'] as Timestamp).toDate()
          : null,
    );
  }

  // ── Dart → Firestore ────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
    'drone_name': droneName,
    'drone_id': droneId,
    'service_type': serviceType,
    'branch': branch,
    'status': status,
    'priority': priority,
    'scheduled_at': Timestamp.fromDate(scheduledAt),
    'completed_at': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    'technician': technician,
    'notes': notes,
    'cost': cost,
    'updated_at': FieldValue.serverTimestamp(),
    'created_by': createdBy,
    'checked_in_at': checkedInAt != null ? Timestamp.fromDate(checkedInAt!) : null,
    'checked_out_at': checkedOutAt != null ? Timestamp.fromDate(checkedOutAt!) : null,
  };

  DroneServiceRecord copyWith({
    String? id,
    String? droneName,
    String? droneId,
    String? serviceType,
    String? branch,
    String? status,
    String? priority,
    DateTime? scheduledAt,
    DateTime? completedAt,
    String? technician,
    String? notes,
    double? cost,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    DateTime? checkedInAt,
    DateTime? checkedOutAt,
    bool clearCheckedInAt = false,
    bool clearCheckedOutAt = false,
  }) =>
      DroneServiceRecord(
        id: id ?? this.id,
        droneName: droneName ?? this.droneName,
        droneId: droneId ?? this.droneId,
        serviceType: serviceType ?? this.serviceType,
        branch: branch ?? this.branch,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        completedAt: completedAt ?? this.completedAt,
        technician: technician ?? this.technician,
        notes: notes ?? this.notes,
        cost: cost ?? this.cost,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        createdBy: createdBy ?? this.createdBy,
        checkedInAt: clearCheckedInAt ? null : (checkedInAt ?? this.checkedInAt),
        checkedOutAt: clearCheckedOutAt ? null : (checkedOutAt ?? this.checkedOutAt),
      );

  bool get isOverdue =>
      status == 'Scheduled' && scheduledAt.isBefore(DateTime.now());

  // ── Drone In/Out status helpers ─────────────────────────────────────
  /// 'Not Checked In' | 'Checked In' | 'Checked Out'
  String get inOutStatus {
    if (checkedOutAt != null) return 'Checked Out';
    if (checkedInAt != null) return 'Checked In';
    return 'Not Checked In';
  }

  bool get isCheckedIn => checkedInAt != null && checkedOutAt == null;
  bool get isCheckedOut => checkedOutAt != null;
  bool get canCheckIn => checkedInAt == null;
  bool get canCheckOut => checkedInAt != null && checkedOutAt == null;
}