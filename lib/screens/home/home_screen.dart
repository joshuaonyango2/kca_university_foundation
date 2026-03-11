// lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../models/campaign.dart';
import '../../providers/auth_provider.dart';
import '../../providers/campaign_provider.dart';

// ── Brand tokens ──────────────────────────────────────────────────────────────
class _KCA {
  static const navy  = Color(0xFF1B2263);
  static const gold  = Color(0xFFF5A800);
  static const bg    = Color(0xFFF0F2F8);
  static const green = Color(0xFF10B981);
}

// ══════════════════════════════════════════════════════════════════════════════
// ROOT SHELL
// ══════════════════════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════════════════════
// HOME SCREEN — admin-aligned shell (sidebar on wide, drawer on mobile)
// ══════════════════════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _titles = ['Dashboard', 'Campaigns', 'Donations', 'Profile'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CampaignProvider>().fetchCampaigns();
    });
  }

  void _goToTab(int i) => setState(() => _selectedIndex = i);

  Widget _currentTab() {
    switch (_selectedIndex) {
      case 0: return _DashboardTab(onTabSwitch: _goToTab);
      case 1: return const _CampaignsTab();
      case 2: return const _DonationsTab();
      case 3: return const _ProfileTab();
      default: return _DashboardTab(onTabSwitch: _goToTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: _KCA.bg,
      appBar: isWide ? null : _buildMobileAppBar(context),
      drawer: isWide ? null : _buildDrawer(context),
      body: isWide
          ? Row(children: [
        _buildSidebar(context),
        Expanded(child: _buildBody(context)),
      ])
          : _buildBody(context),
    );
  }

  // ── Mobile app bar ─────────────────────────────────────────────────────────
  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AppBar(
      backgroundColor: _KCA.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(_titles[_selectedIndex],
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: _KCA.gold)),
      actions: [
        const SizedBox(width: 4),
        _NotificationBell(
            uid: FirebaseAuth.instance.currentUser?.uid ?? ''),
        const SizedBox(width: 6),
        GestureDetector(
            onTap: () => _goToTab(3),
            child: Container(
                width: 36, height: 36,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _KCA.gold,
                    border: Border.all(color: Colors.white.withAlpha(80), width: 2)),
                child: Center(child: Text(
                    auth.user?.initials ?? 'U',
                    style: const TextStyle(color: _KCA.navy,
                        fontSize: 13, fontWeight: FontWeight.bold))))),
      ],
    );
  }

  // ── Drawer (mobile) ────────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context) => Drawer(
      child: Container(color: _KCA.navy, child: _buildSidebarContent(context)));

  // ── Sidebar (wide) ─────────────────────────────────────────────────────────
  Widget _buildSidebar(BuildContext context) => Container(
      width: 240, height: double.infinity,
      color: _KCA.navy,
      child: _buildSidebarContent(context));

  // ── Shared sidebar content ─────────────────────────────────────────────────
  Widget _buildSidebarContent(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Column(children: [
      // Logo + user info
      Container(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
          child: Column(children: [
            // Logo circle
            Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _KCA.gold, width: 2)),
                padding: const EdgeInsets.all(6),
                child: ClipOval(child: Image.asset(
                    'assets/image.asset.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.school, color: _KCA.navy, size: 32)))),
            const SizedBox(height: 12),
            Text(user?.name ?? 'Donor',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            // Donor badge
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: _KCA.gold,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(
                    user?.donorType?.displayName != null
                        ? '${user!.donorType!.displayName} Donor'
                        : 'Donor Portal',
                    style: const TextStyle(
                        color: _KCA.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w700))),
          ])),

      Divider(color: Colors.white.withAlpha(30), height: 1),

      // Nav items
      Expanded(child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            _navItem(context,
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard_rounded,
                label: 'Dashboard',
                index: 0),
            _navItem(context,
                icon: Icons.campaign_outlined,
                activeIcon: Icons.campaign_rounded,
                label: 'Campaigns',
                index: 1),
            _navItem(context,
                icon: Icons.favorite_outline,
                activeIcon: Icons.favorite_rounded,
                label: 'Donations',
                index: 2),
            _navItem(context,
                icon: Icons.person_outline,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                index: 3),
          ])),

      Divider(color: Colors.white.withAlpha(30), height: 1),

      // Logout
      Padding(
          padding: const EdgeInsets.all(12),
          child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
              title: const Text('Log Out',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onTap: () async {
                final auth = context.read<AuthProvider>();
                await auth.logout();
                if (!context.mounted) return;
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              })),
    ]);
  }

  // ── Nav item (same style as admin) ────────────────────────────────────────
  Widget _navItem(BuildContext context,
      {required IconData icon,
        required IconData activeIcon,
        required String label,
        required int index}) {
    final isActive = _selectedIndex == index;
    return Container(
        margin: const EdgeInsets.only(bottom: 4),
        child: ListTile(
            leading: Icon(
                isActive ? activeIcon : icon,
                color: isActive ? _KCA.gold : Colors.white.withAlpha(180),
                size: 20),
            title: Text(label,
                style: TextStyle(
                    color: isActive ? _KCA.gold : Colors.white.withAlpha(180),
                    fontSize: 14,
                    fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.normal)),
            selected: isActive,
            selectedTileColor: Colors.white.withAlpha(20),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            onTap: () {
              _goToTab(index);
              // Close drawer on mobile after tap
              if (MediaQuery.of(context).size.width < 900) {
                Navigator.of(context).pop();
              }
            }));
  }

  // ── Body: white title bar + content (matches admin _buildBody) ─────────────
  Widget _buildBody(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final auth   = context.watch<AuthProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // White top bar (wide only — mobile uses AppBar)
        if (isWide)
          Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 20),
              color: Colors.white,
              child: Row(children: [
                Text(_titles[_selectedIndex],
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _KCA.navy)),
                const Spacer(),
                _NotificationBell(
                    uid: FirebaseAuth.instance.currentUser?.uid ?? ''),
                const SizedBox(width: 8),
                GestureDetector(
                    onTap: () => _goToTab(3),
                    child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: _KCA.navy,
                            border: Border.all(color: _KCA.gold, width: 2)),
                        child: Center(child: Text(
                            auth.user?.initials ?? 'U',
                            style: const TextStyle(
                                color: _KCA.gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 13))))),
              ])),

        // Tab content
        Expanded(child: _currentTab()),
      ],
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final ValueChanged<int> onTabSwitch;
  const _DashboardTab({required this.onTabSwitch});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Stat grid (2 × 2) ───────────────────────────────────────────
          _DonorStatGrid(uid: uid),
          const SizedBox(height: 20),

          // ── Featured Campaigns panel ─────────────────────────────────────
          _DashPanel(
            title: 'Featured Campaigns',
            onViewAll: () => onTabSwitch(1),
            child: _FeaturedCampaignList(),
          ),
          const SizedBox(height: 20),

          // ── Recent Donations panel ───────────────────────────────────────
          _DashPanel(
            title: 'Your Recent Gifts',
            onViewAll: () => onTabSwitch(2),
            child: _RecentDonationsList(uid: uid),
          ),
          const SizedBox(height: 20),

          // ── Quick Actions panel ──────────────────────────────────────────
          _DashPanel(
            title: 'Quick Actions',
            child: _QuickActionsGrid(onTabSwitch: onTabSwitch),
          ),
          const SizedBox(height: 32),
        ]));
  }
}

