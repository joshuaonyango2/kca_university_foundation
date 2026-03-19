// lib/screens/admin/admin_donors_screen.dart
// ✅ Includes: Donor Profile Editing, Manual Donations, Receipt Regeneration

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/routes.dart';
import '../../services/receipt_service.dart';
import '../../services/donor_type_service.dart';
import 'package:provider/provider.dart';
import '../../models/role_model.dart';
import '../../providers/staff_provider.dart';
import 'widgets/admin_layout.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
class KCA {
  static const navy    = Color(0xFF1B2263);
  static const gold    = Color(0xFFF5A800);
  static const white   = Colors.white;
  static const bg      = Color(0xFFF0F2F8);
  static const green   = Color(0xFF10B981);
  static const amber   = Color(0xFFF59E0B);
  static const error   = Color(0xFFDC2626);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
}

class AdminDonorsScreen extends StatefulWidget {
  const AdminDonorsScreen({super.key});
  @override
  State<AdminDonorsScreen> createState() => _AdminDonorsScreenState();
}

class _AdminDonorsScreenState extends State<AdminDonorsScreen> {
  final _searchCtrl  = TextEditingController();
  String _search     = '';
  String _filterType = 'all';

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<StaffProvider>();
    final canManageDonors = staff.canDo(Permission.manageDonors);
    final canDeleteDonors = staff.canDo(Permission.deleteDonors);

    return AdminLayout(
      title: 'Donors',
      activeRoute: AppRoutes.adminDonors,
      actions: canManageDonors ? [
        TextButton.icon(
          onPressed: () => _showAddDonorDialog(context),
          icon: const Icon(Icons.person_add, color: Colors.white, size: 18),
          label: const Text('Add Donor',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ] : null,
      child: Column(children: [
        // Search + filter
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            SizedBox(width: double.infinity, child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search donors by name or email...',
                  prefixIcon: const Icon(Icons.search, color: KCA.navy),
                  filled: true, fillColor: KCA.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ))),
            _chip('All', 'all'), _chip('👤 Individual', 'individual'),
            _chip('🏢 Corporate', 'corporate'), _chip('🤝 Partner', 'partner'),
          ]),
        ),

