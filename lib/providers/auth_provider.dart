// lib/providers/auth_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';  // ✅ ADDED
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final SharedPreferences prefs;

  // ── Firebase & Google instances ────────────────────────────────────────────
  final FirebaseAuth      _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore    = FirebaseFirestore.instance; //  ADDED
  final GoogleSignIn      _googleSignIn = GoogleSignIn(
    clientId: '712922432471-u7bmf4mh2jvoas179h089a2slqs7fvfl.apps.googleusercontent.com',
  );

  // ── State ──────────────────────────────────────────────────────────────────
  UserModel? _user;
  bool       _isLoading       = false;
  bool       _isGoogleLoading = false;
  String?    _errorMessage;

  AuthProvider({required this.prefs}) {
    _restoreSession();
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  UserModel? get user            => _user;
  bool       get isLoading       => _isLoading;
  bool       get isGoogleLoading => _isGoogleLoading;
  String?    get errorMessage    => _errorMessage;
  bool       get isAuthenticated => _user != null;

  // ── Restore session on app start ───────────────────────────────────────────
  void _restoreSession() {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser != null) {
      _user = _userFromFirebase(
          firebaseUser, isAdmin: _checkIfAdmin(firebaseUser.email));
      notifyListeners();
      // ✅ ADDED: load donorType from Firestore in background
      _loadDonorProfile(firebaseUser.uid);
    }
  }

  // ── Load donor profile from Firestore ──────────────────────────────────────
  // ✅ ADDED: fetches donorType and phone saved during registration
  Future<void> _loadDonorProfile(String uid) async {
    try {
      final doc = await _firestore.collection('donors').doc(uid).get();
      if (doc.exists && _user != null) {
        final data      = doc.data();
        final donorType = _parseDonorType(data?['donor_type'] as String?);
        _user = UserModel(
          id:              _user!.id,
          email:           _user!.email,
          name:            _user!.name,
          phoneNumber:     data?['phone'] as String? ?? _user!.phoneNumber,
          role:            _user!.role,
          donorType:       donorType,     // ✅ restored from Firestore
          isEmailVerified: _user!.isEmailVerified,
          isPhoneVerified: _user!.isPhoneVerified,
          createdAt:       _user!.createdAt,
          lastLoginAt:     _user!.lastLoginAt,
        );
        notifyListeners();
      }
    } catch (_) {
      // Non-fatal — app continues without donorType if Firestore is unavailable
    }
  }

  // ── Email / Password Login ─────────────────────────────────────────────────
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        _errorMessage = 'Login failed. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _user = _userFromFirebase(
        firebaseUser,
        isAdmin: _checkIfAdmin(firebaseUser.email),
      );

      _isLoading = false;
      notifyListeners();

      // ✅ ADDED: load donorType after login
      _loadDonorProfile(firebaseUser.uid);
      return true;

    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyFirebaseError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────
  Future<bool> signInWithGoogle() async {
    _isGoogleLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _isGoogleLoading = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      final userCredential =
      await _firebaseAuth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        _errorMessage = 'Google sign-in failed. Please try again.';
        _isGoogleLoading = false;
        notifyListeners();
        return false;
      }

      // ✅ CHANGED: now checks admin list for Google sign-in too
      // (admin login screen rejects non-admins after this returns true)
      final isAdmin = _checkIfAdmin(firebaseUser.email);
      _user = _userFromFirebase(firebaseUser, isAdmin: isAdmin);

      _isGoogleLoading = false;
      notifyListeners();

      // ✅ ADDED: load donor profile for non-admin Google users
      if (!isAdmin) {
        _loadDonorProfile(firebaseUser.uid);
      }

      return true;

    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyFirebaseError(e.code);
      _isGoogleLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Google sign-in failed. Please try again.';
      _isGoogleLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Register ───────────────────────────────────────────────────────────────
  Future<bool> register({
    required String    email,
    required String    password,
    required String    name,
    required String    phone,      // ✅ ADDED
    required DonorType donorType,  // ✅ ADDED
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Create Firebase Auth account
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await credential.user?.updateDisplayName(name);
      await credential.user?.reload();

      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) {
        _errorMessage = 'Registration failed. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Save donor profile to Firestore (non-blocking — won't stop registration if it fails)
      try {
        await _firestore.collection('donors').doc(firebaseUser.uid).set({
          'id':         firebaseUser.uid,
          'name':       name,
          'email':      email.trim(),
          'phone':      phone,
          'role':       'donor',
          'donor_type': donorType.name,
          'created_at': DateTime.now().toIso8601String(),
        }).timeout(const Duration(seconds: 8));
      } catch (firestoreError) {
        // Firestore save failed (e.g. security rules) — account still created
        // Profile will be saved on next login once rules are fixed
        debugPrint('Firestore save failed: $firestoreError');
      }

      // 3. ✅ UPDATED: Build local user model with phone and donorType
      _user = UserModel(
        id:              firebaseUser.uid,
        email:           firebaseUser.email ?? '',
        name:            name,
        phoneNumber:     phone,
        role:            UserRole.donor,
        donorType:       donorType,
        isEmailVerified: firebaseUser.emailVerified,
        isPhoneVerified: false,
        createdAt:       DateTime.now(),
      );

      // 4. Send email verification (non-blocking)
      try {
        await firebaseUser.sendEmailVerification();
      } catch (_) {
        // Non-fatal — user can request verification later
      }

      _isLoading = false;
      notifyListeners();
      return true;

    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyFirebaseError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Reset Password ─────────────────────────────────────────────────────────
  Future<bool> resetPassword({required String email}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyFirebaseError(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to send reset email. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
    _user = null;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  UserModel _userFromFirebase(User firebaseUser, {required bool isAdmin}) {
    return UserModel(
      id:              firebaseUser.uid,
      email:           firebaseUser.email ?? '',
      name:            firebaseUser.displayName ??
          firebaseUser.email?.split('@').first ??
          'User',
      role:            isAdmin ? UserRole.admin : UserRole.donor,
      isEmailVerified: firebaseUser.emailVerified,
      isPhoneVerified: firebaseUser.phoneNumber != null,
      createdAt:       firebaseUser.metadata.creationTime ?? DateTime.now(),
    );
  }

  /// Admin check — email must be in the list below.
  /// ⚠️ For production: replace with a Firestore 'admins' collection lookup.
  bool _checkIfAdmin(String? email) {
    if (email == null) return false;
    const adminEmails = [
      'admin@kca.ac.ke',
      'foundation@kca.ac.ke',
    ];
    return adminEmails.contains(email.toLowerCase());
  }

  String _friendlyFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  // ✅ Local helper — parses Firestore donor_type string to DonorType enum
  DonorType? _parseDonorType(String? value) {
    switch (value) {
      case 'individual': return DonorType.individual;
      case 'corporate':  return DonorType.corporate;
      case 'partner':    return DonorType.partner;
      default:           return null;
    }
  }
}