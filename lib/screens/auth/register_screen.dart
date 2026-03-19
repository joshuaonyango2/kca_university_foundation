// lib/screens/auth/register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../services/donor_type_service.dart';

// ── KCA brand tokens ──────────────────────────────────────────────────────────
class _KCA {
  static const navy    = Color(0xFF1B2263);
  static const gold    = Color(0xFFF5A800);
  static const white   = Colors.white;
  static const lightBg = Color(0xFFF5F7FA);
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _pageController = PageController();

  // Controllers
  final _nameController            = TextEditingController();
  final _emailController           = TextEditingController();
  final _phoneController           = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // State — now uses DonorTypeModel (from Firestore) instead of enum
  DonorTypeModel? _selectedDonorType;
  bool _obscurePassword        = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading              = false;
  bool _agreeToTerms           = false;
  int  _currentStep            = 0;

  static const int _totalSteps = 4;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────
  void _handleBack() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _handleNext() async {
    if (_currentStep == 0) {
      if (_selectedDonorType == null) {
        _showError('Please select your donor type to continue');
        return;
      }
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      if (!_formKey.currentState!.validate()) return;
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      _showError('Please agree to the Terms & Conditions to continue');
      return;
    }
    await _handleRegister();
  }

  Future<void> _handleRegister() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final navigator    = Navigator.of(context);
    final messenger    = ScaffoldMessenger.of(context);