        // Donor list
        Expanded(child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donors')
                .orderBy('created_at', descending: true).snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: KCA.navy));
              }
              final docs     = snap.data?.docs ?? [];
              final filtered = docs.where((doc) {
                final d     = doc.data() as Map<String, dynamic>;
                final name  = (d['name']       as String? ?? '').toLowerCase();
                final email = (d['email']      as String? ?? '').toLowerCase();
                final rawType = d['donor_type'] as String? ?? '';
                final type = rawType.isNotEmpty
                    ? rawType[0].toUpperCase() + rawType.substring(1) : '';
                final matchSearch = _search.isEmpty || name.contains(_search) || email.contains(_search);
                final matchType   = _filterType == 'all' || type == _filterType;
                return matchSearch && matchType;
              }).toList();

              if (filtered.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.people_outline, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('No donors found', style: TextStyle(color: Colors.grey[400], fontSize: 15)),
                ]));
              }

              return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final doc  = filtered[i];
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id;
                    return _DonorCard(
                      data:          data,
                      canManage:     canManageDonors,
                      canDelete:     canDeleteDonors,
                      onEdit:        () => _showEditDialog(context, data),
                      onDonate:      () {
                        if (!canManageDonors) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('You do not have permission to record donations.'),
                              backgroundColor: Colors.red));
                          return;
                        }
                        _showManualDonationDialog(context, data);
                      },
                      onView:        () => _showDetailDialog(context, data),
                      onDeleteDonor: (id) => _confirmDeleteDonor(context, id,
                          data['name'] as String? ?? ''),
                    );
                  });
            })),
      ]),
    );
  }

  Widget _chip(String label, String value) => FilterChip(
      label: Text(label, style: TextStyle(
          color: _filterType == value ? KCA.white : KCA.navy,
          fontWeight: FontWeight.w600, fontSize: 12)),
      selected:      _filterType == value,
      onSelected:    (_) => setState(() => _filterType = value),
      backgroundColor:    KCA.white,
      selectedColor:      KCA.navy,
      checkmarkColor:     KCA.gold,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)));

  // ── Dialogs ───────────────────────────────────────────────────────────────
  void _showAddDonorDialog(BuildContext ctx) {
    showDialog(context: ctx, barrierDismissible: false,
        builder: (_) => _EditDonorDialog(data: const {}));
  }

  void _showEditDialog(BuildContext ctx, Map<String, dynamic> data) {
    showDialog(context: ctx, barrierDismissible: false,
        builder: (_) => _EditDonorDialog(data: data));
  }

  void _showManualDonationDialog(BuildContext ctx, Map<String, dynamic> data) {
    showDialog(context: ctx, barrierDismissible: false,
        builder: (_) => _ManualDonationDialog(donorData: data));
  }

  void _showDetailDialog(BuildContext ctx, Map<String, dynamic> data) {
    showDialog(context: ctx, builder: (_) => _DonorDetailDialog(data: data));
  }

  void _confirmDeleteDonor(BuildContext ctx, String id, String name) {
    showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Donor',
              style: TextStyle(color: KCA.navy, fontWeight: FontWeight.bold)),
          content: RichText(text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.5),
              children: [
                const TextSpan(text: 'Permanently delete '),
                TextSpan(text: '"$name"',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(
                    text: ' from the system?\n\nThis will remove their profile. '
                        'Donation records are kept for audit purposes.'),
              ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await FirebaseFirestore.instance
                      .collection('donors').doc(id).delete();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text('"$name" deleted'),
                        backgroundColor: KCA.error));
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: KCA.error, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text('Delete Permanently')),
          ],
        ));
  }
}

// ── Donor card ────────────────────────────────────────────────────────────────
class _DonorCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool canManage, canDelete;
  final VoidCallback onEdit, onDonate, onView;
  final void Function(String id) onDeleteDonor;
  const _DonorCard({
    required this.data,
    required this.canManage,
    required this.canDelete,
    required this.onEdit,
    required this.onDonate,
    required this.onView,
    required this.onDeleteDonor,
  });

  @override
  Widget build(BuildContext context) {
    final name  = data['name']       as String? ?? 'Unknown';
    final email = data['email']      as String? ?? '';
    final rawDt = data['donor_type'] as String? ?? 'individual';
    final type  = rawDt.isNotEmpty ? rawDt[0].toUpperCase() + rawDt.substring(1) : 'Individual';
    final init  = name.isNotEmpty ? name[0].toUpperCase() : 'D';

    final typeColor = type == 'corporate' ? KCA.amber : type == 'partner' ? KCA.green : KCA.navy;
    final typeIcon  = type == 'corporate' ? Icons.business : type == 'partner' ? Icons.handshake : Icons.person;

    return Container(
        decoration: BoxDecoration(color: KCA.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 2))]),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(radius: 24, backgroundColor: KCA.navy,
              child: Text(init, style: const TextStyle(color: KCA.gold, fontWeight: FontWeight.bold, fontSize: 17))),
          title: Row(children: [
            Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: KCA.navy), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: typeColor.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(typeIcon, size: 10, color: typeColor),
                  const SizedBox(width: 3),
                  Text(type[0].toUpperCase() + type.substring(1),
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: typeColor)),
                ])),
          ]),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 2),
            Text(email, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 4),
            // Total donations
            StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('donations')
                    .where('donor_id', isEqualTo: data['id'] as String).snapshots(),
                builder: (ctx, snap) {
                  final total = snap.data?.docs.fold(0.0,
                          (s, d) => s + ((d.data() as Map)['amount'] as num? ?? 0)) ?? 0.0;
                  final count = snap.data?.docs.length ?? 0;
                  return Text('$count donation${count != 1 ? 's' : ''} · KES ${_f(total)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]));
                }),
          ]),
          trailing: PopupMenuButton<String>(

              onSelected: (v) {
                if (v == 'view')   onView();
                if (v == 'edit')   onEdit();
                if (v == 'donate') onDonate();
                if (v == 'delete') onDeleteDonor(data['id'] as String? ?? '');
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'view', child: Row(children: [
                  Icon(Icons.visibility_outlined, size: 18, color: KCA.navy),
                  SizedBox(width: 8), Text('View Profile')])),
                if (canManage) ...[
                  const PopupMenuItem(value: 'edit', child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18, color: KCA.navy),
                    SizedBox(width: 8), Text('Edit Profile')])),
                  const PopupMenuItem(value: 'donate', child: Row(children: [
                    Icon(Icons.add_card_outlined, size: 18, color: KCA.green),
                    SizedBox(width: 8), Text('Record Manual Donation')])),
                ],
                if (canDelete) ...[
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'delete', child: Row(children: [
                    Icon(Icons.delete_outline, size: 18, color: KCA.error),
                    SizedBox(width: 8),
                    Text('Delete Donor', style: TextStyle(color: KCA.error))])),
                ],
              ]),
          onTap: onView,
        ));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EDIT DONOR DIALOG
