/// Categories used to classify scanned bills across the app.
const List<String> billCategories = [
  'Purchase Invoice',
  'Maintenance',
  'Repair',
  'Fuel / Utility',
  'Rental',
  'Insurance',
  'Training Material',
  'Other',
];

/// Includes 'All' — used only for the filter chip row on the list screen.
const List<String> billFilterCategories = ['All', ...billCategories];