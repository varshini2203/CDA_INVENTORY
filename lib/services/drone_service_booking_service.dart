// lib/services/drone_service_booking_service.dart
//
// Firestore backend for the "Drone Services" module (service & maintenance
// bookings, shown on the Drone Service Dashboard — list + calendar views,
// filterable by branch: All Branch / CDA Admin / CDA Ops).
//
// Firestore structure:
//   drone_services/                 ← collection
//     {serviceId}/                  ← document

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/drone_service_record.dart';
import 'activity_log_service.dart';

class ApiResult<T> {
  final T? data;
  final String? error;
  bool get success => error == null;

  ApiResult.ok(this.data) : error = null;
  ApiResult.err(this.error) : data = null;
}

class DroneServiceBookingService {
  final FirebaseFirestore _db;

  DroneServiceBookingService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _services =>
      _db.collection('drone_services');

  // ── IN-MEMORY CACHE (mirrors DroneService's pattern) ─────────────────────
  static List<DroneServiceRecord>? _cache;

  static void clearCache() => _cache = null;

  Future<List<DroneServiceRecord>> _fetchAll({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;
    final snapshot =
    await _services.orderBy('scheduled_at', descending: false).get();
    final list = snapshot.docs
        .map((doc) => DroneServiceRecord.fromFirestore(
        doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();
    _cache = list;
    return list;
  }

  // ── GET ALL (with filters) ────────────────────────────────────────────────

  static const String branchAll = 'ALL';
  static const String statusAll = 'ALL';

  Future<ApiResult<List<DroneServiceRecord>>> getServices({
    String? search,
    String? status,
    String? branch,
    DateTime? onDate,
    bool forceRefresh = false,
  }) async {
    try {
      List<DroneServiceRecord> list = await _fetchAll(forceRefresh: forceRefresh);

      if (branch != null && branch.isNotEmpty && branch != branchAll) {
        list = list.where((s) => s.branch == branch).toList();
      }
      if (status != null && status.isNotEmpty && status != statusAll) {
        list = list.where((s) => s.status == status).toList();
      }
      if (onDate != null) {
        list = list.where((s) => _isSameDate(s.scheduledAt, onDate)).toList();
      }
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        list = list.where((s) {
          return s.droneName.toLowerCase().contains(q) ||
              s.serviceType.toLowerCase().contains(q) ||
              s.technician.toLowerCase().contains(q);
        }).toList();
      }
      return ApiResult.ok(list);
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── REAL-TIME STREAM ───────────────────────────────────────────────────────

  Stream<List<DroneServiceRecord>> servicesStream({String? branch}) {
    Query<Map<String, dynamic>> query = _services;
    if (branch != null && branch.isNotEmpty && branch != branchAll) {
      query = query.where('branch', isEqualTo: branch);
    }
    query = query.orderBy('scheduled_at', descending: false);
    return query.snapshots().map((snap) => snap.docs
        .map((doc) => DroneServiceRecord.fromFirestore(
        doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList());
  }

  // ── ADD ─────────────────────────────────────────────────────────────────

  Future<ApiResult<DroneServiceRecord>> addService(
      DroneServiceRecord record) async {
    try {
      final data = record.toFirestore();
      data['created_at'] = FieldValue.serverTimestamp();
      final ref = await _services.add(data);
      final saved = record.copyWith(id: ref.id, createdAt: DateTime.now());
      clearCache();
      ActivityLogService.logAdd(
        module: 'Drone Services',
        itemName: '${record.serviceType} — ${record.droneName}',
        data: {
          'drone': record.droneName,
          'service_type': record.serviceType,
          'branch': record.branch,
          'status': record.status,
          'scheduled_at': record.scheduledAt.toIso8601String(),
          'technician': record.technician,
        },
      );
      return ApiResult.ok(saved);
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  // ── UPDATE (full edit) ─────────────────────────────────────────────────────

  Future<ApiResult<DroneServiceRecord>> updateService(
      DroneServiceRecord before, DroneServiceRecord after) async {
    try {
      await _services.doc(before.id).update(after.toFirestore());
      clearCache();
      ActivityLogService.logEdit(
        module: 'Drone Services',
        itemName: '${after.serviceType} — ${after.droneName}',
        before: {
          'status': before.status,
          'scheduled_at': before.scheduledAt.toIso8601String(),
          'technician': before.technician,
          'priority': before.priority,
        },
        after: {
          'status': after.status,
          'scheduled_at': after.scheduledAt.toIso8601String(),
          'technician': after.technician,
          'priority': after.priority,
        },
      );
      return ApiResult.ok(after);
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  // ── UPDATE STATUS ONLY (quick action: Start / Complete / Cancel) ───────────

  Future<ApiResult<bool>> updateStatus(String id, String status,
      {String? previousStatus, String? itemName}) async {
    try {
      final updates = <String, dynamic>{
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
        if (status == 'Completed') 'completed_at': FieldValue.serverTimestamp(),
      };
      await _services.doc(id).update(updates);
      clearCache();
      ActivityLogService.logEdit(
        module: 'Drone Services',
        itemName: itemName ?? id,
        before: {'status': previousStatus ?? ''},
        after: {'status': status},
      );
      return ApiResult.ok(true);
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  // ── DELETE ──────────────────────────────────────────────────────────────

  Future<ApiResult<bool>> deleteService(DroneServiceRecord record) async {
    try {
      await _services.doc(record.id).delete();
      clearCache();
      ActivityLogService.logDelete(
        module: 'Drone Services',
        itemName: '${record.serviceType} — ${record.droneName}',
        data: {
          'drone': record.droneName,
          'service_type': record.serviceType,
          'branch': record.branch,
          'status': record.status,
        },
      );
      return ApiResult.ok(true);
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  // ── STATS ───────────────────────────────────────────────────────────────

  Future<ApiResult<Map<String, int>>> getStats({String? branch}) async {
    try {
      final all = await _fetchAll();
      final list = (branch == null || branch.isEmpty || branch == branchAll)
          ? all
          : all.where((s) => s.branch == branch).toList();
      return ApiResult.ok({
        'total': list.length,
        'scheduled': list.where((s) => s.status == 'Scheduled').length,
        'in_progress': list.where((s) => s.status == 'In Progress').length,
        'completed': list.where((s) => s.status == 'Completed').length,
        'cancelled': list.where((s) => s.status == 'Cancelled').length,
        'overdue': list.where((s) => s.isOverdue).length,
      });
    } catch (e) {
      return ApiResult.err(_firestoreError(e));
    }
  }

  String _firestoreError(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'Permission denied. Check your Firestore security rules.';
        case 'unavailable':
          return 'Firestore is currently unavailable. Check your internet connection.';
        case 'not-found':
          return 'Document not found.';
        default:
          return 'Firestore error (${e.code}): ${e.message}';
      }
    }
    return 'Error: $e';
  }
}
