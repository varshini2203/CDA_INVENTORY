// lib/data/seed_branch_drones.dart
//
// Curated from the raw branch1.xlsx / branch_2.xlsx inventory sheets.
// Only complete, flyable drone units are included here — frames, flight
// controller boards, propellers, gimbals, and other spares were left out
// on purpose (per Pavithra's call) since they don't belong in a Drone
// In/Out tracker. Two things were also skipped because the sheet didn't
// give them an identifiable model:
//   - Branch 1, Admin Room: "OLD DRONES" (qty 2) — no model name given
//   - Branch 2, RPTO column: "DRONE-1" (appears 4x) — same issue
// Add those two manually once you know what they actually are.
//
// kBranchOptions / kBranchLabels (drone_categories.dart) already map:
//   'Branch 1' -> 'CDA Admin'   'Branch 2' -> 'CDA Ops'
//
// Serial numbers weren't in the sheet, so placeholders are generated as
// CDA-ADM-001, CDA-ADM-002... / CDA-OPS-001, CDA-OPS-002... — replace with
// real serials in the Edit Drone screen once you have them on hand.

class SeedBranchDrones {
  SeedBranchDrones._();

  // ── Branch 1 — CDA Admin ───────────────────────────────────────────────
  static const List<Map<String, dynamic>> adminDrones = [
    {"name": "Meteor Drone (Old)", "model": "Meteor", "category": "Other", "notes": "From: Admin Room — old unit"},
    {"name": "Yellow Toy Drone", "model": "Toy Drone", "category": "Other", "notes": "From: Admin Room"},
    {"name": "BetaFPV Small", "model": "BetaFPV", "category": "Racing", "notes": "From: Admin Room — tiny whoop class"},
    {"name": "Autel Robotics Drone Kit", "model": "Autel EVO Series", "category": "Photography", "notes": "From: Charging Station"},
    {"name": "DXP S6 Pro", "model": "DXP S6 Pro", "category": "Photography", "notes": "From: Charging Station — with kit"},
    {"name": "Hrethik Drone Kit", "model": "Unspecified", "category": "Photography", "notes": "From: Charging Station — with shoulder bag"},
    {"name": "Phantom Drone", "model": "DJI Phantom", "category": "Photography", "notes": "From: Training Room"},
  ];

  // ── Branch 2 — CDA Ops ──────────────────────────────────────────────────
  static const List<Map<String, dynamic>> opsDrones = [
    {"name": "Cinelog 35 V2 O3", "model": "Cinelog 35 V2", "category": "Racing", "notes": "From: FPV Drones — qty 2"},
    {"name": "5 Inch Race Drone", "model": "Custom 5-inch", "category": "Racing", "notes": "From: FPV Drones"},
    {"name": "Pave O4 Lite", "model": "Pave O4 Lite", "category": "Racing", "notes": "From: FPV Drones"},
    {"name": "CDA 3 Inch Analog Drone", "model": "Custom 3-inch analog", "category": "Racing", "notes": "From: FPV Drones — CDA build"},
    {"name": "Seeker 5", "model": "Seeker 5", "category": "Racing", "notes": "From: FPV Drones"},
    {"name": "DJI Inspire 2", "model": "DJI Inspire 2", "category": "Photography", "notes": "From: FPV Drones"},
    {"name": "DJI Air 3S", "model": "DJI Air 3S", "category": "Photography", "notes": "From: FPV Drones"},
    {"name": "DJI Matrice 4E", "model": "DJI Matrice 4E", "category": "Surveying", "notes": "From: FPV Drones"},
    {"name": "Agriculture Drone", "model": "Unspecified", "category": "Agricultural", "notes": "From: FPV Drones"},
    {"name": "Built Class Drone", "model": "Custom build", "category": "Multi-Rotor", "notes": "From: FPV Drones — qty 2, training build"},
    {"name": "450 Drone", "model": "450mm frame quad", "category": "Multi-Rotor", "notes": "From: FPV Drones"},
    {"name": "CDA Defense Drone", "model": "Custom build", "category": "Military", "notes": "From: FPV Drones — with thermal camera"},
    {"name": "Speedy Bee Drone", "model": "SpeedyBee", "category": "Racing", "notes": "From: FPV Drones"},
  ];
}
