// lib/models/staff_model.dart

class StaffModel {
  final String       id;
  final String       name;
  final String       email;
  final String       roleId;
  final String       roleName;
  final List<String> permissions;
  final bool         isAdmin;
  final bool         isActive;
  final DateTime     createdAt;
  final String?      createdBy;
  final DateTime?    lastLoginAt;

  const StaffModel({
    required this.id,
    required this.name,
    required this.email,
    required this.roleId,
    required this.roleName,
    required this.permissions,
    this.isAdmin    = false,
    this.isActive   = true,
    required this.createdAt,
    this.createdBy,
    this.lastLoginAt,
  });

  bool hasPermission(String permissionKey) =>
      isAdmin || permissions.contains(permissionKey);

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'S';
  }

  Map<String, dynamic> toJson() => {
    'id':            id,
    'name':          name,
    'email':         email,
    'role_id':       roleId,
    'role_name':     roleName,
    'permissions':   permissions,
    'is_admin':      isAdmin,
    'is_active':     isActive,
    'created_at':    createdAt.toIso8601String(),
    'created_by':    createdBy,
    'last_login_at': lastLoginAt?.toIso8601String(),
  };

  factory StaffModel.fromJson(Map<String, dynamic> json) => StaffModel(
    id:           json['id'] as String? ?? '',
    name:         json['name'] as String? ?? '',
    email:        json['email'] as String? ?? '',
    roleId:       json['role_id'] as String? ?? '',
    roleName:     json['role_name'] as String? ?? '',
    permissions:  List<String>.from(json['permissions'] as List? ?? []),
    isAdmin:      json['is_admin'] as bool? ?? false,
    isActive:     json['is_active'] as bool? ?? true,
    createdAt:    DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
    createdBy:    json['created_by'] as String?,
    lastLoginAt:  json['last_login_at'] != null
        ? DateTime.tryParse(json['last_login_at'] as String)
        : null,
  );

  StaffModel copyWith({
    String?       roleId,
    String?       roleName,
    List<String>? permissions,
    bool?         isAdmin,
    bool?         isActive,
  }) {
    return StaffModel(
      id:          id,
      name:        name,
      email:       email,
      roleId:      roleId ?? this.roleId,
      roleName:    roleName ?? this.roleName,
      permissions: permissions ?? this.permissions,
      isAdmin:     isAdmin ?? this.isAdmin,
      isActive:    isActive ?? this.isActive,
      createdAt:   createdAt,
      createdBy:   createdBy,
      lastLoginAt: lastLoginAt,
    );
  }
}