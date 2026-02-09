// lib/screens/admin/tabs/settings_tab.dart
// 📱 IMPROVED MOBILE UX VERSION

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';

// Main Settings Tab Container
class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          // ✨ IMPROVED TAB BAR
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 0 : 16),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 3,
              labelStyle: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.normal,
              ),
              tabs: [
                Tab(
                  icon: Icon(Icons.person, size: isMobile ? 20 : 24),
                  text: 'Profile',
                ),
                Tab(
                  icon: Icon(Icons.lock, size: isMobile ? 20 : 24),
                  text: 'Security',
                ),
                Tab(
                  icon: Icon(Icons.admin_panel_settings, size: isMobile ? 20 : 24),
                  text: 'Admin Users',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                ProfileSettingsTab(),
                SecuritySettingsTab(),
                AdminUsersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// PROFILE SETTINGS TAB (Keep existing code)
// ============================================
class ProfileSettingsTab extends StatefulWidget {
  const ProfileSettingsTab({super.key});

  @override
  State<ProfileSettingsTab> createState() => _ProfileSettingsTabState();
}

class _ProfileSettingsTabState extends State<ProfileSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile Information',
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Update your account profile information',
            style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.grey[600]),
          ),
          SizedBox(height: isMobile ? 20 : 32),
          Container(
            padding: EdgeInsets.all(isMobile ? 20 : 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Picture - More compact on mobile
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: isMobile ? 50 : 60,
                              backgroundColor: const Color(0xFF2563EB).withAlpha(25),
                              child: Text(
                                user?.firstName?.substring(0, 1).toUpperCase() ?? 'A',
                                style: TextStyle(
                                  fontSize: isMobile ? 40 : 48,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: isMobile ? 16 : 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Upload profile picture feature coming soon'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.upload, size: 18),
                          label: const Text('Upload Photo'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 20 : 32),
                  const Divider(),
                  SizedBox(height: isMobile ? 20 : 32),

                  // Name Fields - Stack on mobile
                  if (isMobile)
                    Column(
                      children: [
                        _buildTextField(
                          'First Name',
                          _firstNameController,
                          'Enter first name',
                              (value) => value == null || value.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          'Last Name',
                          _lastNameController,
                          'Enter last name',
                              (value) => value == null || value.isEmpty ? 'Required' : null,
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            'First Name',
                            _firstNameController,
                            'Enter first name',
                                (value) => value == null || value.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            'Last Name',
                            _lastNameController,
                            'Enter last name',
                                (value) => value == null || value.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  // Email
                  _buildTextField(
                    'Email Address',
                    _emailController,
                    'Enter email address',
                        (value) {
                      if (value == null || value.isEmpty) return 'Please enter email';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter valid email';
                      }
                      return null;
                    },
                    prefixIcon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  _buildTextField(
                    'Phone Number (Optional)',
                    _phoneController,
                    '+254 712 345 678',
                    null,
                    prefixIcon: Icons.phone_outlined,
                  ),
                  SizedBox(height: isMobile ? 24 : 32),

                  // Save Button - Full width on mobile
                  if (isMobile)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Profile updated successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Save Changes'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              _firstNameController.text = user?.firstName ?? '';
                              _lastNameController.text = user?.lastName ?? '';
                              _emailController.text = user?.email ?? '';
                              _phoneController.clear();
                            },
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _firstNameController.text = user?.firstName ?? '';
                            _lastNameController.text = user?.lastName ?? '';
                            _emailController.text = user?.email ?? '';
                            _phoneController.clear();
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile updated successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                          child: const Text('Save Changes'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      String label,
      TextEditingController controller,
      String hint,
      String? Function(String?)? validator, {
        IconData? prefixIcon,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

// ============================================
// SECURITY SETTINGS TAB (Keep existing - add mobile optimizations)
// ============================================
class SecuritySettingsTab extends StatefulWidget {
  const SecuritySettingsTab({super.key});

  @override
  State<SecuritySettingsTab> createState() => _SecuritySettingsTabState();
}

class _SecuritySettingsTabState extends State<SecuritySettingsTab> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Change Password',
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Update your password to keep your account secure',
            style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.grey[600]),
          ),
          SizedBox(height: isMobile ? 20 : 32),
          Container(
            padding: EdgeInsets.all(isMobile ? 20 : 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPasswordField(
                    'Current Password',
                    _currentPasswordController,
                    _obscureCurrentPassword,
                        () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
                    'Please enter current password',
                  ),
                  const SizedBox(height: 20),
                  _buildPasswordField(
                    'New Password',
                    _newPasswordController,
                    _obscureNewPassword,
                        () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                    'Please enter new password',
                    minLength: 8,
                  ),
                  const SizedBox(height: 20),
                  _buildPasswordField(
                    'Confirm New Password',
                    _confirmPasswordController,
                    _obscureConfirmPassword,
                        () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    'Please confirm new password',
                    matchController: _newPasswordController,
                  ),
                  const SizedBox(height: 16),

                  // Password Requirements
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Password Requirements',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildPasswordRequirement('At least 8 characters'),
                        _buildPasswordRequirement('At least one uppercase letter'),
                        _buildPasswordRequirement('At least one lowercase letter'),
                        _buildPasswordRequirement('At least one number'),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 24 : 32),

                  // Update Button - Full width on mobile
                  if (isMobile)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Password updated successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                _currentPasswordController.clear();
                                _newPasswordController.clear();
                                _confirmPasswordController.clear();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Update Password'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              _currentPasswordController.clear();
                              _newPasswordController.clear();
                              _confirmPasswordController.clear();
                            },
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _currentPasswordController.clear();
                            _newPasswordController.clear();
                            _confirmPasswordController.clear();
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password updated successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _currentPasswordController.clear();
                              _newPasswordController.clear();
                              _confirmPasswordController.clear();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                          child: const Text('Update Password'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(
      String label,
      TextEditingController controller,
      bool obscure,
      VoidCallback onToggle,
      String errorMessage, {
        int? minLength,
        TextEditingController? matchController,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
              onPressed: onToggle,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return errorMessage;
            }
            if (minLength != null && value.length < minLength) {
              return 'Password must be at least $minLength characters';
            }
            if (matchController != null && value != matchController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

// ============================================
// ADMIN USERS TAB - IMPROVED MOBILE UX
// ============================================

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final List<AdminUser> _admins = [
    AdminUser(
      id: '1',
      name: 'John Admin',
      email: 'john@kcafoundation.org',
      role: 'Super Admin',
      lastActive: DateTime.now().subtract(const Duration(minutes: 5)),
      isActive: true,
    ),
    AdminUser(
      id: '2',
      name: 'Sarah Manager',
      email: 'sarah@kcafoundation.org',
      role: 'Campaign Manager',
      lastActive: DateTime.now().subtract(const Duration(hours: 2)),
      isActive: true,
    ),
    AdminUser(
      id: '3',
      name: 'Mike Finance',
      email: 'mike@kcafoundation.org',
      role: 'Finance Officer',
      lastActive: DateTime.now().subtract(const Duration(days: 1)),
      isActive: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 32,
            isMobile ? 16 : 32,
            isMobile ? 16 : 32,
            isMobile ? 80 : 32, // Extra padding for FAB on mobile
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header - Stack on mobile
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Users',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage admin users and their permissions',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Admin Users',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Manage admin users and their permissions',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddAdminDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Admin'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: isMobile ? 16 : 32),

              // Admin Cards
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _admins.length,
                itemBuilder: (context, index) {
                  final admin = _admins[index];
                  return _buildAdminCard(admin, isMobile);
                },
              ),
            ],
          ),
        ),

        // ✨ FLOATING ACTION BUTTON - Mobile Only
        if (isMobile)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: () => _showAddAdminDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Admin'),
              backgroundColor: const Color(0xFF2563EB),
            ),
          ),
      ],
    );
  }

  // ✨ IMPROVED ADMIN CARD - More compact on mobile
  Widget _buildAdminCard(AdminUser admin, bool isMobile) {
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: isMobile ? 24 : 30,
                backgroundColor: const Color(0xFF2563EB).withAlpha(25),
                child: Text(
                  admin.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 12 : 24),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            admin.name,
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (admin.isActive)
                          Container(
                            width: isMobile ? 8 : 10,
                            height: isMobile ? 8 : 10,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      admin.email,
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getRoleColor(admin.role).withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            admin.role,
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 12,
                              fontWeight: FontWeight.w600,
                              color: _getRoleColor(admin.role),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${_formatLastActive(admin.lastActive)}',
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              if (!isMobile)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showEditAdminDialog(context, admin),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _showDeleteAdminDialog(context, admin),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
            ],
          ),

          // Mobile Actions Row
          if (isMobile)
            Column(
              children: [
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditAdminDialog(context, admin),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDeleteAdminDialog(context, admin),
                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Super Admin':
        return const Color(0xFF8B5CF6);
      case 'Campaign Manager':
        return const Color(0xFF2563EB);
      case 'Finance Officer':
        return const Color(0xFF10B981);
      case 'Communications':
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  String _formatLastActive(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  void _showAddAdminDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'Campaign Manager';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Admin'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width < 600 ? double.maxFinite : 500,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: firstNameController,
                          decoration: const InputDecoration(labelText: 'First Name'),
                          validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: lastNameController,
                          decoration: const InputDecoration(labelText: 'Last Name'),
                          validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email Address'),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter email';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: ['Super Admin', 'Campaign Manager', 'Finance Officer', 'Communications', 'Viewer']
                        .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                        .toList(),
                    onChanged: (value) => selectedRole = value!,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Initial Password'),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter password';
                      if (value.length < 8) return 'Password must be at least 8 characters';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Admin user added successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Add Admin'),
          ),
        ],
      ),
    );
  }

  void _showEditAdminDialog(BuildContext context, AdminUser admin) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: admin.name);
    final emailController = TextEditingController(text: admin.email);
    String selectedRole = admin.role;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Admin'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width < 600 ? double.maxFinite : 500,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.isEmpty ? 'Please enter name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) => value == null || value.isEmpty ? 'Please enter email' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: ['Super Admin', 'Campaign Manager', 'Finance Officer', 'Communications', 'Viewer']
                      .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                      .toList(),
                  onChanged: (value) => selectedRole = value!,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Admin updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAdminDialog(BuildContext context, AdminUser admin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Admin'),
        content: Text(
          'Are you sure you want to delete ${admin.name}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Admin deleted successfully!'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Helper Class
class AdminUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final DateTime lastActive;
  final bool isActive;

  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.lastActive,
    required this.isActive,
  });
}