// lib/screens/admin/admin_settings_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../models/role_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/staff_provider.dart';
import 'widgets/admin_layout.dart';
import '../../services/category_service.dart';
import '../../services/donor_type_service.dart';
import '../../services/payment_method_service.dart';
import '../../services/permission_service.dart';
import '../../services/donation_amount_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _navy  = Color(0xFF1B2263);
const _gold  = Color(0xFFF5A800);
const _bg    = Color(0xFFF0F2F8);
const _green = Color(0xFF10B981);

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});
  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StaffProvider>().bootstrapRoles();
      CategoryService.seedIfEmpty();
      DonorTypeService.seedIfEmpty();
      PaymentMethodService.seedIfEmpty();
    });
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  void _showAddAdminDialog(BuildContext context) {
    // Capture providers BEFORE opening dialog — dialog route context is isolated
    final staffProv = context.read<StaffProvider>();
    final authProv  = context.read<AuthProvider>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddAdminDialog(staffProvider: staffProv, authProvider: authProv),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Settings',
      activeRoute: AppRoutes.adminSettings,
      child: Column(children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            labelColor: _navy,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _gold,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.admin_panel_settings_outlined, size: 18), text: 'Admins'),
              Tab(icon: Icon(Icons.person_outlined, size: 18),               text: 'My Profile'),
              Tab(icon: Icon(Icons.lock_outline, size: 18),                  text: 'Change Password'),
              Tab(icon: Icon(Icons.category_outlined, size: 18),              text: 'Categories'),
              Tab(icon: Icon(Icons.people_alt_outlined, size: 18),             text: 'Donor Types'),
              Tab(icon: Icon(Icons.attach_money, size: 18),                    text: 'Amounts'),
            ],
          ),
        ),
        Expanded(child: TabBarView(
          controller: _tabs,
          children: [
            _AdminsTab(onAddAdmin: () => _showAddAdminDialog(context)),
            const _ProfileTab(),
            const _PasswordTab(),
            _CategoriesTabWithPerms(
                canManage: context.read<StaffProvider>().canDo(Permission.manageCategories)),
            _DonorTypesTabWithPerms(
                canManage: context.read<StaffProvider>().canDo(Permission.manageDonorTypes)),
            _DonationAmountsTabWithPerms(
                canManage: context.read<StaffProvider>().canDo(Permission.managePaymentMethods)),
          ],
        )),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 1 — ADMINS MANAGEMENT
// ═════════════════════════════════════════════════════════════════════════════
class _AdminsTab extends StatefulWidget {
  final VoidCallback onAddAdmin;
  const _AdminsTab({required this.onAddAdmin});
  @override
  State<_AdminsTab> createState() => _AdminsTabState();
}

class _AdminsTabState extends State<_AdminsTab> {
  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        color: _bg,
        child: Row(children: [
          const Icon(Icons.group, color: _navy, size: 20),
          const SizedBox(width: 10),
          const Text('Admin & Staff Accounts',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: widget.onAddAdmin,
            icon: const Icon(Icons.person_add_outlined, size: 17),
            label: const Text('Add Admin / Staff'),
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: _db.collection('staff').orderBy('created_at', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _navy));
            }
            if (snapshot.hasError) {
              return Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Firestore error: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                  ])));
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.group_outlined, size: 56, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No staff added yet', style: TextStyle(color: Colors.grey[400], fontSize: 15)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                    onPressed: widget.onAddAdmin,
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Add First Admin'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _navy, foregroundColor: Colors.white)),
              ]));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                data['id'] = docs[i].id;
                final cardEmail = data['email'] as String? ?? '';
                final isSA = PermissionService.isSuperAdminEmail(cardEmail);
                return _AdminCard(
                  data:              data,
                  isSuperAdmin:      isSA,
                  onViewTempPassword: () => _showTempPassword(context, data),
                  onEdit:            () {
                    if (isSA) { _showProtectedWarning(context); return; }
                    _showEditDialog(context, data);
                  },
                  onPassword:     () => _showResetPasswordDialog(context, cardEmail),
                  onToggleAdmin:  () {
                    if (isSA) { _showProtectedWarning(context); return; }
                    _toggleAdmin(data['id'] as String, data['is_admin'] as bool? ?? false, context);
                  },
                  onDeactivate:   () {
                    if (isSA) { _showProtectedWarning(context); return; }
                    _toggleActive(data['id'] as String, data['is_active'] as bool? ?? true);
                  },
                  onDelete:       () {
                    if (isSA) { _showProtectedWarning(context); return; }
                    _confirmDelete(context, data);
                  },
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Future<void> _toggleAdmin(String id, bool current, BuildContext ctx) async {
    // Only someone with grantAdmin permission may change is_admin flag
    if (!context.read<StaffProvider>().canDo(Permission.grantAdmin)) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text('You need "Grant / Revoke Admin Access" permission to do this.'),
          backgroundColor: Colors.red));
      return;
    }
    await _db.collection('staff').doc(id).update({'is_admin': !current});
  }

  Future<void> _toggleActive(String id, bool current) async {
    await _db.collection('staff').doc(id).update({'is_active': !current});
  }

  void _showTempPassword(BuildContext ctx, Map<String, dynamic> data) {
    final name    = data['name']          as String? ?? 'Staff';
    final tempPwd = data['temp_password'] as String? ?? '';
    final isSA    = PermissionService.isSuperAdminEmail(
        FirebaseAuth.instance.currentUser?.email);
    if (!isSA && !context.read<StaffProvider>().canDo(Permission.manageStaff)) {
      _showProtectedWarning(ctx);
      return;
    }
    showDialog(context: ctx, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        const Icon(Icons.lock_open_outlined, color: _navy),
        const SizedBox(width: 10),
        Text('Temp Password — $name',
            style: const TextStyle(fontSize: 15, color: _navy,
                fontWeight: FontWeight.bold)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: _bg, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  tempPwd.isEmpty ? '(Not available — password was set manually)' : tempPwd,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      fontFamily: 'monospace', letterSpacing: 2),
                )),
            const SizedBox(height: 12),
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withAlpha(60))),
                child: const Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                          'This password is only visible until the user changes it. '
                              'Once changed, this view will no longer be available.',
                          style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.4))),
                    ])),
          ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Close')),
      ],
    ));
  }

  void _showProtectedWarning(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
      content: Row(children: [
        Icon(Icons.lock_outlined, color: Colors.white, size: 16),
        SizedBox(width: 8),
        Expanded(child: Text(
            'This is a protected super-admin account and cannot be modified.',
            style: TextStyle(fontSize: 13))),
      ]),
      backgroundColor: Color(0xFF1B2263),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(context: context, barrierDismissible: false,
        builder: (_) => _EditAdminDialog(data: data));
  }

  void _showResetPasswordDialog(BuildContext context, String email) {
    showDialog(context: context, builder: (_) => _ResetPasswordDialog(email: email));
  }

  void _confirmDelete(BuildContext context, Map<String, dynamic> data) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Remove Account', style: TextStyle(color: Colors.red)),
      content: Text('Remove ${data['name']} from the system?\n\n'
          'This removes their staff record. Their Firebase Auth account '
          'must be deleted separately from the Firebase Console.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _db.collection('staff').doc(data['id'] as String).delete();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${data['name']} removed'),
                      backgroundColor: Colors.red));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white))),
      ],
    ));
  }
}

