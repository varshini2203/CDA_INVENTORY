// lib/constants/payment_modes.dart
//
// Single source of truth for the "Payment Mode" dropdown used across the
// app — Sale Invoices (New Sale), Payment-In, Payment-Out, and Purchases.
// Change the list here and it updates everywhere that imports it.

const List<String> kPaymentModes = [
  'Cash',
  'Axis Bank',
  'Axis Card Machine',
  'Indian Bank',
  'Indian Razor Pay',
  'JP HDFC',
];

/// Fallback used whenever a stored value (old data, edited record, etc.)
/// no longer matches one of the current [kPaymentModes] options.
const String kDefaultPaymentMode = 'Cash';

/// Returns [stored] if it's still a valid option, otherwise falls back to
/// [kDefaultPaymentMode]. Use this whenever pre-filling a dropdown from an
/// existing record (edit screens, legacy data with old mode names, etc.)
String resolvePaymentMode(String? stored) {
  if (stored != null && kPaymentModes.contains(stored)) return stored;
  return kDefaultPaymentMode;
}
