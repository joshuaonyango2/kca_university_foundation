// lib/screens/admin/admin_campaigns_screen.dart

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/routes.dart';
import '../../services/story_media_service.dart';
import '../../services/category_service.dart';
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
  static const success = Color(0xFF10B981);
  static const error   = Color(0xFFDC2626);
}

class AdminCampaignsScreen extends StatefulWidget {
  const AdminCampaignsScreen({super.key});

  @override
  State<AdminCampaignsScreen> createState() => _AdminCampaignsScreenState();
}

class _AdminCampaignsScreenState extends State<AdminCampaignsScreen> {
  final _searchCtrl = TextEditingController();
  String _search       = '';
  String _filterStatus = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Campaigns',
      activeRoute: AppRoutes.adminCampaigns,
      actions: [
        ElevatedButton.icon(
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New Campaign'),
          style: ElevatedButton.styleFrom(
            backgroundColor: KCA.navy,
            foregroundColor: KCA.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
      child: Column(children: [
        // ── Search + filters ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search campaigns...',
                prefixIcon: const Icon(Icons.search, color: KCA.navy),
                filled: true, fillColor: KCA.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            )),
            const SizedBox(width: 12),
            _filterChip('All', 'all'),
            const SizedBox(width: 6),
            _filterChip('Active', 'active'),
            const SizedBox(width: 6),
            _filterChip('Inactive', 'inactive'),
          ]),
        ),

        // ── Campaign list (real-time) ─────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('campaigns')
                .orderBy('created_at', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(KCA.navy)));
              }

              final docs = snap.data?.docs ?? [];
              final filtered = docs.where((doc) {
                final d      = doc.data() as Map<String, dynamic>;
                final title  = (d['title'] as String? ?? '').toLowerCase();
                final active = d['is_active'] as bool? ?? false;
                final matchSearch = _search.isEmpty || title.contains(_search);
                final matchStatus = _filterStatus == 'all' ||
                    (_filterStatus == 'active' && active) ||
                    (_filterStatus == 'inactive' && !active);
                return matchSearch && matchStatus;
              }).toList();

              if (filtered.isEmpty) {
                return Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.campaign_outlined, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      docs.isEmpty
                          ? 'No campaigns yet\nCreate your first campaign to get started'
                          : 'No campaigns match your search',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 15, height: 1.5),
                    ),
                    if (docs.isEmpty) ...[
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _openForm(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Campaign'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: KCA.navy, foregroundColor: KCA.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                      ),
                    ],
                  ],
                ));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final doc  = filtered[i];
                  final data = doc.data() as Map<String, dynamic>;
                  return _CampaignCard(
                    id: doc.id,
                    data: data,
                    onEdit:   () {
                      final staff = context.read<StaffProvider>();
                      if (!staff.canDo(Permission.manageCampaigns)) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('You do not have permission to edit campaigns.'),
                            backgroundColor: Colors.red));
                        return;
                      }
                      _openForm(context, id: doc.id, data: data);
                    },
                    onDelete: () {
                      final staff = context.read<StaffProvider>();
                      if (!staff.canDo(Permission.manageCampaigns)) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('You do not have permission to delete campaigns.'),
                            backgroundColor: Colors.red));
                        return;
                      }
                      _confirmDelete(context, doc.id, data['title'] as String? ?? '');
                    },
                    onToggle: () => _toggleStatus(doc.id, data['is_active'] as bool? ?? false),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filterStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? KCA.navy : KCA.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? KCA.navy : Colors.grey[300]!),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? KCA.white : Colors.grey[700],
                fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _openForm(BuildContext context, {String? id, Map<String, dynamic>? data}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CampaignFormDialog(id: id, data: data),
    );
  }

  Future<void> _toggleStatus(String id, bool current) async {
    await FirebaseFirestore.instance
        .collection('campaigns')
        .doc(id)
        .update({'is_active': !current});
  }

  void _confirmDelete(BuildContext context, String id, String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Campaign', style: TextStyle(color: KCA.error)),
        content: Text('Delete "$title"? This cannot be undone and all associated data will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('campaigns').doc(id).delete();
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Campaign deleted'), backgroundColor: KCA.error));
            },
            style: ElevatedButton.styleFrom(backgroundColor: KCA.error),
            child: const Text('Delete', style: TextStyle(color: KCA.white)),
          ),
        ],
      ),
    );
  }
}

