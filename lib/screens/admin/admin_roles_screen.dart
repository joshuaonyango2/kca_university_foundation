// lib/screens/admin/admin_roles_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../models/role_model.dart';
import '../../providers/staff_provider.dart';
import '../../services/permission_service.dart';
import 'widgets/admin_layout.dart';

// ── Brand tokens ──────────────────────────────────────────────────────────────
class _KCA {
  static const navy  = Color(0xFF1B2263);
  static const gold  = Color(0xFFF5A800);
  static const white = Colors.white;
  static const bg    = Color(0xFFF0F2F8);
  static const green = Color(0xFF10B981);
}

// ── Permission group colours ──────────────────────────────────────────────────
Color _groupColor(String group) {
  switch (group) {
    case 'Campaigns':      return const Color(0xFF2563EB);
    case 'Donors':         return const Color(0xFF10B981);
    case 'Reports':        return const Color(0xFFF59E0B);
    case 'Administration': return const Color(0xFFEF4444);
    default:               return _KCA.navy;
  }
}

IconData _groupIcon(String group) {
  switch (group) {
    case 'Campaigns':      return Icons.campaign_outlined;
    case 'Donors':         return Icons.people_outline;
    case 'Reports':        return Icons.bar_chart_outlined;
    case 'Administration': return Icons.admin_panel_settings_outlined;
    default:               return Icons.dashboard_outlined;
  }
}

// ── Role templates (quick-start presets for common titles) ────────────────────
class _RoleTemplate {
  final String     name;
  final String     description;
  final IconData   icon;
  final List<String> permissions;
  const _RoleTemplate(this.name, this.description, this.icon, this.permissions);
}