// ── Notification bell (white icons — on navy bg) ───────────────────────────────
class _NotificationBell extends StatelessWidget {
  final String uid;
  const _NotificationBell({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.notifications));
    }
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('user_id', isEqualTo: uid)
            .where('is_read', isEqualTo: false)
            .snapshots(),
        builder: (ctx, snap) {
          final count = snap.data?.docs.length ?? 0;
          return Stack(children: [
            IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.notifications)),
            if (count > 0)
              Positioned(right: 6, top: 6,
                  child: Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                          color: _KCA.gold, shape: BoxShape.circle,
                          border: Border.all(color: _KCA.navy, width: 1.5)),
                      child: Center(child: Text('$count',
                          style: const TextStyle(color: _KCA.navy, fontSize: 9,
                              fontWeight: FontWeight.bold))))),
          ]);
        });
  }
}

// ── Donor stat grid — matches admin _LiveStat style ───────────────────────────
class _DonorStatGrid extends StatelessWidget {
  final String uid;
  const _DonorStatGrid({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('donor_id', isEqualTo: uid)
            .where('status', isEqualTo: 'completed')
            .snapshots(),
        builder: (ctx, snap) {
          final loading = snap.connectionState == ConnectionState.waiting;
          final docs    = snap.data?.docs ?? [];
          double total  = 0;
          final Set<String> campaigns = {};
          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            total += (data['amount'] as num? ?? 0).toDouble();
            final c = data['campaign_id'] as String?;
            if (c != null) campaigns.add(c);
          }

          final stats = [
            _StatData(
                label: 'Total Donated',
                value: loading ? '…' : _fmt(total),
                sub: loading ? '' : '${docs.length} donations',
                icon: Icons.volunteer_activism_outlined,
                color: _KCA.navy),
            _StatData(
                label: 'Campaigns Supported',
                value: loading ? '…' : '${campaigns.length}',
                sub: 'Unique campaigns',
                icon: Icons.campaign_outlined,
                color: _KCA.gold),
            _StatData(
                label: 'Donations Made',
                value: loading ? '…' : '${docs.length}',
                sub: 'All time',
                icon: Icons.favorite_outline,
                color: _KCA.green),
            _StatData(
                label: 'Receipts',
                value: loading ? '…' : (docs.isNotEmpty ? '${docs.length}' : '—'),
                sub: docs.isNotEmpty ? 'Available to download' : 'Donate to generate',
                icon: Icons.receipt_long_outlined,
                color: const Color(0xFF7C3AED)),
          ];

          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.0,
            children: stats.map((s) => _StatCard(stat: s)).toList(),
          );
        });
  }

  static String _fmt(double v) {
    if (v >= 1000000) return 'KES ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return 'KES ${(v / 1000).toStringAsFixed(1)}K';
    return 'KES ${v.toStringAsFixed(0)}';
  }
}

