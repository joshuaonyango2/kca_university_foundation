// lib/screens/impact/impact_screen.dart
// spell-checker: disable
//
// ✅ FIX: Reads campaign data directly from Firestore instead of relying on
//    Campaign.fromMap() or new Campaign model fields (donorCount, stories,
//    milestones, impactMetrics) which may not exist in the current model.
//    Zero changes needed to campaign.dart.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

const _navy = Color(0xFF1B2263);
const _gold = Color(0xFFF5A800);
const _bg   = Color(0xFFF5F6FA);

class ImpactScreen extends StatefulWidget {
  final String campaignId;
  const ImpactScreen({super.key, required this.campaignId});

  @override
  State<ImpactScreen> createState() => _ImpactScreenState();
}

class _ImpactScreenState extends State<ImpactScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // Raw data read directly from Firestore — no Campaign model needed
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('campaigns')
          .doc(widget.campaignId)
          .get();
      if (!mounted) return;
      setState(() {
        _data    = snap.exists ? snap.data() : null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Safe field accessors ────────────────────────────────────────────────
  String get _title    => _data?['title']     as String? ?? 'Campaign';
  String get _imageUrl => _data?['image_url'] as String? ?? '';
  double get _raised   => (_data?['raised']   as num?)?.toDouble() ?? 0;
  double get _goal     => (_data?['goal']     as num?)?.toDouble() ?? 1;
  bool   get _isActive => _data?['is_active'] as bool? ?? true;
  int    get _donorCount => (_data?['donor_count'] as num?)?.toInt() ?? 0;
  double get _progress => (_goal > 0 ? _raised / _goal : 0).clamp(0.0, 1.0).toDouble();

  // ✅ Safe list cast — works even if Firestore returns List<dynamic>
  List<Map<String, dynamic>> _listField(String key) {
    final raw = _data?[key];
    if (raw == null) return [];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> get _stories       => _listField('stories');
  List<Map<String, dynamic>> get _milestones    => _listField('milestones');
  List<Map<String, dynamic>> get _impactMetrics => _listField('impact_metrics');

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
          backgroundColor: _bg,
          appBar: _appBar('Loading…'),
          body: const Center(
              child: CircularProgressIndicator(color: _navy)));
    }
    if (_data == null) {
      return Scaffold(
          backgroundColor: _bg,
          appBar: _appBar('Not Found'),
          body: const Center(child: Text('Campaign not found.')));
    }
    return _buildBody();
  }

  AppBar _appBar(String t) => AppBar(
    backgroundColor: _navy,
    foregroundColor: Colors.white,
    title: Text(t,
        style: const TextStyle(fontWeight: FontWeight.bold)),
    centerTitle: true,
    bottom: PreferredSize(
        preferredSize: const Size.fromHeight(3),
        child: Container(height: 3, color: _gold)),
  );

  Widget _buildBody() => NestedScrollView(
    headerSliverBuilder: (ctx, _) => [
      // ── Hero ──────────────────────────────────────────────────────────
      SliverAppBar(
        expandedHeight: 260,
        pinned: true,
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        flexibleSpace: FlexibleSpaceBar(
          title: Text(_title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          background: Stack(fit: StackFit.expand, children: [
            _imageUrl.isNotEmpty
                ? CachedNetworkImage(
                imageUrl: _imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Container(color: _navy))
                : Container(color: _navy),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _navy.withAlpha(200)
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),

      // ── Progress header ───────────────────────────────────────────────
      SliverToBoxAdapter(child: _ProgressBanner(
        raised:     _raised,
        goal:       _goal,
        progress:   _progress,
        donorCount: _donorCount,
        isActive:   _isActive,
      )),

      // ── Tab bar ───────────────────────────────────────────────────────
      SliverPersistentHeader(
        pinned: true,
        delegate: _StickyTabBar(
          TabBar(
            controller: _tabs,
            labelColor: _navy,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _gold,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: 'Stories'),
              Tab(text: 'Milestones'),
              Tab(text: 'Impact'),
            ],
          ),
        ),
      ),
    ],
    body: TabBarView(
      controller: _tabs,
      children: [
        _StoriesTab(stories: _stories),
        _MilestonesTab(milestones: _milestones),
        _ImpactTab(metrics: _impactMetrics),
      ],
    ),
  );
}

// ─── Progress Banner ──────────────────────────────────────────────────────────
class _ProgressBanner extends StatelessWidget {
  final double raised, goal, progress;
  final int    donorCount;
  final bool   isActive;
  const _ProgressBanner({
    required this.raised,
    required this.goal,
    required this.progress,
    required this.donorCount,
    required this.isActive,
  });

  String _fmt(double v) {
    if (v >= 1000000) return 'KES ${(v/1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return 'KES ${(v/1000).toStringAsFixed(0)}K';
    return 'KES ${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) => Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_fmt(raised),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: _navy)),
                        Text('raised of ${_fmt(goal)}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ]),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: _gold.withAlpha(30),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                              color: _gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 16))),
                ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                  const AlwaysStoppedAnimation<Color>(_gold)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.people_outline,
                  size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text('$donorCount donors',
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12)),
              const SizedBox(width: 16),
              Icon(
                  isActive
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  size: 16,
                  color: isActive ? Colors.green : Colors.red),
              const SizedBox(width: 4),
              Text(isActive ? 'Active' : 'Closed',
                  style: TextStyle(
                      color: isActive ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ]));
}

// ─── Stories Tab ──────────────────────────────────────────────────────────────
class _StoriesTab extends StatelessWidget {
  final List<Map<String, dynamic>> stories;
  const _StoriesTab({required this.stories});

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return _emptyState(
          Icons.auto_stories_outlined, 'No beneficiary stories yet.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: stories.length,
      itemBuilder: (_, i) => _StoryCard(story: stories[i]),
    );
  }
}

