// lib/models/role_model.dart

import 'package:flutter/material.dart';

// ── Permissions ───────────────────────────────────────────────────────────────
enum Permission {
  // Dashboard
  viewDashboard,

  // Campaigns
  viewCampaigns,
  manageCampaigns,      // create / edit / delete campaigns
  manageCategories,     // add / edit / delete campaign categories & subcategories

  // Donors
  viewDonors,
  manageDonors,         // edit donor profiles, add manual donors
  deleteDonors,         // permanently delete a donor from the system

  // Donations / Transactions
  viewTransactions,
  manageDonations,      // manually add / adjust / remove a donation record
  exportData,

  // Donor Types
  manageDonorTypes,     // add / edit / delete donor types shown at registration

  // Payment Methods
  managePaymentMethods, // add / edit / activate / delete M-Pesa, bank, PayPal etc.

  // Administration
  manageStaff,          // invite / edit / deactivate staff accounts
  manageRoles,          // create / edit / delete permission roles
  grantAdmin,           // promote/demote other admins; super-admin gate
}

extension PermissionExt on Permission {
  String get key {
    switch (this) {
      case Permission.viewDashboard:         return 'view_dashboard';
      case Permission.viewCampaigns:         return 'view_campaigns';
      case Permission.manageCampaigns:       return 'manage_campaigns';
      case Permission.manageCategories:      return 'manage_categories';
      case Permission.viewDonors:            return 'view_donors';
      case Permission.manageDonors:          return 'manage_donors';
      case Permission.deleteDonors:          return 'delete_donors';
      case Permission.viewTransactions:      return 'view_transactions';
      case Permission.manageDonations:       return 'manage_donations';
      case Permission.exportData:            return 'export_data';
      case Permission.manageDonorTypes:      return 'manage_donor_types';
      case Permission.managePaymentMethods:  return 'manage_payment_methods';
      case Permission.manageStaff:           return 'manage_staff';
      case Permission.manageRoles:           return 'manage_roles';
      case Permission.grantAdmin:            return 'grant_admin';
    }
  }

  String get label {
    switch (this) {
      case Permission.viewDashboard:         return 'View Dashboard';
      case Permission.viewCampaigns:         return 'View Campaigns';
      case Permission.manageCampaigns:       return 'Manage Campaigns';
      case Permission.manageCategories:      return 'Manage Categories & Subcategories';
      case Permission.viewDonors:            return 'View Donors';
      case Permission.manageDonors:          return 'Manage Donors (Edit / Add)';
      case Permission.deleteDonors:          return 'Delete Donors';
      case Permission.viewTransactions:      return 'View Transactions';
      case Permission.manageDonations:       return 'Manage Donations (Add / Remove)';
      case Permission.exportData:            return 'Export Data';
      case Permission.manageDonorTypes:      return 'Manage Donor Types';
      case Permission.managePaymentMethods:  return 'Manage Payment Methods';
      case Permission.manageStaff:           return 'Manage Staff';
      case Permission.manageRoles:           return 'Manage Roles';
      case Permission.grantAdmin:            return 'Grant / Revoke Admin Access';
    }
  }

  String get description {
    switch (this) {
      case Permission.viewDashboard:         return 'Access the admin dashboard overview';
      case Permission.viewCampaigns:         return 'View campaign list and details';
      case Permission.manageCampaigns:       return 'Create, edit and delete campaigns';
      case Permission.manageCategories:      return 'Add, rename and remove campaign categories and their subcategories';
      case Permission.viewDonors:            return 'View donor profiles and history';
      case Permission.manageDonors:          return 'Edit donor profiles, add donors manually';
      case Permission.deleteDonors:          return 'Permanently remove a donor from the system';
      case Permission.viewTransactions:      return 'View all donation transactions';
      case Permission.manageDonations:       return 'Manually record, adjust or remove donation entries';
      case Permission.exportData:            return 'Download CSV / PDF reports';
      case Permission.manageDonorTypes:      return 'Add, edit or remove donor type options shown at registration';
      case Permission.managePaymentMethods:  return 'Configure payment gateways: M-Pesa, Bank, PayPal, etc.';
      case Permission.manageStaff:           return 'Invite, edit and deactivate staff accounts';
      case Permission.manageRoles:           return 'Create and modify permission roles';
      case Permission.grantAdmin:            return 'Promote staff to admin or revoke admin access';
    }
  }

  String get group {
    switch (this) {
      case Permission.viewDashboard:
        return 'Dashboard';
      case Permission.viewCampaigns:
      case Permission.manageCampaigns:
      case Permission.manageCategories:
        return 'Campaigns';
      case Permission.viewDonors:
      case Permission.manageDonors:
      case Permission.deleteDonors:
        return 'Donors';
      case Permission.viewTransactions:
      case Permission.manageDonations:
      case Permission.exportData:
        return 'Donations & Reports';
      case Permission.manageDonorTypes:
      case Permission.managePaymentMethods:
        return 'System Settings';
      case Permission.manageStaff:
      case Permission.manageRoles:
      case Permission.grantAdmin:
        return 'Administration';
    }
  }

