// lib/services/payment_service.dart

import '../config/api_config.dart';
import 'api_service.dart';

class PaymentService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> initiateMpesaPayment({
    required String donationId,
    required String phoneNumber,
  }) async {
    final response = await _api.post(
      '${ApiConfig.paymentsEndpoint}/mpesa/initiate',
      {
        'donation_id': donationId,
        'phone_number': phoneNumber,
      },
      requiresAuth: true,
    );

    return response;
  }

  Future<Map<String, dynamic>> checkPaymentStatus(String donationId) async {
    final response = await _api.get(
      '${ApiConfig.paymentsEndpoint}/status/$donationId',
      requiresAuth: true,
    );

    return response;
  }

  Future<Map<String, dynamic>> confirmBankTransfer({
    required String donationId,
    required String transactionReference,
    String? receiptImageUrl,
  }) async {
    final response = await _api.post(
      '${ApiConfig.paymentsEndpoint}/bank-transfer/confirm',
      {
        'donation_id': donationId,
        'transaction_reference': transactionReference,
        'receipt_image_url': receiptImageUrl,
      },
      requiresAuth: true,
    );

    return response;
  }
}