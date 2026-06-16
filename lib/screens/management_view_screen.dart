import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'inventory_screen.dart';
import 'all_sales_screen.dart';
import 'daily_report_screen.dart';

class ManagementViewScreen extends StatefulWidget {
  final UserModel user;
  const ManagementViewScreen({super.key, required this.user});

  @override
  State<ManagementViewScreen> createState() =>
      _ManagementViewScreenState();
}

class _ManagementViewScreenState
    extends State<ManagementViewScreen> {
  int _currentIndex = 0;

  final List<String> _titles = [
    'Dashboard',
    'Inventory',
    'Sales Records',
    'Daily Report',
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _ManagementDashboard(user: widget.user),
      InventoryTab(user: widget.user),
      // Pass user so AllSalesTab knows not to show edit dialog
      AllSalesTab(user: widget.user),
      DailyReportTab(user: widget.user),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_titles[_currentIndex],
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const Text('G-Technology Sales Tracker',
                style: TextStyle(
                    fontSize: 10, color: Colors.white54)),
          ],
        ),
        actions: [
          // View only badge
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber),
            ),
            child: const Text('VIEW ONLY',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber)),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1A237E),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Report',
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content:
        const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => AuthService().signOut(),
              child: const Text('Sign Out')),
        ],
      ),
    );
  }
}

// ─── MANAGEMENT DASHBOARD (Read Only) ────────────────────────────

class _ManagementDashboard extends StatelessWidget {
  final UserModel user;
  const _ManagementDashboard({required this.user});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final currency =
    NumberFormat.currency(symbol: '₦', decimalDigits: 2);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF1A237E),
                radius: 24,
                child: Text(
                  user.name.isNotEmpty
                      ? user.name[0].toUpperCase()
                      : 'M',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text('Welcome, ${user.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text(
                      DateFormat('EEEE, MMM d yyyy')
                          .format(DateTime.now()),
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.amber.shade300),
                      ),
                      child: const Text('Management — View Only',
                          style: TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
            ]),
          ),
          const SizedBox(height: 16),

          // Today Revenue
          StreamBuilder<QuerySnapshot>(
            stream: fs.getTodaySalesStream(),
            builder: (context, snap) {
              double total = 0;
              int count = 0;
              if (snap.hasData) {
                count = snap.data!.docs.length;
                for (var doc in snap.data!.docs) {
                  final d = doc.data() as Map<String, dynamic>;
                  total +=
                      (d['totalAmount'] as num? ?? 0).toDouble();
                }
              }
              return _ROStatCard(
                title: "Today's Revenue",
                value: currency.format(total),
                subtitle: '$count transactions',
                icon: Icons.trending_up,
                color: Colors.green,
              );
            },
          ),
          const SizedBox(height: 12),

          // Payment breakdown
          StreamBuilder<QuerySnapshot>(
            stream: fs.getTodaySalesStream(),
            builder: (context, snap) {
              double cash = 0, pos = 0, transfer = 0;
              if (snap.hasData) {
                for (var doc in snap.data!.docs) {
                  final d =
                  doc.data() as Map<String, dynamic>;
                  final amt =
                  (d['totalAmount'] as num? ?? 0).toDouble();
                  if (d['paymentMethod'] == 'Cash') cash += amt;
                  if (d['paymentMethod'] == 'POS') pos += amt;
                  if (d['paymentMethod'] == 'Transfer')
                    transfer += amt;
                }
              }
              return Row(children: [
                Expanded(
                    child: _MiniROCard(
                        label: 'Cash',
                        value: currency.format(cash),
                        color: Colors.blue)),
                const SizedBox(width: 8),
                Expanded(
                    child: _MiniROCard(
                        label: 'POS',
                        value: currency.format(pos),
                        color: Colors.purple)),
                const SizedBox(width: 8),
                Expanded(
                    child: _MiniROCard(
                        label: 'Transfer',
                        value: currency.format(transfer),
                        color: Colors.orange)),
              ]);
            },
          ),
          const SizedBox(height: 12),

          // Returns
          StreamBuilder<QuerySnapshot>(
            stream: fs.getTodayReturnsStream(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return _ROStatCard(
                title: 'Returns Today',
                value: '$count item(s)',
                subtitle: 'View full list in Records tab',
                icon: Icons.undo,
                color: Colors.orange,
              );
            },
          ),
          const SizedBox(height: 24),

          // Recent sales
          const Text('Recent Sales',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: fs.getSalesStream(),
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('No sales recorded yet.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                );
              }
              final docs = snap.data!.docs.take(10).toList();
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d =
                  docs[i].data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF1A237E),
                        child: Icon(Icons.receipt,
                            color: Colors.white, size: 18),
                      ),
                      title: Text(d['itemName'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${d['cashierName']} • ${d['paymentMethod']} • ${d['date']}'),
                      trailing: Text(
                        currency.format(d['totalAmount'] ?? 0),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 40),
          const Center(
            child: Text('Powered by PRIMENOVA GLOBAL',
                style:
                TextStyle(color: Colors.grey, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _ROStatCard extends StatelessWidget {
  final String title, value, subtitle;
  final IconData icon;
  final Color color;

  const _ROStatCard(
      {required this.title,
        required this.value,
        required this.subtitle,
        required this.icon,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 13)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text(subtitle,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _MiniROCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniROCard(
      {required this.label,
        required this.value,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }
}