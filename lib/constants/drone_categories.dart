// lib/constants/drone_categories.dart

// Raw branch values as stored/filtered on in Firestore (kept distinct from
// the on-screen labels, matching the pattern used for Consumables branches).
const List<String> kBranchOptions = ['Branch 1', 'Branch 2'];

// Display-only rename: 'Branch 1' -> 'CDA Admin', 'Branch 2' -> 'CDA Ops'.
const Map<String, String> kBranchLabels = {
  'Branch 1': 'CDA Admin',
  'Branch 2': 'CDA Ops',
};

const List<String> kDroneCategories = [
  'Fixed Wing',
  'Multi-Rotor',
  'Single Rotor',
  'Hybrid VTOL',
  'Racing',
  'Photography',
  'Agricultural',
  'Surveying',
  'Delivery',
  'Military',
  'Other',
];