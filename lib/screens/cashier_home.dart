import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'sales_entry_screen.dart';
import 'returns_screen.dart';

class CashierHome extends StatefulWidget {
  final UserModel user;
  const CashierHome({super.key, required this.user});

  @override
  State<CashierHome> createState() => _CashierHomeState();
}

class _CashierHomeState extends State<CashierHome> {
  int _currentIndex = 0;

  final List<String> _titles = ['Record Sale', 'Record Return'];

  @override
  Widget build(BuildContext context) {
    final tabs = [
      SalesEntryScreen(user: widget.user, embedded: true),
      ReturnsScreen(user: widget.user, embedded: true),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
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
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => AuthService().signOut()),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: Colors.green.shade700,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_outlined),
            activeIcon: Icon(Icons.point_of_sale),
            label: 'Sales',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_return_outlined),
            activeIcon: Icon(Icons.assignment_return),
            label: 'Returns',
          ),
        ],
      ),
    );
  }
}