// ══════════════════════════════════════════════════════════════════════════════
class _EditDonorDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  const _EditDonorDialog({required this.data});
  @override
  State<_EditDonorDialog> createState() => _EditDonorDialogState();
}

class _EditDonorDialogState extends State<_EditDonorDialog> {
  final _formKey    = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _orgCtrl;
  late final TextEditingController _addressCtrl;
  String _donorType = 'individual';
  bool   _saving    = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl    = TextEditingController(text: widget.data['name']         as String? ?? '');
    _phoneCtrl   = TextEditingController(text: widget.data['phone']        as String? ?? '');
    _orgCtrl     = TextEditingController(text: widget.data['organization'] as String? ?? '');
    _addressCtrl = TextEditingController(text: widget.data['address']      as String? ?? '');
    _donorType   = widget.data['donor_type'] as String? ?? 'individual';
  }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); _orgCtrl.dispose(); _addressCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('donors').doc(widget.data['id'] as String).update({
        'name':         _nameCtrl.text.trim(),
        'phone':        _phoneCtrl.text.trim(),
        'organization': _orgCtrl.text.trim(),
        'address':      _addressCtrl.text.trim(),
        'donor_type':   _donorType,
        'updated_at':   DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Donor profile updated'), backgroundColor: KCA.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(constraints: const BoxConstraints(maxWidth: 500), child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: KCA.navy, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Row(children: [
                const Icon(Icons.person_outline, color: KCA.gold),
                const SizedBox(width: 12),
                Expanded(child: Text('Edit Donor: ${widget.data['name']}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
              ])),

          Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Form(key: _formKey, child: Column(children: [
            _f(_nameCtrl,  'Full Name',    Icons.person_outline,  required: true),
            const SizedBox(height: 12),
            // Email — read only
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(color: KCA.bg, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.email_outlined, color: KCA.navy, size: 20), const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Email (read-only)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(widget.data['email'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ])),
                ])),
            const SizedBox(height: 12),
            _f(_phoneCtrl, 'Phone Number', Icons.phone_outlined, type: TextInputType.phone),
            const SizedBox(height: 12),
            _f(_orgCtrl,   'Organization / Company', Icons.business_outlined),
            const SizedBox(height: 12),
            _f(_addressCtrl, 'Address', Icons.location_on_outlined),
            const SizedBox(height: 12),

            // Donor type — loaded live from Firestore
            StreamBuilder<List<DonorTypeModel>>(
                stream: DonorTypeService.activeStream(),
                builder: (ctx, snap) {
                  final types = snap.data ?? [];
                  // Ensure the current value is still valid; fall back to first type
                  final validValue = types.any((t) => t.id == _donorType)
                      ? _donorType
                      : (types.isNotEmpty ? types.first.id : null);
                  return DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: validValue,
                    decoration: InputDecoration(
                        labelText: 'Donor Type',
                        prefixIcon: const Icon(Icons.category_outlined, color: KCA.navy),
                        filled: true, fillColor: KCA.bg,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        labelStyle: const TextStyle(color: KCA.navy)),
                    items: types.map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Text('${t.icon}  ${t.displayName}'),
                    )).toList(),
                    onChanged: (v) { if (v != null) setState(() => _donorType = v); },
                  );
                }),
          ])))),

          Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: KCA.navy, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)))),
          ])),
        ])));
  }

  Widget _f(TextEditingController ctrl, String label, IconData icon,
      {bool required = false, TextInputType type = TextInputType.text}) {
    return TextFormField(controller: ctrl, keyboardType: type,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: KCA.navy),
            filled: true, fillColor: KCA.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: KCA.navy, width: 2)),
            labelStyle: const TextStyle(color: KCA.navy)),
        validator: required ? (v) => v == null || v.trim().isEmpty ? '$label required' : null : null);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MANUAL DONATION DIALOG
