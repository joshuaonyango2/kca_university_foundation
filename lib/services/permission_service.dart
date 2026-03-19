// lib/services/permission_service.dart
//
// ── Permission Model ───────────────────────────────────────────────────────────
//
//  RULE: Nobody bypasses permission checks — not even super-admin accounts.
//  Every can(Permission) call evaluates against the permissions[] list stored
//  in the user's Firestore staff document.
//
//  isSuperAdmin is a UI-only flag meaning:
//    • This account is the primary system owner (admin@kca.ac.ke / foundation@kca.ac.ke)
//    • Their card is padlocked — cannot be edited, deleted, or demoted by others
//    • Their permissions are bootstrapped with every key on first login
//    • It does NOT grant any automatic access — Firestore permissions still apply
//
//  is_admin (Firestore flag) means:
//    • This account can access the full admin dashboard (login routing decision)
//    • Does NOT mean "bypass all permission checks"
//    • Can be granted/revoked by anyone holding the grantAdmin permission
//    • Super-admin accounts always have is_admin: true and is_super_admin: true
//
//  Flow on login:
//    1. If email is in _kSuperAdminEmails and no staff doc exists → auto-seed one
//       with all permissions + is_admin: true + is_super_admin: true
//    2. Stream the staff doc; evaluate can() purely from permissions[]
//    3. Any change to permissions[] in Firestore propagates instantly via stream

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/role_model.dart';

// ── Protected super-admin email addresses ─────────────────────────────────────
// These accounts are padlocked in the UI and auto-seeded with all permissions,
// but they still go through the normal Firestore permission check like everyone.
const kSuperAdminEmails = {'admin@kca.ac.ke', 'foundation@kca.ac.ke'};

// ── AdminContext ──────────────────────────────────────────────────────────────
class AdminContext {
  /// Whether this is a protected super-admin account (UI label + padlock only).
  /// Does NOT grant automatic access — permissions[] still governs everything.
  final bool         isSuperAdmin;

  /// The explicit list of permission keys this user holds.
  /// This is the ONLY thing that grants access to any action.
  final List<String> permissions;

  const AdminContext({
    required this.isSuperAdmin,
    required this.permissions,
  });

  static const empty = AdminContext(isSuperAdmin: false, permissions: []);

  /// The single gate for every privileged action.
  /// Returns true only if the permission key is in the list — always.
  /// No bypass, no shortcuts. Even isSuperAdmin=true must have the key.
  bool can(Permission permission) =>
      permissions.contains(permission.key);

  /// True if the user holds ANY of the listed permissions.
  bool canAny(List<Permission> perms) =>
      perms.any((p) => permissions.contains(p.key));

  bool get isAuthenticated => permissions.isNotEmpty || isSuperAdmin;
}

// ── Service ───────────────────────────────────────────────────────────────────
class PermissionService {
  static final _db   = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── Live permission stream ─────────────────────────────────────────────────
  /// Streams the AdminContext for the currently signed-in user.
  /// Re-emits on every Firestore change so revocations take effect immediately.
  static Stream<AdminContext> contextStream() async* {
    await for (final user in _auth.authStateChanges()) {
      if (user == null) {
        yield AdminContext.empty;
        continue;
      }

      final email = user.email?.toLowerCase() ?? '';
      final isSA  = kSuperAdminEmails.contains(email);

      // Ensure super-admin accounts have a staff doc with all permissions.
      // This is a one-time bootstrap that runs on first login; afterwards
      // the doc already exists so this is a fast no-op.
      if (isSA) await _ensureSuperAdminDoc(user.uid, user.email ?? '');

      // Stream the staff doc — same for everyone, no special path
      yield* _db
          .collection('staff')
          .doc(user.uid)
          .snapshots()
          .map((snap) {
        if (!snap.exists) return AdminContext.empty;
        final d    = snap.data()!;
        final isSADoc = d['is_super_admin'] as bool? ?? false;
        final perms   = List<String>.from(d['permissions'] as List? ?? []);
        return AdminContext(isSuperAdmin: isSADoc, permissions: perms);
      });
    }
  }

  // ── One-shot load ──────────────────────────────────────────────────────────
  static Future<AdminContext> load() async {
    final user = _auth.currentUser;
    if (user == null) return AdminContext.empty;

    final email = user.email?.toLowerCase() ?? '';
    final isSA  = kSuperAdminEmails.contains(email);
    if (isSA) await _ensureSuperAdminDoc(user.uid, user.email ?? '');

    try {
      final doc = await _db.collection('staff').doc(user.uid).get();
      if (!doc.exists) return AdminContext.empty;
      final d     = doc.data()!;
      final isSAD = d['is_super_admin'] as bool? ?? false;
      final perms = List<String>.from(d['permissions'] as List? ?? []);
      return AdminContext(isSuperAdmin: isSAD, permissions: perms);
    } catch (_) {
      return AdminContext.empty;
    }
  }

  // ── Super-admin staff-doc bootstrap ───────────────────────────────────────
  /// Creates or upgrades the staff doc for a super-admin account so they have:
  ///   • is_super_admin: true  (padlock UI flag — cannot be set for anyone else)
  ///   • is_admin: true        (admin dashboard access)
  ///   • permissions: [all]    (every key — set explicitly, not bypassed)
  ///
  /// Uses SetOptions(merge: true) so manual edits to the doc are preserved
  /// and a subsequent login never silently downgrades their permissions.
  static Future<void> _ensureSuperAdminDoc(String uid, String email) async {
    try {
      final ref  = _db.collection('staff').doc(uid);
      final snap = await ref.get();

      if (!snap.exists) {
        // First login — create the full doc
        final allPerms = Permission.values.map((p) => p.key).toList();
        await ref.set({
          'id':             uid,
          'name':           email.split('@').first
              .replaceAll('.', ' ')
              .split(' ')
              .map((w) => w.isEmpty ? '' :
          w[0].toUpperCase() + w.substring(1))
              .join(' '),
          'email':          email,
          'role_id':        'executive_director',
          'role_name':      'Executive Director',
          'permissions':    allPerms,
          'is_admin':       true,
          'is_super_admin': true,
          'is_active':      true,
          'created_at':     DateTime.now().toIso8601String(),
          'created_by':     'system',
        });
        debugPrint('✅ PermissionService: super-admin doc created for $email');
      } else {
        // Doc exists — ensure the protected flags are still correct and
        // make sure they have all current permissions (handles new permissions
        // added in future app updates)
        final d         = snap.data()!;
        final existing  = List<String>.from(d['permissions'] as List? ?? []);
        final allPerms  = Permission.values.map((p) => p.key).toList();
        final missing   = allPerms.where((k) => !existing.contains(k)).toList();
        final updates   = <String, dynamic>{
          'is_admin':       true,
          'is_super_admin': true,
        };
        if (missing.isNotEmpty) {
          updates['permissions'] = [...existing, ...missing];
          debugPrint('✅ PermissionService: added ${missing.length} new '
              'permissions to super-admin $email');
        }
        await ref.update(updates);
      }
    } catch (e) {
      debugPrint('⚠️ PermissionService._ensureSuperAdminDoc: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  static bool isSuperAdminEmail(String? email) =>
      kSuperAdminEmails.contains(email?.toLowerCase());
}