// lib/screens/campaign/campaign_detail_screen.dart
// spell-checker: disable

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/routes.dart';
import '../../models/campaign.dart';
import '../../services/story_media_service.dart';

const _navy  = Color(0xFF1B2263);
const _gold  = Color(0xFFF5A800);
const _green = Color(0xFF10B981);
const _bg    = Color(0xFFF5F7FA);

// ─────────────────────────────────────────────────────────────────────────────
class CampaignDetailScreen extends StatelessWidget {
  final String campaignId;
  const CampaignDetailScreen({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('campaigns')
            .doc(campaignId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _navy));
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Campaign not found.'));
          }

          final data     = snap.data!.data() as Map<String, dynamic>;
          final campaign = Campaign.fromFirestore(campaignId, data);
          final pct      = campaign.progress;
          final raised   = campaign.raised;
          final goal     = campaign.goal;

          return CustomScrollView(
            slivers: [
              // ── Hero App Bar ──────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () {},
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(fit: StackFit.expand, children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_navy, _categoryColor(campaign.category)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Positioned(right: -40, top: -40,
                        child: Container(width: 200, height: 200,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withAlpha(15)))),
                    Positioned(left: -30, bottom: -30,
                        child: Container(width: 150, height: 150,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withAlpha(10)))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(30),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withAlpha(60))),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(_categoryIcon(campaign.category), size: 14, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(campaign.category.toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 11,
                                          fontWeight: FontWeight.bold, letterSpacing: 1)),
                                ])),
                            const SizedBox(height: 10),
                            Text(campaign.title,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 22,
                                    fontWeight: FontWeight.bold, height: 1.2),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                          ]),
                    ),
                  ]),
                ),
              ),

              // ── Body ─────────────────────────────────────────────────────
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── Progress card ─────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10),
                            blurRadius: 8, offset: const Offset(0, 2))]),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('KES ${_fmt(raised)}',
                              style: const TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.bold, color: _navy)),
                          Text('raised of KES ${_fmt(goal)} goal',
                              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                        ])),
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: _progressColor(pct).withAlpha(25),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text('${(pct * 100).round()}%',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold,
                                    color: _progressColor(pct)))),
                      ]),
                      const SizedBox(height: 14),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                              value: pct, minHeight: 10,
                              backgroundColor: Colors.grey[100],
                              valueColor: AlwaysStoppedAnimation<Color>(_progressColor(pct)))),
                      const SizedBox(height: 16),
                      Row(children: [
                        _statChip(Icons.people_outline,
                            (data['donor_count'] as int? ?? 0).toString(), 'Donors'),
                        const SizedBox(width: 12),
                        if (campaign.endDate != null)
                          _statChip(Icons.event_outlined,
                              _daysLeft(campaign.endDate!), 'Days Left'),
                        const SizedBox(width: 12),
                        _statChip(Icons.verified_outlined,
                            campaign.isActive ? 'Active' : 'Closed', 'Status',
                            color: campaign.isActive ? _green : Colors.grey),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  // ── IMPACT METRICS ────────────────────────────────────────
                  if (campaign.impactMetrics.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.bar_chart_rounded,
                      title: 'Our Impact',
                      subtitle: 'What your donations have achieved',
                    ),
                    const SizedBox(height: 12),
                    _ImpactMetricsRow(metrics: campaign.impactMetrics),
                    const SizedBox(height: 24),
                  ],

                  // ── ABOUT ─────────────────────────────────────────────────
                  _SectionHeader(
                    icon: Icons.info_outline_rounded,
                    title: 'About This Campaign',
                  ),
                  const SizedBox(height: 12),
                  Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8),
                              blurRadius: 6, offset: const Offset(0, 2))]),
                      child: Text(
                          campaign.description.isNotEmpty
                              ? campaign.description
                              : 'Help KCA University Foundation reach this goal and create lasting impact for students and the community.',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.7))),
                  const SizedBox(height: 24),

                  // ── MILESTONES ────────────────────────────────────────────
                  if (campaign.milestones.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.flag_rounded,
                      title: 'Campaign Milestones',
                      subtitle: 'Funding checkpoints and what they unlock',
                    ),
                    const SizedBox(height: 12),
                    _MilestonesTimeline(
                      milestones: campaign.milestones,
                      currentPct: (pct * 100).round(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── BENEFICIARY STORIES ───────────────────────────────────
                  if (campaign.stories.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.format_quote_rounded,
                      title: 'Stories of Impact',
                      subtitle: 'Real people, real change',
                    ),
                    const SizedBox(height: 12),
                    _StoriesSection(stories: campaign.stories),
                    const SizedBox(height: 24),
                  ],

                  // ── RECENT DONATIONS ──────────────────────────────────────
                  _SectionHeader(
                    icon: Icons.favorite_rounded,
                    title: 'Recent Donations',
                  ),
                  const SizedBox(height: 12),
                  _RecentDonationsList(campaignId: campaignId),
                  const SizedBox(height: 100),
                ]),
              )),
            ],
          );
        },
      ),

      // ── Sticky Donate Button ───────────────────────────────────────────────
      bottomNavigationBar: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('campaigns').doc(campaignId).snapshots(),
        builder: (context, snap) {
          final data     = snap.data?.data() as Map<String, dynamic>?;
          final campaign = data != null
              ? Campaign.fromFirestore(campaignId, data) : null;
          final isActive = campaign?.isActive ?? true;

          return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(15),
                      blurRadius: 12, offset: const Offset(0, -3))]),
              child: ElevatedButton(
                  onPressed: (!isActive || campaign == null) ? null : () {
                    Navigator.pushNamed(context, AppRoutes.donationFlow,
                        arguments: {
                          'campaign':   campaign.toJson(),
                          'campaignId': campaignId,
                        });
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: isActive ? _navy : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: isActive ? 4 : 0),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(isActive ? Icons.favorite_outline : Icons.lock_outline, size: 20),
                    const SizedBox(width: 10),
                    Text(isActive ? 'Donate to This Campaign' : 'Campaign Closed',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ])));
        },
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, {Color color = _navy}) {
    return Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
            color: color.withAlpha(12), borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ])));
  }

  Color _progressColor(double pct) {
    if (pct >= 0.9) return _green;
    if (pct >= 0.5) return _navy;
    return _gold;
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  String _daysLeft(String endDate) {
    try {
      final end  = DateTime.parse(endDate);
      final diff = end.difference(DateTime.now()).inDays;
      return diff > 0 ? '$diff' : '0';
    } catch (_) { return '—'; }
  }

  IconData _categoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'scholarships':   return Icons.school;
      case 'infrastructure': return Icons.business;
      case 'research':       return Icons.science;
      case 'health':         return Icons.local_hospital_outlined;
      case 'community':      return Icons.people_outline;
      default:               return Icons.favorite;
    }
  }

  Color _categoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'scholarships':   return const Color(0xFF2563EB);
      case 'infrastructure': return const Color(0xFFF59E0B);
      case 'research':       return const Color(0xFF10B981);
      case 'health':         return const Color(0xFFEC4899);
      case 'community':      return const Color(0xFF8B5CF6);
      default:               return Colors.teal;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared section header widget
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String?  subtitle;
  const _SectionHeader({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: _navy.withAlpha(15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: _navy, size: 18)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
        if (subtitle != null)
          Text(subtitle!, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ])),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Impact Metrics — horizontal scrolling cards
