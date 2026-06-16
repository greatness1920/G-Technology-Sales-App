import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SheetsService {
  static const String _webAppUrl =
      'https://script.google.com/macros/s/AKfycbwXV4C0DhLRaiVDk9LykZhY5ZDkLZ_K3ChZ7Jewyq-UkmJ66kr_JCXVq9aKch2lPQvTzg/exec';

  final _db = FirebaseFirestore.instance;

  // Handles POST + follows 302 redirect automatically
  Future<http.Response> _post(Map<String, dynamic> body) async {
    final encoded = jsonEncode(body);
    var uri = Uri.parse(_webAppUrl);

    var response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: encoded,
    ).timeout(const Duration(seconds: 30));

    // Follow redirect if Google Apps Script returns 302
    if (response.statusCode == 302) {
      final location = response.headers['location'];
      if (location != null) {
        response = await http.post(
          Uri.parse(location),
          headers: {'Content-Type': 'application/json'},
          body: encoded,
        ).timeout(const Duration(seconds: 30));
      }
    }

    return response;
  }

  Future<String> syncInventoryToSheets(
      List<Map<String, dynamic>> inventoryItems) async {
    try {
      final cleanItems = inventoryItems.map((item) => {
        'name': item['name']?.toString() ?? '',
        'unit': item['unit']?.toString() ?? '',
        'openingStock': (item['openingStock'] as num? ?? 0).toDouble(),
        'unitCost': (item['unitCost'] as num? ?? 0).toDouble(),
        'sellingPrice': (item['sellingPrice'] as num? ?? 0).toDouble(),
        'currentStock': (item['currentStock'] as num? ?? 0).toDouble(),
      }).toList();

      final response = await _post({
        'action': 'syncInventory',
        'items': cleanItems,
      });

      if (response.statusCode == 200) {
        return 'Inventory synced to Google Sheets successfully';
      } else {
        return 'Sync failed — code: ${response.statusCode}\n${response.body}';
      }
    } catch (e) {
      return 'Sync error: $e';
    }
  }

  Future<String> syncTodaySalesToSheets() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final sales = await _db
          .collection('sales')
          .where('date', isEqualTo: today)
          .get();

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