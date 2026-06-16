import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class StockVerificationScreen extends StatefulWidget {
  final UserModel user;
  final bool embedded;
  const StockVerificationScreen({
    super.key,
    required this.user,
    this.embedded = false,
  });

  @override
  State<StockVerificationScreen> createState() =>
      _StockVerificationScreenState();
}

class _StockVerificationScreenState
    extends State<StockVerificationScreen> {
  final _fs = FirestoreService();
  List<_StockItem> _items = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() => _loading = true);

    final inventory = await FirebaseFirestore.instance
        .collection('inventory')
        .orderBy('name')
        .get();

    final stockIn = await FirebaseFirestore.instance
        .collection('stock_in')
        .get();
    final sales = await FirebaseFirestore.instance
        .collection('sales')
        .get();
    final returns = await FirebaseFirestore.instance
        .collection('returns')
        .get();

    final items = inventory.docs.map((doc) {
      final data = doc.data();
      final name = data['name'] ?? '';
      final unit = data['unit'] ?? '';
      final opening =
      (data['openingStock'] as num? ?? 0).toDouble();

      final totalIn = stockIn.docs
          .where((d) => d.data()['itemName'] == name)
          .fold(0.0,
              (s, d) => s + (d.data()['qtyReceived'] as num? ?? 0));
      final totalSold = sales.docs
          .where((d) => d.data()['itemName'] == name)
          .fold(0.0,
              (s, d) => s + (d.data()['qtySold'] as num? ?? 0));
      final totalReturned = returns.docs
          .where((d) => d.data()['itemName'] == name)
          .fold(0.0,
              (s, d) => s + (d.data()['qtyReturned'] as num? ?? 0));

      final systemQty = opening + totalIn - totalSold + totalReturned;

      return _StockItem(
        name: name,
        unit: unit,
        systemQty: systemQty,
        controller: TextEditingController(),
      );
    }).toList();

    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _submitAll() async {
    final toSubmit =
    _items.where((i) => i.controller.text.isNotEmpty).toList();

    if (toSubmit.isEmpty) {
      _showSnack('Enter at least one physical count', isError: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      for (final item in toSubmit) {
        final physical = double.tryParse(item.controller.text) ?? 0;
        await _fs.addStockVerification(
          itemName: item.name,
          systemQty: item.systemQty.toInt(),
          physicalCount: physical.toInt(),
          verifiedBy: widget.user.name,
        );
      }
      _showSnack('${toSubmit.length} item(s) verified successfully!');
      // Clear all fields after submit
      for (final item in _items) {
        item.controller.clear();
        item.countEntered = false;
      }
      setState(() {});
    } catch (e) {
      _showSnack('Error submitting: $e', isError: true);
    } finally {
      setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          color: Colors.purple.shade700,
          child: Row(children: [
            Text(
              '${_items.length} items to verify',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _loadInventory,
              icon: const Icon(Icons.refresh,
                  color: Colors.white70, size: 16),
              label: const Text('Refresh',
                  style: TextStyle(color: Colors.white70)),
            ),
          ]),
        ),

        // Instructions banner
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.purple.shade50,
          child: const Row(children: [
            Icon(Icons.info_outline,
                color: Colors.purple, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Enter physical count for each item. System quantity will appear after you type.',
                style: TextStyle(
                    fontSize: 12, color: Colors.purple),
              ),
            ),
          ]),
        ),

        // Items list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _items.length,
            itemBuilder: (context, i) {
              final item = _items[i];
              final physical =
              double.tryParse(item.controller.text);
              final diff = physical != null
                  ? physical - item.systemQty
                  : null;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: diff == null
                        ? Colors.grey.shade200
                        : diff == 0
                        ? Colors.green.shade300
                        : diff > 0
                        ? Colors.orange.shade300
                        : Colors.red.shade300,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      // Item name + unit
                      Row(children: [
                        const Icon(Icons.inventory_2,
                            size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15),
                          ),
                        ),
                        Text(
                          item.unit,
                          style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      // Physical count input
                      TextField(
                        controller: item.controller,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {
                          item.countEntered =
                              item.controller.text.isNotEmpty;
                        }),
                        decoration: InputDecoration(
                          labelText: 'Physical Count',
                          hintText: 'How many did you count?',
                          border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),

                      // Show system qty + difference AFTER count is entered
                      if (item.countEntered) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: diff == 0
                                ? Colors.green.shade50
                                : diff != null && diff > 0
                                ? Colors.orange.shade50
                                : Colors.red.shade50,
                            borderRadius:
                            BorderRadius.circular(8),
                          ),
                          child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceAround,
                              children: [
                                _InfoBox(
                                  label: 'System Qty',
                                  value: item.systemQty
                                      .toStringAsFixed(0),
                                  color: Colors.blue,
                                ),
                                _InfoBox(
                                  label: 'You Counted',
                                  value: item.controller.text,
                                  color: Colors.purple,
                                ),
                                _InfoBox(
                                  label: 'Difference',
                                  value: diff != null
                                      ? (diff >= 0
                                      ? '+${diff.toStringAsFixed(0)}'
                                      : diff.toStringAsFixed(0))
                                      : '-',
                                  color: diff == null || diff == 0
                                      ? Colors.green
                                      : diff > 0
                                      ? Colors.orange
                                      : Colors.red,
                                ),
                              ]),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Submit button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _submitting ? null : _submitAll,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700),
            child: _submitting
                ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Text('Submit All Verifications',
                style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Verification'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: body,
    );
  }
}

class _StockItem {
  final String name;
  final String unit;
  final double systemQty;
  final TextEditingController controller;
  bool countEntered;

  _StockItem({
    required this.name,
    required this.unit,
    required this.systemQty,
    required this.controller,
    this.countEntered = false,
  });
}

class _InfoBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _InfoBox(
      {required this.label,
        required this.value,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color)),
    ]);
  }
}