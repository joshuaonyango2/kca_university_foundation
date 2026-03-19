// lib/screens/donation/donation_flow_screen.dart
// spell-checker: disable
//
// COMPLETE donation flow — 4 steps:
//   Step 0: Form  (details + method + purpose + recurring + anonymity + amount)
//   Step 1: Confirmation
//   Step 2: Waiting (M-Pesa STK only)
//   Step 3: Success
//   Step 4: Failed
//
// Firestore: payment_methods (is_active), donation_amounts (is_active)
// After payment → notifyDonationReceived + notifyDonorReceipt + PDF receipt

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/campaign.dart';
import '../../services/mpesa_service.dart';
import '../../services/receipt_service.dart';
import '../../services/donation_amount_service.dart';
import '../../services/payment_method_service.dart';
import '../../services/notification_service.dart';

const _navy  = Color(0xFF1B2263);
const _gold  = Color(0xFFF5A800);
const _green = Color(0xFF10B981);
const _bg    = Color(0xFFF5F7FA);
const _red   = Color(0xFFDC2626);

const _purposes = [
  'General Fund',
  'Scholarship Fund',
  'Endowment Fund',
  'Infrastructure',
  'Research & Outreach',
];

class DonationFlowScreen extends StatefulWidget {
  final Campaign campaign;
  const DonationFlowScreen({super.key, required this.campaign});
  @override
  State<DonationFlowScreen> createState() => _DonationFlowScreenState();
}

