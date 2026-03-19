// lib/providers/campaign_provider.dart
//
// Fix: removed .orderBy() from all compound .where() queries.
// Firestore requires a composite index for where+orderBy combinations.
// We sort client-side instead — this works with zero index setup.

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/campaign.dart';

class CampaignProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;

  List<Campaign> _campaigns = [];
  bool           _isLoading = false;
  String?        _error;

  List<Campaign> get campaigns     => _campaigns;
  bool           get isLoading     => _isLoading;
  String?        get error         => _error;

  // Active campaigns sorted by newest first (for dashboard)
  List<Campaign> get activeCampaigns =>
      [..._campaigns.where((c) => c.isActive)]
        ..sort((a, b) => (b.id).compareTo(a.id));

  // ── One-time fetch (HomeScreen initState) ──────────────────────────────────
  Future<void> fetchCampaigns() async {
    _isLoading = true;
    _error     = null;
    notifyListeners();
    try {
      // Simple query — no orderBy so no composite index needed
      final snap = await _db
          .collection('campaigns')
          .where('is_active', isEqualTo: true)
          .get();

      _campaigns = snap.docs
          .map((d) => Campaign.fromFirestore(d.id, d.data()))
          .toList()
      // Sort client-side: newest first (by created_at string or doc id)
        ..sort((a, b) {
          final ta = a.startDate ?? '';
          final tb = b.startDate ?? '';
          return tb.compareTo(ta);
        });
    } catch (e) {
      _error = e.toString();
      debugPrint('CampaignProvider.fetchCampaigns error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Real-time stream for Campaigns tab (no orderBy = no index needed) ──────
  Stream<List<Campaign>> allCampaignsStream() {
    return _db
        .collection('campaigns')
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => Campaign.fromFirestore(d.id, d.data()))
          .toList()
        ..sort((a, b) {
          // Sort by raised descending (most funded first)
          return b.raised.compareTo(a.raised);
        });
      return list;
    });
  }

  // ── Stream with optional category filter (no orderBy) ─────────────────────
  Stream<List<Campaign>> campaignsStream({String? category}) {
    Query<Map<String, dynamic>> q = _db
        .collection('campaigns')
        .where('is_active', isEqualTo: true);

    if (category != null && category != 'all') {
      q = q.where('category', isEqualTo: category);
    }

    return q.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => Campaign.fromFirestore(d.id, d.data()))
          .toList()
        ..sort((a, b) => b.raised.compareTo(a.raised));
      return list;
    });
  }

  void refresh() => fetchCampaigns();
}