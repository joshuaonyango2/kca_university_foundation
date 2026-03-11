// lib/screens/admin/staff_dashboard_screen.dart
//
// This screen is shown to staff members (non-admin) after login.
// It renders only the modules their role's permissions allow.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../models/role_model.dart';
import '../../providers/auth_provider.dart';

const _navy  = Color(0xFF1B2263);
const _gold  = Color(0xFFF5A800);
const _bg    = Color(0xFFF0F2F8);
const _green = Color(0xFF10B981);
const _amber = Color(0xFFF59E0B);

// ─────────────────────────────────────────────────────────────────────────────
class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});
  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  final _db  = FirebaseFirestore.instance;
  Map<String, dynamic>? _staffProfile;
  List<String> _permissions = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadStaffProfile(); }

  Future<void> _loadStaffProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      final doc = await _db.collection('staff').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        _staffProfile = data;
        _permissions  = List<String>.from(data['permissions'] as List? ?? []);
        // If admin flag is set, give all permissions
        if (data['is_admin'] == true) {
          _permissions = Permission.values.map((p) => p.key).toList();
        }
      }
    } catch (e) { debugPrint('Staff profile load error: $e'); }
    if (mounted) setState(() => _loading = false);
  }

  bool _can(Permission p) => _permissions.contains(p.key);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: _bg, body: Center(child: CircularProgressIndicator(color: _navy)));

    if (_staffProfile == null) {
      return Scaffold(
          backgroundColor: _bg,
          body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            const Text('Profile not found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Your account exists but has no staff profile.', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: () {
                  final auth = context.read<AuthProvider>();
                  final nav  = Navigator.of(context);
                  auth.logout().then((_) => nav.pushReplacementNamed(AppRoutes.adminLogin));
                },
                style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
                child: const Text('Back to Login')),
          ])));
    }

    final name     = _staffProfile!['name'] as String? ?? 'Staff';
    final roleName = _staffProfile!['role_name'] as String? ?? 'Staff';
    final initials = name.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    final isAdmin  = _staffProfile!['is_admin'] as bool? ?? false;

    // Build available modules based on permissions
    final modules = <_Module>[];

    if (_can(Permission.viewDashboard)) {
      modules.add(_Module(icon: Icons.dashboard, label: 'Dashboard', color: _navy,
          builder: () => _DashboardModule(permissions: _permissions)));
    }
    if (_can(Permission.viewCampaigns)) {
      modules.add(_Module(icon: Icons.campaign, label: 'Campaigns', color: const Color(0xFF2563EB),
          builder: () => _CampaignsModule(canManage: _can(Permission.manageCampaigns))));
    }
    if (_can(Permission.viewDonors)) {
      modules.add(_Module(icon: Icons.people, label: 'Donors', color: _green,
          builder: () => _DonorsModule(canManage: _can(Permission.manageDonors))));
    }
    if (_can(Permission.viewTransactions)) {
      modules.add(_Module(icon: Icons.receipt_long, label: 'Transactions', color: _amber,
          builder: () => _TransactionsModule(canExport: _can(Permission.exportData))));
    }
    if (_can(Permission.manageStaff)) {
      modules.add(_Module(icon: Icons.group, label: 'Staff', color: Colors.purple,
          builder: () => _StaffModule()));
    }

    if (modules.isEmpty) {
      return _noAccessScreen(name, roleName);
    }

    return _StaffShell(
      name: name, roleName: roleName, initials: initials, isAdmin: isAdmin,
      modules: modules,
    );
  }

  Widget _noAccessScreen(String name, String role) {
    return Scaffold(
        backgroundColor: _bg,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 80, height: 80, decoration: BoxDecoration(color: _navy, shape: BoxShape.circle),
              child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: const TextStyle(color: _gold, fontSize: 32, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 16),
          Text('Welcome, $name', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 4),
          Text('Role: $role', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Column(children: [
                Icon(Icons.lock_outline, size: 40, color: Colors.orange),
                SizedBox(height: 12),
                Text('No Modules Assigned', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 8),
                Text('Your role has no dashboard permissions yet.\nPlease contact your administrator.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ])),
          const SizedBox(height: 24),
          OutlinedButton.icon(
              onPressed: () {
                final auth = context.read<AuthProvider>();
                final nav  = Navigator.of(context);
                auth.logout().then((_) => nav.pushReplacementNamed(AppRoutes.adminLogin));
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Log Out', style: TextStyle(color: Colors.red))),
        ])));
  }
}

// ── Shell with sidebar ────────────────────────────────────────────────────────
class _StaffShell extends StatefulWidget {
  final String name, roleName, initials;
  final bool isAdmin;
  final List<_Module> modules;
  const _StaffShell({required this.name, required this.roleName, required this.initials, required this.isAdmin, required this.modules});
  @override
  State<_StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<_StaffShell> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: _bg,
      appBar: isWide ? null : AppBar(
          backgroundColor: _navy, foregroundColor: Colors.white,
          title: Text(widget.modules[_selected].label, style: const TextStyle(fontWeight: FontWeight.bold))),
      drawer: isWide ? null : _buildDrawer(),
      body: isWide
          ? Row(children: [_buildSidebar(), Expanded(child: _buildContent())])
          : _buildContent(),
    );
  }

  Widget _buildDrawer() => Drawer(child: Container(color: _navy, child: _buildSidebarContent()));
  Widget _buildSidebar() => Container(width: 230, height: double.infinity, color: _navy, child: _buildSidebarContent());

  Widget _buildSidebarContent() => Column(children: [
    Container(padding: const EdgeInsets.fromLTRB(20, 48, 20, 24), child: Column(children: [
      CircleAvatar(radius: 30, backgroundColor: _gold,
          child: Text(widget.initials, style: const TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 20))),
      const SizedBox(height: 10),
      Text(widget.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: widget.isAdmin ? _gold : Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(12)),
          child: Text(widget.isAdmin ? 'Admin' : widget.roleName,
              style: TextStyle(color: widget.isAdmin ? _navy : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
    ])),
    Divider(color: Colors.white.withAlpha(30), height: 1),
    Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: widget.modules.asMap().entries.map((e) {
          final i = e.key; final m = e.value;
          return Container(margin: const EdgeInsets.only(bottom: 4), child: ListTile(
              leading: Icon(m.icon, color: i == _selected ? _gold : Colors.white.withAlpha(180), size: 20),
              title: Text(m.label, style: TextStyle(color: i == _selected ? _gold : Colors.white.withAlpha(180),
                  fontSize: 14, fontWeight: i == _selected ? FontWeight.bold : FontWeight.normal)),
              selected: i == _selected, selectedTileColor: Colors.white.withAlpha(20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () => setState(() => _selected = i)));
        }).toList())),
    Divider(color: Colors.white.withAlpha(30), height: 1),
    Padding(padding: const EdgeInsets.all(12), child: ListTile(
        leading: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
        title: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () {
          final auth = context.read<AuthProvider>();
          final nav  = Navigator.of(context);
          auth.logout().then((_) => nav.pushReplacementNamed(AppRoutes.adminLogin));
        })),
  ]);

  Widget _buildContent() => Column(children: [
    // Top bar (desktop)
    if (MediaQuery.of(context).size.width >= 900)
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          color: Colors.white,
          child: Row(children: [
            Text(widget.modules[_selected].label,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _navy)),
            const Spacer(),
            CircleAvatar(radius: 18, backgroundColor: _navy,
                child: Text(widget.initials, style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 12))),
          ])),
    Expanded(child: widget.modules[_selected].builder()),
  ]);
}