// ─────────────────────────────────────────────────────────────────────────────
class _ImpactMetricsRow extends StatelessWidget {
  final List<ImpactMetric> metrics;
  const _ImpactMetricsRow({required this.metrics});

  static const _iconMap = <String, IconData>{
    'star':      Icons.star_rounded,
    'school':    Icons.school_rounded,
    'people':    Icons.people_rounded,
    'home':      Icons.home_rounded,
    'science':   Icons.science_rounded,
    'volunteer': Icons.volunteer_activism_rounded,
    'money':     Icons.attach_money_rounded,
    'check':     Icons.check_circle_rounded,
  };

  static const _colors = [_navy, _green, _gold,
    Color(0xFF8B5CF6), Color(0xFFEC4899)];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 114,
      child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: metrics.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (ctx, i) {
            final m     = metrics[i];
            final color = _colors[i % _colors.length];
            final icon  = _iconMap[m.icon] ?? Icons.star_rounded;
            return Container(
                width: 136,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(8),
                        blurRadius: 6, offset: const Offset(0, 2))],
                    border: Border(left: BorderSide(color: color, width: 4))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: color, size: 22),
                      const SizedBox(height: 6),
                      Text(m.value,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                      const SizedBox(height: 2),
                      Text(m.label,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.3),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ]));
          }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Milestones — vertical timeline
