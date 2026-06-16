import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'stock_in_screen.dart';
import '../widgets/item_name_autocomplete.dart';
import '../widgets/comments_sheet.dart';

class ReturnsScreen extends StatefulWidget {
  final UserModel user;
  final bool embedded;
  const ReturnsScreen({
    super.key,
    required this.user,
    this.embedded = false,
  });

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  final _itemController = TextEditingController();
  final _qtyController = TextEditingController();
  final _reasonController = TextEditingController();
  String _actionTaken = 'Restocked';
  final _fs = FirestoreService();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_itemController.text.isEmpty ||
        _qtyController.text.isEmpty ||
        _reasonController.text.isEmpty) {
      _showSnack('Please fill in all fields', isError: true);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await _fs.addReturn(
        itemName: _itemController.text,
        qtyReturned: int.parse(_qtyController.text),
        reason: _reasonController.text,
        actionTaken: _actionTaken,
        processedBy: widget.user.name,
      );
      _showSnack('Return recorded successfully!');
      _itemController.clear();
      _qtyController.clear();
      _reasonController.clear();
      setState(() => _actionTaken = 'Restocked');

      // After recording the return, offer to add a comment
      if (mounted) {
        final latestDoc = await FirebaseFirestore.instance
            .collection('returns')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
        if (latestDoc.docs.isNotEmpty && mounted) {
          CommentsSheet.show(
            context,
            transactionId: latestDoc.docs.first.id,
            transactionInfo:
            'Return — ${latestDoc.docs.first.data()['itemName']}',
            collection: 'returns',
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
    _reasonController.dispose();
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
              label: 'Quantity Returned',
              controller: _qtyController,
              keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          AppFormField(
              label: 'Reason for Return',
              controller: _reasonController,
              maxLines: 3),
          const SizedBox(height: 16),
          const Text('Action Taken',
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              'Restocked',
              'Refund Given',
              'Exchanged',
              'Pending'
            ].map((action) {
              final selected = _actionTaken == action;
              return GestureDetector(
                onTap: () => setState(() => _actionTaken = action),
                child: Chip(
                  label: Text(action),
                  backgroundColor: selected
                      ? Colors.orange.shade700
                      : Colors.grey.shade200,
                  labelStyle: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.grey.shade700),
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.person, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text('Processed by: ${widget.user.name}',
                  style: const TextStyle(color: Colors.grey)),
            ]),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700),
            child: _isSubmitting
                ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Text('Submit Return',
                style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Return'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: body,
    );
  }
}