// ── Admin card ────────────────────────────────────────────────────────────────
class _AdminCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool                 isSuperAdmin;
  final VoidCallback onEdit, onPassword, onToggleAdmin, onDeactivate, onDelete;

  final VoidCallback onViewTempPassword;
  const _AdminCard({
    required this.data,
    required this.isSuperAdmin,
    required this.onEdit,
    required this.onPassword,
    required this.onToggleAdmin,
    required this.onDeactivate,
    required this.onDelete,
    required this.onViewTempPassword,
  });

  @override
  Widget build(BuildContext context) {
    final name      = data['name'] as String? ?? 'Unknown';
    final email     = data['email'] as String? ?? '';
    final roleName  = data['role_name'] as String? ?? 'Staff';
    final isAdmin   = data['is_admin'] as bool? ?? false;
    final isActive  = data['is_active'] as bool? ?? true;
    final isPending = data['pending_uid'] as bool? ?? false;
    final initials  = name.isNotEmpty
        ? name.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join()
        : 'S';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: isAdmin ? Border.all(color: _gold.withAlpha(180), width: 1.5) : null,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Row(children: [
        Stack(children: [
          CircleAvatar(radius: 26,
              backgroundColor: isActive ? _navy : Colors.grey[400]!,
              child: Text(initials, style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 16))),
          if (isAdmin) Positioned(right: 0, bottom: 0,
              child: Container(width: 16, height: 16,
                  decoration: BoxDecoration(color: _gold, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5)),
                  child: const Icon(Icons.star, size: 9, color: _navy))),
        ]),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(name,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                    color: isActive ? _navy : Colors.grey),
                overflow: TextOverflow.ellipsis)),
            if (isSuperAdmin) ...[const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF1B2263), Color(0xFF2D3A9C)]),
                      borderRadius: BorderRadius.all(Radius.circular(4))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.shield_outlined, size: 9, color: Colors.white),
                    SizedBox(width: 3),
                    Text('SUPER ADMIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                  ]))
            ] else if (isAdmin) ...[const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(4)),
                  child: const Text('ADMIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _navy)))],
            if (isPending) ...[const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                  child: const Text('PENDING LOGIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)))],
          ]),
          const SizedBox(height: 2),
          Text(email, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 5),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _navy.withAlpha(15), borderRadius: BorderRadius.circular(6)),
                child: Text(roleName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _navy))),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: isActive ? _green.withAlpha(25) : Colors.grey.withAlpha(20),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(isActive ? 'Active' : 'Inactive',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                        color: isActive ? _green : Colors.grey))),
          ]),
        ])),
        Tooltip(
            message: (data['permissions'] as List? ?? []).cast<String>()
                .map((p) => PermissionExt.fromKey(p)?.label ?? p).join('\n'),
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: Colors.blue.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                child: Text('${(data['permissions'] as List? ?? []).length} perms',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue)))),
        const SizedBox(width: 6),
        PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[400]),
            onSelected: (v) {
              if (v == 'edit')        onEdit();
              if (v == 'password')    onPassword();
              if (v == 'admin')       onToggleAdmin();
              if (v == 'deactivate')  onDeactivate();
              if (v == 'delete')      onDelete();
              if (v == 'view_pw')     onViewTempPassword();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'password',
                  child: Row(children: [Icon(Icons.lock_reset_outlined, size: 18),
                    SizedBox(width: 8), Text('Reset Password')])),
              if ((data['is_password_changed'] as bool? ?? true) == false)
                PopupMenuItem(value: 'view_pw',
                    child: Row(children: [
                      const Icon(Icons.visibility_outlined, size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text('View Temp Password',
                          style: TextStyle(color: Colors.orange)),
                    ])),
              if (!isSuperAdmin) ...[
                const PopupMenuItem(value: 'edit',
                    child: Row(children: [Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8), Text('Edit Profile & Role')])),
                PopupMenuItem(value: 'admin', child: Row(children: [
                  Icon(isAdmin ? Icons.remove_moderator_outlined
                      : Icons.admin_panel_settings_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(isAdmin ? 'Revoke Admin Access' : 'Grant Admin Access')])),
                PopupMenuItem(value: 'deactivate', child: Row(children: [
                  Icon(isActive ? Icons.person_off_outlined : Icons.person_outlined,
                      size: 18),
                  const SizedBox(width: 8),
                  Text(isActive ? 'Deactivate' : 'Activate')])),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'delete', child: Row(children: [
                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Remove', style: TextStyle(color: Colors.red))])),
              ] else ...[
                const PopupMenuItem(
                  enabled: false,
                  child: Row(children: [
                    Icon(Icons.lock_outlined, size: 18, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Protected Account',
                        style: TextStyle(color: Colors.grey, fontSize: 13))]),
                ),
              ],
            ]),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2 — MY PROFILE
// ═════════════════════════════════════════════════════════════════════════════
class _ProfileTab extends StatefulWidget {
  const _ProfileTab();
  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl.text  = user?.name ?? '';
    _phoneCtrl.text = user?.phoneNumber ?? '';
  }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final staffDoc = await FirebaseFirestore.instance.collection('staff').doc(uid).get();
        if (staffDoc.exists) {
          await FirebaseFirestore.instance.collection('staff').doc(uid).update({
            'name': _nameCtrl.text.trim(), 'phone': _phoneCtrl.text.trim()});
        }
        await FirebaseAuth.instance.currentUser?.updateDisplayName(_nameCtrl.text.trim());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully'), backgroundColor: _green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final user     = auth.user;
    final initials = user?.initials ?? 'A';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Column(children: [
              CircleAvatar(radius: 48, backgroundColor: _navy,
                  child: Text(initials, style: const TextStyle(color: _gold, fontSize: 32, fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),
              Text(user?.name ?? 'Admin',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: _navy)),
              Text(user?.email ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              const SizedBox(height: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(20)),
                  child: const Text('Admin', style: TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 12))),
            ])),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))]),
              child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navy)),
                const SizedBox(height: 20),
                _field(_nameCtrl, 'Full Name', Icons.person_outline,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null),
                const SizedBox(height: 14),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.email_outlined, color: _navy, size: 20),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Email Address', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(user?.email ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ]),
                      const Spacer(),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.grey.withAlpha(30), borderRadius: BorderRadius.circular(6)),
                          child: const Text('Cannot change', style: TextStyle(fontSize: 10, color: Colors.grey))),
                    ])),
                const SizedBox(height: 14),
                _field(_phoneCtrl, 'Phone Number', Icons.phone_outlined, type: TextInputType.phone),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity,
                    child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: _saving
                            ? const SizedBox(height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
              ])),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text, String? Function(String?)? validator}) {
    return TextFormField(
        controller: ctrl, keyboardType: type,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: _navy),
            filled: true, fillColor: _bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _navy, width: 2)),
            labelStyle: const TextStyle(color: _navy)),
        validator: validator);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 3 — CHANGE PASSWORD
// ═════════════════════════════════════════════════════════════════════════════
class _PasswordTab extends StatefulWidget {
  const _PasswordTab();
  @override
  State<_PasswordTab> createState() => _PasswordTabState();
}

class _PasswordTabState extends State<_PasswordTab> {
  final _formKey     = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _savingPwd  = false;
  bool _obscureCur = true, _obscureNew = true, _obscureCon = true;