class _StoryCard extends StatelessWidget {
  final Map<String, dynamic> story;
  const _StoryCard({required this.story});

  @override
  Widget build(BuildContext context) {
    final name     = story['name']      as String? ?? 'Anonymous';
    final text     = story['story']     as String? ?? '';
    final photoUrl = story['photo_url'] as String? ?? '';
    final videoUrl = story['video_url'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photoUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14)),
                child: CachedNetworkImage(
                    imageUrl: photoUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                        height: 120,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image,
                            color: Colors.grey))),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(
                          radius: 18,
                          backgroundColor: _navy.withAlpha(25),
                          child: Text(name[0].toUpperCase(),
                              style: const TextStyle(
                                  color: _navy,
                                  fontWeight: FontWeight.bold))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _navy))),
                    ]),
                    if (text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(text,
                          style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.6)),
                    ],
                    if (videoUrl.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _VideoThumbnail(url: videoUrl),
                    ],
                  ]),
            ),
          ]),
    );
  }
}

class _VideoThumbnail extends StatelessWidget {
  final String url;
  const _VideoThumbnail({required this.url});

  String? _ytId(String u) {
    final uri = Uri.tryParse(u);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first : null;
    }
    return uri.queryParameters['v'];
  }

  @override
  Widget build(BuildContext context) {
    final id    = _ytId(url);
    final thumb = id != null
        ? 'https://img.youtube.com/vi/$id/hqdefault.jpg'
        : null;

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) launchUrl(uri);
      },
      child: Stack(alignment: Alignment.center, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: thumb != null
              ? CachedNetworkImage(
              imageUrl: thumb,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                  height: 160, color: Colors.grey.shade300))
              : Container(
              height: 160,
              width: double.infinity,
              color: Colors.grey.shade300,
              child: const Icon(Icons.video_library,
                  size: 48, color: Colors.grey)),
        ),
        Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
                color: _gold, shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow,
                color: Colors.white, size: 32)),
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4)),
              child: const Text('Watch Story',
                  style: TextStyle(
                      color: Colors.white, fontSize: 12))),
        ),
      ]),
    );
  }
}

// ─── Milestones Tab ───────────────────────────────────────────────────────────
class _MilestonesTab extends StatelessWidget {
  final List<Map<String, dynamic>> milestones;
  const _MilestonesTab({required this.milestones});

