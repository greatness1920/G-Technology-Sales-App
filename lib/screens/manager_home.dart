import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'stock_in_screen.dart';
import 'stock_verification_screen.dart';
import 'sales_entry_screen.dart';
import 'returns_screen.dart';
import 'inventory_screen.dart';
import 'all_sales_screen.dart';
import 'daily_report_screen.dart';
import 'all_records_screen.dart';

class ManagerHome extends StatefulWidget {
  final UserModel user;
  const ManagerHome({super.key, required this.user});

  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> {
  int _currentIndex = 0;

  final List<String> _titles = [
    'Dashboard',
    'Stock',
    'Inventory',
    'Sales',
    'Reports',
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _DashboardTab(user: widget.user),
      _StockTab(user: widget.user),
      InventoryTab(user: widget.user),
      _SalesTab(user: widget.user),
      DailyReportTab(user: widget.user),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titles[_currentIndex],
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const Text(
              'G-Technology Sales Tracker',
              style: TextStyle(fontSize: 10, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0D47A1),
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
            icon: Icon(Icons.add_box_outlined),
            activeIcon: Icon(Icons.add_box),
            label: 'Stock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_outlined),
            activeIcon: Icon(Icons.point_of_sale),
            label: 'Sales',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Reports',
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
        content: const Text('Are you sure you want to sign out?'),
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

// ═══════════════════════════════════════════════════════════
// TAB 1: DASHBOARD
// ═══════════════════════════════════════════════════════════

class _DashboardTab extends StatelessWidget {
  final UserModel user;
  const _DashboardTab({required this.user});

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
          // Welcome row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF0D47A1),
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const Text('Manager',
                      style: TextStyle(
                          color: Color(0xFF0D47A1),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Revenue card
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
              return _StatCard(
                title: "Today's Revenue",
                value: currency.format(total),
                subtitle: '$count transactions today',
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
                  final d = doc.data() as Map<String, dynamic>;
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
                    child: _MiniCard(
                        label: 'Cash',
                        value: currency.format(cash),
                        color: Colors.blue)),
                const SizedBox(width: 8),
                Expanded(
                    child: _MiniCard(
                        label: 'POS',
                        value: currency.format(pos),
                        color: Colors.purple)),
                const SizedBox(width: 8),
                Expanded(
                    child: _MiniCard(
                        label: 'Transfer',
                        value: currency.format(transfer),
                        color: Colors.orange)),
              ]);
            },
          ),
          const SizedBox(height: 12),

          // Returns today
          StreamBuilder<QuerySnapshot>(
            stream: fs.getTodayReturnsStream(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return _StatCard(
                title: 'Returns Today',
                value: '$count item(s) returned',
                subtitle: 'Go to Sales tab to view details',
                icon: Icons.undo,
                color: Colors.orange,
              );
            },
          ),
          const SizedBox(height: 12),

          // All Records — Manager Delete Access
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AllRecordsScreen(user: user)),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.delete_sweep_outlined,
                      color: Colors.red.shade700, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('All Records',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.red.shade700)),
                      const Text(
                          'Delete Sales, Stock In, Returns & Verification',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    color: Colors.red.shade300, size: 16),
              ]),
            ),
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
                  final d = docs[i].data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF0D47A1),
                        child: Icon(Icons.receipt,
                            color: Colors.white, size: 18),
                      ),
                      title: Text(d['itemName'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${d['cashierName']} • ${d['paymentMethod']}'),
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
            child: Text(
              'Powered by PRIMENOVA GLOBAL',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 2: STOCK
// ═══════════════════════════════════════════════════════════

class _StockTab extends StatefulWidget {
  final UserModel user;
  const _StockTab({required this.user});

  @override
  State<_StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<_StockTab> {
  int _subIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SubTabBar(
          options: ['Stock In', 'Verify Stock'],
          selectedIndex: _subIndex,
          onChanged: (i) => setState(() => _subIndex = i),
          activeColor: const Color(0xFF1565C0),
        ),
        Expanded(
          child: IndexedStack(
            index: _subIndex,
            children: [
              StockInScreen(user: widget.user, embedded: true),
              StockVerificationScreen(
                  user: widget.user, embedded: true),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TAB 4: SALES
// ═══════════════════════════════════════════════════════════

class _SalesTab extends StatefulWidget {
  final UserModel user;
  const _SalesTab({required this.user});

  @override
  State<_SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<_SalesTab> {
  int _subIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SubTabBar(
          options: ['New Sale', 'Returns', 'All Records'],
          selectedIndex: _subIndex,
          onChanged: (i) => setState(() => _subIndex = i),
          activeColor: Colors.green.shade700,
        ),
        Expanded(
          child: IndexedStack(
            index: _subIndex,
            children: [
              SalesEntryScreen(
                  user: widget.user, embedded: true),
              ReturnsScreen(user: widget.user, embedded: true),
              AllSalesTab(user: widget.user),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════

class _SubTabBar extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final Function(int) onChanged;
  final Color activeColor;

  const _SubTabBar({
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: List.generate(options.length, (i) {
          final selected = selectedIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                margin: EdgeInsets.only(
                    right: i < options.length - 1 ? 8 : 0),
                padding:
                const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? activeColor
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  options[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Colors.grey.shade600,
                    fontWeight: selected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniCard(
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