class _DonationFlowScreenState extends State<DonationFlowScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _mpesaCtrl = TextEditingController();
  final _amtCtrl   = TextEditingController();
  final _mpesa     = MpesaService();

  // ── Steps: 0=form 1=confirm 2=waiting 3=success 4=failed ──────────────────
  int    _step       = 0;
  double _amount     = 0;
  int    _elapsed    = 0;
  String _checkoutId = '';
  String _errorMsg   = '';

  // ── Form state ─────────────────────────────────────────────────────────────
  List<PaymentMethodModel>  _paymentMethods = [];
  PaymentMethodModel?       _selectedMethod;
  bool                      _loadingMethods = true;
  List<DonationAmountModel> _presets        = [];
  bool                      _loadingPresets = true;

  // ── New fields ─────────────────────────────────────────────────────────────
  String  _purpose    = 'General Fund';
  String  _frequency  = 'one-time';   // one-time | monthly | yearly
  bool    _anonymous  = false;

  @override
  void initState() {
    super.initState();
    _prefillDonorInfo();
    _loadData();
  }

  Future<void> _prefillDonorInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _nameCtrl.text  = user.displayName ?? '';
    _emailCtrl.text = user.email ?? '';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('donors').doc(user.uid).get();
      if (!mounted) return;
      final d = doc.data();
      if (d == null) return;
      if (_nameCtrl.text.isEmpty)  _nameCtrl.text  = d['name']  as String? ?? '';
      if (_emailCtrl.text.isEmpty) _emailCtrl.text = d['email'] as String? ?? '';
      if (_phoneCtrl.text.isEmpty) _phoneCtrl.text = d['phone'] as String? ?? '';
      setState(() {});
    } catch (_) {}
  }

  Future<void> _loadData() async {
    await Future.wait([_loadPaymentMethods(), _loadPresets()]);
  }

  Future<void> _loadPaymentMethods() async {
    try {
      await PaymentMethodService.seedIfEmpty();
      final snap = await FirebaseFirestore.instance
          .collection('payment_methods')
          .where('is_active', isEqualTo: true)
          .get();
      final methods = snap.docs
          .map((d) => PaymentMethodModel.fromFirestore(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      if (mounted) {
        setState(() {
          _paymentMethods = methods;
          if (methods.isNotEmpty) _selectedMethod = methods.first;
          _loadingMethods = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMethods = false);
    }
  }

  Future<void> _loadPresets() async {
    try {
      await DonationAmountService.seedIfEmpty();
      final snap = await FirebaseFirestore.instance
          .collection('donation_amounts')
          .where('is_active', isEqualTo: true)
          .get();
      final presets = snap.docs
          .map((d) => DonationAmountModel.fromFirestore(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      if (mounted) {
        setState(() {
          _presets = presets;
          _loadingPresets = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _presets = [500.0, 1000.0, 2500.0, 5000.0, 10000.0]
              .asMap().entries.map((e) => DonationAmountModel(
              id: 'def_${e.key}', amount: e.value,
              isActive: true, order: e.key,
              createdAt: DateTime.now())).toList();
          _loadingPresets = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
    _mpesaCtrl.dispose(); _amtCtrl.dispose();
    super.dispose();
  }

  // ── Step 0 → 1: validate form, go to confirmation ─────────────────────────
  void _toConfirm() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMethod == null) {
      _showSnack('Please select a payment method.', isError: true);
      return;
    }
    _amount = double.tryParse(_amtCtrl.text.replaceAll(',', '')) ?? 0;
    if (_amount < 10) {
      _showSnack('Minimum donation is KES 10.', isError: true);
      return;
    }
    setState(() => _step = 1);
  }

  // ── Step 1 → payment ───────────────────────────────────────────────────────
  Future<void> _pay() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { _showSnack('Please log in.', isError: true); return; }
    if (_selectedMethod!.type == PaymentType.mobileMoney) {
      await _payMpesa(user);
    } else {
      await _payManual(user);
    }
  }

  Future<void> _payMpesa(User user) async {
    setState(() => _step = 2);
    final result = await _mpesa.initiateSTKPush(
      phoneNumber:   _mpesaCtrl.text.trim(),
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
      setState(() { _step = 4; _errorMsg = result.error ?? 'Payment initiation failed'; });
      return;
    }
    _checkoutId = result.checkoutRequestId!;
    final status = await _mpesa.waitForPayment(
      _checkoutId,
      onTick: (s) { if (mounted) setState(() => _elapsed = s); },
    );
    if (!mounted) return;
    if (status == MpesaStatus.completed) {
      setState(() => _step = 3);
      await _recordAndNotify(user);
    } else {
      setState(() {
        _step = 4;
        _errorMsg = status == MpesaStatus.cancelled
            ? 'Payment was cancelled on your phone.'
            : status == MpesaStatus.timedOut
            ? 'Payment timed out. Check your M-Pesa messages.'
            : 'Payment failed. Please try again.';
      });
    }
  }

  Future<void> _payManual(User user) async {
    try {
      final ref = FirebaseFirestore.instance.collection('donations').doc();
      await ref.set({
        'id':             ref.id,
        'donor_id':       user.uid,
        'donor_name':     _nameCtrl.text.trim(),
        'donor_email':    _emailCtrl.text.trim(),
        'donor_phone':    _phoneCtrl.text.trim(),
        'campaign_id':    widget.campaign.id,
        'campaign_title': widget.campaign.title,
        'amount':         _amount,
        'payment_method': _selectedMethod!.name,
        'payment_type':   _selectedMethod!.type.key,
        'purpose':        _purpose,
        'frequency':      _frequency,
        'is_anonymous':   _anonymous,
        'status':         'pending',
        'type':           'manual',
        'instructions':   _selectedMethod!.instructions,
        'created_at':     FieldValue.serverTimestamp(),
      });
      _checkoutId = ref.id;
      setState(() => _step = 3);
      await _recordAndNotify(user, isPending: true);
    } catch (e) {
      setState(() { _step = 4; _errorMsg = 'Could not record donation: $e'; });
    }
  }

  Future<void> _recordAndNotify(User user, {bool isPending = false}) async {
    // Save to Firestore donations (M-Pesa case — manual already saved above)
    if (!isPending) {
      try {
        final ref = FirebaseFirestore.instance.collection('donations').doc();
        _checkoutId = _checkoutId.isNotEmpty ? _checkoutId : ref.id;
        await ref.set({
          'id':             ref.id,
          'donor_id':       user.uid,
          'donor_name':     _nameCtrl.text.trim(),
          'donor_email':    _emailCtrl.text.trim(),
          'donor_phone':    _phoneCtrl.text.trim(),
          'campaign_id':    widget.campaign.id,
          'campaign_title': widget.campaign.title,
          'amount':         _amount,
          'payment_method': _selectedMethod?.name ?? 'M-Pesa',
          'payment_type':   _selectedMethod?.type.key ?? 'mobile_money',
          'purpose':        _purpose,
          'frequency':      _frequency,
          'is_anonymous':   _anonymous,
          'transaction_id': _checkoutId,
          'status':         'completed',
          'type':           'mpesa',
          'created_at':     FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    // Notify admins
    try {
      await NotificationService.notifyDonationReceived(
        donorName:     _anonymous ? 'Anonymous' : _nameCtrl.text.trim(),
        amount:        _amount,
        campaignTitle: widget.campaign.title,
        donorId:       user.uid,
        campaignId:    widget.campaign.id,
      );
    } catch (_) {}

    // Notify donor + receipt (completed only)
    if (!isPending) {
      try {
        await NotificationService.notifyDonorReceipt(
          donorId:       user.uid,
          donorName:     _nameCtrl.text.trim(),
          amount:        _amount,
          campaignTitle: widget.campaign.title,
          transactionId: _checkoutId,
        );
      } catch (_) {}
      try {
        await ReceiptService.generateAndSend(
          donorName:     _nameCtrl.text.trim(),
          donorEmail:    _emailCtrl.text.trim().isNotEmpty
              ? _emailCtrl.text.trim()
              : user.email ?? '',
          amount:        _amount,
          campaignTitle: widget.campaign.title,
          transactionId: _checkoutId,
          phone:         _phoneCtrl.text.trim(),
        );
      } catch (_) {}
    }

    // Update campaign raised
    try {
      if (!isPending) {
        await FirebaseFirestore.instance
            .collection('campaigns').doc(widget.campaign.id)
            .update({'raised': FieldValue.increment(_amount)});
      }
    } catch (_) {}
  }

  void _showSnack(String msg, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: isError ? _red : _green,
          behavior: SnackBarBehavior.floating));

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: Text(_appBarTitle(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: _step == 1
            ? IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _step = 0))
            : null,
      ),
      body: SafeArea(child: _buildStep()),
    );
  }

  String _appBarTitle() => switch (_step) {
    1 => 'Confirm Donation',
    2 => 'Processing Payment',
    3 => 'Donation Complete',
    4 => 'Payment Failed',
    _ => 'Make a Donation',
  };

  Widget _buildStep() => switch (_step) {
    1 => _confirmView(),
    2 => _waitingView(),
    3 => _successView(),
    4 => _failedView(),
    _ => _formView(),
  };

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 0: FORM
  // ══════════════════════════════════════════════════════════════════════════
  Widget _formView() => SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _campaignCard(),
        const SizedBox(height: 20),
        Form(key: _formKey, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Donor Details ──────────────────────────────────────────────
          _sectionHeader(Icons.person_outline, 'Your Details'),
          const SizedBox(height: 10),
          _label('Full Name *'),
          _field(_nameCtrl, 'Full name', Icons.person_outline, required: true),
          const SizedBox(height: 12),
          _label('Email Address *'),
          _field(_emailCtrl, 'your@email.com', Icons.email_outlined,
              type: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              }),
          const SizedBox(height: 12),
          _label('Phone Number *'),
          _field(_phoneCtrl, '07XX XXX XXX', Icons.phone_outlined,
              type: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Phone required';
                if (v.replaceAll(RegExp(r'\D'), '').length < 9) {
                  return 'Enter a valid phone number';
                }
                return null;
              }),
          const SizedBox(height: 20),

          // ── Payment Method ─────────────────────────────────────────────
          _sectionHeader(Icons.payment_outlined, 'Payment Method'),
          const SizedBox(height: 10),
          _paymentMethodSelector(),
          const SizedBox(height: 10),

          if (_selectedMethod?.type == PaymentType.mobileMoney) ...[
            _label('M-Pesa Phone *'),
            _field(_mpesaCtrl, '07XX XXX XXX', Icons.phone_android,
                type: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'M-Pesa number required';
                  if (v.replaceAll(RegExp(r'\D'), '').length < 9) {
                    return 'Enter a valid M-Pesa number';
                  }
                  return null;
                }),
            Padding(padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(child: Text('STK Push will be sent to this number',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
                ])),
          ],

          if (_selectedMethod != null &&
              _selectedMethod!.type != PaymentType.mobileMoney &&
              _selectedMethod!.instructions.isNotEmpty) ...[
            _InstructionsBox(text: _selectedMethod!.instructions),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 10),

          // ── Donation Purpose ───────────────────────────────────────────
          _sectionHeader(Icons.flag_outlined, 'Donation Purpose'),
          const SizedBox(height: 10),
          _PurposeDropdown(
            value: _purpose,
            onChanged: (v) { if (v != null) setState(() => _purpose = v); },
          ),
          const SizedBox(height: 20),

          // ── Frequency ─────────────────────────────────────────────────
          _sectionHeader(Icons.repeat_outlined, 'Donation Frequency'),
          const SizedBox(height: 10),
          _FrequencyToggle(
            value: _frequency,
            onChanged: (v) => setState(() => _frequency = v),
          ),
          const SizedBox(height: 20),

          // ── Donation Amount ────────────────────────────────────────────
          _sectionHeader(Icons.attach_money, 'Donation Amount (KES)'),
          const SizedBox(height: 10),
          _presetsRow(),
          const SizedBox(height: 10),
          TextFormField(
              controller: _amtCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  hintText: 'Or enter custom amount',
                  prefixText: 'KES ',
                  prefixStyle: const TextStyle(
                      fontWeight: FontWeight.bold, color: _navy),
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _navy, width: 2)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16)),
              validator: (v) {
                final amt = double.tryParse(v?.replaceAll(',', '') ?? '');
                if (amt == null || amt <= 0) return 'Enter a valid amount';
                if (amt < 10) return 'Minimum donation is KES 10';
                return null;
              }),
          const SizedBox(height: 14),

          // ── Anonymity ──────────────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _anonymous = !_anonymous),
            child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: _anonymous ? _navy.withAlpha(12) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _anonymous ? _navy : Colors.grey.shade300)),
                child: Row(children: [
                  Icon(_anonymous
                      ? Icons.visibility_off
                      : Icons.visibility_off_outlined,
                      color: _anonymous ? _navy : Colors.grey, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Donate Anonymously',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _anonymous ? _navy : Colors.black87,
                            fontSize: 14)),
                    Text('Your name won\'t appear on public campaign displays',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500])),
                  ])),
                  Switch(
                      value: _anonymous,
                      onChanged: (v) => setState(() => _anonymous = v),
                      activeThumbColor: _navy,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ])),
          ),
          const SizedBox(height: 28),

          // ── CTA ────────────────────────────────────────────────────────
          SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _toConfirm,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_forward, size: 20),
                    const SizedBox(width: 10),
                    Text(
                        'Review Donation'
                            '${_amtCtrl.text.isEmpty ? "" : " — KES ${_f(double.tryParse(_amtCtrl.text.replaceAll(",", "")) ?? 0.0)}"}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ]))),
          const SizedBox(height: 16),
        ])),
      ]));

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1: CONFIRMATION
  // ══════════════════════════════════════════════════════════════════════════
  Widget _confirmView() => SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: _navy, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              const Icon(Icons.receipt_long, color: _gold, size: 40),
              const SizedBox(height: 10),
              const Text('Review Your Donation',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              Text('Please confirm the details below',
                  style: TextStyle(
                      color: Colors.white.withAlpha(180), fontSize: 12)),
            ])),
        const SizedBox(height: 20),

        // Summary card
        Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200)),
            child: Column(children: [
              _confirmRow('Campaign', widget.campaign.title),
              _confirmRow('Amount',
                  'KES ${_f(_amount)}', highlight: true),
              _confirmRow('Payment Method',
                  '${_selectedMethod?.emoji ?? ""} ${_selectedMethod?.name ?? ""}'),
              _confirmRow('Processing Fee', _feeLabel(), highlight: false),
              _confirmRow('You Pay',
                  'KES ${_f(_totalWithFee())}', highlight: false),
              _confirmRow('Purpose', _purpose),
              _confirmRow('Frequency', _frequency == 'one-time'
                  ? 'One-time donation'
                  : _frequency == 'monthly' ? 'Monthly recurring'
                  : 'Yearly recurring'),
              _confirmRow('Name',
                  _anonymous ? 'Anonymous' : _nameCtrl.text.trim()),
              _confirmRow('Email', _emailCtrl.text.trim()),
              _confirmRow('Phone', _phoneCtrl.text.trim()),
              if (_selectedMethod?.type == PaymentType.mobileMoney)
                _confirmRow('M-Pesa Phone', _mpesaCtrl.text.trim()),
              _confirmRow('Visibility',
                  _anonymous ? '🔒 Anonymous' : '👁 Public'),
            ])),

        if (_frequency != 'one-time') ...[
          const SizedBox(height: 12),
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: _navy.withAlpha(10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _navy.withAlpha(30))),
              child: Row(children: [
                const Icon(Icons.info_outline, color: _navy, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                    'This sets up a $_frequency recurring donation. '
                        'You will be charged KES ${_f(_amount)} '
                        '${_frequency == "monthly" ? "every month" : "every year"}. '
                        'Cancel anytime from My Donations.',
                    style: TextStyle(fontSize: 12,
                        color: Colors.grey[600], height: 1.4))),
              ])),
        ],

        const SizedBox(height: 28),
        SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _pay,
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_selectedMethod?.type == PaymentType.mobileMoney
                      ? Icons.phone_android : Icons.send_outlined, size: 20),
                  const SizedBox(width: 10),
                  Text('Confirm & Pay KES ${_f(_amount)}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                ]))),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: OutlinedButton(
            onPressed: () => setState(() => _step = 0),
            style: OutlinedButton.styleFrom(
                foregroundColor: _navy,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: _navy),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: const Text('Edit Details'))),
      ]));

  Widget _confirmRow(String label, String value,
      {bool highlight = false}) =>
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(
                  color: Colors.grey.shade100))),
          child: Row(children: [
            SizedBox(width: 120, child: Text(label,
                style: TextStyle(color: Colors.grey[500], fontSize: 12))),
            Expanded(child: Text(value,
                style: TextStyle(
                    fontWeight: highlight
                        ? FontWeight.bold : FontWeight.w500,
                    fontSize: highlight ? 16 : 13,
                    color: highlight ? _navy : Colors.black87))),
          ]));

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2: WAITING
  // ══════════════════════════════════════════════════════════════════════════
  Widget _waitingView() => Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 100, height: 100,
            decoration: const BoxDecoration(
                color: Color(0xFF006633), shape: BoxShape.circle),
            child: const Center(child: Text('M',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 48)))),
        const SizedBox(height: 28),
        const Text('Check Your Phone',
            style: TextStyle(fontSize: 22,
                fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(height: 12),
        Text(
            'An STK Push has been sent to ${_mpesaCtrl.text.trim()}.\n'
                'Enter your M-Pesa PIN to complete the payment.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: Colors.grey[600], height: 1.6)),
        const SizedBox(height: 28),
        const CircularProgressIndicator(color: _navy, strokeWidth: 3),
        const SizedBox(height: 16),
        Text('Waiting... ${_elapsed}s',
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        const SizedBox(height: 32),
        TextButton(
            onPressed: () => setState(() => _step = 0),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.red))),
      ])));

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3: SUCCESS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _successView() {
    final isPending = _selectedMethod?.type != PaymentType.mobileMoney;
    return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 100, height: 100,
                  decoration: BoxDecoration(
                      color: _green.withAlpha(20), shape: BoxShape.circle),
                  child: Icon(
                      isPending
                          ? Icons.hourglass_top_outlined
                          : Icons.check_circle,
                      color: _green, size: 64)),
              const SizedBox(height: 24),
              Text(isPending ? 'Donation Recorded 📋' : 'Thank You! 🎉',
                  style: const TextStyle(fontSize: 26,
                      fontWeight: FontWeight.bold, color: _navy)),
              const SizedBox(height: 12),
              Text(
                  isPending
                      ? 'Your donation of KES ${_f(_amount)} to '
                      '"${widget.campaign.title}" has been recorded as pending.\n\n'
                      'Please complete your ${_selectedMethod?.name ?? "payment"} '
                      'and our team will verify within 24 hours.'
                      : 'Your donation of KES ${_f(_amount)} to '
                      '"${widget.campaign.title}" has been received!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey[700], height: 1.6)),
              if (!isPending) ...[
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.email_outlined,
                      size: 14, color: _green),
                  const SizedBox(width: 4),
                  Text('Receipt sent to ${_emailCtrl.text.trim()}',
                      style: const TextStyle(
                          fontSize: 12, color: _green,
                          fontWeight: FontWeight.w600)),
                ]),
              ],
              const SizedBox(height: 8),
              Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: _navy.withAlpha(10),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.notifications_active_outlined,
                        color: _navy, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                        'Check your Notifications tab to view receipts '
                            'and donation history.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[700]))),
                  ])),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _navy, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Back to Campaigns',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)))),
            ])));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 4: FAILED
  // ══════════════════════════════════════════════════════════════════════════
  Widget _failedView() => Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 100, height: 100,
                decoration: BoxDecoration(
                    color: _red.withAlpha(20), shape: BoxShape.circle),
                child: const Icon(Icons.error_outline,
                    color: _red, size: 64)),
            const SizedBox(height: 24),
            const Text('Payment Failed',
                style: TextStyle(fontSize: 22,
                    fontWeight: FontWeight.bold, color: _red)),
            const SizedBox(height: 12),
            Text(_errorMsg,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey[600], height: 1.6)),
            const SizedBox(height: 40),
            SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () => setState(() { _step = 0; _elapsed = 0; }),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _navy, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Try Again',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)))),
            const SizedBox(height: 12),
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.grey))),
          ])));

  // ── Shared widgets ─────────────────────────────────────────────────────────
  Widget _campaignCard() => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: _navy, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.campaign, color: _gold, size: 28)),
        const SizedBox(width: 14),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.campaign.title,
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('campaigns')
                  .doc(widget.campaign.id).snapshots(),
              builder: (ctx, snap) {
                final raised = (snap.data?.get('raised') as num? ?? 0).toDouble();
                final goal   = (snap.data?.get('goal')   as num? ?? 1).toDouble();
                final pct    = (raised / goal).clamp(0.0, 1.0);
                return Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KES ${_f(raised)} raised of KES ${_f(goal)}',
                          style: TextStyle(
                              color: Colors.white.withAlpha(180),
                              fontSize: 12)),
                      const SizedBox(height: 6),
                      ClipRRect(borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                              value: pct, minHeight: 6,
                              color: _gold,
                              backgroundColor: Colors.white.withAlpha(40))),
                    ]);
              }),
        ])),
      ]));

  Widget _sectionHeader(IconData icon, String title) =>
      Row(children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _navy.withAlpha(15),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: _navy, size: 18)),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15, color: _navy)),
      ]);

  Widget _paymentMethodSelector() {
    if (_loadingMethods) {
      return const Center(child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(
              strokeWidth: 2, color: _navy)));
    }
    if (_paymentMethods.isEmpty) {
      return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.orange.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withAlpha(60))),
          child: const Row(children: [
            Icon(Icons.warning_amber_outlined,
                color: Colors.orange, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text(
                'No active payment methods. Contact the foundation.',
                style: TextStyle(
                    fontSize: 12, color: Colors.orange))),
          ]));
    }
    return Column(children: _paymentMethods.map((m) {
      final selected = _selectedMethod?.id == m.id;
      return GestureDetector(
          onTap: () => setState(() => _selectedMethod = m),
          child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  color: selected ? _navy.withAlpha(12) : Colors.white,
                  border: Border.all(
                      color: selected ? _navy : Colors.grey.shade300,
                      width: selected ? 2 : 1),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Text(m.emoji,
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: selected ? _navy : Colors.black87)),
                      if (m.description.isNotEmpty)
                        Text(m.description, style: TextStyle(
                            fontSize: 11, color: Colors.grey[600])),
                    ])),
                Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: selected ? _navy : Colors.grey.shade400,
                            width: selected ? 2 : 1.5)),
                    child: selected
                        ? Center(child: Container(
                        width: 11, height: 11,
                        decoration: const BoxDecoration(
                            color: _navy,
                            shape: BoxShape.circle)))
                        : null),
              ])));
    }).toList());
  }

  Widget _presetsRow() {
    if (_loadingPresets) {
      return const SizedBox(height: 36,
          child: Center(child: LinearProgressIndicator(
              color: _navy)));
    }
    if (_presets.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: _presets.map((p) {
      final val = p.amount.toStringAsFixed(0);
      final sel = _amtCtrl.text == val;
      return GestureDetector(
          onTap: () => setState(() => _amtCtrl.text = val),
          child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: sel ? _navy : Colors.white,
                  border: Border.all(
                      color: sel ? _navy : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(20)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('KES ${_f(p.amount)}',
                    style: TextStyle(
                        color: sel ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                if (p.label != null)
                  Text(p.label!, style: TextStyle(
                      color: sel
                          ? Colors.white.withAlpha(180)
                          : Colors.grey[500],
                      fontSize: 10)),
              ])));
    }).toList());
  }

  Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t, style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13, color: _navy)));

  Widget _field(TextEditingController c, String hint, IconData icon,
      {TextInputType type = TextInputType.text, bool required = false,
        String? Function(String?)? validator}) =>
      TextFormField(
          controller: c, keyboardType: type,
          decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: _navy),
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _navy, width: 2)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _red)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 16)),
          validator: validator ?? (required
              ? (v) => v == null || v.trim().isEmpty
              ? '$hint required' : null
              : null));

  String _f(double v) => v >= 1000000
      ? '\${(v / 1000000).toStringAsFixed(1)}M'
      : v >= 1000
      ? '\${(v / 1000).toStringAsFixed(0)}K'
      : v.toStringAsFixed(0);

  // ── Fee helpers ────────────────────────────────────────────────────────────
  double _feePercent() {
    if (_selectedMethod == null) return 0;
    return switch (_selectedMethod!.type) {
      PaymentType.mobileMoney => 0.0,   // M-Pesa: 0% — KCA absorbs
      PaymentType.online      => 0.014, // ~1.4% Flutterwave card/online
      PaymentType.bank        => 0.0,   // Bank transfer: no online fee
      _                       => 0.0,
    };
  }

  double _feeAmount()    => (_amount * _feePercent());
  double _totalWithFee() => _amount + _feeAmount();

  String _feeLabel() {
    final pct = _feePercent();
    if (pct == 0) return '0% — No processing fee 🎉';
    return '${(pct * 100).toStringAsFixed(1)}% = KES ${_feeAmount().toStringAsFixed(0)}';
  }
}