  @override
  void dispose() { _currentCtrl.dispose(); _newCtrl.dispose(); _confirmCtrl.dispose(); super.dispose(); }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _savingPwd = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(email: user.email!, password: _currentCtrl.text);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newCtrl.text);
      // ── Mark password changed in Firestore (staff flow) ──────────────────
      try {
        await FirebaseFirestore.instance
            .collection('staff').doc(user.uid)
            .update({
          'is_password_changed': true,
          'temp_password':       '',
          'password_changed_at': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Non-staff user (admin) — doc may not exist, ignore
      }
      _currentCtrl.clear(); _newCtrl.clear(); _confirmCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully'), backgroundColor: _green));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'wrong-password' ? 'Current password is incorrect.'
          : e.code == 'weak-password' ? 'New password is too weak.'
          : 'Error: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _savingPwd = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))]),
            child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _navy.withAlpha(15), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.lock_outline, color: _navy)),
                const SizedBox(width: 12),
                const Text('Change Password',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: _navy)),
              ]),
              const SizedBox(height: 8),
              Text('Enter your current password before setting a new one.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 24),
              _pwdField(_currentCtrl, 'Current Password', _obscureCur,
                      () => setState(() => _obscureCur = !_obscureCur),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 14),
              _pwdField(_newCtrl, 'New Password', _obscureNew,
                      () => setState(() => _obscureNew = !_obscureNew),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 8) return 'Must be at least 8 characters';
                    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Must contain an uppercase letter';
                    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Must contain a number';
                    return null;
                  }),
              const SizedBox(height: 14),
              _pwdField(_confirmCtrl, 'Confirm New Password', _obscureCon,
                      () => setState(() => _obscureCon = !_obscureCon),
                  validator: (v) => v != _newCtrl.text ? 'Passwords do not match' : null),
              const SizedBox(height: 8),
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Requirements:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _navy)),
                    const SizedBox(height: 6),
                    ...[
                      ['At least 8 characters',     _newCtrl.text.length >= 8],
                      ['One uppercase letter (A–Z)', RegExp(r'[A-Z]').hasMatch(_newCtrl.text)],
                      ['One number (0–9)',            RegExp(r'[0-9]').hasMatch(_newCtrl.text)],
                    ].map((r) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(children: [
                          Icon(r[1] as bool ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 14, color: r[1] as bool ? _green : Colors.grey[400]),
                          const SizedBox(width: 6),
                          Text(r[0] as String,
                              style: TextStyle(fontSize: 12, color: r[1] as bool ? _green : Colors.grey[500])),
                        ]))),
                  ])),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity,
                  child: ElevatedButton(
                      onPressed: _savingPwd ? null : _changePassword,
                      style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _savingPwd
                          ? const SizedBox(height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
            ])),
          ),
        ),
      ),
    );
  }

  Widget _pwdField(TextEditingController ctrl, String label, bool obscure, VoidCallback toggle,
      {String? Function(String?)? validator}) {
    return TextFormField(
        controller: ctrl, obscureText: obscure,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
            labelText: label, prefixIcon: const Icon(Icons.lock_outline, color: _navy),
            suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: Colors.grey[500]),
                onPressed: toggle),
            filled: true, fillColor: _bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _navy, width: 2)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red)),
            labelStyle: const TextStyle(color: _navy)),
        validator: validator);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ADD ADMIN DIALOG — fully self-contained with diagnostics
