// lib/services/card_payment_service.dart
// spell-checker: disable
//
// Flutterwave Rave card & mobile money payments.
//
// ── SETUP (do this once) ──────────────────────────────────────────────────────
//   1. Run: flutter pub get   (resolves flutterwave_standard: ^1.0.9)
//   2. Set your keys in FlutterwaveConfig below.
//   3. Uncomment the flutterwave import + the charge() real block.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// TODO: uncomment after flutter pub get resolves flutterwave_standard
// import 'package:flutterwave_standard/flutterwave.dart';

// ── Config ────────────────────────────────────────────────────────────────────
class FlutterwaveConfig {
  static const publicKey     = 'FLWPUBK_TEST-XXXXXXXXXXXXXXXXXXXXXXXX-X'; // replace
  static const encryptionKey = 'FLWENCK_TEST-XXXXXXXXXXXXXXXXXXXXXXXX-X'; // replace
  static const isProduction  = false;
  static const currency      = 'KES';
  static const country       = 'KE';
}

// ── Result ────────────────────────────────────────────────────────────────────
class CardPaymentResult {
  final bool    success;
  final String? transactionId;
  final String? error;
  const CardPaymentResult({required this.success, this.transactionId, this.error});
}

// ── Service ───────────────────────────────────────────────────────────────────
class CardPaymentService {

  static Future<CardPaymentResult> charge({
    required BuildContext context,
    required double       amount,
    required String       email,
    required String       name,
    required String       phone,
    required String       campaignId,
    required String       campaignTitle,
    required String       donorId,
    String                purpose   = 'General Fund',
    String                frequency = 'one-time',
    bool                  anonymous = false,
  }) async {
    final txRef = 'KCA-${DateTime.now().millisecondsSinceEpoch}';

    // ── STUB: simulate payment until flutterwave_standard is installed ─────────
    // TODO: remove this stub and uncomment the real block below once resolved.
    const navy = Color(0xFF1B2263);
    const gold = Color(0xFFF5A800);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.credit_card, color: navy),
          SizedBox(width: 8),
          Text('Card Payment', style: TextStyle(color: navy, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFFEEF0F8),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                const Text('Amount', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text('KES ${_fmt(amount)}',
                    style: const TextStyle(color: navy, fontSize: 24,
                        fontWeight: FontWeight.bold)),
                Text(campaignTitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ])),
          const SizedBox(height: 12),
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF3DC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: gold)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Color(0xFF92570A), size: 14),
                SizedBox(width: 6),
                Expanded(child: Text(
                    'Run flutter pub get to enable live card payments '
                        'via Flutterwave. This simulates success for testing.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF92570A)))),
              ])),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: navy),
              child: const Text('Simulate Success',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirmed != true) {
      return const CardPaymentResult(success: false, error: 'Payment was cancelled.');
    }

    // Record simulated payment to Firestore
    final docId = await _recordDonation(
      txRef: txRef, flwRef: 'SIM-$txRef',
      donorId: donorId, donorName: name, donorEmail: email,
      donorPhone: phone, amount: amount, campaignId: campaignId,
      campaignTitle: campaignTitle, purpose: purpose,
      frequency: frequency, anonymous: anonymous,
    );
    return CardPaymentResult(success: true, transactionId: docId);
    // ── END STUB ──────────────────────────────────────────────────────────────

    // ── TODO: REAL FLUTTERWAVE BLOCK ──────────────────────────────────────────
    // Uncomment after flutter pub get resolves flutterwave_standard:
    //
    // try {
    //   final flutterwave = Flutterwave(
    //     context:        context,
    //     publicKey:      FlutterwaveConfig.publicKey,
    //     currency:       FlutterwaveConfig.currency,
    //     amount:         amount.toStringAsFixed(0),
    //     customer:       Customer(name: name, phoneNumber: phone, email: email),
    //     paymentOptions: 'card,mobilemoney,ussd',
    //     customization:  Customization(
    //       title:       'KCA Foundation Donation',
    //       description: campaignTitle,
    //       logo: 'https://kca-university-foundation.web.app/icons/Icon-192.png',
    //     ),
    //     txRef:       txRef,
    //     isTestMode:  !FlutterwaveConfig.isProduction,
    //     redirectUrl: 'https://kca-university-foundation.web.app/payment-callback',
    //   );
    //   final response = await flutterwave.charge();
    //   if (response == null) return const CardPaymentResult(success: false, error: 'Cancelled.');
    //   if (response.status == 'successful' || response.status == 'completed') {
    //     final docId = await _recordDonation(
    //       txRef: txRef, flwRef: response.transactionId ?? txRef,
    //       donorId: donorId, donorName: name, donorEmail: email,
    //       donorPhone: phone, amount: amount, campaignId: campaignId,
    //       campaignTitle: campaignTitle, purpose: purpose,
    //       frequency: frequency, anonymous: anonymous,
    //     );
    //     return CardPaymentResult(success: true, transactionId: docId);
    //   }
    //   return CardPaymentResult(success: false, error: 'Status: ${response.status}');
    // } catch (e) {
    //   return CardPaymentResult(success: false, error: 'Error: $e');
    // }
    // ── END TODO ──────────────────────────────────────────────────────────────
  }

  // ── Firestore record ──────────────────────────────────────────────────────
  static Future<String> _recordDonation({
    required String txRef, required String flwRef,
    required String donorId, required String donorName,
    required String donorEmail, required String donorPhone,
    required double amount, required String campaignId,
    required String campaignTitle, required String purpose,
    required String frequency, required bool anonymous,
  }) async {
    final db  = FirebaseFirestore.instance;
    final ref = db.collection('donations').doc();
    await ref.set({
      'id': ref.id, 'donor_id': donorId, 'donor_name': donorName,
      'donor_email': donorEmail, 'donor_phone': donorPhone,
      'campaign_id': campaignId, 'campaign_title': campaignTitle,
      'amount': amount, 'payment_method': 'Card (Flutterwave)',
      'payment_type': 'card', 'purpose': purpose, 'frequency': frequency,
      'is_anonymous': anonymous, 'transaction_id': flwRef, 'tx_ref': txRef,
      'status': 'completed', 'type': 'card',
      'created_at': FieldValue.serverTimestamp(),
    });
    if (campaignId.isNotEmpty) {
      await db.collection('campaigns').doc(campaignId)
          .update({'raised': FieldValue.increment(amount)});
    }
    return ref.id;
  }

  // ── Fee calculator ────────────────────────────────────────────────────────
  static double calculateFee(double amount, {bool international = false}) {
    final pct = international ? 0.038 : 0.014;
    return (amount * pct).clamp(0, 2500).toDouble();
  }

  static String _fmt(double v) => v >= 1000
      ? '${(v / 1000).toStringAsFixed(0)}K'
      : v.toStringAsFixed(0);
}

