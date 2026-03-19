// lib/screens/donations/my_donations_screen.dart
// spell-checker: disable
//
// Shows the current donor's complete donation history.
// Features: status badges, payment method icon, receipt view, share.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../../services/receipt_service.dart';

const _navy  = Color(0xFF1B2263);
const _gold  = Color(0xFFF5A800);
const _green = Color(0xFF10B981);
const _bg    = Color(0xFFF5F7FA);
const _red   = Color(0xFFDC2626);
const _amber = Color(0xFFF59E0B);

class MyDonationsScreen extends StatefulWidget {
  const MyDonationsScreen({super.key});
  @override
  State<MyDonationsScreen> createState() => _MyDonationsScreenState();
}

class _MyDonationsScreenState extends State<MyDonationsScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _filter = 'all'; // all | completed | pending | failed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('My Donations',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: Container(height: 3, color: _gold)),
      ),
      body: Column(children: [
        // ── Stats strip ───────────────────────────────────────────────────
        _StatsStrip(uid: _uid),

        // ── Filter chips ──────────────────────────────────────────────────
        Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _chip('All',       'all'),
                _chip('Completed', 'completed'),
                _chip('Pending',   'pending'),
                _chip('Failed',    'failed'),
              ]),
            )),

        // ── Donation list ─────────────────────────────────────────────────
        Expanded(child: _DonationList(uid: _uid, filter: _filter)),
      ]),
    );
  }

  Widget _chip(String label, String value) {
    final active = _filter == value;
    return GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
                color: active ? _navy : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active ? _navy : Colors.grey.shade300)),
            child: Text(label,
                style: TextStyle(
                    color: active ? Colors.white : Colors.grey[700],
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13))));
  }
}

// ── Stats strip ───────────────────────────────────────────────────────────────
class _StatsStrip extends StatelessWidget {
  final String uid;
  const _StatsStrip({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('donor_id', isEqualTo: uid)
            .snapshots(),
        builder: (ctx, snap) {
          final docs = snap.data?.docs ?? [];
          double total = 0;
          int completed = 0;
          int pending   = 0;
          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            final status = data['status'] as String? ?? '';
            final amount = (data['amount'] as num? ?? 0).toDouble();
            if (status == 'completed') { total += amount; completed++; }
            if (status == 'pending')   pending++;
          }
          return Container(
            color: _navy,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(children: [
              _stat(_fmt(total), 'Total Donated', Icons.volunteer_activism),
              _div(),
              _stat('$completed', 'Successful', Icons.check_circle_outline),
              _div(),
              _stat('${docs.length}', 'All Donations', Icons.receipt_long_outlined),
              _div(),
              _stat('$pending', 'Pending', Icons.hourglass_top_outlined),
            ]),
          );
        });
  }

  Widget _stat(String v, String l, IconData icon) => Expanded(
      child: Column(children: [
        Icon(icon, color: _gold, size: 18),
        const SizedBox(height: 4),
        Text(v, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(l, style: TextStyle(
            color: Colors.white.withAlpha(180), fontSize: 11)),
      ]));

  Widget _div() => Container(
      width: 1, height: 40,
      color: Colors.white.withAlpha(40),
      margin: const EdgeInsets.symmetric(horizontal: 4));

  String _fmt(double v) => v >= 1000000
      ? 'KES ${(v / 1000000).toStringAsFixed(1)}M'
      : v >= 1000 ? 'KES ${(v / 1000).toStringAsFixed(0)}K'
      : 'KES ${v.toStringAsFixed(0)}';
}

// ── Donation list ─────────────────────────────────────────────────────────────
class _DonationList extends StatelessWidget {
  final String uid;
  final String filter;
  const _DonationList({required this.uid, required this.filter});

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('donations')
        .where('donor_id', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .limit(100);

    if (filter != 'all') {
      q = FirebaseFirestore.instance
          .collection('donations')
          .where('donor_id', isEqualTo: uid)
          .where('status', isEqualTo: filter)
          .orderBy('created_at', descending: true)
          .limit(100);
    }

    return StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _navy, strokeWidth: 2));
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _EmptyState(filter: filter);
          }
          return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (ctx, i) {
                final d    = docs[i].data() as Map<String, dynamic>;
                final id   = docs[i].id;
                return _DonationCard(id: id, data: d);
              });
        });
  }
}