// ═════════════════════════════════════════════════════════════════════════════
class _AddAdminDialog extends StatefulWidget {
  final StaffProvider staffProvider;
  final AuthProvider  authProvider;
  const _AddAdminDialog({required this.staffProvider, required this.authProvider});
  @override
  State<_AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<_AddAdminDialog> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  List<RoleModel> _roles        = [];
  RoleModel?      _selectedRole;
  bool            _isAdmin      = false;
  bool            _loading      = false;
  bool            _rolesLoading = true;
  bool            _obscure      = true;
  String          _step         = '';
  String?         _inlineError;
  String?         _rulesWarning;   // soft warning — defaults loaded, rules not deployed
  String?         _diagResult;
  bool            _diagLoading  = false;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Load roles — Firestore first, fall back to built-in defaults ─────────
  Future<void> _loadRoles() async {
    if (!mounted) return;
    setState(() { _rolesLoading = true; _inlineError = null; });

    // 1. Try to seed roles into Firestore (idempotent — safe to call always)
    try {
      await widget.staffProvider.bootstrapRoles();
    } catch (_) {}

    // 2. Try to read from Firestore
    try {
      final snap = await FirebaseFirestore.instance
          .collection('roles')
          .orderBy('name')
          .get();

      if (snap.docs.isNotEmpty) {
        final roles = snap.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] = d.id;
          return RoleModel.fromJson(data);
        }).toList();
        if (mounted) setState(() { _roles = roles; _rolesLoading = false; });
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Firestore roles read failed: $e — using built-in defaults');
    }

    // 3. Firestore unavailable or empty — use hard-coded defaults so the
    //    admin can still add staff without waiting for rules to be deployed.
    if (mounted) {
      setState(() {
        _roles        = RoleModel.defaults;
        _rolesLoading = false;
        // Show a soft warning — not a hard error — since defaults loaded fine
        _rulesWarning = 'Roles loaded from built-in defaults (Firestore rules '
            'may not be deployed yet). Staff will be saved correctly — deploy '
            'your Firestore rules to persist custom roles.';
      });
    }
  }

  // ── Diagnose Firebase connection ──────────────────────────────────────────
  Future<void> _diagnose() async {
    setState(() { _diagLoading = true; _diagResult = null; });
    final result = await widget.staffProvider.testFirebaseAuthConnection();
    if (mounted) setState(() { _diagResult = result; _diagLoading = false; });
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _inlineError = null);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null) {
      setState(() => _inlineError = 'Please select a role before submitting.');
      return;
    }

    setState(() {
      _loading = true;
      _step    = 'Creating account for ${_nameCtrl.text.trim()}…';
      _inlineError = null;
    });

    // Update step message mid-way for better UX
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _loading) {
        setState(() => _step = 'Setting up role & permissions…');
      }
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _loading) {
        setState(() => _step = 'Sending invite email…');
      }
    });

    // Store temp password so super-admin can view it until staff changes it
    final tempPwd = _passCtrl.text;
    final result = await widget.staffProvider.onboardStaff(
      name:           _nameCtrl.text.trim(),
      email:          _emailCtrl.text.trim(),
      phone:          _phoneCtrl.text.trim(),
      tempPassword:   tempPwd,
      role:           _selectedRole!,
      isAdmin:        _isAdmin,
      createdByEmail: widget.authProvider.user?.email ?? '',
    );

    if (!mounted) return;
    setState(() { _loading = false; _step = ''; });

    if (result.success) {
      if (!mounted) return;
      Navigator.pop(context);
      // Show temp password to super-admin immediately after creation
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(
                '${_nameCtrl.text.trim()} added as ${_selectedRole!.name}. '
                    'Invite email sent. Temp password: $tempPwd',
                style: const TextStyle(fontWeight: FontWeight.w500))),
          ]),
          backgroundColor: _green,
          duration: const Duration(seconds: 12),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    } else {
      // Error shown INSIDE dialog — snackbars are hidden behind dialogs
      setState(() => _inlineError = result.error ?? 'An unexpected error occurred.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Header ───────────────────────────────────────────────────────
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(color: _navy,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Row(children: [
                const Icon(Icons.person_add_outlined, color: _gold, size: 22),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Add Admin / Staff Member',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('They will receive a password reset email to activate their account.',
                      style: TextStyle(color: Colors.white60, fontSize: 11)),
                ])),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: _loading ? null : () => Navigator.pop(context)),
              ])),

          // ── Scrollable form body ─────────────────────────────────────────
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
            child: Form(key: _formKey, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Step progress ─────────────────────────────────────────────
              if (_loading) ...[
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _navy.withAlpha(12),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: _navy)),
                      const SizedBox(width: 12),
                      Text(_step, style: const TextStyle(
                          color: _navy, fontSize: 13, fontWeight: FontWeight.w600)),
                    ])),
                const SizedBox(height: 12),
              ],

              // ── Inline error ──────────────────────────────────────────────
              if (_inlineError != null) ...[
                Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Could not add staff member',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13))),
                        GestureDetector(
                            onTap: () => setState(() => _inlineError = null),
                            child: const Icon(Icons.close, size: 16, color: Colors.red)),
                      ]),
                      const SizedBox(height: 6),
                      Text(_inlineError!, style: TextStyle(fontSize: 12, color: Colors.red.shade800)),
                      const SizedBox(height: 10),
                      // Diagnose button — appears alongside error
                      OutlinedButton.icon(
                          onPressed: _diagLoading ? null : _diagnose,
                          icon: _diagLoading
                              ? const SizedBox(width: 12, height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.wifi_tethering, size: 14),
                          label: Text(_diagLoading ? 'Checking…' : 'Run Firebase Diagnostics'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12))),
                    ])),
                const SizedBox(height: 4),
              ],

              // ── Diagnostic result ─────────────────────────────────────────
              if (_diagResult != null) ...[
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: _diagResult!.startsWith('✅')
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _diagResult!.startsWith('✅')
                                ? Colors.green.shade300
                                : Colors.orange.shade300)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(_diagResult!.startsWith('✅') ? Icons.check_circle : Icons.warning_amber,
                            size: 16,
                            color: _diagResult!.startsWith('✅') ? Colors.green : Colors.orange),
                        const SizedBox(width: 6),
                        const Text('Diagnostic Result',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ]),
                      const SizedBox(height: 6),
                      Text(_diagResult!, style: const TextStyle(fontSize: 12, height: 1.5)),
                    ])),
                const SizedBox(height: 12),
              ],

              // ── Rules warning (soft — defaults loaded) ────────────────────
              if (_rulesWarning != null) ...[
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.info_outline,
                          color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Using built-in roles',
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    fontSize: 12, color: Colors.amber)),
                            const SizedBox(height: 4),
                            Text(_rulesWarning!,
                                style: TextStyle(fontSize: 11,
                                    color: Colors.amber.shade800, height: 1.4)),
                            const SizedBox(height: 6),
                            Text('Run: firebase deploy --only firestore:rules',
                                style: TextStyle(fontSize: 10,
                                    fontFamily: 'monospace',
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.w600)),
                          ])),
                    ])),
                const SizedBox(height: 12),
              ],

              // ── Name ──────────────────────────────────────────────────────
              _field(_nameCtrl, 'Full Name', Icons.person_outline, required: true),
              const SizedBox(height: 12),

              // ── Email ─────────────────────────────────────────────────────
              _field(_emailCtrl, 'Work Email', Icons.email_outlined,
                  required: true, type: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  }),
              const SizedBox(height: 12),

              // ── Temporary password ────────────────────────────────────────
              TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                      labelText: 'Temporary Password',
                      prefixIcon: const Icon(Icons.lock_outline, color: _navy),
                      helperText: 'Min 6 chars. A password reset email will be sent automatically.',
                      suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: Colors.grey[500]),
                          onPressed: () => setState(() => _obscure = !_obscure)),
                      filled: true, fillColor: _bg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _navy, width: 2)),
                      labelStyle: const TextStyle(color: _navy)),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Minimum 6 characters';
                    return null;
                  }),
              const SizedBox(height: 16),

              // ── Role selector ─────────────────────────────────────────────
              const Text('Assign Role *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
              const SizedBox(height: 6),

              if (_rolesLoading)
                Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _navy)),
                      SizedBox(width: 10),
                      Text('Loading roles…', style: TextStyle(color: _navy, fontSize: 13)),
                    ]))

              else if (_roles.isEmpty)
                Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [
                        Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 18),
                        SizedBox(width: 8),
                        Text('No roles found',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13)),
                      ]),
                      const SizedBox(height: 6),
                      const Text(
                          'Default roles could not be loaded. This may be a Firestore '
                              'permissions issue. Check that admin@kca.ac.ke is listed in '
                              'the isAdmin() function in your Firestore rules.',
                          style: TextStyle(fontSize: 12, color: Colors.orange)),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                          onPressed: _loadRoles,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry Loading Roles'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange, foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12))),
                    ]))

              else
                DropdownButtonFormField<RoleModel>(
                  // Use value: (not initialValue:) to keep selection in sync with state
                    value: _selectedRole,
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.badge_outlined, color: _navy),
                        filled: true, fillColor: _bg,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _navy, width: 2)),
                        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red)),
                        hintText: 'Select a role…',
                        hintStyle: TextStyle(color: Colors.grey[500])),
                    items: _roles.map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.name, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (r) => setState(() { _selectedRole = r; _inlineError = null; }),
                    validator: (v) => v == null ? 'Please select a role' : null),

              const SizedBox(height: 12),

              // ── Permission preview for selected role ──────────────────────
              if (_selectedRole != null)
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: _navy.withAlpha(10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _navy.withAlpha(30))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.dashboard_outlined, size: 14, color: _navy),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                            'Dashboard modules for "${_selectedRole!.name}":',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold, color: _navy))),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 5,
                          children: _selectedRole!.permissionObjects.isEmpty
                              ? [Text('No permissions assigned to this role',
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]))]
                              : _selectedRole!.permissionObjects.map((p) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: _navy, borderRadius: BorderRadius.circular(5)),
                              child: Text(p.label,
                                  style: const TextStyle(fontSize: 10, color: Colors.white)))
                          ).toList()),
                    ])),

              const SizedBox(height: 14),

              // ── Admin dashboard access toggle (grantAdmin permission required) ──
              if (context.read<StaffProvider>().canDo(Permission.grantAdmin))
                Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: _isAdmin ? _gold.withAlpha(30) : _bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _isAdmin ? _gold : Colors.grey.shade300)),
                    child: Row(children: [
                      Icon(Icons.admin_panel_settings_outlined,
                          color: _isAdmin ? _navy : Colors.grey[500]),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Grant Admin Dashboard Access',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('Allows this user to access the full admin dashboard. '
                            'What they can do is still governed by their assigned permissions.',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ])),
                      Switch(
                          value: _isAdmin,
                          onChanged: (v) => setState(() => _isAdmin = v),
                          activeColor: _navy),
                    ])),
              const SizedBox(height: 6),
            ])),
          )),

          // ── Footer actions ───────────────────────────────────────────────
          Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
              child: Row(children: [
                Expanded(child: OutlinedButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: ElevatedButton(
                    onPressed: (_loading || _rolesLoading || _roles.isEmpty) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _navy, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: _loading
                        ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 10),
                      Text('Creating…'),
                    ])
                        : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.person_add_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Add & Send Invite', style: TextStyle(fontWeight: FontWeight.bold)),
                    ]))),
              ])),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool required = false,
        TextInputType type = TextInputType.text,
        String? Function(String?)? validator}) {
    return TextFormField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: _navy),
            filled: true, fillColor: _bg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _navy, width: 2)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red)),
            labelStyle: const TextStyle(color: _navy)),
        validator: validator ??
            (required ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null : null));
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EDIT ADMIN DIALOG
// ═════════════════════════════════════════════════════════════════════════════
class _EditAdminDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  const _EditAdminDialog({required this.data});
  @override
  State<_EditAdminDialog> createState() => _EditAdminDialogState();
}

