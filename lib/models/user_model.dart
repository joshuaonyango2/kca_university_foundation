// lib/models/user_model.dart

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? phoneNumber;
  final String? profileImageUrl;
  final UserRole role;
  final DonorType? donorType;       // ✅ NEW — individual, corporate, partner
  final bool isEmailVerified;
  final bool isPhoneVerified;
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
  String get firstName {
    final parts = name.split(' ');
    return parts.isNotEmpty ? parts[0] : name;
  }

  String get lastName {
    final parts = name.split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  String get fullName => name;

  bool get isAdmin  => role == UserRole.admin || role == UserRole.superAdmin;
  bool get isDonor  => role == UserRole.donor;

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  // ── Serialization ─────────────────────────────────────────────────────────
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:               json['id'] as String,
      email:            json['email'] as String,
      name:             json['name'] as String,
      phoneNumber:      json['phone_number'] as String?,
      profileImageUrl:  json['profile_image_url'] as String?,
      role:             _parseRole(json['role'] as String? ?? 'donor'),
      donorType:        _parseDonorType(json['donor_type'] as String?),
      isEmailVerified:  json['is_email_verified'] as bool? ?? false,
      isPhoneVerified:  json['is_phone_verified'] as bool? ?? false,
      createdAt:        DateTime.parse(json['created_at'] as String),
      lastLoginAt:      json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':                 id,
      'email':              email,
      'name':               name,
      'phone_number':       phoneNumber,
      'profile_image_url':  profileImageUrl,
      'role':               role.name,
      'donor_type':         donorType?.name,
      'is_email_verified':  isEmailVerified,
      'is_phone_verified':  isPhoneVerified,
      'created_at':         createdAt.toIso8601String(),
      'last_login_at':      lastLoginAt?.toIso8601String(),
    };
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static UserRole _parseRole(String roleString) {
    switch (roleString) {
      case 'admin':       return UserRole.admin;
      case 'super_admin': return UserRole.superAdmin;
      default:            return UserRole.donor;
    }
  }

  static DonorType? _parseDonorType(String? value) {
    switch (value) {
      case 'individual':  return DonorType.individual;
      case 'corporate':   return DonorType.corporate;
      case 'partner':     return DonorType.partner;
      default:            return null;
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

enum DonorType {
  individual,
  corporate,
  partner;

  String get displayName {
    switch (this) {
      case DonorType.individual: return 'Individual';
      case DonorType.corporate:  return 'Corporate';
      case DonorType.partner:    return 'Partner';
    }
  }

  String get description {
    switch (this) {
      case DonorType.individual:
        return 'Personal donations for scholarships, infrastructure & more';
      case DonorType.corporate:
        return 'CSR giving with receipts and named endowment branding';
      case DonorType.partner:
        return 'Strategic partnership with pledge workflows & reporting';
    }
  }

  String get icon {
    switch (this) {
      case DonorType.individual: return '👤';
      case DonorType.corporate:  return '🏢';
      case DonorType.partner:    return '🤝';
    }
  }
}