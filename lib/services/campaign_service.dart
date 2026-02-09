// lib/services/campaign_service.dart

import '../config/api_config.dart';
import '../models/campaign.dart';
import 'api_service.dart';

class CampaignService {
  final ApiService _api = ApiService();

  Future<List<Campaign>> getCampaigns({String? category}) async {
    String endpoint = ApiConfig.campaignsEndpoint;
    if (category != null && category != 'all') {
      endpoint += '?category=$category';
    }

    final response = await _api.get(endpoint);

    if (response['success']) {
      final List<dynamic> data = response['data'];
      return data.map((json) => Campaign.fromJson(json)).toList();
    }

    throw Exception(response['message'] ?? 'Failed to load campaigns');
  }

  Future<Campaign> getCampaignById(String campaignId) async {
    final endpoint = '${ApiConfig.campaignsEndpoint}/$campaignId';
    final response = await _api.get(endpoint);

    if (response['success']) {
      return Campaign.fromJson(response['data']);
    }

    throw Exception(response['message'] ?? 'Failed to load campaign');
  }
}