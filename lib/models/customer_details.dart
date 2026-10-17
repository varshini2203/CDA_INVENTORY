// lib/models/customer_details.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerDetails {
  final String? id; // Firestore doc id (null for details embedded in a document)
  final String name;
  final String? gstin;
  final String? billingAddress;
  final String? shippingAddress;
  final String? phone;
  final String? email;
  final String placeOfSupply; // state name/code — determines CGST+SGST vs IGST
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CustomerDetails({
    this.id,
    required this.name,
    this.gstin,
    this.billingAddress,
    this.shippingAddress,
    this.phone,
    this.email,
    this.placeOfSupply = 'Tamil Nadu',
    this.createdAt,
    this.updatedAt,
  });

  /// Last 10 digits of the phone number — used to match the same customer
  /// even when typed as "98765 43210", "+91 9876543210", etc.
  String get phoneKey {
    final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  String get nameKey => name.trim().toLowerCase();

  CustomerDetails copyWith({
    String? id,
    String? name,
    String? gstin,
    String? billingAddress,
    String? shippingAddress,
    String? phone,
    String? email,
    String? placeOfSupply,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      CustomerDetails(
        id: id ?? this.id,
        name: name ?? this.name,
        gstin: gstin ?? this.gstin,
        billingAddress: billingAddress ?? this.billingAddress,
        shippingAddress: shippingAddress ?? this.shippingAddress,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        placeOfSupply: placeOfSupply ?? this.placeOfSupply,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory CustomerDetails.fromMap(Map<String, dynamic> m) => CustomerDetails(
    id: m['id']?.toString(),
    name: m['name']?.toString() ?? '',
    gstin: m['gstin']?.toString(),
    billingAddress: m['billing_address']?.toString(),
    shippingAddress: m['shipping_address']?.toString(),
    phone: m['phone']?.toString(),
    email: m['email']?.toString(),
    placeOfSupply: m['place_of_supply']?.toString() ?? 'Tamil Nadu',
  );

  /// Shape embedded inside invoices / estimates / etc.
  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'gstin': gstin,
    'billing_address': billingAddress,
    'shipping_address': shippingAddress,
    'phone': phone,
    'email': email,
    'place_of_supply': placeOfSupply,
  };

  factory CustomerDetails.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CustomerDetails(
      id: doc.id,
      name: d['name']?.toString() ?? '',
      gstin: d['gstin']?.toString(),
      billingAddress: d['billing_address']?.toString(),
      shippingAddress: d['shipping_address']?.toString(),
      phone: d['phone']?.toString(),
      email: d['email']?.toString(),
      placeOfSupply: d['place_of_supply']?.toString() ?? 'Tamil Nadu',
      createdAt: (d['created_at'] as Timestamp?)?.toDate(),
      updatedAt: (d['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name.trim(),
    'name_lower': nameKey,
    'gstin': gstin,
    'billing_address': billingAddress,
    'shipping_address': shippingAddress,
    'phone': phone,
    'phone_key': phoneKey,
    'email': email,
    'place_of_supply': placeOfSupply,
    'updated_at': FieldValue.serverTimestamp(),
  };
}