// ── Campaign card ─────────────────────────────────────────────────────────────
class _CampaignCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _CampaignCard({
    required this.id, required this.data,
    required this.onEdit, required this.onDelete, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final title    = data['title']       as String? ?? 'Untitled';
    final desc     = data['description'] as String? ?? '';
    final category = data['category']   as String? ?? 'General';
    final isActive = data['is_active']  as bool? ?? false;
    final raised   = (data['raised']    as num? ?? 0).toDouble();
    final goal     = (data['goal']      as num? ?? 1).toDouble();
    final pct      = (raised / goal).clamp(0.0, 1.0);
    final endDate  = data['end_date']   as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: KCA.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
        border: Border(left: BorderSide(
            color: isActive ? KCA.gold : Colors.grey[300]!, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: KCA.navy.withAlpha(15), borderRadius: BorderRadius.circular(10)),
              child: Icon(_catIcon(category), color: KCA.navy, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: KCA.navy),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(children: [
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: KCA.gold.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: KCA.gold.withAlpha(80))),
                    child: Text(category,
                        style: const TextStyle(fontSize: 10, color: KCA.navy, fontWeight: FontWeight.w600)),
                  ),
                  if (endDate.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.calendar_today_outlined, size: 11, color: Colors.grey[400]),
                    const SizedBox(width: 3),
                    Text('Ends $endDate', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                  ],
                ]),
              ],
            )),

            // Status toggle
            GestureDetector(
              onTap: onToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive ? KCA.success.withAlpha(20) : Colors.grey.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isActive ? KCA.success : Colors.grey[300]!),
                ),
                child: Text(isActive ? '● Active' : '○ Inactive',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold,
                        color: isActive ? KCA.success : Colors.grey[500])),
              ),
            ),
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[400]),
              onSelected: (v) {
                if (v == 'edit')   onEdit();
                if (v == 'delete') onDelete();
                if (v == 'toggle') onToggle();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit',
                    child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                PopupMenuItem(value: 'toggle',
                    child: Row(children: [
                      Icon(isActive ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 18),
                      const SizedBox(width: 8),
                      Text(isActive ? 'Deactivate' : 'Activate'),
                    ])),
                const PopupMenuItem(value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 18, color: KCA.error),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: KCA.error)),
                    ])),
              ],
            ),
          ]),

          const SizedBox(height: 12),
          Text(desc, style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 14),

          // Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('KES ${_fmt(raised)} raised',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: KCA.navy)),
              Text('${(pct * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: KCA.success, fontSize: 12)),
              Text('Goal: KES ${_fmt(goal)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct, minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(pct >= 1.0 ? KCA.gold : KCA.success),
            ),
          ),
        ]),
      ),
    );
  }

  String _fmt(double v) => v >= 1000000
      ? '${(v / 1000000).toStringAsFixed(1)}M'
      : v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);

  IconData _catIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'scholarships':   return Icons.school;
      case 'infrastructure': return Icons.business;
      case 'research':       return Icons.science;
      case 'health':         return Icons.health_and_safety;
      case 'technology':     return Icons.computer;
      case 'community':      return Icons.groups;
      default:               return Icons.favorite;
    }
  }
}

// ── Campaign form dialog ──────────────────────────────────────────────────────

// ── Campaign form dialog ──────────────────────────────────────────────────────
// Uses DefaultTabController so TabBarView gets a proper height budget.
class _CampaignFormDialog extends StatefulWidget {
  final String? id;
  final Map<String, dynamic>? data;
  const _CampaignFormDialog({this.id, this.data});

  @override
  State<_CampaignFormDialog> createState() => _CampaignFormDialogState();
}

class _CampaignFormDialogState extends State<_CampaignFormDialog> {
  final _formKey     = GlobalKey<FormState>();
  final _titleCtrl   = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _goalCtrl    = TextEditingController();
  final _endDateCtrl = TextEditingController();

  String? _category;
  String? _subcategory;
  List<CampaignCategory> _categories = [];  // loaded from Firestore
  bool    _isActive  = true;
  bool    _isLoading = false;
  bool get _isEdit   => widget.id != null;

  // Impact & Stories state
  final List<Map<String, String>>  _metrics    = [];
  final List<Map<String, dynamic>> _milestones = [];
  // Stories: each map holds name/role/story text + media fields
  final List<Map<String, dynamic>> _stories    = [];


