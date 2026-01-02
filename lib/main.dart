// main.dart
import 'package:flutter/material.dart';
import 'pages/authentication_pages.dart';
import 'pages/admin_dashboard.dart';
import 'pages/user_dashboard.dart';
import 'services/authentication_service.dart';

void main() {
  runApp(const WaterQualityApp());
}

class WaterQualityApp extends StatelessWidget {
  const WaterQualityApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthenticationService();
    
    // Check if user is already logged in
    final currentUser = authService.currentUser;
    Widget home;
    
    if (currentUser != null) {
      // Determine if user is admin (has more than 1 device)
      if (currentUser.deviceCount > 1) {
        home = AdminDashboard(user: currentUser);
      } else {
        home = UserDashboard(user: currentUser);
      }
    } else {
      home = const EnhancedLoginPage();
    }

    return MaterialApp(
      title: 'Water Quality Monitor',
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
