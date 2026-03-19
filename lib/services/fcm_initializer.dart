// lib/services/fcm_initializer.dart
//
// ✅ FIX: flutter_local_notifications was removed by flutter pub upgrade --major-versions.
//    Replaced foreground notification display with Firebase Messaging's built-in
//    setForegroundNotificationPresentationOptions (works on iOS/macOS) and
//    a simple overlay snackbar approach for Android foreground messages.
//    This removes the flutter_local_notifications dependency entirely.
//
// If you want to restore local notifications, add to pubspec.yaml:
//   flutter_local_notifications: ^18.0.1
// Then restore the full implementation from the previous version.

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';

// Must be top-level for Android background handling
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  debugPrint('📩 FCM Background: ${message.notification?.title}');
}

class FCMInitializer {
  FCMInitializer._();

  static final _messaging = FirebaseMessaging.instance;

  // Callback to show in-app snackbar — set from main.dart or app shell
  // e.g. FCMInitializer.onForegroundMessage = (title, body) => ...
  static void Function(String title, String body)? onForegroundMessage;

  /// Call once from main() after Firebase.initializeApp().
  static Future<void> init() async {

    // ── 1. Request permission (iOS + Android 13+) ─────────────────────────
    await _messaging.requestPermission(
      alert:       true,
      badge:       true,
      sound:       true,
      provisional: false,
    );

    // ── 2. Register background handler ────────────────────────────────────
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    // ── 3. iOS/macOS foreground presentation options ──────────────────────
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // ── 4. Save initial FCM token ─────────────────────────────────────────
    final token = await _messaging.getToken();
    if (token != null) {
      debugPrint('📱 FCM Token: $token');
      await NotificationService.saveToken(token);
    }

    // ── 5. Auto-refresh token ─────────────────────────────────────────────
    _messaging.onTokenRefresh.listen(NotificationService.saveToken);

    // ── 6. Handle foreground messages ─────────────────────────────────────
    // On Android, Firebase does NOT show a heads-up notification when the
    // app is in foreground. We use a callback so the app shell can show
    // a SnackBar or custom overlay — no local notifications package needed.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notif = message.notification;
      if (notif == null) return;

      debugPrint('📬 FCM Foreground: ${notif.title} — ${notif.body}');

      // Trigger in-app display if a handler is registered
      if (onForegroundMessage != null) {
        onForegroundMessage!(
          notif.title ?? 'KCA Foundation',
          notif.body  ?? '',
        );
      }
    });

    // ── 7. Subscribe to donor broadcast topic ─────────────────────────────
    await _messaging.subscribeToTopic('all_donors');

    debugPrint('✅ FCM initialized');
  }
}