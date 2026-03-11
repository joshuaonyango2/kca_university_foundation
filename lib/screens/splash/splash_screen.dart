// lib/screens/splash/splash_screen.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToNext();
    });
  }

  Future<void> _navigateToNext() async {
    // On web, respect direct URL navigation (e.g. /#/admin/login)
    if (kIsWeb) {
      final url = Uri.base.fragment;
      if (url.isNotEmpty && url != '/' && url != AppRoutes.splash) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(url);
        return;
      }
    }

    // ✅ Wait for BOTH: minimum 2s splash display AND Firebase auth state restore
    // This is what keeps users logged in between sessions
    await Future.wait([
      Future.delayed(const Duration(seconds: 2)),
      _waitForFirebaseAuth(),
    ]);

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.isAuthenticated) {
      // ✅ Already logged in — go straight to home (no re-login needed)
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  // ✅ Waits for Firebase to emit its first auth state event
  // Without this, currentUser is null on first frame even when logged in
  Future<void> _waitForFirebaseAuth() async {
    try {
      await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Timeout or error — proceed anyway
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2263),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF5A800), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/image.asset.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('KCA',
                        style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B2263))),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text('KCA University Foundation',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Making a Difference Together',
                style: TextStyle(
                    fontSize: 16, color: Colors.white.withAlpha(204))),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF5A800)),
            ),
          ],
        ),
      ),
    );
  }
}