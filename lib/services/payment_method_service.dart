// lib/services/payment_method_service.dart
//
// Manages configurable payment methods stored in Firestore.
// Collection: payment_methods/{id}
//   name, type, emoji, description, instructions, isActive, order, config, createdAt

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ── Payment type ──────────────────────────────────────────────────────────────
enum PaymentType {
  mobileMoney,
  bank,
  online,
  other;

  String get key {
    switch (this) {
      case PaymentType.mobileMoney: return 'mobile_money';
      case PaymentType.bank:        return 'bank';
      case PaymentType.online:      return 'online';
      case PaymentType.other:       return 'other';
    }
  }

  String get label {
    switch (this) {
      case PaymentType.mobileMoney: return 'Mobile Money';
      case PaymentType.bank:        return 'Bank Transfer';
      case PaymentType.online:      return 'Online / Card';
      case PaymentType.other:       return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentType.mobileMoney: return Icons.phone_android_outlined;
      case PaymentType.bank:        return Icons.account_balance_outlined;
      case PaymentType.online:      return Icons.credit_card_outlined;
      case PaymentType.other:       return Icons.payments_outlined;
    }
  }

  Color get color {
    switch (this) {
      case PaymentType.mobileMoney: return const Color(0xFF10B981);
      case PaymentType.bank:        return const Color(0xFF1B2263);
      case PaymentType.online:      return const Color(0xFF2563EB);
      case PaymentType.other:       return const Color(0xFF7C3AED);
    }
  }