  @override
  void initState() {
    super.initState();
    _loadCategories();
    final d = widget.data;
    if (d != null) {
      _titleCtrl.text   = d['title']       as String? ?? '';
      _descCtrl.text    = d['description'] as String? ?? '';
      _goalCtrl.text    = '${d['goal'] ?? ''}';
      _endDateCtrl.text = d['end_date']    as String? ?? '';
      _category         = d['category']   as String?;
      _subcategory      = d['subcategory'] as String?;
      _isActive         = d['is_active']  as bool?   ?? true;

      // Load impact metrics
      final rawM = d['impact_metrics'];
      if (rawM is List) {
        for (final m in rawM) {
          if (m is Map) _metrics.add({
            'label': m['label'] as String? ?? '',
            'value': m['value'] as String? ?? '',
            'icon':  m['icon']  as String? ?? 'star',
          });
        }
      }
      // Load milestones
      final rawMs = d['milestones'];
      if (rawMs is List) {
        for (final m in rawMs) {
          if (m is Map) _milestones.add({
            'title':       m['title']       as String? ?? '',
            'description': m['description'] as String? ?? '',
            'percentage':  m['percentage']  as int?    ?? 25,
            'achieved':    m['achieved']    as bool?   ?? false,
          });
        }
      }
      // Load stories (includes media fields)
      final rawS = d['stories'];
      if (rawS is List) {
        for (final s in rawS) {
          if (s is Map) _stories.add({
            'name':       s['name']       as String? ?? '',
            'role':       s['role']       as String? ?? '',
            'story':      s['story']      as String? ?? '',
            'media_type': s['media_type'] as String? ?? 'none',
            'photo_url':  s['photo_url']  as String? ?? '',
            'video_url':  s['video_url']  as String? ?? '',
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _goalCtrl.dispose();
    _endDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await CategoryService.fetch();
    if (mounted) setState(() => _categories = cats);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final payload = <String, dynamic>{
      'title':          _titleCtrl.text.trim(),
      'description':    _descCtrl.text.trim(),
      'goal':           double.tryParse(_goalCtrl.text.trim()) ?? 0,
      'category':       _category ?? 'Other',
      'subcategory':    _subcategory,
      'end_date':       _endDateCtrl.text.trim(),
      'is_active':      _isActive,
      'impact_metrics': _metrics.map((m) => Map<String, dynamic>.from(m)).toList(),
      'milestones':     _milestones.map((m) => Map<String, dynamic>.from(m)).toList(),
      'stories':        _stories.toList(),
    };

    try {
      if (_isEdit) {
        await FirebaseFirestore.instance
            .collection('campaigns').doc(widget.id).update(payload);
      } else {
        payload['raised']     = 0.0;
        payload['created_at'] = DateTime.now().toIso8601String();
        await FirebaseFirestore.instance.collection('campaigns').add(payload);
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit ? '✓ Campaign updated' : '✓ Campaign created successfully'),
          backgroundColor: KCA.success));
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: KCA.error));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // DefaultTabController wraps the whole dialog so TabBar + TabBarView
    // share the same controller without needing SingleTickerProviderStateMixin.
    return DefaultTabController(
      length: 2,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 620,
            // Use screen height minus padding so dialog is never taller than viewport
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // ── Navy header + tab bar ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              decoration: const BoxDecoration(
                color: KCA.navy,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: KCA.gold.withAlpha(30),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(_isEdit ? Icons.edit_outlined : Icons.campaign_outlined,
                          color: KCA.gold, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isEdit ? 'Edit Campaign' : 'New Campaign',
                            style: const TextStyle(color: KCA.white, fontSize: 17,
                                fontWeight: FontWeight.bold)),
                        Text(_isEdit
                            ? 'Update campaign details, impact & stories'
                            : 'Create campaign with impact metrics & stories',
                            style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 11)),
                      ])),
                  IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context)),
                ]),
                const SizedBox(height: 10),
                TabBar(
                  indicatorColor: KCA.gold,
                  indicatorWeight: 3,
                  labelColor: KCA.gold,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(icon: Icon(Icons.info_outline, size: 16), text: 'Details'),
                    Tab(icon: Icon(Icons.bar_chart, size: 16),    text: 'Impact & Stories'),
                  ],
                ),
              ]),
            ),

            // ── Tab content — explicit Expanded so TabBarView has height ───
            Expanded(
              child: TabBarView(children: [

                // ─── TAB 1: Details ────────────────────────────────────────
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Form(
                    key: _formKey,
                    child: Column(children: [
                      _field(_titleCtrl, 'Campaign Title *', Icons.title, required: true),
                      const SizedBox(height: 14),
                      _field(_descCtrl, 'Description *', Icons.description,
                          required: true, maxLines: 3),
                      const SizedBox(height: 14),
                      _field(_goalCtrl, 'Fundraising Goal (KES) *', Icons.attach_money,
                          required: true,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
                            if ((double.tryParse(v.trim()) ?? 0) <= 0) return 'Must be > 0';
                            return null;
                          }),
                      const SizedBox(height: 14),
                      // ── Category (from Firestore) ──────────────────────────
                      _categories.isEmpty
                          ? Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: KCA.bg, borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!)),
                          child: Row(children: [
                            const SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: KCA.navy)),
                            const SizedBox(width: 10),
                            Text('Loading categories…',
                                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                          ]))
                          : DropdownButtonFormField<String>(
                        value: _categories.any((c) => c.name == _category)
                            ? _category : null,
                        decoration: _dec('Category *', Icons.category_outlined),
                        hint: const Text('Select campaign category'),
                        isExpanded: true,
                        items: _categories.map((cat) => DropdownMenuItem(
                          value: cat.name,
                          child: Row(children: [
                            Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                    color: cat.color.withAlpha(20),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Icon(cat.icon, size: 16, color: cat.color)),
                            const SizedBox(width: 8),
                            Flexible(child: Text(cat.name,
                                overflow: TextOverflow.ellipsis)),
                          ]),
                        )).toList(),
                        onChanged: (v) => setState(() {
                          _category    = v;
                          _subcategory = null; // reset when category changes
                        }),
                        validator: (v) => v == null ? 'Please select a category' : null,
                      ),
                      // ── Subcategory (shown only when the selected category has subcategories)
                      Builder(builder: (ctx) {
                        final cat = _categories.where(
                                (c) => c.name == _category).firstOrNull;
                        if (cat == null || !cat.hasSubcategories) {
                          return const SizedBox.shrink();
                        }
                        return Column(children: [
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: cat.subcategories.contains(_subcategory)
                                ? _subcategory : null,
                            decoration: _dec('Subcategory (optional)',
                                Icons.subdirectory_arrow_right_outlined),
                            hint: const Text('Select subcategory'),
                            isExpanded: true,
                            items: cat.subcategories.map((sub) =>
                                DropdownMenuItem(value: sub,
                                    child: Text(sub, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setState(() => _subcategory = v),
                          ),
                        ]);
                      }),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _endDateCtrl,
                        readOnly: true,
                        decoration: _dec('End Date (optional)', Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                  colorScheme: const ColorScheme.light(
                                      primary: KCA.navy, secondary: KCA.gold)),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            _endDateCtrl.text =
                            '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      // Active toggle
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: _isActive
                                ? KCA.navy.withAlpha(10)
                                : Colors.grey.withAlpha(10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _isActive
                                    ? KCA.navy.withAlpha(40)
                                    : Colors.grey[300]!)),
                        child: Row(children: [
                          Icon(Icons.visibility_outlined,
                              color: _isActive ? KCA.navy : Colors.grey[400]),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Visible to Donors',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _isActive ? KCA.navy : Colors.grey[500])),
                                Text('Active campaigns appear in the donor app',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              ])),
                          Switch(
                            value: _isActive,
                            onChanged: (v) => setState(() => _isActive = v),
                            activeThumbColor: KCA.navy,
                            activeTrackColor: KCA.gold.withAlpha(120),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                    ]),
                  ),
                ),

                // ─── TAB 2: Impact & Stories ───────────────────────────────
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // ── Impact Metrics ──────────────────────────────────────
                    _sectionHeader(
                      'Impact Metrics',
                      Icons.bar_chart,
                      'Key numbers that show what donations achieved\n(e.g. "50 Scholarships Awarded")',
                    ),
                    const SizedBox(height: 10),
                    ..._metrics.asMap().entries.map((e) => _MetricTile(
                      data: e.value,
                      onEdit:   () => _showMetricSheet(e.key),
                      onDelete: () => setState(() => _metrics.removeAt(e.key)),
                    )),
                    _addButton('Add Impact Metric', Icons.add_chart,
                            () => _showMetricSheet(null)),
                    const SizedBox(height: 20),

                    // ── Milestones ──────────────────────────────────────────
                    _sectionHeader(
                      'Milestones',
                      Icons.flag_outlined,
                      'Funding checkpoints & what they unlock\n(e.g. "25% funded – first 10 scholarships")',
                    ),
                    const SizedBox(height: 10),
                    ..._milestones.asMap().entries.map((e) => _MilestoneTile(
                      data: e.value,
                      onEdit:   () => _showMilestoneSheet(e.key),
                      onDelete: () => setState(() => _milestones.removeAt(e.key)),
                    )),
                    _addButton('Add Milestone', Icons.add_circle_outline,
                            () => _showMilestoneSheet(null)),
                    const SizedBox(height: 20),

                    // ── Beneficiary Stories ─────────────────────────────────
                    _sectionHeader(
                      'Beneficiary Stories',
                      Icons.format_quote,
                      'Real testimonials from people impacted by this campaign',
                    ),
                    const SizedBox(height: 10),
                    ..._stories.asMap().entries.map((e) => _StoryTile(
                      data: e.value,
                      onEdit:   () => _showStorySheet(e.key),
                      onDelete: () => setState(() => _stories.removeAt(e.key)),
                    )),
                    _addButton('Add Story', Icons.person_add_outlined,
                            () => _showStorySheet(null)),
                    const SizedBox(height: 8),
                  ]),
                ),

              ]),
            ),

            // ── Action buttons ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 4, offset: const Offset(0, -2))]),
              child: Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancel'),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KCA.navy, foregroundColor: KCA.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(KCA.white)))
                      : Text(_isEdit ? 'Save Changes' : 'Create Campaign',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                )),
              ]),
            ),

          ]),
        ),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon, String subtitle) {
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: KCA.navy.withAlpha(10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: KCA.navy.withAlpha(30))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: KCA.navy, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold,
                fontSize: 14, color: KCA.navy)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.4)),
          ])),
        ]));
  }

  // ── Dashed add button ─────────────────────────────────────────────────────
  Widget _addButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                border: Border.all(color: KCA.navy.withAlpha(60)),
                borderRadius: BorderRadius.circular(10),
                color: KCA.navy.withAlpha(5)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: KCA.navy, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: KCA.navy,
                  fontWeight: FontWeight.w600, fontSize: 13)),
            ])));
  }

  // ── Metric bottom sheet ───────────────────────────────────────────────────
  void _showMetricSheet(int? editIndex) {
    final isEdit     = editIndex != null;
    final labelCtrl  = TextEditingController(
        text: isEdit ? _metrics[editIndex]['label'] ?? '' : '');
    final valueCtrl  = TextEditingController(
        text: isEdit ? _metrics[editIndex]['value'] ?? '' : '');
    String selIcon   = isEdit ? (_metrics[editIndex]['icon'] ?? 'star') : 'star';

    final iconOptions = <String, IconData>{
      'star':      Icons.star_outline,
      'school':    Icons.school_outlined,
      'people':    Icons.people_outline,
      'home':      Icons.home_outlined,
      'science':   Icons.science_outlined,
      'volunteer': Icons.volunteer_activism_outlined,
      'money':     Icons.attach_money,
      'check':     Icons.check_circle_outline,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 20, right: 20, top: 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle bar
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(isEdit ? 'Edit Impact Metric' : 'Add Impact Metric',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: KCA.navy)),
            const SizedBox(height: 16),
            TextField(controller: valueCtrl,
                keyboardType: TextInputType.text,
                decoration: _dec('Value  (e.g. "50" or "200+")', Icons.numbers)),
            const SizedBox(height: 12),
            TextField(controller: labelCtrl,
                decoration: _dec('Label  (e.g. "Scholarships Awarded")', Icons.label_outline)),
            const SizedBox(height: 14),
            Align(alignment: Alignment.centerLeft,
                child: Text('Icon', style: TextStyle(fontWeight: FontWeight.bold,
                    color: Colors.grey[700], fontSize: 13))),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8,
                children: iconOptions.entries.map((e) => GestureDetector(
                  onTap: () => setS(() => selIcon = e.key),
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: selIcon == e.key ? KCA.navy : const Color(0xFFF0F2F8),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(e.value,
                          color: selIcon == e.key ? Colors.white : KCA.navy, size: 22)),
                )).toList()),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: KCA.navy, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  onPressed: () {
                    if (valueCtrl.text.trim().isEmpty ||
                        labelCtrl.text.trim().isEmpty) return;
                    setState(() {
                      final entry = {
                        'value': valueCtrl.text.trim(),
                        'label': labelCtrl.text.trim(),
                        'icon':  selIcon,
                      };
                      if (isEdit) { _metrics[editIndex] = entry; }
                      else        { _metrics.add(entry); }
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text(isEdit ? 'Save Changes' : 'Add Metric',
                      style: const TextStyle(fontWeight: FontWeight.bold)))),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  // ── Milestone bottom sheet ────────────────────────────────────────────────
  void _showMilestoneSheet(int? editIndex) {
    final isEdit    = editIndex != null;
    final titleCtrl = TextEditingController(
        text: isEdit ? _milestones[editIndex]['title'] as String? ?? '' : '');
    final descCtrl  = TextEditingController(
        text: isEdit ? _milestones[editIndex]['description'] as String? ?? '' : '');
    int  pct      = isEdit ? (_milestones[editIndex]['percentage'] as int? ?? 25) : 25;
    bool achieved = isEdit ? (_milestones[editIndex]['achieved']   as bool? ?? false) : false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 20, right: 20, top: 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(isEdit ? 'Edit Milestone' : 'Add Milestone',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: KCA.navy)),
            const SizedBox(height: 16),
            TextField(controller: titleCtrl,
                decoration: _dec('Milestone title (e.g. "25% Funded")', Icons.flag_outlined)),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, maxLines: 2,
                decoration: _dec(
                    'What it unlocks (e.g. "First 10 scholarships awarded")',
                    Icons.description_outlined)),
            const SizedBox(height: 14),
            Row(children: [
              Text('Funding threshold: $pct%',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: KCA.navy)),
              Expanded(child: Slider(
                value: pct.toDouble(), min: 5, max: 100, divisions: 19,
                activeColor: KCA.navy,
                onChanged: (v) => setS(() => pct = v.round()),
              )),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: achieved
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFF0F2F8),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(achieved ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: achieved ? const Color(0xFF10B981) : Colors.grey[500]),
                const SizedBox(width: 10),
                Expanded(child: Text('Already achieved',
                    style: TextStyle(fontWeight: FontWeight.w600,
                        color: achieved ? const Color(0xFF065F46) : Colors.grey[600]))),
                Switch(
                  value: achieved,
                  onChanged: (v) => setS(() => achieved = v),
                  activeThumbColor: const Color(0xFF10B981),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: KCA.navy, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty) return;
                    setState(() {
                      final entry = {
                        'title':       titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'percentage':  pct,
                        'achieved':    achieved,
                      };
                      if (isEdit) { _milestones[editIndex] = entry; }
                      else        { _milestones.add(entry); }
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text(isEdit ? 'Save Changes' : 'Add Milestone',
                      style: const TextStyle(fontWeight: FontWeight.bold)))),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  // ── Story dialog (full StatefulWidget for async upload state) ──────────────
  void _showStorySheet(int? editIndex) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _StoryDialog(
        campaignId:  widget.id ?? 'new',
        storyIndex:  editIndex ?? _stories.length,
        existing:    editIndex != null ? _stories[editIndex] : null,
        onSave: (entry) {
          setState(() {
            if (editIndex != null) { _stories[editIndex] = entry; }
            else                   { _stories.add(entry); }
          });
        },
      ),
    );
  }

  // ── Field helpers ─────────────────────────────────────────────────────────
  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool required = false, int maxLines = 1,
        TextInputType keyboardType = TextInputType.text,
        String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _dec(label, icon),
      validator: validator ?? (required
          ? (v) => v == null || v.trim().isEmpty ? 'Required field' : null
          : null),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: KCA.navy),
    filled: true, fillColor: const Color(0xFFF0F2F8),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: KCA.navy, width: 2)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: KCA.error)),
    labelStyle: const TextStyle(color: KCA.navy),
  );

  IconData _catIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'scholarships':   return Icons.school;
      case 'infrastructure': return Icons.business;
      case 'research':       return Icons.science;
      case 'health':         return Icons.health_and_safety;
      case 'technology':     return Icons.computer;
      case 'community':      return Icons.groups;
      default:               return Icons.favorite;
    }
  }
}

