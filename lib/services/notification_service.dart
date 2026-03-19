// lib/services/notification_service.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  NotificationService._();

  static final _db        = FirebaseFirestore.instance;
  static final _messaging = FirebaseMessaging.instance;

  // Replace with your actual Firebase project region + ID
  static const _functionsBaseUrl =
      'https://us-central1-kca-university-foundation.cloudfunctions.net';

  // ════════════════════════════════════════════════════════════════════════
  // 1.  TOKEN MANAGEMENT
  // ════════════════════════════════════════════════════════════════════════

  /// Saves FCM token for the currently signed-in user.
  /// Called by FCMInitializer on launch and on token refresh.
  static Future<void> saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db
          .collection('donors')
          .doc(uid)
          .set({'fcm_token': token}, SetOptions(merge: true));

      await _db
          .collection('staff')
          .doc(uid)
          .set({'fcm_token': token}, SetOptions(merge: true))
          .catchError((_) {});

      debugPrint('[NotificationService] FCM token saved for uid=$uid');
    } catch (e) {
      debugPrint('[NotificationService] saveToken error: $e');
    }
  }

  /// Saves the FCM token for a known uid.
  /// Called from admin_login_screen after successful login.
  static Future<void> saveFCMToken(String uid,
      {bool isAdmin = false}) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      await _db
          .collection('staff')
          .doc(uid)
          .set({'fcm_token': token}, SetOptions(merge: true));

      if (!isAdmin) {
        await _db
            .collection('donors')
            .doc(uid)
            .set({'fcm_token': token}, SetOptions(merge: true));
      }

      debugPrint(
          '[NotificationService] saveFCMToken uid=$uid isAdmin=$isAdmin');
    } catch (e) {
      debugPrint('[NotificationService] saveFCMToken error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 2.  TOPIC SUBSCRIPTIONS
  // ════════════════════════════════════════════════════════════════════════

  /// Subscribes device to 'admins' FCM topic.
  /// Called from admin_login_screen after successful admin login.
  static Future<void> subscribeAdminToTopic() async {
    try {
      await _messaging.subscribeToTopic('admins');
      debugPrint('[NotificationService] Subscribed: admins');
    } catch (e) {
      debugPrint('[NotificationService] subscribeAdminToTopic error: $e');
    }
  }

  /// Subscribes device to 'all_donors' FCM topic.
  /// Called by FCMInitializer for regular donor users.
  static Future<void> subscribeDonorToTopic() async {
    try {
      await _messaging.subscribeToTopic('all_donors');
      debugPrint('[NotificationService] Subscribed: all_donors');
    } catch (e) {
      debugPrint('[NotificationService] subscribeDonorToTopic error: $e');
    }
  }

  /// Unsubscribes from admin topic on logout.
  static Future<void> unsubscribeAdminFromTopic() async {
    try {
      await _messaging.unsubscribeFromTopic('admins');
      debugPrint('[NotificationService] Unsubscribed: admins');
    } catch (e) {
      debugPrint(
          '[NotificationService] unsubscribeAdminFromTopic error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 3.  IN-APP NOTIFICATIONS  (Firestore)
  // ════════════════════════════════════════════════════════════════════════

  /// Creates an in-app notification document in Firestore.
  /// [recipientId] — uid | 'admins' | 'all'
  static Future<void> createNotification({
    required String recipientId,
    required String title,
    required String body,
    required String type,
    double?  amount,
    String?  transactionId,
    String?  campaignTitle,
  }) async {
    try {
      await _db.collection('notifications').add({
        'recipient_id':   recipientId,
        'title':          title,
        'body':           body,
        'type':           type,
        'is_read':        false,
        'created_at':     FieldValue.serverTimestamp(),
        if (amount        != null) 'amount':         amount,
        if (transactionId != null) 'transaction_id': transactionId,
        if (campaignTitle != null) 'campaign_title': campaignTitle,
      });
    } catch (e) {
      debugPrint('[NotificationService] createNotification error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 4.  DONATION NOTIFICATION HELPERS
  // ════════════════════════════════════════════════════════════════════════

  /// Notifies admins AND the donor when a donation is received.
  ///
  /// Called from:
  ///   • bank_transfer_screen.dart  — after Firestore write
  ///   • donation_flow_screen.dart  — _recordAndNotify()
  ///
  /// Pass 'Anonymous' as [donorName] when is_anonymous is true.
  static Future<void> notifyDonationReceived({
    required String donorName,
    required double amount,
    required String campaignTitle,
    required String donorId,
    required String campaignId,
    String? transactionId,
  }) async {
    final amtStr = 'KES ${amount.toStringAsFixed(0)}';

    // In-app notification → admins
    await createNotification(
      recipientId:   'admins',
      title:         'New Donation: $amtStr',
      body:          '$donorName donated $amtStr to "$campaignTitle".'
          '${transactionId != null ? ' TXN: $transactionId' : ''}',
      type:          'donation_received',
      amount:        amount,
      transactionId: transactionId,
      campaignTitle: campaignTitle,
    );

    // In-app notification → donor
    await createNotification(
      recipientId:   donorId,
      title:         'Donation Received 🎉',
      body:          'Thank you $donorName! Your $amtStr donation to '
          '"$campaignTitle" has been recorded.',
      type:          'receipt',
      amount:        amount,
      transactionId: transactionId,
      campaignTitle: campaignTitle,
    );

    debugPrint('[NotificationService] notifyDonationReceived: '
        '$donorName | $amtStr | $campaignTitle');
  }

  /// Sends a receipt notification specifically to the donor.
  ///
  /// Called from donation_flow_screen.dart after a COMPLETED (non-pending)
  /// M-Pesa or card payment — line 300 in _recordAndNotify().
  ///
  /// Distinct from [notifyDonationReceived] which notifies both admins
  /// and the donor together.  This method sends only the donor receipt
  /// with the confirmed transaction ID.
  static Future<void> notifyDonorReceipt({
    required String donorId,
    required String donorName,
    required double amount,
    required String campaignTitle,
    required String transactionId,
  }) async {
    final amtStr = 'KES ${amount.toStringAsFixed(0)}';

    await createNotification(
      recipientId:   donorId,
      title:         'Payment Confirmed ✅',
      body:          'Your $amtStr donation to "$campaignTitle" is confirmed. '
          'TXN: $transactionId',
      type:          'receipt',
      amount:        amount,
      transactionId: transactionId,
      campaignTitle: campaignTitle,
    );

    debugPrint('[NotificationService] notifyDonorReceipt: '
        '$donorName | $amtStr | TXN=$transactionId');
  }

  // ════════════════════════════════════════════════════════════════════════
  // 5.  EMAIL  (via Cloud Function)
  // ════════════════════════════════════════════════════════════════════════

  /// Calls the sendThankYouEmail Cloud Function via HTTP POST.
  /// Non-fatal — donation flow continues even if this fails.
  static Future<void> sendDonorThankYouEmail({
    required String donorName,
    required String donorEmail,
    required double amount,
    required String campaignTitle,
    required String transactionId,
  }) async {
    try {
      final url = Uri.parse('$_functionsBaseUrl/sendThankYouEmail');
      final response = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': {
            'donorName':     donorName,
            'donorEmail':    donorEmail,
            'amount':        amount,
            'campaignTitle': campaignTitle,
            'transactionId': transactionId,
          }
        }),
      )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        debugPrint(
            '[NotificationService] Thank-you email queued for $donorEmail');
      } else {
        debugPrint('[NotificationService] Email fn '
            '${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[NotificationService] sendDonorThankYouEmail error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // 6.  CONVENIENCE — full post-donation sequence
  // ════════════════════════════════════════════════════════════════════════

  /// Full post-donation notification flow:
  ///   1. notifyDonationReceived  → donor + admins in-app
  ///   2. sendDonorThankYouEmail  → donor email (non-fatal)
  static Future<void> onDonationSuccess({
    required String donorId,
    required String donorName,
    required String donorEmail,
    required double amount,
    required String campaignTitle,
    required String transactionId,
  }) async {
    await notifyDonationReceived(
      donorName:     donorName,
      amount:        amount,
      campaignTitle: campaignTitle,
      donorId:       donorId,
      campaignId:    '',
      transactionId: transactionId,
    );

    if (donorEmail.isNotEmpty) {
      await sendDonorThankYouEmail(
        donorName:     donorName,
        donorEmail:    donorEmail,
        amount:        amount,
        campaignTitle: campaignTitle,
        transactionId: transactionId,
      );
    }
  }
}