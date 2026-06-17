import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';

class AllRecordsScreen extends StatefulWidget {
  final UserModel user;
  const AllRecordsScreen({super.key, required this.user});

  @override
  State<AllRecordsScreen> createState() => _AllRecordsScreenState();
}

class _AllRecordsScreenState extends State<AllRecordsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currency = NumberFormat.currency(symbol: '₦', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Confirm and delete any document
  void _confirmDelete(BuildContext context, DocumentSnapshot doc,
      String recordTitle) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Record?'),
        content: Text('Delete "$recordTitle"?\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
            ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await doc.reference.delete();
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Record deleted'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('All Records',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            Text('Manager — Delete Access',
                style: TextStyle(fontSize: 10, color: Colors.white54)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.add_box, size: 18), text: 'Stock In'),
            Tab(icon: Icon(Icons.undo, size: 18), text: 'Returns'),
            Tab(icon: Icon(Icons.fact_check, size: 18), text: 'Verify'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _StockInRecords(
              user: widget.user,
              currency: _currency,
              onDelete: _confirmDelete),
          _ReturnsRecords(
              user: widget.user, onDelete: _confirmDelete),
          _VerificationRecords(
              user: widget.user, onDelete: _confirmDelete),
        ],
      ),
    );
  }
}

// ─── STOCK IN RECORDS ─────────────────────────────────────────────

class _StockInRecords extends StatelessWidget {
  final UserModel user;
  final NumberFormat currency;
  final Function(BuildContext, DocumentSnapshot, String) onDelete;

  const _StockInRecords(
      {required this.user,
        required this.currency,
        required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stock_in')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text('No stock in records yet.',
                style: TextStyle(color: Colors.grey)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return _RecordCard(
              icon: Icons.add_box,
              iconColor: const Color(0xFF1565C0),
              title: d['itemName'] ?? '',
              line1:
              '${d['date']} • Qty: ${d['qtyReceived']} • By: ${d['receivedBy']}',
              line2: 'Supplier: ${d['supplier']}',
              trailing: currency.format(d['totalValue'] ?? 0),
              trailingColor: Colors.blue,
              onDelete: () => onDelete(
                context,
                docs[i],
                '${d['itemName']} — ${d['date']}',
              ),
            );
          },
        );
      },
    );
  }
}

// ─── RETURNS RECORDS ──────────────────────────────────────────────

class _ReturnsRecords extends StatelessWidget {
  final UserModel user;
  final Function(BuildContext, DocumentSnapshot, String) onDelete;

  const _ReturnsRecords(
      {required this.user, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('returns')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text('No returns records yet.',
                style: TextStyle(color: Colors.grey)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return _RecordCard(
              icon: Icons.assignment_return,
              iconColor: Colors.orange.shade700,
              title: d['itemName'] ?? '',
              line1:
              '${d['date']} • Qty: ${d['qtyReturned']} • By: ${d['processedBy']}',
              line2:
              'Reason: ${d['reason']} • Action: ${d['actionTaken']}',
              trailing: d['actionTaken'] ?? '',
              trailingColor: Colors.orange,
              onDelete: () => onDelete(
                context,
                docs[i],
                '${d['itemName']} return — ${d['date']}',
              ),
            );
          },
        );
      },
    );
  }
}

// ─── STOCK VERIFICATION RECORDS ──────────────────────────────────

class _VerificationRecords extends StatelessWidget {
  final UserModel user;
  final Function(BuildContext, DocumentSnapshot, String) onDelete;

  const _VerificationRecords(
      {required this.user, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stock_verification')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text('No verification records yet.',
                style: TextStyle(color: Colors.grey)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final diff = (d['difference'] as num? ?? 0).toInt();
            final diffColor = diff == 0
                ? Colors.green
                : diff > 0
                ? Colors.orange
                : Colors.red;
            final diffText = diff == 0
                ? 'Perfect match'
                : diff > 0
                ? 'Surplus: +$diff'
                : 'Shortage: $diff';

            return _RecordCard(
              icon: Icons.fact_check,
              iconColor: Colors.purple.shade700,
              title: d['itemName'] ?? '',
              line1:
              '${d['date']} • System: ${d['systemQty']} • Counted: ${d['physicalCount']}',
              line2: 'Verified by: ${d['verifiedBy']}',
              trailing: diffText,
              trailingColor: diffColor,
              onDelete: () => onDelete(
                context,
                docs[i],
                '${d['itemName']} verification — ${d['date']}',
              ),
            );
          },
        );
      },
    );
  }
}

// ─── SHARED RECORD CARD ───────────────────────────────────────────

class _RecordCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, line1, line2, trailing;
  final Color trailingColor;
  final VoidCallback onDelete;

  const _RecordCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.line1,
    required this.line2,
    required this.trailing,
    required this.trailingColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line1,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(line2,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(trailing,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: trailingColor,
                    fontSize: 12)),
            const SizedBox(width: 4),
            // Delete button — manager only
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 20),
              onPressed: onDelete,
              tooltip: 'Delete record',
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}