class _EditAdminDialogState extends State<_EditAdminDialog> {
  final _formKey   = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  RoleModel? _role;
  bool _isAdmin  = false;
  bool _loading  = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.data['name']  as String? ?? '');
    _phoneCtrl = TextEditingController(text: widget.data['phone'] as String? ?? '');
    _isAdmin   = widget.data['is_admin'] as bool? ?? false;
  }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final update = <String, dynamic>{
        'name':     _nameCtrl.text.trim(),
        'phone':    _phoneCtrl.text.trim(),
        'is_admin': _isAdmin,
      };
      if (_role != null) {
        update['role_id']     = _role!.id;
        update['role_name']   = _role!.name;
        update['permissions'] = _role!.permissions;
      }
      await FirebaseFirestore.instance
          .collection('staff')
          .doc(widget.data['id'] as String)
          .update(update);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated'), backgroundColor: _green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: _navy,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Row(children: [
                const Icon(Icons.edit, color: _gold),
                const SizedBox(width: 12),
                Expanded(child: Text('Edit: ${widget.data['name']}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context)),
              ])),
          Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(key: _formKey, child: Column(children: [
                _f(_nameCtrl, 'Full Name', Icons.person_outline, required: true),
                const SizedBox(height: 12),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.email_outlined, color: _navy, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Email (read-only)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(widget.data['email'] as String? ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ])),
                    ])),
                const SizedBox(height: 12),
                _f(_phoneCtrl, 'Phone Number', Icons.phone_outlined, type: TextInputType.phone),
                const SizedBox(height: 12),
                StreamBuilder<List<RoleModel>>(
                    stream: context.read<StaffProvider>().rolesStream(),
                    builder: (ctx, snap) {
                      final roles        = snap.data ?? [];
                      final currentRoleId = widget.data['role_id'] as String? ?? '';
                      final currentRole  = roles.where((r) => r.id == currentRoleId).firstOrNull;
                      return DropdownButtonFormField<RoleModel>(
                          value: _role ?? currentRole,
                          decoration: InputDecoration(
                              labelText: 'Role',
                              prefixIcon: const Icon(Icons.badge_outlined, color: _navy),
                              filled: true, fillColor: _bg,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              labelStyle: const TextStyle(color: _navy)),
                          items: roles.map((r) => DropdownMenuItem(
                              value: r, child: Text(r.name, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (r) => setState(() => _role = r));
                    }),
                const SizedBox(height: 12),
                if (context.read<StaffProvider>().canDo(Permission.grantAdmin))
                  SwitchListTile(
                      value: _isAdmin,
                      onChanged: (v) => setState(() => _isAdmin = v),
                      title: const Text('Admin Dashboard Access',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                          'Allows access to the admin panel. '
                              'Actual permissions are still governed by the assigned role.',
                          style: TextStyle(fontSize: 11)),
                      activeColor: _navy,
                      tileColor: _bg,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
              ])))),
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: _loading ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: _loading
                        ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)))),
              ])),
        ]),
      ),
    );
  }

  Widget _f(TextEditingController ctrl, String label, IconData icon,
      {bool required = false, TextInputType type = TextInputType.text}) {
    return TextFormField(controller: ctrl, keyboardType: type,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: _navy),
            filled: true, fillColor: _bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _navy, width: 2)),
            labelStyle: const TextStyle(color: _navy)),
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? '$label required' : null
            : null);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// RESET PASSWORD DIALOG
// ═════════════════════════════════════════════════════════════════════════════
class _ResetPasswordDialog extends StatefulWidget {
  final String email;
  const _ResetPasswordDialog({required this.email});
  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  bool _sending = false, _sent = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final apiKey = Firebase.app().options.apiKey;
      await http.post(
          Uri.parse(
              'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'requestType': 'PASSWORD_RESET', 'email': widget.email}));
      if (mounted) setState(() { _sending = false; _sent = true; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Icon(_sent ? Icons.check_circle : Icons.lock_reset,
            color: _sent ? _green : _navy),
        const SizedBox(width: 10),
        Text(_sent ? 'Email Sent!' : 'Reset Password'),
      ]),
      content: _sent
          ? Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.mark_email_read_outlined, size: 48, color: _green),
        const SizedBox(height: 12),
        Text('A password reset link has been sent to\n${widget.email}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700])),
      ])
          : Text('Send a password reset email to:\n\n${widget.email}',
          style: TextStyle(color: Colors.grey[700])),
      actions: _sent
          ? [ElevatedButton(onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
              backgroundColor: _navy, foregroundColor: Colors.white),
          child: const Text('Done'))]
          : [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: _sending ? null : _send,
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white),
            child: _sending
                ? const SizedBox(height: 16, width: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Send Reset Email')),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 4 — CAMPAIGN CATEGORIES
// ═════════════════════════════════════════════════════════════════════════════
class _CategoriesTab extends StatefulWidget {
  final bool canManage;
  const _CategoriesTab({this.canManage = true});
  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  // ── palette shorthand ──────────────────────────────────────────────────────
  static const _navy  = Color(0xFF1B2263);
  static const _bg    = Color(0xFFF0F2F8);
  static const _green = Color(0xFF10B981);
  static const _red   = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CampaignCategory>>(
      stream: CategoryService.stream(),
      builder: (ctx, snap) {
        final loading    = snap.connectionState == ConnectionState.waiting;
        final categories = snap.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header row ─────────────────────────────────────────────────
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Campaign Categories',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: _navy)),
                const SizedBox(height: 4),
                Text('${categories.length} categories configured',
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ]),
              const Spacer(),
              if (widget.canManage)
                ElevatedButton.icon(
                  onPressed: () => _showAddCategoryDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Category'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _navy, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                ),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Categories appear in the campaign creation form. '
                  'Subcategories appear when a category is selected.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            if (loading)
              const Center(child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: _navy)))
            else if (categories.isEmpty)
              _emptyState()
            else
              ...categories.map((cat) => _CategoryCard(
                cat:         cat,
                canManage:   widget.canManage,
                onAddSub:    () => _showAddSubDialog(context, cat),
                onDelete:    () => _confirmDelete(context, cat),
              )),
          ]),
        );
      },
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────
  Widget _emptyState() => Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!)),
      child: Column(children: [
        Icon(Icons.category_outlined, size: 56, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text('No categories yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                color: _navy)),
        const SizedBox(height: 8),
        Text('Click "Add Category" to create your first category.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center),
      ]));

  // ── Add category dialog ─────────────────────────────────────────────────
  void _showAddCategoryDialog(BuildContext context) {
    final nameCtrl    = TextEditingController();
    String  iconKey   = 'favorite';
    String  colorHex  = '1B2263';
    bool    saving    = false;

    // Color options
    final colors = [
      ('2563EB', 'Blue'),    ('10B981', 'Green'),   ('F59E0B', 'Amber'),
      ('7C3AED', 'Purple'),  ('EC4899', 'Pink'),    ('1B2263', 'Navy'),
      ('DC2626', 'Red'),     ('0891B2', 'Teal'),    ('F97316', 'Orange'),
      ('6B7280', 'Grey'),
    ];

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => StatefulBuilder(builder: (dCtx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          title: const Row(children: [
            Icon(Icons.add_circle_outline, color: _navy),
            SizedBox(width: 10),
            Text('New Category', style: TextStyle(color: _navy, fontSize: 18,
                fontWeight: FontWeight.bold)),
          ]),
          content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Name
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Category Name *',
                    prefixIcon: const Icon(Icons.label_outline, color: _navy),
                    filled: true, fillColor: _bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _navy, width: 2)),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 20),

                // Icon picker
                const Text('Icon', style: TextStyle(fontWeight: FontWeight.w600,
                    color: _navy, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8,
                    children: CategoryService.iconKeys.map((key) {
                      final selected = iconKey == key;
                      return GestureDetector(
                        onTap: () => setS(() => iconKey = key),
                        child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                                color: selected ? _navy : _bg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: selected ? _navy : Colors.transparent, width: 2)),
                            child: Icon(CategoryService.iconFor(key),
                                color: selected ? Colors.white : Colors.grey[600],
                                size: 22)),
                      );
                    }).toList()),
                const SizedBox(height: 20),

                // Colour picker
                const Text('Colour', style: TextStyle(fontWeight: FontWeight.w600,
                    color: _navy, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8,
                    children: colors.map((pair) {
                      final hex      = pair.$1;
                      final label    = pair.$2;
                      final col      = Color(int.parse('FF$hex', radix: 16));
                      final selected = colorHex == hex;
                      return GestureDetector(
                        onTap: () => setS(() => colorHex = hex),
                        child: Tooltip(
                          message: label,
                          child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                  color: col, shape: BoxShape.circle,
                                  border: Border.all(
                                      color: selected ? Colors.black54 : Colors.transparent,
                                      width: 3)),
                              child: selected
                                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                                  : null),
                        ),
                      );
                    }).toList()),
                const SizedBox(height: 16),

                // Preview
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: Color(int.parse('FF$colorHex', radix: 16)).withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Color(int.parse('FF$colorHex', radix: 16)).withAlpha(60))),
                    child: Row(children: [
                      Icon(CategoryService.iconFor(iconKey),
                          color: Color(int.parse('FF$colorHex', radix: 16)), size: 20),
                      const SizedBox(width: 8),
                      Flexible(child: Text(
                          nameCtrl.text.isEmpty ? 'Category preview' : nameCtrl.text,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(int.parse('FF$colorHex', radix: 16))),
                          overflow: TextOverflow.ellipsis)),
                    ])),
              ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: saving ? null : () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Category name is required'),
                          backgroundColor: _red));
                  return;
                }
                setS(() => saving = true);
                await CategoryService.addCategory(
                    name: name, iconKey: iconKey, colorHex: colorHex);
                if (dCtx.mounted) Navigator.pop(dCtx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"$name" added'),
                          backgroundColor: _green));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: saving
                  ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Text('Add Category'),
            ),
          ],
        )));
  }

  // ── Add subcategory dialog ──────────────────────────────────────────────
  void _showAddSubDialog(BuildContext context, CampaignCategory cat) {
    final ctrl   = TextEditingController();
    bool  saving = false;
    showDialog(
        context: context,
        builder: (_) => StatefulBuilder(builder: (dCtx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(cat.icon, color: cat.color, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text('Add subcategory to "${cat.name}"',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                    color: _navy), overflow: TextOverflow.ellipsis)),
          ]),
          content: SizedBox(width: 360, child: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
                labelText: 'Subcategory Name *',
                prefixIcon: const Icon(Icons.subdirectory_arrow_right_outlined,
                    color: _navy),
                filled: true, fillColor: _bg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _navy, width: 2))),
          )),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: saving ? null : () async {
                final name = ctrl.text.trim();
                if (name.isEmpty) return;
                setS(() => saving = true);
                await CategoryService.addSubcategory(cat.id, name);
                if (dCtx.mounted) Navigator.pop(dCtx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"$name" added to ${cat.name}'),
                          backgroundColor: _green));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: saving
                  ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Text('Add'),
            ),
          ],
        )));
  }

  // ── Confirm delete category ─────────────────────────────────────────────
  void _confirmDelete(BuildContext context, CampaignCategory cat) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Category',
              style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
          content: RichText(text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.5),
              children: [
                const TextSpan(text: 'Are you sure you want to delete '),
                TextSpan(text: '"${cat.name}"',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(
                    text: '?\n\nExisting campaigns using this category will '
                        'not be affected, but it will no longer appear when '
                        'creating new campaigns.'),
              ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await CategoryService.deleteCategory(cat.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"${cat.name}" deleted'),
                          backgroundColor: _red));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _red, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Delete'),
            ),
          ],
        ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category card — shows category + its subcategories inline
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final CampaignCategory cat;
  final bool             canManage;
  final VoidCallback     onAddSub;
  final VoidCallback     onDelete;
  const _CategoryCard({
    required this.cat,
    required this.canManage,
    required this.onAddSub,
    required this.onDelete,
  });

  static const _navy  = Color(0xFF1B2263);
  static const _bg    = Color(0xFFF0F2F8);
  static const _red   = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8),
              blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Category header ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
              color: cat.color.withAlpha(12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(color: cat.color.withAlpha(30)))),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: cat.color.withAlpha(25),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(cat.icon, color: cat.color, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cat.name, style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
              Text(
                  cat.hasSubcategories
                      ? '${cat.subcategories.length} subcategories'
                      : 'No subcategories',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ])),
            // Delete category button
            IconButton(
                tooltip: 'Delete category',
                icon: const Icon(Icons.delete_outline, color: _red, size: 20),
                onPressed: onDelete,
                style: IconButton.styleFrom(
                    backgroundColor: _red.withAlpha(12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)))),
          ]),
        ),

        // ── Subcategories ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            if (cat.hasSubcategories) ...[
              const Text('Subcategories',
                  style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: cat.subcategories.map((sub) =>
                    _SubchipTile(
                        label: sub,
                        color: cat.color,
                        onDelete: () => _confirmDeleteSub(context, sub))).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Add subcategory row
            GestureDetector(
              onTap: onAddSub,
              child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.grey[300]!, style: BorderStyle.solid)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add, color: cat.color, size: 16),
                    const SizedBox(width: 6),
                    Text('Add subcategory',
                        style: TextStyle(fontSize: 13,
                            color: cat.color,
                            fontWeight: FontWeight.w600)),
                  ])),
            ),
            const SizedBox(height: 14),
          ]),
        ),
      ]),
    );
  }

  void _confirmDeleteSub(BuildContext context, String sub) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Remove Subcategory',
              style: TextStyle(color: _navy, fontWeight: FontWeight.bold,
                  fontSize: 16)),
          content: Text('Remove "$sub" from "${cat.name}"?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await CategoryService.removeSubcategory(cat.id, sub);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"$sub" removed'),
                          backgroundColor: _red));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _red, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: const Text('Remove'),
            ),
          ],
        ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subcategory chip tile with delete button