class _StatData {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _StatData({required this.label, required this.value, required this.sub,
    required this.icon, required this.color});
}

// Matches admin _LiveStat exactly: white card, 4px left colored border, icon circle + text
class _StatCard extends StatelessWidget {
  final _StatData stat;
  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 8, offset: const Offset(0, 2))],
            border: Border(
                left: BorderSide(color: stat.color, width: 4))),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: stat.color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(stat.icon, color: stat.color, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(stat.value,
                    style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.bold, color: stat.color)),
                const SizedBox(height: 1),
                Text(stat.label,
                    style: const TextStyle(fontSize: 10,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(stat.sub,
                    style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
        ]));
  }
}

// ── Dashboard panel — matches admin white card with title + Divider ────────────
class _DashPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onViewAll;
  const _DashPanel({required this.title, required this.child, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title,
                style: const TextStyle(fontSize: 15,
                    fontWeight: FontWeight.bold, color: _KCA.navy)),
            const Spacer(),
            if (onViewAll != null)
              TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero),
                  child: const Text('View All',
                      style: TextStyle(color: _KCA.navy,
                          fontWeight: FontWeight.w600, fontSize: 12))),
          ]),
          const Divider(height: 20),
          child,
        ]));
  }
}

// ── Featured campaigns — vertical list inside panel ───────────────────────────
class _FeaturedCampaignList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<CampaignProvider>(builder: (ctx, prov, _) {
      if (prov.isLoading) {
        return const Padding(padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: _KCA.navy)));
      }
      final list = prov.activeCampaigns.take(3).toList();
      if (list.isEmpty) {
        return _emptyState(
            Icons.campaign_outlined, 'No campaigns yet');
      }
      return Column(children: list.asMap().entries.map((e) {
        final campaign = e.value;
        final isLast   = e.key == list.length - 1;
        final color    = _catColor(campaign.category);
        return Column(children: [
          InkWell(
            onTap: () => Navigator.pushNamed(ctx, AppRoutes.campaignDetail,
                arguments: {'campaignId': campaign.id}),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  // Category icon
                  Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: color.withAlpha(20),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(_catIcon(campaign.category),
                          color: color, size: 20)),
                  const SizedBox(width: 14),
                  // Title + progress
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(campaign.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13, color: _KCA.navy),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 5),
                        ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                                value: campaign.progress, minHeight: 5,
                                backgroundColor: Colors.grey[100],
                                valueColor: AlwaysStoppedAnimation<Color>(color))),
                        const SizedBox(height: 4),
                        Text('KES ${_fmt(campaign.raised)} of KES ${_fmt(campaign.goal)}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      ])),
                  const SizedBox(width: 12),
                  // Progress %
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: color.withAlpha(20),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('${campaign.progressPercentage}%',
                          style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.bold, color: color))),
                ])),
          ),
          if (!isLast) Divider(height: 1, color: Colors.grey[100]),
        ]);
      }).toList());
    });
  }
}

// ── Recent donations — vertical list inside panel ─────────────────────────────
class _RecentDonationsList extends StatelessWidget {
  final String uid;
  const _RecentDonationsList({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return _emptyState(Icons.favorite_border, 'Log in to see donations');
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('donor_id', isEqualTo: uid)
            .orderBy('created_at', descending: true)
            .limit(4)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(color: _KCA.navy)));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _emptyState(Icons.favorite_outline,
                "You haven't donated yet.\nBrowse campaigns and make your first gift!");
          }
          return Column(children: docs.asMap().entries.map((e) {
            final data   = e.value.data() as Map<String, dynamic>;
            final title  = data['campaign_title'] as String? ?? 'Donation';
            final amt    = (data['amount'] as num? ?? 0).toDouble();
            final ts     = data['created_at'] as String? ?? '';
            final ok     = (data['status'] as String?) == 'completed';
            final isLast = e.key == docs.length - 1;
            return Column(children: [
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    CircleAvatar(
                        radius: 20, backgroundColor: _KCA.navy.withAlpha(12),
                        child: Icon(
                            ok ? Icons.check_circle_outline : Icons.pending_outlined,
                            color: ok ? _KCA.green : Colors.orange, size: 20)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(fontWeight: FontWeight.w600,
                                  fontSize: 13),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(_timeAgo(ts),
                              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('KES ${amt.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13,
                              color: ok ? _KCA.green : Colors.orange)),
                      Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: ok
                                  ? _KCA.green.withAlpha(20)
                                  : Colors.orange.withAlpha(20),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(ok ? 'Completed' : 'Pending',
                              style: TextStyle(fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: ok ? _KCA.green : Colors.orange))),
                    ]),
                  ])),
              if (!isLast) Divider(height: 1, color: Colors.grey[100]),
            ]);
          }).toList());
        });
  }

  String _timeAgo(String iso) {
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso));
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
  }
}

