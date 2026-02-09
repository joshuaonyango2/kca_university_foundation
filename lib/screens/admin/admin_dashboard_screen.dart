// lib/screens/admin/admin_dashboard_screen.dart
// 📱 MOBILE-RESPONSIVE VERSION

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/campaign_provider.dart';
import '../../config/routes.dart';

// Import all tabs
import 'tabs/overview_tab.dart';
import 'tabs/campaigns_tab.dart';
import 'tabs/donors_tab.dart';
import 'tabs/transactions_tab.dart';
import 'tabs/reports_tab.dart';
import 'tabs/settings_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<_MenuItem> _menuItems = [
    _MenuItem(icon: Icons.dashboard, title: 'Overview'),
    _MenuItem(icon: Icons.campaign, title: 'Campaigns'),
    _MenuItem(icon: Icons.people, title: 'Donors'),
    _MenuItem(icon: Icons.receipt_long, title: 'Transactions'),
    _MenuItem(icon: Icons.analytics, title: 'Reports'),
    _MenuItem(icon: Icons.settings, title: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CampaignProvider>(context, listen: false).fetchCampaigns();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(user, isDesktop),
      // Only show drawer on mobile
      drawer: isDesktop ? null : _buildDrawer(user),
      body: isDesktop
          ? Row(
        children: [
          // Desktop sidebar
          Container(
            width: 280,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
              ),
            ),
            child: _buildSidebarContent(user),
          ),
          // Desktop content
          Expanded(child: _getSelectedScreen()),
        ],
      )
          : _getSelectedScreen(), // Mobile content (full width)
    );
  }

  // 📱 MOBILE APP BAR
  PreferredSizeWidget _buildAppBar(dynamic user, bool isDesktop) {
    if (isDesktop) {
      // Desktop - Simple top bar
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          _menuItems[_selectedIndex].title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          // Search
          Container(
            width: 300,
            height: 40,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Notifications
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined, color: Colors.black87),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 8,
                      minHeight: 8,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 16),
        ],
      );
    } else {
      // Mobile - Compact app bar with menu
      return AppBar(
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KCA Foundation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _menuItems[_selectedIndex].title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined, color: Colors.white),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 6,
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {},
          ),
        ],
      );
    }
  }

  // 📱 MOBILE DRAWER
  Widget _buildDrawer(dynamic user) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          ),
        ),
        child: _buildSidebarContent(user),
      ),
    );
  }

  // 🎨 SIDEBAR/DRAWER CONTENT (Same for both mobile & desktop)
  Widget _buildSidebarContent(dynamic user) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'KCA Foundation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Admin Portal',
                style: TextStyle(
                  color: Colors.white.withAlpha(204),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white24, height: 1),

        // Menu Items
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _menuItems.length,
            itemBuilder: (context, index) {
              return _buildMenuItem(_menuItems[index], index);
            },
          ),
        ),

        const Divider(color: Colors.white24, height: 1),

        // User Profile
        _buildUserProfile(user),
      ],
    );
  }

  Widget _buildMenuItem(_MenuItem item, int index) {
    final isSelected = _selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withAlpha(38) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(item.icon, color: Colors.white),
        title: Text(
          item.title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() => _selectedIndex = index);
          // Close drawer on mobile after selection
          if (MediaQuery.of(context).size.width < 900) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildUserProfile(dynamic user) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.white,
          child: Text(
            user?.firstName?.substring(0, 1).toUpperCase() ?? 'A',
            style: const TextStyle(
              color: Color(0xFF1E3A8A),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user?.name ?? 'Admin',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          user?.email ?? '',
          style: TextStyle(
            color: Colors.white.withAlpha(204),
            fontSize: 11,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person, size: 18),
                  SizedBox(width: 12),
                  Text('Profile'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, size: 18),
                  SizedBox(width: 12),
                  Text('Settings'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 18, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Logout', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (String value) async {
            if (value == 'logout') {
              final authProvider =
              Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.adminLogin);
              }
            } else if (value == 'settings' || value == 'profile') {
              setState(() => _selectedIndex = 5);
              if (MediaQuery.of(context).size.width < 900) {
                Navigator.pop(context);
              }
            }
          },
        ),
      ),
    );
  }

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return const AdminOverviewTab();
      case 1:
        return const AdminCampaignsTab();
      case 2:
        return const AdminDonorsTab();
      case 3:
        return const AdminTransactionsTab();
      case 4:
        return const AdminReportsTab();
      case 5:
        return const AdminSettingsTab();
      default:
        return const AdminOverviewTab();
    }
  }
}

// Helper class
class _MenuItem {
  final IconData icon;
  final String title;

  _MenuItem({required this.icon, required this.title});
}