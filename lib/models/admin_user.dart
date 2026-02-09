// lib/models/admin_user.dart

class AdminUser {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final AdminRole role;
  final bool isActive;
  final Map<String, bool> permissions;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String? profileImage;

  AdminUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.isActive = true,
    required this.permissions,
    required this.createdAt,
    this.lastLogin,
    this.profileImage,
  });

  String get fullName => '$firstName $lastName';

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['_id'] ?? json['id'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      role: _parseRole(json['role']),
      isActive: json['isActive'] ?? true,
      permissions: _parsePermissions(json['permissions']),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      lastLogin: json['lastLogin'] != null
          ? DateTime.parse(json['lastLogin'])
          : null,
      profileImage: json['profileImage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role.toString().split('.').last,
      'isActive': isActive,
      'permissions': permissions,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'profileImage': profileImage,
    };
  }

  static AdminRole _parseRole(dynamic roleData) {
    if (roleData == null) return AdminRole.viewer;

    final roleString = roleData.toString().toLowerCase();
    switch (roleString) {
      case 'superadmin':
      case 'super_admin':
        return AdminRole.superAdmin;
      case 'campaignmanager':
      case 'campaign_manager':
        return AdminRole.campaignManager;
      case 'financeofficer':
      case 'finance_officer':
        return AdminRole.financeOfficer;
      case 'communications':
        return AdminRole.communications;
      case 'viewer':
        return AdminRole.viewer;
      default:
        return AdminRole.viewer;
    }
  }

  static Map<String, bool> _parsePermissions(dynamic permissionsData) {
    if (permissionsData == null) return {};

    if (permissionsData is Map) {
      return Map<String, bool>.from(
        permissionsData.map((key, value) => MapEntry(
          key.toString(),
          value == true || value == 'true',
        )),
      );
    }

    return {};
  }

  AdminUser copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    AdminRole? role,
    bool? isActive,
    Map<String, bool>? permissions,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? profileImage,
  }) {
    return AdminUser(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      profileImage: profileImage ?? this.profileImage,
    );
  }
}

// ============================================
// ADMIN ROLE ENUM
// ============================================

enum AdminRole {
  superAdmin,
  campaignManager,
  financeOfficer,
  communications,
  viewer,
}

extension AdminRoleExtension on AdminRole {
  String get displayName {
    switch (this) {
      case AdminRole.superAdmin:
        return 'Super Admin';
      case AdminRole.campaignManager:
        return 'Campaign Manager';
      case AdminRole.financeOfficer:
        return 'Finance Officer';
      case AdminRole.communications:
        return 'Communications';
      case AdminRole.viewer:
        return 'Viewer';
    }
  }

  String get description {
    switch (this) {
      case AdminRole.superAdmin:
        return 'Full system access and user management';
      case AdminRole.campaignManager:
        return 'Manage campaigns and view donations';
      case AdminRole.financeOfficer:
        return 'Access financial reports and transactions';
      case AdminRole.communications:
        return 'Manage content and communications';
      case AdminRole.viewer:
        return 'Read-only access to reports';
    }
  }

  Map<String, bool> get defaultPermissions {
    switch (this) {
      case AdminRole.superAdmin:
        return {
          'manage_users': true,
          'manage_campaigns': true,
          'manage_donations': true,
          'view_reports': true,
          'manage_settings': true,
          'export_data': true,
          'delete_data': true,
        };
      case AdminRole.campaignManager:
        return {
          'manage_users': false,
          'manage_campaigns': true,
          'manage_donations': false,
          'view_reports': true,
          'manage_settings': false,
          'export_data': true,
          'delete_data': false,
        };
      case AdminRole.financeOfficer:
        return {
          'manage_users': false,
          'manage_campaigns': false,
          'manage_donations': true,
          'view_reports': true,
          'manage_settings': false,
          'export_data': true,
          'delete_data': false,
        };
      case AdminRole.communications:
        return {
          'manage_users': false,
          'manage_campaigns': false,
          'manage_donations': false,
          'view_reports': true,
          'manage_settings': false,
          'export_data': false,
          'delete_data': false,
        };
      case AdminRole.viewer:
        return {
          'manage_users': false,
          'manage_campaigns': false,
          'manage_donations': false,
          'view_reports': true,
          'manage_settings': false,
          'export_data': false,
          'delete_data': false,
        };
    }
  }
}