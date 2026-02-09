// lib/models/user_model.dart

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? phoneNumber;
  final String? profileImageUrl;
  final UserRole role;
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
    required this.isEmailVerified,
    required this.isPhoneVerified,
    required this.createdAt,
    this.lastLoginAt,
  });

  // ✅ Add these getters
  String get firstName {
    final parts = name.split(' ');
    return parts.isNotEmpty ? parts[0] : name;
  }

  String get lastName {
    final parts = name.split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  String get fullName => name;

  // Check if user is admin
  bool get isAdmin => role == UserRole.admin || role == UserRole.superAdmin;

  // Check if user is donor
  bool get isDonor => role == UserRole.donor;

  // Get initials for avatar
  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  // fromJson
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      phoneNumber: json['phone_number'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      role: _parseRole(json['role'] as String),
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      isPhoneVerified: json['is_phone_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
    );
  }

  // toJson
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone_number': phoneNumber,
      'profile_image_url': profileImageUrl,
      'role': role.name,
      'is_email_verified': isEmailVerified,
      'is_phone_verified': isPhoneVerified,
      'created_at': createdAt.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
    };
  }

  static UserRole _parseRole(String roleString) {
    switch (roleString) {
      case 'donor':
        return UserRole.donor;
      case 'admin':
        return UserRole.admin;
      case 'super_admin':
        return UserRole.superAdmin;
      default:
        return UserRole.donor;
    }
  }
}

enum UserRole {
  donor,
  admin,
  superAdmin;

  String get displayName {
    switch (this) {
      case UserRole.donor:
        return 'Donor';
      case UserRole.admin:
        return 'Admin';
      case UserRole.superAdmin:
        return 'Super Admin';
    }
  }
}