  IconData get icon {
    switch (this) {
      case Permission.viewDashboard:         return Icons.dashboard_outlined;
      case Permission.viewCampaigns:         return Icons.campaign_outlined;
      case Permission.manageCampaigns:       return Icons.edit_note_outlined;
      case Permission.manageCategories:      return Icons.category_outlined;
      case Permission.viewDonors:            return Icons.people_outline;
      case Permission.manageDonors:          return Icons.manage_accounts_outlined;
      case Permission.deleteDonors:          return Icons.person_remove_outlined;
      case Permission.viewTransactions:      return Icons.receipt_long_outlined;
      case Permission.manageDonations:       return Icons.volunteer_activism_outlined;
      case Permission.exportData:            return Icons.download_outlined;
      case Permission.manageDonorTypes:      return Icons.badge_outlined;
      case Permission.managePaymentMethods:  return Icons.payment_outlined;
      case Permission.manageStaff:           return Icons.admin_panel_settings_outlined;
      case Permission.manageRoles:           return Icons.security_outlined;
      case Permission.grantAdmin:            return Icons.verified_user_outlined;
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
  final String       id;
  final String       name;
  final String       description;
  final List<String> permissions;
  final bool         isDefault;
  final int          staffCount;
  final DateTime?    createdAt;

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
  }) => RoleModel(
    id:          id,
    name:        name        ?? this.name,
    description: description ?? this.description,
    permissions: permissions ?? this.permissions,
    isDefault:   isDefault,
    staffCount:  staffCount  ?? this.staffCount,
    createdAt:   createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id':          id,
    'name':        name,
    'description': description,
    'permissions': permissions,
    'is_default':  isDefault,
    'created_at':  createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
  };

  factory RoleModel.fromJson(Map<String, dynamic> json) => RoleModel(
    id:          json['id']          as String? ?? '',
    name:        json['name']        as String? ?? '',
    description: json['description'] as String? ?? '',
    permissions: List<String>.from(json['permissions'] as List? ?? []),
    isDefault:   json['is_default']  as bool?   ?? false,
    staffCount:  json['staff_count'] as int?    ?? 0,
    createdAt:   json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String) : null,
  );

  // ── Default KCA managerial roles ──────────────────────────────────────────
  static final _allKeys = Permission.values.map((p) => p.key).toList();

  static List<RoleModel> get defaults => [
    // ── Super admin — everything ───────────────────────────────────────────
    RoleModel(
      id:          'executive_director',
      name:        'Executive Director',
      description: 'Full access to all modules including payment methods, '
          'donor types, categories and admin management.',
      isDefault:   true,
      permissions: _allKeys,
    ),

    // ── Resource Mobilization Manager ─────────────────────────────────────
    RoleModel(
      id:          'resource_mobilization_manager',
      name:        'Manager of Resource Mobilization',
      description: 'Manages fundraising campaigns, categories and donor relations.',
      isDefault:   true,
      permissions: [
        Permission.viewDashboard.key,
        Permission.viewCampaigns.key,
        Permission.manageCampaigns.key,
        Permission.manageCategories.key,
        Permission.viewDonors.key,
        Permission.manageDonors.key,
        Permission.viewTransactions.key,
        Permission.manageDonations.key,
        Permission.exportData.key,
      ],
    ),

    // ── Asst. Director Development ─────────────────────────────────────────
    RoleModel(
      id:          'asst_director_development',
      name:        'Asst. Director — Development & Investment',
      description: 'Oversees development projects and investment tracking.',
      isDefault:   true,
      permissions: [
        Permission.viewDashboard.key,
        Permission.viewCampaigns.key,
        Permission.manageCampaigns.key,
        Permission.manageCategories.key,
        Permission.viewDonors.key,
        Permission.viewTransactions.key,
        Permission.exportData.key,
      ],
    ),

    // ── Administrator ─────────────────────────────────────────────────────
    RoleModel(
      id:          'administrator',
      name:        'Administrator',
      description: 'System admin — staff, roles, donor types, payment methods.',
      isDefault:   true,
      permissions: [
        Permission.viewDashboard.key,
        Permission.viewCampaigns.key,
        Permission.manageCampaigns.key,
        Permission.manageCategories.key,
        Permission.viewDonors.key,
        Permission.manageDonors.key,
        Permission.deleteDonors.key,
        Permission.viewTransactions.key,
        Permission.manageDonations.key,
        Permission.exportData.key,
        Permission.manageDonorTypes.key,
        Permission.managePaymentMethods.key,
        Permission.manageStaff.key,
        Permission.manageRoles.key,
      ],
    ),

    // ── Deputy Director Donor Engagement ──────────────────────────────────
    RoleModel(
      id:          'deputy_director_donor',
      name:        'Deputy Director — Donor Engagement & Comms',
      description: 'Leads donor communications, engagement and management.',
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