// ── Tile widgets (displayed inside the Impact & Stories tab) ──────────────────
class _MetricTile extends StatelessWidget {
  final Map<String, String> data;
  final VoidCallback onEdit, onDelete;
  const _MetricTile({required this.data, required this.onEdit, required this.onDelete});

  static const _iconMap = <String, IconData>{
    'star':      Icons.star_outline,
    'school':    Icons.school_outlined,
    'people':    Icons.people_outline,
    'home':      Icons.home_outlined,
    'science':   Icons.science_outlined,
    'volunteer': Icons.volunteer_activism_outlined,
    'money':     Icons.attach_money,
    'check':     Icons.check_circle_outline,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _iconMap[data['icon'] ?? 'star'] ?? Icons.star_outline;
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDDDDDD))),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: KCA.navy.withAlpha(15),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: KCA.navy, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['value'] ?? '', style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: KCA.navy)),
            Text(data['label'] ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ])),
          IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: KCA.navy),
              onPressed: onEdit),
          IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              onPressed: onDelete),
        ]));
  }
}

class _MilestoneTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit, onDelete;
  const _MilestoneTile({required this.data, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final pct      = data['percentage'] as int?  ?? 0;
    final achieved = data['achieved']   as bool? ?? false;
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: achieved ? const Color(0xFFD1FAE5) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: achieved ? const Color(0xFF10B981) : const Color(0xFFDDDDDD))),
        child: Row(children: [
          Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                  color: achieved ? const Color(0xFF10B981) : KCA.navy,
                  shape: BoxShape.circle),
              child: Center(child: Text('$pct%',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 11)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(data['title'] as String? ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 13, color: KCA.navy))),
              if (achieved)
                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
            ]),
            if ((data['description'] as String? ?? '').isNotEmpty)
              Text(data['description'] as String,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ])),
          IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: KCA.navy),
              onPressed: onEdit),
          IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              onPressed: onDelete),
        ]));
  }
}