// ─────────────────────────────────────────────────────────────────────────────
class _SubchipTile extends StatelessWidget {
  final String      label;
  final Color       color;
  final VoidCallback onDelete;
  const _SubchipTile({required this.label,
    required this.color, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(50))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 13,
            color: color, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onDelete,
          child: Icon(Icons.close, size: 14,
              color: color.withAlpha(160)),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DONOR TYPES TAB
// ═════════════════════════════════════════════════════════════════════════════
class _DonorTypesTab extends StatefulWidget {
  final bool canManage;
  const _DonorTypesTab({this.canManage = true});
  @override
  State<_DonorTypesTab> createState() => _DonorTypesTabState();
}

class _DonorTypesTabState extends State<_DonorTypesTab> {
  static const _navy  = Color(0xFF1B2263);
  static const _bg    = Color(0xFFF0F2F8);
  static const _green = Color(0xFF10B981);
  static const _red   = Color(0xFFDC2626);

  // Available emojis for icon picker
  static const _emojis = [
    '👤','🏢','🤝','🎓','❤️','🌟','💡','🔬','🏗️',
    '🌍','🏆','💰','🎭','🎯','🏥','📚','🤲','✨',
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DonorTypeModel>>(
      stream: DonorTypeService.stream(),
      builder: (ctx, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final types   = snap.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Donor Types',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: _navy)),
                const SizedBox(height: 4),
                Text('${types.length} types  •  ${types.where((t) => t.isActive).length} active',
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ]),
              const Spacer(),
              if (widget.canManage)
                ElevatedButton.icon(
                  onPressed: () => _showAddDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Type'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _navy, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                ),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Donor types appear during registration and in donor profiles. '
                  'Deactivating a type hides it from new registrations but keeps existing donors unchanged.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            if (loading)
              const Center(child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: _navy)))
            else if (types.isEmpty)
              _emptyState()
            else
              ...types.map((t) => _DonorTypeCard(
                type:       t,
                canManage:  widget.canManage,
                onToggle:   () => DonorTypeService.setActive(t.id, !t.isActive),
                onEdit:     () => _showEditDialog(context, t),
                onDelete:   () => _confirmDelete(context, t),
              )),
          ]),
        );
      },
    );
  }

  Widget _emptyState() => Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!)),
      child: Column(children: [
        Icon(Icons.people_alt_outlined, size: 56, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text('No donor types yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(height: 8),
        Text('Click "Add Type" to create your first donor type.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center),
      ]));

  // ── Add dialog ────────────────────────────────────────────────────────────
  void _showAddDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String icon    = '👤';
    bool   saving  = false;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => StatefulBuilder(builder: (dCtx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          title: const Row(children: [
            Icon(Icons.add_circle_outline, color: _navy),
            SizedBox(width: 10),
            Text('New Donor Type',
                style: TextStyle(color: _navy, fontSize: 17, fontWeight: FontWeight.bold)),
          ]),
          content: SizedBox(width: 420, child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Name
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                  labelText: 'Type Name  (e.g. Alumni, Foundation Member)',
                  prefixIcon: const Icon(Icons.label_outline, color: _navy),
                  filled: true, fillColor: _bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _navy, width: 2))),
            ),
            const SizedBox(height: 14),

            // Description
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                  labelText: 'Description  (shown at registration)',
                  prefixIcon: const Icon(Icons.info_outline, color: _navy),
                  filled: true, fillColor: _bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _navy, width: 2))),
            ),
            const SizedBox(height: 18),

            // Emoji icon picker
            const Text('Icon', style: TextStyle(
                fontWeight: FontWeight.w600, color: _navy, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
                spacing: 6, runSpacing: 6,
                children: _emojis.map((e) {
                  final sel = icon == e;
                  return GestureDetector(
                    onTap: () => setS(() => icon = e),
                    child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                            color: sel ? _navy : _bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: sel ? _navy : Colors.transparent, width: 2)),
                        child: Center(child: Text(e,
                            style: const TextStyle(fontSize: 20)))),
                  );
                }).toList()),
            const SizedBox(height: 16),

            // Preview
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: _navy.withAlpha(12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _navy.withAlpha(40))),
                child: Row(children: [
                  Text(icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                        nameCtrl.text.isEmpty ? 'Type Name' : nameCtrl.text,
                        style: const TextStyle(fontWeight: FontWeight.bold,
                            color: _navy, fontSize: 14)),
                    if (descCtrl.text.isNotEmpty)
                      Text(descCtrl.text,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                ])),
          ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: saving ? null : () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Type name is required'),
                          backgroundColor: _red));
                  return;
                }
                setS(() => saving = true);
                await DonorTypeService.addType(
                    displayName: name,
                    icon:        icon,
                    description: descCtrl.text.trim());
                if (dCtx.mounted) Navigator.pop(dCtx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"$name" added'),
                          backgroundColor: _green));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: saving
                  ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Add Type'),
            ),
          ],
        )));
  }

  // ── Edit dialog ───────────────────────────────────────────────────────────
  void _showEditDialog(BuildContext context, DonorTypeModel type) {
    final nameCtrl = TextEditingController(text: type.displayName);
    final descCtrl = TextEditingController(text: type.description);
    String icon    = type.icon;
    bool   saving  = false;

    showDialog(
        context: context,
        builder: (_) => StatefulBuilder(builder: (dCtx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          title: Row(children: [
            Text(type.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text('Edit "${type.displayName}"',
                style: const TextStyle(color: _navy, fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ]),
          content: SizedBox(width: 420, child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                    labelText: 'Type Name',
                    prefixIcon: const Icon(Icons.label_outline, color: _navy),
                    filled: true, fillColor: _bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _navy, width: 2)))),
            const SizedBox(height: 14),
            TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                    labelText: 'Description',
                    prefixIcon: const Icon(Icons.info_outline, color: _navy),
                    filled: true, fillColor: _bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _navy, width: 2)))),
            const SizedBox(height: 18),
            const Text('Icon', style: TextStyle(
                fontWeight: FontWeight.w600, color: _navy, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
                spacing: 6, runSpacing: 6,
                children: _emojis.map((e) {
                  final sel = icon == e;
                  return GestureDetector(
                    onTap: () => setS(() => icon = e),
                    child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                            color: sel ? _navy : _bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: sel ? _navy : Colors.transparent, width: 2)),
                        child: Center(child: Text(e,
                            style: const TextStyle(fontSize: 20)))),
                  );
                }).toList()),
          ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: saving ? null : () async {
                if (nameCtrl.text.trim().isEmpty) return;
                setS(() => saving = true);
                await DonorTypeService.updateType(type.id,
                    displayName: nameCtrl.text.trim(),
                    icon:        icon,
                    description: descCtrl.text.trim());
                if (dCtx.mounted) Navigator.pop(dCtx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Donor type updated'),
                          backgroundColor: _green));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: saving
                  ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            ),
          ],
        )));
  }

  // ── Confirm delete ────────────────────────────────────────────────────────
  void _confirmDelete(BuildContext context, DonorTypeModel type) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Donor Type',
              style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
          content: RichText(text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.5),
              children: [
                const TextSpan(text: 'Delete '),
                TextSpan(text: '"${type.displayName}"',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(
                    text: '?\n\nExisting donors who selected this type will '
                        'not be affected, but it will no longer appear as an '
                        'option for new registrations.\n\n'
                        'Tip: use Deactivate instead to hide it temporarily.'),
              ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            OutlinedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await DonorTypeService.setActive(type.id, false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('"${type.displayName}" deactivated'),
                            backgroundColor: Colors.orange));
                  }
                },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange)),
                child: const Text('Deactivate')),
            ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await DonorTypeService.deleteType(type.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('"${type.displayName}" deleted'),
                            backgroundColor: _red));
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: _red, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text('Delete Permanently')),
          ],
        ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Donor Type Card
