// lib/services/storage_service.dart
//
// ✅ FIX: Supports BOTH usage patterns found across the project:
//
//   INSTANCE pattern (api_service.dart, auth_service.dart):
//     final _storage = StorageService();
//     await _storage.getToken();
//     await _storage.saveToken(token);
//     await _storage.saveUser(data);
//     await _storage.getUser();
//     await _storage.clearAll();
//
//   STATIC pattern (other files):
//     await StorageService.getAuthToken();
//     await StorageService.setAuthToken(token);
//     await StorageService.clearSession();
//
// All backed by shared_preferences (web-safe, already in pubspec).
// flutter_secure_storage was removed by flutter pub upgrade --major-versions.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class StorageService {

  // ── Keys ───────────────────────────────────────────────────────────────────
  static const _keyAuthToken      = 'auth_token';
  static const _keyRefreshToken   = 'refresh_token';
  static const _keyUserId         = 'user_id';
  static const _keyUserEmail      = 'user_email';
  static const _keyUserRole       = 'user_role';
  static const _keyUserData       = 'user_data';
  static const _keyOnboardingDone = 'onboarding_done';

  // ════════════════════════════════════════════════════════════════════════
  // INSTANCE METHODS  (used by api_service.dart + auth_service.dart)
  // ════════════════════════════════════════════════════════════════════════

  /// Returns the stored auth token.
  /// Called as: await _storage.getToken()
  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyAuthToken);
    } catch (e) {
      debugPrint('[StorageService] getToken error: $e');
      return null;
    }
  }

  /// Saves the auth token.
  /// Called as: await _storage.saveToken(token)
  Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAuthToken, token);
    } catch (e) {
      debugPrint('[StorageService] saveToken error: $e');
    }
  }

  /// Saves user data as JSON.
  /// Called as: await _storage.saveUser({'uid': ..., 'email': ...})
  Future<void> saveUser(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserData, jsonEncode(userData));
      // Also persist individual fields for convenience
      if (userData['uid']   != null) await prefs.setString(_keyUserId,    userData['uid']   as String);
      if (userData['email'] != null) await prefs.setString(_keyUserEmail,  userData['email'] as String);
      if (userData['role']  != null) await prefs.setString(_keyUserRole,   userData['role']  as String);
    } catch (e) {
      debugPrint('[StorageService] saveUser error: $e');
    }
  }

  /// Returns stored user data map, or null if none saved.
  /// Called as: await _storage.getUser()
  Future<Map<String, dynamic>?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyUserData);
      if (raw == null || raw.isEmpty) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (e) {
      debugPrint('[StorageService] getUser error: $e');
      return null;
    }
  }

  /// Clears all stored data.
  /// Called as: await _storage.clearAll()
  ///
  /// NOTE: clearAll() is also a static method — when called on an instance
  /// (_storage.clearAll()) Dart resolves it correctly because the instance
  /// method below shadows the static one within an instance context.
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('[StorageService] All storage cleared (instance)');
    } catch (e) {
      debugPrint('[StorageService] clearAll error: $e');
    }
  }

  /// Clears only session tokens (preserves onboarding flag etc.).
  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAuthToken);
      await prefs.remove(_keyRefreshToken);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUserEmail);
      await prefs.remove(_keyUserRole);
      await prefs.remove(_keyUserData);
      debugPrint('[StorageService] Session cleared (instance)');
    } catch (e) {
      debugPrint('[StorageService] clearSession error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // STATIC METHODS  (used by FCMInitializer, NotificationService, etc.)
  // ════════════════════════════════════════════════════════════════════════

  static Future<void> setAuthToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAuthToken, token);
    } catch (e) {
      debugPrint('[StorageService] setAuthToken error: $e');
    }
  }

  static Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyAuthToken);
    } catch (e) {
      debugPrint('[StorageService] getAuthToken error: $e');
      return null;
    }
  }

  static Future<void> setRefreshToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRefreshToken, token);
    } catch (e) {
      debugPrint('[StorageService] setRefreshToken error: $e');
    }
  }

  static Future<String?> getRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyRefreshToken);
    } catch (e) {
      debugPrint('[StorageService] getRefreshToken error: $e');
      return null;
    }
  }

  static Future<void> setUserId(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserId, uid);
    } catch (e) {
      debugPrint('[StorageService] setUserId error: $e');
    }
  }

  static Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserId);
    } catch (e) {
      debugPrint('[StorageService] getUserId error: $e');
      return null;
    }
  }

  static Future<void> setUserEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserEmail, email);
    } catch (e) {
      debugPrint('[StorageService] setUserEmail error: $e');
    }
  }

  static Future<String?> getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserEmail);
    } catch (e) {
      debugPrint('[StorageService] getUserEmail error: $e');
      return null;
    }
  }

  static Future<void> setUserRole(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserRole, role);
    } catch (e) {
      debugPrint('[StorageService] setUserRole error: $e');
    }
  }

  static Future<String?> getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserRole);
    } catch (e) {
      debugPrint('[StorageService] getUserRole error: $e');
      return null;
    }
  }

  static Future<void> setOnboardingDone(bool done) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyOnboardingDone, done);
    } catch (e) {
      debugPrint('[StorageService] setOnboardingDone error: $e');
    }
  }

  static Future<bool> getOnboardingDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyOnboardingDone) ?? false;
    } catch (e) {
      debugPrint('[StorageService] getOnboardingDone error: $e');
      return false;
    }
  }

  static Future<void> write(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('[StorageService] write error: $e');
    }
  }

  static Future<String?> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (e) {
      debugPrint('[StorageService] read error: $e');
      return null;
    }
  }

  static Future<void> delete(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (e) {
      debugPrint('[StorageService] delete error: $e');
    }
  }
}