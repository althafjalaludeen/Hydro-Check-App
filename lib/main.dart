// main.dart
import 'package:flutter/material.dart';
import 'pages/authentication_pages.dart';
import 'pages/admin_dashboard.dart';
import 'pages/user_dashboard.dart';
import 'pages/subordinate_dashboard.dart';
import 'services/firebase_authentication_service.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('🚀 Initializing App...');
    // Initialize Firebase
    print('📂 Initializing Firebase...');
    await FirebaseService.initializeFirebase();
    print('✅ Firebase Initialized.');

    // Check if user is already logged in
    print('🔐 Checking Auth Status...');
    final authService = FirebaseAuthenticationService();
    await authService.checkAuthStatus();
    print('✅ Auth Status Checked.');

    print('🏗️ Starting App UI...');
    runApp(const HydroCheckApp());
  } catch (e) {
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Initialization Failed',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 24),
                const Text(
                  'If running on Web, ensure you have updated lib/services/firebase_options.dart with your Web configuration keys.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

class HydroCheckApp extends StatelessWidget {
  const HydroCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = FirebaseAuthenticationService();

    // Check if user is already logged in
    final currentUser = authService.currentUser;
    Widget home;

    if (currentUser != null) {
      // 3-role routing
      switch (currentUser.role) {
        case 'admin':
          home = AdminDashboard(user: currentUser);
          break;
        case 'subordinate':
          home = SubordinateDashboard(user: currentUser);
          break;
        default:
          home = UserDashboard(user: currentUser);
          break;
      }
    } else {
      home = const EnhancedLoginPage();
    }

    return MaterialApp(
      title: 'HydroCheck - Smart Water Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: home,
      routes: {
        '/login': (context) => const EnhancedLoginPage(),
        '/register': (context) => const EnhancedRegistrationPage(),
        '/admin-dashboard': (context) {
          final user = authService.currentUser;
          return user != null
              ? AdminDashboard(user: user)
              : const EnhancedLoginPage();
        },
        '/subordinate-dashboard': (context) {
          final user = authService.currentUser;
          return user != null
              ? SubordinateDashboard(user: user)
              : const EnhancedLoginPage();
        },
        '/user-dashboard': (context) {
          final user = authService.currentUser;
          return user != null
              ? UserDashboard(user: user)
              : const EnhancedLoginPage();
        },
      },
    );
  }
}