// ─────────────────────────────────────────────────────────────────────────────
class _DonorTypeCard extends StatelessWidget {
  final DonorTypeModel type;
  final bool           canManage;
  final VoidCallback   onToggle;
  final VoidCallback   onEdit;
  final VoidCallback   onDelete;

  const _DonorTypeCard({
    required this.type,
    required this.canManage,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  static const _navy  = Color(0xFF1B2263);
  static const _green = Color(0xFF10B981);
  static const _red   = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: type.isActive ? Colors.grey[200]! : Colors.orange.shade100),
          boxShadow: [BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 6, offset: const Offset(0, 2))]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icon
          Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: (type.isActive ? _navy : Colors.grey).withAlpha(12),
                  borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(type.icon,
                  style: const TextStyle(fontSize: 24)))),
          const SizedBox(width: 14),

          // Details
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(type.displayName,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15,
                      color: type.isActive ? _navy : Colors.grey[500]))),
              // Active / Inactive badge
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                      color: (type.isActive ? _green : Colors.orange).withAlpha(20),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    type.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold,
                        color: type.isActive ? _green : Colors.orange),
                  )),
            ]),
            if (type.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(type.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ])),

          // Actions
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[500], size: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'edit')   onEdit();
              if (v == 'toggle') onToggle();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Row(children: [
                const Icon(Icons.edit_outlined, size: 18, color: _navy),
                const SizedBox(width: 8),
                const Text('Edit')])),
              PopupMenuItem(value: 'toggle', child: Row(children: [
                Icon(type.isActive
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                    size: 18, color: Colors.orange),
                const SizedBox(width: 8),
                Text(type.isActive ? 'Deactivate' : 'Activate')])),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'delete', child: Row(children: [
                const Icon(Icons.delete_outline, size: 18, color: _red),
                const SizedBox(width: 8),
                const Text('Delete',
                    style: TextStyle(color: _red))])),
            ],
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Permission-aware wrappers — re-build tabs reactively when permissions change
// ═════════════════════════════════════════════════════════════════════════════

class _CategoriesTabWithPerms extends StatelessWidget {
  final bool canManage;
  const _CategoriesTabWithPerms({required this.canManage});

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever StaffProvider notifies (permission change)
    final canNow = context.watch<StaffProvider>()
        .canDo(Permission.manageCategories);
    return _CategoriesTab(canManage: canNow);
  }
}

class _DonorTypesTabWithPerms extends StatelessWidget {
  final bool canManage;
  const _DonorTypesTabWithPerms({required this.canManage});