// ── Individual donation card ──────────────────────────────────────────────────
class _DonationCard extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;
  const _DonationCard({required this.id, required this.data});
  @override
  State<_DonationCard> createState() => _DonationCardState();
}

class _DonationCardState extends State<_DonationCard> {
  bool _generating = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final status  = d['status']         as String? ?? 'pending';
    final amount  = (d['amount'] as num? ?? 0).toDouble();
    final method  = d['payment_method'] as String? ?? '—';
    final campaign= d['campaign_title'] as String? ?? 'General';
    final purpose = d['purpose']        as String?;
    final txId    = d['transaction_id'] as String? ?? widget.id;
    final anon    = d['is_anonymous']   as bool? ?? false;
    final ts      = d['created_at'];
    DateTime? dt;
    if (ts is Timestamp)  dt = ts.toDate();
    else if (ts is String) dt = DateTime.tryParse(ts);

    final (statusColor, statusBg, statusIcon) = _statusStyle(status);

    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 6, offset: const Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top row ─────────────────────────────────────────────────────
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Payment method icon
                Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                        color: _navy.withAlpha(12),
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text(
                        _methodEmoji(method),
                        style: const TextStyle(fontSize: 22)))),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(campaign,
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 14, color: _navy),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(method,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  if (purpose != null)
                    Text('Purpose: $purpose',
                        style: TextStyle(fontSize: 11,
                            color: Colors.grey[500], fontStyle: FontStyle.italic)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('KES ${_fmt(amount)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17, color: _navy)),
                  const SizedBox(height: 6),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(_statusLabel(status),
                            style: TextStyle(
                                color: statusColor, fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ])),
                ]),
              ])),

          // ── Divider ──────────────────────────────────────────────────────
          Divider(height: 1, color: Colors.grey.shade100),

          // ── Bottom row ──────────────────────────────────────────────────
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
              child: Row(children: [
                const Icon(Icons.access_time_outlined,
                    size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                    dt != null
                        ? DateFormat('dd MMM yyyy, HH:mm').format(dt)
                        : '—',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                if (anon) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.visibility_off_outlined,
                      size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Anonymous',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                ],
                const Spacer(),
                // Receipt button (completed only)
                if (status == 'completed')
                  _generating
                      ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _navy))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                    TextButton.icon(
                        onPressed: () => _viewReceipt(d, txId),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4)),
                        icon: const Icon(Icons.receipt_long,
                            size: 15, color: _navy),
                        label: const Text('Receipt',
                            style: TextStyle(
                                color: _navy, fontSize: 12,
                                fontWeight: FontWeight.w600))),
                    TextButton.icon(
                        onPressed: () => _shareReceipt(d, txId),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4)),
                        icon: const Icon(Icons.share_outlined,
                            size: 15, color: _green),
                        label: const Text('Share',
                            style: TextStyle(
                                color: _green, fontSize: 12,
                                fontWeight: FontWeight.w600))),
                  ]),
                if (status == 'pending')
                  TextButton.icon(
                      onPressed: () => _showPendingInfo(d),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4)),
                      icon: const Icon(Icons.info_outline,
                          size: 15, color: _amber),
                      label: const Text('Details',
                          style: TextStyle(
                              color: _amber, fontSize: 12,
                              fontWeight: FontWeight.w600))),
              ])),
        ]));
  }

  Future<void> _shareReceipt(Map<String, dynamic> d, String txId) async {
    setState(() => _generating = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      // generateAndSend already handles mobile share via share_plus on non-web
      await ReceiptService.generateAndSend(
        donorName:     d['donor_name']  as String? ?? user.displayName ?? '',
        donorEmail:    d['donor_email'] as String? ?? user.email ?? '',
        amount:        (d['amount'] as num? ?? 0).toDouble(),
        campaignTitle: d['campaign_title'] as String? ?? '',
        transactionId: txId,
        phone:         d['donor_phone'] as String? ?? '',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Share failed: $e'),
                backgroundColor: _red));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _viewReceipt(Map<String, dynamic> d, String txId) async {
    setState(() => _generating = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      await ReceiptService.generateAndSend(
        donorName:     d['donor_name']  as String? ?? user.displayName ?? '',
        donorEmail:    d['donor_email'] as String? ?? user.email ?? '',
        amount:        (d['amount'] as num? ?? 0).toDouble(),
        campaignTitle: d['campaign_title'] as String? ?? '',
        transactionId: txId,
        phone:         d['donor_phone'] as String? ?? '',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not generate receipt: $e'),
                backgroundColor: _red));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _showPendingInfo(Map<String, dynamic> d) {
    final method = d['payment_method'] as String? ?? '';
    final instructions = d['instructions'] as String? ?? '';
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.hourglass_top_outlined, color: _amber),
        SizedBox(width: 8),
        Text('Pending Payment', style: TextStyle(color: _navy, fontSize: 16)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your donation via $method is pending verification.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            if (instructions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(instructions,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700],
                      height: 1.5)),
            ],
            const SizedBox(height: 12),
            const Text(
                'Please ensure you have completed your payment and our '
                    'team will verify and confirm within 24 hours.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('OK')),
      ],
    ));
  }

  (Color, Color, IconData) _statusStyle(String s) => switch (s) {
    'completed' => (_green, _green.withAlpha(20),   Icons.check_circle_outline),
    'pending'   => (_amber, _amber.withAlpha(25),   Icons.hourglass_top_outlined),
    'failed'    => (_red,   _red.withAlpha(20),     Icons.cancel_outlined),
    'refunded'  => (Colors.purple, Colors.purple.withAlpha(20), Icons.undo_outlined),
    _           => (Colors.grey, Colors.grey.withAlpha(20), Icons.help_outline),
  };

  String _statusLabel(String s) => switch (s) {
    'completed' => 'Completed',
    'pending'   => 'Pending',
    'failed'    => 'Failed',
    'refunded'  => 'Refunded',
    _           => s.toUpperCase(),
  };

  String _methodEmoji(String m) {
    final l = m.toLowerCase();
    if (l.contains('mpesa') || l.contains('m-pesa')) return '📱';
    if (l.contains('equity'))  return '🏦';
    if (l.contains('kcb'))     return '🏦';
    if (l.contains('bank'))    return '🏛️';
    if (l.contains('card') || l.contains('visa') || l.contains('mastercard')) return '💳';
    if (l.contains('paypal')) return '🅿️';
    return '💰';
  }

  String _fmt(double v) => v >= 1000000
      ? '${(v / 1000000).toStringAsFixed(1)}M'
      : v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}K'
      : v.toStringAsFixed(0);
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) => Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.volunteer_activism_outlined,
            size: 72, color: Colors.grey[200]),
        const SizedBox(height: 16),
        Text(
            filter == 'all'
                ? 'No donations yet'
                : 'No ${_label(filter).toLowerCase()} donations',
            style: const TextStyle(fontSize: 17,
                fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(height: 8),
        Text(
            filter == 'all'
                ? 'Your donation history will appear here\nafter you make your first donation.'
                : 'No donations with this status found.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13,
                color: Colors.grey[500], height: 1.5)),
        if (filter == 'all') ...[
          const SizedBox(height: 24),
          ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.campaign_outlined, size: 18),
              label: const Text('Browse Campaigns')),
        ],
      ]));

  String _label(String s) => switch (s) {
    'completed' => 'Completed',
    'pending'   => 'Pending',
    'failed'    => 'Failed',
    _           => s,
  };
}