// ── Quick Actions grid inside panel ──────────────────────────────────────────
class _QuickActionsGrid extends StatelessWidget {
  final ValueChanged<int> onTabSwitch;
  const _QuickActionsGrid({required this.onTabSwitch});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QA(Icons.favorite_rounded,     'Donate Now',   _KCA.navy,
              () => onTabSwitch(1)),
      _QA(Icons.history_rounded,      'My History',   const Color(0xFFF59E0B),
              () => onTabSwitch(2)),
      _QA(Icons.receipt_long_rounded, 'Receipts',     _KCA.green,
              () => Navigator.pushNamed(context, AppRoutes.myDonations)),
      _QA(Icons.help_outline_rounded, 'Help',         const Color(0xFFEC4899),
              () => Navigator.pushNamed(context, AppRoutes.help)),
    ];
    return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: 0,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
        children: actions.map((a) => _QACell(action: a)).toList());
  }
}

class _QACell extends StatelessWidget {
  final _QA action;
  const _QACell({required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: action.color.withAlpha(18),
                  shape: BoxShape.circle,
                  border: Border.all(color: action.color.withAlpha(50))),
              child: Icon(action.icon, color: action.color, size: 22)),
          const SizedBox(height: 7),
          Text(action.label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: Colors.grey[700]),
              textAlign: TextAlign.center, maxLines: 2),
        ]));
  }
}

class _QA {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  _QA(this.icon, this.label, this.color, this.onTap);
}

// ── Shared helpers ────────────────────────────────────────────────────────────
Widget _emptyState(IconData icon, String msg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(children: [
      Icon(icon, color: Colors.grey[300], size: 32),
      const SizedBox(width: 14),
      Expanded(child: Text(msg,
          style: TextStyle(color: Colors.grey[400], fontSize: 13))),
    ]));

String _fmt(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}

IconData _catIcon(String cat) {
  switch (cat.toLowerCase()) {
    case 'scholarships':   return Icons.school;
    case 'infrastructure': return Icons.business;
    case 'research':       return Icons.science;
    case 'health':         return Icons.local_hospital_outlined;
    case 'community':      return Icons.people_outline;
    default:               return Icons.favorite;
  }
}

Color _catColor(String cat) {
  switch (cat.toLowerCase()) {
    case 'scholarships':   return const Color(0xFF2563EB);
    case 'infrastructure': return const Color(0xFFF59E0B);
    case 'research':       return const Color(0xFF10B981);
    case 'health':         return const Color(0xFFEC4899);
    case 'community':      return const Color(0xFF8B5CF6);
    default:               return Colors.teal;
  }
}

class CampaignCard extends StatelessWidget {
  final Campaign campaign;
  final EdgeInsets margin;
  const CampaignCard({super.key, required this.campaign,
    this.margin = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    final color = _catColor(campaign.category);
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.campaignDetail,
          arguments: {'campaignId': campaign.id}),
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(12),
                blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top: category + progress% ───────────────────────────────────
          Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: color.withAlpha(22),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(_catIcon(campaign.category), color: color, size: 20)),
                const Spacer(),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                        color: _progColor(campaign.progress).withAlpha(22),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('${campaign.progressPercentage}%',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                            color: _progColor(campaign.progress)))),
              ])),
          // ── Title + description ─────────────────────────────────────────
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(campaign.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                      color: _KCA.navy),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(height: 3),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(campaign.description,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
          // ── Progress bar ─────────────────────────────────────────────────
          Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: campaign.progress,
                      backgroundColor: Colors.grey[100],
                      valueColor: AlwaysStoppedAnimation<Color>(_progColor(campaign.progress)),
                      minHeight: 5))),
          // ── Raised / Goal ────────────────────────────────────────────────
          Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
              child: Row(children: [
                Text('KES ${_fmt(campaign.raised)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                Text(' / KES ${_fmt(campaign.goal)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                const Spacer(),
                const Icon(Icons.arrow_forward, size: 14, color: _KCA.navy),
              ])),
        ]),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  Color _progColor(double p) {
    if (p >= 0.9) return _KCA.green;
    if (p >= 0.5) return _KCA.navy;
    return _KCA.gold;
  }

  IconData _catIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'scholarships':   return Icons.school;
      case 'infrastructure': return Icons.business;
      case 'research':       return Icons.science;
      case 'health':         return Icons.local_hospital_outlined;
      case 'community':      return Icons.people_outline;
      default:               return Icons.favorite;
    }
  }

  Color _catColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'scholarships':   return const Color(0xFF2563EB);
      case 'infrastructure': return const Color(0xFFF59E0B);
      case 'research':       return const Color(0xFF10B981);
      case 'health':         return const Color(0xFFEC4899);
      case 'community':      return const Color(0xFF8B5CF6);
      default:               return Colors.teal;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — CAMPAIGNS (full live list with search + filter)
