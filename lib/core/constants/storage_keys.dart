// lib/core/constants/storage_keys.dart

/// Storage keys for SharedPreferences and SecureStorage
class StorageKeys {
  // Auth tokens
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String authToken = 'auth_token'; // Legacy support
  static const String userId = 'user_id';
  static const String user = 'user';

  // User preferences
  static const String isFirstLaunch = 'is_first_launch';
  static const String rememberMe = 'remember_me';
  static const String language = 'language';
  static const String theme = 'theme';

  // Notifications
  static const String fcmToken = 'fcm_token';
  static const String notificationsEnabled = 'notifications_enabled';

  // Cache
  static const String campaignsCache = 'campaigns_cache';
  static const String donationsCache = 'donations_cache';
  static const String lastCacheUpdate = 'last_cache_update';
}