// lib/services/notification_service.dart
//
// Firebase Cloud Messaging (FCM) push notifications.
// Topics: 'all_donors', 'admins', 'campaign_{id}'
// Requires: firebase_messaging, flutter_local_notifications packages

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// CONFIG — replace with your FCM server key from Firebase Console
// Firebase Console → Project Settings → Cloud Messaging → Server Key
// ─────────────────────────────────────────────────────────────────────────────
class NotificationConfig {
  // FCM v1 API (recommended — uses OAuth2)
  static const String projectId  = 'kca-university-foundation';
  // Legacy FCM key (simpler to set up)
  static const String serverKey  = 'YOUR_FCM_SERVER_KEY_HERE';
  static const String fcmLegacyUrl = 'https://fcm.googleapis.com/fcm/send';
}

// ── Notification model ────────────────────────────────────────────────────────
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;         // 'donation', 'campaign', 'system', 'milestone'
  final String? campaignId;
  final String? donorId;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.campaignId,
    this.donorId,
    required this.createdAt,
    this.isRead = false,
  });

  factory AppNotification.fromFirestore(Map<String, dynamic> d, String id) =>
      AppNotification(
        id:         id,
        title:      d['title']       as String? ?? '',
        body:       d['body']        as String? ?? '',
        type:       d['type']        as String? ?? 'system',
        campaignId: d['campaign_id'] as String?,
        donorId:    d['donor_id']    as String?,
        createdAt:  DateTime.tryParse(d['created_at'] as String? ?? '') ?? DateTime.now(),
        isRead:     d['is_read']     as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
    'title':       title,
    'body':        body,
    'type':        type,
    'campaign_id': campaignId,
    'donor_id':    donorId,
    'created_at':  createdAt.toIso8601String(),
    'is_read':     isRead,
  };
}

// ── Service ───────────────────────────────────────────────────────────────────
class NotificationService {
  static final _db = FirebaseFirestore.instance;

