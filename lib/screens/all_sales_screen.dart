import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import 'stock_in_screen.dart';

class AllSalesTab extends StatefulWidget {
  final UserModel user;
  const AllSalesTab({super.key, required this.user});

  @override
  State<AllSalesTab> createState() => _AllSalesTabState();
}

class _AllSalesTabState extends State<AllSalesTab> {
  final _currency =
  NumberFormat.currency(symbol: '₦', decimalDigits: 2);
  String _filterPayment = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  final List<String> _paymentFilters = [
    'All', 'Cash', 'POS', 'Transfer', 'Credit'
  ];

  void _showEditDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final itemCtrl =
    TextEditingController(text: data['itemName'] ?? '');
    final qtyCtrl = TextEditingController(
        text: data['qtySold']?.toString() ?? '');
    final priceCtrl = TextEditingController(
        text: data['unitPrice']?.toString() ?? '');
    final receiptCtrl =
    TextEditingController(text: data['receiptNo'] ?? '');
    final cashierCtrl =
    TextEditingController(text: data['cashierName'] ?? '');
    String paymentMethod = data['paymentMethod'] ?? 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Sale Record'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('Date: ${data['date']}',
                        style:
                        const TextStyle(color: Colors.grey)),
                  ]),
                ),
                const SizedBox(height: 12),
                AppFormField(
                    label: 'Item Name', controller: itemCtrl),
                const SizedBox(height: 12),
                AppFormField(
                    label: 'Qty Sold',
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                AppFormField(
                    label: 'Unit Price (₦)',
                    controller: priceCtrl,
                    keyboardType:
                    const TextInputType.numberWithOptions(
                        decimal: true)),
                const SizedBox(height: 12),
                AppFormField(
                    label: 'Cashier Name',
                    controller: cashierCtrl),
                const SizedBox(height: 12),
                AppFormField(
                    label: 'Receipt No',
                    controller: receiptCtrl),
                const SizedBox(height: 12),
                const Text('Payment Method',
                    style:
                    TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children:
                  ['Cash', 'POS', 'Transfer', 'Credit']
                      .map((m) {
                    final selected = paymentMethod == m;
                    return GestureDetector(
                      onTap: () => setDialogState(
                              () => paymentMethod = m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.green.shade700
                              : Colors.grey.shade200,
                          borderRadius:
                          BorderRadius.circular(8),
                        ),
                        child: Text(m,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            )),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _confirmDelete(ctx, doc),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final qty = int.tryParse(qtyCtrl.text) ?? 0;
                final price =
                    double.tryParse(priceCtrl.text) ?? 0.0;
                await doc.reference.update({
                  'itemName': itemCtrl.text.trim(),
                  'qtySold': qty,
                  'unitPrice': price,
                  'totalAmount': qty * price,
                  'paymentMethod': paymentMethod,
                  'cashierName': cashierCtrl.text.trim(),
                  'receiptNo': receiptCtrl.text.trim(),
                  'editedBy': widget.user.name,
                  'editedAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _showSnack('Sale updated successfully');
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, DocumentSnapshot doc) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete Sale Record?'),
        content: const Text(
            'This cannot be undone. Are you sure you want to delete this record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () async {
              await doc.reference.delete();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                Navigator.pop(ctx);
              }
              _showSnack('Record deleted');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Color _paymentColor(String method) {
    switch (method) {
      case 'Cash':
        return Colors.blue;
      case 'POS':
        return Colors.purple;
      case 'Transfer':
        return Colors.orange;
      case 'Credit':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Container(
          color: const Color(0xFF0D47A1),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (val) =>
                setState(() => _searchQuery = val.toLowerCase()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by item or cashier...',
              hintStyle:
              const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search,
                  color: Colors.white54),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear,
                    color: Colors.white54),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Payment filter chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _paymentFilters.map((filter) {
                final selected = _filterPayment == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _filterPayment = filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF0D47A1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : Colors.grey.shade700,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Sales list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sales')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator());
              }

              var docs = snap.data!.docs;

              if (_filterPayment != 'All') {
                docs = docs.where((doc) {
                  final d =
                  doc.data() as Map<String, dynamic>;
                  return d['paymentMethod'] == _filterPayment;
                }).toList();
              }

              if (_searchQuery.isNotEmpty) {
                docs = docs.where((doc) {
                  final d =
                  doc.data() as Map<String, dynamic>;
                  final item =
                  (d['itemName'] ?? '').toLowerCase();
                  final cashier =
                  (d['cashierName'] ?? '').toLowerCase();
                  return item.contains(_searchQuery) ||
                      cashier.contains(_searchQuery);
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No results for "$_searchQuery"'
                            : 'No sales records found',
                        style: const TextStyle(
                            color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              double filteredTotal =
              docs.fold(0.0, (sum, doc) {
                final d = doc.data() as Map<String, dynamic>;
                return sum +
                    (d['totalAmount'] as num? ?? 0).toDouble();
              });

              return Column(
                children: [
                  // Summary bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: Colors.grey.shade200,
                    child: Row(children: [
                      Text(
                        '${docs.length} record${docs.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        'Total: ${_currency.format(filteredTotal)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1)),
                      ),
                    ]),
                  ),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i].data()
                        as Map<String, dynamic>;
                        final wasEdited = d['editedBy'] != null;

                        return GestureDetector(
                          onTap: () {
                            // Only manager can edit
                            // view_only management cannot
                            if (widget.user.isManager) {
                              _showEditDialog(docs[i]);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(
                                bottom: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                              BorderRadius.circular(10),
                              border: wasEdited
                                  ? Border.all(
                                  color:
                                  Colors.amber.shade300,
                                  width: 1)
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _paymentColor(
                                    d['paymentMethod'] ?? '')
                                    .withOpacity(0.1),
                                child: Icon(
                                  Icons.receipt,
                                  size: 18,
                                  color: _paymentColor(
                                      d['paymentMethod'] ?? ''),
                                ),
                              ),
                              title: Row(children: [
                                Expanded(
                                  child: Text(
                                    d['itemName'] ?? '',
                                    style: const TextStyle(
                                        fontWeight:
                                        FontWeight.w600),
                                  ),
                                ),
                                if (wasEdited)
                                  const Tooltip(
                                    message:
                                    'This record was edited',
                                    child: Icon(Icons.edit,
                                        size: 14,
                                        color: Colors.amber),
                                  ),
                                // Show lock icon for view-only users
                                if (!widget.user.isManager)
                                  const Icon(Icons.lock_outline,
                                      size: 14,
                                      color: Colors.grey),
                              ]),
                              subtitle: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${d['date']} • ${d['cashierName']} • Qty: ${d['qtySold']}',
                                    style: const TextStyle(
                                        fontSize: 12),
                                  ),
                                  Row(children: [
                                    Container(
                                      margin:
                                      const EdgeInsets.only(
                                          top: 4),
                                      padding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 8,
                                          vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _paymentColor(
                                            d['paymentMethod'] ??
                                                '')
                                            .withOpacity(0.1),
                                        borderRadius:
                                        BorderRadius.circular(
                                            4),
                                      ),
                                      child: Text(
                                        d['paymentMethod'] ?? '',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _paymentColor(
                                              d['paymentMethod'] ??
                                                  ''),
                                          fontWeight:
                                          FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ]),
                                ],
                              ),
                              trailing: Text(
                                _currency.format(
                                    d['totalAmount'] ?? 0),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  fontSize: 14,
                                ),
                              ),
                              isThreeLine: true,
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
        ),
      ],
    );
  }
}