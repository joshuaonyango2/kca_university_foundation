// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/campaign_provider.dart';

// Config
import 'config/routes.dart';

// Screens
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/campaign/campaign_detail_screen.dart';
import 'screens/profile/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MyApp({Key? key, required this.prefs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(prefs: prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => CampaignProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'KCA Foundation',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        initialRoute: AppRoutes.splash,
        routes: _buildRoutes(),
      ),
    );
  }

  // Build theme
  ThemeData _buildTheme() {
    return ThemeData(
      primaryColor: const Color(0xFF1E3A8A),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E3A8A),
        primary: const Color(0xFF1E3A8A),
        secondary: const Color(0xFF2563EB),
      ),
      useMaterial3: true,

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),

      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  // Build routes
  Map<String, WidgetBuilder> _buildRoutes() {
    return {
      AppRoutes.splash: (context) => const SplashScreen(),
      AppRoutes.login: (context) => const LoginScreen(),
      AppRoutes.register: (context) => const RegisterScreen(),
      AppRoutes.home: (context) => const HomeScreen(),
      AppRoutes.profile: (context) => const ProfileScreen(),

      // Admin routes
      AppRoutes.adminLogin: (context) => const AdminLoginScreen(),
      AppRoutes.adminDashboard: (context) => const AdminDashboardScreen(),
    };
  }
}