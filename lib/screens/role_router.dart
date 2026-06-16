// ============================================================
// ROLE ROUTER
// Reads the logged-in user's role from Firestore and routes
// them to the correct home screen.
//
// Routing map:
//   manager    → ManagerHome     (5-tab bottom nav, full access)
//   view_only  → ManagementViewScreen (4-tab read-only view)
//   stock_rep  → StockRepHome    (2-tab: Stock In + Verify)
//   cashier    → CashierHome     (2-tab: Sales + Returns)
//   backup     → BackupRepHome   (4-tab: all forms)
//   (other)    → Unassigned screen (contact manager message)
//
// If the Firestore user document doesn't exist,
// the user is signed out automatically.
// ============================================================

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'manager_home.dart';
import 'management_view_screen.dart';
import 'stock_rep_home.dart';
import 'cashier_home.dart';
import 'backup_rep_home.dart';

class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      // Fetch the current user's profile (name, email, role) from Firestore
      future: AuthService().getCurrentUserModel(),
      builder: (context, snapshot) {
        // Show loading while Firestore fetches the user document
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;

        // If user document not found in Firestore, sign out.
        // This happens when Firebase Auth has the account but
        // the manager hasn't created the Firestore document yet.
        if (user == null) {
          AuthService().signOut();
          return const Scaffold(
            body: Center(
                child: Text('Account not found. Contact manager.')),
          );
        }

        // Route based on role
        switch (user.role) {
          case 'manager':
            return ManagerHome(user: user);
          case 'view_only':
            return ManagementViewScreen(user: user);
          case 'stock_rep':
            return StockRepHome(user: user);
          case 'cashier':
            return CashierHome(user: user);
          case 'backup':
            return BackupRepHome(user: user);
          default:
          // Role not recognized — show a clear message
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.block, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('No role assigned.',
                        style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text('Contact your manager.',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => AuthService().signOut(),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}