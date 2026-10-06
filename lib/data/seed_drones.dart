// lib/data/seed_drones.dart
//
// Fleet master list — taken exactly from DRONE_LIST.xlsx.
// This is the ONLY source of drones for Drone IN / OUT. Drones are picked
// from a dropdown built from these records; nothing is typed by hand.
//
// Fields per drone: group, name, UIN (only if the sheet has one), GPS module
// (only if the sheet has one) and link type Analog / Digital (only if the
// sheet has one). Missing values stay null — nothing is invented.
//
// seedDrones() is safe to run any number of times: it matches existing
// drones by normalised name, refreshes their list details, and never
// touches status, history or IN/OUT times.

import 'package:cloud_firestore/cloud_firestore.dart';

class DroneMasterEntry {
  final String group;
  final String name;
  final String? uin;
  final String? gps;
  final String? linkType; // 'Analog' | 'Digital'
  const DroneMasterEntry({
    required this.group,
    required this.name,
    this.uin,
    this.gps,
    this.linkType,
  });

  String get key => droneNameKey(name);
  String get docId => 'dl_${key.replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
}

/// Case / spacing-insensitive key used to match a master entry to a doc.
String droneNameKey(String? name) =>
    (name ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

/// Group order shown in the dropdown and filter chips.
const List<String> kDroneGroups = [
  'TC Drones',
  'DJI Drones',
  'FPV Drones',
  'Fixed Wings',
];

const List<DroneMasterEntry> kDroneMasterList = [
  DroneMasterEntry(group: 'TC Drones', name: 'MODEL-T UIN-UB202502479TC', uin: 'UIN-UB202502479TC', gps: null, linkType: null),
  DroneMasterEntry(group: 'TC Drones', name: 'MODEL-T UIN-UB202502480TC', uin: 'UIN-UB202502480TC', gps: null, linkType: null),
  DroneMasterEntry(group: 'TC Drones', name: 'DR MGR NAI AGRO DRONE -MK1 UIN UB202605383TC', uin: 'UIN-UB202605383TC', gps: null, linkType: null),
  DroneMasterEntry(group: 'TC Drones', name: 'DR MGR NAI AGRO DRONE -MK1 UIN UB202605382TC', uin: 'UIN-UB202605382TC', gps: null, linkType: null),
  DroneMasterEntry(group: 'DJI Drones', name: 'DJI MATERICE ENTERPRISES 4E', uin: null, gps: null, linkType: null),
  DroneMasterEntry(group: 'DJI Drones', name: 'DJI AIR 3S', uin: null, gps: null, linkType: null),
  DroneMasterEntry(group: 'DJI Drones', name: 'DJI MINI 3', uin: null, gps: null, linkType: null),
  DroneMasterEntry(group: 'DJI Drones', name: 'DJI INSPIRE 2', uin: null, gps: null, linkType: null),
  DroneMasterEntry(group: 'FPV Drones', name: 'FREESTYLE SEEKER 5 (ANALOG) HGLRC M100', uin: null, gps: 'HGLRC M100', linkType: 'Analog'),
  DroneMasterEntry(group: 'FPV Drones', name: 'CINELOG 35 V2 DEEPAK(DIGITAL) M10', uin: null, gps: 'M10', linkType: 'Digital'),
  DroneMasterEntry(group: 'FPV Drones', name: 'CINELOG 35 V2 NAVIN(DIGITAL) M10', uin: null, gps: 'M10', linkType: 'Digital'),
  DroneMasterEntry(group: 'FPV Drones', name: 'CINELOG 25 V2 NAVIN(DIGITAL)FLYWOO MINI GPS', uin: null, gps: 'FLYWOO MINI GPS', linkType: 'Digital'),
  DroneMasterEntry(group: 'FPV Drones', name: 'GEPRC MARK 5 DC GREEN NAGASAI', uin: null, gps: null, linkType: null),
  DroneMasterEntry(group: 'FPV Drones', name: 'GEPRC MARK 5 X GREEN (DIGITAL) M100', uin: null, gps: 'M100', linkType: 'Digital'),
  DroneMasterEntry(group: 'FPV Drones', name: 'SPEEDYBEE MARIO(DIGITAL) M100', uin: null, gps: 'M100', linkType: 'Digital'),
  DroneMasterEntry(group: 'FPV Drones', name: 'SPEEDYBEE BEE35 MOHAN(DIGITAL)', uin: null, gps: null, linkType: 'Digital'),
  DroneMasterEntry(group: 'FPV Drones', name: 'CDA DEFENSE DRONE THERMAL & RGB CAMERA WITH GPS', uin: null, gps: null, linkType: null),
  DroneMasterEntry(group: 'FPV Drones', name: 'CDA DEFENSE DRONE RGB CAMERA', uin: null, gps: null, linkType: null),
  DroneMasterEntry(group: 'Fixed Wings', name: 'TBS CHUPITO O4 CAMERA', uin: null, gps: null, linkType: null),
  DroneMasterEntry(group: 'Fixed Wings', name: 'SKY SUFER', uin: null, gps: null, linkType: null),
  DroneMasterEntry(group: 'Fixed Wings', name: 'FIXED WING CRESENT', uin: null, gps: null, linkType: null),
  DroneMasterEntry(group: 'Fixed Wings', name: 'HUNTER LICO', uin: null, gps: null, linkType: null),
];

/// Writes / refreshes the master list in the `drones` collection.
/// Returns the number of drones newly created.
Future<int> seedDrones(FirebaseFirestore firestore) async {
  final ref = firestore.collection('drones');
  final existing = await ref.get();
  final byKey = <String, DocumentReference<Map<String, dynamic>>>{};
  for (final d in existing.docs) {
    final k = droneNameKey(d.data()['name']?.toString());
    if (k.isNotEmpty) byKey.putIfAbsent(k, () => d.reference);
  }

  WriteBatch batch = firestore.batch();
  var pending = 0;
  var created = 0;

  for (final e in kDroneMasterList) {
    final found = byKey[e.key];
    final details = <String, dynamic>{
      'name': e.name,
      'category': e.group,
      'uin': e.uin,
      'gps': e.gps,
      'link_type': e.linkType,
      'in_master_list': true,
    };
    if (found != null) {
      batch.set(found, details, SetOptions(merge: true));
    } else {
      batch.set(ref.doc(e.docId), {
        ...details,
        'model': '',
        'serial_number': '',
        'status': 'IN',
        'flight_hours': 0,
        'created_at': FieldValue.serverTimestamp(),
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      created++;
    }
    pending++;
    if (pending >= 400) {
      await batch.commit();
      batch = firestore.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
  return created;
}