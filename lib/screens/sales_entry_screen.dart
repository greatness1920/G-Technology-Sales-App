import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'stock_in_screen.dart';
import '../widgets/item_name_autocomplete.dart';



class SalesEntryScreen extends StatefulWidget {
  final UserModel user;
  final bool embedded;
  const SalesEntryScreen({
    super.key,
    required this.user,
    this.embedded = false,
  });

  @override
  State<SalesEntryScreen> createState() => _SalesEntryScreenState();
}

class _SalesEntryScreenState extends State<SalesEntryScreen> {
  final _itemController = TextEditingController();
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();
  final _receiptController = TextEditingController();
  String _paymentMethod = 'Cash';
  final _fs = FirestoreService();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_itemController.text.isEmpty ||
        _qtyController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _receiptController.text.isEmpty) {
      _showSnack('Please fill in all fields', isError: true);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await _fs.addSale(
        itemName: _itemController.text,
        qtySold: int.parse(_qtyController.text),
        unitPrice: double.parse(_priceController.text),
        paymentMethod: _paymentMethod,
        cashierName: widget.user.name,
        receiptNo: _receiptController.text,
      );
      _showSnack('Sale recorded successfully!');
      _clearForm();
    } catch (e) {
      _showSnack('Error: Check your inputs', isError: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _clearForm() {
    _itemController.clear();
    _qtyController.clear();
    _priceController.clear();
    _receiptController.clear();
    setState(() => _paymentMethod = 'Cash');
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
    _itemController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _receiptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ItemNameAutocomplete(controller: _itemController),
          const SizedBox(height: 16),
          AppFormField(
              label: 'Quantity Sold',
              controller: _qtyController,
              keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          AppFormField(
              label: 'Unit Price (₦)',
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true)),
          const SizedBox(height: 16),
          AppFormField(
              label: 'Receipt Number',
              controller: _receiptController,
              keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          const Text('Payment Method',
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: ['Cash', 'POS', 'Transfer', 'Credit']
                .map((method) {
              final selected = _paymentMethod == method;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _paymentMethod = method),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.green.shade700
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      method,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.person, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text('Cashier: ${widget.user.name}',
                  style: const TextStyle(color: Colors.grey)),
            ]),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700),
            child: _isSubmitting
                ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Text('Submit Sale',
                style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Sale'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: body,
    );
  }
}