import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/excel_service.dart';
import '../services/sheets_service.dart';
import 'stock_in_screen.dart';

class InventoryTab extends StatefulWidget {
  final UserModel user;
  const InventoryTab({super.key, required this.user});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final _excel = ExcelService();
  final _sheets = SheetsService();
  final _currency = NumberFormat.currency(symbol: '₦', decimalDigits: 2);

  List<Map<String, dynamic>> _stockInData = [];
  List<Map<String, dynamic>> _salesData = [];
  List<Map<String, dynamic>> _returnsData = [];
  bool _dataLoaded = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadTransactionData();
  }

  Future<void> _loadTransactionData() async {
    setState(() => _dataLoaded = false);
    final stockIn =
    await FirebaseFirestore.instance.collection('stock_in').get();
    final sales =
    await FirebaseFirestore.instance.collection('sales').get();
    final returns =
    await FirebaseFirestore.instance.collection('returns').get();

    setState(() {
      _stockInData = stockIn.docs.map((d) => d.data()).toList();
      _salesData = sales.docs.map((d) => d.data()).toList();
      _returnsData = returns.docs.map((d) => d.data()).toList();
      _dataLoaded = true;
    });
  }

  double _getCurrentStock(String itemName, double openingStock) {
    final totalIn = _stockInData
        .where((d) => d['itemName'] == itemName)
        .fold(0.0, (sum, d) => sum + (d['qtyReceived'] as num? ?? 0).toDouble());

    final totalSold = _salesData
        .where((d) => d['itemName'] == itemName)
        .fold(0.0, (sum, d) => sum + (d['qtySold'] as num? ?? 0).toDouble());

    final totalReturned = _returnsData
        .where((d) => d['itemName'] == itemName)
        .fold(0.0, (sum, d) => sum + (d['qtyReturned'] as num? ?? 0).toDouble());

    return openingStock + totalIn - totalSold + totalReturned;
  }

  void _showAddItemDialog([DocumentSnapshot? existingDoc]) {
    final nameCtrl = TextEditingController(
        text: existingDoc != null
            ? (existingDoc.data() as Map)['name'] ?? ''
            : '');
    final unitCtrl = TextEditingController(
        text: existingDoc != null
            ? (existingDoc.data() as Map)['unit'] ?? ''
            : '');
    final openingCtrl = TextEditingController(
        text: existingDoc != null
            ? (existingDoc.data() as Map)['openingStock']?.toString() ?? ''
            : '');
    final costCtrl = TextEditingController(
        text: existingDoc != null
            ? (existingDoc.data() as Map)['unitCost']?.toString() ?? ''
            : '');
    final priceCtrl = TextEditingController(
        text: existingDoc != null
            ? (existingDoc.data() as Map)['sellingPrice']?.toString() ?? ''
            : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existingDoc == null ? 'Add New Item' : 'Edit Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppFormField(label: 'Item Name', controller: nameCtrl),
              const SizedBox(height: 12),
              AppFormField(
                  label: 'Unit (e.g. pieces, kg, litres)',
                  controller: unitCtrl),
              const SizedBox(height: 12),
              AppFormField(
                  label: 'Opening Stock',
                  controller: openingCtrl,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              AppFormField(
                  label: 'Unit Cost (₦)',
                  controller: costCtrl,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 12),
              AppFormField(
                  label: 'Selling Price (₦)',
                  controller: priceCtrl,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;

              final data = {
                'name': nameCtrl.text.trim(),
                'unit': unitCtrl.text.trim(),
                'openingStock':
                double.tryParse(openingCtrl.text) ?? 0,
                'unitCost': double.tryParse(costCtrl.text) ?? 0,
                'sellingPrice': double.tryParse(priceCtrl.text) ?? 0,
              };

              if (existingDoc == null) {
                data['createdAt'] = FieldValue.serverTimestamp() as Object;
                await FirebaseFirestore.instance
                    .collection('inventory')
                    .add(data);
              } else {
                await existingDoc.reference.update(data);
              }

              if (ctx.mounted) Navigator.pop(ctx);
              _loadTransactionData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromExcel() async {
    _showLoading('Importing...');
    final result = await _excel.importInventory();
    if (mounted) {
      Navigator.pop(context); // close loading
      _showSnack(result);
      _loadTransactionData();
    }
  }

  Future<void> _exportToExcel(List<Map<String, dynamic>> inventoryWithStock) async {
    _showLoading('Preparing export...');
    final result = await _excel.exportInventory(inventoryWithStock);
    if (mounted) {
      Navigator.pop(context);
      _showSnack(result);
    }
  }

  Future<void> _syncToSheets(List<Map<String, dynamic>> inventoryWithStock) async {
    setState(() => _syncing = true);
    final result = await _sheets.syncInventoryToSheets(inventoryWithStock);
    setState(() => _syncing = false);
    _showSnack(result);
  }

  void _showLoading(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Text(message),
        ]),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Master Inventory'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: !_dataLoaded
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('inventory')
            .orderBy('name')
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          // Build inventory with current stock for export/sync
          final inventoryWithStock = docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final name = d['name'] ?? '';
            final openingStock =
            (d['openingStock'] as num? ?? 0).toDouble();
            return {
              ...d,
              'currentStock': _getCurrentStock(name, openingStock),
            };
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No inventory items yet.',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text(
                      'Add items manually or import from Excel',
                      style: TextStyle(
                          color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showAddItemDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Item'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _importFromExcel,
                        icon: const Icon(Icons.upload),
                        label: const Text('Import Excel'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Action toolbar
              Container(
                color: const Color(0xFF1B5E20),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Text('${docs.length} items',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    const Spacer(),
                    _ToolbarButton(
                      icon: Icons.upload,
                      label: 'Import',
                      onTap: _importFromExcel,
                    ),
                    _ToolbarButton(
                      icon: Icons.download,
                      label: 'Export',
                      onTap: () =>
                          _exportToExcel(inventoryWithStock),
                    ),
                    _ToolbarButton(
                      icon: _syncing
                          ? Icons.hourglass_empty
                          : Icons.sync,
                      label: 'Sync Sheet',
                      onTap: _syncing
                          ? null
                          : () =>
                          _syncToSheets(inventoryWithStock),
                    ),
                    _ToolbarButton(
                      icon: Icons.refresh,
                      label: 'Refresh',
                      onTap: _loadTransactionData,
                    ),
                  ],
                ),
              ),

              // Column headers
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                color: Colors.grey.shade200,
                child: const Row(
                  children: [
                    Expanded(
                        flex: 3,
                        child: Text('ITEM',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Colors.grey))),
                    Expanded(
                        flex: 2,
                        child: Text('STOCK',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Colors.grey),
                            textAlign: TextAlign.center)),
                    Expanded(
                        flex: 2,
                        child: Text('PRICE',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Colors.grey),
                            textAlign: TextAlign.center)),
                    SizedBox(width: 36),
                  ],
                ),
              ),

              // Item list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d =
                    docs[i].data() as Map<String, dynamic>;
                    final name = d['name'] ?? '';
                    final unit = d['unit'] ?? '';
                    final openingStock =
                    (d['openingStock'] as num? ?? 0).toDouble();
                    final sellingPrice =
                    (d['sellingPrice'] as num? ?? 0).toDouble();
                    final currentStock =
                    _getCurrentStock(name, openingStock);
                    final isLow = currentStock <= 5;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: isLow
                            ? Border.all(
                            color: Colors.red.shade300)
                            : null,
                        boxShadow: [
                          BoxShadow(
                              color:
                              Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isLow
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          child: Icon(
                            Icons.inventory_2,
                            size: 18,
                            color: isLow
                                ? Colors.red
                                : Colors.green.shade700,
                          ),
                        ),
                        title: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          isLow
                              ? '⚠️ LOW — ${currentStock.toStringAsFixed(0)} $unit'
                              : '${currentStock.toStringAsFixed(0)} $unit in stock',
                          style: TextStyle(
                            fontSize: 12,
                            color: isLow
                                ? Colors.red
                                : Colors.grey,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currency.format(sellingPrice),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            if (widget.user.isManager)
                              GestureDetector(
                                onTap: () =>
                                    _showAddItemDialog(docs[i]),
                                child: const Padding(
                                  padding:
                                  EdgeInsets.only(left: 8),
                                  child: Icon(Icons.edit,
                                      size: 16,
                                      color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: widget.user.isManager
          ? FloatingActionButton.extended(
        onPressed: () => _showAddItemDialog(),
        backgroundColor: const Color(0xFF1B5E20),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Item',
            style: TextStyle(color: Colors.white)),
      )
          : null,
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ToolbarButton(
      {required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            Text(label,
                style:
                const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}