import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../widgets/item_name_autocomplete.dart';
import '../widgets/comments_sheet.dart';

class StockInScreen extends StatefulWidget {
  final UserModel user;
  final bool embedded;
  const StockInScreen({
    super.key,
    required this.user,
    this.embedded = false,
  });

  @override
  State<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends State<StockInScreen> {
  final _itemController = TextEditingController();
  final _qtyController = TextEditingController();
  final _costController = TextEditingController();
  final _supplierController = TextEditingController();
  final _fs = FirestoreService();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_itemController.text.isEmpty ||
        _qtyController.text.isEmpty ||
        _costController.text.isEmpty ||
        _supplierController.text.isEmpty) {
      _showSnack('Please fill in all fields', isError: true);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await _fs.addStockIn(
        itemName: _itemController.text,
        qtyReceived: int.parse(_qtyController.text),
        unitCost: double.parse(_costController.text),
        supplier: _supplierController.text,
        receivedBy: widget.user.name,
      );
      _showSnack('Stock In recorded successfully!');
      _clearForm();

      // After recording stock in, offer to add a comment
      if (mounted) {
        final latestDoc = await FirebaseFirestore.instance
            .collection('stock_in')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
        if (latestDoc.docs.isNotEmpty && mounted) {
          CommentsSheet.show(
            context,
            transactionId: latestDoc.docs.first.id,
            transactionInfo:
            'Stock In — ${latestDoc.docs.first.data()['itemName']}',
            collection: 'stock_in',
            user: widget.user,
          );
        }
      }
    } catch (e) {
      _showSnack('Error: Check your inputs', isError: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _clearForm() {
    _itemController.clear();
    _qtyController.clear();
    _costController.clear();
    _supplierController.clear();
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
    _costController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ItemNameAutocomplete(controller: _itemController),
          const SizedBox(height: 16),
          AppFormField(
              label: 'Quantity Received',
              controller: _qtyController,
              keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          AppFormField(
              label: 'Unit Cost (₦)',
              controller: _costController,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true)),
          const SizedBox(height: 16),
          AppFormField(
              label: 'Supplier Name',
              controller: _supplierController),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.person, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text('Received by: ${widget.user.name}',
                  style: const TextStyle(color: Colors.grey)),
            ]),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Text('Submit Stock In',
                style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Stock In'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: body,
    );
  }
}

// ─── SHARED FORM FIELD — used by all form screens ────────────────

class AppFormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final Function(String)? onChanged;

  const AppFormField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}