// lib/models/user_model.dart

class UserModel {
  final String  id;
  final String  email;
  final String  name;
  final String? phoneNumber;
  final String? profileImageUrl;
  final UserRole role;

  /// Stores the donor_types doc ID (e.g. "individual", "corporate", "partner",
  /// or any custom ID added by the admin). Falls back to capitalizing the raw
  /// string for backward-compat with old records.
  final String? donorType;

  final bool     isEmailVerified;
  final bool     isPhoneVerified;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.phoneNumber,
    this.profileImageUrl,
    required this.role,
    this.donorType,
    required this.isEmailVerified,
    required this.isPhoneVerified,
    required this.createdAt,
    this.lastLoginAt,
  });

  // ── Getters ───────────────────────────────────────────────────────────────
  String get firstName => name.split(' ').first;
  String get lastName  => name.split(' ').length > 1
      ? name.split(' ').sublist(1).join(' ') : '';
  String get fullName  => name;

  bool get isAdmin => role == UserRole.admin || role == UserRole.superAdmin;
  bool get isDonor => role == UserRole.donor;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  /// Human-readable donor type label (works even without Firestore lookup).
  /// Use DonorTypeService.resolveDisplayName() for proper lookup when types
  /// list is available.
  String get donorTypeLabel {
    if (donorType == null || donorType!.isEmpty) return '';
    return donorType![0].toUpperCase() + donorType!.substring(1);
  }

  // ── Serialization ─────────────────────────────────────────────────────────
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id:               json['id']             as String,
    email:            json['email']          as String,
    name:             json['name']           as String,
    phoneNumber:      json['phone_number']   as String?,
    profileImageUrl:  json['profile_image_url'] as String?,
    role:             _parseRole(json['role'] as String? ?? 'donor'),
    donorType:        json['donor_type']     as String?,
    isEmailVerified:  json['is_email_verified'] as bool? ?? false,
    isPhoneVerified:  json['is_phone_verified']  as bool? ?? false,
    createdAt:        DateTime.parse(json['created_at'] as String),
    lastLoginAt:      json['last_login_at'] != null
        ? DateTime.parse(json['last_login_at'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    'id':                 id,
    'email':              email,
    'name':               name,
    'phone_number':       phoneNumber,
    'profile_image_url':  profileImageUrl,
    'role':               role.name,
    'donor_type':         donorType,
    'is_email_verified':  isEmailVerified,
    'is_phone_verified':  isPhoneVerified,
    'created_at':         createdAt.toIso8601String(),
    'last_login_at':      lastLoginAt?.toIso8601String(),
  };

  static UserRole _parseRole(String s) {
    switch (s) {
      case 'admin':       return UserRole.admin;
      case 'super_admin': return UserRole.superAdmin;
      default:            return UserRole.donor;
    }
  }
}

// ── Enums ─────────────────────────────────────────────────────────────────────
enum UserRole {
  donor,
  admin,
  superAdmin;

  String get displayName {
    switch (this) {
      case UserRole.donor:      return 'Donor';
      case UserRole.admin:      return 'Admin';
      case UserRole.superAdmin: return 'Super Admin';
    }
  }
}
// NOTE: DonorType is no longer a Dart enum.
// Types are now managed in Firestore via DonorTypeService.
// Use DonorTypeService.stream() / DonorTypeService.activeStream() to get types.