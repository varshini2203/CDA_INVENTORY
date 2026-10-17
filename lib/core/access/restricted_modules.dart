// lib/core/access/restricted_modules.dart
//
// SINGLE SOURCE OF TRUTH for the finance modules that are hidden from
// everyone except the specific employees the admin has granted them to.
//
// The admin always sees every module. An employee sees one of these only
// if its key is present in the `moduleAccess` array on their users/{uid}
// document (set from Manage Employees). Nothing is granted by default.
//
// To move a screen from one module to another, change it in
// [RestrictedModules._titleToModule] below — the dashboard cards, side
// drawer, report tiles and screen guards all read from this one map.

class RestrictedModules {
  RestrictedModules._();

  static const String invoices = 'invoices';
  static const String sales = 'sales';
  static const String purchases = 'purchases';

  /// Every restricted module key, in the order they appear in the admin UI.
  static const List<String> all = [invoices, sales, purchases];

  static String label(String key) {
    switch (key) {
      case invoices:
        return 'Invoices';
      case sales:
        return 'Sales';
      case purchases:
        return 'Purchases';
      default:
        return key;
    }
  }

  // Dashboard card titles / drawer keys / report names -> module key.
  // Anything NOT listed here is visible to every approved employee.
  static const Map<String, String> _titleToModule = {
    // Purchases
    'Purchases': purchases,
    'Purchase Report': purchases,

    // Invoices
    'Invoice List': invoices,
    'Sale Invoices': invoices,
    'Proforma Invoice': invoices,
    'Invoice Report': invoices,

    // Sales
    'Customers': sales,
    'Estimate/ Quotation': sales,
    'Payment-In': sales,
    'Sale Order': sales,
    'Delivery Challan': sales,
    'Sale Return/ Credit Note': sales,
  };

  /// Returns the module key guarding [title], or null if [title] is not
  /// a restricted screen.
  static String? forTitle(String title) => _titleToModule[title];
}