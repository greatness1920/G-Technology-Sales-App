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
      future: AuthService().getCurrentUserModel(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;

        if (user == null) {
          AuthService().signOut();
          return const Scaffold(
            body: Center(
                child:
                Text('Account not found. Contact manager.')),
          );
        }

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
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.block,
                        size: 64, color: Colors.grey),
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