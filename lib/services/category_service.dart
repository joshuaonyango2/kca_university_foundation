// lib/services/category_service.dart
//
// Manages campaign categories + subcategories stored in Firestore.
// Collection: campaign_categories/{id}
//   name:          String
//   iconKey:       String   — key into _icons map below
//   colorHex:      String   — 6-char hex, e.g. "2563EB"
//   subcategories: List<String>
//   order:         int
//   createdAt:     String ISO-8601

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────
class CampaignCategory {
  final String       id;
  final String       name;
  final String       iconKey;
  final String       colorHex;
  final List<String> subcategories;
  final int          order;

  const CampaignCategory({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorHex,
    required this.subcategories,
    required this.order,
  });

  bool get hasSubcategories => subcategories.isNotEmpty;

  Color get color {
    try {
      return Color(int.parse('FF$colorHex', radix: 16));
    } catch (_) {
      return const Color(0xFF1B2263);
    }
  }

  IconData get icon => CategoryService.iconFor(iconKey);

  factory CampaignCategory.fromFirestore(String id, Map<String, dynamic> d) =>
      CampaignCategory(
        id:            id,
        name:          d['name']     as String? ?? '',
        iconKey:       d['iconKey']  as String? ?? 'favorite',
        colorHex:      d['colorHex'] as String? ?? '1B2263',
        subcategories: List<String>.from(d['subcategories'] as List? ?? []),
        order:         (d['order']   as num?    ?? 999).toInt(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────
class CategoryService {
  static final _db  = FirebaseFirestore.instance;
  static const _col = 'campaign_categories';

  // ── Icon map ──────────────────────────────────────────────────────────────
  static const Map<String, IconData> _icons = {
    'school':            Icons.school_outlined,
    'construction':      Icons.construction_outlined,
    'science':           Icons.science_outlined,
    'account_balance':   Icons.account_balance_outlined,
    'groups':            Icons.groups_outlined,
    'health':            Icons.health_and_safety_outlined,
    'computer':          Icons.computer_outlined,
    'sports':            Icons.sports_outlined,
    'volunteer':         Icons.volunteer_activism_outlined,
    'favorite':          Icons.favorite_outline,
    'business':          Icons.business_outlined,
    'lightbulb':         Icons.lightbulb_outline,
    'star':              Icons.star_outline,
    'emoji_events':      Icons.emoji_events_outlined,
    'workspace_premium': Icons.workspace_premium_outlined,
    'diversity':         Icons.diversity_3_outlined,
  };

  static IconData iconFor(String key) =>
      _icons[key] ?? Icons.category_outlined;

  static List<String>   get iconKeys   => _icons.keys.toList();
  static List<IconData> get iconValues => _icons.values.toList();

  // ── Default KCA categories (seeded on first run) ──────────────────────────
  static final _seed = [
    {
      'name': 'Infrastructure Development', 'iconKey': 'construction',
      'colorHex': 'F59E0B', 'subcategories': <String>[], 'order': 0,
    },
    {
      'name': 'Endowment Funding', 'iconKey': 'account_balance',
      'colorHex': '7C3AED', 'subcategories': <String>[], 'order': 1,
    },
    {
      'name': 'Student Scholarships', 'iconKey': 'school',
      'colorHex': '2563EB',
      'subcategories': [
        'Teke la Mwisho',
        'Comrade for Comrade',
        'Tuendelee Scholarship',
        'KCA Foundation',
        'Talents and Sports',
        'Others',
      ],
      'order': 2,
    },
    {
      'name': 'Research and Innovation', 'iconKey': 'science',
      'colorHex': '10B981', 'subcategories': <String>[], 'order': 3,
    },
  ];

  // ── Seed if empty ─────────────────────────────────────────────────────────
  static Future<void> seedIfEmpty() async {
    try {
      final snap = await _db.collection(_col).limit(1).get();
      if (snap.docs.isNotEmpty) return;
      final batch = _db.batch();
      final now   = DateTime.now().toIso8601String();
      for (final cat in _seed) {
        batch.set(_db.collection(_col).doc(), {...cat, 'createdAt': now});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('CategoryService.seedIfEmpty: $e');
    }
  }

  // ── Live stream sorted by order ───────────────────────────────────────────
  static Stream<List<CampaignCategory>> stream() =>
      _db.collection(_col).snapshots().map((snap) => snap.docs
          .map((d) => CampaignCategory.fromFirestore(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order)));

  // ── One-time fetch ────────────────────────────────────────────────────────
  static Future<List<CampaignCategory>> fetch() async {
    final snap = await _db.collection(_col).get();
    return snap.docs
        .map((d) => CampaignCategory.fromFirestore(d.id, d.data()))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  // ── Add category ──────────────────────────────────────────────────────────
  static Future<void> addCategory({
    required String name,
    required String iconKey,
    required String colorHex,
  }) async {
    final snap = await _db.collection(_col).get();
    await _db.collection(_col).add({
      'name': name.trim(), 'iconKey': iconKey, 'colorHex': colorHex,
      'subcategories': <String>[], 'order': snap.docs.length,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  // ── Delete category ───────────────────────────────────────────────────────
  static Future<void> deleteCategory(String id) =>
      _db.collection(_col).doc(id).delete();

  // ── Add subcategory ───────────────────────────────────────────────────────
  static Future<void> addSubcategory(String catId, String name) =>
      _db.collection(_col).doc(catId).update({
        'subcategories': FieldValue.arrayUnion([name.trim()]),
      });

  // ── Remove subcategory ────────────────────────────────────────────────────
  static Future<void> removeSubcategory(String catId, String name) =>
      _db.collection(_col).doc(catId).update({
        'subcategories': FieldValue.arrayRemove([name]),
      });

  // ── Rename category ───────────────────────────────────────────────────────
  static Future<void> updateCategory(String id,
      {String? name, String? iconKey, String? colorHex}) async {
    final u = <String, dynamic>{};
    if (name     != null) u['name']     = name.trim();
    if (iconKey  != null) u['iconKey']  = iconKey;
    if (colorHex != null) u['colorHex'] = colorHex;
    if (u.isNotEmpty) await _db.collection(_col).doc(id).update(u);
  }
}