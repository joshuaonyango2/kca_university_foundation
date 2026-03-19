// lib/screens/admin/admin_payment_methods_screen.dart
//
// Full CRUD for payment methods: M-Pesa, Bank, PayPal, Card, etc.
// Gated by Permission.managePaymentMethods — super-admin always passes.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../models/role_model.dart';
import '../../providers/staff_provider.dart';
import '../../services/payment_method_service.dart';
import 'widgets/admin_layout.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _navy  = Color(0xFF1B2263);
const _bg    = Color(0xFFF0F2F8);
const _green = Color(0xFF10B981);
const _red   = Color(0xFFDC2626);

class AdminPaymentMethodsScreen extends StatefulWidget {
  const AdminPaymentMethodsScreen({super.key});
  @override
  State<AdminPaymentMethodsScreen> createState() =>
      _AdminPaymentMethodsScreenState();
}

class _AdminPaymentMethodsScreenState
    extends State<AdminPaymentMethodsScreen> {
  @override
  void initState() {
    super.initState();
    PaymentMethodService.seedIfEmpty();
  }

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<StaffProvider>();
    final canManage = staff.canDo(Permission.managePaymentMethods);

    return AdminLayout(
      title: 'Payment Methods',
      activeRoute: AppRoutes.adminPaymentMethods,
      actions: canManage
          ? [
        TextButton.icon(
          onPressed: () => _showForm(context, null),
          icon: const Icon(Icons.add, color: Colors.white, size: 18),
          label: const Text('Add Method',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        )
      ]
          : null,
      child: StreamBuilder<List<PaymentMethodModel>>(
        stream: PaymentMethodService.stream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _navy));
          }
          final methods = snap.data ?? [];
          final active  = methods.where((m) => m.isActive).length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment Methods',
                              style: TextStyle(fontSize: 22,
                                  fontWeight: FontWeight.bold, color: _navy)),
                          const SizedBox(height: 4),
                          Text('$active active · ${methods.length} total',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey)),
                        ]),
                    const Spacer(),
                    if (canManage)
                      ElevatedButton.icon(
                        onPressed: () => _showForm(context, null),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Method'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _navy, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'Configure which payment options donors see on the donation screen. '
                        'Deactivating hides a method without deleting its configuration.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),

                  if (!canManage)
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade200)),
                      child: const Row(children: [
                        Icon(Icons.info_outline,
                            color: Colors.amber, size: 20),
                        SizedBox(width: 10),
                        Expanded(child: Text(
                            'You have view-only access. Contact the super-admin '
                                'to request permission to manage payment methods.',
                            style: TextStyle(fontSize: 13))),
                      ]),
                    ),

                  if (methods.isEmpty)
                    _empty(canManage, context)
                  else
                    ...methods.map((m) => _MethodCard(
                      method:    m,
                      canManage: canManage,
                      onEdit:    () => _showForm(context, m),
                      onToggle:  () => PaymentMethodService.setActive(
                          m.id, !m.isActive),
                      onDelete:  () => _confirmDelete(context, m),
                    )),
                ]),
          );
        },
      ),
    );
  }

  Widget _empty(bool canManage, BuildContext context) => Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!)),
      child: Column(children: [
        Icon(Icons.payment_outlined, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text('No payment methods configured',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                color: _navy)),
        const SizedBox(height: 8),
        Text(canManage
            ? 'Click "Add Method" to configure your first payment option.'
            : 'No payment methods have been configured yet.',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center),
        if (canManage) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
              onPressed: () => _showForm(context, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Method'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)))),
        ],
      ]));

  // ── Add / Edit Form Dialog ────────────────────────────────────────────────
  void _showForm(BuildContext context, PaymentMethodModel? existing) {
    final isEdit     = existing != null;
    final nameCtrl   = TextEditingController(text: existing?.name ?? '');
    final descCtrl   = TextEditingController(text: existing?.description ?? '');
    final instCtrl   = TextEditingController(text: existing?.instructions ?? '');
    PaymentType type = existing?.type ?? PaymentType.mobileMoney;
    String emoji     = existing?.emoji ?? '💳';
    bool saving      = false;

    // Config key-value pairs
    final configEntries = existing?.config.entries.map(
            (e) => MapEntry(TextEditingController(text: e.key),
            TextEditingController(text: e.value))).toList()
        ?? <MapEntry<TextEditingController, TextEditingController>>[];

    final emojis = ['📱','🏦','💳','💙','🏧','💵','💰','🤑','🌍','✈️','🎓','❤️'];

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => StatefulBuilder(builder: (dCtx, setS) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Title bar
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                decoration: const BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.only(
                        topLeft:  Radius.circular(20),
                        topRight: Radius.circular(20))),
                child: Row(children: [
                  Icon(isEdit ? Icons.edit_outlined : Icons.add_circle_outline,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(isEdit ? 'Edit Payment Method' : 'New Payment Method',
                      style: const TextStyle(color: Colors.white, fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(dCtx),
                      padding: EdgeInsets.zero),
                ]),
              ),

              // Body
              Flexible(child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      _field(nameCtrl, 'Method Name *',
                          Icons.label_outline, 'e.g. M-Pesa, KCB Bank'),
                      const SizedBox(height: 14),

                      // Type dropdown
                      DropdownButtonFormField<PaymentType>(
                        value: type,
                        decoration: _dec('Type', Icons.category_outlined),
                        items: PaymentType.values.map((t) => DropdownMenuItem(
                          value: t,
                          child: Row(children: [
                            Icon(t.icon, size: 18,
                                color: t.color),
                            const SizedBox(width: 8),
                            Text(t.label),
                          ]),
                        )).toList(),
                        onChanged: (v) { if (v != null) setS(() => type = v); },
                      ),
                      const SizedBox(height: 14),

                      // Emoji picker
                      const Text('Icon (emoji)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: _navy)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8,
                          children: emojis.map((e) {
                            final sel = emoji == e;
                            return GestureDetector(
                              onTap: () => setS(() => emoji = e),
                              child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                      color: sel ? _navy : _bg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: sel ? _navy : Colors.transparent,
                                          width: 2)),
                                  child: Center(child: Text(e,
                                      style: const TextStyle(fontSize: 22)))),
                            );
                          }).toList()),
                      const SizedBox(height: 14),

                      // Description
                      _field(descCtrl, 'Short Description (shown on payment screen)',
                          Icons.info_outline, 'One-line summary for donors'),
                      const SizedBox(height: 14),

                      // Instructions
                      TextField(
                        controller: instCtrl,
                        maxLines: 4,
                        decoration: _dec(
                            'Donor Instructions (shown after selecting this method)',
                            Icons.list_alt_outlined),
                      ),
                      const SizedBox(height: 18),

                      // Config (admin-only details)
                      Row(children: [
                        const Text('Admin Config (account numbers, keys etc.)',
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w600, color: _navy)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => setS(() => configEntries.add(MapEntry(
                              TextEditingController(), TextEditingController()))),
                          icon: const Icon(Icons.add, size: 16, color: _navy),
                          label: const Text('Add Field',
                              style: TextStyle(color: _navy, fontSize: 12)),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      ...configEntries.asMap().entries.map((entry) {
                        final i   = entry.key;
                        final kv  = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            Expanded(child: TextField(
                              controller: kv.key,
                              style: const TextStyle(fontSize: 13),
                              decoration: _dec('Key', Icons.vpn_key_outlined),
                            )),
                            const SizedBox(width: 8),
                            Expanded(child: TextField(
                              controller: kv.value,
                              style: const TextStyle(fontSize: 13),
                              decoration: _dec('Value', Icons.text_fields_outlined),
                            )),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: _red, size: 20),
                              onPressed: () => setS(() => configEntries.removeAt(i)),
                            ),
                          ]),
                        );
                      }),
                    ]),
              )),

              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.pop(dCtx),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    onPressed: saving ? null : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Method name is required'),
                                backgroundColor: _red));
                        return;
                      }
                      setS(() => saving = true);
                      final config = Map<String, String>.fromEntries(
                          configEntries
                              .where((e) => e.key.text.trim().isNotEmpty)
                              .map((e) => MapEntry(
                              e.key.text.trim(), e.value.text.trim())));
                      if (isEdit && existing != null) {
                        await PaymentMethodService.updateMethod(existing.id,
                            name: name, type: type, emoji: emoji,
                            description: descCtrl.text.trim(),
                            instructions: instCtrl.text.trim(),
                            config: config);
                      } else {
                        await PaymentMethodService.addMethod(
                            name: name, type: type, emoji: emoji,
                            description: descCtrl.text.trim(),
                            instructions: instCtrl.text.trim(),
                            config: config);
                      }
                      if (dCtx.mounted) Navigator.pop(dCtx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(isEdit
                                ? '"$name" updated' : '"$name" added'),
                            backgroundColor: _green));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _navy, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: saving
                        ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : Text(isEdit ? 'Save Changes' : 'Add Method',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                  )),
                ]),
              ),
            ]),
          ),
        )));
  }

  // ── Confirm delete ────────────────────────────────────────────────────────
  void _confirmDelete(BuildContext context, PaymentMethodModel m) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Payment Method',
              style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
          content: RichText(text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 14,
                  height: 1.5),
              children: [
                const TextSpan(text: 'Delete '),
                TextSpan(text: '"${m.name}"',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(
                    text: '?\n\nExisting donation records are unaffected, but '
                        'donors will no longer see this option.\n\n'
                        'Tip: use Deactivate to temporarily hide it instead.'),
              ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.grey))),
            OutlinedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await PaymentMethodService.setActive(m.id, false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('"${m.name}" deactivated'),
                        backgroundColor: Colors.orange));
                  }
                },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange)),
                child: const Text('Deactivate')),
            ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await PaymentMethodService.deleteMethod(m.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('"${m.name}" deleted'),
                        backgroundColor: _red));
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: _red, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text('Delete')),
          ],
        ));
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label, prefixIcon: Icon(icon, color: _navy, size: 18),
    filled: true, fillColor: _bg,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _navy, width: 2)),
    labelStyle: const TextStyle(color: _navy, fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
  );

  Widget _field(TextEditingController ctrl, String label,
      IconData icon, String hint) =>
      TextField(
          controller: ctrl,
          decoration: _dec(label, icon).copyWith(hintText: hint));
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment Method Card
// ─────────────────────────────────────────────────────────────────────────────
class _MethodCard extends StatelessWidget {
  final PaymentMethodModel method;
  final bool               canManage;
  final VoidCallback        onEdit;
  final VoidCallback        onToggle;
  final VoidCallback        onDelete;

