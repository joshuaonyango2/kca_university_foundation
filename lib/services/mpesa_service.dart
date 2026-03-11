// lib/services/mpesa_service.dart
//
// Handles M-Pesa STK Push (Lipa Na M-Pesa Online) via Daraja API.
// Flow: get token → initiate STK Push → poll/wait for callback
//
// Daraja API docs: https://developer.safaricom.co.ke/APIs/MpesaExpressSimulate

import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

// ── M-Pesa Config ─────────────────────────────────────────────────────────────
// Replace these with your actual Daraja credentials from
// https://developer.safaricom.co.ke/
class MpesaConfig {
  // Toggle to switch between sandbox and production
  static const bool isSandbox = true;

  // ── Sandbox credentials (for testing) ──────────────────────────────────────
  static const String sandboxConsumerKey    = 'YOUR_SANDBOX_CONSUMER_KEY';
  static const String sandboxConsumerSecret = 'YOUR_SANDBOX_CONSUMER_SECRET';
  static const String sandboxShortcode      = '174379';           // Daraja test shortcode
  static const String sandboxPasskey        = 'bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919';

  // ── Production credentials ──────────────────────────────────────────────────
  static const String prodConsumerKey       = 'YOUR_PROD_CONSUMER_KEY';
  static const String prodConsumerSecret    = 'YOUR_PROD_CONSUMER_SECRET';
  static const String prodShortcode         = 'YOUR_BUSINESS_SHORTCODE';
  static const String prodPasskey           = 'YOUR_LIPA_NA_MPESA_PASSKEY';

  // ── Callback URL (must be publicly accessible HTTPS) ───────────────────────
  // Use ngrok during dev: ngrok http 3000
  // Production: your server endpoint
  static const String callbackUrl = 'https://your-server.com/mpesa/callback';

  // ── Active values ───────────────────────────────────────────────────────────
  static String get consumerKey    => isSandbox ? sandboxConsumerKey    : prodConsumerKey;
  static String get consumerSecret => isSandbox ? sandboxConsumerSecret : prodConsumerSecret;
  static String get shortcode      => isSandbox ? sandboxShortcode      : prodShortcode;
  static String get passkey        => isSandbox ? sandboxPasskey        : prodPasskey;
  static String get baseUrl        => isSandbox
      ? 'https://sandbox.safaricom.co.ke'
      : 'https://api.safaricom.co.ke';
}

// ── Result model ─────────────────────────────────────────────────────────────
class MpesaResult {
  final bool   success;
  final String? checkoutRequestId;
  final String? merchantRequestId;
  final String? error;

  const MpesaResult({
    required this.success,
    this.checkoutRequestId,
    this.merchantRequestId,
    this.error,
  });
}

// ── Payment status ────────────────────────────────────────────────────────────
enum MpesaStatus { pending, completed, failed, cancelled, timedOut }

// ── Service ───────────────────────────────────────────────────────────────────
class MpesaService {
  static final MpesaService _instance = MpesaService._internal();
  factory MpesaService() => _instance;
  MpesaService._internal();

  final _db = FirebaseFirestore.instance;
  String? _accessToken;
  DateTime? _tokenExpiry;