    final success = await authProvider.register(
      name:       _nameController.text.trim(),
      email:      _emailController.text.trim(),
      password:   _passwordController.text,
      phone:      '+254${_phoneController.text.trim()}',
      donorType:  _selectedDonorType!.id,  // pass String doc ID
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _showSuccessDialog(navigator);
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(authProvider.errorMessage ?? 'Registration failed. Please try again.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showSuccessDialog(NavigatorState navigator) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.check_circle, color: Colors.green, size: 32),
          SizedBox(width: 12),
          Text('Welcome!'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your ${_selectedDonorType?.displayName} account has been created.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(Icons.email_outlined, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                      'Verification link sent to ${_emailController.text}',
                      style: TextStyle(fontSize: 13, color: Colors.blue[900]))),
                ]),
              ),
            ]),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              navigator.pushReplacementNamed(AppRoutes.home);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _KCA.navy),
            child: const Text('Go to Dashboard',
                style: TextStyle(color: _KCA.white)),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────────────
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
        title: Text('Create Account',
            style: TextStyle(color: Colors.grey[800], fontSize: 18,
                fontWeight: FontWeight.w600)),
      ),
      body: Form(
        key: _formKey,
        child: Column(children: [
          _buildProgressIndicator(),
          const SizedBox(height: 24),
          Expanded(child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentStep = i),
            children: [
              _buildStep0DonorType(),
              _buildStep1PersonalInfo(),
              _buildStep2Contact(),
              _buildStep3Security(),
            ],
          )),
          _buildBottomNavigation(),
        ]),
      ),
    );
  }

  // ── Progress bar ────────────────────────────────────────────────────────────
  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(_totalSteps, (index) => Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
            height: 4,
            decoration: BoxDecoration(
                color: index <= _currentStep ? _KCA.navy : Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
        )),
      ),
    );
  }

  // ── Step 0: Donor Type — loads from Firestore via DonorTypeService ──────────
  Widget _buildStep0DonorType() {
    return StreamBuilder<List<DonorTypeModel>>(
      stream: DonorTypeService.activeStream(),
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final types   = snap.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('I am a...',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                    color: Colors.grey[800])),
            const SizedBox(height: 8),
            Text('Choose the type of donor you are. '
                'This helps us personalise your experience.',
                style: TextStyle(fontSize: 15, color: Colors.grey[600])),
            const SizedBox(height: 32),

            if (loading)
              const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: _KCA.navy)))
            else if (types.isEmpty)
              Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200)),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(child: Text(
                        'No donor types available. Please contact an administrator.',
                        style: TextStyle(fontSize: 14))),
                  ]))
            else
              ...types.map((type) => _buildDonorTypeCard(type)),
          ]),
        );
      },
    );
  }

  Widget _buildDonorTypeCard(DonorTypeModel type) {
    final isSelected = _selectedDonorType?.id == type.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedDonorType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? _KCA.navy.withAlpha(10) : _KCA.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? _KCA.navy : Colors.grey[300]!,
              width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [BoxShadow(color: _KCA.navy.withAlpha(30),
              blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(children: [
          // Emoji icon in circle
          Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color: isSelected ? _KCA.navy : Colors.grey[100],
                  shape: BoxShape.circle),
              child: Center(child: Text(type.icon,
                  style: const TextStyle(fontSize: 24)))),
          const SizedBox(width: 16),

          // Label + description
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.displayName,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                        color: isSelected ? _KCA.navy : Colors.grey[800])),
                if (type.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(type.description,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              ])),

          // Radio indicator
          Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: isSelected ? _KCA.navy : Colors.grey[400]!, width: 2),
                  color: isSelected ? _KCA.navy : Colors.transparent),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null),
        ]),
      ),
    );
  }

  // ── Step 1: Personal Info ───────────────────────────────────────────────────
  Widget _buildStep1PersonalInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Personal Information',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                color: Colors.grey[800])),
        const SizedBox(height: 8),
        Text('Please enter your basic details',
            style: TextStyle(fontSize: 15, color: Colors.grey[600])),
        const SizedBox(height: 32),

        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: _inputDecoration(
              label: 'Full Name', hint: 'John Doe',
              icon: Icons.person_outline),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Please enter your full name';
            if (v.length < 3) return 'Name must be at least 3 characters';
            return null;
          },
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          decoration: _inputDecoration(
              label: 'Email Address', hint: 'your.email@example.com',
              icon: Icons.email_outlined),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Please enter your email';
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
      ]),
    );
  }

  // ── Step 2: Contact ─────────────────────────────────────────────────────────
  Widget _buildStep2Contact() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Contact Information',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                color: Colors.grey[800])),
        const SizedBox(height: 8),
        Text("We'll use this for M-Pesa payments",
            style: TextStyle(fontSize: 15, color: Colors.grey[600])),
        const SizedBox(height: 32),

        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: _inputDecoration(
            label: 'Phone Number', hint: '0712 345 678',
            icon: Icons.phone_outlined,
          ).copyWith(
            prefixText: '+254 ',
            helperText: 'Enter Safaricom number for M-Pesa',
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Please enter your phone number';
            if (v.length != 10) return 'Phone number must be 10 digits';
            if (!v.startsWith('0')) return 'Phone number must start with 0';
            return null;
          },
        ),
      ]),
    );
  }

  // ── Step 3: Security ────────────────────────────────────────────────────────
  Widget _buildStep3Security() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Security',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                color: Colors.grey[800])),
        const SizedBox(height: 8),
        Text('Create a secure password',
            style: TextStyle(fontSize: 15, color: Colors.grey[600])),
        const SizedBox(height: 32),

        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          decoration: _inputDecoration(
              label: 'Password', hint: 'Minimum 6 characters',
              icon: Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword)),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Please enter a password';
            if (v.length < 6) return 'Password must be at least 6 characters';
            return null;
          },
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          textInputAction: TextInputAction.done,
          decoration: _inputDecoration(
              label: 'Confirm Password', hint: 'Re-enter your password',
              icon: Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword
                    ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword)),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Please confirm your password';
            if (v != _passwordController.text) return 'Passwords do not match';
            return null;
          },
        ),
        const SizedBox(height: 24),

        // Terms checkbox
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 24, height: 24,
              child: Checkbox(
                  value: _agreeToTerms,
                  activeColor: _KCA.navy,
                  onChanged: (v) => setState(() => _agreeToTerms = v ?? false),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)))),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
            child: Text.rich(TextSpan(
              text: 'I agree to the ',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              children: const [
                TextSpan(text: 'Terms & Conditions',
                    style: TextStyle(color: _KCA.navy,
                        fontWeight: FontWeight.w600)),
                TextSpan(text: ' and '),
                TextSpan(text: 'Privacy Policy',
                    style: TextStyle(color: _KCA.navy,
                        fontWeight: FontWeight.w600)),
              ],
            )),
          )),
        ]),
      ]),
    );
  }

  // ── Bottom navigation ───────────────────────────────────────────────────────
  Widget _buildBottomNavigation() {
    final isLast = _currentStep == _totalSteps - 1;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: _KCA.white,
          boxShadow: [BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(children: [
        if (_currentStep > 0) ...[
          Expanded(child: OutlinedButton(
              onPressed: _isLoading ? null : _handleBack,
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: Colors.grey[300]!)),
              child: const Text('Back',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                      color: Colors.black87)))),
          const SizedBox(width: 12),
        ],
        Expanded(child: ElevatedButton(
          onPressed: _isLoading ? null : _handleNext,
          style: ElevatedButton.styleFrom(
              backgroundColor: _KCA.navy,
              disabledBackgroundColor: _KCA.navy.withAlpha(120),
              foregroundColor: _KCA.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0),
          child: _isLoading
              ? const SizedBox(height: 20, width: 20,
              child: CircularProgressIndicator(strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : Text(isLast ? 'Create Account' : 'Continue',
              style: const TextStyle(fontSize: 16,
                  fontWeight: FontWeight.bold)),
        )),
      ]),
    );
  }

  // ── Input decoration helper ─────────────────────────────────────────────────
  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label, hintText: hint,
      prefixIcon: Icon(icon, color: _KCA.navy),
      filled: true, fillColor: _KCA.lightBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _KCA.navy, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red)),
      labelStyle: const TextStyle(color: _KCA.navy),
    );
  }
}