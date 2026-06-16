import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'stock_in_screen.dart';
import 'stock_verification_screen.dart';

class StockRepHome extends StatefulWidget {
  final UserModel user;
  const StockRepHome({super.key, required this.user});

  @override
  State<StockRepHome> createState() => _StockRepHomeState();
}

class _StockRepHomeState extends State<StockRepHome> {
  int _currentIndex = 0;

  final List<String> _titles = ['Stock In', 'Verify Stock'];

  @override
  Widget build(BuildContext context) {
    final tabs = [
      StockInScreen(user: widget.user, embedded: true),
      StockVerificationScreen(user: widget.user, embedded: true),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
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
        selectedItemColor: const Color(0xFF1565C0),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            activeIcon: Icon(Icons.add_box),
            label: 'Stock In',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fact_check_outlined),
            activeIcon: Icon(Icons.fact_check),
            label: 'Verify Stock',
          ),
        ],
      ),
    );
  }
}