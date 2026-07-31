// =============================================================================
// lib/data/seed_drones.dart
//
// Seed data for the `drones` Firestore collection, extracted exclusively from:
//   - cda_admin.xlsx (Sheet1 — Branch 1, Adambakkam)
//   - cda_ops.xlsx   (Sheet1 / STORAGE FACILITY / RPTO / Navin Kit sections)
//
// Only records representing complete drone units were kept. The following
// categories were explicitly EXCLUDED during extraction, even when the
// original row mentioned "drone" (e.g. "3A UBEC FOR DRONE"):
//   - Batteries (e.g. "3S DRONE LIION BATTERY", "LIION 2S DRONE BATTERY")
//   - Chargers (e.g. "HIGH CAPACITY DRONE CHARGING POWERBANK PACK")
//   - Controllers / flight controllers (e.g. "PIXHAWK 2.4.8 FC DRONE",
//     "NEWBEE DRONE BEE BRAIN BLV5 AIO", "MASTER/SLAVE CONTROLLER")
//   - Propellers (e.g. "TC DRONE PROPELLER-2 SET")
//   - Cameras / gimbals (e.g. "OSMO DJI GIMBAL")
//   - Frames / spare parts (e.g. "RACING DRONE FRAME", "DRONE ARMS",
//     "CARBON FIBRE RACING DRONE QUAD FRAME", "DAMAGED FLYFISH DRONE FRAME")
//   - Tools, consumables, documents, and handbooks (e.g. "CDA DRONE
//     INSURANCE FILE", "DRONE PILOT HANDBOOK", "DYNAMICS OF DRONE FOAM BOARD")
//
// Duplicate detection key (best available unique identifier), in order of
// preference:
//   1. serialNumber (exact match)
//   2. name + model (case-insensitive, trimmed)
//   3. name + branch (case-insensitive, trimmed) as a final fallback
//
// Fields not present anywhere in the source spreadsheets (purchaseDate,
// cost, supplier, and in most cases serialNumber/brand/model) are kept as
// `null` rather than fabricated, per the no-sample-data requirement.
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

