// lib/constants/drone_service_options.dart

const List<String> kServiceTypes = [
  'Drone Service',
  'Battery Service',
  'Motor Repair',
  'Propeller Replacement',
  'Firmware Update',
  'Full Maintenance',
  'Calibration',
  'Pre-Flight Inspection',
  'Camera / Gimbal Repair',
  'Frame Repair',
  'Other',
];

const List<String> kServiceStatuses = [
  'Scheduled',
  'In Progress',
  'Completed',
  'Cancelled',
];

// Display labels shown to the user — kept separate from the raw status
// values above (which are what's stored in Firestore and used for
// filtering) so the on-screen wording can speak the "drone in / drone
// out" language without touching any stored data or query logic.
const Map<String, String> kServiceStatusLabels = {
  'Scheduled': 'Scheduled',
  'In Progress': 'Drone In',
  'Completed': 'Handed Over',
  'Cancelled': 'Cancelled',
};

// Longer form used where there's room to spell it out (e.g. the detail
// sheet's status badge).
const Map<String, String> kServiceStatusLongLabels = {
  'Scheduled': 'Scheduled',
  'In Progress': 'Drone Service In',
  'Completed': 'Completed — Handed Over to Customer',
  'Cancelled': 'Cancelled',
};

const List<String> kServicePriorities = ['Low', 'Normal', 'High', 'Urgent'];