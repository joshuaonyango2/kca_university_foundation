// lib/providers/donation_provider.dart

import 'package:flutter/foundation.dart';
import '../models/donation.dart';
import '../services/donation_service.dart';
import '../services/payment_service.dart';

class DonationProvider with ChangeNotifier {
  final DonationService _donationService = DonationService();
  final PaymentService _paymentService = PaymentService();

  List<Donation> _donations = [];
  Donation? _currentDonation;
  bool _isLoading = false;
  String? _errorMessage;

  List<Donation> get donations => _donations;
  Donation? get currentDonation => _currentDonation;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Initiate donation
  Future<Map<String, dynamic>> initiateDonation({
    required String campaignId,
    required double amount,
    required String paymentMethod,
    bool isRecurring = false,
    String? recurrenceFrequency,
    bool isAnonymous = false,
    String? dedicationMessage,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _donationService.initiateDonation(
        campaignId: campaignId,
        amount: amount,
        paymentMethod: paymentMethod,
        isRecurring: isRecurring,
        recurrenceFrequency: recurrenceFrequency,
        isAnonymous: isAnonymous,
        dedicationMessage: dedicationMessage,
      );

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': e.toString()};
    }
  }

  // Process M-Pesa payment
  Future<Map<String, dynamic>> processMpesaPayment({
    required String donationId,
    required String phoneNumber,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _paymentService.initiateMpesaPayment(
        donationId: donationId,
        phoneNumber: phoneNumber,
      );

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': e.toString()};
    }
  }

  // Check payment status
  Future<Map<String, dynamic>> checkPaymentStatus(String donationId) async {
    try {
      final result = await _paymentService.checkPaymentStatus(donationId);
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fetch my donations
  Future<void> fetchMyDonations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _donations = await _donationService.getMyDonations();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}