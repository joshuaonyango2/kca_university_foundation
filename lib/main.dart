// lib/main.dart
// spell-checker: disable
//
// KCA University Foundation — App entry point.
// Firebase init, providers, theme, routing.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/campaign_provider.dart';
import 'providers/staff_provider.dart';

// Config
import 'config/routes.dart';
import 'firebase_options.dart';

// ─────────────────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase before anything else
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

// ── Root widget ───────────────────────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth — handles login, Google Sign-In, session persistence
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        // Campaigns — Firestore stream of active campaigns
        ChangeNotifierProvider(
          create: (_) => CampaignProvider(),
        ),
        // Staff / RBAC — roles, permissions, staff onboarding
        ChangeNotifierProvider(
          create: (_) => StaffProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'KCA University Foundation',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),

        // ── Routing ──────────────────────────────────────────────────────────
        initialRoute: AppRoutes.splash,

        // ✅ FIX: AppRouter.generateRoute (not AppRoutes — that's just constants)
        onGenerateRoute: AppRouter.generateRoute,

        // Fallback for unknown routes
        onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (_) => _NotFoundPage(routeName: settings.name ?? ''),
        ),
      ),
    );
  }

  // ── App theme ─────────────────────────────────────────────────────────────
  static ThemeData _buildTheme() {
    const navy = Color(0xFF1B2263);
    const gold = Color(0xFFF5A800);

    return ThemeData(
      useMaterial3: true,
      primaryColor: navy,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: navy,
        secondary: gold,
        surface: Colors.white,
        // background deprecated after v3.18 — use surface instead
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // Outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          side: const BorderSide(color: navy),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: navy,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: navy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        labelStyle: const TextStyle(color: Colors.grey),
        hintStyle: TextStyle(color: Colors.grey[400]),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFEEF0F8),
        selectedColor: navy,
        labelStyle: const TextStyle(fontSize: 12, color: navy),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
      ),

      // Bottom nav bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: navy,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Snackbars
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1F2937),
        contentTextStyle: const TextStyle(
            color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),

      // Dividers
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E7EB),
        thickness: 1,
        space: 1,
      ),

      // Progress indicators
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: navy,
        linearTrackColor: Color(0xFFE5E7EB),
      ),

      // Tab bar
      tabBarTheme: const TabBarThemeData(
        labelColor: navy,
        unselectedLabelColor: Colors.grey,
        indicatorColor: navy,
        labelStyle: TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: TextStyle(fontSize: 13),
      ),
    );
  }
}

// ── 404 page ──────────────────────────────────────────────────────────────────
class _NotFoundPage extends StatelessWidget {
  final String routeName;
  const _NotFoundPage({required this.routeName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 64, color: Color(0xFF1B2263)),
            const SizedBox(height: 16),
            const Text('Page not found',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B2263))),
            const SizedBox(height: 8),
            Text(routeName,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context, AppRoutes.splash, (_) => false),
              icon: const Icon(Icons.home_outlined, size: 18),
              label: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}