// ══════════════════════════════════════════════════════════════════════════════
class _CampaignsTab extends StatefulWidget {
  const _CampaignsTab();
  @override
  State<_CampaignsTab> createState() => _CampaignsTabState();
}

class _CampaignsTabState extends State<_CampaignsTab> {
  String _search   = '';
  String _category = 'all';

  static const _cats = ['all', 'scholarships', 'infrastructure', 'research',
    'health', 'community'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Column(children: [
      // ── Header ─────────────────────────────────────────────────────────────
      Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Campaigns',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _KCA.navy)),
            const SizedBox(height: 12),
            // Search
            TextField(
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                decoration: InputDecoration(
                    hintText: 'Search campaigns…',
                    prefixIcon: const Icon(Icons.search, color: _KCA.navy, size: 20),
                    filled: true, fillColor: _KCA.bg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14))),
            const SizedBox(height: 10),
            // Category filter chips
            SizedBox(
                height: 34,
                child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _cats.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final cat = _cats[i];
                      final active = _category == cat;
                      return GestureDetector(
                          onTap: () => setState(() => _category = cat),
                          child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                  color: active ? _KCA.navy : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: active ? _KCA.navy : Colors.grey[300]!)),
                              child: Text(
                                  cat == 'all' ? 'All' : '${cat[0].toUpperCase()}${cat.substring(1)}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                      color: active ? Colors.white : Colors.grey[600]))));
                    })),
          ])),

      // ── Campaign list ───────────────────────────────────────────────────────
      Expanded(child: StreamBuilder<List<Campaign>>(
          stream: context.read<CampaignProvider>().allCampaignsStream(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _KCA.navy));
            }
            var list = snap.data ?? [];
            // category filter
            if (_category != 'all') {
              list = list.where((c) => c.category.toLowerCase() == _category).toList();
            }
            // search filter
            if (_search.isNotEmpty) {
              list = list.where((c) =>
              c.title.toLowerCase().contains(_search) ||
                  c.description.toLowerCase().contains(_search) ||
                  c.category.toLowerCase().contains(_search)).toList();
            }
            if (list.isEmpty) {
              return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.campaign_outlined, size: 56, color: Colors.grey[200]),
                const SizedBox(height: 12),
                Text(_search.isEmpty ? 'No campaigns in this category'
                    : 'No results for "$_search"',
                    style: TextStyle(color: Colors.grey[400], fontSize: 15)),
              ]));
            }
            return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                itemCount: list.length,
                itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _CampaignListCard(campaign: list[i])));
          })),
    ]));
  }
}

