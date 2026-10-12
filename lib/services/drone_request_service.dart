// lib/services/drone_request_service.dart
//
// "Add New Drone" with ADMIN approval.
//
//  • Any logged-in user can request a new drone from the Drone IN / OUT
//    Entry screen. The request is stored in `drone_requests` as 'pending'.
//  • Until the admin approves it, EVERYONE sees that drone in the list with a
//    RED dot + "PENDING" tag, and it can't be used for IN / OUT yet.
//  • Admin approves  -> a real drone document is created in `drones`
//    (it then shows normally, in its group).
//  • Admin rejects   -> the request is marked rejected and disappears.
//  • If the admin adds a drone themself, it is approved immediately.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cda_inventory/models/drone.dart';
import 'current_user_service.dart';
import 'drone_service.dart';

class DroneRequest {
  final String id;
  final String name;
  final String group;
  final String serialNumber;
  final String requestedBy;
  final String status; // pending | approved | rejected
  final String droneId; // set once approved

  const DroneRequest({
    required this.id,
    required this.name,
    required this.group,
    required this.serialNumber,
    required this.requestedBy,
    required this.status,
    required this.droneId,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';

  factory DroneRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    String s(String k) => (m[k] ?? '').toString();
    return DroneRequest(
      id: d.id,
      name: s('name'),
      group: s('group'),
      serialNumber: s('serialNumber'),
      requestedBy: s('requestedBy'),
      status: s('status').isEmpty ? 'pending' : s('status'),
      droneId: s('droneId'),
    );
  }
}

class DroneRequestService {
  DroneRequestService._();

  static final CollectionReference<Map<String, dynamic>> _col =
  FirebaseFirestore.instance.collection('drone_requests');
  static final CollectionReference<Map<String, dynamic>> _drones =
  FirebaseFirestore.instance.collection('drones');

  static String _key(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Pending + approved requests (rejected ones are hidden).
  static Future<List<DroneRequest>> fetchActive() async {
    final snap = await _col.get();
    return snap.docs
        .map(DroneRequest.fromDoc)
        .where((r) => r.status != 'rejected' && r.status != 'deleted')
        .toList();
  }

  /// True when a pending/approved request already uses this name.
  static Future<bool> nameTaken(String name) async {
    final k = _key(name);
    final all = await fetchActive();
    return all.any((r) => _key(r.name) == k);
  }

  /// Creates the request. [isAdmin] -> approved straight away.
  static Future<void> submit({
    required String name,
    required String group,
    required String serialNumber,
    required bool isAdmin,
  }) async {
    final who = await CurrentUserService.getName();
    final ref = await _col.add({
      'name': name.trim(),
      'group': group,
      'serialNumber': serialNumber.trim(),
      'requestedBy': who,
      'status': 'pending',
      'droneId': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (isAdmin) {
      final doc = await ref.get();
      await approve(DroneRequest.fromDoc(doc));
    }
  }

  /// Admin approval: creates the real drone, then marks the request.
  static Future<void> approve(DroneRequest r) async {
    final approver = await CurrentUserService.getName();
    final drone = Drone(
      id: '',
      name: r.name,
      model: '',
      serialNumber: r.serialNumber,
      status: 'IN',
      category: r.group,
      inMasterList: false,
      hasMovement: false,
      addedBy: r.requestedBy,
    );
    final data = drone.toFirestore()
      ..['created_at'] = FieldValue.serverTimestamp();
    final ref = await _drones.add(data);
    await _col.doc(r.id).update({
      'status': 'approved',
      'droneId': ref.id,
      'approvedBy': approver,
      'approvedAt': FieldValue.serverTimestamp(),
    });
    DroneService.clearCache();
  }

  /// Admin deleted the drone -> its request must not bring it back.
  static Future<void> markDeletedByDroneId(String droneId) async {
    final snap = await _col.where('droneId', isEqualTo: droneId).get();
    for (final d in snap.docs) {
      await d.reference.update({'status': 'deleted'});
    }
  }

  static Future<void> reject(DroneRequest r) async {
    final who = await CurrentUserService.getName();
    await _col.doc(r.id).update({
      'status': 'rejected',
      'rejectedBy': who,
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }
}