// ── Module definitions ────────────────────────────────────────────────────────
class _Module {
  final IconData   icon;
  final String     label;
  final Color      color;
  final Widget Function() builder;
  const _Module({required this.icon, required this.label, required this.color, required this.builder});
}

// ══════════════════════════════════════════════════════════════════════════════
// MODULE WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

// ── Dashboard module ──────────────────────────────────────────────────────────
class _DashboardModule extends StatelessWidget {
  final List<String> permissions;
  const _DashboardModule({required this.permissions});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('My Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(height: 6),
        Text('You have access to ${permissions.length} feature(s) based on your role.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const SizedBox(height: 20),

        // Live stats
        StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations').snapshots(),
            builder: (ctx, snap) {
              final total = snap.data?.docs.fold(0.0, (s, d) => s + ((d.data() as Map)['amount'] as num? ?? 0)) ?? 0.0;
              return _StatCard('Total Donations', 'KES ${_f(total)}', Icons.payments, _green);
            }),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donors').snapshots(),
            builder: (ctx, snap) => _StatCard('Registered Donors', '${snap.data?.docs.length ?? 0}', Icons.people, _navy)),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('campaigns').where('is_active', isEqualTo: true).snapshots(),
            builder: (ctx, snap) => _StatCard('Active Campaigns', '${snap.data?.docs.length ?? 0}', Icons.campaign, _amber)),
        const SizedBox(height: 24),

        // Permissions list
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your Permissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: permissions.map((p) {
                final label = PermissionExt.fromKey(p)?.label ?? p;
                return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: _navy.withAlpha(15), borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle, size: 13, color: _green),
                      const SizedBox(width: 5),
                      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _navy)),
                    ]));
              }).toList()),
            ])),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ]),
      ]));
}

