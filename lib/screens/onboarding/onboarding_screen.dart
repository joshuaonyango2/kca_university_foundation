// lib/screens/onboarding/onboarding_screen.dart
// spell-checker: disable
//
// 3-slide welcome/onboarding shown once on first launch.
// Uses SharedPreferences to track whether the user has seen it.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/routes.dart';

const _navy = Color(0xFF1B2263);
const _gold = Color(0xFFF5A800);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      emoji:    '🎓',
      title:    'Transform Lives\nThrough Education',
      subtitle: 'Join thousands of supporters funding scholarships, '
          'infrastructure, and research at KCA University. '
          'Every donation unlocks potential.',
      bg:       Color(0xFF1B2263),
      accent:   Color(0xFFF5A800),
    ),
    _Slide(
      emoji:    '💳',
      title:    'Donate Easily\nYour Way',
      subtitle: 'Give instantly via M-Pesa, bank transfer, or card. '
          'Choose your amount, set a recurring schedule, '
          'and track your impact in real time.',
      bg:       Color(0xFF0F3460),
      accent:   Color(0xFF10B981),
    ),
    _Slide(
      emoji:    '📊',
      title:    'Track Your\nImpact & Giving',
      subtitle: 'See exactly where your money goes — campaign '
          'milestones, beneficiary stories, and instant PDF '
          'receipts for every donation.',
      bg:       Color(0xFF16213E),
      accent:   Color(0xFFF5A800),
    ),
  ];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(children: [
        // ── Page view ─────────────────────────────────────────────────
        PageView.builder(
            controller: _ctrl,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (ctx, i) => _SlideView(slide: _slides[i],
                size: size)),

        // ── Skip button ───────────────────────────────────────────────
        Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 20,
            child: _page < _slides.length - 1
                ? TextButton(
                onPressed: _finish,
                child: const Text('Skip',
                    style: TextStyle(color: Colors.white70,
                        fontSize: 14)))
                : const SizedBox.shrink()),

        // ── Bottom controls ───────────────────────────────────────────
        Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 32,
            left: 0, right: 0,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Dots
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (int i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width:  _page == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: _page == i
                              ? _gold
                              : Colors.white.withAlpha(100),
                          borderRadius: BorderRadius.circular(4))),
              ]),
              const SizedBox(height: 32),
              // Button
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_page < _slides.length - 1) {
                            _ctrl.nextPage(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOut);
                          } else {
                            _finish();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: _navy,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 4),
                        child: Text(
                            _page < _slides.length - 1
                                ? 'Continue'
                                : 'Get Started',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ))),
            ])),
      ]),
    );
  }
}

// ── Individual slide ──────────────────────────────────────────────────────────
class _SlideView extends StatelessWidget {
  final _Slide slide;
  final Size size;
  const _SlideView({required this.slide, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [slide.bg, slide.bg.withAlpha(200)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)),
        child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    // Emoji in circle
                    Container(
                        width: 140, height: 140,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withAlpha(15),
                            border: Border.all(
                                color: slide.accent.withAlpha(120), width: 2)),
                        child: Center(child: Text(slide.emoji,
                            style: const TextStyle(fontSize: 68)))),
                    const SizedBox(height: 48),
                    // KCA logo text
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                          width: 4, height: 24,
                          decoration: BoxDecoration(
                              color: slide.accent,
                              borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 10),
                      const Text('KCA UNIVERSITY FOUNDATION',
                          style: TextStyle(color: Colors.white70,
                              fontSize: 11, letterSpacing: 1.5,
                              fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 20),
                    // Title
                    Text(slide.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            height: 1.25)),
                    const SizedBox(height: 20),
                    // Subtitle
                    Text(slide.subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 15,
                            height: 1.6)),
                    const SizedBox(height: 120), // space for bottom controls
                  ]),
            )));
  }
}

class _Slide {
  final String emoji, title, subtitle;
  final Color bg, accent;
  const _Slide({
    required this.emoji, required this.title,
    required this.subtitle, required this.bg, required this.accent,
  });
}

// ── Static helper to check/show onboarding ────────────────────────────────────
class OnboardingHelper {
  /// Call in main.dart / splash to determine initial route.
  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_done') ?? false;
  }

  /// Reset for testing.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_done');
  }
}