// ─────────────────────────────────────────────────────────────────────────────
class _MilestonesTimeline extends StatelessWidget {
  final List<CampaignMilestone> milestones;
  final int currentPct;
  const _MilestonesTimeline({required this.milestones, required this.currentPct});

  @override
  Widget build(BuildContext context) {
    final sorted = [...milestones]
      ..sort((a, b) => a.percentage.compareTo(b.percentage));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8),
              blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(
        children: sorted.asMap().entries.map((entry) {
          final i      = entry.key;
          final m      = entry.value;
          final isLast = i == sorted.length - 1;
          final reached = m.achieved || currentPct >= m.percentage;

          return IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Timeline column
              SizedBox(width: 42, child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: reached ? _green : _bg,
                          border: Border.all(
                              color: reached ? _green : Colors.grey[300]!, width: 2)),
                      child: Center(
                          child: reached
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                              : Text('${m.percentage}%',
                              style: TextStyle(fontSize: 10,
                                  fontWeight: FontWeight.bold, color: Colors.grey[500])))),
                  if (!isLast)
                    Expanded(child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: reached ? _green.withAlpha(80) : Colors.grey[200]))),
                ],
              )),
              const SizedBox(width: 14),

              // Content
              Expanded(child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Text(m.title,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                            color: reached ? _navy : Colors.grey[500]))),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: reached ? _green.withAlpha(20) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(reached ? 'Reached' : 'At ${m.percentage}%',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                color: reached ? _green : Colors.grey[500]))),
                  ]),
                  if (m.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(m.description,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4)),
                  ],
                ]),
              )),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Beneficiary Stories — rich media cards with photo/video + expandable text
// ─────────────────────────────────────────────────────────────────────────────
class _StoriesSection extends StatefulWidget {
  final List<BeneficiaryStory> stories;
  const _StoriesSection({required this.stories});

  @override
  State<_StoriesSection> createState() => _StoriesSectionState();
}

class _StoriesSectionState extends State<_StoriesSection> {
  // Which story's text is fully expanded (-1 = none)
  int _expanded = -1;

  static const _colors = [
    Color(0xFF2563EB), Color(0xFF059669), Color(0xFFF59E0B),
    Color(0xFF7C3AED), Color(0xFFDB2777),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: widget.stories.asMap().entries.map((entry) {
        final i      = entry.key;
        final s      = entry.value;
        final color  = _colors[i % _colors.length];
        final isOpen = _expanded == i;
        return _StoryCard(
          story:   s,
          color:   color,
          isOpen:  isOpen,
          onToggle: () => setState(() => _expanded = isOpen ? -1 : i),
        );
      }).toList(),
    );
  }
}

