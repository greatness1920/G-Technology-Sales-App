// ============================================================
// EXCEL SERVICE
// Handles exporting data to .xlsx files and importing
// inventory data from .xlsx files.
//
// Export functions:
//   exportDailyReport(date) → Creates an Excel file with
//     Sales and Returns sheets for the selected date.
//     Shared via the device's share sheet (WhatsApp, email, etc.)
//
//   exportInventory(items) → Creates an Excel file with
//     Inventory Master, Stock In, and All Sales sheets.
//
// Import function:
//   importInventory() → Opens file picker, reads an Excel file,
//     and updates/creates inventory items in Firestore.
//     Expected sheet name: "Inventory Master"
//     Expected columns: Item Name | Unit | Opening Stock | Unit Cost | Selling Price
// ============================================================

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ExcelService {
  final _db = FirebaseFirestore.instance;

  /// Exports sales and returns for a specific date to an Excel file.
  /// The file is saved to a temp directory then shared via the system share sheet.
  Future<String> exportDailyReport(DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final excel = Excel.createExcel();

      // Remove the default empty sheet Excel creates
      excel.delete('Sheet1');

      // ── Build Sales Sheet ──
      final salesSheet = excel['Sales'];
      // Add header row
      salesSheet.appendRow([
        TextCellValue('Date'), TextCellValue('Item Name'),
        TextCellValue('Qty Sold'), TextCellValue('Unit Price (₦)'),
        TextCellValue('Total Amount (₦)'), TextCellValue('Payment Method'),
        TextCellValue('Cashier'), TextCellValue('Receipt No'),
      ]);

      // Fetch today's sales and add each as a row
      final sales = await _db.collection('sales')
          .where('date', isEqualTo: dateStr).get();

      double totalRevenue = 0;
      for (var doc in sales.docs) {
        final d = doc.data();
        final amt = (d['totalAmount'] as num? ?? 0).toDouble();
        totalRevenue += amt;
        salesSheet.appendRow([
          TextCellValue(d['date'] ?? ''),
          TextCellValue(d['itemName'] ?? ''),
          IntCellValue(d['qtySold'] ?? 0),
          DoubleCellValue((d['unitPrice'] as num? ?? 0).toDouble()),
          DoubleCellValue(amt),
          TextCellValue(d['paymentMethod'] ?? ''),
          TextCellValue(d['cashierName'] ?? ''),
          TextCellValue(d['receiptNo'] ?? ''),
        ]);
      }

      // Add a total row at the bottom
      salesSheet.appendRow([]);
      salesSheet.appendRow([
        TextCellValue('TOTAL'), TextCellValue(''), TextCellValue(''),
        TextCellValue(''), DoubleCellValue(totalRevenue),
        TextCellValue(''), TextCellValue(''), TextCellValue(''),
      ]);

      // ── Build Returns Sheet ──
      final returnsSheet = excel['Returns'];
      returnsSheet.appendRow([
        TextCellValue('Date'), TextCellValue('Item Name'),
        TextCellValue('Qty Returned'), TextCellValue('Reason'),
        TextCellValue('Action Taken'), TextCellValue('Processed By'),
      ]);

      final returns = await _db.collection('returns')
          .where('date', isEqualTo: dateStr).get();
      for (var doc in returns.docs) {
        final d = doc.data();
        returnsSheet.appendRow([
          TextCellValue(d['date'] ?? ''),
          TextCellValue(d['itemName'] ?? ''),
          IntCellValue(d['qtyReturned'] ?? 0),
          TextCellValue(d['reason'] ?? ''),
          TextCellValue(d['actionTaken'] ?? ''),
          TextCellValue(d['processedBy'] ?? ''),
        ]);
      }

      // Save the Excel file to a temporary directory
      final bytes = excel.save();
      if (bytes == null) return 'Export failed — could not generate file';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sales_report_$dateStr.xlsx');
      await file.writeAsBytes(bytes);

      // Share the file using the device's native share sheet
      await Share.shareXFiles([XFile(file.path)],
          subject: 'Sales Report — $dateStr');

      return 'Exported successfully';
    } catch (e) {
      return 'Export failed: $e';
    }
  }

  /// Exports the full inventory with current stock levels to Excel.
  /// Takes the pre-calculated inventory list (with currentStock) as input
  /// since stock is calculated client-side, not stored in Firestore directly.
  Future<String> exportInventory(
      List<Map<String, dynamic>> inventoryWithStock) async {
    try {
      final excel = Excel.createExcel();
      excel.delete('Sheet1');

      // ── Inventory Master Sheet ──
      final inventorySheet = excel['Inventory Master'];
      inventorySheet.appendRow([
        TextCellValue('Item Name'), TextCellValue('Unit'),
        TextCellValue('Opening Stock'), TextCellValue('Unit Cost (₦)'),
        TextCellValue('Selling Price (₦)'), TextCellValue('Current Stock'),
      ]);

      for (var item in inventoryWithStock) {
        inventorySheet.appendRow([
          TextCellValue(item['name'] ?? ''),
          TextCellValue(item['unit'] ?? ''),
          DoubleCellValue((item['openingStock'] as num? ?? 0).toDouble()),
          DoubleCellValue((item['unitCost'] as num? ?? 0).toDouble()),
          DoubleCellValue((item['sellingPrice'] as num? ?? 0).toDouble()),
          DoubleCellValue((item['currentStock'] as num? ?? 0).toDouble()),
        ]);
      }

      // ── Stock In History Sheet ──
      final stockInSheet = excel['Stock In'];
      stockInSheet.appendRow([
        TextCellValue('Date'), TextCellValue('Item Name'),
        TextCellValue('Qty Received'), TextCellValue('Unit Cost (₦)'),
        TextCellValue('Total Value (₦)'), TextCellValue('Supplier'),
        TextCellValue('Received By'),
      ]);

      final stockIn = await _db.collection('stock_in')
          .orderBy('createdAt', descending: true).get();
      for (var doc in stockIn.docs) {
        final d = doc.data();
        stockInSheet.appendRow([
          TextCellValue(d['date'] ?? ''),
          TextCellValue(d['itemName'] ?? ''),
          IntCellValue(d['qtyReceived'] ?? 0),
          DoubleCellValue((d['unitCost'] as num? ?? 0).toDouble()),
          DoubleCellValue((d['totalValue'] as num? ?? 0).toDouble()),
          TextCellValue(d['supplier'] ?? ''),
          TextCellValue(d['receivedBy'] ?? ''),
        ]);
      }

      // ── All Sales History Sheet ──
      final salesSheet = excel['All Sales'];
      salesSheet.appendRow([
        TextCellValue('Date'), TextCellValue('Item Name'),
        TextCellValue('Qty Sold'), TextCellValue('Unit Price (₦)'),
        TextCellValue('Total (₦)'), TextCellValue('Payment'),
        TextCellValue('Cashier'),
      ]);

      final sales = await _db.collection('sales')
          .orderBy('createdAt', descending: true).get();
      for (var doc in sales.docs) {
        final d = doc.data();
        salesSheet.appendRow([
          TextCellValue(d['date'] ?? ''),
          TextCellValue(d['itemName'] ?? ''),
          IntCellValue(d['qtySold'] ?? 0),
          DoubleCellValue((d['unitPrice'] as num? ?? 0).toDouble()),
          DoubleCellValue((d['totalAmount'] as num? ?? 0).toDouble()),
          TextCellValue(d['paymentMethod'] ?? ''),
          TextCellValue(d['cashierName'] ?? ''),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) return 'Export failed';

      final dir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final file = File('${dir.path}/inventory_export_$dateStr.xlsx');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)],
          subject: 'Inventory Export — $dateStr');

      return 'Exported successfully';
    } catch (e) {
      return 'Export failed: $e';
    }
  }

  /// Imports inventory items from an Excel file.
  ///
  /// The Excel file must have a sheet named exactly "Inventory Master"
  /// with columns in this order:
  ///   A: Item Name | B: Unit | C: Opening Stock | D: Unit Cost | E: Selling Price
  ///
  /// If an item with the same name already exists in Firestore,
  /// it will be UPDATED. If it's new, it will be CREATED.
  Future<String> importInventory() async {
    try {
      // Open the device's file picker filtered to Excel files only
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true, // Load file bytes into memory
      );

      if (result == null || result.files.isEmpty) return 'No file selected';

      final bytes = result.files.first.bytes;
      if (bytes == null) return 'Could not read file';

      final excel = Excel.decodeBytes(bytes);

      // Look for the required sheet by exact name
      final sheet = excel.tables['Inventory Master'];
      if (sheet == null) {
        return 'No sheet named "Inventory Master" found.\n'
            'Make sure your Excel file has a sheet named exactly: Inventory Master';
      }

      int imported = 0; // Count of new items added
      int updated = 0;  // Count of existing items updated

      // Skip row 0 (header) and process data rows
      for (var row in sheet.rows.skip(1)) {
        if (row.isEmpty || row[0]?.value == null) continue;

        final name = row[0]?.value.toString().trim() ?? '';
        if (name.isEmpty) continue; // Skip empty rows

        final unit = row[1]?.value.toString() ?? '';
        final openingStock =
            double.tryParse(row[2]?.value.toString() ?? '0') ?? 0;
        final unitCost =
            double.tryParse(row[3]?.value.toString() ?? '0') ?? 0;
        final sellingPrice =
            double.tryParse(row[4]?.value.toString() ?? '0') ?? 0;

        // Check if item already exists by name
        final existing = await _db.collection('inventory')
            .where('name', isEqualTo: name).get();

        if (existing.docs.isNotEmpty) {
          // Update existing item
          await existing.docs.first.reference.update({
            'unit': unit, 'openingStock': openingStock,
            'unitCost': unitCost, 'sellingPrice': sellingPrice,
          });
          updated++;
        } else {
          // Create new item
          await _db.collection('inventory').add({
            'name': name, 'unit': unit, 'openingStock': openingStock,
            'unitCost': unitCost, 'sellingPrice': sellingPrice,
            'createdAt': FieldValue.serverTimestamp(),
          });
          imported++;
        }
      }

      return '$imported new items added, $updated items updated';
    } catch (e) {
      return 'Import failed: $e';
    }
  }
}