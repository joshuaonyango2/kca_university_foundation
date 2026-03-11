// lib/providers/campaign_provider.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/campaign.dart';

class CampaignProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;

  List<Campaign> _campaigns    = [];
  bool           _isLoading    = false;
  String?        _error;

  List<Campaign> get campaigns  => _campaigns;
  bool           get isLoading  => _isLoading;
  String?        get error      => _error;

  // Active campaigns only (for donor-facing feed)
  List<Campaign> get activeCampaigns =>
      _campaigns.where((c) => c.isActive).toList();

  // Fetch once (called on HomeScreen init)
  Future<void> fetchCampaigns() async {
    _isLoading = true;
    _error     = null;
    notifyListeners();
    try {
      final snap = await _db
          .collection('campaigns')
          .where('is_active', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .get();
      _campaigns = snap.docs
          .map((d) => Campaign.fromFirestore(d.id, d.data()))
          .toList();
    } catch (e) {
      _error = 'Failed to load campaigns: $e';
      debugPrint('CampaignProvider: $_error');
    }
    _isLoading = false;
    notifyListeners();
  }

  // Real-time stream (used by CampaignsTab for live updates)
  Stream<List<Campaign>> campaignsStream({String? category}) {
    Query<Map<String, dynamic>> q = _db
        .collection('campaigns')
        .where('is_active', isEqualTo: true)
        .orderBy('created_at', descending: true);
    if (category != null && category != 'all') {
      q = q.where('category', isEqualTo: category);
    }
    return q.snapshots().map((snap) =>
        snap.docs.map((d) => Campaign.fromFirestore(d.id, d.data())).toList());
  }

  // All campaigns stream (no filter — for full browse)
  Stream<List<Campaign>> allCampaignsStream() {
    return _db
        .collection('campaigns')
        .where('is_active', isEqualTo: true)
        .orderBy('raised', descending: true)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => Campaign.fromFirestore(d.id, d.data())).toList());
  }

  void refresh() => fetchCampaigns();
}