final _kTemplates = [
  _RoleTemplate(
    'CEO',
    'Chief Executive Officer — full strategic oversight of the Foundation.',
    Icons.business_center_outlined,
    Permission.values.map((p) => p.key).toList(),
  ),
  _RoleTemplate(
    'CFO',
    'Chief Financial Officer — financial reporting and transaction oversight.',
    Icons.account_balance_outlined,
    [
      Permission.viewDashboard.key,
      Permission.viewCampaigns.key,
      Permission.viewDonors.key,
      Permission.viewTransactions.key,
      Permission.exportData.key,
    ],
  ),
  _RoleTemplate(
    'Fundraising Officer',
    'Manages active campaigns and donor outreach.',
    Icons.volunteer_activism_outlined,
    [
      Permission.viewDashboard.key,
      Permission.viewCampaigns.key,
      Permission.manageCampaigns.key,
      Permission.viewDonors.key,
      Permission.manageDonors.key,
      Permission.exportData.key,
    ],
  ),
  _RoleTemplate(
    'Communications Manager',
    'Handles donor engagement and public communications.',
    Icons.campaign_outlined,
    [
      Permission.viewDashboard.key,
      Permission.viewCampaigns.key,
      Permission.viewDonors.key,
      Permission.manageDonors.key,
      Permission.exportData.key,
    ],
  ),
  _RoleTemplate(
    'Data Analyst',
    'Read-only access to reports, transactions and donor data.',
    Icons.analytics_outlined,
    [
      Permission.viewDashboard.key,
      Permission.viewCampaigns.key,
      Permission.viewDonors.key,
      Permission.viewTransactions.key,
      Permission.exportData.key,
    ],
  ),
  _RoleTemplate(
    'HR Manager',
    'Manages staff records and role assignments.',
    Icons.badge_outlined,
    [
      Permission.viewDashboard.key,
      Permission.manageStaff.key,
      Permission.manageRoles.key,
    ],
  ),
];

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class AdminRolesScreen extends StatelessWidget {
  const AdminRolesScreen({super.key});

  void _openCreate(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _RoleFormDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Roles & Permissions',
      activeRoute: AppRoutes.adminRoles,
      actions: [
        // Templates quick-add button
        OutlinedButton.icon(
          onPressed: () => _showTemplates(context),
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: const Text('Templates'),
          style: OutlinedButton.styleFrom(
              foregroundColor: _KCA.navy,
              side: BorderSide(color: _KCA.navy.withAlpha(80)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
        ),
        const SizedBox(width: 10),
        if (context.watch<StaffProvider>().canDo(Permission.manageRoles))
          ElevatedButton.icon(
            onPressed: () => _openCreate(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Role'),
            style: ElevatedButton.styleFrom(
                backgroundColor: _KCA.navy,
                foregroundColor: _KCA.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
          ),
      ],
      child: StreamBuilder<List<RoleModel>>(
        stream: context.read<StaffProvider>().rolesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(_KCA.navy)));
          }

          final roles = snapshot.data ?? [];

          if (roles.isEmpty) {
            return _EmptyState(onSeed: () =>
                context.read<StaffProvider>().bootstrapRoles());
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: roles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) => _RoleCard(
              role: roles[i],
              onEdit: () => showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => _RoleFormDialog(role: roles[i]),
              ),
              onDelete: () {
                if (!context.read<StaffProvider>().canDo(Permission.manageRoles)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('You need Manage Roles permission to delete roles.'),
                      backgroundColor: Colors.red));
                  return;
                }
                _confirmDelete(context, roles[i]);
              },
            ),
          );
        },
      ),
    );
  }

  // ── Template picker sheet ──────────────────────────────────────────────────
  void _showTemplates(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplatesSheet(parentContext: context),
    );
  }

  // ── Delete confirmation with live staff count ──────────────────────────────
  void _confirmDelete(BuildContext context, RoleModel role) async {
    // Check how many staff are assigned
    final snap = await FirebaseFirestore.instance
        .collection('staff')
        .where('role_id', isEqualTo: role.id)
        .get();
    final count = snap.docs.length;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 22)),
          const SizedBox(width: 12),
          const Text('Delete Role',
              style: TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  children: [
                    const TextSpan(text: 'You are about to delete '),
                    TextSpan(text: '"${role.name}"',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const TextSpan(text: '.'),
                  ])),
              const SizedBox(height: 14),
              if (count > 0) ...[
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200)),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                          '$count staff member${count > 1 ? 's are' : ' is'} '
                              'currently assigned to this role. '
                              'Reassign them before deleting.',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.red))),
                    ])),
                const SizedBox(height: 8),
              ] else ...[
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200)),
                    child: const Row(children: [
                      Icon(Icons.check_circle_outline,
                          color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Text('No staff are assigned to this role.',
                          style: TextStyle(fontSize: 12, color: Colors.green)),
                    ])),
                const SizedBox(height: 8),
              ],
              if (role.isDefault)
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300)),
                    child: const Row(children: [
                      Icon(Icons.info_outline,
                          color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                          'This is a built-in default role.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.amber))),
                    ])),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: count > 0
                  ? null   // disabled — must reassign staff first
                  : () async {
                Navigator.pop(ctx);
                final ok = await context
                    .read<StaffProvider>()
                    .deleteRole(role.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? '✓ "${role.name}" deleted'
                      : context
                      .read<StaffProvider>()
                      .error ??
                      'Delete failed'),
                  backgroundColor:
                  ok ? _KCA.green : Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200),
              child: const Text('Delete',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onSeed;
  const _EmptyState({required this.onSeed});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.badge_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No roles yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[400])),
          const SizedBox(height: 8),
          Text('Create your first role or load the built-in defaults.',
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton.icon(
                onPressed: onSeed,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Load Defaults'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: _KCA.navy,
                    side: const BorderSide(color: _KCA.navy))),
            const SizedBox(width: 12),
            ElevatedButton.icon(
                onPressed: () => showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const _RoleFormDialog()),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create Role'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _KCA.navy,
                    foregroundColor: _KCA.white)),
          ]),
        ]));
  }
}

// ── Templates bottom sheet ────────────────────────────────────────────────────
class _TemplatesSheet extends StatelessWidget {
  final BuildContext parentContext;
  const _TemplatesSheet({required this.parentContext});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        // Header
        Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _KCA.gold.withAlpha(30),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.auto_awesome,
                  color: _KCA.navy, size: 20)),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Role Templates',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: _KCA.navy)),
                Text('Pick a template to pre-fill the form',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
        ]),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        // Template list
        ...(_kTemplates.map((t) => ListTile(
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 4, vertical: 4),
          leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: _KCA.navy.withAlpha(12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(t.icon, color: _KCA.navy, size: 22)),
          title: Text(t.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _KCA.navy)),
          subtitle: Text(t.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          trailing: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: _KCA.navy.withAlpha(12),
                  borderRadius: BorderRadius.circular(6)),
              child: Text('${t.permissions.length} perms',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _KCA.navy))),
          onTap: () {
            Navigator.pop(context);
            showDialog(
              context: parentContext,
              barrierDismissible: false,
              builder: (_) => _RoleFormDialog(template: t),
            );
          },
        ))),
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 4),
        TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              showDialog(
                context: parentContext,
                barrierDismissible: false,
                builder: (_) => const _RoleFormDialog(),
              );
            },
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Start from scratch instead'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey)),
      ]),
    );
  }
}