// ── Purpose Dropdown ──────────────────────────────────────────────────────────
class _PurposeDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  const _PurposeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300)),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
              value: value,
              onChanged: onChanged,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: _navy),
              items: _purposes.map((p) => DropdownMenuItem(
                  value: p,
                  child: Row(children: [
                    const Icon(Icons.flag_outlined, color: _navy, size: 16),
                    const SizedBox(width: 8),
                    Text(p, style: const TextStyle(fontSize: 14)),
                  ]))).toList())));
}

// ── Frequency Toggle ──────────────────────────────────────────────────────────
class _FrequencyToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _FrequencyToggle(
      {required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _btn('one-time', 'One-Time', Icons.looks_one_outlined),
      const SizedBox(width: 8),
      _btn('monthly',  'Monthly',  Icons.repeat_outlined),
      const SizedBox(width: 8),
      _btn('yearly',   'Yearly',   Icons.calendar_today_outlined),
    ]);
  }

  Widget _btn(String v, String label, IconData icon) {
    final sel = value == v;
    return Expanded(
        child: GestureDetector(
            onTap: () => onChanged(v),
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: sel ? _navy : Colors.white,
                    border: Border.all(
                        color: sel ? _navy : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Icon(icon,
                      color: sel ? _gold : Colors.grey, size: 18),
                  const SizedBox(height: 4),
                  Text(label,
                      style: TextStyle(
                          color: sel ? Colors.white : Colors.grey[700],
                          fontSize: 11,
                          fontWeight: sel
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ]))));
  }
}

// ── Instructions box ──────────────────────────────────────────────────────────
class _InstructionsBox extends StatelessWidget {
  final String text;
  const _InstructionsBox({required this.text});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _navy.withAlpha(10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _navy.withAlpha(30))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.info_outline, color: _navy, size: 16),
              SizedBox(width: 8),
              Text('Payment Instructions',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      color: _navy, fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            Text(text, style: TextStyle(
                fontSize: 12, color: Colors.grey[700], height: 1.5)),
          ]));
}