  @override
  Widget build(BuildContext context) {
    final canNow = context.watch<StaffProvider>()
        .canDo(Permission.manageDonorTypes);
    return _DonorTypesTab(canManage: canNow);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DONATION AMOUNTS TAB — permission-aware wrapper
// ═════════════════════════════════════════════════════════════════════════════
class _DonationAmountsTabWithPerms extends StatelessWidget {
  final bool canManage;
  const _DonationAmountsTabWithPerms({required this.canManage});
  @override
  Widget build(BuildContext context) {
    final canNow = context.watch<StaffProvider>()
        .canDo(Permission.managePaymentMethods);
    return _DonationAmountsTab(canManage: canNow);
  }
}

class _DonationAmountsTab extends StatefulWidget {
  final bool canManage;
  const _DonationAmountsTab({required this.canManage});
  @override
  State<_DonationAmountsTab> createState() => _DonationAmountsTabState();
}

class _DonationAmountsTabState extends State<_DonationAmountsTab> {
  static const _navy  = Color(0xFF1B2263);
  static const _bg    = Color(0xFFF0F2F8);
  static const _green = Color(0xFF10B981);
  static const _red   = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    DonationAmountService.seedIfEmpty();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Header ─────────────────────────────────────────────────────────
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          color: _bg,
          child: Row(children: [
            const Icon(Icons.attach_money, color: _navy, size: 20),
            const SizedBox(width: 10),
            const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Preset Donation Amounts',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 15, color: _navy)),
              Text('Donors see these as quick-pick chips when donating.',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ])),
            if (widget.canManage)
              ElevatedButton.icon(
                onPressed: () => _showAmountDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Amount'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _navy, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
              ),
          ])),

      if (!widget.canManage)
        Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.orange.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withAlpha(60))),
            child: const Row(children: [
              Icon(Icons.visibility_outlined,
                  color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('View-only. Payment Methods permission required to edit.',
                  style: TextStyle(fontSize: 12, color: Colors.orange))),
            ])),

      // ── List ────────────────────────────────────────────────────────────
      Expanded(child: StreamBuilder<List<DonationAmountModel>>(
        stream: DonationAmountService.stream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _navy));
          }
          final amounts = snap.data ?? [];
          if (amounts.isEmpty) {
            return Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.attach_money, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              Text('No amounts configured yet.',
                  style: TextStyle(color: Colors.grey[500])),
              if (widget.canManage) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                    onPressed: () => _showAmountDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Amount'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white)),
              ],
            ]));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: amounts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _AmountCard(
              amount:    amounts[i],
              canManage: widget.canManage,
              onEdit:    () => _showAmountDialog(ctx, existing: amounts[i]),
              onDelete:  () => _confirmDelete(ctx, amounts[i]),
              onToggle:  () => DonationAmountService.setActive(
                  amounts[i].id, !amounts[i].isActive),
            ),
          );
        },
      )),
    ]);
  }

  // ── Add / Edit dialog ────────────────────────────────────────────────────
  void _showAmountDialog(BuildContext ctx,
      {DonationAmountModel? existing}) {
    final amtCtrl   = TextEditingController(
        text: existing != null
            ? existing.amount.toStringAsFixed(0) : '');
    final labelCtrl = TextEditingController(
        text: existing?.label ?? '');
    final orderCtrl = TextEditingController(
        text: existing != null ? existing.order.toString() : '');
    final formKey   = GlobalKey<FormState>();
    bool  saving    = false;
    final isEdit    = existing != null;

    showDialog(context: ctx, barrierDismissible: false,
        builder: (_) => StatefulBuilder(builder: (dCtx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(children: [
            Icon(isEdit ? Icons.edit_outlined : Icons.add_circle_outline,
                color: _navy),
            const SizedBox(width: 10),
            Text(isEdit ? 'Edit Amount' : 'Add Donation Amount',
                style: const TextStyle(color: _navy, fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ]),
          content: SizedBox(width: 380, child: Form(key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Amount
                TextFormField(
                    controller: amtCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: 'Amount (KES) *',
                        prefixIcon: const Icon(Icons.attach_money, color: _navy),
                        filled: true, fillColor: _bg,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _navy, width: 2))),
                    validator: (v) {
                      final n = double.tryParse(v?.trim() ?? '');
                      if (n == null || n <= 0) return 'Enter a valid amount';
                      return null;
                    }),
                const SizedBox(height: 12),
                // Label (optional)
                TextFormField(
                  controller: labelCtrl,
                  decoration: InputDecoration(
                      labelText: 'Label (optional, e.g. "School Fees")',
                      prefixIcon: const Icon(Icons.label_outline, color: _navy),
                      filled: true, fillColor: _bg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _navy, width: 2))),
                ),
                const SizedBox(height: 12),
                // Order
                TextFormField(
                  controller: orderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: 'Display Order',
                      prefixIcon: const Icon(Icons.sort, color: _navy),
                      hintText: 'e.g. 1 = first chip',
                      filled: true, fillColor: _bg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _navy, width: 2))),
                ),
              ]))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: saving ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setS(() => saving = true);
                final amt   = double.parse(amtCtrl.text.trim());
                final label = labelCtrl.text.trim();
                final order = int.tryParse(orderCtrl.text.trim()) ?? 99;
                if (isEdit) {
                  await DonationAmountService.update(existing.id,
                      amount: amt,
                      label:  label.isEmpty ? null : label,
                      order:  order);
                } else {
                  await DonationAmountService.add(
                      amount: amt,
                      label:  label.isEmpty ? null : label,
                      order:  order);
                }
                if (dCtx.mounted) Navigator.pop(dCtx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: saving
                  ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : Text(isEdit ? 'Save Changes' : 'Add Amount'),
            ),
          ],
        )));
  }

  void _confirmDelete(BuildContext ctx, DonationAmountModel amount) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Delete Amount?',
          style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
      content: Text(
          'Remove KES ${amount.amount.toStringAsFixed(0)}'
              '${amount.label != null ? " (${amount.label})" : ""} '
              'from the preset list? Donors won\'t see this chip anymore.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            await DonationAmountService.delete(amount.id);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: _red, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          child: const Text('Delete'),
        ),
      ],
    ));
  }
}

class _AmountCard extends StatelessWidget {
  final DonationAmountModel amount;
  final bool          canManage;
  final VoidCallback  onEdit, onDelete, onToggle;

  static const _navy  = Color(0xFF1B2263);
  static const _green = Color(0xFF10B981);

  const _AmountCard({
    required this.amount,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: amount.isActive
            ? Border.all(color: _navy.withAlpha(30))
            : Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8),
            blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(children: [
        // Order badge
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color: amount.isActive ? _navy.withAlpha(15) : Colors.grey.shade100,
              shape: BoxShape.circle),
          child: Center(child: Text('${amount.order}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                  color: amount.isActive ? _navy : Colors.grey))),
        ),
        const SizedBox(width: 12),
        // Amount + label
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('KES ${amount.amount.toStringAsFixed(0)}',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16,
                  color: amount.isActive ? _navy : Colors.grey[400])),
          if (amount.label != null)
            Text(amount.label!,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ])),
        // Active badge
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: amount.isActive
                    ? _green.withAlpha(20) : Colors.grey.withAlpha(20),
                borderRadius: BorderRadius.circular(8)),
            child: Text(amount.isActive ? 'Active' : 'Hidden',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                    color: amount.isActive ? _green : Colors.grey))),
        if (canManage) ...[
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
            onSelected: (v) {
              if (v == 'edit')   onEdit();
              if (v == 'toggle') onToggle();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit',
                  child: Row(children: const [
                    Icon(Icons.edit_outlined, size: 16),
                    SizedBox(width: 8), Text('Edit')])),
              PopupMenuItem(value: 'toggle',
                  child: Row(children: [
                    Icon(amount.isActive
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined, size: 16),
                    const SizedBox(width: 8),
                    Text(amount.isActive ? 'Hide from Donors' : 'Show to Donors'),
                  ])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ]),
    );
  }
}