// lib/services/donor_type_service.dart
//
// Manages donor types stored in Firestore.
// Collection: donor_types/{id}
//   displayName:  String  — e.g. "Individual", "Corporate", "Alumni"
//   icon:         String  — emoji, e.g. "👤"
//   description:  String  — shown during registration
//   isActive:     bool    — only active types shown at registration
//   order:        int
//   createdAt:    String  ISO-8601
//
// The 3 built-in types are seeded with FIXED doc IDs so old donor records
// (which stored "individual" / "corporate" / "partner") keep matching.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────
class DonorTypeModel {
  final String id;
  final String displayName;
  final String icon;
  final String description;
  final bool   isActive;
  final int    order;

  const DonorTypeModel({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.description,
    required this.isActive,
    required this.order,
  });

  factory DonorTypeModel.fromFirestore(String id, Map<String, dynamic> d) =>
      DonorTypeModel(
        id:          id,
        displayName: d['displayName'] as String? ?? id,
        icon:        d['icon']        as String? ?? '👤',
        description: d['description'] as String? ?? '',
        isActive:    d['isActive']    as bool?   ?? true,
        order:       (d['order']      as num?    ?? 999).toInt(),
      );

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'icon':        icon,
    'description': description,
    'isActive':    isActive,
    'order':       order,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────
class DonorTypeService {
  static final _db  = FirebaseFirestore.instance;
  static const _col = 'donor_types';

  // ── Seed defaults (fixed IDs match old Firestore data) ───────────────────
  static final _seed = [
    {
      'id':          'individual',
      'displayName': 'Individual',
      'icon':        '👤',
      'description': 'Personal donations for scholarships, infrastructure & more',
      'isActive':    true,
      'order':       0,
    },
    {
      'id':          'corporate',
      'displayName': 'Corporate',
      'icon':        '🏢',
      'description': 'CSR giving with receipts and named endowment branding',
      'isActive':    true,
      'order':       1,
    },
    {
      'id':          'partner',
      'displayName': 'Partner',
      'icon':        '🤝',
      'description': 'Strategic partnership with pledge workflows & reporting',
      'isActive':    true,
      'order':       2,
    },
  ];

  // ── Seed if empty ─────────────────────────────────────────────────────────
  static Future<void> seedIfEmpty() async {
    try {
      final snap = await _db.collection(_col).limit(1).get();
      if (snap.docs.isNotEmpty) return;
      final batch = _db.batch();
      final now   = DateTime.now().toIso8601String();
      for (final t in _seed) {
        final id = t['id'] as String;
        batch.set(_db.collection(_col).doc(id), {
          ...t..remove('id'),
          'createdAt': now,
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('DonorTypeService.seedIfEmpty: $e');
    }
  }

  // ── Live stream — ALL types sorted by order ───────────────────────────────
  static Stream<List<DonorTypeModel>> stream() =>
      _db.collection(_col).snapshots().map((snap) => snap.docs
          .map((d) => DonorTypeModel.fromFirestore(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order)));

  // ── Active types only (for registration dropdown) ─────────────────────────
  static Stream<List<DonorTypeModel>> activeStream() =>
      stream().map((list) => list.where((t) => t.isActive).toList());

  // ── One-time fetch ────────────────────────────────────────────────────────
  static Future<List<DonorTypeModel>> fetch() async {
    final snap = await _db.collection(_col).get();
    return snap.docs
        .map((d) => DonorTypeModel.fromFirestore(d.id, d.data()))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  // ── Get single type by ID ─────────────────────────────────────────────────
  static Future<DonorTypeModel?> getById(String id) async {
    try {
      final doc = await _db.collection(_col).doc(id).get();
      if (!doc.exists) return null;
      return DonorTypeModel.fromFirestore(doc.id, doc.data()!);
    } catch (_) {
      return null;
    }
  }

  // ── Resolve display name from stored ID (with fallback) ──────────────────
  // Capitalizes the id as fallback so "individual" → "Individual"
  static String resolveDisplayName(String? id, List<DonorTypeModel> types) {
    if (id == null || id.isEmpty) return '';
    final match = types.where((t) => t.id == id).firstOrNull;
    if (match != null) return match.displayName;
    // Fallback: capitalize first letter of the stored id
    return id[0].toUpperCase() + id.substring(1);
  }

  static String resolveIcon(String? id, List<DonorTypeModel> types) {
    if (id == null) return '👤';
    return types.where((t) => t.id == id).firstOrNull?.icon ?? '👤';
  }

  // ── Add new type ──────────────────────────────────────────────────────────
  static Future<void> addType({
    required String displayName,
    required String icon,
    required String description,
  }) async {
    final snap = await _db.collection(_col).get();
    await _db.collection(_col).add({
      'displayName': displayName.trim(),
      'icon':        icon,
      'description': description.trim(),
      'isActive':    true,
      'order':       snap.docs.length,
      'createdAt':   DateTime.now().toIso8601String(),
    });
  }

  // ── Toggle active ─────────────────────────────────────────────────────────
  static Future<void> setActive(String id, bool isActive) =>
      _db.collection(_col).doc(id).update({'isActive': isActive});

  // ── Update display name / icon / description ──────────────────────────────
  static Future<void> updateType(String id, {
    String? displayName,
    String? icon,
    String? description,
  }) async {
    final u = <String, dynamic>{};
    if (displayName != null) u['displayName'] = displayName.trim();
    if (icon        != null) u['icon']        = icon;
    if (description != null) u['description'] = description.trim();
    if (u.isNotEmpty) await _db.collection(_col).doc(id).update(u);
  }

  // ── Delete type ───────────────────────────────────────────────────────────
  static Future<void> deleteType(String id) =>
      _db.collection(_col).doc(id).delete();
}