  const _MethodCard({
    required this.method, required this.canManage,
    required this.onEdit, required this.onToggle, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = method.type.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: method.isActive
                  ? Colors.grey[200]! : Colors.orange.shade100),
          boxShadow: [BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 6, offset: const Offset(0, 2))]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Emoji icon in coloured circle
          Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color: typeColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: typeColor.withAlpha(50))),
              child: Center(child: Text(method.emoji,
                  style: const TextStyle(fontSize: 26)))),
          const SizedBox(width: 14),

          // Info
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(method.name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                      color: method.isActive ? _navy : Colors.grey[500]))),
              // Type chip
              Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: typeColor.withAlpha(15),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(method.type.icon, size: 11, color: typeColor),
                    const SizedBox(width: 4),
                    Text(method.type.label,
                        style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.bold, color: typeColor)),
                  ])),
              const SizedBox(width: 8),
              // Active badge
              Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: (method.isActive
                          ? _green : Colors.orange).withAlpha(18),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(method.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold,
                          color: method.isActive ? _green : Colors.orange))),
            ]),
            if (method.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(method.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (method.config.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4,
                children: method.config.entries.take(3).map<Widget>((e) =>
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text('${e.key}: ${e.value}',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[600])))).toList(),
              ),
            ],
          ])),

          // Actions
          if (canManage)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  color: Colors.grey[400], size: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (v) {
                if (v == 'edit')   onEdit();
                if (v == 'toggle') onToggle();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18, color: _navy),
                  SizedBox(width: 8), Text('Edit')])),
                PopupMenuItem(value: 'toggle', child: Row(children: [
                  Icon(method.isActive
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                      size: 18, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(method.isActive ? 'Deactivate' : 'Activate')])),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'delete', child: Row(children: [
                  Icon(Icons.delete_outline, size: 18, color: _red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: _red))])),
              ],
            )
          else
            const SizedBox(width: 40),
        ]),
      ),
    );
  }
}