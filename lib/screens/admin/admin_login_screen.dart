// lib/screens/admin/admin_login_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';

class _KCA {
  static const navy    = Color(0xFF1B2263);
  static const gold    = Color(0xFFF5A800);
  static const white   = Colors.white;
  static const lightBg = Color(0xFFF5F7FA);
}

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

  // ── Smart routing: checks Firestore to decide which dashboard to open ───────
  //
  //  • Hardcoded admin emails (admin@kca.ac.ke etc.)  → full admin dashboard
  //  • Staff doc exists + is_admin == true             → full admin dashboard
  //  • Staff doc exists + is_admin == false            → role-based staff dashboard
  //  • No staff doc found (unknown user)               → access denied
  //
  Future<void> _routeAfterLogin(String uid, String email) async {
    // 1. Always allow the hardcoded super-admin accounts through
    const hardcodedAdmins = ['admin@kca.ac.ke', 'foundation@kca.ac.ke'];
    if (hardcodedAdmins.contains(email.toLowerCase())) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.adminDashboard);
      }
      return;
    }

    // 2. Look up the staff record in Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('staff')
          .doc(uid)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final isAdmin   = doc.data()?['is_admin'] as bool? ?? false;
        final isActive  = doc.data()?['is_active'] as bool? ?? true;

        // Blocked / deactivated account
        if (!isActive) {
          await Provider.of<AuthProvider>(context, listen: false).logout();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account has been deactivated. Contact the administrator.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        if (isAdmin) {
          // Staff member with full admin flag → full dashboard
          Navigator.of(context).pushReplacementNamed(AppRoutes.adminDashboard);
        } else {
          // Staff member with role-based access → staff dashboard
          Navigator.of(context).pushReplacementNamed(AppRoutes.staffDashboard);
        }
      } else {
        // Logged in but no staff record — deny access
        await Provider.of<AuthProvider>(context, listen: false).logout();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied. Your account has not been set up as staff.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking access: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Email/password login ────────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messenger    = ScaffoldMessenger.of(context);

    final success = await authProvider.login(
      email:    _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      final uid   = authProvider.user?.id ?? '';
      final email = authProvider.user?.email ?? '';

      // ✅ CHANGED: smart routing instead of hardcoded adminDashboard
      await _routeAfterLogin(uid, email);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Login failed'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Google Sign-In ──────────────────────────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messenger    = ScaffoldMessenger.of(context);

    final success = await authProvider.signInWithGoogle();

    if (!mounted) return;

    if (success) {
      final uid   = authProvider.user?.id ?? '';
      final email = authProvider.user?.email ?? '';

      // ✅ CHANGED: smart routing instead of hardcoded adminDashboard
      await _routeAfterLogin(uid, email);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Google sign-in failed'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Forgot password dialog ─────────────────────────────────────────────────
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: _KCA.navy, size: 26),
            SizedBox(width: 10),
            Text('Reset Admin Password',
                style: TextStyle(color: _KCA.navy, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your admin email and we\'ll send a password reset link.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Admin Email',
                hintText: 'admin@kca.ac.ke',
                prefixIcon: const Icon(Icons.email_outlined, color: _KCA.navy),
                filled: true,
                fillColor: _KCA.lightBg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    const BorderSide(color: _KCA.navy, width: 2)),
                labelStyle: const TextStyle(color: _KCA.navy),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              return ElevatedButton(
                onPressed: auth.isLoading
                    ? null
                    : () async {
                  final email = resetEmailController.text.trim();
                  if (email.isEmpty || !email.contains('@')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                        Text('Please enter a valid email address'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  final success =
                  await auth.resetPassword(email: email);

                  if (!context.mounted) return;
                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? '✓ Reset link sent to $email — check your inbox'
                          : auth.errorMessage ??
                          'Failed to send reset email'),
                      backgroundColor:
                      success ? Colors.green : Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _KCA.navy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: auth.isLoading
                    ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(_KCA.white)))
                    : const Text('Send Reset Link',
                    style: TextStyle(color: _KCA.white)),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Gold header band
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
                  letterSpacing: 1.6),
            ),
          ),

          // Navy body
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
                          borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 44),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildLogo(),
                              const SizedBox(height: 28),

                              const Text('Admin Portal',
                                  style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: _KCA.navy)),
                              const SizedBox(height: 6),
                              Text('KCA University Foundation',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      letterSpacing: 0.4)),

                              Padding(
                                padding:
                                const EdgeInsets.symmetric(vertical: 20),
                                child: Container(
                                    height: 3,
                                    width: 56,
                                    decoration: BoxDecoration(
                                        color: _KCA.gold,
                                        borderRadius:
                                        BorderRadius.circular(2))),
                              ),

                              // Email field
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: _inputDecoration(
                                    label: 'Admin Email',
                                    hint: 'admin@kca.ac.ke',
                                    icon: Icons.email_outlined),
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

                              const SizedBox(height: 16),

                              // Password field
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

                              // Forgot password link
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _showForgotPasswordDialog,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4, horizontal: 0),
                                    tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Forgot Password?',
                                      style: TextStyle(
                                          color: _KCA.navy,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Login button
                              Consumer<AuthProvider>(
                                builder: (context, auth, _) {
                                  return SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: auth.isLoading
                                          ? null
                                          : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _KCA.navy,
                                        disabledBackgroundColor:
                                        _KCA.navy.withAlpha(120),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(12)),
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
                                                  _KCA.white)))
                                          : const Text('Login as Admin',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: _KCA.white)),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 16),

                              // OR divider
                              Row(children: [
                                Expanded(
                                    child: Divider(color: Colors.grey[300])),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text('OR',
                                      style: TextStyle(
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12)),
                                ),
                                Expanded(
                                    child: Divider(color: Colors.grey[300])),
                              ]),

                              const SizedBox(height: 16),

                              // Google Sign-In
                              Consumer<AuthProvider>(
                                builder: (context, auth, _) {
                                  return SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: auth.isGoogleLoading
                                          ? null
                                          : _handleGoogleSignIn,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        side: BorderSide(
                                            color: Colors.grey[300]!),
                                        backgroundColor: _KCA.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(12)),
                                      ),
                                      child: auth.isGoogleLoading
                                          ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                              AlwaysStoppedAnimation(
                                                  _KCA.navy)))
                                          : Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          const _GoogleIcon(),
                                          const SizedBox(width: 10),
                                          Text('Sign in with Google',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight:
                                                  FontWeight.w600,
                                                  color: Colors
                                                      .grey[800])),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 20),

                              // Back to donor login
                              TextButton.icon(
                                onPressed: () =>
                                    Navigator.pushReplacementNamed(
                                        context, AppRoutes.login),
                                icon: const Icon(Icons.arrow_back_ios,
                                    size: 13, color: _KCA.navy),
                                label: const Text('Back to Donor Login',
                                    style: TextStyle(
                                        color: _KCA.navy,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
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
              offset: const Offset(0, 8))
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: ClipOval(
        child: Image.asset('assets/image.asset.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
                Icons.admin_panel_settings,
                size: 44,
                color: _KCA.navy)),
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String label,
        required String hint,
        required IconData icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _KCA.navy),
      filled: true,
      fillColor: _KCA.lightBg,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _KCA.navy, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red)),
      labelStyle: const TextStyle(color: _KCA.navy),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: Text('G',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4285F4))),
      ),
    );
  }
}