// ══════════════════════════════════════════════════════════════════════════════
class _ManualDonationDialog extends StatefulWidget {
  final Map<String, dynamic> donorData;
  const _ManualDonationDialog({required this.donorData});
  @override
  State<_ManualDonationDialog> createState() => _ManualDonationDialogState();
}

class _ManualDonationDialogState extends State<_ManualDonationDialog> {
  final _formKey   = GlobalKey<FormState>();
  final _amtCtrl   = TextEditingController();
  final _noteCtrl  = TextEditingController();
  final _refCtrl   = TextEditingController();
  String? _campaignId;
  String  _campaignTitle = '';
  String  _method  = 'Cash';
  bool    _saving  = false;
  final _methods   = ['Cash', 'Bank Transfer', 'Cheque', 'M-Pesa (Manual)', 'Other'];

  @override
  void dispose() { _amtCtrl.dispose(); _noteCtrl.dispose(); _refCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final amount = double.tryParse(_amtCtrl.text.replaceAll(',', '')) ?? 0;
    try {
      final txId = 'MANUAL-${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance.collection('donations').doc(txId).set({
        'checkout_request_id': txId,
        'donor_id':       widget.donorData['id'] as String,
        'campaign_id':    _campaignId ?? '',
        'donor_name':     widget.donorData['name'] as String? ?? '',
        'campaign_title': _campaignTitle,
        'amount':         amount,
        'phone':          widget.donorData['phone'] as String? ?? '',
        'payment_method': _method,
        'reference':      _refCtrl.text.trim(),
        'notes':          _noteCtrl.text.trim(),
        'status':         'completed',
        'is_manual':      true,
        'created_at':     DateTime.now().toIso8601String(),
      });

      // Update campaign raised amount
      if (_campaignId != null && _campaignId!.isNotEmpty) {
        await FirebaseFirestore.instance.collection('campaigns').doc(_campaignId!).update({
          'raised': FieldValue.increment(amount),
        });
      }

