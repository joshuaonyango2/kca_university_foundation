// lib/screens/admin/admin_staff_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../models/role_model.dart';
import '../../models/staff_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/staff_provider.dart';
import 'widgets/admin_layout.dart';

class _KCA {
  static const navy  = Color(0xFF1B2263);
  static const gold  = Color(0xFFF5A800);
  static const white = Colors.white;
  static const bg    = Color(0xFFF0F2F8);
  static const green = Color(0xFF10B981);
}

class AdminStaffScreen extends StatefulWidget {
  const AdminStaffScreen({super.key});
  @override
  State<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StaffProvider>().bootstrapRoles();
    });
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Staff Management',
      activeRoute: AppRoutes.adminStaff,
      actions: [
        ElevatedButton.icon(
          onPressed: () => showDialog(context: context, barrierDismissible: false, builder: (_) => const _OnboardDialog()),
          icon: const Icon(Icons.person_add_outlined, size: 18),
          label: const Text('Onboard Staff'),
          style: ElevatedButton.styleFrom(backgroundColor: _KCA.navy, foregroundColor: _KCA.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ],
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            decoration: InputDecoration(hintText: 'Search staff...', prefixIcon: const Icon(Icons.search, color: _KCA.navy),
                filled: true, fillColor: _KCA.white, contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<StaffModel>>(
            stream: context.read<StaffProvider>().staffStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(_KCA.navy)));
              }
              final all = snapshot.data ?? [];
              final filtered = _search.isEmpty ? all : all.where((s) =>
              s.name.toLowerCase().contains(_search) || s.email.toLowerCase().contains(_search) ||
                  s.roleName.toLowerCase().contains(_search)).toList();

              if (filtered.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.group_outlined, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('No staff members yet', style: TextStyle(color: Colors.grey[400], fontSize: 15)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => showDialog(context: context, barrierDismissible: false, builder: (_) => const _OnboardDialog()),
                    icon: const Icon(Icons.person_add_outlined), label: const Text('Onboard First Staff'),
                    style: ElevatedButton.styleFrom(backgroundColor: _KCA.navy, foregroundColor: _KCA.white),
                  ),
                ]));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _StaffCard(
                  staff: filtered[i],
                  onEdit: () => showDialog(context: context, builder: (_) => _EditRoleDialog(staff: filtered[i])),
                  onToggle: () => context.read<StaffProvider>().toggleStaffActive(filtered[i].id, filtered[i].isActive),
                  onAdminToggle: () => context.read<StaffProvider>().setAdminAccess(filtered[i].id, !filtered[i].isAdmin),
                  onDelete: () => _confirmDelete(context, filtered[i]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  void _confirmDelete(BuildContext context, StaffModel staff) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Remove Staff Member', style: TextStyle(color: Colors.red)),
      content: Text('Remove ${staff.name}?\n\nThis removes their record but does not delete their login account.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final ok = await context.read<StaffProvider>().deleteStaff(staff.id);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok ? '${staff.name} removed' : 'Failed to remove staff'),
                backgroundColor: ok ? _KCA.green : Colors.red));
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Remove', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }
}