class _StoryTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit, onDelete;
  const _StoryTile({required this.data, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name      = data['name']       as String? ?? '';
    final role      = data['role']       as String? ?? '';
    final story     = data['story']      as String? ?? '';
    final mediaType = data['media_type'] as String? ?? 'none';
    final photoUrl  = data['photo_url']  as String? ?? '';
    final videoUrl  = data['video_url']  as String? ?? '';

    return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Media preview strip ─────────────────────────────────────────
          if (mediaType == 'photo' && photoUrl.isNotEmpty)
            ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: CachedNetworkImage(
                  imageUrl: photoUrl,
                  height: 130, width: double.infinity, fit: BoxFit.cover,
                  placeholder: (_, __) => Container(height: 130,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                  errorWidget: (_, __, ___) => Container(height: 130,
                      color: Colors.grey[100],
                      child: const Icon(Icons.image_not_supported, color: Colors.grey)),
                )),
          if (mediaType == 'video' && videoUrl.isNotEmpty)
            Container(
                height: 90,
                decoration: BoxDecoration(
                    color: const Color(0xFF0F0F1E),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.play_circle_outline_rounded,
                      color: Color(0xFFF5A800), size: 36),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    videoUrl.contains('youtube') ? '▶  YouTube video' : '▶  Uploaded video',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  )),
                ])),
          // ── Person info ─────────────────────────────────────────────────
          Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(radius: 20,
                    backgroundColor: KCA.gold.withAlpha(40),
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: KCA.navy,
                            fontWeight: FontWeight.bold, fontSize: 16))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13, color: KCA.navy)),
                  if (role.isNotEmpty)
                    Text(role, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  if (story.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text('"$story"',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600],
                            fontStyle: FontStyle.italic, height: 1.4),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ])),
                Column(children: [
                  IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: KCA.navy),
                      onPressed: onEdit),
                  IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      onPressed: onDelete),
                ]),
              ])),
        ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Story dialog — full StatefulWidget that manages async photo/video upload
