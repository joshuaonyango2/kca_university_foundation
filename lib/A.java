// lib/main_admin.dart
// 🔐 ADMIN APP - SEPARATE ENTRY POINT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/campaign_provider.dart';
import 'providers/admin_provider.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'config/routes.dart';

void main() {
  runApp(const KCAAdminApp());
}

class KCAAdminApp extends StatelessWidget {
  const KCAAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CampaignProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: MaterialApp(
        title: 'KCA Admin Portal',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E3A8A),
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
          ),
        ),
        initialRoute: AppRoutes.adminLogin,
        onGenerateRoute: _generateAdminRoute,
      ),
    );
  }

  Route<dynamic>? _generateAdminRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.adminLogin:
        return MaterialPageRoute(
          builder: (_) => const AdminLoginScreen(),
        );
      
      case AppRoutes.adminDashboard:
        return MaterialPageRoute(
          builder: (_) => const AdminDashboardScreen(),
        );
      
      default:
        return MaterialPageRoute(
          builder: (_) => const AdminLoginScreen(),
        );
    }
  }
}