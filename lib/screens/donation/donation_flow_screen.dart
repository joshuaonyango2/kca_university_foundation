// lib/screens/donation/donation_flow_screen.dart
// spell-checker: disable

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/campaign.dart';
import '../../services/mpesa_service.dart';
import '../../services/receipt_service.dart';

const _navy  = Color(0xFF1B2263);
const _gold  = Color(0xFFF5A800);
const _green = Color(0xFF10B981);
const _bg    = Color(0xFFF5F7FA);

class DonationFlowScreen extends StatefulWidget {
  final Campaign campaign;
  const DonationFlowScreen({super.key, required this.campaign});
  @override
  State<DonationFlowScreen> createState() => _DonationFlowScreenState();
}

class _DonationFlowScreenState extends State<DonationFlowScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _amtCtrl   = TextEditingController();
  final _nameCtrl  = TextEditingController();
  final _mpesa     = MpesaService();

  // State
  int    _step        = 0; // 0=form, 1=waiting, 2=success, 3=failed
  double _amount      = 0;
  int    _elapsed     = 0;
  String _checkoutId  = '';
  String _errorMsg    = '';

  // Preset amounts
  final _presets = [500.0, 1000.0, 2500.0, 5000.0, 10000.0];

  @override
  void initState() {
    super.initState();
    // Pre-fill donor name from Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameCtrl.text = user.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _amtCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Submit donation ───────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _amount = double.tryParse(_amtCtrl.text.replaceAll(',', '')) ?? 0;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Please log in to donate.');
      return;
    }

    setState(() => _step = 1);

    final result = await _mpesa.initiateSTKPush(
      phoneNumber:   _phoneCtrl.text.trim(),
      amount:        _amount,
      accountRef:    widget.campaign.title,
      description:   'KCA Foundation',
      donorId:       user.uid,
      campaignId:    widget.campaign.id,
      donorName:     _nameCtrl.text.trim(),
      campaignTitle: widget.campaign.title,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() { _step = 3; _errorMsg = result.error ?? 'Payment initiation failed'; });
      return;
    }

    _checkoutId = result.checkoutRequestId!;

    // Poll for result
    final status = await _mpesa.waitForPayment(
      _checkoutId,
      onTick: (s) { if (mounted) setState(() => _elapsed = s); },
    );

    if (!mounted) return;

    if (status == MpesaStatus.completed) {
      setState(() => _step = 2);
      // Generate and send receipt
      _sendReceipt();
    } else {
      setState(() {
        _step = 3;
        _errorMsg = status == MpesaStatus.cancelled
            ? 'Payment was cancelled on your phone.'
            : status == MpesaStatus.timedOut
            ? 'Payment timed out. Check your M-Pesa messages.'
            : 'Payment failed. Please try again.';
      });
    }
  }

  Future<void> _sendReceipt() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch donor email
    final donorDoc = await FirebaseFirestore.instance
        .collection('donors').doc(user.uid).get();
    final email = donorDoc.data()?['email'] as String? ?? user.email ?? '';

    await ReceiptService.generateAndSend(
      donorName:     _nameCtrl.text.trim(),
      donorEmail:    email,
      amount:        _amount,
      campaignTitle: widget.campaign.title,
      transactionId: _checkoutId,
      phone:         _phoneCtrl.text.trim(),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Make a Donation', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(child: () {
        switch (_step) {
          case 1: return _waitingView();
          case 2: return _successView();
          case 3: return _failedView();
          default: return _formView();
        }
      }()),
    );
  }

  // ── STEP 0: Form ──────────────────────────────────────────────────────────
  Widget _formView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Campaign card
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.campaign, color: _gold, size: 28)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.campaign.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('campaigns').doc(widget.campaign.id).snapshots(),
                    builder: (ctx, snap) {
                      final raised = (snap.data?.get('raised') as num? ?? 0).toDouble();
                      final goal   = (snap.data?.get('goal')   as num? ?? 1).toDouble();
                      final pct    = (raised / goal).clamp(0.0, 1.0);
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('KES ${_f(raised)} raised of KES ${_f(goal)}',
                            style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12)),
                        const SizedBox(height: 6),
                        ClipRRect(borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: pct, minHeight: 6,
                                color: _gold, backgroundColor: Colors.white.withAlpha(40))),
                      ]);
                    }),
              ])),
            ])),
        const SizedBox(height: 24),

        Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Name
          _label('Your Name'),
          _field(_nameCtrl, 'Full name', Icons.person_outline, required: true),
          const SizedBox(height: 16),

          // Phone
          _label('M-Pesa Phone Number'),
          _field(_phoneCtrl, '07XX XXX XXX or 254XXXXXXXXX',
              Icons.phone_android, type: TextInputType.phone,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Phone required';
                final d = v.replaceAll(RegExp(r'\D'), '');
                if (d.length < 9) return 'Enter a valid M-Pesa number';
                return null;
              }),
          Padding(padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text('You will receive a payment prompt on this number',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ])),
          const SizedBox(height: 20),

          // Amount
          _label('Donation Amount (KES)'),
          // Preset chips
          Wrap(spacing: 8, runSpacing: 8, children: _presets.map((p) {
            final selected = _amtCtrl.text == p.toStringAsFixed(0);
            return GestureDetector(
              onTap: () => setState(() => _amtCtrl.text = p.toStringAsFixed(0)),
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      color: selected ? _navy : Colors.white,
                      border: Border.all(color: selected ? _navy : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('KES ${_f(p)}',
                      style: TextStyle(color: selected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600, fontSize: 13))),
            );
          }).toList()),
          const SizedBox(height: 10),
          TextFormField(
              controller: _amtCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  hintText: 'Or enter custom amount',
                  prefixText: 'KES ',
                  prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: _navy),
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _navy, width: 2)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
              validator: (v) {
                final amt = double.tryParse(v?.replaceAll(',','') ?? '');
                if (amt == null || amt <= 0) return 'Enter a valid amount';
                if (amt < 10) return 'Minimum donation is KES 10';
                return null;
              }),
          const SizedBox(height: 32),

          // M-Pesa branding notice
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFF006633).withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF006633).withAlpha(40))),
              child: Row(children: [
                Container(width: 32, height: 32, decoration: const BoxDecoration(color: Color(0xFF006633), shape: BoxShape.circle),
                    child: const Center(child: Text('M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Pay via M-Pesa', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006633))),
                  Text('Secure payment via Daraja API', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ])),
              ])),
          const SizedBox(height: 24),

          // Submit
          SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006633), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.phone_android, size: 20),
                const SizedBox(width: 10),
                Text('Donate KES ${_amtCtrl.text.isEmpty ? "—" : _f(double.tryParse(_amtCtrl.text.replaceAll(',','')) ?? 0)} via M-Pesa',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]))),
        ])),
      ]),
    );
  }

  // ── STEP 1: Waiting ───────────────────────────────────────────────────────
  Widget _waitingView() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Animated phone icon
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.9, end: 1.1),
          duration: const Duration(milliseconds: 800),
          builder: (ctx, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
              width: 100, height: 100,
              decoration: const BoxDecoration(color: Color(0xFF006633), shape: BoxShape.circle),
              child: const Center(child: Text('M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 48)))),
        ),
        const SizedBox(height: 28),
        const Text('Check Your Phone', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(height: 12),
        Text(
            'An STK Push notification has been sent to ${_phoneCtrl.text.trim()}.\nEnter your M-Pesa PIN to complete the donation.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.6)),
        const SizedBox(height: 28),

        // Progress indicator
        const CircularProgressIndicator(color: _navy, strokeWidth: 3),
        const SizedBox(height: 16),
        Text('Waiting for confirmation... ${_elapsed}s',
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        const SizedBox(height: 8),
        Text('Timeout in ${120 - _elapsed}s',
            style: TextStyle(fontSize: 11, color: Colors.grey[400])),

        const SizedBox(height: 32),
        TextButton(
            onPressed: () => setState(() { _step = 0; }),
            child: const Text('Cancel', style: TextStyle(color: Colors.red))),
      ]),
    ));
  }

  // ── STEP 2: Success ───────────────────────────────────────────────────────
  Widget _successView() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 100, height: 100,
            decoration: BoxDecoration(color: _green.withAlpha(20), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, color: _green, size: 64)),
        const SizedBox(height: 24),
        const Text('Thank You! 🎉', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(height: 12),
        Text('Your donation of KES ${_f(_amount)} to\n"${widget.campaign.title}"\nhas been received!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.6)),
        const SizedBox(height: 8),
        Text('Transaction: $_checkoutId',
            style: TextStyle(fontSize: 11, color: Colors.grey[400], fontFamily: 'monospace')),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.email_outlined, size: 14, color: _green),
          const SizedBox(width: 4),
          Text('A receipt has been sent to your email',
              style: TextStyle(fontSize: 12, color: _green, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 40),
        SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Back to Campaigns', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
        const SizedBox(height: 12),
        TextButton(
            onPressed: _sendReceipt,
            child: const Text('Resend Receipt', style: TextStyle(color: _navy))),
      ]),
    ));
  }

  // ── STEP 3: Failed ────────────────────────────────────────────────────────
  Widget _failedView() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 100, height: 100,
            decoration: BoxDecoration(color: Colors.red.withAlpha(20), shape: BoxShape.circle),
            child: const Icon(Icons.error_outline, color: Colors.red, size: 64)),
        const SizedBox(height: 24),
        const Text('Payment Failed', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
        const SizedBox(height: 12),
        Text(_errorMsg, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.6)),
        const SizedBox(height: 40),
        SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => setState(() { _step = 0; _elapsed = 0; }),
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
        const SizedBox(height: 12),
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
      ]),
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _navy)));

  Widget _field(TextEditingController c, String hint, IconData icon,
      {TextInputType type = TextInputType.text, bool required = false,
        String? Function(String?)? validator}) {
    return TextFormField(
        controller: c, keyboardType: type,
        decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: _navy),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _navy, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
        validator: validator ?? (required ? (v) => v == null || v.trim().isEmpty ? '$hint required' : null : null));
  }

  String _f(double v) => v >= 1000000 ? '${(v/1000000).toStringAsFixed(1)}M'
      : v >= 1000 ? '${(v/1000).toStringAsFixed(0)}K' : v.toStringAsFixed(0);
}