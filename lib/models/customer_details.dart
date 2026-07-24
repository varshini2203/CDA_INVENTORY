// lib/models/customer_details.dart
class CustomerDetails {
  final String name;
  final String? gstin;
  final String? billingAddress;
  final String? shippingAddress;
  final String? phone;
  final String? email;
  final String placeOfSupply;   // state name/code — determines CGST+SGST vs IGST

  CustomerDetails({
    required this.name,
    this.gstin,
    this.billingAddress,
    this.shippingAddress,
    this.phone,
    this.email,
    this.placeOfSupply = 'Tamil Nadu',
  });

  factory CustomerDetails.fromMap(Map<String, dynamic> m) => CustomerDetails(
    name: m['name']?.toString() ?? '',
    gstin: m['gstin']?.toString(),
    billingAddress: m['billing_address']?.toString(),
    shippingAddress: m['shipping_address']?.toString(),
    phone: m['phone']?.toString(),
    email: m['email']?.toString(),
    placeOfSupply: m['place_of_supply']?.toString() ?? 'Tamil Nadu',
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'gstin': gstin,
    'billing_address': billingAddress,
    'shipping_address': shippingAddress,
    'phone': phone,
    'email': email,
    'place_of_supply': placeOfSupply,
  };
}