// lib/screens/admin/admin_login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';

// ── KCA Foundation brand tokens ──────────────────────────────────────────────
class _KCA {
  static const navy    = Color(0xFF1B2263);
  static const gold    = Color(0xFFF5A800);
  static const white   = Colors.white;
  static const lightBg = Color(0xFFF5F7FA);
}
// ─────────────────────────────────────────────────────────────────────────────

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey            = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      if (authProvider.user?.isAdmin ?? false) {
        navigator.pushReplacementNamed(AppRoutes.adminDashboard);
      } else {
        await authProvider.logout();
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Access denied. Admin credentials required.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Login failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── Gold header band ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: _KCA.gold,
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: const Text(
              'STAFF & ADMINISTRATOR PORTAL',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _KCA.navy,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          ),

          // ── Navy body ────────────────────────────────────────────────────
          Expanded(
            child: Container(
              color: _KCA.navy,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Card(
                      elevation: 16,
                      shadowColor: Colors.black38,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 44),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ── Logo ───────────────────────────────────
                              _buildLogo(),

                              const SizedBox(height: 28),

                              // ── Titles ─────────────────────────────────
                              const Text(
                                'Admin Portal',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: _KCA.navy,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'KCA University Foundation',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  letterSpacing: 0.4,
                                ),
                              ),

                              // ── Gold accent line ────────────────────────
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Container(
                                  height: 3,
                                  width: 56,
                                  decoration: BoxDecoration(
                                    color: _KCA.gold,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),

                              // ── Email field ─────────────────────────────
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: _inputDecoration(
                                  label: 'Admin Email',
                                  hint: 'admin@kca.ac.ke',
                                  icon: Icons.email_outlined,
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Email is required';
                                  }
                                  if (!v.contains('@')) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 18),

                              // ── Password field ──────────────────────────
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleLogin(),
                                decoration: _inputDecoration(
                                  label: 'Password',
                                  hint: 'Enter admin password',
                                  icon: Icons.lock_outline,
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Colors.grey[600],
                                    ),
                                    onPressed: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Password is required';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 30),

                              // ── Login button ────────────────────────────
                              Consumer<AuthProvider>(
                                builder: (context, auth, _) {
                                  return SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed:
                                      auth.isLoading ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _KCA.navy,
                                        disabledBackgroundColor:
                                        _KCA.navy.withAlpha(120),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: auth.isLoading
                                          ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                          AlwaysStoppedAnimation(
                                              _KCA.white),
                                        ),
                                      )
                                          : const Text(
                                        'Login as Admin',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _KCA.white,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 20),

                              // ── Back to donor login ─────────────────────
                              TextButton.icon(
                                onPressed: () =>
                                    Navigator.pushReplacementNamed(
                                        context, AppRoutes.login),
                                icon: const Icon(Icons.arrow_back_ios,
                                    size: 13, color: _KCA.navy),
                                label: const Text(
                                  'Back to Donor Login',
                                  style: TextStyle(
                                    color: _KCA.navy,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Logo widget ─────────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: _KCA.white,
        shape: BoxShape.circle,
        border: Border.all(color: _KCA.gold, width: 3),
        boxShadow: [
          BoxShadow(
            color: _KCA.navy.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: ClipOval(
        child: Image.asset(
          'assets/icon/kca_logo.png',   // ✅ uses your existing asset
          fit: BoxFit.contain,
          // Fallback to admin icon if image fails to load
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.admin_panel_settings,
              size: 44,
              color: _KCA.navy,
            );
          },
        ),
      ),
    );
  }

  // ── Shared input decoration helper ─────────────────────────────────────────
  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _KCA.navy),
      filled: true,
      fillColor: _KCA.lightBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _KCA.navy, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      labelStyle: const TextStyle(color: _KCA.navy),
    );
  }
}