// ── Larger list card for the campaigns tab ────────────────────────────────────
class _CampaignListCard extends StatelessWidget {
  final Campaign campaign;
  const _CampaignListCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final color = _catColor(campaign.category);
    final pct   = campaign.progress;
    return GestureDetector(
        onTap: () => Navigator.pushNamed(context, AppRoutes.campaignDetail,
            arguments: {'campaignId': campaign.id}),
        child: Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(10),
                    blurRadius: 8, offset: const Offset(0, 3))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Colored top bar
              Container(
                  height: 6,
                  decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)))),
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: color.withAlpha(22),
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(_catIcon(campaign.category), color: color, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(campaign.title,
                          style: const TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 15, color: _KCA.navy),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: _progColor(pct).withAlpha(22),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text('${(pct * 100).round()}%',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                                  color: _progColor(pct)))),
                    ]),
                    const SizedBox(height: 10),
                    Text(campaign.description,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                            value: pct, minHeight: 7,
                            backgroundColor: Colors.grey[100],
                            valueColor: AlwaysStoppedAnimation<Color>(_progColor(pct)))),
                    const SizedBox(height: 10),
                    Row(children: [
                      Text('KES ${_fmt(campaign.raised)}',
                          style: const TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 13, color: _KCA.navy)),
                      Text(' raised',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      const Spacer(),
                      Text('Goal: KES ${_fmt(campaign.goal)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity,
                        child: ElevatedButton(
                            onPressed: () => Navigator.pushNamed(context, AppRoutes.donationFlow,
                                arguments: {'campaign': campaign.toJson(),
                                  'campaignId': campaign.id}),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: _KCA.navy, foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            child: const Text('Donate Now',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
                  ])),
            ])));
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  Color _progColor(double p) {
    if (p >= 0.9) return _KCA.green;
    if (p >= 0.5) return _KCA.navy;
    return _KCA.gold;
  }

  IconData _catIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'scholarships':   return Icons.school;
      case 'infrastructure': return Icons.business;
      case 'research':       return Icons.science;
      case 'health':         return Icons.local_hospital_outlined;
      case 'community':      return Icons.people_outline;
      default:               return Icons.favorite;
    }
  }

  Color _catColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'scholarships':   return const Color(0xFF2563EB);
      case 'infrastructure': return const Color(0xFFF59E0B);
      case 'research':       return const Color(0xFF10B981);
      case 'health':         return const Color(0xFFEC4899);
      case 'community':      return const Color(0xFF8B5CF6);
      default:               return Colors.teal;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — DONATIONS (full history with filters, receipt button)
// ══════════════════════════════════════════════════════════════════════════════
class _DonationsTab extends StatefulWidget {
  const _DonationsTab();
  @override
  State<_DonationsTab> createState() => _DonationsTabState();
}

class _DonationsTabState extends State<_DonationsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return SafeArea(child: Column(children: [
      // ── Header ─────────────────────────────────────────────────────────────
      Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('My Donations',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _KCA.navy)),
            const SizedBox(height: 12),
            TabBar(
                controller: _tabs,
                labelColor: _KCA.navy, unselectedLabelColor: Colors.grey,
                indicatorColor: _KCA.gold, indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [Tab(text: 'All Donations'), Tab(text: 'Receipts')]),
          ])),

      // ── Tabs ───────────────────────────────────────────────────────────────
      Expanded(child: TabBarView(controller: _tabs, children: [
        _DonationHistoryList(uid: uid),
        _ReceiptsList(uid: uid),
      ])),
    ]));
  }
}

class _DonationHistoryList extends StatelessWidget {
  final String uid;
  const _DonationHistoryList({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return _empty('Log in to see your donations');
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('donor_id', isEqualTo: uid)
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _KCA.navy));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _empty("You haven't made any donations yet.\nBrowse campaigns and make your first gift!");
          }
          // Summary
          double total = 0;
          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            if ((data['status'] as String?) == 'completed') {
              total += (data['amount'] as num? ?? 0).toDouble();
            }
          }
          return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                // Total summary
                Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_KCA.navy, Color(0xFF2563EB)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      const Icon(Icons.volunteer_activism, color: Colors.white, size: 28),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Total Given', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('KES ${total.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white,
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ]),
                      const Spacer(),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text('Transactions', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('${docs.length}', style: const TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ]),
                    ])),
                ...docs.map((d) => _DonationTile(data: d.data() as Map<String, dynamic>)),
              ]);
        });
  }

  Widget _empty(String msg) => Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.favorite_border, size: 56, color: Colors.grey[200]),
        const SizedBox(height: 14),
        Text(msg, style: TextStyle(color: Colors.grey[400], fontSize: 14),
            textAlign: TextAlign.center),
      ]));
}

class _DonationTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DonationTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final title  = data['campaign_title'] as String? ?? 'Donation';
    final amt    = (data['amount'] as num? ?? 0).toDouble();
    final ts     = data['created_at'] as String? ?? '';
    final status = data['status'] as String? ?? 'pending';
    final isOk   = status == 'completed';
    final txId   = data['checkout_request_id'] as String?
        ?? data['transaction_id'] as String? ?? '';

    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(8),
                blurRadius: 6, offset: const Offset(0, 2))]),
        child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: isOk ? _KCA.green.withAlpha(20) : Colors.orange.withAlpha(20),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(
                    isOk ? Icons.check_circle_outline : Icons.pending_outlined,
                    color: isOk ? _KCA.green : Colors.orange, size: 22)),
            title: Text(title, style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 2),
              Text(_fmtDate(ts),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              if (txId.isNotEmpty)
                Text('Ref: ${txId.length > 12 ? txId.substring(0, 12) : txId}…',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400])),
            ]),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('KES ${amt.toStringAsFixed(0)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                          color: isOk ? _KCA.green : Colors.orange)),
                  Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: isOk ? _KCA.green.withAlpha(20) : Colors.orange.withAlpha(20),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(isOk ? 'Completed' : status.capitalize(),
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                              color: isOk ? _KCA.green : Colors.orange))),
                ])));
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) { return iso; }
  }
}

