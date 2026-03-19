// lib/screens/splash/splash_screen.dart
// spell-checker: disable
//
// Splash screen:
//   1. Shows KCA logo with fade-in animation
//   2. Checks SharedPreferences → if onboarding not done → /onboarding
//   3. Checks Firebase Auth  → if logged in → /home (donor) or /admin/dashboard
//   4. Otherwise → /login
//
// ✅ FIX: firebase_auth internally exports its own 'AuthProvider' class.
//    This collides with the app's AuthProvider from auth_provider.dart.
//    Solution: add  `hide AuthProvider`  to the firebase_auth import so
//    Dart uses only the app's AuthProvider throughout this file.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider; // ✅ FIXED
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 2), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    // 1. Check onboarding completion
    final prefs = await SharedPreferences.getInstance();
    final done  = prefs.getBool('onboarding_done') ?? false;
    if (!mounted) return;

    if (!done) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
      return;
    }

    // 2. Check Firebase Auth state
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;

    if (user == null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      return;
    }

    // 3. Route by role via AuthProvider
    // AuthProvider here refers to app's auth_provider.dart (firebase_auth's
    // AuthProvider is hidden by the 'hide AuthProvider' directive above)
    final ap = context.read<AuthProvider>();
    if (ap.user?.isAdmin == true) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.adminDashboard);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2263),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Logo ──────────────────────────────────────────────────
              Container(
                width:  120,
                height: 120,
                decoration: BoxDecoration(
                    color:  Colors.white,
                    shape:  BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color:        Colors.black.withAlpha(40),
                          blurRadius:   30,
                          spreadRadius: 4),
                    ]),
                child: Center(
                  child: Image.asset(
                      'assets/image.asset.png',
                      width:  80,
                      height: 80,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.school,
                          color: Color(0xFF1B2263),
                          size:  60)),
                ),
              ),

              const SizedBox(height: 28),

              // ── App name ──────────────────────────────────────────────
              const Text(
                'KCA University Foundation',
                style: TextStyle(
                    color:         Colors.white,
                    fontWeight:    FontWeight.bold,
                    fontSize:      20,
                    letterSpacing: 0.5),
              ),

              const SizedBox(height: 6),

              Text(
                'Transforming Lives Through Education',
                style: TextStyle(
                    color:         Colors.white.withAlpha(180),
                    fontSize:      13,
                    letterSpacing: 0.2),
              ),

              const SizedBox(height: 48),

              // ── Loading spinner ───────────────────────────────────────
              SizedBox(
                width:  28,
                height: 28,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(
                        const Color(0xFFF5A800).withAlpha(200))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}