/// Raw seed data for drones, combined and de-duplicated from
/// `cda_admin.xlsx` and `cda_ops.xlsx`.
const List<Map<String, dynamic>> seedDroneData = [
  {
    "name": "Old Drones",
    "model": null,
    "brand": null,
    "serialNumber": null,
    "category": "Legacy Drone",
    "branch": "BRANCH 1 - ADAMBAKKAM",
    "quantity": 2,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "Retired",
    "description": "Old drone units stored in Admin Room, no longer in active service.",
    "sourceFile": "cda_admin.xlsx",
    "sourceSheet": "Sheet1",
  },
  {
    "name": "Meteor Drone (Old)",
    "model": "Meteor",
    "brand": null,
    "serialNumber": null,
    "category": "Legacy Drone",
    "branch": "BRANCH 1 - ADAMBAKKAM",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "Retired",
    "description": "Legacy Meteor drone stored in Admin Room.",
    "sourceFile": "cda_admin.xlsx",
    "sourceSheet": "Sheet1",
  },
  {
    "name": "Yellow Toy Drone",
    "model": null,
    "brand": null,
    "serialNumber": null,
    "category": "Toy Drone",
    "branch": "BRANCH 1 - ADAMBAKKAM",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "Yellow toy drone stored in Admin Room.",
    "sourceFile": "cda_admin.xlsx",
    "sourceSheet": "Sheet1",
  },
  {
    "name": "Phantom Drone",
    "model": "Phantom",
    "brand": "DJI",
    "serialNumber": null,
    "category": "Commercial Drone",
    "branch": "BRANCH 1 - ADAMBAKKAM",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "DJI Phantom drone stored in the Training Room.",
    "sourceFile": "cda_admin.xlsx",
    "sourceSheet": "Sheet1",
  },
  {
    "name": "Autel Robotics Drone Kit (EVO II Series)",
    "model": "EVO II Series",
    "brand": "Autel Robotics",
    "serialNumber": null,
    "category": "Commercial Drone Kit",
    "branch": "BRANCH 1 - ADAMBAKKAM",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": "Autel Robotics",
    "status": "In Stock",
    "description": "Autel Robotics EVO II series drone kit stored at the Charging Station.",
    "sourceFile": "cda_admin.xlsx",
    "sourceSheet": "Sheet1",
  },
  {
    "name": "DXP S6 Pro Drone with Kit",
    "model": "S6 Pro",
    "brand": "DXP",
    "serialNumber": null,
    "category": "Commercial Drone Kit",
    "branch": "BRANCH 1 - ADAMBAKKAM",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "DXP S6 Pro drone with full kit stored at the Charging Station.",
    "sourceFile": "cda_admin.xlsx",
    "sourceSheet": "Sheet1",
  },
  {
    "name": "Hrethik Drone Kit (with Shoulder Bag)",
    "model": null,
    "brand": null,
    "serialNumber": null,
    "category": "Drone Kit",
    "branch": "BRANCH 1 - ADAMBAKKAM",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "Hrethik-branded drone kit with carrying shoulder bag, stored at the Charging Station.",
    "sourceFile": "cda_admin.xlsx",
    "sourceSheet": "Sheet1",
  },
  {
    "name": "Mark 5 X-Frame (Green)",
    "model": "Mark 5",
    "brand": null,
    "serialNumber": null,
    "category": "FPV Racing Drone",
    "branch": "CDA Ops - Main Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "Green Mark 5 X-frame FPV racing drone.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (FPV Drones)",
  },
  {
    "name": "Cinelog 35 V2 (O3)",
    "model": "Cinelog 35 V2 O3",
    "brand": "iFlight",
    "serialNumber": null,
    "category": "FPV Cinematic Drone",
    "branch": "CDA Ops - Main Facility",
    "quantity": 2,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "iFlight Cinelog 35 V2 cinewhoop drone with DJI O3 air unit.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (FPV Drones)",
  },
  {
    "name": "SpeedyBee X-Frame",
    "model": null,
    "brand": "SpeedyBee",
    "serialNumber": null,
    "category": "FPV Racing Drone",
    "branch": "CDA Ops - Main Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "SpeedyBee X-frame FPV racing drone.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (FPV Drones)",
  },
  {
    "name": "5 Inch Race Drone",
    "model": null,
    "brand": null,
    "serialNumber": null,
    "category": "FPV Racing Drone",
    "branch": "CDA Ops - Main Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "5 inch class FPV race drone.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (FPV Drones)",
  },
  {
    "name": "Pavo O4 Lite",
    "model": "Pavo O4 Lite",
    "brand": "BetaFPV",
    "serialNumber": null,
    "category": "FPV Whoop Drone",
    "branch": "CDA Ops - Main Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "BetaFPV Pavo O4 Lite whoop-style FPV drone.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (FPV Drones)",
  },
  {
    "name": "CDA 3 Inch Analog Drone",
    "model": null,
    "brand": null,
    "serialNumber": null,
    "category": "FPV Analog Drone",
    "branch": "CDA Ops - Main Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "CDA in-house built 3 inch analog FPV drone.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (FPV Drones)",
  },
  {
    "name": "Seeker 5",
    "model": "Seeker 5",
    "brand": null,
    "serialNumber": null,
    "category": "FPV Racing Drone",
    "branch": "CDA Ops - Main Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "Seeker 5 FPV racing drone.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (FPV Drones)",
  },
  {
    "name": "DJI Inspire 2",
    "model": "Inspire 2",
    "brand": "DJI",
    "serialNumber": null,
    "category": "Commercial Drone",
    "branch": "CDA Ops - Main Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "DJI Inspire 2 cinema drone.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (FPV Drones)",
  },
  {
    "name": "DJI Air 3S",
    "model": "Air 3S",
    "brand": "DJI",
    "serialNumber": null,
    "category": "Commercial Drone",
    "branch": "CDA Ops - Main Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "DJI Air 3S consumer drone.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (FPV Drones)",
  },
  {
    "name": "DJI Matrice 4E",
    "model": "Matrice 4E",
    "brand": "DJI",
    "serialNumber": null,
    "category": "Enterprise Drone",
    "branch": "CDA Ops - Main Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "DJI Matrice 4E enterprise drone.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (FPV Drones)",
  },
  {
    "name": "Agriculture Drone",
    "model": null,
    "brand": null,
    "serialNumber": null,
    "category": "Agriculture Drone",
    "branch": "CDA Ops - Main Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "Agricultural spraying drone.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (FPV Drones)",
  },
  {
    "name": "Built Class Drone",
    "model": null,
    "brand": null,
    "serialNumber": null,
    "category": "FPV Custom Build",
    "branch": "CDA Ops - Main Facility",
    "quantity": 2,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "In-house built class FPV drone.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (FPV Drones)",
  },
  {
    "name": "450 Drone",
    "model": "450",
    "brand": null,
    "serialNumber": null,
    "category": "FPV Drone",
    "branch": "CDA Ops - Main Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "450 frame-size FPV drone.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (FPV Drones)",
  },
  {
    "name": "CDA Defense Drone with Thermal Camera",
    "model": null,
    "brand": null,
    "serialNumber": null,
    "category": "Defense / Thermal Drone",
    "branch": "CDA Ops - Main Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "CDA defense-configuration drone fitted with a thermal camera payload.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (FPV Drones)",
  },
  {
    "name": "SpeedyBee Drone",
    "model": null,
    "brand": "SpeedyBee",
    "serialNumber": null,
    "category": "FPV Drone",
    "branch": "CDA Ops - Main Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "SpeedyBee branded FPV drone.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (FPV Drones)",
  },
  {
    "name": "Butterfly Drone",
    "model": null,
    "brand": null,
    "serialNumber": null,
    "category": "Drone",
    "branch": "CDA Ops - Main Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "Butterfly drone stored in the Manager Room.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (Manager Room)",
  },
  {
    "name": "TC 79 Training Drone",
    "model": null,
    "brand": null,
    "serialNumber": null,
    "category": "RPTO Training Drone",
    "branch": "CDA Ops - RPTO",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "Drone belonging to Training Craft set TC-79 (crystal ball), used with a master/slave controller pair for RPTO training.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (RPTO)",
  },
  {
    "name": "TC 80 Training Drone",
    "model": null,
    "brand": null,
    "serialNumber": null,
    "category": "RPTO Training Drone",
    "branch": "CDA Ops - RPTO",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "Drone belonging to Training Craft set TC-80 (crystal ball), used with a master/slave controller pair for RPTO training.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (RPTO)",
  },
  {
    "name": "TC 82 (MGR) Training Drone",
    "model": null,
    "brand": null,
    "serialNumber": null,
    "category": "RPTO Training Drone",
    "branch": "CDA Ops - RPTO",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "Drone belonging to Training Craft set TC-82 (MGR), used with a master/slave controller pair for RPTO training.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (RPTO)",
  },
  {
    "name": "TC 83 (MGR) Training Drone",
    "model": null,
    "brand": null,
    "serialNumber": null,
    "category": "RPTO Training Drone",
    "branch": "CDA Ops - RPTO",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "Drone belonging to Training Craft set TC-83 (MGR), used with a master/slave controller pair for RPTO training.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (RPTO)",
  },
  {
    "name": "Cinelog 35 V2 (Navin Kit)",
    "model": "Cinelog 35 V2",
    "brand": "iFlight",
    "serialNumber": null,
    "category": "FPV Cinematic Drone",
    "branch": "CDA Ops - Main Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "iFlight Cinelog 35 V2 assigned as part of Navin's personal kit.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (Navin Kit)",
  },
  {
    "name": "Cinelog 25 V2 (Navin Kit)",
    "model": "Cinelog 25 V2",
    "brand": "iFlight",
    "serialNumber": null,
    "category": "FPV Cinematic Drone",
    "branch": "CDA Ops - Main Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "iFlight Cinelog 25 V2 assigned as part of Navin's personal kit.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "Sheet1 (Navin Kit)",
  },
  {
    "name": "CDA Defence Drone",
    "model": null,
    "brand": null,
    "serialNumber": null,
    "category": "Defense Drone",
    "branch": "CDA Ops - Storage Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "CDA defence-configuration drone stored in the Storage Facility (Row 5).",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "STORAGE FACILITY",
  },
  {
    "name": "CDA SpeedyBee Drone Box",
    "model": null,
    "brand": "SpeedyBee",
    "serialNumber": null,
    "category": "FPV Drone",
    "branch": "CDA Ops - Storage Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "Boxed SpeedyBee drone stored in the Storage Facility (Row 5).",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "STORAGE FACILITY",
  },
  {
    "name": "Guru Mugilan Drone and Products Bundle",
    "model": null,
    "brand": null,
    "serialNumber": null,
    "category": "Drone Bundle",
    "branch": "CDA Ops - Storage Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "Bundle containing a drone box, Radiomaster Pocket radio, HOTA D6 Pro charger, and DogCom LiPo 6S battery.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "STORAGE FACILITY",
  },
  {
    "name": "Pavo and Pico Drones",
    "model": "Pavo / Pico",
    "brand": "BetaFPV",
    "serialNumber": null,
    "category": "FPV Whoop Drone",
    "branch": "CDA Ops - Storage Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "BetaFPV Pavo and Pico series whoop drones, stored together in the Storage Facility (Row 5).",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "STORAGE FACILITY",
  },
  {
    "name": "450 Assorted Drone Box",
    "model": "450",
    "brand": null,
    "serialNumber": null,
    "category": "FPV Drone",
    "branch": "CDA Ops - Storage Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "Assorted 450 frame-size drone box stored in the Storage Facility (Row 5).",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "STORAGE FACILITY",
  },
  {
    "name": "Assorted Drone (CDA)",
    "model": null,
    "brand": null,
    "serialNumber": null,
    "category": "Assorted Drone",
    "branch": "CDA Ops - Storage Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "Assorted CDA-owned drone stored in the Storage Facility (Row 5).",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "STORAGE FACILITY",
  },
  {
    "name": "UB202502480TC Drone",
    "model": "TC Drone",
    "brand": null,
    "serialNumber": "UB202502480TC",
    "category": "Training Craft Drone",
    "branch": "CDA Ops - Storage Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "Serial-tagged training craft drone stored in Row -8 (80-TC) of the Storage Facility.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "STORAGE FACILITY",
  },
  {
    "name": "UB202502479TC Drone",
    "model": "TC Drone",
    "brand": null,
    "serialNumber": "UB202502479TC",
    "category": "Training Craft Drone",
    "branch": "CDA Ops - Storage Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "Checked Out",
    "description": "Serial-tagged training craft drone from Row -7 (79-TC) of the Storage Facility; currently checked out.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "STORAGE FACILITY",
  },
  {
    "name": "UB202605382TC Drone",
    "model": "TC Drone",
    "brand": null,
    "serialNumber": "UB202605382TC",
    "category": "Training Craft Drone",
    "branch": "CDA Ops - Storage Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "Serial-tagged training craft drone stored in Row 3 of the Storage Facility.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "STORAGE FACILITY",
  },
  {
    "name": "UB202605383TC Drone",
    "model": "TC Drone",
    "brand": null,
    "serialNumber": "UB202605383TC",
    "category": "Training Craft Drone",
    "branch": "CDA Ops - Storage Facility",
    "quantity": 1,
    "purchaseDate": null,
    "cost": null,
    "supplier": null,
    "status": "In Stock",
    "description": "Serial-tagged training craft drone stored in Row 3 of the Storage Facility.",
    "sourceFile": "cda_ops.xlsx",
    "sourceSheet": "STORAGE FACILITY",
  },
];
/// Builds a normalized, trimmed, lowercase string used purely for
/// case-insensitive duplicate comparisons. Returns an empty string for
/// null/blank input so comparisons never throw.
String _normalize(dynamic value) {
  if (value == null) return '';
  return value.toString().trim().toLowerCase();
}