class _StaffCard extends StatelessWidget {
  final StaffModel staff;
  final VoidCallback onEdit, onToggle, onAdminToggle, onDelete;
  const _StaffCard({required this.staff, required this.onEdit, required this.onToggle, required this.onAdminToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _KCA.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Row(children: [
        Stack(children: [
          CircleAvatar(radius: 26, backgroundColor: staff.isActive ? _KCA.navy : Colors.grey[400]!,
              child: Text(staff.initials, style: const TextStyle(color: _KCA.gold, fontWeight: FontWeight.bold, fontSize: 16))),
          if (staff.isAdmin)
            Positioned(right: 0, bottom: 0, child: Container(
                width: 16, height: 16,
                decoration: BoxDecoration(color: _KCA.gold, shape: BoxShape.circle, border: Border.all(color: _KCA.white, width: 1.5)),
                child: const Icon(Icons.star, size: 9, color: _KCA.navy))),
        ]),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(staff.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: staff.isActive ? _KCA.navy : Colors.grey)),
            if (staff.isAdmin) ...[const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: _KCA.gold, borderRadius: BorderRadius.circular(4)),
                  child: const Text('ADMIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _KCA.navy)))],
          ]),
          const SizedBox(height: 2),
          Text(staff.email, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _KCA.navy.withAlpha(15), borderRadius: BorderRadius.circular(6)),
              child: Text(staff.roleName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _KCA.navy))),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: staff.isActive ? _KCA.green.withAlpha(25) : Colors.grey.withAlpha(25),
              borderRadius: BorderRadius.circular(20)),
          child: Text(staff.isActive ? 'Active' : 'Inactive',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: staff.isActive ? _KCA.green : Colors.grey)),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: staff.permissions.map((p) => PermissionExt.fromKey(p)?.label ?? p).join(', '),
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: Colors.blue.withAlpha(20), borderRadius: BorderRadius.circular(8)),
              child: Text('${staff.permissions.length} perms', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue))),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey[400]),
          onSelected: (v) { if (v == 'edit') onEdit(); if (v == 'toggle') onToggle(); if (v == 'admin') onAdminToggle(); if (v == 'delete') onDelete(); },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.manage_accounts_outlined, size: 18), SizedBox(width: 8), Text('Change Role')])),
            PopupMenuItem(value: 'admin', child: Row(children: [Icon(staff.isAdmin ? Icons.remove_moderator_outlined : Icons.admin_panel_settings_outlined, size: 18), const SizedBox(width: 8), Text(staff.isAdmin ? 'Revoke Admin' : 'Grant Admin')])),
            PopupMenuItem(value: 'toggle', child: Row(children: [Icon(staff.isActive ? Icons.person_off_outlined : Icons.person_outlined, size: 18), const SizedBox(width: 8), Text(staff.isActive ? 'Deactivate' : 'Activate')])),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Remove', style: TextStyle(color: Colors.red))])),
          ],
        ),
      ]),
    );
  }
}

class _OnboardDialog extends StatefulWidget {
  const _OnboardDialog();
  @override
  State<_OnboardDialog> createState() => _OnboardDialogState();
}

class _OnboardDialogState extends State<_OnboardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(), _emailCtrl = TextEditingController(), _passCtrl = TextEditingController();
  RoleModel? _selectedRole;
  bool _isAdmin = false, _isLoading = false, _obscurePass = true;

  @override
  void dispose() { _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all fields and select a role'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);
    final result = await context.read<StaffProvider>().onboardStaff(
        name: _nameCtrl.text.trim(), email: _emailCtrl.text.trim(),
        tempPassword: _passCtrl.text, role: _selectedRole!, isAdmin: _isAdmin,
        createdByEmail: context.read<AuthProvider>().user?.email ?? '');
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✓ ${_nameCtrl.text.trim()} onboarded! Password reset email sent.'), backgroundColor: _KCA.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error ?? 'Failed'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: _KCA.navy, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Row(children: [
                const Icon(Icons.person_add_outlined, color: _KCA.gold), const SizedBox(width: 12),
                const Text('Onboard New Staff Member', style: TextStyle(color: _KCA.white, fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
              ])),
          Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Form(key: _formKey, child: Column(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.withAlpha(20), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withAlpha(60))),
                child: const Row(children: [Icon(Icons.info_outline, color: Colors.blue, size: 16), SizedBox(width: 8),
                  Expanded(child: Text('A password reset email will be sent so the staff member can set their own password.', style: TextStyle(fontSize: 12, color: Colors.blue)))])),
            const SizedBox(height: 16),
            _field(_nameCtrl, 'Full Name', Icons.person_outline, required: true),
            const SizedBox(height: 12),
            _field(_emailCtrl, 'Work Email', Icons.email_outlined, required: true, type: TextInputType.emailAddress,
                validator: (v) { if (v == null || v.isEmpty) return 'Required'; if (!v.contains('@')) return 'Invalid email'; return null; }),
            const SizedBox(height: 12),
            TextFormField(controller: _passCtrl, obscureText: _obscurePass,
                decoration: _dec('Temporary Password', Icons.lock_outline).copyWith(
                    helperText: 'Min 6 characters. Staff will be asked to reset it.',
                    suffixIcon: IconButton(icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey[500]),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass))),
                validator: (v) { if (v == null || v.isEmpty) return 'Required'; if (v.length < 6) return 'Min 6 chars'; return null; }),
            const SizedBox(height: 12),
            StreamBuilder<List<RoleModel>>(
                stream: context.read<StaffProvider>().rolesStream(),
                builder: (context, snap) => DropdownButtonFormField<RoleModel>(
                    value: _selectedRole, decoration: _dec('Assign Role', Icons.badge_outlined),
                    items: (snap.data ?? []).map((r) => DropdownMenuItem(value: r, child: Text(r.name, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (r) => setState(() => _selectedRole = r),
                    validator: (v) => v == null ? 'Select a role' : null)),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _isAdmin ? _KCA.gold.withAlpha(30) : _KCA.bg, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isAdmin ? _KCA.gold : Colors.grey[300]!)),
                child: Row(children: [
                  Icon(Icons.admin_panel_settings_outlined, color: _isAdmin ? _KCA.navy : Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Grant Admin Access', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('Full system access regardless of role.', style: TextStyle(fontSize: 11, color: Colors.grey[600]))])),
                  Switch(value: _isAdmin, onChanged: (v) => setState(() => _isAdmin = v), activeColor: _KCA.navy)])),
            if (_selectedRole != null) ...[const SizedBox(height: 12), _PermPreview(role: _selectedRole!)],
          ])))),
          Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: _KCA.navy, foregroundColor: _KCA.white, padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: _isLoading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_KCA.white)))
                    : const Text('Onboard & Send Email', style: TextStyle(fontWeight: FontWeight.bold)))),
          ])),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {bool required = false, TextInputType type = TextInputType.text, String? Function(String?)? validator}) {
    return TextFormField(controller: ctrl, keyboardType: type, decoration: _dec(label, icon),
        validator: validator ?? (required ? (v) => v == null || v.trim().isEmpty ? '$label required' : null : null));
  }
  InputDecoration _dec(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon, color: _KCA.navy), filled: true, fillColor: _KCA.bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _KCA.navy, width: 2)),
      labelStyle: const TextStyle(color: _KCA.navy));
}

