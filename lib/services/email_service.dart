// lib/services/email_service.dart
//
// Sends transactional emails via Brevo's REST API (free plan — no
// Cloud Functions / Blaze needed). Only admin users receive these;
// employees are never emailed.
//
// Run the app with:
//   flutter run --dart-define=BREVO_API_KEY=xkeysib-your-key-here
//
// For release builds:
//   flutter build apk --dart-define=BREVO_API_KEY=xkeysib-your-key-here

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailService {
  static const String _apiKey = String.fromEnvironment('BREVO_API_KEY');
  static const String _endpoint = 'https://api.brevo.com/v3/smtp/email';

  // Must match the sender you verified in Brevo.
  static const String _senderEmail = 'info@chennaidroneacademy.com';
  static const String _senderName = 'CDA Inventory';

  /// Fetches every admin's email from Firestore (users collection,
  /// role == 'admin'). Adjust field names to match your schema.
  static Future<List<String>> _getAdminEmails() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();
    return snap.docs
        .map((d) => (d.data()['email'] as String?) ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Core sender — one Brevo API call per recipient (free-plan safe,
  /// avoids exposing every admin's address to every other admin).
  static Future<bool> _send({
    required String subject,
    required String htmlContent,
  }) async {
    if (_apiKey.isEmpty) {
      print('EmailService: BREVO_API_KEY not set — skipping email.');
      return false;
    }

    final admins = await _getAdminEmails();
    if (admins.isEmpty) {
      print('EmailService: no admin emails found — skipping.');
      return false;
    }

    bool allOk = true;
    for (final email in admins) {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'accept': 'application/json',
          'api-key': _apiKey,
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'sender': {'name': _senderName, 'email': _senderEmail},
          'to': [
            {'email': email}
          ],
          'subject': subject,
          'htmlContent': htmlContent,
        }),
      );
      if (response.statusCode != 201) {
        print('EmailService: failed for $email → ${response.body}');
        allOk = false;
      }
    }
    return allOk;
  }

  // ── Public trigger methods — call these from your existing services ──

  static Future<void> sendLowStock({
    required String itemName,
    required int currentQty,
    required int threshold,
    required String branch,
  }) {
    return _send(
      subject: '⚠️ Low Stock Alert — $itemName',
      htmlContent: '''
        <h3>Low Stock Alert</h3>
        <p><b>Item:</b> $itemName</p>
        <p><b>Branch:</b> $branch</p>
        <p><b>Current Quantity:</b> $currentQty (threshold: $threshold)</p>
        <p>Please restock soon.</p>
      ''',
    );
  }

  static Future<void> sendNewInventory({
    required String itemName,
    required int quantity,
    required String branch,
    required String addedBy,
  }) {
    return _send(
      subject: '📦 New Inventory Added — $itemName',
      htmlContent: '''
        <h3>New Inventory Added</h3>
        <p><b>Item:</b> $itemName</p>
        <p><b>Quantity:</b> $quantity</p>
        <p><b>Branch:</b> $branch</p>
        <p><b>Added by:</b> $addedBy</p>
      ''',
    );
  }

  static Future<void> sendProductSold({
    required String itemName,
    required int quantitySold,
    required String branch,
    required String soldBy,
  }) {
    return _send(
      subject: '💰 Product Sold — $itemName',
      htmlContent: '''
        <h3>Product Sold</h3>
        <p><b>Item:</b> $itemName</p>
        <p><b>Quantity Sold:</b> $quantitySold</p>
        <p><b>Branch:</b> $branch</p>
        <p><b>Sold by:</b> $soldBy</p>
      ''',
    );
  }

  static Future<void> sendDailyReport({
    required String branch,
    required int totalItems,
    required int lowStockCount,
    required int transactionsToday,
  }) {
    return _send(
      subject: '📊 Daily Inventory Report — $branch',
      htmlContent: '''
        <h3>Daily Report — $branch</h3>
        <p><b>Total Items:</b> $totalItems</p>
        <p><b>Low Stock Items:</b> $lowStockCount</p>
        <p><b>Transactions Today:</b> $transactionsToday</p>
      ''',
    );
  }
}