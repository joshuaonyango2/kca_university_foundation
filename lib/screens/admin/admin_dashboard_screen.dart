// lib/screens/admin/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/routes.dart';
import 'widgets/admin_layout.dart';

class _KCA {
  static const navy  = Color(0xFF1B2263);
  static const gold  = Color(0xFFF5A800);
  static const white = Colors.white;
  static const bg    = Color(0xFFF0F2F8);
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _firestore = FirebaseFirestore.instance;

  // Stats
  int    _totalDonors       = 0;
  int    _activeCampaigns   = 0;
  double _totalDonations    = 0;
  int    _totalTransactions = 0;
  bool   _loadingStats      = true;

  // Recent activity
  List<Map<String, dynamic>> _recentDonations  = [];
  List<Map<String, dynamic>> _activeCampaignsList = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _loadingStats = true);
    try {
      await Future.wait([
        _loadStats(),
        _loadRecentDonations(),
        _loadActiveCampaigns(),
      ]);
    } catch (e) {
      debugPrint('Dashboard load error: $e');
    }
    if (mounted) setState(() => _loadingStats = false);
  }

  Future<void> _loadStats() async {
    final donors     = await _firestore.collection('donors').count().get();
    final campaigns  = await _firestore.collection('campaigns')
        .where('is_active', isEqualTo: true).count().get();
    final donations  = await _firestore.collection('donations').get();

    double total = 0;
    for (final doc in donations.docs) {
      total += (doc.data()['amount'] as num? ?? 0).toDouble();
    }

    if (mounted) {
      setState(() {
        _totalDonors       = donors.count ?? 0;
        _activeCampaigns   = campaigns.count ?? 0;
        _totalDonations    = total;
        _totalTransactions = donations.docs.length;
      });
    }
  }

  Future<void> _loadRecentDonations() async {
    final snap = await _firestore
        .collection('donations')
        .orderBy('created_at', descending: true)
        .limit(5)
        .get();
    if (mounted) {
      setState(() {
        _recentDonations = snap.docs.map((d) => d.data()).toList();
      });
    }
  }

  Future<void> _loadActiveCampaigns() async {
    final snap = await _firestore
        .collection('campaigns')
        .where('is_active', isEqualTo: true)
        .limit(4)
        .get();
    if (mounted) {
      setState(() {
        _activeCampaignsList = snap.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Dashboard',
      activeRoute: AppRoutes.adminDashboard,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: _KCA.navy),
          onPressed: _loadDashboardData,
          tooltip: 'Refresh',
        ),
      ],
      child: _loadingStats
          ? const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(_KCA.navy)))
          : RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Stats cards ──────────────────────────────────────
              _buildStatsGrid(),
              const SizedBox(height: 28),

              // ── Two column layout ────────────────────────────────
              LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth > 700) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildRecentDonations()),
                      const SizedBox(width: 20),
                      Expanded(child: _buildActiveCampaigns()),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildRecentDonations(),
                    const SizedBox(height: 20),
                    _buildActiveCampaigns(),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stats grid ─────────────────────────────────────────────────────────────
  Widget _buildStatsGrid() {
    final stats = [
      _StatCard(
        label: 'Total Donations',
        value: 'KES ${_formatAmount(_totalDonations)}',
        icon: Icons.payments_outlined,
        color: const Color(0xFF10B981),
        sub: '$_totalTransactions transactions',
      ),
      _StatCard(
        label: 'Active Campaigns',
        value: '$_activeCampaigns',
        icon: Icons.campaign_outlined,
        color: const Color(0xFF2563EB),
        sub: 'Currently running',
      ),
      _StatCard(
        label: 'Total Donors',
        value: '$_totalDonors',
        icon: Icons.people_outline,
        color: _KCA.navy,
        sub: 'Registered accounts',
      ),
      _StatCard(
        label: 'This Month',
        value: 'KES 0',
        icon: Icons.trending_up_outlined,
        color: _KCA.gold,
        sub: 'Monthly total',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisExtent: 130,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) => _buildStatCard(stats[i]),
    );
  }

  Widget _buildStatCard(_StatCard s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _KCA.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: s.color.withAlpha(25),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(s.icon, color: s.color, size: 22),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: s.color)),
              const SizedBox(height: 2),
              Text(s.label,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Recent donations ───────────────────────────────────────────────────────
  Widget _buildRecentDonations() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _KCA.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Donations',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _KCA.navy)),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(
                    context, AppRoutes.adminTransactions),
                child: const Text('View All',
                    style: TextStyle(
                        color: _KCA.navy, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _recentDonations.isEmpty
              ? _emptyState(
              icon: Icons.payments_outlined,
              message: 'No donations yet')
              : Column(
              children: _recentDonations
                  .map((d) => _donationRow(d))
                  .toList()),
        ],
      ),
    );
  }

  Widget _donationRow(Map<String, dynamic> d) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _KCA.navy.withAlpha(20),
            child: Text(
              (d['donor_name'] as String? ?? 'U')
                  .substring(0, 1)
                  .toUpperCase(),
              style: const TextStyle(
                  color: _KCA.navy, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d['donor_name'] as String? ?? 'Unknown',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(d['campaign_title'] as String? ?? '—',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(
            'KES ${_formatAmount((d['amount'] as num? ?? 0).toDouble())}',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF10B981),
                fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Active campaigns ───────────────────────────────────────────────────────
  Widget _buildActiveCampaigns() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _KCA.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Active Campaigns',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _KCA.navy)),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(
                    context, AppRoutes.adminCampaigns),
                child: const Text('Manage',
                    style: TextStyle(
                        color: _KCA.navy, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _activeCampaignsList.isEmpty
              ? _emptyState(
              icon: Icons.campaign_outlined,
              message: 'No active campaigns')
              : Column(
              children: _activeCampaignsList
                  .map((c) => _campaignRow(c))
                  .toList()),
        ],
      ),
    );
  }

  Widget _campaignRow(Map<String, dynamic> c) {
    final raised = (c['raised'] as num? ?? 0).toDouble();
    final goal   = (c['goal'] as num? ?? 1).toDouble();
    final pct    = (raised / goal).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(c['title'] as String? ?? 'Campaign',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text('${(pct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor:
              const AlwaysStoppedAnimation(Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
              'KES ${_formatAmount(raised)} of KES ${_formatAmount(goal)}',
              style:
              TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _emptyState({required IconData icon, required String message}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 36, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(message,
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}

class _StatCard {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String sub;
  _StatCard(
      {required this.label,
        required this.value,
        required this.icon,
        required this.color,
        required this.sub});
}