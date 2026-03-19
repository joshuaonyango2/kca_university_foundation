// lib/screens/notifications/notifications_screen.dart
// Donor-side notifications & receipts tab.
// Shows: donation receipts, campaign updates, system messages.
// spell-checker: disable

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

const _navy  = Color(0xFF1B2263);
const _gold  = Color(0xFFF5A800);
const _green = Color(0xFF10B981);
const _bg    = Color(0xFFF5F7FA);
const _red   = Color(0xFFDC2626);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _db  = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Mark a notification as read
  Future<void> _markRead(String docId) async {
    try {
      await _db.collection('notifications').doc(docId).update({'is_read': true});
    } catch (_) {}
  }

  /// Mark all as read for this user
  Future<void> _markAllRead() async {
    final snap = await _db.collection('notifications')
        .where('recipient_id', isEqualTo: _uid)
        .where('is_read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'is_read': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Header ────────────────────────────────────────────────────────────
      Container(
          color: Colors.white,
          child: Column(children: [
            // Unread badge row
            StreamBuilder<QuerySnapshot>(
                stream: _db.collection('notifications')
                    .where('recipient_id', isEqualTo: _uid)
                    .where('is_read', isEqualTo: false)
                    .snapshots(),
                builder: (ctx, snap) {
                  final unread = snap.data?.docs.length ?? 0;
                  if (unread == 0) return const SizedBox.shrink();
                  return Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                          color: _navy.withAlpha(10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _navy.withAlpha(30))),
                      child: Row(children: [
                        const Icon(Icons.notifications_active,
                            color: _navy, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                            '$unread unread notification${unread == 1 ? "" : "s"}',
                            style: const TextStyle(
                                color: _navy, fontWeight: FontWeight.w600,
                                fontSize: 13))),
                        TextButton(
                            onPressed: _markAllRead,
                            style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4)),
                            child: const Text('Mark all read',
                                style: TextStyle(color: _navy, fontSize: 12))),
                      ]));
                }),
            const SizedBox(height: 4),
            TabBar(
              controller: _tabs,
              labelColor: _navy,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _gold,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.notifications_outlined, size: 18),
                    text: 'All'),
                Tab(icon: Icon(Icons.receipt_long_outlined, size: 18),
                    text: 'Receipts'),
              ],
            ),
          ])),

      // ── Tab content ───────────────────────────────────────────────────────
      Expanded(child: TabBarView(
        controller: _tabs,
        children: [
          _NotifList(uid: _uid, filterType: null,     onMarkRead: _markRead),
          _NotifList(uid: _uid, filterType: 'receipt', onMarkRead: _markRead),
        ],
      )),
    ]);
  }
}

// ── Notification list ─────────────────────────────────────────────────────────
class _NotifList extends StatelessWidget {
  final String  uid;
  final String? filterType;
  final Future<void> Function(String) onMarkRead;

  const _NotifList({
    required this.uid,
    required this.filterType,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipient_id', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .limit(50);

    if (filterType != null) {
      q = q.where('type', isEqualTo: filterType);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _navy, strokeWidth: 2));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(filterType: filterType);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final d    = docs[i].data() as Map<String, dynamic>;
            final id   = docs[i].id;
            final type = d['type'] as String? ?? 'system';
            final ts   = d['created_at'];
            DateTime? dt;
            if (ts is Timestamp) dt = ts.toDate();
            else if (ts is String) dt = DateTime.tryParse(ts);

            final isRead = d['is_read'] as bool? ?? true;

            return _NotifCard(
              id:         id,
              type:       type,
              title:      d['title']  as String? ?? '',
              body:       d['body']   as String? ?? '',
              isRead:     isRead,
              createdAt:  dt,
              amount:     d['amount'] as String?,
              txId:       d['transaction_id'] as String?,
              campaign:   d['campaign_title'] as String?,
              onTap: () {
                if (!isRead) onMarkRead(id);
                if (type == 'receipt') {
                  _showReceiptDetail(ctx, d, id);
                }
              },
            );
          },
        );
      },
    );
  }

  void _showReceiptDetail(BuildContext ctx,
      Map<String, dynamic> d, String id) {
    final amt      = d['amount']         as String?;
    final txId     = d['transaction_id'] as String?;
    final campaign = d['campaign_title'] as String?;
    final ts       = d['created_at'];
    DateTime? dt;
    if (ts is Timestamp) dt = ts.toDate();
    else if (ts is String) dt = DateTime.tryParse(ts);

    showDialog(context: ctx, builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                  color: _navy,
                  borderRadius: BorderRadius.only(
                      topLeft:  Radius.circular(20),
                      topRight: Radius.circular(20))),
              child: Column(children: [
                const Icon(Icons.receipt_long, color: _gold, size: 40),
                const SizedBox(height: 10),
                const Text('Donation Receipt',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                Text('KCA University Foundation',
                    style: TextStyle(
                        color: Colors.white.withAlpha(180), fontSize: 12)),
              ])),
          // Body
          Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                _receiptRow('Campaign', campaign ?? '—'),
                const Divider(height: 16),
                _receiptRow('Amount',
                    amt != null ? 'KES $amt' : '—',
                    bold: true, color: _green),
                const Divider(height: 16),
                _receiptRow('Date',
                    dt != null
                        ? DateFormat('dd MMM yyyy, HH:mm').format(dt)
                        : '—'),
                const Divider(height: 16),
                _receiptRow('Transaction ID', txId ?? '—', mono: true),
                const SizedBox(height: 16),
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: _green.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _green.withAlpha(40))),
                    child: const Row(children: [
                      Icon(Icons.check_circle_outline, color: _green, size: 16),
                      SizedBox(width: 8),
                      Text('Payment confirmed',
                          style: TextStyle(color: _green,
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ])),
              ])),
          // Close
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(width: double.infinity,
                  child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _navy, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      child: const Text('Close')))),
        ])));
  }

  Widget _receiptRow(String label, String value,
      {bool bold = false, Color? color, bool mono = false}) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label,
            style: TextStyle(color: Colors.grey[500], fontSize: 12))),
        Expanded(child: Text(value,
            style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
                color: color ?? Colors.black87,
                fontFamily: mono ? 'monospace' : null))),
      ]);
}

