// ============================================================
// SHEETS SERVICE
// Syncs inventory and sales data to Google Sheets via a
// Google Apps Script Web App deployed as an HTTP endpoint.
//
// How it works:
//   1. Flutter sends a POST request with JSON data
//   2. Google Apps Script receives it and writes to the sheet
//   3. The sheet updates in real time
//
// Note: Google Apps Script redirects the initial request (302).
// The _post() helper handles this automatically by re-sending
// the POST to the redirect URL.
//
// Web App URL: Stored in _webAppUrl constant.
// Must be updated if the Apps Script is redeployed.
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SheetsService {
  /// Google Apps Script Web App URL.
  /// This endpoint receives POST requests and writes to the Google Sheet.
  /// Update this URL if the Apps Script deployment changes.
  static const String _webAppUrl =
      'https://script.google.com/macros/s/AKfycbwXV4C0DhLRaiVDk9LykZhY5ZDkLZ_K3ChZ7Jewyq-UkmJ66kr_JCXVq9aKch2lPQvTzg/exec';

  final _db = FirebaseFirestore.instance;

  /// Internal POST helper that handles Google Apps Script's 302 redirect.
  ///
  /// Problem: Google Apps Script redirects the initial POST to a new URL.
  /// Standard http clients don't re-send the POST body after a redirect.
  /// Solution: Detect the 302, then manually re-send the POST to the new URL.
  Future<http.Response> _post(Map<String, dynamic> body) async {
    final encoded = jsonEncode(body);
    var uri = Uri.parse(_webAppUrl);

    // Try up to 5 redirect hops
    for (int i = 0; i < 5; i++) {
      // Send POST with followRedirects disabled so we can handle it manually
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      request.body = encoded;
      request.followRedirects = false;

      final client = http.Client();
      final streamed = await client.send(request);
      client.close();

      // Handle redirect responses (301, 302, 303)
      if (streamed.statusCode == 301 ||
          streamed.statusCode == 302 ||
          streamed.statusCode == 303) {
        final location = streamed.headers['location'];
        if (location != null) {
          uri = Uri.parse(location); // Follow redirect URL
          await streamed.stream.drain(); // Discard redirect response body
          continue;
        }
      }

      // Non-redirect response — return it
      return await http.Response.fromStream(streamed);
    }

    return http.Response('Too many redirects', 500);
  }

  /// Syncs the master inventory list to the 'INVENTORY MASTER' sheet.
  ///
  /// Strips Firestore Timestamp fields before encoding to JSON,
  /// since Timestamps are not JSON-serializable.
  Future<String> syncInventoryToSheets(
      List<Map<String, dynamic>> inventoryItems) async {
    try {
      // Clean the data — extract only plain, JSON-safe fields
      final cleanItems = inventoryItems.map((item) => {
        'name': item['name']?.toString() ?? '',
        'unit': item['unit']?.toString() ?? '',
        'openingStock': (item['openingStock'] as num? ?? 0).toDouble(),
        'unitCost': (item['unitCost'] as num? ?? 0).toDouble(),
        'sellingPrice': (item['sellingPrice'] as num? ?? 0).toDouble(),
        'currentStock': (item['currentStock'] as num? ?? 0).toDouble(),
      }).toList();

      final response = await _post({
        'action': 'syncInventory', // Apps Script reads this to route the request
        'items': cleanItems,
      });

      if (response.statusCode == 200) {
        return 'Inventory synced to Google Sheets successfully';
      } else {
        return 'Sync failed — code: ${response.statusCode}';
      }
    } catch (e) {
      return 'Sync error: $e';
    }
  }

  /// Syncs today's sales to the 'SALES LOG' sheet.
  ///
  /// Fetches only today's sales from Firestore, strips Timestamps,
  /// then appends them to the sheet (does not overwrite existing rows).
  Future<String> syncTodaySalesToSheets() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Fetch only today's sales from Firestore
      final sales = await _db
          .collection('sales')
          .where('date', isEqualTo: today)
          .get();

      // Clean data — remove Firestore Timestamps and non-JSON fields
      final cleanSales = sales.docs.map((doc) {
        final d = doc.data();
        return {
          'date': d['date']?.toString() ?? '',
          'itemName': d['itemName']?.toString() ?? '',
          'qtySold': (d['qtySold'] as num? ?? 0).toInt(),
          'unitPrice': (d['unitPrice'] as num? ?? 0).toDouble(),
          'totalAmount': (d['totalAmount'] as num? ?? 0).toDouble(),
          'paymentMethod': d['paymentMethod']?.toString() ?? '',
          'cashierName': d['cashierName']?.toString() ?? '',
          'receiptNo': d['receiptNo']?.toString() ?? '',
        };
      }).toList();

      final response = await _post({
        'action': 'syncSales',
        'date': today,
        'sales': cleanSales,
      });

      if (response.statusCode == 200) {
        return 'Sales synced to Google Sheets successfully';
      } else {
        return 'Sync failed — code: ${response.statusCode}';
      }
    } catch (e) {
      return 'Sync error: $e';
    }
  }
}