// ── Fee breakdown widget ──────────────────────────────────────────────────────
class FeeBreakdownCard extends StatefulWidget {
  final double amount;
  final String paymentMethod;
  const FeeBreakdownCard({super.key, required this.amount, required this.paymentMethod});

  @override
  State<FeeBreakdownCard> createState() => _FeeBreakdownCardState();
}

class _FeeBreakdownCardState extends State<FeeBreakdownCard> {
  bool _international = false;

  double get _fee {
    if (widget.paymentMethod.toLowerCase().contains('card')) {
      return CardPaymentService.calculateFee(widget.amount, international: _international);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF1B2263);
    final method  = widget.paymentMethod.toLowerCase();
    final hasCard = method.contains('card');

    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.receipt_outlined, color: navy, size: 18),
            SizedBox(width: 8),
            Text('Fee Breakdown', style: TextStyle(
                fontWeight: FontWeight.bold, color: navy, fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          if (hasCard) ...[
            Row(children: [
              const Icon(Icons.public, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              const Expanded(child: Text('International card',
                  style: TextStyle(fontSize: 13))),
              Switch(
                  value: _international,
                  onChanged: (v) => setState(() => _international = v),
                  activeThumbColor: navy,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ]),
            const SizedBox(height: 8),
          ],
          _feeRow('Donation amount', 'KES ${_fmt(widget.amount)}'),
          _feeRow(
              hasCard
                  ? 'Card fee (${_international ? "3.8%" : "1.4%"})'
                  : method.contains('mpesa') ? 'M-Pesa fee' : 'Transfer fee',
              _fee == 0 ? 'Free 🎉' : 'KES ${_fmt(_fee)}',
              valueColor: _fee == 0 ? const Color(0xFF10B981) : null),
          const Divider(height: 16),
          _feeRow('Total charged', 'KES ${_fmt(widget.amount + _fee)}', bold: true),
          if (!hasCard) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.check_circle_outline,
                  color: Color(0xFF10B981), size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(
                  method.contains('mpesa')
                      ? 'No additional fee — M-Pesa is free'
                      : 'No processing fee for bank transfers',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF10B981)))),
            ]),
          ],
        ]));
  }

  Widget _feeRow(String label, String value,
      {bool bold = false, Color? valueColor}) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
            Text(value, style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: valueColor ?? const Color(0xFF1B2263))),
          ]));

  String _fmt(double v) => v >= 1000
      ? '${(v / 1000).toStringAsFixed(1)}K'
      : v.toStringAsFixed(0);
}