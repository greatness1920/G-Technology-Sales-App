import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ExcelService {
  final _db = FirebaseFirestore.instance;

  // ─── EXPORT DAILY SALES REPORT ────────────────────────────────

  Future<String> exportDailyReport(DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final excel = Excel.createExcel();

      // Remove default sheet
      excel.delete('Sheet1');

      // ── SALES SHEET ──
      final salesSheet = excel['Sales'];
      salesSheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Item Name'),
        TextCellValue('Qty Sold'),
        TextCellValue('Unit Price (₦)'),
        TextCellValue('Total Amount (₦)'),
        TextCellValue('Payment Method'),
        TextCellValue('Cashier'),
        TextCellValue('Receipt No'),
      ]);

      final sales = await _db
          .collection('sales')
          .where('date', isEqualTo: dateStr)
          .get();

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

      // Total row
      salesSheet.appendRow([]);
      salesSheet.appendRow([
        TextCellValue('TOTAL'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        DoubleCellValue(totalRevenue),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
      ]);

      // ── RETURNS SHEET ──
      final returnsSheet = excel['Returns'];
      returnsSheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Item Name'),
        TextCellValue('Qty Returned'),
        TextCellValue('Reason'),
        TextCellValue('Action Taken'),
        TextCellValue('Processed By'),
      ]);

      final returns = await _db
          .collection('returns')
          .where('date', isEqualTo: dateStr)
          .get();

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

      // Save file
      final bytes = excel.save();
      if (bytes == null) return 'Export failed — could not generate file';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sales_report_$dateStr.xlsx');
      await file.writeAsBytes(bytes);

      // Share file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Sales Report — $dateStr',
        text: 'Daily sales report for $dateStr',
      );

      return 'Exported successfully';
    } catch (e) {
      return 'Export failed: $e';
    }
  }

  // ─── EXPORT FULL INVENTORY ────────────────────────────────────

  Future<String> exportInventory(List<Map<String, dynamic>> inventoryWithStock) async {
    try {
      final excel = Excel.createExcel();
      excel.delete('Sheet1');

      // ── INVENTORY MASTER SHEET ──
      final inventorySheet = excel['Inventory Master'];
      inventorySheet.appendRow([
        TextCellValue('Item Name'),
        TextCellValue('Unit'),
        TextCellValue('Opening Stock'),
        TextCellValue('Unit Cost (₦)'),
        TextCellValue('Selling Price (₦)'),
        TextCellValue('Current Stock'),
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

      // ── STOCK IN SHEET ──
      final stockInSheet = excel['Stock In'];
      stockInSheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Item Name'),
        TextCellValue('Qty Received'),
        TextCellValue('Unit Cost (₦)'),
        TextCellValue('Total Value (₦)'),
        TextCellValue('Supplier'),
        TextCellValue('Received By'),
      ]);

      final stockIn = await _db
          .collection('stock_in')
          .orderBy('createdAt', descending: true)
          .get();
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

      // ── ALL SALES SHEET ──
      final salesSheet = excel['All Sales'];
      salesSheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Item Name'),
        TextCellValue('Qty Sold'),
        TextCellValue('Unit Price (₦)'),
        TextCellValue('Total (₦)'),
        TextCellValue('Payment'),
        TextCellValue('Cashier'),
      ]);

      final sales = await _db
          .collection('sales')
          .orderBy('createdAt', descending: true)
          .get();
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

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Inventory Export — $dateStr',
      );

      return 'Exported successfully';
    } catch (e) {
      return 'Export failed: $e';
    }
  }

  // ─── IMPORT INVENTORY FROM EXCEL ─────────────────────────────

  Future<String> importInventory() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return 'No file selected';

      final bytes = result.files.first.bytes;
      if (bytes == null) return 'Could not read file';

      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables['Inventory Master'];

      if (sheet == null) {
        return 'No sheet named "Inventory Master" found.\n'
            'Make sure your Excel file has a sheet named exactly: Inventory Master';
      }

      int imported = 0;
      int updated = 0;

      for (var row in sheet.rows.skip(1)) {
        if (row.isEmpty || row[0]?.value == null) continue;

        final name = row[0]?.value.toString().trim() ?? '';
        if (name.isEmpty) continue;

        final unit = row[1]?.value.toString() ?? '';
        final openingStock =
            double.tryParse(row[2]?.value.toString() ?? '0') ?? 0;
        final unitCost =
            double.tryParse(row[3]?.value.toString() ?? '0') ?? 0;
        final sellingPrice =
            double.tryParse(row[4]?.value.toString() ?? '0') ?? 0;

        // Check if item already exists
        final existing = await _db
            .collection('inventory')
            .where('name', isEqualTo: name)
            .get();

        if (existing.docs.isNotEmpty) {
          await existing.docs.first.reference.update({
            'unit': unit,
            'openingStock': openingStock,
            'unitCost': unitCost,
            'sellingPrice': sellingPrice,
          });
          updated++;
        } else {
          await _db.collection('inventory').add({
            'name': name,
            'unit': unit,
            'openingStock': openingStock,
            'unitCost': unitCost,
            'sellingPrice': sellingPrice,
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