// ── Role card ─────────────────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final RoleModel  role;
  final VoidCallback onEdit, onDelete;
  const _RoleCard({
    required this.role,
    required this.onEdit,
    required this.onDelete});

  @override
  Widget build(BuildContext context) {
    // Group permissions for display
    final groups = <String, List<Permission>>{};
    for (final p in role.permissionObjects) {
      groups.putIfAbsent(p.group, () => []).add(p);
    }

    return Container(
      decoration: BoxDecoration(
          color: _KCA.white,
          borderRadius: BorderRadius.circular(16),
          border: role.isDefault
              ? Border.all(color: _KCA.gold.withAlpha(120), width: 1.5)
              : Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────────
            Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                decoration: BoxDecoration(
                    color: role.isDefault ? _KCA.navy : _KCA.bg,
                    borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16))),
                child: Row(children: [
                  // Icon
                  Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: role.isDefault
                              ? _KCA.gold
                              : _KCA.gold.withAlpha(40),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.badge_outlined,
                          color: _KCA.navy, size: 22)),
                  const SizedBox(width: 14),
                  // Name + description
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(child: Text(role.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: role.isDefault
                                      ? _KCA.white
                                      : _KCA.navy))),
                          if (role.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                    color: _KCA.gold,
                                    borderRadius: BorderRadius.circular(4)),
                                child: const Text('DEFAULT',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: _KCA.navy,
                                        letterSpacing: 0.5))),
                          ],
                        ]),
                        const SizedBox(height: 3),
                        Text(role.description,
                            style: TextStyle(
                                fontSize: 12,
                                color: role.isDefault
                                    ? Colors.white60
                                    : Colors.grey[500]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ])),
                  // Perm count badge
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: role.isDefault
                              ? Colors.white.withAlpha(20)
                              : _KCA.navy.withAlpha(12),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(
                          '${role.permissions.length} perms',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: role.isDefault
                                  ? Colors.white70
                                  : _KCA.navy))),
                  const SizedBox(width: 4),
                  // Actions menu
                  PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          color: role.isDefault
                              ? Colors.white70
                              : Colors.grey[500]),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onSelected: (v) {
                        if (v == 'edit')   onEdit();
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit_outlined,
                                  size: 18, color: _KCA.navy),
                              SizedBox(width: 10),
                              Text('Edit Role'),
                            ])),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 10),
                              Text('Delete Role',
                                  style: TextStyle(color: Colors.red)),
                            ])),
                      ]),
                ])),

            // ── Permissions body ─────────────────────────────────────────────────
            Padding(
                padding: const EdgeInsets.all(16),
                child: groups.isEmpty
                    ? const Text('No permissions assigned',
                    style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                        fontSize: 13))
                    : Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: groups.entries.map((entry) {
                      final color = _groupColor(entry.key);
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Group label with icon
                            Row(mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_groupIcon(entry.key),
                                      size: 13, color: color),
                                  const SizedBox(width: 4),
                                  Text(entry.key.toUpperCase(),
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                          letterSpacing: 0.8)),
                                ]),
                            const SizedBox(height: 6),
                            Wrap(
                                spacing: 5,
                                runSpacing: 4,
                                children: entry.value.map((p) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: color.withAlpha(18),
                                      borderRadius:
                                      BorderRadius.circular(6),
                                      border: Border.all(
                                          color: color.withAlpha(70))),
                                  child: Text(p.label,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: color,
                                          fontWeight:
                                          FontWeight.w600)),
                                )).toList()),
                          ]);
                    }).toList())),

            // ── Live staff count ─────────────────────────────────────────────────
            StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('staff')
                    .where('role_id', isEqualTo: role.id)
                    .where('is_active', isEqualTo: true)
                    .snapshots(),
                builder: (ctx, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                          color: _KCA.bg,
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(16))),
                      child: Row(children: [
                        Icon(Icons.people_outline,
                            size: 14,
                            color: count > 0 ? _KCA.navy : Colors.grey[400]),
                        const SizedBox(width: 6),
                        Text(
                            count == 0
                                ? 'No staff assigned'
                                : '$count staff member${count > 1 ? 's' : ''} assigned',
                            style: TextStyle(
                                fontSize: 12,
                                color: count > 0
                                    ? _KCA.navy
                                    : Colors.grey[400],
                                fontWeight: count > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal)),
                        const Spacer(),
                        // Quick action buttons
                        TextButton.icon(
                            onPressed: () => showDialog(
                              context: ctx,
                              barrierDismissible: false,
                              builder: (_) => _RoleFormDialog(role: role),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 14),
                            label: const Text('Edit'),
                            style: TextButton.styleFrom(
                                foregroundColor: _KCA.navy,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                textStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600))),
                      ]));
                }),
          ]),
    );
  }
}


