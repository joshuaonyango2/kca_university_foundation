// lib/screens/admin/widgets/admin_layout.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/routes.dart';
import '../../../providers/auth_provider.dart';

class _KCA {
  static const navy    = Color(0xFF1B2263);
  static const gold    = Color(0xFFF5A800);
  static const navyLight = Color(0xFF243080);
  static const white   = Colors.white;
  static const bg      = Color(0xFFF0F2F8);
}

class AdminLayout extends StatelessWidget {
  final String title;
  final Widget child;
  final String activeRoute;
  final List<Widget>? actions;

  const AdminLayout({
    super.key,
    required this.title,
    required this.child,
    required this.activeRoute,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: _KCA.bg,
      appBar: isWide ? null : _buildMobileAppBar(context),
      drawer: isWide ? null : _buildDrawer(context),
      body: isWide
          ? Row(
        children: [
          _buildSidebar(context),
          Expanded(child: _buildBody(context)),
        ],
      )
          : _buildBody(context),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _KCA.navy,
      foregroundColor: _KCA.white,
      title: Text(title,
          style: const TextStyle(
              color: _KCA.white, fontWeight: FontWeight.bold)),
      actions: actions,
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: _KCA.navy,
        child: _buildSidebarContent(context),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 240,
      height: double.infinity,
      color: _KCA.navy,
      child: _buildSidebarContent(context),
    );
  }

  Widget _buildSidebarContent(BuildContext context) {
    return Column(
      children: [
        // ── Logo area ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _KCA.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _KCA.gold, width: 2),
                ),
                padding: const EdgeInsets.all(6),
                child: ClipOval(
                  child: Image.asset('assets/image.asset.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.admin_panel_settings,
                          color: _KCA.navy,
                          size: 32)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('KCA Foundation',
                  style: TextStyle(
                      color: _KCA.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 4),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _KCA.gold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Admin Portal',
                    style: TextStyle(
                        color: _KCA.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),

        Divider(color: Colors.white.withAlpha(30), height: 1),
        const SizedBox(height: 8),

        // ── Nav items ──────────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _navItem(context,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                  route: AppRoutes.adminDashboard),
              _navItem(context,
                  icon: Icons.campaign_outlined,
                  activeIcon: Icons.campaign,
                  label: 'Campaigns',
                  route: AppRoutes.adminCampaigns),
              _navItem(context,
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'Donors',
                  route: AppRoutes.adminDonors),
              _navItem(context,
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: 'Transactions',
                  route: AppRoutes.adminTransactions),
              _navItem(context,
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart,
                  label: 'Reports',
                  route: AppRoutes.adminReports),
              _navItem(context,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'Settings',
                  route: AppRoutes.adminSettings),
            ],
          ),
        ),

        // ── Logout ─────────────────────────────────────────────────────────
        Divider(color: Colors.white.withAlpha(30), height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              return ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                title: const Text('Log Out',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                onTap: () async {
                  await auth.logout();
                  if (!context.mounted) return;
                  Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.adminLogin);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _navItem(BuildContext context,
      {required IconData icon,
        required IconData activeIcon,
        required String label,
        required String route}) {
    final isActive = activeRoute == route;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(
          isActive ? activeIcon : icon,
          color: isActive ? _KCA.gold : Colors.white.withAlpha(180),
          size: 20,
        ),
        title: Text(label,
            style: TextStyle(
                color: isActive ? _KCA.gold : Colors.white.withAlpha(180),
                fontSize: 14,
                fontWeight:
                isActive ? FontWeight.w700 : FontWeight.normal)),
        selected: isActive,
        selectedTileColor: Colors.white.withAlpha(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () {
          if (!isActive) {
            Navigator.of(context).pushReplacementNamed(route);
          }
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top bar (desktop only) ─────────────────────────────────────────
        if (MediaQuery.of(context).size.width >= 900)
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            color: _KCA.white,
            child: Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _KCA.navy)),
                const Spacer(),
                if (actions != null) ...actions!,
                const SizedBox(width: 16),
                Consumer<AuthProvider>(
                  builder: (_, auth, __) => CircleAvatar(
                    radius: 18,
                    backgroundColor: _KCA.navy,
                    child: Text(
                      auth.user?.initials ?? 'A',
                      style: const TextStyle(
                          color: _KCA.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ── Page content ───────────────────────────────────────────────────
        Expanded(child: child),
      ],
    );
  }
}