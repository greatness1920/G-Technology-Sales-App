import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ExcelService {
  final _db = FirebaseFirestore.instance;

  Future<String> exportDailyReport(DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final excel = Excel.createExcel();
      excel.delete('Sheet1');

      final salesSheet = excel['Sales'];
      salesSheet.appendRow([
        TextCellValue('Date'), TextCellValue('Item Name'),
        TextCellValue('Qty Sold'), TextCellValue('Unit Price (₦)'),
        TextCellValue('Total Amount (₦)'), TextCellValue('Payment Method'),
        TextCellValue('Cashier'), TextCellValue('Receipt No'),
      ]);

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

      salesSheet.appendRow([]);
      salesSheet.appendRow([
        TextCellValue('TOTAL'), TextCellValue(''), TextCellValue(''),
        TextCellValue(''), DoubleCellValue(totalRevenue),
        TextCellValue(''), TextCellValue(''), TextCellValue(''),
      ]);

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

      final bytes = excel.save();
      if (bytes == null) return 'Export failed';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sales_report_$dateStr.xlsx');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)],
          subject: 'Sales Report — $dateStr');

      return 'Exported successfully';
    } catch (e) {
      return 'Export failed: $e';
    }
  }

  Future<String> exportInventory(
      List<Map<String, dynamic>> inventoryWithStock) async {
    try {
      final excel = Excel.createExcel();
      excel.delete('Sheet1');

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

  // Import temporarily disabled — will be restored in next update
  Future<String> importInventory() async {
    return 'Import from Excel coming in next update';
  }
}