// ── Permission group tile (extracted to avoid spread+block-body lint) ─────────
class _PermGroupTile extends StatelessWidget {
  final String             groupName;
  final List<Permission>   perms;
  final Set<String>        selected;
  final ValueChanged<bool> onToggleAll;
  final void Function(String key, bool on) onToggleOne;

  const _PermGroupTile({
    required this.groupName,
    required this.perms,
    required this.selected,
    required this.onToggleAll,
    required this.onToggleOne,
  });

  @override
  Widget build(BuildContext context) {
    final color      = _groupColor(groupName);
    final allChecked = perms.every((p) => selected.contains(p.key));
    final anyChecked = perms.any((p)  => selected.contains(p.key));
    final selCount   = perms.where((p) => selected.contains(p.key)).length;

    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            border: Border.all(
                color: anyChecked ? color.withAlpha(80) : Colors.grey[200]!),
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          // Group header row — tap toggles entire group
          InkWell(
              onTap: () => onToggleAll(allChecked),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                      color: anyChecked ? color.withAlpha(15) : _KCA.bg,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12))),
                  child: Row(children: [
                    Icon(_groupIcon(groupName), color: color, size: 18),
                    const SizedBox(width: 8),
                    Text(groupName,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: color)),
                    const Spacer(),
                    Text(
                        allChecked
                            ? 'Deselect all'
                            : anyChecked
                            ? '$selCount/${perms.length} selected'
                            : 'Select all',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    const SizedBox(width: 4),
                    Icon(
                        allChecked
                            ? Icons.check_box
                            : anyChecked
                            ? Icons.indeterminate_check_box
                            : Icons.check_box_outline_blank,
                        color: allChecked || anyChecked ? color : Colors.grey[400],
                        size: 20),
                  ]))),
          // Individual checkboxes
          ...perms.map((p) => CheckboxListTile(
              value: selected.contains(p.key),
              onChanged: (v) => onToggleOne(p.key, v ?? false),
              title: Text(p.label,
                  style: const TextStyle(fontSize: 13)),
              secondary: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: selected.contains(p.key)
                          ? color.withAlpha(18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6)),
                  child: Icon(_groupIcon(p.group),
                      color: selected.contains(p.key)
                          ? color
                          : Colors.grey[400],
                      size: 16)),
              activeColor: color,
              dense: true,
              controlAffinity: ListTileControlAffinity.trailing)),
        ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ROLE FORM DIALOG — create / edit / from template
// ══════════════════════════════════════════════════════════════════════════════
class _RoleFormDialog extends StatefulWidget {
  final RoleModel?       role;       // non-null → edit mode
  final _RoleTemplate?   template;   // non-null → pre-fill from template
  const _RoleFormDialog({this.role, this.template});

  @override
  State<_RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<_RoleFormDialog> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _selected = <String>{};
  bool _isLoading = false;