  @override
  Widget build(BuildContext context) {
    if (milestones.isEmpty) {
      return _emptyState(
          Icons.flag_outlined, 'No milestones defined yet.');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 20),
      itemCount: milestones.length,
      itemBuilder: (_, i) {
        final m       = milestones[i];
        final title   = m['title']          as String? ?? '';
        final desc    = m['description']    as String? ?? '';
        final target  = (m['target_amount'] as num?)?.toDouble() ?? 0;
        final reached = m['is_reached']     as bool?   ?? false;
        final isLast  = i == milestones.length - 1;

        return IntrinsicHeight(
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(children: [
                  Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                          color: reached
                              ? _gold : Colors.grey.shade300,
                          shape: BoxShape.circle),
                      child: Icon(
                          reached
                              ? Icons.check
                              : Icons.radio_button_unchecked,
                          color: reached
                              ? Colors.white : Colors.grey,
                          size: 16)),
                  if (!isLast)
                    Expanded(
                        child: Container(
                            width: 2,
                            color: reached
                                ? _gold.withAlpha(80)
                                : Colors.grey.shade200)),
                ]),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: reached
                              ? _gold.withAlpha(20)
                              : Colors.white,
                          border: Border.all(
                              color: reached
                                  ? _gold.withAlpha(80)
                                  : Colors.grey.shade200),
                          borderRadius:
                          BorderRadius.circular(12)),
                      child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(title,
                                        style: TextStyle(
                                            fontWeight:
                                            FontWeight.bold,
                                            fontSize: 15,
                                            color: reached
                                                ? _gold : _navy)),
                                  ),
                                  if (reached)
                                    Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 8,
                                            vertical: 3),
                                        decoration: BoxDecoration(
                                            color: _gold,
                                            borderRadius:
                                            BorderRadius
                                                .circular(10)),
                                        child: const Text(
                                            '✓ Reached',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight:
                                                FontWeight.bold))),
                                ]),
                            if (desc.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(desc,
                                  style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 13,
                                      height: 1.5)),
                            ],
                            if (target > 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                  'Target: ${_fmt(target)}',
                                  style: TextStyle(
                                      color: reached
                                          ? _gold : Colors.grey,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ],
                          ]),
                    ),
                  ),
                ),
              ]),
        );
      },
    );
  }

  String _fmt(double v) => v >= 1000
      ? 'KES ${(v / 1000).toStringAsFixed(0)}K'
      : 'KES ${v.toStringAsFixed(0)}';
}

// ─── Impact Metrics Tab ───────────────────────────────────────────────────────
class _ImpactTab extends StatelessWidget {
  final List<Map<String, dynamic>> metrics;
  const _ImpactTab({required this.metrics});

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return _emptyState(
          Icons.insights_outlined, 'No impact metrics yet.');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.05),
      itemCount: metrics.length,
      itemBuilder: (_, i) {
        final m     = metrics[i];
        final label = m['label']?.toString() ?? '';
        final value = m['value']?.toString() ?? '';
        return Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ]),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                        color: _gold.withAlpha(30),
                        shape: BoxShape.circle),
                    child: Icon(_icon(label),
                        color: _gold, size: 26)),
                const SizedBox(height: 10),
                Text(value,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _navy)),
                const SizedBox(height: 4),
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ),
              ]),
        );
      },
    );
  }

  IconData _icon(String label) {
    final l = label.toLowerCase();
    if (l.contains('student') || l.contains('scholar'))
      return Icons.school;
    if (l.contains('job') || l.contains('employ'))
      return Icons.work;
    if (l.contains('communit') || l.contains('people'))
      return Icons.people;
    if (l.contains('project') || l.contains('build'))
      return Icons.construction;
    if (l.contains('research')) return Icons.biotech;
    return Icons.star;
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────
Widget _emptyState(IconData icon, String msg) => Center(
  child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 14),
        Text(msg,
            style: const TextStyle(
                color: Colors.grey, fontSize: 15)),
      ]),
);

class _StickyTabBar extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _StickyTabBar(this.tabBar);
  @override double get minExtent => tabBar.preferredSize.height;
  @override double get maxExtent => tabBar.preferredSize.height;
  @override Widget build(
      BuildContext ctx, double shrink, bool overlaps) =>
      Container(color: Colors.white, child: tabBar);
  @override bool shouldRebuild(_StickyTabBar old) => false;
}
