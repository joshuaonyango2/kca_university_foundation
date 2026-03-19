// lib/repositories/auth_repository.dart
//
// ✅ FIX: dio removed by flutter pub upgrade --major-versions.
//    All Dio / DioException / DioExceptionType references replaced with
//    HttpException from dio_client.dart (drop-in replacement).
//    Uses Firebase Auth directly — no REST calls needed for core auth.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart';
import '../core/network/dio_client.dart'; // HttpException lives here

class AuthRepository {
  AuthRepository._();

  static final _auth = FirebaseAuth.instance;
  static final _db   = FirebaseFirestore.instance;

  // ── Login ──────────────────────────────────────────────────────────────────
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email:    email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return AuthResult.failure('Login returned no user.');
      }
      return AuthResult.success(uid: user.uid, email: user.email ?? email);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseError(e));
    } on HttpException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      debugPrint('[AuthRepository] login error: $e');
      return AuthResult.failure('Login failed. Please try again.');
    }
  }

  // ── Register ───────────────────────────────────────────────────────────────
  static Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String donorType,
    String? organization,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email:    email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return AuthResult.failure('Registration returned no user.');
      }

      // Update display name
      await user.updateDisplayName(name);

      // Create donor document
      await _db.collection('donors').doc(user.uid).set({
        'name':         name,
        'email':        email.trim(),
        'phone':        phone,
        'donor_type':   donorType,
        'organization': organization ?? '',
        'created_at':   FieldValue.serverTimestamp(),
      });

      return AuthResult.success(uid: user.uid, email: email);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseError(e));
    } on HttpException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      debugPrint('[AuthRepository] register error: $e');
      return AuthResult.failure('Registration failed. Please try again.');
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('[AuthRepository] logout error: $e');
    }
  }

  // ── Reset password ─────────────────────────────────────────────────────────
  static Future<AuthResult> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(uid: '', email: email);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseError(e));
    } on HttpException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      debugPrint('[AuthRepository] resetPassword error: $e');
      return AuthResult.failure('Failed to send reset email.');
    }
  }

  // ── Change password ────────────────────────────────────────────────────────
  static Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return AuthResult.failure('Not authenticated.');
      }

      // Re-authenticate first
      final credential = EmailAuthProvider.credential(
        email:    user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return AuthResult.success(uid: user.uid, email: user.email!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseError(e));
    } on HttpException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      debugPrint('[AuthRepository] changePassword error: $e');
      return AuthResult.failure('Failed to change password.');
    }
  }

  // ── Update profile ─────────────────────────────────────────────────────────
  static Future<AuthResult> updateProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _db.collection('donors').doc(uid).update(data);

      final user = _auth.currentUser;
      if (user != null && data.containsKey('name')) {
        await user.updateDisplayName(data['name'] as String);
      }
      return AuthResult.success(uid: uid, email: '');
    } on HttpException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      debugPrint('[AuthRepository] updateProfile error: $e');
      return AuthResult.failure('Failed to update profile.');
    }
  }

  // ── Get current user ───────────────────────────────────────────────────────
  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Firebase error mapper ──────────────────────────────────────────────────
  static String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'requires-recent-login':
        return 'Please log in again to continue.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}

// ── AuthResult ─────────────────────────────────────────────────────────────────
class AuthResult {
  final bool   isSuccess;
  final String uid;
  final String email;
  final String? errorMessage;

  const AuthResult._({
    required this.isSuccess,
    required this.uid,
    required this.email,
    this.errorMessage,
  });

  factory AuthResult.success({required String uid, required String email}) =>
      AuthResult._(isSuccess: true,  uid: uid, email: email);

  factory AuthResult.failure(String message) =>
      AuthResult._(isSuccess: false, uid: '', email: '', errorMessage: message);

  bool get isFailure => !isSuccess;
}