  bool get _isEdit => widget.role != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      // Edit mode — populate from existing role
      _nameCtrl.text = widget.role!.name;
      _descCtrl.text = widget.role!.description;
      _selected.addAll(widget.role!.permissions);
    } else if (widget.template != null) {
      // Template mode — pre-fill name, description and permissions
      _nameCtrl.text = widget.template!.name;
      _descCtrl.text = widget.template!.description;
      _selected.addAll(widget.template!.permissions);
    } else {
      // New blank role — default to view dashboard
      _selected.add(Permission.viewDashboard.key);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Assign at least one permission'),
          backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);

    final provider = context.read<StaffProvider>();
    bool ok;

    if (_isEdit) {
      ok = await provider.updateRole(widget.role!.copyWith(
        name:        _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        permissions: _selected.toList(),
      ));
    } else {
      ok = await provider.createRole(RoleModel(
        id:          '',
        name:        _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        permissions: _selected.toList(),
        createdAt:   DateTime.now(),
      ));
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text(_isEdit
              ? '✓ "${_nameCtrl.text.trim()}" updated'
              : '✓ "${_nameCtrl.text.trim()}" created'),
        ]),
        backgroundColor: _KCA.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.error ?? 'Failed to save role'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ── Select / deselect all in a group ──────────────────────────────────────
  void _toggleGroup(List<Permission> perms, bool allSelected) {
    setState(() {
      if (allSelected) {
        for (final p in perms) { _selected.remove(p.key); }
      } else {
        for (final p in perms) { _selected.add(p.key); }
      }
    });
  }

  // ── Select all / none ─────────────────────────────────────────────────────
  void _selectAll() => setState(() =>
      _selected.addAll(Permission.values.map((p) => p.key)));
  void _clearAll()  => setState(() => _selected.clear());

  // All permissions can be assigned to a role, but that still does not make
  // the user a "super admin". Super-admin status is a Firestore-level
  // protection flag (is_super_admin: true) that is set only for
  // admin@kca.ac.ke / foundation@kca.ac.ke by PermissionService at login.
  // No action in this screen can create another super-admin.
  static const _kNoSuperAdminNote =
      'Assigning all permissions to a role gives that role holder full '
      'operational access. It does not grant super-admin status — protected '
      'system accounts cannot be modified by any role, including this one.';

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _KCA.navy, size: 20),
      filled: true,
      fillColor: _KCA.bg,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _KCA.navy, width: 2)),
      labelStyle: const TextStyle(color: _KCA.navy));

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Permission>>{};
    for (final p in Permission.values) {
      groups.putIfAbsent(p.group, () => []).add(p);
    }
    final totalSelected = _selected.length;
    final totalPerms    = Permission.values.length;
    final allSelected   = totalSelected == totalPerms;

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(
            maxWidth: 600, maxHeight: 740),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Header ─────────────────────────────────────────────────────────
          Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              decoration: const BoxDecoration(
                  color: _KCA.navy,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20))),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: _KCA.gold,
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(
                        _isEdit ? Icons.edit_outlined : Icons.add_circle_outline,
                        color: _KCA.navy, size: 20)),
                const SizedBox(width: 14),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          _isEdit
                              ? 'Edit Role'
                              : widget.template != null
                              ? 'New Role from Template'
                              : 'Create New Role',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text(
                          _isEdit
                              ? 'Update name, description and permissions'
                              : 'Define what this role can access',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11)),
                    ])),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context)),
              ])),

          // ── Form ───────────────────────────────────────────────────────────
          Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(key: _formKey, child: Builder(builder: (context) {
                // Build permission group tiles first — avoids for-loop inside children[]
                final permGroupWidgets = groups.entries.map<Widget>((entry) =>
                    _PermGroupTile(
                      groupName:   entry.key,
                      perms:       entry.value,
                      selected:    _selected,
                      onToggleAll: (all) => _toggleGroup(entry.value, all),
                      onToggleOne: (key, on) => setState(() {
                        if (on) { _selected.add(key); } else { _selected.remove(key); }
                      }),
                    )).toList();

                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Name
                      TextFormField(
                          controller: _nameCtrl,
                          decoration: _dec('Role Name', Icons.badge_outlined),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Role name is required'
                              : null),
                      const SizedBox(height: 14),

                      // Description
                      TextFormField(
                          controller: _descCtrl,
                          maxLines: 2,
                          decoration: _dec(
                              'Description', Icons.description_outlined),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Description is required'
                              : null),
                      const SizedBox(height: 22),

                      // Permissions header
                      Row(children: [
                        const Text('Permissions',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: _KCA.navy)),
                        const Spacer(),
                        // Counter badge
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: _KCA.navy.withAlpha(12),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text('$totalSelected / $totalPerms selected',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _KCA.navy))),
                        const SizedBox(width: 8),
                        // Select all / clear
                        TextButton(
                            onPressed: totalSelected == totalPerms
                                ? _clearAll
                                : _selectAll,
                            style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                minimumSize: Size.zero),
                            child: Text(
                                totalSelected == totalPerms
                                    ? 'Clear all'
                                    : 'Select all',
                                style: const TextStyle(
                                    fontSize: 12, color: _KCA.navy))),
                      ]),
                      const SizedBox(height: 12),

                      // Permission groups
                      ...permGroupWidgets,
                    ]);
              })))),

          // ── Footer ─────────────────────────────────────────────────────────
          Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
              decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(color: Color(0xFFEEEEEE)))),
              child: Row(children: [
                Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _KCA.navy,
                        foregroundColor: _KCA.white,
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: _isLoading
                        ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                                _KCA.white)))
                        : Row(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Icon(
                              _isEdit
                                  ? Icons.save_outlined
                                  : Icons.add_circle_outline,
                              size: 18),
                          const SizedBox(width: 8),
                          Text(
                              _isEdit ? 'Save Changes' : 'Create Role',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ]))),
              ])),
        ]),
      ),
    );
  }
}