// ── Individual notification card ──────────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  final String   id, type, title, body;
  final bool     isRead;
  final DateTime? createdAt;
  final String?  amount, txId, campaign;
  final VoidCallback onTap;

  const _NotifCard({
    required this.id,    required this.type,  required this.title,
    required this.body,  required this.isRead,required this.onTap,
    this.createdAt, this.amount, this.txId, this.campaign,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconForType(type);
    final timeStr = createdAt != null
        ? _timeAgo(createdAt!)
        : '';

    return GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: isRead ? Colors.white : _navy.withAlpha(8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isRead ? Colors.grey.shade200 : _navy.withAlpha(40),
                    width: isRead ? 1 : 1.5),
                boxShadow: [BoxShadow(
                    color: Colors.black.withAlpha(6),
                    blurRadius: 4, offset: const Offset(0, 1))]),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Icon
              Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: color.withAlpha(20), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20)),
              const SizedBox(width: 12),
              // Content
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(title,
                      style: TextStyle(
                          fontWeight: isRead
                              ? FontWeight.w600 : FontWeight.bold,
                          fontSize: 13, color: _navy))),
                  if (!isRead)
                    Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                            color: _navy, shape: BoxShape.circle)),
                ]),
                const SizedBox(height: 4),
                Text(body,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600],
                        height: 1.4)),
                if (timeStr.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(timeStr,
                      style: TextStyle(fontSize: 10,
                          color: Colors.grey[400])),
                ],
                if (type == 'receipt')
                  Padding(padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [
                        const Icon(Icons.touch_app_outlined,
                            size: 12, color: _navy),
                        const SizedBox(width: 4),
                        Text('Tap to view receipt',
                            style: TextStyle(fontSize: 11,
                                color: _navy.withAlpha(180),
                                fontWeight: FontWeight.w600)),
                      ])),
              ])),
            ])));
  }

  (IconData, Color) _iconForType(String type) => switch (type) {
    'receipt'  => (Icons.receipt_long_outlined, _green),
    'donation' => (Icons.favorite_outlined,     _navy),
    'campaign' => (Icons.campaign_outlined,     _gold),
    'milestone'=> (Icons.flag_outlined,         const Color(0xFF7C3AED)),
    _          => (Icons.notifications_outlined, Colors.grey),
  };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 7)     return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(dt);
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String? filterType;
  const _EmptyState({this.filterType});

  @override
  Widget build(BuildContext context) => Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
            filterType == 'receipt'
                ? Icons.receipt_long_outlined
                : Icons.notifications_none_outlined,
            size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(
            filterType == 'receipt'
                ? 'No receipts yet'
                : 'No notifications yet',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(height: 8),
        Text(
            filterType == 'receipt'
                ? 'Your donation receipts will appear here\nafter you make a donation.'
                : 'Donation confirmations and campaign\nupdates will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.5)),
      ]));
}