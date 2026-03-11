// lib/services/fcm_initializer.dart
//
// ─────────────────────────────────────────────────────────────────────────────
// STEP 1: Run this in your terminal first:
//   flutter pub get
//
// STEP 2: Then add ONE line to main.dart inside main():
//   await FCMInitializer.init();
//
// STEP 3: Add ONE import to main.dart:
//   import 'services/fcm_initializer.dart';
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';

// Must be top-level (outside any class) for Android background handling
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  debugPrint('📩 FCM Background: ${message.notification?.title}');
}

class FCMInitializer {
  static final _localNotif = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'kca_channel',
    'KCA Foundation',
    description:  'Donation and campaign notifications',
    importance:   Importance.high,
  );

  static Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS + Android 13+)
    await messaging.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );

    // Background handler
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    // Local notifications (for foreground display)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotif.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Create Android notification channel
    await _localNotif
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Save FCM token to Firestore
    final token = await messaging.getToken();
    if (token != null) {
      debugPrint('📱 FCM Token: $token');
      await NotificationService.saveToken(token);
    }

    // Auto-refresh token
    messaging.onTokenRefresh.listen(NotificationService.saveToken);

    // Show notification when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notif = message.notification;
      if (notif == null) return;
      _localNotif.show(
        notif.hashCode,
        notif.title,
        notif.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id, _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority:   Priority.high,
            icon:       '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true, presentBadge: true, presentSound: true,
          ),
        ),
      );
    });

    // Subscribe all users to donor broadcast topic
    await messaging.subscribeToTopic('all_donors');

    debugPrint('✅ FCM initialized');
  }
}