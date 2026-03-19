// lib/screens/donation/bank_transfer_screen.dart
// spell-checker: disable
//
// Bank transfer payment screen:
//   • Shows KCA bank account details
//   • Donor pastes/types their TxID or bank reference
//   • Optional: upload deposit slip (file_picker — image or PDF)
//   • Saves pending donation to Firestore with transaction proof

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';           // ✅ provides Uint8List + Clipboard
// ✅ FIX: removed 'dart:typed_data' import (line 10 warning).
//    Uint8List is re-exported by 'package:flutter/services.dart' which is
//    already imported above, making dart:typed_data redundant.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/campaign.dart';
import '../../services/notification_service.dart';

const _navy  = Color(0xFF1B2263);
const _gold  = Color(0xFFF5A800);
const _green = Color(0xFF10B981);
const _bg    = Color(0xFFF5F7FA);
const _red   = Color(0xFFDC2626);

// KCA bank accounts — update with real details before going live
const _bankAccounts = [
  _BankAccount(
    bank:    'Equity Bank',
    branch:  'Nairobi CBD Branch',
    account: '0540200001234',
    name:    'KCA University Foundation',
    swift:   'EQBLKENA',
    paybill: '247247',
    accNo:   '0540200001234',
  ),
  _BankAccount(
    bank:    'KCB Bank',
    branch:  'University Way Branch',
    account: '1234567890',
    name:    'KCA University Foundation',
    swift:   'KCBLKENX',
    paybill: '522522',
    accNo:   '1234567890',
  ),
];

class BankTransferScreen extends StatefulWidget {
  final Campaign campaign;
  final String   donorName;
  final String   donorEmail;
  final String   donorPhone;
  final double   amount;
  final String   purpose;
  final String   frequency;
  final bool     anonymous;
  final String   selectedBank;

  const BankTransferScreen({
    super.key,
    required this.campaign,
    required this.donorName,
    required this.donorEmail,
    required this.donorPhone,
    required this.amount,
    this.purpose     = 'General Fund',
    this.frequency   = 'one-time',
    this.anonymous   = false,
    this.selectedBank = '',
  });

  @override
  State<BankTransferScreen> createState() => _BankTransferScreenState();
}

class _BankTransferScreenState extends State<BankTransferScreen> {
  final _txCtrl   = TextEditingController();
  final _noteCtrl = TextEditingController();
  int     _step      = 0;   // 0=details, 1=submitting, 2=success
  String? _slipPath;
  String? _slipUrl;
  bool    _uploading = false;

  _BankAccount get _account {
    if (widget.selectedBank.isNotEmpty) {
      return _bankAccounts.firstWhere(
            (b) => b.bank.toLowerCase()
            .contains(widget.selectedBank.toLowerCase()),
        orElse: () => _bankAccounts.first,
      );
    }
    return _bankAccounts.first;
  }