  // ── Step 1: Get OAuth access token ────────────────────────────────────────
  Future<String?> _getAccessToken() async {
    // Reuse token if still valid
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    try {
      final credentials = base64Encode(
          utf8.encode('${MpesaConfig.consumerKey}:${MpesaConfig.consumerSecret}'));

      final response = await http.get(
        Uri.parse('${MpesaConfig.baseUrl}/oauth/v1/generate?grant_type=client_credentials'),
        headers: {'Authorization': 'Basic $credentials'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'] as String;
        _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
        return _accessToken;
      }
    } catch (e) {
      debugPrint('M-Pesa token error: $e');
    }
    return null;
  }

  // ── Step 2: Initiate STK Push ─────────────────────────────────────────────
  Future<MpesaResult> initiateSTKPush({
    required String phoneNumber,   // Format: 254XXXXXXXXX
    required double amount,
    required String accountRef,    // e.g. campaign name
    required String description,   // e.g. "Donation - KCA Foundation"
    required String donorId,
    required String campaignId,
    required String donorName,
    required String campaignTitle,
  }) async {
    final token = await _getAccessToken();
    if (token == null) {
      return const MpesaResult(success: false, error: 'Could not authenticate with M-Pesa');
    }

    // Sanitize phone: ensure it starts with 254
    final phone = _sanitizePhone(phoneNumber);
    if (phone == null) {
      return const MpesaResult(success: false, error: 'Invalid phone number. Use format: 07XX XXX XXX');
    }

    // Generate timestamp and password
    final timestamp = _timestamp();
    final password  = base64Encode(utf8.encode(
        '${MpesaConfig.shortcode}${MpesaConfig.passkey}$timestamp'));

    final amountInt = amount.ceil(); // M-Pesa only accepts integers

    try {
      final response = await http.post(
        Uri.parse('${MpesaConfig.baseUrl}/mpesa/stkpush/v1/processrequest'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'BusinessShortCode': MpesaConfig.shortcode,
          'Password':          password,
          'Timestamp':         timestamp,
          'TransactionType':   'CustomerPayBillOnline',
          'Amount':            amountInt,
          'PartyA':            phone,
          'PartyB':            MpesaConfig.shortcode,
          'PhoneNumber':       phone,
          'CallBackURL':       MpesaConfig.callbackUrl,
          'AccountReference':  accountRef.length > 12 ? accountRef.substring(0, 12) : accountRef,
          'TransactionDesc':   description.length > 13 ? description.substring(0, 13) : description,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('M-Pesa STK response: $data');

      if (response.statusCode == 200 &&
          data['ResponseCode'] == '0') {
        final checkoutId  = data['CheckoutRequestID']  as String;
        final merchantId  = data['MerchantRequestID']  as String;

        // Save pending donation to Firestore immediately
        await _savePendingDonation(
          checkoutRequestId: checkoutId,
          merchantRequestId: merchantId,
          donorId:      donorId,
          campaignId:   campaignId,
          donorName:    donorName,
          campaignTitle: campaignTitle,
          amount:       amount,
          phone:        phone,
        );

        return MpesaResult(
          success:           true,
          checkoutRequestId: checkoutId,
          merchantRequestId: merchantId,
        );
      } else {
        final errorMsg = data['errorMessage'] as String? ??
            data['ResponseDescription'] as String? ??
            'STK Push failed';
        return MpesaResult(success: false, error: errorMsg);
      }
    } catch (e) {
      return MpesaResult(success: false, error: 'Network error: $e');
    }
  }

  // ── Step 3: Query STK Push status (polling fallback) ─────────────────────
  Future<MpesaStatus> querySTKStatus(String checkoutRequestId) async {
    final token = await _getAccessToken();
    if (token == null) return MpesaStatus.failed;

    final timestamp = _timestamp();
    final password  = base64Encode(utf8.encode(
        '${MpesaConfig.shortcode}${MpesaConfig.passkey}$timestamp'));

    try {
      final response = await http.post(
        Uri.parse('${MpesaConfig.baseUrl}/mpesa/stkpushquery/v1/query'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'BusinessShortCode': MpesaConfig.shortcode,
          'Password':          password,
          'Timestamp':         timestamp,
          'CheckoutRequestID': checkoutRequestId,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final resultCode = data['ResultCode']?.toString();

      switch (resultCode) {
        case '0':    return MpesaStatus.completed;
        case '1032': return MpesaStatus.cancelled;
        case '1037': return MpesaStatus.timedOut;
        default:
          if (data['errorCode'] == '500.001.1001') return MpesaStatus.pending;
          return MpesaStatus.failed;
      }
    } catch (e) {
      return MpesaStatus.pending; // Assume still pending on network error
    }
  }

  // ── Wait for payment with polling ─────────────────────────────────────────
  // Polls Firestore (updated by your callback server) every 3s for up to 2min
  Future<MpesaStatus> waitForPayment(
      String checkoutRequestId, {
        Duration timeout = const Duration(minutes: 2),
        void Function(int secondsElapsed)? onTick,
      }) async {
    final deadline = DateTime.now().add(timeout);
    int elapsed    = 0;

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 3));
      elapsed += 3;
      onTick?.call(elapsed);

      // 1. Check Firestore first (updated by your backend callback)
      final status = await _checkFirestoreStatus(checkoutRequestId);
      if (status != MpesaStatus.pending) return status;

      // 2. Fallback: query Daraja directly
      final apiStatus = await querySTKStatus(checkoutRequestId);
      if (apiStatus != MpesaStatus.pending) {
        await _updateDonationStatus(checkoutRequestId, apiStatus);
        return apiStatus;
      }
    }

    await _updateDonationStatus(checkoutRequestId, MpesaStatus.timedOut);
    return MpesaStatus.timedOut;
  }

  // ── Firestore helpers ─────────────────────────────────────────────────────
  Future<void> _savePendingDonation({
    required String checkoutRequestId,
    required String merchantRequestId,
    required String donorId,
    required String campaignId,
    required String donorName,
    required String campaignTitle,
    required double amount,
    required String phone,
  }) async {
    await _db.collection('donations').doc(checkoutRequestId).set({
      'checkout_request_id': checkoutRequestId,
      'merchant_request_id': merchantRequestId,
      'donor_id':       donorId,
      'campaign_id':    campaignId,
      'donor_name':     donorName,
      'campaign_title': campaignTitle,
      'amount':         amount,
      'phone':          phone,
      'payment_method': 'M-Pesa',
      'status':         'pending',
      'created_at':     DateTime.now().toIso8601String(),
    });
  }

  Future<MpesaStatus> _checkFirestoreStatus(String checkoutRequestId) async {
    try {
      final doc = await _db.collection('donations').doc(checkoutRequestId).get();
      if (!doc.exists) return MpesaStatus.pending;
      final status = doc.data()?['status'] as String? ?? 'pending';
      switch (status) {
        case 'completed': return MpesaStatus.completed;
        case 'failed':    return MpesaStatus.failed;
        case 'cancelled': return MpesaStatus.cancelled;
        default:          return MpesaStatus.pending;
      }
    } catch (_) { return MpesaStatus.pending; }
  }

  Future<void> _updateDonationStatus(
      String checkoutRequestId, MpesaStatus status) async {
    final statusStr = status.name; // 'completed', 'failed', etc.
    await _db.collection('donations').doc(checkoutRequestId).update({
      'status':       statusStr,
      'updated_at':   DateTime.now().toIso8601String(),
    });

    // If completed, increment campaign raised amount
    if (status == MpesaStatus.completed) {
      final doc = await _db.collection('donations').doc(checkoutRequestId).get();
      if (doc.exists) {
        final d          = doc.data()!;
        final campaignId = d['campaign_id'] as String?;
        final amount     = (d['amount'] as num?)?.toDouble() ?? 0;
        if (campaignId != null) {
          await _db.collection('campaigns').doc(campaignId).update({
            'raised': FieldValue.increment(amount),
          });
        }
      }
    }
  }

  // ── Utility ───────────────────────────────────────────────────────────────
  String _timestamp() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2,'0')}'
        '${now.day.toString().padLeft(2,'0')}'
        '${now.hour.toString().padLeft(2,'0')}'
        '${now.minute.toString().padLeft(2,'0')}'
        '${now.second.toString().padLeft(2,'0')}';
  }

  String? _sanitizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('254') && digits.length == 12) return digits;
    if (digits.startsWith('0')   && digits.length == 10) return '254${digits.substring(1)}';
    if (digits.startsWith('7')   && digits.length == 9)  return '254$digits';
    return null;
  }
}