class _EditRoleDialog extends StatefulWidget {
  final StaffModel staff;
  const _EditRoleDialog({required this.staff});
  @override
  State<_EditRoleDialog> createState() => _EditRoleDialogState();
}

class _EditRoleDialogState extends State<_EditRoleDialog> {
  RoleModel? _selectedRole;
  bool _isAdmin = false;
  @override
  void initState() { super.initState(); _isAdmin = widget.staff.isAdmin; }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(constraints: const BoxConstraints(maxWidth: 460), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: _KCA.navy, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(children: [
              const Icon(Icons.manage_accounts, color: _KCA.gold), const SizedBox(width: 12),
              Expanded(child: Text('Edit Role: ${widget.staff.name}', style: const TextStyle(color: _KCA.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context))])),
        Padding(padding: const EdgeInsets.all(24), child: Column(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _KCA.bg, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [const Icon(Icons.badge_outlined, color: _KCA.navy, size: 18), const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Current Role', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(widget.staff.roleName, style: const TextStyle(fontWeight: FontWeight.bold, color: _KCA.navy))])])),
          const SizedBox(height: 16),
          StreamBuilder<List<RoleModel>>(
              stream: context.read<StaffProvider>().rolesStream(),
              builder: (context, snap) => DropdownButtonFormField<RoleModel>(
                  value: _selectedRole, hint: const Text('Select new role...'),
                  decoration: InputDecoration(labelText: 'New Role', prefixIcon: const Icon(Icons.swap_horiz, color: _KCA.navy),
                      filled: true, fillColor: _KCA.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      labelStyle: const TextStyle(color: _KCA.navy)),
                  items: (snap.data ?? []).map((r) => DropdownMenuItem(value: r, child: Text(r.name, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (r) => setState(() => _selectedRole = r))),
          const SizedBox(height: 12),
          if (_selectedRole != null) ...[_PermPreview(role: _selectedRole!), const SizedBox(height: 12)],
          SwitchListTile(value: _isAdmin, onChanged: (v) => setState(() => _isAdmin = v),
              title: const Text('Admin Access', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Full system access'), activeColor: _KCA.navy, tileColor: _KCA.bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))])),
        Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), child: Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
              onPressed: _selectedRole == null ? null : () async {
                await context.read<StaffProvider>().updateStaffRole(staffId: widget.staff.id, role: _selectedRole!, isAdmin: _isAdmin);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Role updated'), backgroundColor: _KCA.green));
              },
              style: ElevatedButton.styleFrom(backgroundColor: _KCA.navy, foregroundColor: _KCA.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Save Changes')))
        ])),
      ])),
    );
  }
}

class _PermPreview extends StatelessWidget {
  final RoleModel role;
  const _PermPreview({required this.role});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _KCA.navy.withAlpha(10), borderRadius: BorderRadius.circular(10), border: Border.all(color: _KCA.navy.withAlpha(30))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Permissions for ${role.name}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _KCA.navy)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 4, children: role.permissionObjects.map((p) =>
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _KCA.navy, borderRadius: BorderRadius.circular(6)),
              child: Text(p.label, style: const TextStyle(fontSize: 10, color: _KCA.white, fontWeight: FontWeight.w500)))).toList()),
    ]),
  );
}