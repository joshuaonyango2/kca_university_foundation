// lib/providers/campaign_provider.dart

import 'package:flutter/foundation.dart';

class Campaign {
  final String id;
  final String title;
  final String description;
  final String category;
  final double goal;
  final double raised;
  final int donors;
  final String imageUrl;

  Campaign({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.goal,
    required this.raised,
    required this.donors,
    required this.imageUrl,
  });

  double get progress => (raised / goal).clamp(0.0, 1.0);
  int get progressPercentage => (progress * 100).round();

  // fromJson for API integration
  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      goal: (json['goal'] as num).toDouble(),
      raised: (json['raised'] as num).toDouble(),
      donors: json['donors'] as int,
      imageUrl: json['image_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'goal': goal,
      'raised': raised,
      'donors': donors,
      'image_url': imageUrl,
    };
  }
}

class CampaignProvider with ChangeNotifier {
  List<Campaign> _campaigns = [];
  Campaign? _selectedCampaign;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Campaign> get campaigns => _campaigns;
  Campaign? get selectedCampaign => _selectedCampaign;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Fetch all campaigns
  Future<void> fetchCampaigns() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // TODO: Replace with actual API call
      // final response = await http.get(Uri.parse('$baseUrl/campaigns'));

      // Simulated data for now
      await Future.delayed(const Duration(seconds: 1));

      _campaigns = [
        Campaign(
          id: '1',
          title: 'Scholarship Fund 2024',
          description: 'Supporting bright students from underprivileged backgrounds to pursue higher education at KCA University.',
          category: 'Scholarships',
          goal: 1000000,
          raised: 650000,
          donors: 234,
          imageUrl: 'https://via.placeholder.com/400x300',
        ),
        Campaign(
          id: '2',
          title: 'New Library Construction',
          description: 'Building a state-of-the-art library facility to enhance learning resources and provide a better study environment.',
          category: 'Infrastructure',
          goal: 2000000,
          raised: 900000,
          donors: 156,
          imageUrl: 'https://via.placeholder.com/400x300',
        ),
        Campaign(
          id: '3',
          title: 'Research Innovation Grant',
          description: 'Funding groundbreaking research projects in technology and innovation to advance knowledge.',
          category: 'Research',
          goal: 500000,
          raised: 400000,
          donors: 89,
          imageUrl: 'https://via.placeholder.com/400x300',
        ),
        Campaign(
          id: '4',
          title: 'Endowment Fund 2024',
          description: 'Building a sustainable endowment fund to support long-term institutional growth and development.',
          category: 'Endowment',
          goal: 5000000,
          raised: 1200000,
          donors: 45,
          imageUrl: 'https://via.placeholder.com/400x300',
        ),
      ];

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get campaign by ID
  Campaign? getCampaignById(String id) {
    try {
      return _campaigns.firstWhere((campaign) => campaign.id == id);
    } catch (e) {
      return null;
    }
  }

  // Select a campaign (use this instead of fetchCampaignById)
  void selectCampaign(String id) {
    _selectedCampaign = getCampaignById(id);
    notifyListeners();
  }

  // Clear selected campaign
  void clearSelectedCampaign() {
    _selectedCampaign = null;
    notifyListeners();
  }

  // Filter campaigns by category
  List<Campaign> getCampaignsByCategory(String category) {
    if (category.toLowerCase() == 'all') {
      return _campaigns;
    }
    return _campaigns
        .where((campaign) => campaign.category.toLowerCase() == category.toLowerCase())
        .toList();
  }
}