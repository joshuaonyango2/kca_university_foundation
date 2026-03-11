// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/campaign_provider.dart';
import 'providers/staff_provider.dart';

// Config
import 'config/routes.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase FIRST
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();

  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  const MyApp({super.key, required this.prefs});

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
        ChangeNotifierProvider(          // ✅ Staff / RBAC provider
          create: (_) => StaffProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'KCA University Foundation',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),

        // ✅ Use onGenerateRoute — handles ALL routes including ones with arguments
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.generateRoute,

        // ✅ Fallback for any unknown route
        onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Page not found: ${settings.name}'),
            ),
          ),
        ),
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      primaryColor: const Color(0xFF1B2263),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1B2263),
        primary: const Color(0xFF1B2263),
        secondary: const Color(0xFFF5A800),
      ),
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B2263),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1B2263),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}