  @override
  void dispose() {
    _txCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Bank Transfer',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: Container(height: 3, color: _gold)),
      ),
      body: _step == 2 ? _successView() : _mainView(),
    );
  }

  // ── Main view ──────────────────────────────────────────────────────────────
  Widget _mainView() => SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SummaryBanner(
            campaign: widget.campaign.title,
            amount:   widget.amount,
            purpose:  widget.purpose),
        const SizedBox(height: 20),

        _sectionHeader(Icons.account_balance_outlined, 'Transfer To'),
        const SizedBox(height: 10),
        _BankDetailsCard(account: _account, amount: widget.amount),
        const SizedBox(height: 20),

        _sectionHeader(Icons.phone_android_outlined, 'Or Pay via Paybill'),
        const SizedBox(height: 10),
        _PaybillCard(account: _account),
        const SizedBox(height: 24),

        _sectionHeader(Icons.task_alt_outlined, 'Confirm Your Transfer'),
        const SizedBox(height: 10),
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Transaction Reference / Bank Ref *',
                      style: TextStyle(fontWeight: FontWeight.w700,
                          fontSize: 13, color: _navy)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: _txCtrl,
                      decoration: InputDecoration(
                          hintText: 'e.g. KCBDP2024XXXXX or EQ12345',
                          prefixIcon: const Icon(Icons.numbers_outlined,
                              color: _navy),
                          filled: true,
                          fillColor: _bg,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14))),
                  const SizedBox(height: 16),

                  const Text('Upload Deposit Slip (optional)',
                      style: TextStyle(fontWeight: FontWeight.w700,
                          fontSize: 13, color: _navy)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickSlip,
                    child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: _slipPath != null
                                ? _green.withAlpha(15)
                                : _navy.withAlpha(8),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _slipPath != null
                                    ? _green
                                    : _navy.withAlpha(40))),
                        child: Row(children: [
                          _uploading
                              ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _navy))
                              : Icon(
                              _slipPath != null
                                  ? Icons.check_circle_outline
                                  : Icons.upload_file_outlined,
                              color: _slipPath != null
                                  ? _green : _navy,
                              size: 24),
                          const SizedBox(width: 12),
                          Expanded(child: Text(
                              _slipPath != null
                                  ? 'Slip uploaded ✓'
                                  : 'Tap to upload photo or PDF',
                              style: TextStyle(
                                  color: _slipPath != null
                                      ? _green : Colors.grey[600],
                                  fontSize: 13,
                                  fontWeight: _slipPath != null
                                      ? FontWeight.w600
                                      : FontWeight.normal))),
                          if (_slipPath != null)
                            IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.grey, size: 18),
                                onPressed: () => setState(
                                        () { _slipPath = null; _slipUrl = null; }),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints()),
                        ])),
                  ),
                  const SizedBox(height: 16),

                  const Text('Additional Note (optional)',
                      style: TextStyle(fontWeight: FontWeight.w700,
                          fontSize: 13, color: _navy)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: _noteCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                          hintText: 'Any additional information...',
                          filled: true,
                          fillColor: _bg,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none))),
                ])),

        const SizedBox(height: 24),
        Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: _navy.withAlpha(8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _navy.withAlpha(25))),
            child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: _navy, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                      'After submitting, our team will verify your transfer '
                          'within 1–2 business days. You will receive an in-app '
                          'notification once confirmed.',
                      style: TextStyle(
                          fontSize: 12, height: 1.5,
                          color: Color(0xFF374151)))),
                ])),

        const SizedBox(height: 24),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: _step == 1 ? null : _submit,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: _step == 1
                    ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white)),
                      SizedBox(width: 12),
                      Text('Submitting...'),
                    ])
                    : const Text('I Have Completed the Transfer',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15)))),
        const SizedBox(height: 24),
      ]));

  // ── Success view ────────────────────────────────────────────────────────────
  Widget _successView() => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                        color: _green.withAlpha(15),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.hourglass_top_outlined,
                        color: _green, size: 52)),
                const SizedBox(height: 24),
                const Text('Transfer Recorded!',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _navy)),
                const SizedBox(height: 12),
                Text(
                    'Your donation of KES ${_f(widget.amount)} to '
                        '"${widget.campaign.title}" has been recorded as pending.\n\n'
                        'Our team will verify within 1–2 business days.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.6)),
                const SizedBox(height: 28),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            padding:
                            const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: const Text('Back to Campaigns',
                            style: TextStyle(
                                fontWeight: FontWeight.bold)))),
              ])));

  // ── Upload slip ─────────────────────────────────────────────────────────────
  Future<void> _pickSlip() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      setState(() { _uploading = true; _slipPath = file.name; });

      final user = FirebaseAuth.instance.currentUser;
      final path = 'deposit_slips/${user?.uid ?? "anon"}/'
          '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref  = FirebaseStorage.instance.ref().child(path);

      // ✅ Uint8List comes from flutter/services.dart — no dart:typed_data needed
      final bytes = file.bytes ?? Uint8List(0);
      final UploadTask task;
      if (kIsWeb) {
        task = ref.putData(bytes,
            SettableMetadata(contentType: 'application/octet-stream'));
      } else {
        task = ref.putData(bytes);
      }
      final snap = await task;
      _slipUrl = await snap.ref.getDownloadURL();
      setState(() => _uploading = false);
    } catch (e) {
      setState(() => _uploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Upload failed: $e'),
                backgroundColor: _red));
      }
    }
  }

  // ── Submit ──────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_txCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please enter your transaction reference'),
              backgroundColor: _red));
      return;
    }
    setState(() => _step = 1);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final ref  = FirebaseFirestore.instance.collection('donations').doc();
      await ref.set({
        'id':               ref.id,
        'donor_id':         user?.uid ?? '',
        'donor_name':       widget.donorName,
        'donor_email':      widget.donorEmail,
        'donor_phone':      widget.donorPhone,
        'campaign_id':      widget.campaign.id,
        'campaign_title':   widget.campaign.title,
        'amount':           widget.amount,
        'payment_method':   _account.bank,
        'payment_type':     'bank_transfer',
        'purpose':          widget.purpose,
        'frequency':        widget.frequency,
        'is_anonymous':     widget.anonymous,
        'transaction_ref':  _txCtrl.text.trim(),
        'deposit_slip_url': _slipUrl,
        'note':             _noteCtrl.text.trim(),
        'bank_name':        _account.bank,
        'bank_account':     _account.account,
        'status':           'pending',
        'type':             'bank_transfer',
        'created_at':       FieldValue.serverTimestamp(),
      });

      // ✅ notifyDonationReceived now defined in NotificationService
      if (user != null) {
        try {
          await NotificationService.notifyDonationReceived(
            donorName:     widget.anonymous ? 'Anonymous' : widget.donorName,
            amount:        widget.amount,
            campaignTitle: widget.campaign.title,
            donorId:       user.uid,
            campaignId:    widget.campaign.id,
            transactionId: _txCtrl.text.trim(),
          );
        } catch (_) {}
      }

      setState(() => _step = 2);
    } catch (e) {
      setState(() => _step = 0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'),
                backgroundColor: _red));
      }
    }
  }

  Widget _sectionHeader(IconData icon, String title) => Row(children: [
    Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: _navy.withAlpha(15),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: _navy, size: 18)),
    const SizedBox(width: 10),
    Text(title,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: _navy)),
  ]);

  String _f(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}K' : v.toStringAsFixed(0);
}

