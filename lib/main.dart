// ============================================================
// MAIN ENTRY POINT
// G-Technology Sales Tracker
// Powered by PRIMENOVA GLOBAL
//
// This file initializes Firebase, sets up offline persistence,
// shows the splash screen while loading, then routes to either
// the login screen or the user's role-based dashboard.
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/role_router.dart';

void main() async {
  // Ensure Flutter widgets are initialized before running async code
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Hold the splash screen while Firebase initializes
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);

  // Enable Firestore offline persistence so the app works without internet.
  // Data entered offline will sync automatically when connection is restored.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Dismiss the splash screen now that everything is ready
  FlutterNativeSplash.remove();

  runApp(const GTechSalesApp());
}

/// Root widget of the G-Technology Sales Tracker app.
/// Sets up the global theme and routes to the AuthWrapper.
class GTechSalesApp extends StatelessWidget {
  const GTechSalesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'G-Technology Sales Tracker',
      debugShowCheckedModeBanner: false, // Hide debug banner in all builds
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1), // G-Tech brand blue
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // Global text field styling — applied to all TextFields in the app
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        // Global button styling — applied to all ElevatedButtons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        // Global bottom navigation bar styling
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Color(0xFF0D47A1),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 10,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

/// Listens to Firebase Auth state changes.
/// - If user is logged in → routes to RoleRouter (role-based dashboard)
/// - If user is logged out → routes to LoginScreen
/// This runs automatically whenever auth state changes (login/logout).
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      // Stream that emits whenever login state changes
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // Show loading spinner while waiting for auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D47A1),
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        // User is logged in — go to role-based routing
        if (snapshot.hasData && snapshot.data != null) {
          return const RoleRouter();
        }
        // User is logged out — show login screen
        return const LoginScreen();
      },
    );
  }
}