class _ReceiptsList extends StatelessWidget {
  final String uid;
  const _ReceiptsList({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) {
      return const Center(child: Text('Log in to see receipts'));
    }
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('receipts')
            .where('donor_id', isEqualTo: uid)
            .orderBy('generated_at', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _KCA.navy));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey[200]),
                  const SizedBox(height: 14),
                  Text('No receipts yet',
                      style: TextStyle(color: Colors.grey[400], fontSize: 15)),
                  Text('Receipts are generated after\nsuccessful donations.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      textAlign: TextAlign.center),
                ]));
          }
          return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final data    = docs[i].data() as Map<String, dynamic>;
                final rcptNo  = data['receipt_no']   as String? ?? docs[i].id;
                final title   = data['campaign_title'] as String? ?? 'Donation';
                final amt     = (data['amount'] as num? ?? 0).toDouble();
                final genAt   = data['generated_at'] as String? ?? '';
                return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8),
                            blurRadius: 6, offset: const Offset(0, 2))]),
                    child: Row(children: [
                      Container(width: 44, height: 44,
                          decoration: BoxDecoration(
                              color: _KCA.navy.withAlpha(12),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.receipt_long_outlined,
                              color: _KCA.navy, size: 22)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('KES ${amt.toStringAsFixed(0)}  •  ${_fmtDate(genAt)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        Text('#$rcptNo', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                      ])),
                      TextButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Opening receipt…'),
                                    backgroundColor: _KCA.navy));
                          },
                          icon: const Icon(Icons.download_outlined, size: 16),
                          label: const Text('View', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(foregroundColor: _KCA.navy,
                              padding: const EdgeInsets.symmetric(horizontal: 8))),
                    ]));
              });
        });
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    } catch (_) { return ''; }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 4 — PROFILE (full, with live edit)
// ══════════════════════════════════════════════════════════════════════════════
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final uid  = FirebaseAuth.instance.currentUser?.uid ?? '';

    return SafeArea(child: SingleChildScrollView(child: Column(children: [
      // ── Hero header ────────────────────────────────────────────────────────
      Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [_KCA.navy, Color(0xFF2563EB)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Column(children: [
            Stack(alignment: Alignment.bottomRight, children: [
              CircleAvatar(radius: 46, backgroundColor: _KCA.gold,
                  child: Text(user?.initials ?? 'U',
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold,
                          color: _KCA.navy))),
              GestureDetector(
                  onTap: () => _showEditProfile(context, user?.name ?? '',
                      user?.phoneNumber ?? ''),
                  child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                          color: _KCA.navy, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)),
                      child: const Icon(Icons.edit, color: Colors.white, size: 14))),
            ]),
            const SizedBox(height: 14),
            Text(user?.name ?? 'User',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Text(user?.email ?? '',
                style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(180))),
            const SizedBox(height: 12),
            if (user?.donorType != null)
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                      color: _KCA.gold, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                      '${user!.donorType!.icon}  ${user.donorType!.displayName} Donor',
                      style: const TextStyle(color: _KCA.navy,
                          fontWeight: FontWeight.bold, fontSize: 13))),
          ])),

      const SizedBox(height: 20),

      // ── Live donation stats ────────────────────────────────────────────────
      if (uid.isNotEmpty) _ProfileStats(uid: uid),
      const SizedBox(height: 20),

      // ── Info section ────────────────────────────────────────────────────────
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            _infoCard(Icons.email_outlined, 'Email', user?.email ?? '—'),
            if (user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty)
              _infoCard(Icons.phone_outlined, 'Phone', user.phoneNumber!),
            _infoCard(Icons.verified_user_outlined, 'Email Verified',
                (user?.isEmailVerified ?? false) ? 'Verified ✓' : 'Not verified',
                valueColor: (user?.isEmailVerified ?? false)
                    ? _KCA.green : Colors.orange),
            _infoCard(Icons.badge_outlined, 'Account Type',
                user?.role.displayName ?? 'Donor'),
          ])),

      const SizedBox(height: 20),

      // ── Menu ─────────────────────────────────────────────────────────────
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            _menuTile(context, Icons.edit_outlined, 'Edit Profile',
                    () => _showEditProfile(context, user?.name ?? '',
                    user?.phoneNumber ?? '')),
            _menuTile(context, Icons.lock_outline, 'Change Password',
                    () => Navigator.pushNamed(context, AppRoutes.forgotPassword)),
            _menuTile(context, Icons.history_outlined, 'Donation History',
                    () => Navigator.pushNamed(context, AppRoutes.myDonations)),
            _menuTile(context, Icons.notifications_outlined, 'Notifications',
                    () => Navigator.pushNamed(context, AppRoutes.notifications)),
            _menuTile(context, Icons.help_outline, 'Help & Support',
                    () => Navigator.pushNamed(context, AppRoutes.help)),
          ])),

      const SizedBox(height: 16),

      // ── Logout ─────────────────────────────────────────────────────────────
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context, auth),
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Log Out',
                      style: TextStyle(color: Colors.red, fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),

      const SizedBox(height: 36),
    ])));
  }

  // ── Edit profile bottom sheet ──────────────────────────────────────────────
  void _showEditProfile(BuildContext context, String name, String phone) {
    final nameCtrl  = TextEditingController(text: name);
    final phoneCtrl = TextEditingController(text: phone);
    final formKey   = GlobalKey<FormState>();
    bool saving     = false;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
          return Container(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Handle
                        Center(child: Container(width: 40, height: 4,
                            decoration: BoxDecoration(color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 20),
                        const Text('Edit Profile',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _KCA.navy)),
                        const SizedBox(height: 20),
                        TextFormField(
                            controller: nameCtrl,
                            decoration: _inputDec('Full Name', Icons.person_outline),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null),
                        const SizedBox(height: 14),
                        TextFormField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: _inputDec('Phone Number', Icons.phone_outlined)),
                        const SizedBox(height: 24),
                        SizedBox(width: double.infinity,
                            child: ElevatedButton(
                                onPressed: saving ? null : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setS(() => saving = true);
                                  try {
                                    final uid = FirebaseAuth.instance.currentUser?.uid;
                                    if (uid != null) {
                                      await FirebaseFirestore.instance
                                          .collection('donors').doc(uid).update({
                                        'name': nameCtrl.text.trim(),
                                        'phone_number': phoneCtrl.text.trim(),
                                      });
                                      await FirebaseAuth.instance.currentUser
                                          ?.updateDisplayName(nameCtrl.text.trim());
                                    }
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Profile updated ✓'),
                                              backgroundColor: _KCA.green));
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e'),
                                              backgroundColor: Colors.red));
                                    }
                                  }
                                  if (ctx.mounted) setS(() => saving = false);
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: _KCA.navy, foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12))),
                                child: saving
                                    ? const SizedBox(height: 18, width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Save Changes',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
                      ]))));
        }));
  }

  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
      labelText: label, prefixIcon: Icon(icon, color: _KCA.navy),
      filled: true, fillColor: _KCA.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _KCA.navy, width: 2)),
      labelStyle: const TextStyle(color: _KCA.navy));

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Log Out',
                style: TextStyle(color: _KCA.navy, fontWeight: FontWeight.bold)),
            content: const Text('Are you sure you want to log out?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: Colors.grey[600]))),
              ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final nav = Navigator.of(context);
                    auth.logout().then((_) => nav.pushReplacementNamed(AppRoutes.login));
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('Log Out', style: TextStyle(color: Colors.white))),
            ]));
  }

  Widget _infoCard(IconData icon, String label, String value, {Color? valueColor}) {
    return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(6),
                blurRadius: 4, offset: const Offset(0, 1))]),
        child: Row(children: [
          Icon(icon, color: _KCA.navy, size: 20),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87)),
          ]),
        ]));
  }

  Widget _menuTile(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!)),
        child: ListTile(
            leading: Icon(icon, color: _KCA.navy),
            title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
            onTap: onTap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }
}