// ── Campaigns module (limited) ────────────────────────────────────────────────
class _CampaignsModule extends StatelessWidget {
  final bool canManage;
  const _CampaignsModule({required this.canManage});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('campaigns').orderBy('created_at', descending: true).snapshots(),
        builder: (ctx, snap) {
          final docs = snap.data?.docs ?? [];
          return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final d      = docs[i].data() as Map<String, dynamic>;
                final raised = (d['raised'] as num? ?? 0).toDouble();
                final goal   = (d['goal'] as num? ?? 1).toDouble();
                final pct    = (raised / goal).clamp(0.0, 1.0);
                return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 2))]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(d['title'] as String? ?? 'Campaign',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy))),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: (d['is_active'] as bool? ?? false) ? _green.withAlpha(25) : Colors.grey.withAlpha(20),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text((d['is_active'] as bool? ?? false) ? 'Active' : 'Inactive',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                    color: (d['is_active'] as bool? ?? false) ? _green : Colors.grey))),
                      ]),
                      const SizedBox(height: 8),
                      Text('KES ${_f(raised)} raised of KES ${_f(goal)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      const SizedBox(height: 6),
                      ClipRRect(borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(value: pct, minHeight: 8, color: _navy, backgroundColor: Colors.grey[200])),
                      if (!canManage)
                        Padding(padding: const EdgeInsets.only(top: 8),
                            child: Text('View only — you do not have edit permissions', style: TextStyle(fontSize: 10, color: Colors.grey[400]))),
                    ]));
              });
        });
  }
}

// ── Donors module (limited) ───────────────────────────────────────────────────
class _DonorsModule extends StatelessWidget {
  final bool canManage;
  const _DonorsModule({required this.canManage});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('donors').orderBy('created_at', descending: true).snapshots(),
        builder: (ctx, snap) {
          final docs = snap.data?.docs ?? [];
          return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: docs.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                if (i == 0) {
                  return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('\${docs.length} registered donors',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13)));
                }
                final d    = docs[i - 1].data() as Map<String, dynamic>;
                final name = d['name'] as String? ?? 'Unknown';
                return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 4, offset: const Offset(0, 2))]),
                    child: Row(children: [
                      CircleAvatar(radius: 20, backgroundColor: _navy,
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: const TextStyle(color: _gold, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(d['email'] as String? ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ])),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: _navy.withAlpha(15), borderRadius: BorderRadius.circular(6)),
                          child: Text(d['donor_type'] as String? ?? 'individual',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _navy))),
                    ]));
              });
        });
  }
}

// ── Transactions module (limited) ─────────────────────────────────────────────
class _TransactionsModule extends StatelessWidget {
  final bool canExport;
  const _TransactionsModule({required this.canExport});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('donations').orderBy('created_at', descending: true).snapshots(),
        builder: (ctx, snap) {
          final docs = snap.data?.docs ?? [];
          final total = docs.fold(0.0, (s, d) => s + ((d.data() as Map)['amount'] as num? ?? 0));
          return Column(children: [
            Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(14)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _sm('${docs.length}', 'Total'),
                  Container(width: 1, height: 32, color: Colors.white24),
                  _sm('KES ${_f(total)}', 'Amount'),
                  Container(width: 1, height: 32, color: Colors.white24),
                  _sm('${docs.where((d) => ((d.data() as Map)['status'] ?? 'completed') == 'completed').length}', 'Completed'),
                ])),
            Expanded(child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final d      = docs[i].data() as Map<String, dynamic>;
                  final status = d['status'] as String? ?? 'completed';
                  final color  = status == 'completed' ? _green : status == 'pending' ? _amber : Colors.red;
                  return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 4, offset: const Offset(0, 2))]),
                      child: Row(children: [
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
                            child: Icon(Icons.payments_outlined, color: color, size: 18)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(d['donor_name'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(d['campaign_title'] as String? ?? '—', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('KES ${_f((d['amount'] as num? ?? 0).toDouble())}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(4)),
                              child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color))),
                        ]),
                      ]));
                })),
          ]);
        });
  }
  Widget _sm(String v, String l) => Column(children: [
    Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
    Text(l, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 11)),
  ]);
}

// ── Staff module ──────────────────────────────────────────────────────────────
class _StaffModule extends StatelessWidget {
  const _StaffModule();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('staff').snapshots(),
        builder: (ctx, snap) {
          final docs = snap.data?.docs ?? [];
          return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final d       = docs[i].data() as Map<String, dynamic>;
                final name    = d['name'] as String? ?? 'Unknown';
                final isAdmin = d['is_admin'] as bool? ?? false;
                return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 4, offset: const Offset(0, 2))]),
                    child: Row(children: [
                      CircleAvatar(radius: 20, backgroundColor: _navy,
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                              style: const TextStyle(color: _gold, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          if (isAdmin) ...[const SizedBox(width: 6),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(4)),
                                child: const Text('ADMIN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: _navy)))],
                        ]),
                        Text(d['role_name'] as String? ?? 'Staff', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ])),
                      Container(width: 10, height: 10, decoration: BoxDecoration(
                          color: (d['is_active'] as bool? ?? true) ? _green : Colors.grey, shape: BoxShape.circle)),
                    ]));
              });
        });
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────
String _f(double v) => v >= 1000000 ? '${(v/1000000).toStringAsFixed(1)}M' : v >= 1000 ? '${(v/1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);