// ─────────────────────────────────────────────────────────────────────────────
class _StoryDialog extends StatefulWidget {
  final String              campaignId;
  final int                 storyIndex;
  final Map<String, dynamic>? existing;
  final void Function(Map<String, dynamic> entry) onSave;

  const _StoryDialog({
    required this.campaignId,
    required this.storyIndex,
    required this.onSave,
    this.existing,
  });

  @override
  State<_StoryDialog> createState() => _StoryDialogState();
}

class _StoryDialogState extends State<_StoryDialog>
    with SingleTickerProviderStateMixin {

  late TabController _tabs;
  final _nameCtrl  = TextEditingController();
  final _roleCtrl  = TextEditingController();
  final _storyCtrl = TextEditingController();
  final _urlCtrl   = TextEditingController();

  String _mediaType = 'none'; // 'none' | 'photo' | 'video'
  String _photoUrl  = '';
  String _videoUrl  = '';

  // Upload state
  bool   _selecting = false;  // true while file picker dialog is open
  bool   _uploading = false;
  double _progress  = 0;
  String _uploadMsg = '';

  // Local preview
  Uint8List?   _photoPreview;
  PickedMedia? _pickedVideo;   // holds picked video until upload completes

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text  = e['name']  as String? ?? '';
      _roleCtrl.text  = e['role']  as String? ?? '';
      _storyCtrl.text = e['story'] as String? ?? '';
      _mediaType      = e['media_type'] as String? ?? 'none';
      _photoUrl       = e['photo_url']  as String? ?? '';
      _videoUrl       = e['video_url']  as String? ?? '';
      if (_videoUrl.isNotEmpty && !_videoUrl.contains('firebase')) {
        _urlCtrl.text = _videoUrl;
      }
      // Pre-select the right tab
      if (_mediaType == 'photo') _tabs.animateTo(1);
      if (_mediaType == 'video') _tabs.animateTo(2);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _storyCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  // ── Pick & upload photo ─────────────────────────────────────────────────
  Future<void> _pickPhoto({bool fromCamera = false}) async {
    // Show "selecting" state immediately so the UI doesn't look frozen
    setState(() { _selecting = true; _uploadMsg = ''; });
    final file = await StoryMediaService.pickPhoto(fromCamera: fromCamera);
    if (!mounted) return;
    if (file == null) {
      setState(() => _selecting = false);
      return;
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      setState(() {
        _selecting = false;
        _uploadMsg = '✗ Photo too large — max 5 MB';
      });
      return;
    }
    setState(() {
      _selecting    = false;
      _photoPreview = bytes;
      _uploading    = true;
      _uploadMsg    = 'Uploading photo…';
      _progress     = 0;
    });
    final url = await StoryMediaService.uploadStoryPhoto(
      campaignId:  widget.campaignId,
      storyIndex:  widget.storyIndex,
      file:        file,
      onProgress:  (p) { if (mounted) setState(() => _progress = p); },
    );
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (url != null) {
        _photoUrl  = url;
        _mediaType = 'photo';
        _uploadMsg = '✓ Photo uploaded successfully';
      } else {
        _uploadMsg = '✗ Upload failed — check connection and try again';
      }
    });
  }

  // ── Pick & upload video ─────────────────────────────────────────────────
  Future<void> _pickVideo() async {
    // Show feedback immediately — picker dialog can take a few seconds to open
    setState(() { _selecting = true; _uploadMsg = ''; _pickedVideo = null; });
    final media = await StoryMediaService.pickVideo();
    if (!mounted) return;
    if (media == null) {
      setState(() => _selecting = false);
      return;
    }
    // Size validation before uploading
    if (media.isTooBig) {
      setState(() {
        _selecting = false;
        _uploadMsg = '✗ Video too large (${media.sizeLabel}) — max 150 MB.'
            ' Use YouTube URL instead for larger videos.';
      });
      return;
    }
    setState(() {
      _selecting     = false;
      _pickedVideo   = media;
      _uploading     = true;
      _uploadMsg     = 'Uploading ${media.sizeLabel}…';
      _progress      = 0;
    });
    final url = await StoryMediaService.uploadStoryVideo(
      campaignId:  widget.campaignId,
      storyIndex:  widget.storyIndex,
      media:       media,
      onProgress:  (p) { if (mounted) setState(() => _progress = p); },
    );
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (url != null) {
        _videoUrl  = url;
        _mediaType = 'video';
        _uploadMsg = '✓ Video uploaded successfully';
      } else {
        _pickedVideo = null;
        _uploadMsg = '✗ Upload failed — check your connection and try again.\n'
            'Tip: for large videos, paste a YouTube URL instead.';
      }
    });
  }

  // ── Save YouTube / external URL ──────────────────────────────────────────
  void _saveVideoUrl() {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _videoUrl  = url;
      _mediaType = 'video';
      _uploadMsg = '✓ Video URL saved';
    });
  }

  void _clearMedia() {
    setState(() {
      _mediaType   = 'none';
      _photoUrl    = '';
      _videoUrl    = '';
      _photoPreview = null;
      _pickedVideo = null;
      _selecting   = false;
      _uploading   = false;
      _urlCtrl.clear();
      _uploadMsg   = '';
      _progress    = 0;
    });
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty || _storyCtrl.text.trim().isEmpty) return;
    widget.onSave({
      'name':       _nameCtrl.text.trim(),
      'role':       _roleCtrl.text.trim(),
      'story':      _storyCtrl.text.trim(),
      'media_type': _mediaType,
      'photo_url':  _photoUrl,
      'video_url':  _videoUrl,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:  560,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // ── Header ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            decoration: const BoxDecoration(
              color: KCA.navy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: KCA.gold.withAlpha(30),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.format_quote_rounded,
                        color: KCA.gold, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isEdit ? 'Edit Story' : 'Add Beneficiary Story',
                          style: const TextStyle(color: KCA.white, fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text('Add photos, videos or just text testimony',
                          style: TextStyle(color: Colors.white.withAlpha(160),
                              fontSize: 11)),
                    ])),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 10),
              TabBar(
                controller: _tabs,
                indicatorColor: KCA.gold,
                indicatorWeight: 3,
                labelColor: KCA.gold,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: const [
                  Tab(icon: Icon(Icons.person_outline, size: 15), text: 'Details'),
                  Tab(icon: Icon(Icons.photo_camera, size: 15),   text: 'Photo'),
                  Tab(icon: Icon(Icons.videocam_outlined, size: 15), text: 'Video'),
                ],
              ),
            ]),
          ),

          // ── Tab content ──────────────────────────────────────────────────
          Expanded(child: TabBarView(controller: _tabs, children: [

            // ── TAB 1: Person details ──────────────────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(children: [
                _field(_nameCtrl, 'Full Name *', Icons.person_outline),
                const SizedBox(height: 12),
                _field(_roleCtrl, 'Role  (e.g. "Scholarship Recipient, Class of 2023")',
                    Icons.badge_outlined),
                const SizedBox(height: 12),
                _field(_storyCtrl, 'Their testimony / story *', Icons.format_quote,
                    maxLines: 5),
                const SizedBox(height: 16),
                // Media summary badge
                if (_mediaType != 'none')
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                          color: KCA.success.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: KCA.success.withAlpha(60))),
                      child: Row(children: [
                        Icon(
                            _mediaType == 'photo'
                                ? Icons.check_circle_outline_rounded
                                : Icons.videocam_outlined,
                            color: KCA.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          _mediaType == 'photo'
                              ? 'Photo attached ✓'
                              : 'Video attached ✓  (${_videoUrl.contains('youtube') ? "YouTube link" : "Uploaded file"})',
                          style: const TextStyle(
                              color: KCA.success, fontWeight: FontWeight.w600, fontSize: 13),
                        )),
                        TextButton(
                            onPressed: _clearMedia,
                            child: const Text('Remove',
                                style: TextStyle(color: Colors.red, fontSize: 12))),
                      ])),
                if (_mediaType == 'none')
                  Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF0F2F8),
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Icon(Icons.info_outline, color: Colors.grey[500], size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'No media yet — use the Photo or Video tabs to attach media.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        )),
                      ])),
              ]),
            ),

            // ── TAB 2: Photo ───────────────────────────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(children: [
                // Preview area
                GestureDetector(
                  onTap: () => _showPhotoOptions(),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: _photoUrl.isNotEmpty
                                ? KCA.success
                                : Colors.grey[300]!,
                            width: 2)),
                    child: _photoPreview != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(13),
                        child: Image.memory(_photoPreview!, fit: BoxFit.cover))
                        : _photoUrl.isNotEmpty
                        ? ClipRRect(borderRadius: BorderRadius.circular(13),
                        child: CachedNetworkImage(imageUrl: _photoUrl,
                            fit: BoxFit.cover))
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text('Tap to add a photo',
                          style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Student photo, certificate, event photo…',
                          style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                // Upload buttons
                Row(children: [
                  Expanded(child: _mediaBtn(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: () => _pickPhoto(),
                  )),
                  const SizedBox(width: 12),
                  if (!kIsWeb) Expanded(child: _mediaBtn(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onTap: () => _pickPhoto(fromCamera: true),
                  )),
                ]),
                const SizedBox(height: 12),
                if (_uploading) _uploadProgress(),
                if (_uploadMsg.isNotEmpty && !_uploading)
                  _statusMsg(_uploadMsg),
                if (_photoUrl.isNotEmpty && !_uploading) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _clearMedia,
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    label: const Text('Remove photo', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ]),
            ),

            // ── TAB 3: Video ───────────────────────────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Option A: Upload video file
                _sectionLabel('Option A — Upload Video File'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!)),
                  child: Column(children: [
                    if (_pickedVideo != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          const Icon(Icons.video_file_outlined,
                              color: KCA.navy, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_pickedVideo?.name ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600,
                                  fontSize: 13, color: KCA.navy),
                              overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                    if (_selecting)
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                              color: KCA.navy.withAlpha(8),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: KCA.navy.withAlpha(30))),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: KCA.navy)),
                            SizedBox(width: 10),
                            Text('Opening file picker…',
                                style: TextStyle(color: KCA.navy,
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                          ]))
                    else
                      _mediaBtn(
                        icon: Icons.video_library_outlined,
                        label: _pickedVideo == null
                            ? 'Pick video from device'
                            : 'Change video  (${_pickedVideo!.sizeLabel})',
                        onTap: _uploading ? null : _pickVideo,
                      ),
                    if (_uploading) ...[
                      const SizedBox(height: 12),
                      _uploadProgress(),
                    ],
                  ]),
                ),
                const SizedBox(height: 20),

                // Option B: YouTube / external URL
                _sectionLabel('Option B — YouTube or External URL'),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlCtrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: 'https://youtube.com/watch?v=...',
                    prefixIcon: const Icon(Icons.link, color: KCA.navy),
                    filled: true, fillColor: const Color(0xFFF0F2F8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: KCA.navy, width: 2)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveVideoUrl,
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Use this URL'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KCA.navy, foregroundColor: KCA.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    )),
                if (_uploadMsg.isNotEmpty && !_uploading) ...[
                  const SizedBox(height: 8),
                  _statusMsg(_uploadMsg),
                ],
                if (_videoUrl.isNotEmpty && !_uploading) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _clearMedia,
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    label: const Text('Remove video', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ]),
            ),

          ])),

          // ── Action buttons ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                boxShadow: [BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 4, offset: const Offset(0, -2))]),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel'),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: _uploading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KCA.navy, foregroundColor: KCA.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _uploading
                    ? const SizedBox(height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(KCA.white)))
                    : Text(isEdit ? 'Save Changes' : 'Add Story',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
            ]),
          ),

        ]),
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────
  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: KCA.navy),
        filled: true, fillColor: const Color(0xFFF0F2F8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: KCA.navy, width: 2)),
        labelStyle: const TextStyle(color: KCA.navy),
      ),
    );
  }

  Widget _mediaBtn({
    required IconData   icon,
    required String     label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
                color: KCA.navy.withAlpha(onTap == null ? 8 : 15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: KCA.navy.withAlpha(onTap == null ? 20 : 50))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: onTap == null ? Colors.grey : KCA.navy, size: 20),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(
                  color: onTap == null ? Colors.grey : KCA.navy,
                  fontWeight: FontWeight.w600, fontSize: 13)),
            ])));
  }

  Widget _uploadProgress() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 6,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(KCA.navy),
          )),
      const SizedBox(height: 4),
      Text('${(_progress * 100).toStringAsFixed(0)}% uploaded…',
          style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ]);
  }

  Widget _statusMsg(String msg) {
    final ok = msg.startsWith('✓');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: ok ? KCA.success.withAlpha(15) : Colors.red.withAlpha(15),
          borderRadius: BorderRadius.circular(8)),
      child: Text(msg, style: TextStyle(
          fontSize: 12,
          color: ok ? KCA.success : Colors.red,
          fontWeight: FontWeight.w600)),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label, style: const TextStyle(
        fontWeight: FontWeight.bold, fontSize: 13, color: KCA.navy));
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Select Photo', style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: KCA.navy)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _mediaBtn(
                  icon: Icons.photo_library_outlined, label: 'Gallery',
                  onTap: () { Navigator.pop(context); _pickPhoto(); },
                )),
                if (!kIsWeb) ...[
                  const SizedBox(width: 12),
                  Expanded(child: _mediaBtn(
                    icon: Icons.camera_alt_outlined, label: 'Camera',
                    onTap: () { Navigator.pop(context); _pickPhoto(fromCamera: true); },
                  )),
                ],
              ]),
            ])));
  }
}