// ── Profile stats strip (live) ────────────────────────────────────────────────
class _ProfileStats extends StatelessWidget {
  final String uid;
  const _ProfileStats({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('donor_id', isEqualTo: uid)
            .where('status', isEqualTo: 'completed')
            .snapshots(),
        builder: (ctx, snap) {
          final docs   = snap.data?.docs ?? [];
          double total = 0;
          final Set<String> camps = {};
          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            total += (data['amount'] as num? ?? 0).toDouble();
            final c = data['campaign_id'] as String?;
            if (c != null) camps.add(c);
          }
          return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                _statBox('KES ${_fmt(total)}', 'Total Donated', Icons.volunteer_activism_outlined),
                const SizedBox(width: 10),
                _statBox('${docs.length}', 'Donations', Icons.favorite_outline),
                const SizedBox(width: 10),
                _statBox('${camps.length}', 'Campaigns', Icons.campaign_outlined),
              ]));
        });
  }

  Widget _statBox(String value, String label, IconData icon) {
    return Expanded(child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(6),
                blurRadius: 4, offset: const Offset(0, 1))]),
        child: Column(children: [
          Icon(icon, color: _KCA.navy, size: 20),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 15, color: _KCA.navy),
              textAlign: TextAlign.center, maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              textAlign: TextAlign.center),
        ])));
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ── String extension ──────────────────────────────────────────────────────────
extension _StringCap on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}