      // Generate receipt
      await ReceiptService.generateAndSend(
        donorName:     widget.donorData['name'] as String? ?? '',
        donorEmail:    widget.donorData['email'] as String? ?? '',
        amount:        amount,
        campaignTitle: _campaignTitle,
        transactionId: txId,
        phone:         widget.donorData['phone'] as String? ?? '',
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✓ Manual donation of KES ${amount.toStringAsFixed(0)} recorded & receipt generated'),
          backgroundColor: KCA.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(constraints: const BoxConstraints(maxWidth: 500), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: KCA.navy, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Row(children: [
                const Icon(Icons.add_card_outlined, color: KCA.gold),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Record Manual Donation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(widget.donorData['name'] as String? ?? '', style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12)),
                ])),
                IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
              ])),

          Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Form(key: _formKey, child: Column(children: [
            // Info banner
            Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.withAlpha(20), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withAlpha(60))),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 16), SizedBox(width: 8),
                  Expanded(child: Text('Use this for cash, bank transfers, cheques, or any non-M-Pesa payment. A receipt will be generated automatically.', style: TextStyle(fontSize: 12, color: Colors.blue))),
                ])),
            const SizedBox(height: 16),

            // Amount
            TextFormField(controller: _amtCtrl, keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Amount (KES)', prefixText: 'KES ', prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: KCA.navy),
                    prefixIcon: const Icon(Icons.payments_outlined, color: KCA.navy),
                    filled: true, fillColor: KCA.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: KCA.navy, width: 2)),
                    labelStyle: const TextStyle(color: KCA.navy)),
                validator: (v) { final a = double.tryParse(v?.replaceAll(',','') ?? ''); return (a == null || a <= 0) ? 'Enter a valid amount' : null; }),
            const SizedBox(height: 12),

            // Payment method
            DropdownButtonFormField<String>(// ignore: deprecated_member_use
                value: _method,
                decoration: InputDecoration(labelText: 'Payment Method',
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: KCA.navy),
                    filled: true, fillColor: KCA.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    labelStyle: const TextStyle(color: KCA.navy)),
                items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) { if (v != null) setState(() => _method = v); }),
            const SizedBox(height: 12),

            // Reference
            TextFormField(controller: _refCtrl,
                decoration: InputDecoration(labelText: 'Reference / Receipt No. (optional)',
                    prefixIcon: const Icon(Icons.tag, color: KCA.navy),
                    filled: true, fillColor: KCA.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    labelStyle: const TextStyle(color: KCA.navy))),
            const SizedBox(height: 12),

            // Campaign
            StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('campaigns').where('is_active', isEqualTo: true).snapshots(),
                builder: (ctx, snap) {
                  final campaigns = snap.data?.docs ?? [];
                  return DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                      value: _campaignId,
                      decoration: InputDecoration(labelText: 'Campaign (optional)',
                          prefixIcon: const Icon(Icons.campaign_outlined, color: KCA.navy),
                          filled: true, fillColor: KCA.bg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          labelStyle: const TextStyle(color: KCA.navy)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— General Donation —')),
                        ...campaigns.map((c) {
                          final d = c.data() as Map<String, dynamic>;
                          return DropdownMenuItem(value: c.id, child: Text(d['title'] as String? ?? '', overflow: TextOverflow.ellipsis));
                        }),
                      ],
                      onChanged: (v) {
                        setState(() => _campaignId = v);
                        if (v != null) {
                          final c = snap.data!.docs.firstWhere((d) => d.id == v);
                          _campaignTitle = (c.data() as Map<String, dynamic>)['title'] as String? ?? '';
                        } else {
                          _campaignTitle = 'General Donation';
                        }
                      });
                }),
            const SizedBox(height: 12),

            // Notes
            TextFormField(controller: _noteCtrl, maxLines: 2,
                decoration: InputDecoration(labelText: 'Notes (optional)',
                    prefixIcon: const Icon(Icons.notes, color: KCA.navy),
                    filled: true, fillColor: KCA.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    labelStyle: const TextStyle(color: KCA.navy))),
          ])))),

          Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: KCA.green, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Record & Generate Receipt', style: TextStyle(fontWeight: FontWeight.bold)))),
          ])),
        ])));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DONOR DETAIL DIALOG (View full profile + donation history + receipts)
