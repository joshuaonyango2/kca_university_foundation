// lib/services/donation_service.dart

import '../config/api_config.dart';
import '../models/donation.dart';
import 'api_service.dart';

class DonationService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> initiateDonation({
    required String campaignId,
    required double amount,
    required String paymentMethod,
    bool isRecurring = false,
    String? recurrenceFrequency,
    bool isAnonymous = false,
    String? dedicationMessage,
  }) async {
    final response = await _api.post(
      '${ApiConfig.donationsEndpoint}/initiate',
      {
        'campaign_id': campaignId,
        'amount': amount,
        'payment_method': paymentMethod,
        'is_recurring': isRecurring,
        'recurrence_frequency': recurrenceFrequency,
        'is_anonymous': isAnonymous,
        'dedication_message': dedicationMessage,
      },
      requiresAuth: true,
    );

    return response;
  }

  Future<List<Donation>> getMyDonations() async {
    final response = await _api.get(
      '${ApiConfig.donationsEndpoint}/my-donations',
      requiresAuth: true,
    );

    if (response['success']) {
      final List<dynamic> data = response['data'];
      return data.map((json) => Donation.fromJson(json)).toList();
    }

    throw Exception(response['message'] ?? 'Failed to load donations');
  }

  Future<Donation> getDonationById(String donationId) async {
    final response = await _api.get(
      '${ApiConfig.donationsEndpoint}/$donationId',
      requiresAuth: true,
    );

    if (response['success']) {
      return Donation.fromJson(response['data']);
    }

    throw Exception(response['message'] ?? 'Failed to load donation');
  }
}