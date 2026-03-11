// lib/providers/staff_provider.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import '../models/staff_model.dart';
import '../models/role_model.dart';

class StaffProvider extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;

  List<StaffModel> _staff     = [];
  List<RoleModel>  _roles     = [];
  bool             _isLoading = false;
  String?          _error;

  List<StaffModel> get staff     => _staff;
  List<RoleModel>  get roles     => _roles;
  bool             get isLoading => _isLoading;
  String?          get error     => _error;

  StaffProvider() {
    // Seed default roles on startup (idempotent)
    bootstrapRoles();
  }

  // ── Bootstrap default roles ────────────────────────────────────────────────
  Future<void> bootstrapRoles() async {
    try {
      final snap = await _firestore.collection('roles').limit(1).get();
      if (snap.docs.isEmpty) {
        // Try batch write first
        try {
          final batch = _firestore.batch();
          for (final role in RoleModel.defaults) {
            final ref = _firestore.collection('roles').doc(role.id);
            batch.set(ref, role.toJson());
          }
          await batch.commit();
          debugPrint('✅ StaffProvider: default roles seeded');
        } catch (writeErr) {
          // Write blocked by rules — seed individually with merge so partial writes succeed
          debugPrint('⚠️ Batch write blocked ($writeErr), trying individual writes…');
          for (final role in RoleModel.defaults) {
            try {
              await _firestore
                  .collection('roles')
                  .doc(role.id)
                  .set(role.toJson(), SetOptions(merge: true));
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ StaffProvider.bootstrapRoles: $e');
    }
  }

  // ── Roles stream ──────────────────────────────────────────────────────────
  Stream<List<RoleModel>> rolesStream() {
    return _firestore
        .collection('roles')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return RoleModel.fromJson(data);
    }).toList());
  }

  Future<bool> createRole(RoleModel role) async {
    try {
      final ref  = _firestore.collection('roles').doc();
      final data = role.toJson();
      data['id'] = ref.id;
      await ref.set(data);
      return true;
    } catch (e) {
      _error = 'Failed to create role: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateRole(RoleModel role) async {
    try {
      await _firestore.collection('roles').doc(role.id).update({
        'name':        role.name,
        'description': role.description,
        'permissions': role.permissions,
      });
      return true;
    } catch (e) {
      _error = 'Failed to update role: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRole(String roleId) async {
    try {
      final snap = await _firestore
          .collection('staff')
          .where('role_id', isEqualTo: roleId)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        _error = 'Cannot delete: staff members are assigned to this role.';
        notifyListeners();
        return false;
      }
      await _firestore.collection('roles').doc(roleId).delete();
      return true;
    } catch (e) {
      _error = 'Failed to delete role: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Staff stream ──────────────────────────────────────────────────────────
  Stream<List<StaffModel>> staffStream() {
    return _firestore
        .collection('staff')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return StaffModel.fromJson(data);
    }).toList());
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ONBOARD STAFF
  // Uses 3 strategies in order — falls back if the previous one fails.
  //
  // Strategy A: Firebase REST API signUp (preserves admin session — preferred)
  // Strategy B: Firebase Auth Admin SDK createUser (if REST fails)
  // Strategy C: Firestore-only record (manual — requires staff to sign up later)
  // ════════════════════════════════════════════════════════════════════════════
  Future<({bool success, String? error, String? uid})> onboardStaff({
    required String    name,
    required String    email,
    required String    tempPassword,
    required RoleModel role,
    required bool      isAdmin,
    required String    createdByEmail,
    String             phone = '',
  }) async {
    // ── Step A: REST API sign-up ───────────────────────────────────────────
    final restResult = await _createAuthViaRest(email: email, password: tempPassword);

    if (restResult.success) {
      final uid = restResult.uid!;
      await _writeStaffDoc(
        uid: uid, name: name, email: email, role: role,
        isAdmin: isAdmin, createdBy: createdByEmail,
      );
      await _sendPasswordResetEmail(email);
      return (success: true, error: null, uid: uid);
    }

    debugPrint('REST API failed: ${restResult.error}');

    // ── Step B: Direct Firebase Auth (signs admin out — only if REST fails) ─
    // ── Step B: Secondary FirebaseApp (does NOT sign out the admin) ──────────
    if (restResult.error != 'EMAIL_EXISTS') {
      debugPrint('⚡ REST failed (${restResult.error}), trying secondary app…');
      final secResult = await _createAuthViaSecondaryApp(
          email: email, password: tempPassword);
      if (secResult.success) {
        final uid = secResult.uid!;
        await _writeStaffDoc(
          uid: uid, name: name, email: email, role: role,
          isAdmin: isAdmin, createdBy: createdByEmail, phone: phone,
        );
        await _sendPasswordResetEmail(email);
        return (success: true, error: null, uid: uid);
      }
      debugPrint('⚠️ Secondary app also failed: ${secResult.error}');
    }

    // ── Step C: EMAIL_EXISTS — Auth account already there, just write doc ────
    if (restResult.error == 'EMAIL_EXISTS') {
      return await _firestoreOnlyRecord(
        email: email, name: name, role: role,
        isAdmin: isAdmin, createdBy: createdByEmail,
      );
    }

    // Collect both errors for a useful message
    return (
    success: false,
    error:   _friendlyError(restResult.error ?? 'Unknown error'),
    uid:     null,
    );
  }

  // ── Strategy A: REST API ───────────────────────────────────────────────────
  Future<({bool success, String? uid, String? error})> _createAuthViaRest({
    required String email,
    required String password,
  }) async {
    try {
      final apiKey  = Firebase.app().options.apiKey;
      final url     = 'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey';
      final resp    = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email':             email,
          'password':          password,
          'returnSecureToken': false,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      debugPrint('REST signUp status: ${resp.statusCode}, body keys: ${body.keys}');

      if (resp.statusCode == 200) {
        final uid = body['localId'] as String?;
        if (uid == null || uid.isEmpty) {
          return (success: false, uid: null, error: 'No UID in response');
        }
        return (success: true, uid: uid, error: null);
      }

      final errCode = (body['error'] as Map?)?['message'] as String? ?? 'UNKNOWN';
      return (success: false, uid: null, error: errCode);
    } catch (e) {
      return (success: false, uid: null, error: 'Network error: $e');
    }
  }

  // ── Strategy B: Secondary FirebaseApp (safe — admin session NEVER touched) ──
  //
  // Creates an isolated FirebaseApp with the same credentials, registers the
  // new user inside that app, then disposes it.  The primary app (and the
  // logged-in admin) are completely unaffected.
  Future<({bool success, String? uid, String? error})> _createAuthViaSecondaryApp({
    required String email,
    required String password,
  }) async {
    FirebaseApp? secondaryApp;
    try {
      // Give each call a unique app name so concurrent calls never conflict
      final appName = 'kca_staff_creator_\${DateTime.now().millisecondsSinceEpoch}';
      secondaryApp  = await Firebase.initializeApp(
        name:    appName,
        options: Firebase.app().options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final cred          = await secondaryAuth.createUserWithEmailAndPassword(
        email:    email,
        password: password,
      );
      final newUid = cred.user!.uid;

      // Sign out from the secondary app — the primary admin is still signed in
      await secondaryAuth.signOut();
      return (success: true, uid: newUid, error: null);

    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ Secondary app auth error: \${e.code}');
      return (success: false, uid: null, error: e.code.toUpperCase());
    } catch (e) {
      debugPrint('⚠️ Secondary app error: \$e');
      return (success: false, uid: null, error: e.toString());
    } finally {
      // Always clean up the secondary app
      try { await secondaryApp?.delete(); } catch (_) {}
    }
  }

  // ── Strategy C: Firestore-only (email already exists in Auth) ─────────────
  Future<({bool success, String? error, String? uid})> _firestoreOnlyRecord({
    required String    email,
    required String    name,
    required RoleModel role,
    required bool      isAdmin,
    required String    createdBy,
  }) async {
    try {
      // Check if a staff doc already exists for this email
      final existing = await _firestore
          .collection('staff')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Update existing record
        await existing.docs.first.reference.update({
          'name':        name,
          'role_id':     role.id,
          'role_name':   role.name,
          'permissions': role.permissions,
          'is_admin':    isAdmin,
          'is_active':   true,
          'updated_at':  DateTime.now().toIso8601String(),
        });
        return (success: true, error: null, uid: existing.docs.first.id);
      }

      // Create a placeholder staff doc — UID will be set when they first log in
      final ref = _firestore.collection('staff').doc();
      await ref.set({
        'id':          ref.id,
        'name':        name,
        'email':       email,
        'role_id':     role.id,
        'role_name':   role.name,
        'permissions': role.permissions,
        'is_admin':    isAdmin,
        'is_active':   true,
        'pending_uid': true,   // flag: UID not yet linked to Auth account
        'created_at':  DateTime.now().toIso8601String(),
        'created_by':  createdBy,
      });

      await _sendPasswordResetEmail(email);
      return (success: true, error: null, uid: ref.id);
    } catch (e) {
      return (success: false, error: 'Firestore error: $e', uid: null);
    }
  }

  // ── Write staff Firestore document ─────────────────────────────────────────
  Future<void> _writeStaffDoc({
    required String    uid,
    required String    name,
    required String    email,
    required RoleModel role,
    required bool      isAdmin,
    required String    createdBy,
    String             phone = '',
  }) async {
    await _firestore.collection('staff').doc(uid).set({
      'id':          uid,
      'name':        name,
      'email':       email,
      'role_id':     role.id,
      'role_name':   role.name,
      'permissions': role.permissions,
      'is_admin':    isAdmin,
      'is_active':   true,
      'created_at':  DateTime.now().toIso8601String(),
      'created_by':  createdBy,
      'phone':       phone,
      'department':  role.name,
    }, SetOptions(merge: true));
  }

  // ── Send password reset email ──────────────────────────────────────────────
  Future<void> _sendPasswordResetEmail(String email) async {
    try {
      final apiKey = Firebase.app().options.apiKey;
      await http.post(
        Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestType': 'PASSWORD_RESET', 'email': email}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('⚠️ Could not send password reset email: $e');
    }
  }

  // ── Quick test: verify Firebase Auth REST API is reachable ─────────────────
  Future<String> testFirebaseAuthConnection() async {
    try {
      final apiKey = Firebase.app().options.apiKey;
      if (apiKey.isEmpty) return '❌ API key is empty';

      // Hit the REST endpoint with a dummy email to test connectivity
      final resp = await http.post(
        Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email':    'test-connectivity-check@test-domain.invalid',
          'password': 'testpass123',
        }),
      ).timeout(const Duration(seconds: 10));

      final body   = jsonDecode(resp.body) as Map<String, dynamic>;
      final errMsg = (body['error'] as Map?)?['message'] as String? ?? '';

      if (resp.statusCode == 200) return '✅ REST API working';

      // OPERATION_NOT_ALLOWED means Email/Password auth is DISABLED in Firebase Console
      if (errMsg == 'OPERATION_NOT_ALLOWED') {
        return '❌ Email/Password sign-in is DISABLED.\n'
            'Go to: Firebase Console → Authentication → Sign-in method → Email/Password → Enable';
      }
      if (errMsg == 'INVALID_EMAIL') return '✅ REST API reachable (expected error)';
      if (errMsg.contains('API_KEY')) {
        return '❌ Invalid API key. Check firebase_options.dart';
      }

      return '⚠️ Unexpected response: $errMsg (status ${resp.statusCode})';
    } catch (e) {
      return '❌ Network error: $e';
    }
  }

  // ── Update staff role ──────────────────────────────────────────────────────
  Future<bool> updateStaffRole({
    required String    staffId,
    required RoleModel role,
    required bool      isAdmin,
  }) async {
    try {
      await _firestore.collection('staff').doc(staffId).update({
        'role_id':     role.id,
        'role_name':   role.name,
        'permissions': role.permissions,
        'is_admin':    isAdmin,
      });
      return true;
    } catch (e) {
      _error = 'Failed to update staff role: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleStaffActive(String staffId, bool current) async {
    try {
      await _firestore.collection('staff').doc(staffId).update({'is_active': !current});
      return true;
    } catch (e) {
      _error = 'Failed to toggle staff status: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> setAdminAccess(String staffId, bool grant) async {
    try {
      await _firestore.collection('staff').doc(staffId).update({'is_admin': grant});
      return true;
    } catch (e) {
      _error = 'Failed to update admin access: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteStaff(String staffId) async {
    try {
      await _firestore.collection('staff').doc(staffId).delete();
      return true;
    } catch (e) {
      _error = 'Failed to delete staff member: $e';
      notifyListeners();
      return false;
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'EMAIL_EXISTS':
      case 'EMAIL-ALREADY-IN-USE':
        return 'This email already has an account. The staff record has been created — '
            'they can log in using their existing password.';
      case 'INVALID_EMAIL':
      case 'INVALID-EMAIL':
        return 'Invalid email address format.';
      case 'WEAK_PASSWORD':
      case 'WEAK-PASSWORD':
        return 'Password too weak. Use at least 6 characters with mixed characters.';
      case 'OPERATION_NOT_ALLOWED':
        return 'Email/Password sign-in is disabled in Firebase Console.\n'
            'Fix: Firebase Console → Authentication → Sign-in method → '
            'Email/Password → Enable it.';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
      case 'TOO-MANY-REQUESTS':
        return 'Too many requests from this device. Wait a few minutes and try again.';
      case 'ADMIN_ONLY_OPERATION':
        return 'Insufficient permissions. Ensure you are signed in as a verified admin.';
      case 'NETWORK_REQUEST_FAILED':
      case 'NETWORK-REQUEST-FAILED':
        return 'Network error. Check your internet connection and try again.';
      case 'INTERNAL_ERROR':
        return 'Firebase internal error. Try again or check Firebase project status.';
      default:
        if (code.contains('Network error')) return code;
        return 'Error ($code). Try the diagnostic tool to identify the cause.';
    }
  }
}