/// Determines whether [existingData] (an already-seeded Firestore document's
/// data) represents the same physical drone as [candidate] (an entry from
/// [seedDroneData]).
///
/// Matching strategy (first match wins):
///   1. Both have a non-empty serialNumber and they match exactly
///      (case-insensitive).
///   2. Both have a non-empty model and the (name, model) pair matches
///      (case-insensitive).
///   3. Fallback: the (name, branch) pair matches (case-insensitive).
bool _isSameDrone(
    Map<String, dynamic> existingData,
    Map<String, dynamic> candidate,
    ) {
  final existingSerial = _normalize(existingData['serialNumber']);
  final candidateSerial = _normalize(candidate['serialNumber']);
  if (existingSerial.isNotEmpty && existingSerial == candidateSerial) {
    return true;
  }

  final existingName = _normalize(existingData['name']);
  final candidateName = _normalize(candidate['name']);
  final existingModel = _normalize(existingData['model']);
  final candidateModel = _normalize(candidate['model']);
  if (existingModel.isNotEmpty &&
      existingModel == candidateModel &&
      existingName == candidateName) {
    return true;
  }

  final existingBranch = _normalize(existingData['branch']);
  final candidateBranch = _normalize(candidate['branch']);
  return existingName.isNotEmpty &&
      existingName == candidateName &&
      existingBranch == candidateBranch;
}

