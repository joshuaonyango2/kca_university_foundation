// lib/models/role_model.dart

// ── Permissions ───────────────────────────────────────────────────────────────
enum Permission {
  viewDashboard,
  viewCampaigns,
  manageCampaigns,   // create, edit, delete
  viewDonors,
  manageDonors,
  viewTransactions,
  exportData,
  manageStaff,
  manageRoles,
  grantAdmin,
}

extension PermissionExt on Permission {
  String get key {
    switch (this) {
      case Permission.viewDashboard:     return 'view_dashboard';
      case Permission.viewCampaigns:     return 'view_campaigns';
      case Permission.manageCampaigns:   return 'manage_campaigns';
      case Permission.viewDonors:        return 'view_donors';
      case Permission.manageDonors:      return 'manage_donors';
      case Permission.viewTransactions:  return 'view_transactions';
      case Permission.exportData:        return 'export_data';
      case Permission.manageStaff:       return 'manage_staff';
      case Permission.manageRoles:       return 'manage_roles';
      case Permission.grantAdmin:        return 'grant_admin';
    }
  }

  String get label {
    switch (this) {
      case Permission.viewDashboard:     return 'View Dashboard';
      case Permission.viewCampaigns:     return 'View Campaigns';
      case Permission.manageCampaigns:   return 'Manage Campaigns';
      case Permission.viewDonors:        return 'View Donors';
      case Permission.manageDonors:      return 'Manage Donors';
      case Permission.viewTransactions:  return 'View Transactions';
      case Permission.exportData:        return 'Export Data';
      case Permission.manageStaff:       return 'Manage Staff';
      case Permission.manageRoles:       return 'Manage Roles';
      case Permission.grantAdmin:        return 'Grant Admin Access';
    }
  }

  String get group {
    switch (this) {
      case Permission.viewDashboard:                    return 'Dashboard';
      case Permission.viewCampaigns:
      case Permission.manageCampaigns:                  return 'Campaigns';
      case Permission.viewDonors:
      case Permission.manageDonors:                     return 'Donors';
      case Permission.viewTransactions:
      case Permission.exportData:                       return 'Reports';
      case Permission.manageStaff:
      case Permission.manageRoles:
      case Permission.grantAdmin:                       return 'Administration';
    }
  }

  static Permission? fromKey(String key) {
    for (final p in Permission.values) {
      if (p.key == key) return p;
    }
    return null;
  }
}

// ── Role Model ────────────────────────────────────────────────────────────────
class RoleModel {
  final String         id;
  final String         name;
  final String         description;
  final List<String>   permissions; // list of Permission.key values
  final bool           isDefault;   // built-in roles can't be deleted
  final int            staffCount;
  final DateTime?      createdAt;

  const RoleModel({
    required this.id,
    required this.name,
    required this.description,
    required this.permissions,
    this.isDefault  = false,
    this.staffCount = 0,
    this.createdAt,
  });

  bool hasPermission(Permission p) => permissions.contains(p.key);

  List<Permission> get permissionObjects => permissions
      .map((k) => PermissionExt.fromKey(k))
      .whereType<Permission>()
      .toList();

  RoleModel copyWith({
    String?       name,
    String?       description,
    List<String>? permissions,
    int?          staffCount,
  }) {
    return RoleModel(
      id:          id,
      name:        name ?? this.name,
      description: description ?? this.description,
      permissions: permissions ?? this.permissions,
      isDefault:   isDefault,
      staffCount:  staffCount ?? this.staffCount,
      createdAt:   createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id':          id,
    'name':        name,
    'description': description,
    'permissions': permissions,
    'is_default':  isDefault,
    'created_at':  createdAt?.toIso8601String() ??
        DateTime.now().toIso8601String(),
  };

  factory RoleModel.fromJson(Map<String, dynamic> json) => RoleModel(
    id:          json['id'] as String? ?? '',
    name:        json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    permissions: List<String>.from(json['permissions'] as List? ?? []),
    isDefault:   json['is_default'] as bool? ?? false,
    staffCount:  json['staff_count'] as int? ?? 0,
    createdAt:   json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String)
        : null,
  );

  // ── Default KCA managerial roles ───────────────────────────────────────────
  static List<RoleModel> get defaults => [
    RoleModel(
      id:          'executive_director',
      name:        'Executive Director',
      description: 'Full administrative access across all modules.',
      isDefault:   true,
      permissions: Permission.values.map((p) => p.key).toList(), // ALL
    ),
    RoleModel(
      id:          'resource_mobilization_manager',
      name:        'Manager of Resource Mobilization',
      description: 'Manages fundraising campaigns and donor relations.',
      isDefault:   true,
      permissions: [
        Permission.viewDashboard.key,
        Permission.viewCampaigns.key,
        Permission.manageCampaigns.key,
        Permission.viewDonors.key,
        Permission.manageDonors.key,
        Permission.viewTransactions.key,
        Permission.exportData.key,
      ],
    ),
    RoleModel(
      id:          'asst_director_development',
      name:        'Asst. Director — Development & Investment',
      description: 'Oversees development projects and investment tracking.',
      isDefault:   true,
      permissions: [
        Permission.viewDashboard.key,
        Permission.viewCampaigns.key,
        Permission.manageCampaigns.key,
        Permission.viewDonors.key,
        Permission.viewTransactions.key,
        Permission.exportData.key,
      ],
    ),
    RoleModel(
      id:          'administrator',
      name:        'Administrator',
      description: 'System administration — staff and content management.',
      isDefault:   true,
      permissions: [
        Permission.viewDashboard.key,
        Permission.viewCampaigns.key,
        Permission.manageCampaigns.key,
        Permission.viewDonors.key,
        Permission.manageDonors.key,
        Permission.viewTransactions.key,
        Permission.exportData.key,
        Permission.manageStaff.key,
        Permission.manageRoles.key,
      ],
    ),
    RoleModel(
      id:          'deputy_director_donor',
      name:        'Deputy Director — Donor Engagement & Comms',
      description: 'Leads donor communications and engagement strategy.',
      isDefault:   true,
      permissions: [
        Permission.viewDashboard.key,
        Permission.viewCampaigns.key,
        Permission.viewDonors.key,
        Permission.manageDonors.key,
        Permission.viewTransactions.key,
        Permission.exportData.key,
      ],
    ),
  ];
}