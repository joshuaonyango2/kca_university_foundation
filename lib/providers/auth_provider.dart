// lib/providers/auth_provider.dart

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final SharedPreferences prefs;

  // ── Firebase & Google instances ────────────────────────────────────────────
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── State ──────────────────────────────────────────────────────────────────
  UserModel? _user;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;

  AuthProvider({required this.prefs}) {
    _restoreSession();
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isGoogleLoading => _isGoogleLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  // ── Restore session on app start ───────────────────────────────────────────
  void _restoreSession() {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser != null) {
      _user = _userFromFirebase(firebaseUser, isAdmin: _checkIfAdmin(firebaseUser.email));
      notifyListeners();
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
      // Trigger the Google authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // User cancelled the sign-in dialog
      if (googleUser == null) {
        _isGoogleLoading = false;
        notifyListeners();
        return false;
      }

      // Get auth tokens from Google
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // Create Firebase credential from Google tokens
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential =
      await _firebaseAuth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        _errorMessage = 'Google sign-in failed. Please try again.';
        _isGoogleLoading = false;
        notifyListeners();
        return false;
      }

      // Google users are always donors — never admins
      _user = _userFromFirebase(firebaseUser, isAdmin: false);

      _isGoogleLoading = false;
      notifyListeners();
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

  // ── Register (email/password) ──────────────────────────────────────────────
  Future<bool> register({
    required String email,
    required String password,
    required String name,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Save display name to Firebase profile
      await credential.user?.updateDisplayName(name);
      await credential.user?.reload();

      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) {
        _errorMessage = 'Registration failed. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _user = _userFromFirebase(firebaseUser, isAdmin: false);

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

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut(); // also signs out of Google session
    _user = null;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Build a UserModel from a Firebase user object
  UserModel _userFromFirebase(User firebaseUser, {required bool isAdmin}) {
    return UserModel(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'User',
      role: isAdmin ? UserRole.admin : UserRole.donor,
      isEmailVerified: firebaseUser.emailVerified,
      isPhoneVerified: firebaseUser.phoneNumber != null,
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
    );
  }

  /// Determine admin status.
  /// ⚠️ For production: replace with a Firestore lookup on an 'admins' collection
  /// instead of relying on the email domain alone.
  bool _checkIfAdmin(String? email) {
    if (email == null) return false;
    // Add your actual admin emails here:
    const adminEmails = [
      'admin@kca.ac.ke',
      'foundation@kca.ac.ke',
    ];
    return adminEmails.contains(email.toLowerCase());
  }

  /// Convert Firebase error codes to user-friendly messages
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
}