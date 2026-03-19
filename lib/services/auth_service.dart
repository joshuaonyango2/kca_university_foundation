// lib/services/auth_service.dart
//
// ✅ FIX (3 errors in auth_service.dart):
//
//   Line 39 + 64: saveUser(user) — was passing Firebase User object directly.
//     saveUser() expects Map<String, dynamic>, not User.
//     Fix: convert User → Map before calling saveUser().
//
//   Line 73: getCurrentUser() return type mismatch.
//     Was returning Map<String,dynamic>? but declared as User? or vice versa.
//     Fix: return Map<String,dynamic>? consistently via getUser().

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

class AuthService {
  final _storage = StorageService();
  final _auth    = FirebaseAuth.instance;
  final _db      = FirebaseFirestore.instance;

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<User?> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email:    email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) return null;

      // ✅ FIX line 39: convert User → Map before calling saveUser()
      await _storage.saveToken(await user.getIdToken() ?? '');
      await _storage.saveUser(_userToMap(user));

      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] login error: ${e.code} — ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] login error: $e');
      rethrow;
    }
  }

  // ── Register ───────────────────────────────────────────────────────────────
  Future<User?> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    String donorType   = 'individual',
    String? organization,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email:    email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) return null;

      await user.updateDisplayName(name);

      // Create Firestore donor doc
      await _db.collection('donors').doc(user.uid).set({
        'name':         name,
        'email':        email.trim(),
        'phone':        phone,
        'donor_type':   donorType,
        'organization': organization ?? '',
        'created_at':   FieldValue.serverTimestamp(),
      });

      // ✅ FIX line 64: convert User → Map before calling saveUser()
      await _storage.saveToken(await user.getIdToken() ?? '');
      await _storage.saveUser(_userToMap(user, name: name, phone: phone));

      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] register error: ${e.code} — ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] register error: $e');
      rethrow;
    }
  }

  // ── Get current user ───────────────────────────────────────────────────────
  // ✅ FIX line 73: return Map<String,dynamic>? — consistent with saveUser/getUser types.
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      // Try live Firebase user first
      final user = _auth.currentUser;
      if (user != null) {
        return _userToMap(user);
      }
      // Fall back to locally stored user data
      return await _storage.getUser();
    } catch (e) {
      debugPrint('[AuthService] getCurrentUser error: $e');
      return null;
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      await _auth.signOut();
      await _storage.clearSession();
    } catch (e) {
      debugPrint('[AuthService] logout error: $e');
    }
  }

  // ── Reset password ─────────────────────────────────────────────────────────
  Future<void> resetPassword({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── Change password ────────────────────────────────────────────────────────
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Not authenticated.');
    }
    final credential = EmailAuthProvider.credential(
      email:    user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  // ── Auth state stream ──────────────────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Helper: Firebase User → Map ────────────────────────────────────────────
  // ✅ This is the fix: always convert User to Map<String,dynamic>
  //    before passing to StorageService.saveUser()
  static Map<String, dynamic> _userToMap(
      User user, {
        String? name,
        String? phone,
      }) {
    return {
      'uid':          user.uid,
      'email':        user.email ?? '',
      'name':         name ?? user.displayName ?? '',
      'phone':        phone ?? user.phoneNumber ?? '',
      'photo_url':    user.photoURL ?? '',
      'email_verified': user.emailVerified,
    };
  }
}