// ── Single story card ─────────────────────────────────────────────────────────
class _StoryCard extends StatelessWidget {
  final BeneficiaryStory story;
  final Color   color;
  final bool    isOpen;
  final VoidCallback onToggle;
  const _StoryCard({
    required this.story, required this.color,
    required this.isOpen, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final initial = story.name.isNotEmpty ? story.name[0].toUpperCase() : '?';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isOpen ? color : Colors.grey.withAlpha(35), width: 2),
          boxShadow: [BoxShadow(
              color: Colors.black.withAlpha(isOpen ? 16 : 7),
              blurRadius: isOpen ? 14 : 6,
              offset: const Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Photo (if any) ───────────────────────────────────────────────
        if (story.hasPhoto)
          GestureDetector(
            onTap: () => _openPhoto(context),
            child: Hero(
              tag: 'story_photo_${story.name}_${story.role}',
              child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: CachedNetworkImage(
                    imageUrl: story.photoUrl!,
                    height: 200, width: double.infinity, fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                        height: 200, color: Colors.grey[100],
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: _navy, strokeWidth: 2))),
                    errorWidget: (_, __, ___) => Container(
                        height: 200, color: Colors.grey[100],
                        child: const Center(
                            child: Icon(Icons.image_not_supported_outlined,
                                color: Colors.grey, size: 36))),
                  )),
            ),
          ),

        // ── Video (if any) ───────────────────────────────────────────────
        if (story.hasVideo && !story.isYoutube)
          Padding(
            padding: EdgeInsets.only(
                top: story.hasPhoto ? 0 : 0,
                left: 0, right: 0),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(story.hasPhoto ? 0 : 16)),
              child: StoryVideoCard(videoUrl: story.videoUrl!),
            ),
          ),

        if (story.hasVideo && story.isYoutube)
          _YoutubeCard(
            videoUrl: story.videoUrl!,
            roundTop: !story.hasPhoto,
          ),

        // ── Person header row ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Avatar with media-type badge
            Stack(clipBehavior: Clip.none, children: [
              Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                  child: Center(child: Text(initial,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 20)))),
              // Media badge
              if (story.hasPhoto || story.hasVideo)
                Positioned(bottom: -2, right: -2,
                    child: Container(
                        width: 20, height: 20,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Colors.white),
                        child: Center(child: Icon(
                            story.hasVideo ? Icons.videocam_rounded : Icons.photo_camera_rounded,
                            size: 13, color: color)))),
            ]),
            const SizedBox(width: 12),
            // Name + role
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(story.name, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
                  const SizedBox(height: 3),
                  if (story.role.isNotEmpty)
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: color.withAlpha(20),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(story.role,
                            style: TextStyle(fontSize: 11, color: color,
                                fontWeight: FontWeight.w600))),
                ])),
            // Expand/collapse button
            GestureDetector(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8),
                  child: AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey[400], size: 26)),
                )),
          ]),
        ),

        // ── Story text (collapsible) ─────────────────────────────────────
        GestureDetector(
          onTap: onToggle,
          child: AnimatedCrossFade(
            firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Text(
                    story.story.length > 110 ? '${story.story.substring(0, 110)}…' : story.story,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600],
                        fontStyle: FontStyle.italic, height: 1.5),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
            secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('❝', style: TextStyle(
                      fontSize: 36, color: color.withAlpha(80), height: 0.9)),
                  const SizedBox(height: 6),
                  Text(story.story, style: TextStyle(
                      fontSize: 14, color: Colors.grey[700],
                      fontStyle: FontStyle.italic, height: 1.7)),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: color.withAlpha(15),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('— ${story.name}',
                            style: TextStyle(fontSize: 12, color: color,
                                fontWeight: FontWeight.bold))),
                  ]),
                ])),
            crossFadeState: isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ),

        // ── Tap to expand hint (only when collapsed) ─────────────────────
        if (!isOpen && story.story.length > 110)
          Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 16),
              child: Text('Tap to read full story',
                  style: TextStyle(fontSize: 11, color: color,
                      fontWeight: FontWeight.w600))),

      ]),
    );
  }

  void _openPhoto(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent,
          foregroundColor: Colors.white, elevation: 0),
      body: Center(child: Hero(
        tag: 'story_photo_${story.name}_${story.role}',
        child: InteractiveViewer(
            child: CachedNetworkImage(imageUrl: story.photoUrl!)),
      )),
    )));
  }
}

