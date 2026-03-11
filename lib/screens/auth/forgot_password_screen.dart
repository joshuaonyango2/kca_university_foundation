// lib/screens/auth/forgot_password_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class _KCA {
  static const navy    = Color(0xFF1B2263);
  static const gold    = Color(0xFFF5A800);
  static const white   = Colors.white;
  static const lightBg = Color(0xFFF5F7FA);
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey         = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messenger    = ScaffoldMessenger.of(context);

    // ✅ Real Firebase password reset — no more simulated delay
    final success = await authProvider.resetPassword(
      email: _emailController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      setState(() => _emailSent = true);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Failed to send reset link. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _handleResendEmail() async {
    setState(() => _emailSent = false);
    await Future.delayed(const Duration(milliseconds: 300));
    _handleSendResetLink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _KCA.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _KCA.navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Reset Password',
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: _emailSent ? _buildSuccessView() : _buildFormView(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Form view ───────────────────────────────────────────────────────────────
  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),

          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _KCA.navy.withAlpha(20),
              shape: BoxShape.circle,
              border: Border.all(color: _KCA.gold, width: 2),
            ),
            child: const Icon(Icons.lock_reset, size: 40, color: _KCA.navy),
          ),

          const SizedBox(height: 32),

          const Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _KCA.navy,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'No worries! Enter your email address and we\'ll send you a link to reset your password.',
            style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
          ),

          const SizedBox(height: 32),

          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleSendResetLink(),
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'your.email@example.com',
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
                  borderSide: const BorderSide(color: _KCA.navy, width: 2)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red)),
              labelStyle: const TextStyle(color: _KCA.navy),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter your email';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          // Send button
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              return ElevatedButton(
                onPressed: auth.isLoading ? null : _handleSendResetLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _KCA.navy,
                  disabledBackgroundColor: _KCA.navy.withAlpha(120),
                  foregroundColor: _KCA.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: auth.isLoading
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(_KCA.white),
                    ))
                    : const Text('Send Reset Link',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              );
            },
          ),

          const SizedBox(height: 24),

          // Back to login
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 18, color: _KCA.navy),
              label: const Text('Back to Login',
                  style: TextStyle(
                      fontSize: 15,
                      color: _KCA.navy,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Success view ────────────────────────────────────────────────────────────
  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),

        // Success icon
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, size: 60, color: Colors.green),
          ),
        ),

        const SizedBox(height: 32),

        const Text(
          'Check Your Email',
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold, color: _KCA.navy),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        Text(
          'We\'ve sent a password reset link to:',
          style: TextStyle(fontSize: 15, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        Text(
          _emailController.text,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: _KCA.navy),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 32),

        // Info box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Text('Important',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900])),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• Check your spam folder if you don\'t see the email\n'
                    '• The link will expire in 1 hour\n'
                    '• Click the link to reset your password',
                style: TextStyle(
                    fontSize: 13, color: Colors.blue[900], height: 1.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Resend
        OutlinedButton(
          onPressed: _handleResendEmail,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            side: BorderSide(color: Colors.grey[300]!),
          ),
          child: const Text('Resend Email',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _KCA.navy)),
        ),

        const SizedBox(height: 16),

        // Back to login
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: _KCA.navy,
            foregroundColor: _KCA.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('Back to Login',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}