// ── Bank details card ─────────────────────────────────────────────────────────
class _BankDetailsCard extends StatelessWidget {
  final _BankAccount account;
  final double       amount;
  const _BankDetailsCard(
      {required this.account, required this.amount});

  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(children: [
        Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
                color: _navy,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(14))),
            child: Row(children: [
              const Icon(Icons.account_balance, color: _gold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(account.bank,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15))),
            ])),
        Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _row('Account Name',   account.name),
              _row('Account Number', account.account, copyable: true),
              _row('Branch',         account.branch),
              _row('SWIFT/BIC',      account.swift,   copyable: true),
              const Divider(height: 20),
              _row('Amount to Transfer', 'KES ${_f(amount)}', bold: true),
              _row('Reference',          'KCA DONATION',      copyable: true),
            ])),
      ]));

  Widget _row(String l, String v,
      {bool copyable = false, bool bold = false}) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(
                width: 140,
                child: Text(l,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[500]))),
            Expanded(
                child: Text(v,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                        bold ? FontWeight.bold : FontWeight.w600,
                        color: _navy))),
            if (copyable)
              GestureDetector(
                  onTap: () => Clipboard.setData(ClipboardData(text: v)),
                  child: const Icon(Icons.copy_outlined,
                      size: 15, color: Colors.grey)),
          ]));

  String _f(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}K' : v.toStringAsFixed(0);
}

// ── Paybill card ──────────────────────────────────────────────────────────────
class _PaybillCard extends StatelessWidget {
  final _BankAccount account;
  const _PaybillCard({required this.account});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(children: [
        Row(children: [
          const Text('📱', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text(account.bank,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _navy)),
        ]),
        const SizedBox(height: 12),
        _row('Paybill Number', account.paybill),
        _row('Account Number', account.accNo),
        _row('Reference',      'KCA DONATION'),
      ]));

  Widget _row(String l, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
            width: 140,
            child: Text(l,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]))),
        Expanded(
            child: Text(v,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _navy))),
        GestureDetector(
            onTap: () => Clipboard.setData(ClipboardData(text: v)),
            child: const Icon(Icons.copy_outlined,
                size: 14, color: Colors.grey)),
      ]));
}

// ── Summary banner ────────────────────────────────────────────────────────────
class _SummaryBanner extends StatelessWidget {
  final String campaign, purpose;
  final double amount;
  const _SummaryBanner({
    required this.campaign,
    required this.amount,
    required this.purpose,
  });

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: _navy, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.account_balance_outlined,
                color: _gold, size: 24)),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(campaign,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(purpose,
                      style: TextStyle(
                          color: Colors.white.withAlpha(180), fontSize: 12)),
                ])),
        Text('KES ${_f(amount)}',
            style: const TextStyle(
                color: _gold,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ]));

  String _f(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}K' : v.toStringAsFixed(0);
}

// ── Data class ────────────────────────────────────────────────────────────────
class _BankAccount {
  final String bank, branch, account, name, swift, paybill, accNo;
  const _BankAccount({
    required this.bank,
    required this.branch,
    required this.account,
    required this.name,
    required this.swift,
    required this.paybill,
    required this.accNo,
  });
}