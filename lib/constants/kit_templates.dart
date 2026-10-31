// lib/constants/kit_templates.dart
//
// Constants for the "Kit Deliveries" module (full drone kits handed to a
// customer, where some parts may be delivered later).

/// Default parts in a full drone kit. Each entry is
/// {name, category, qty}. The Add Kit screen starts from this list and the
/// user can change quantities, remove parts or add custom ones.
const List<Map<String, Object>> kDefaultKitItems = [
  {'name': 'Drone', 'category': 'Drone', 'qty': 1},
  {'name': 'Propellers', 'category': 'Propeller', 'qty': 4},
  {'name': 'Motors', 'category': 'Motor', 'qty': 4},
  {'name': 'Battery', 'category': 'Battery', 'qty': 1},
  {'name': 'Charger', 'category': 'Charger', 'qty': 1},
  {'name': 'Remote Controller', 'category': 'Controller', 'qty': 1},
  {'name': 'Carry Bag', 'category': 'Bag', 'qty': 1},
];

/// Categories offered when adding a custom part to a kit.
const List<String> kKitItemCategories = [
  'Drone',
  'Propeller',
  'Motor',
  'Battery',
  'Charger',
  'Controller',
  'Bag',
  'Accessory',
  'Other',
];

/// Kit status values stored in Firestore.
const String kKitPending = 'Pending';
const String kKitComplete = 'Complete';

/// How many days after the first hand-over the pending parts are promised
/// by default (pre-filled on the Add Kit screen, editable per kit).
const int kDefaultPendingPromiseDays = 3;

/// Time of day the pending-parts reminder fires (24h). The device
/// notification repeats daily at this time until the kit is complete.
const int kKitReminderHour = 10;
const int kKitReminderMinute = 0;