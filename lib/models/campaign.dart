// lib/models/campaign.dart

// ── Impact metric ─────────────────────────────────────────────────────────────
class ImpactMetric {
  final String label;
  final String value;
  final String icon;

  const ImpactMetric({
    required this.label,
    required this.value,
    this.icon = 'star',
  });

  factory ImpactMetric.fromJson(Map<String, dynamic> j) => ImpactMetric(
    label: j['label'] as String? ?? '',
    value: j['value'] as String? ?? '',
    icon:  j['icon']  as String? ?? 'star',
  );

  Map<String, dynamic> toJson() => {'label': label, 'value': value, 'icon': icon};
}

// ── Milestone ─────────────────────────────────────────────────────────────────
class CampaignMilestone {
  final String title;
  final String description;
  final int    percentage;
  final bool   achieved;

  const CampaignMilestone({
    required this.title,
    required this.description,
    required this.percentage,
    this.achieved = false,
  });

  factory CampaignMilestone.fromJson(Map<String, dynamic> j) => CampaignMilestone(
    title:       j['title']       as String? ?? '',
    description: j['description'] as String? ?? '',
    percentage:  (j['percentage'] as num?    ?? 0).toInt(),
    achieved:    j['achieved']    as bool?   ?? false,
  );

  Map<String, dynamic> toJson() => {
    'title':       title,
    'description': description,
    'percentage':  percentage,
    'achieved':    achieved,
  };
}

// ── Beneficiary story with rich media ─────────────────────────────────────────
// mediaType: 'none' | 'photo' | 'video'
class BeneficiaryStory {
  final String  name;
  final String  role;
  final String  story;
  final String  mediaType;   // 'none' | 'photo' | 'video'
  final String? photoUrl;    // Firebase Storage download URL
  final String? videoUrl;    // Firebase Storage URL or YouTube/Vimeo link

  const BeneficiaryStory({
    required this.name,
    required this.role,
    required this.story,
    this.mediaType = 'none',
    this.photoUrl,
    this.videoUrl,
  });

  bool get hasPhoto => mediaType == 'photo' && (photoUrl?.isNotEmpty ?? false);
  bool get hasVideo => mediaType == 'video' && (videoUrl?.isNotEmpty ?? false);
  bool get isYoutube => hasVideo &&
      (videoUrl!.contains('youtube.com') || videoUrl!.contains('youtu.be'));

  factory BeneficiaryStory.fromJson(Map<String, dynamic> j) => BeneficiaryStory(
    name:      j['name']       as String? ?? '',
    role:      j['role']       as String? ?? '',
    story:     j['story']      as String? ?? '',
    mediaType: j['media_type'] as String? ?? 'none',
    photoUrl:  j['photo_url']  as String?,
    videoUrl:  j['video_url']  as String?,
  );

  Map<String, dynamic> toJson() => {
    'name':       name,
    'role':       role,
    'story':      story,
    'media_type': mediaType,
    'photo_url':  photoUrl,
    'video_url':  videoUrl,
  };
}

// ── Campaign ──────────────────────────────────────────────────────────────────
class Campaign {
  final String  id;
  final String  title;
  final String  description;
  final String  category;
  final double  goal;
  final double  raised;
  final String? imageUrl;
  final bool    isActive;
  final String? endDate;
  final String? startDate;
  final List<ImpactMetric>      impactMetrics;
  final List<CampaignMilestone> milestones;
  final List<BeneficiaryStory>  stories;

  const Campaign({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.goal,
    required this.raised,
    this.imageUrl,
    this.isActive      = true,
    this.endDate,
    this.startDate,
    this.impactMetrics = const [],
    this.milestones    = const [],
    this.stories       = const [],
  });

  double get progress           => goal > 0 ? (raised / goal).clamp(0.0, 1.0) : 0.0;
  int    get progressPercentage => (progress * 100).round();

  factory Campaign.fromJson(Map<String, dynamic> json) {
    List<T> _parse<T>(String key, T Function(Map<String, dynamic>) fn) {
      final raw = json[key];
      if (raw == null) return [];
      if (raw is List) {
        return raw.map((e) => fn(Map<String, dynamic>.from(e as Map))).toList();
      }
      return [];
    }

    return Campaign(
      id:            json['id']          as String? ?? '',
      title:         json['title']       as String? ?? '',
      description:   json['description'] as String? ?? '',
      category:      json['category']    as String? ?? 'general',
      goal:          (json['goal']       as num?    ?? 0).toDouble(),
      raised:        (json['raised']     as num?    ?? 0).toDouble(),
      imageUrl:      json['image_url']   as String?,
      isActive:      json['is_active']   as bool?   ?? true,
      endDate:       json['end_date']    as String?,
      startDate:     json['start_date']  as String?,
      impactMetrics: _parse('impact_metrics', ImpactMetric.fromJson),
      milestones:    _parse('milestones',     CampaignMilestone.fromJson),
      stories:       _parse('stories',        BeneficiaryStory.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
    'id':             id,
    'title':          title,
    'description':    description,
    'category':       category,
    'goal':           goal,
    'raised':         raised,
    'image_url':      imageUrl,
    'is_active':      isActive,
    'end_date':       endDate,
    'start_date':     startDate,
    'impact_metrics': impactMetrics.map((m) => m.toJson()).toList(),
    'milestones':     milestones.map((m) => m.toJson()).toList(),
    'stories':        stories.map((s) => s.toJson()).toList(),
  };

  factory Campaign.fromFirestore(String docId, Map<String, dynamic> data) =>
      Campaign.fromJson({'id': docId, ...data});

  Campaign copyWith({
    String? id, String? title, String? description,
    String? category, double? goal, double? raised,
    String? imageUrl, bool? isActive, String? endDate, String? startDate,
    List<ImpactMetric>?      impactMetrics,
    List<CampaignMilestone>? milestones,
    List<BeneficiaryStory>?  stories,
  }) => Campaign(
    id:            id            ?? this.id,
    title:         title         ?? this.title,
    description:   description   ?? this.description,
    category:      category      ?? this.category,
    goal:          goal          ?? this.goal,
    raised:        raised        ?? this.raised,
    imageUrl:      imageUrl      ?? this.imageUrl,
    isActive:      isActive      ?? this.isActive,
    endDate:       endDate       ?? this.endDate,
    startDate:     startDate     ?? this.startDate,
    impactMetrics: impactMetrics ?? this.impactMetrics,
    milestones:    milestones    ?? this.milestones,
    stories:       stories       ?? this.stories,
  );
}