  static PaymentType fromKey(String key) {
    for (final t in PaymentType.values) {
      if (t.key == key) return t;
    }
    return PaymentType.other;
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────
class PaymentMethodModel {
  final String              id;
  final String              name;
  final PaymentType         type;
  final String              emoji;
  final String              description;  // shown on donor payment screen
  final String              instructions; // shown to donor after selecting
  final bool                isActive;
  final int                 order;
  final Map<String, String> config;       // admin-only (account nos, api keys etc)

  const PaymentMethodModel({
    required this.id,
    required this.name,
    required this.type,
    required this.emoji,
    required this.description,
    required this.instructions,
    required this.isActive,
    required this.order,
    required this.config,
  });

  factory PaymentMethodModel.fromFirestore(String id, Map<String, dynamic> d) =>
      PaymentMethodModel(
        id:           id,
        name:         d['name']         as String? ?? '',
        type:         PaymentType.fromKey(d['type'] as String? ?? ''),
        emoji:        d['emoji']        as String? ?? '💳',
        description:  d['description']  as String? ?? '',
        instructions: d['instructions'] as String? ?? '',
        isActive:     d['is_active']    as bool?   ?? true,
        order:        (d['order']       as num?    ?? 999).toInt(),
        config:       Map<String, String>.from(
            (d['config'] as Map<String, dynamic>? ?? {})
                .map((k, v) => MapEntry(k, v.toString()))),
      );

  Map<String, dynamic> toJson() => {
    'name': name, 'type': type.key, 'emoji': emoji,
    'description': description, 'instructions': instructions,
    'is_active': isActive, 'order': order, 'config': config,
  };
}

// ── Service ───────────────────────────────────────────────────────────────────
class PaymentMethodService {
  static final _db  = FirebaseFirestore.instance;
  static const _col = 'payment_methods';

  static final _seed = [
    {
      'name': 'M-Pesa (STK Push)', 'type': 'mobile_money', 'emoji': '📱',
      'description': 'Pay instantly from your Safaricom M-Pesa wallet.',
      'instructions': 'Enter your Safaricom number. You will receive an M-Pesa STK push prompt to confirm the payment.',
      'is_active': true, 'order': 0, 'config': <String, String>{},
    },
    {
      'name': 'Equity Bank', 'type': 'bank', 'emoji': '🏦',
      'description': 'Bank transfer to our Equity Bank account.',
      'instructions': 'Account Name: KCA University Foundation\nAccount No: 0123456789\nBank: Equity Bank\nBranch: Nairobi CBD\nSwift Code: EQBLKENA\n\nSend proof of payment to foundation@kca.ac.ke',
      'is_active': true, 'order': 1,
      'config': <String, String>{'accountName': 'KCA University Foundation', 'accountNo': '0123456789', 'bank': 'Equity Bank', 'branch': 'Nairobi CBD'},
    },
    {
      'name': 'KCB Bank', 'type': 'bank', 'emoji': '🏦',
      'description': 'Bank transfer to our KCB account.',
      'instructions': 'Account Name: KCA University Foundation\nAccount No: 9876543210\nBank: KCB Bank\nBranch: Upperhill\n\nSend proof of payment to foundation@kca.ac.ke',
      'is_active': true, 'order': 2,
      'config': <String, String>{'accountName': 'KCA University Foundation', 'accountNo': '9876543210', 'bank': 'KCB Bank', 'branch': 'Upperhill'},
    },
    {
      'name': 'PayPal', 'type': 'online', 'emoji': '💙',
      'description': 'International donors — pay via PayPal.',
      'instructions': 'Send to: foundation@kca.ac.ke\nInclude your name and the campaign name in the payment note.\nFor gifts above KES 100,000 please contact us first.',
      'is_active': false, 'order': 3,
      'config': <String, String>{'paypalEmail': 'foundation@kca.ac.ke'},
    },
    {
      'name': 'Visa / Mastercard', 'type': 'online', 'emoji': '💳',
      'description': 'Pay by debit or credit card (coming soon).',
      'instructions': 'Card payments are being configured. Please use M-Pesa or bank transfer for now.',
      'is_active': false, 'order': 4, 'config': <String, String>{},
    },
  ];

  static Future<void> seedIfEmpty() async {
    try {
      final snap = await _db.collection(_col).limit(1).get();
      if (snap.docs.isNotEmpty) return;
      final batch = _db.batch();
      final now   = DateTime.now().toIso8601String();
      for (final m in _seed) {
        batch.set(_db.collection(_col).doc(), {...m, 'createdAt': now});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('PaymentMethodService.seedIfEmpty: $e');
    }
  }

  /// All methods sorted by order — for admin management
  static Stream<List<PaymentMethodModel>> stream() =>
      _db.collection(_col).snapshots().map((snap) => snap.docs
          .map((d) => PaymentMethodModel.fromFirestore(d.id, d.data()))
          .toList()..sort((a, b) => a.order.compareTo(b.order)));

  /// Active methods only — for donor payment selection screen
  static Stream<List<PaymentMethodModel>> activeStream() =>
      stream().map((l) => l.where((m) => m.isActive).toList());

  static Future<void> addMethod({
    required String      name,
    required PaymentType type,
    required String      emoji,
    required String      description,
    required String      instructions,
    Map<String, String>? config,
  }) async {
    final snap = await _db.collection(_col).get();
    await _db.collection(_col).add({
      'name': name.trim(), 'type': type.key, 'emoji': emoji,
      'description': description.trim(), 'instructions': instructions.trim(),
      'is_active': true, 'order': snap.docs.length,
      'config': config ?? {}, 'createdAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> updateMethod(String id, {
    String?              name,
    PaymentType?         type,
    String?              emoji,
    String?              description,
    String?              instructions,
    Map<String, String>? config,
  }) async {
    final u = <String, dynamic>{};
    if (name         != null) u['name']         = name.trim();
    if (type         != null) u['type']         = type.key;
    if (emoji        != null) u['emoji']        = emoji;
    if (description  != null) u['description']  = description.trim();
    if (instructions != null) u['instructions'] = instructions.trim();
    if (config       != null) u['config']       = config;
    if (u.isNotEmpty) await _db.collection(_col).doc(id).update(u);
  }

  static Future<void> setActive(String id, bool active) =>
      _db.collection(_col).doc(id).update({'is_active': active});

  static Future<void> deleteMethod(String id) =>
      _db.collection(_col).doc(id).delete();
}