import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ItemNameAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String label;

  const ItemNameAutocomplete({
    super.key,
    required this.controller,
    this.label = 'Item Name',
  });

  @override
  State<ItemNameAutocomplete> createState() =>
      _ItemNameAutocompleteState();
}

class _ItemNameAutocompleteState
    extends State<ItemNameAutocomplete> {
  List<String> _inventoryItems = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final snap = await FirebaseFirestore.instance
        .collection('inventory')
        .orderBy('name')
        .get();
    if (mounted) {
      setState(() {
        _inventoryItems = snap.docs
            .map((d) => (d.data()['name'] ?? '').toString())
            .where((n) => n.isNotEmpty)
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: FocusNode(),
      optionsBuilder: (TextEditingValue value) {
        if (value.text.isEmpty) return const [];
        return _inventoryItems.where((item) =>
            item.toLowerCase().contains(value.text.toLowerCase()));
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.grey.shade50,
            suffixIcon: const Icon(Icons.arrow_drop_down,
                color: Colors.grey),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final option = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.inventory_2_outlined,
                        size: 16, color: Colors.grey),
                    title: Text(option,
                        style: const TextStyle(fontSize: 14)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}