// ── YouTube / Vimeo link card ─────────────────────────────────────────────────
class _YoutubeCard extends StatelessWidget {
  final String videoUrl;
  final bool   roundTop;
  const _YoutubeCard({required this.videoUrl, this.roundTop = true});

  String? get _thumbnailUrl {
    // Extract YouTube video ID and build thumbnail
    final uri = Uri.tryParse(videoUrl);
    if (uri == null) return null;
    String? id;
    if (uri.host.contains('youtu.be')) {
      id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    } else {
      id = uri.queryParameters['v'];
    }
    if (id == null) return null;
    return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _thumbnailUrl;
    return GestureDetector(
      onTap: () {
        // Open in browser / default video handler
        // Using url_launcher if available; otherwise show snackbar
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Opening: $videoUrl'),
          action: SnackBarAction(
            label: 'OK', onPressed: () {},
          ),
          duration: const Duration(seconds: 3),
        ));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(roundTop ? 16 : 0)),
        child: Stack(children: [
          // Thumbnail
          thumb != null
              ? CachedNetworkImage(
            imageUrl: thumb,
            height: 200, width: double.infinity, fit: BoxFit.cover,
            placeholder: (_, __) => Container(
                height: 200, color: const Color(0xFF0F0F1E)),
            errorWidget: (_, __, ___) => _darkBg(),
          )
              : _darkBg(),
          // Dark overlay + play button
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(100),
            ),
            child: Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                      color: const Color(0xFFFF0000),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 40)),
              const SizedBox(height: 8),
              const Text('Tap to watch on YouTube',
                  style: TextStyle(color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ])),
          ),
        ]),
      ),
    );
  }

  Widget _darkBg() => Container(
      height: 200, color: const Color(0xFF0F0F1E),
      child: const Center(child: Icon(Icons.videocam_outlined,
          color: Colors.white38, size: 48)));
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent Donations List
// ─────────────────────────────────────────────────────────────────────────────
class _RecentDonationsList extends StatelessWidget {
  final String campaignId;
  const _RecentDonationsList({required this.campaignId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('campaign_id', isEqualTo: campaignId)
            .where('status', isEqualTo: 'completed')
            .orderBy('created_at', descending: true)
            .limit(5)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: _navy)));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Icon(Icons.favorite_border, color: Colors.grey[300], size: 28),
                  const SizedBox(width: 14),
                  Text('Be the first to donate!',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                ]));
          }
          return Container(
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(8),
                      blurRadius: 6, offset: const Offset(0, 2))]),
              child: Column(children: docs.asMap().entries.map((e) {
                final d      = e.value.data() as Map<String, dynamic>;
                final name   = d['donor_name'] as String? ?? 'Anonymous';
                final amt    = (d['amount'] as num? ?? 0).toDouble();
                final ts     = d['created_at'] as String? ?? '';
                final isLast = e.key == docs.length - 1;
                return Column(children: [
                  ListTile(
                    leading: CircleAvatar(radius: 18,
                        backgroundColor: _navy.withAlpha(15),
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'A',
                            style: const TextStyle(color: _navy,
                                fontWeight: FontWeight.bold, fontSize: 14))),
                    title: Text(name, style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(_timeAgo(ts),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    trailing: Text('KES ${amt.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: _green, fontSize: 14)),
                  ),
                  if (!isLast) Divider(height: 1, color: Colors.grey[100]),
                ]);
              }).toList()));
        });
  }

  String _timeAgo(String iso) {
    try {
      final dt   = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours   < 24) return '${diff.inHours}h ago';
      if (diff.inDays    < 30) return '${diff.inDays}d ago';
      return '${(diff.inDays / 30).floor()}mo ago';
    } catch (_) { return ''; }
  }
}