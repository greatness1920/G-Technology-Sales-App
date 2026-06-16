import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/excel_service.dart';

class DailyReportTab extends StatefulWidget {
  final UserModel user;
  const DailyReportTab({super.key, required this.user});

  @override
  State<DailyReportTab> createState() => _DailyReportTabState();
}

class _DailyReportTabState extends State<DailyReportTab> {
  DateTime _selectedDate = DateTime.now();
  final _currency = NumberFormat.currency(symbol: '₦', decimalDigits: 2);
  final _excel = ExcelService();
  bool _exporting = false;

  String get _dateStr =>
      DateFormat('yyyy-MM-dd').format(_selectedDate);
  String get _displayDate =>
      DateFormat('EEEE, MMMM d yyyy').format(_selectedDate);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF0D47A1),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _exportReport() async {
    setState(() => _exporting = true);
    final result = await _excel.exportDailyReport(_selectedDate);
    setState(() => _exporting = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Daily Sales Report'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.download),
            tooltip: 'Export to Excel',
            onPressed: _exporting ? null : _exportReport,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date picker bar
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              color: const Color(0xFF1565C0),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _displayDate,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_drop_down, color: Colors.white70),
                ],
              ),
            ),
          ),

          // Report content
          Expanded(
            child: FutureBuilder<List<QuerySnapshot>>(
              future: Future.wait([
                FirebaseFirestore.instance
                    .collection('sales')
                    .where('date', isEqualTo: _dateStr)
                    .get(),
                FirebaseFirestore.instance
                    .collection('returns')
                    .where('date', isEqualTo: _dateStr)
                    .get(),
                FirebaseFirestore.instance
                    .collection('stock_in')
                    .where('date', isEqualTo: _dateStr)
                    .get(),
              ]),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final salesDocs = snap.data![0].docs;
                final returnsDocs = snap.data![1].docs;
                final stockInDocs = snap.data![2].docs;

                // Calculate totals
                double total = 0, cash = 0, pos = 0,
                    transfer = 0, credit = 0;
                for (var doc in salesDocs) {
                  final d = doc.data() as Map<String, dynamic>;
                  final amt =
                  (d['totalAmount'] as num? ?? 0).toDouble();
                  total += amt;
                  final method = d['paymentMethod'] ?? '';
                  if (method == 'Cash') cash += amt;
                  if (method == 'POS') pos += amt;
                  if (method == 'Transfer') transfer += amt;
                  if (method == 'Credit') credit += amt;
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total Revenue
                      _SummaryCard(
                        icon: Icons.attach_money,
                        title: 'Total Revenue',
                        value: _currency.format(total),
                        subtitle: '${salesDocs.length} transactions',
                        color: Colors.green,
                      ),
                      const SizedBox(height: 12),

                      // Payment breakdown
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Payment Breakdown',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            const SizedBox(height: 12),
                            _PayRow('Cash', cash, Colors.blue, _currency),
                            _PayRow('POS', pos, Colors.purple, _currency),
                            _PayRow('Transfer', transfer, Colors.orange,
                                _currency),
                            _PayRow('Credit', credit, Colors.red, _currency),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Sales transactions
                      _SectionHeader(
                          'Sales Transactions (${salesDocs.length})'),
                      const SizedBox(height: 8),
                      if (salesDocs.isEmpty)
                        _EmptyCard('No sales recorded on this date')
                      else
                        ...salesDocs.map((doc) {
                          final d =
                          doc.data() as Map<String, dynamic>;
                          return _TransactionCard(
                            title: d['itemName'] ?? '',
                            subtitle:
                            '${d['cashierName']} • ${d['paymentMethod']} • Qty: ${d['qtySold']}',
                            amount:
                            _currency.format(d['totalAmount'] ?? 0),
                            amountColor: Colors.green,
                            icon: Icons.receipt,
                            iconColor: Colors.blue,
                          );
                        }),

                      const SizedBox(height: 16),

                      // Stock In for this date
                      if (stockInDocs.isNotEmpty) ...[
                        _SectionHeader(
                            'Stock Received (${stockInDocs.length})'),
                        const SizedBox(height: 8),
                        ...stockInDocs.map((doc) {
                          final d =
                          doc.data() as Map<String, dynamic>;
                          return _TransactionCard(
                            title: d['itemName'] ?? '',
                            subtitle:
                            '${d['supplier']} • Qty: ${d['qtyReceived']} • Received by: ${d['receivedBy']}',
                            amount: _currency.format(
                                d['totalValue'] ?? 0),
                            amountColor: Colors.blue,
                            icon: Icons.add_box,
                            iconColor: Colors.blue,
                          );
                        }),
                        const SizedBox(height: 16),
                      ],

                      // Returns
                      if (returnsDocs.isNotEmpty) ...[
                        _SectionHeader(
                            'Returns (${returnsDocs.length})'),
                        const SizedBox(height: 8),
                        ...returnsDocs.map((doc) {
                          final d =
                          doc.data() as Map<String, dynamic>;
                          return _TransactionCard(
                            title: d['itemName'] ?? '',
                            subtitle:
                            '${d['reason']} • ${d['actionTaken']}',
                            amount: 'Qty: ${d['qtyReturned']}',
                            amountColor: Colors.orange,
                            icon: Icons.undo,
                            iconColor: Colors.orange,
                          );
                        }),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title, value, subtitle;
  final Color color;

  const _SummaryCard(
      {required this.icon,
        required this.title,
        required this.value,
        required this.subtitle,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
              const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          Text(subtitle,
              style:
              const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      ]),
    );
  }
}

class _PayRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final NumberFormat currency;

  const _PayRow(this.label, this.amount, this.color, this.currency);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration:
            BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 14)),
        const Spacer(),
        Text(currency.format(amount),
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 14)),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style:
        const TextStyle(fontWeight: FontWeight.bold, fontSize: 15));
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Text(message,
            style: const TextStyle(color: Colors.grey)),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final String title, subtitle, amount;
  final Color amountColor, iconColor;
  final IconData icon;

  const _TransactionCard(
      {required this.title,
        required this.subtitle,
        required this.amount,
        required this.amountColor,
        required this.iconColor,
        required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style:
            const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: Text(amount,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: amountColor)),
      ),
    );
  }
}