  // ── Save device FCM token to Firestore ───────────────────────────────────
  // Call this after FirebaseMessaging.instance.getToken()
  static Future<void> saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('fcm_tokens').doc(uid).set({
      'token':      token,
      'uid':        uid,
      'platform':   defaultTargetPlatform.name,
      'updated_at': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    debugPrint('FCM token saved for uid: $uid');
  }

  // ── In-app notification stream for current user ───────────────────────────
  static Stream<List<AppNotification>> myNotificationsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('notifications')
        .where('recipient_id', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => AppNotification.fromFirestore(d.data(), d.id))
        .toList());
  }

  // ── Admin: all notifications stream ──────────────────────────────────────
  static Stream<List<AppNotification>> allNotificationsStream() {
    return _db
        .collection('notifications')
        .orderBy('created_at', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => AppNotification.fromFirestore(d.data(), d.id))
        .toList());
  }

  // ── Mark notification as read ─────────────────────────────────────────────
  static Future<void> markRead(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).update({'is_read': true});
  }

  static Future<void> markAllRead(String uid) async {
    final batch = _db.batch();
    final unread = await _db.collection('notifications')
        .where('recipient_id', isEqualTo: uid)
        .where('is_read', isEqualTo: false)
        .get();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'is_read': true});
    }
    await batch.commit();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SEND NOTIFICATIONS — call these from your server/Cloud Functions
  // Or call directly from admin (requires server key)
  // ════════════════════════════════════════════════════════════════════════════

  // ── Notify admins when a donation is received ─────────────────────────────
  static Future<void> notifyDonationReceived({
    required String donorName,
    required double amount,
    required String campaignTitle,
    required String donorId,
    required String campaignId,
  }) async {
    final amtStr = amount >= 1000 ? 'KES ${(amount/1000).toStringAsFixed(0)}K' : 'KES ${amount.toStringAsFixed(0)}';

    // 1. Save to Firestore notifications (for in-app)
    await _saveNotification(
      recipientId: 'admins',  // special: all admins
      title: '💰 New Donation Received!',
      body:  '$donorName donated $amtStr to "$campaignTitle"',
      type:  'donation',
      campaignId: campaignId,
      donorId:    donorId,
    );

    // 2. Send FCM push to 'admins' topic
    await _sendFCMToTopic(
      topic: 'admins',
      title: '💰 New Donation — $amtStr',
      body:  '$donorName donated to "$campaignTitle"',
      data:  {'type': 'donation', 'campaign_id': campaignId},
    );
  }

  // ── Notify donor: thank you message ──────────────────────────────────────
  static Future<void> notifyDonorThankYou({
    required String donorId,
    required String donorName,
    required double amount,
    required String campaignTitle,
  }) async {
    final amtStr = 'KES ${amount.toStringAsFixed(0)}';
    await _saveNotification(
      recipientId: donorId,
      title: 'Thank you, $donorName! 🙏',
      body:  'Your donation of $amtStr to "$campaignTitle" has been received. A receipt has been emailed to you.',
      type:  'donation',
    );
    await _sendFCMToUser(
      uid:   donorId,
      title: '🙏 Thank you for your donation!',
      body:  '$amtStr received for "$campaignTitle". Check your email for a receipt.',
      data:  {'type': 'donation'},
    );
  }

  // ── Notify: campaign milestone (50%, 75%, 100%) ───────────────────────────
  static Future<void> notifyCampaignMilestone({
    required String campaignId,
    required String campaignTitle,
    required int    percentReached,
  }) async {
    final emoji = percentReached >= 100 ? '🎉' : percentReached >= 75 ? '🔥' : '📈';
    await _saveNotification(
      recipientId: 'admins',
      title: '$emoji Campaign Milestone!',
      body:  '"$campaignTitle" has reached $percentReached% of its goal!',
      type:  'milestone',
      campaignId: campaignId,
    );
    await _sendFCMToTopic(
      topic: 'admins',
      title: '$emoji "$campaignTitle" — $percentReached% reached!',
      body:  'The campaign has hit a new milestone.',
      data:  {'type': 'milestone', 'campaign_id': campaignId},
    );

    // Also notify all subscribers of this campaign
    await _sendFCMToTopic(
      topic: 'campaign_$campaignId',
      title: '$emoji Campaign Update',
      body:  '"$campaignTitle" is now at $percentReached% of its goal!',
      data:  {'type': 'milestone', 'campaign_id': campaignId},
    );
  }

  // ── Admin broadcast: send to all donors ──────────────────────────────────
  static Future<void> broadcastToAllDonors({
    required String title,
    required String body,
  }) async {
    await _saveNotification(
      recipientId: 'all',
      title: title,
      body:  body,
      type:  'system',
    );
    await _sendFCMToTopic(
      topic: 'all_donors',
      title: title,
      body:  body,
      data:  {'type': 'system'},
    );
  }

  // ── New campaign launched ─────────────────────────────────────────────────
  static Future<void> notifyNewCampaign({
    required String campaignId,
    required String campaignTitle,
    required double goal,
  }) async {
    await _sendFCMToTopic(
      topic: 'all_donors',
      title: '🚀 New Campaign Launched!',
      body:  '"$campaignTitle" — Help us raise KES ${goal >= 1000 ? '${(goal/1000).toStringAsFixed(0)}K' : goal.toStringAsFixed(0)}',
      data:  {'type': 'campaign', 'campaign_id': campaignId},
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────
  static Future<void> _saveNotification({
    required String recipientId,
    required String title,
    required String body,
    required String type,
    String? campaignId,
    String? donorId,
  }) async {
    await _db.collection('notifications').add({
      'recipient_id': recipientId,
      'title':        title,
      'body':         body,
      'type':         type,
      'campaign_id':  campaignId,
      'donor_id':     donorId,
      'is_read':      false,
      'created_at':   DateTime.now().toIso8601String(),
    });
  }

  // Legacy FCM HTTP API — simplest approach for admin-initiated pushes
  static Future<void> _sendFCMToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    if (NotificationConfig.serverKey == 'YOUR_FCM_SERVER_KEY_HERE') {
      debugPrint('FCM not configured — set serverKey in NotificationConfig');
      return;
    }
    try {
      await http.post(
        Uri.parse(NotificationConfig.fcmLegacyUrl),
        headers: {
          'Authorization': 'key=${NotificationConfig.serverKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'to':           '/topics/$topic',
          'notification': {'title': title, 'body': body, 'sound': 'default'},
          'data':         data ?? {},
          'priority':     'high',
        }),
      );
    } catch (e) {
      debugPrint('FCM send error: $e');
    }
  }

  static Future<void> _sendFCMToUser({
    required String uid,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    // Get user's FCM token from Firestore
    final tokenDoc = await _db.collection('fcm_tokens').doc(uid).get();
    final token = tokenDoc.data()?['token'] as String?;
    if (token == null) return;

    try {
      await http.post(
        Uri.parse(NotificationConfig.fcmLegacyUrl),
        headers: {
          'Authorization': 'key=${NotificationConfig.serverKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'to':           token,
          'notification': {'title': title, 'body': body, 'sound': 'default'},
          'data':         data ?? {},
          'priority':     'high',
        }),
      );
    } catch (e) {
      debugPrint('FCM send to user error: $e');
    }
  }
}