/// Seeds the `drones` Firestore collection with [seedDroneData], skipping any
/// drone that already exists (matched via [_isSameDrone]) and writing the
/// remainder in batches for efficiency.
///
/// Safe to call multiple times — re-running this function will never create
/// duplicate drone documents.
Future<void> seedDrones(FirebaseFirestore firestore) async {
  final CollectionReference<Map<String, dynamic>> dronesRef =
  firestore.collection('drones');

  // Pull all existing drone documents once, up front, so every candidate can
  // be checked in memory instead of issuing a query per candidate.
  final QuerySnapshot<Map<String, dynamic>> existingSnapshot =
  await dronesRef.get();
  final List<Map<String, dynamic>> existingDrones = existingSnapshot.docs
      .map((doc) => doc.data())
      .toList(growable: false);

  // Firestore batched writes are capped at 500 operations each, so chunk
  // the work into multiple batches if the seed list ever grows past that.
  const int maxOperationsPerBatch = 500;

  WriteBatch batch = firestore.batch();
  int pendingOperations = 0;
  int skippedCount = 0;
  int queuedCount = 0;

  Future<void> commitCurrentBatch() async {
    if (pendingOperations > 0) {
      await batch.commit();
      batch = firestore.batch();
      pendingOperations = 0;
    }
  }

  for (final Map<String, dynamic> drone in seedDroneData) {
    final bool alreadyExists = existingDrones.any(
          (existing) => _isSameDrone(existing, drone),
    );

    if (alreadyExists) {
      skippedCount++;
      continue;
    }

    final DocumentReference<Map<String, dynamic>> newDocRef =
    dronesRef.doc();
    batch.set(newDocRef, {
      ...drone,
      // Track when this record was written so re-seeding runs can be
      // audited later if needed.
      'createdAt': FieldValue.serverTimestamp(),
    });

    pendingOperations++;
    queuedCount++;

    // Also add this newly-queued drone to the in-memory list so that if the
    // seed list itself contains near-duplicates, later entries in the same
    // run are still checked against it.
    existingDrones.add(drone);

    if (pendingOperations >= maxOperationsPerBatch) {
      await commitCurrentBatch();
    }
  }

  // Commit any remaining queued writes that didn't fill a full batch.
  await commitCurrentBatch();

  // ignore: avoid_print
  print(
    'seedDrones: queued $queuedCount new drone(s), '
        'skipped $skippedCount existing duplicate(s), '
        'out of ${seedDroneData.length} total seed record(s).',
  );
}