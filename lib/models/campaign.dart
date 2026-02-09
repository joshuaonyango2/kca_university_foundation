// lib/models/campaign.dart

  class Campaign {
  final String campaignId;
  final String title;
  final String slug;
  final String description;
  final String category;
  final double goalAmount;
  final double currentAmount;
  final String currency;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final bool featured;
  final String? imageUrl;
  final String? videoUrl;
  final double progressPercentage;
  final int? totalDonors;

  Campaign({
    required this.campaignId,
    required this.title,
    required this.slug,
    required this.description,
    required this.category,
    required this.goalAmount,
    required this.currentAmount,
    required this.currency,
    this.startDate,
    this.endDate,
    required this.status,
    required this.featured,
    this.imageUrl,
    this.videoUrl,
    required this.progressPercentage,
    this.totalDonors,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      campaignId: json['campaign_id'],
      title: json['title'],
      slug: json['slug'],
      description: json['description'] ?? '',
      category: json['category'],
      goalAmount: double.parse(json['goal_amount'].toString()),
      currentAmount: double.parse(json['current_amount'].toString()),
      currency: json['currency'] ?? 'KES',
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : null,
      status: json['status'],
      featured: json['featured'] ?? false,
      imageUrl: json['image_url'],
      videoUrl: json['video_url'],
      progressPercentage: double.parse(json['progress_percentage']?.toString() ?? '0'),
      totalDonors: json['total_donors'],
    );
  }

  String get categoryDisplay {
    switch (category) {
      case 'scholarship':
        return 'Scholarship';
      case 'endowment':
        return 'Endowment';
      case 'infrastructure':
        return 'Infrastructure';
      case 'research':
        return 'Research & Innovation';
      default:
        return 'General';
    }
  }

  bool get isActive => status == 'active';

  double get remainingAmount => goalAmount - currentAmount;
}