// ══════════════════════════════════════════════════════════════════════════════
class _DonorDetailDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DonorDetailDialog({required this.data});

  @override
  Widget build(BuildContext context) {
    final name  = data['name']       as String? ?? 'Unknown';
    final email = data['email']      as String? ?? '';
    final phone = data['phone']      as String? ?? '—';
    final rawDt = data['donor_type'] as String? ?? 'individual';
    final type  = rawDt.isNotEmpty ? rawDt[0].toUpperCase() + rawDt.substring(1) : 'Individual';
    final org   = data['organization'] as String? ?? '';
    final init  = name.isNotEmpty ? name[0].toUpperCase() : 'D';

    return Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700), child: Column(children: [
          // Header
          Container(padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: KCA.navy, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Row(children: [
                CircleAvatar(radius: 28, backgroundColor: KCA.gold,
                    child: Text(init, style: const TextStyle(color: KCA.navy, fontWeight: FontWeight.bold, fontSize: 22))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                  Text(email, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12)),
                  if (org.isNotEmpty) Text(org, style: TextStyle(color: KCA.gold.withAlpha(200), fontSize: 11)),
                ])),
                IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
              ])),

          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Profile details
            _infoRow('Phone',      phone,    Icons.phone_outlined),
            _infoRow('Type',       type[0].toUpperCase() + type.substring(1), Icons.category_outlined),
            if (data['address'] != null && (data['address'] as String).isNotEmpty)
              _infoRow('Address', data['address'] as String, Icons.location_on_outlined),
            const SizedBox(height: 20),

            // Donation history
            const Text('Donation History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: KCA.navy)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('donations')
                    .where('donor_id', isEqualTo: data['id'] as String)
                    .orderBy('created_at', descending: true).snapshots(),
                builder: (ctx, snap) {
                  final docs  = snap.data?.docs ?? [];
                  final total = docs.fold(0.0, (s, d) => s + ((d.data() as Map)['amount'] as num? ?? 0));

                  if (docs.isEmpty) {
                    return Container(padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: KCA.bg, borderRadius: BorderRadius.circular(10)),
                        child: const Center(child: Text('No donations yet', style: TextStyle(color: Colors.grey))));
                  }

                  return Column(children: [
                    // Summary
                    Container(padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: KCA.navy, borderRadius: BorderRadius.circular(10)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                          _sm('${docs.length}', 'Donations'),
                          Container(width: 1, height: 28, color: Colors.white24),
                          _sm('KES ${_f(total)}', 'Total Given'),
                        ])),
                    const SizedBox(height: 10),
                    ...docs.take(10).map((doc) {
                      final d      = doc.data() as Map<String, dynamic>;
                      final status = d['status'] as String? ?? 'completed';
                      final color  = status == 'completed' ? KCA.green : status == 'pending' ? KCA.amber : Colors.red;
                      return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: KCA.bg, borderRadius: BorderRadius.circular(8)),
                          child: Row(children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(d['campaign_title'] as String? ?? 'General', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                            Text('KES ${_f((d['amount'] as num? ?? 0).toDouble())}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(width: 8),
                            // Receipt button
                            if (status == 'completed') GestureDetector(
                                onTap: () => ReceiptService.regenerateFromFirestore(doc.id),
                                child: Tooltip(message: 'View Receipt',
                                    child: const Icon(Icons.receipt_long_outlined, size: 16, color: KCA.navy))),
                          ]));
                    }),
                  ]);
                }),
          ]))),

          Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), child: SizedBox(width: double.infinity,
              child: OutlinedButton(onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Close')))),
        ])));
  }

  Widget _infoRow(String label, String value, IconData icon) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: KCA.navy),
        const SizedBox(width: 10),
        Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
      ]));

  Widget _sm(String v, String l) => Column(children: [
    Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
    Text(l, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 11)),
  ]);
}

// ── helpers ───────────────────────────────────────────────────────────────────
String _f(double v) => v >= 1000000 ? '${(v/1000000).toStringAsFixed(1)}M'
    : v >= 1000 ? '${(v/1000).toStringAsFixed(0)}K' : v.toStringAsFixed(0);