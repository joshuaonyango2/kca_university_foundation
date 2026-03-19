// lib/services/donation_amount_service.dart
//
// Firestore-backed preset donation amounts.
// Admins with managePaymentMethods permission can add/edit/delete/reorder amounts.
// Donors see active amounts as quick-pick chips in the donation flow.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DonationAmountModel {
  final String  id;
  final double  amount;
  final String? label;     // optional display label e.g. "School Fees", "Lunch"
  final bool    isActive;
  final int     order;
  final DateTime createdAt;

  const DonationAmountModel({
    required this.id,
    required this.amount,
    this.label,
    required this.isActive,
    required this.order,
    required this.createdAt,
  });

  factory DonationAmountModel.fromFirestore(String id, Map<String, dynamic> d) =>
      DonationAmountModel(
        id:        id,
        amount:    (d['amount'] as num? ?? 0).toDouble(),
        label:     d['label'] as String?,
        isActive:  d['is_active'] as bool? ?? true,
        order:     d['order']    as int?  ?? 0,
        createdAt: d['created_at'] is Timestamp
            ? (d['created_at'] as Timestamp).toDate()
            : DateTime.tryParse(d['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
    'amount':     amount,
    'label':      label,
    'is_active':  isActive,
    'order':      order,
    'created_at': FieldValue.serverTimestamp(),
  };
}

class DonationAmountService {
  static final _db = FirebaseFirestore.instance;
  static const _col = 'donation_amounts';

  // ── Seed defaults on first run ────────────────────────────────────────────
  static Future<void> seedIfEmpty() async {
    try {
      final snap = await _db.collection(_col).limit(1).get();
      if (snap.docs.isNotEmpty) return;

      final defaults = [
        {'amount': 100,   'label': null,          'order': 1},
        {'amount': 250,   'label': null,          'order': 2},
        {'amount': 500,   'label': null,          'order': 3},
        {'amount': 1000,  'label': 'Basic',       'order': 4},
        {'amount': 2500,  'label': null,          'order': 5},
        {'amount': 5000,  'label': 'Standard',    'order': 6},
        {'amount': 10000, 'label': 'Premium',     'order': 7},
        {'amount': 50000, 'label': 'Gold Patron', 'order': 8},
      ];

      final batch = _db.batch();
      for (final d in defaults) {
        final ref = _db.collection(_col).doc();
        batch.set(ref, {
          ...d,
          'is_active':  true,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      debugPrint('✅ DonationAmountService: seeded ${defaults.length} defaults');
    } catch (e) {
      debugPrint('⚠️ DonationAmountService.seedIfEmpty: $e');
    }
  }

  // ── Streams ───────────────────────────────────────────────────────────────
  static Stream<List<DonationAmountModel>> stream() =>
      _db.collection(_col)
          .snapshots()
          .map((s) {
        final list = s.docs
            .map((d) => DonationAmountModel.fromFirestore(d.id, d.data()))
            .toList();
        list.sort((a, b) => a.order.compareTo(b.order));
        return list;
      });

  static Stream<List<DonationAmountModel>> activeStream() =>
      stream().map((list) => list.where((a) => a.isActive).toList());

  // ── CRUD ──────────────────────────────────────────────────────────────────
  static Future<void> add({
    required double amount,
    String?  label,
    required int    order,
  }) async {
    await _db.collection(_col).add({
      'amount':     amount,
      'label':      label,
      'is_active':  true,
      'order':      order,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> update(String id, {
    double? amount,
    String? label,
    bool?   isActive,
    int?    order,
  }) async {
    final data = <String, dynamic>{};
    if (amount   != null) data['amount']    = amount;
    if (label    != null) data['label']     = label;
    if (isActive != null) data['is_active'] = isActive;
    if (order    != null) data['order']     = order;
    await _db.collection(_col).doc(id).update(data);
  }

  static Future<void> setActive(String id, bool active) =>
      _db.collection(_col).doc(id).update({'is_active': active});

  static Future<void> delete(String id) =>
      _db.collection(_col).doc(id).delete();
}