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

  // ── Customer details ────────────────────────────────────────────────────
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  // Free-text description of the reported issue, typed in by whoever is
  // booking the service (distinct from `serviceType`, which is the fixed
  // dropdown category).
  final String? issueDescription;

  // ── Drone-in / drone-out tracking ──────────────────────────────────────
  // Distinct from `scheduledAt`/`completedAt` (which are the booking's
  // planned/finished timestamps): these capture the physical hand-over —
  // exactly when the drone arrived at the shop for this service, who
  // received it, exactly when it was handed back, and who released it.
  final DateTime? checkedInAt;
  final String? checkedInBy;
  final DateTime? checkedOutAt;
  final String? checkedOutBy;

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
    this.checkedInBy,
    this.checkedOutAt,
    this.checkedOutBy,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.issueDescription,
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
      checkedInBy: j['checked_in_by']?.toString(),
      checkedOutAt: j['checked_out_at'] is Timestamp
          ? (j['checked_out_at'] as Timestamp).toDate()
          : null,
      checkedOutBy: j['checked_out_by']?.toString(),
      customerName: j['customer_name']?.toString(),
      customerPhone: j['customer_phone']?.toString(),
      customerAddress: j['customer_address']?.toString(),
      issueDescription: j['issue_description']?.toString(),
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
    'checked_in_by': checkedInBy,
    'checked_out_at': checkedOutAt != null ? Timestamp.fromDate(checkedOutAt!) : null,
    'checked_out_by': checkedOutBy,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'customer_address': customerAddress,
    'issue_description': issueDescription,
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
    String? checkedInBy,
    DateTime? checkedOutAt,
    String? checkedOutBy,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? issueDescription,
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
        checkedInBy: clearCheckedInAt ? null : (checkedInBy ?? this.checkedInBy),
        checkedOutAt: clearCheckedOutAt ? null : (checkedOutAt ?? this.checkedOutAt),
        checkedOutBy: clearCheckedOutAt ? null : (checkedOutBy ?? this.checkedOutBy),
        customerName: customerName ?? this.customerName,
        customerPhone: customerPhone ?? this.customerPhone,
        customerAddress: customerAddress ?? this.customerAddress,
        issueDescription: issueDescription ?? this.issueDescription,
      );

  bool get isOverdue =>
      status == 'Scheduled' && scheduledAt.isBefore(DateTime.now());

  /// True when the booking is still open (Scheduled / In Progress) but its
  /// scheduled date & time has already passed — drives the overdue alert.
  bool get isPastSchedule =>
      (status == 'Scheduled' || status == 'In Progress') &&
          scheduledAt.isBefore(DateTime.now());

  /// How far past the scheduled date the booking is (zero if not overdue).
  Duration get overdueBy =>
      isPastSchedule ? DateTime.now().difference(scheduledAt) : Duration.zero;

  /// True once the drone has physically arrived for this service and has
  /// not yet been handed back out.
  bool get isDroneCheckedIn => checkedInAt != null && checkedOutAt == null;

  /// True once the drone has both arrived and been handed back out.
  bool get isDroneCheckedOut => checkedInAt != null && checkedOutAt != null;

  /// How long the drone stayed in the shop for this service, once both
  /// timestamps are known.
  Duration? get turnaroundDuration =>
      (checkedInAt != null && checkedOutAt != null)
          ? checkedOutAt!.difference(checkedInAt!)
          : null;
}