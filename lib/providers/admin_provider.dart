// lib/providers/admin_provider.dart

import 'package:flutter/foundation.dart';
import '../models/admin_user.dart';
import '../services/api_service.dart';

class AdminProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<AdminUser> _admins = [];
  bool _isLoading = false;
  String? _errorMessage;
  AdminUser? _currentAdmin;

  List<AdminUser> get admins => _admins;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AdminUser? get currentAdmin => _currentAdmin;

  // Fetch all admins
  Future<void> fetchAdmins() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/admin/users');
      _admins = (response['data'] as List)
          .map((json) => AdminUser.fromJson(json))
          .toList();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add new admin
  Future<bool> addAdmin({
    required String email,
    required String firstName,
    required String lastName,
    required AdminRole role,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post('/admin/users', {
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'role': role.toString().split('.').last,
        'password': password,
        'permissions': role.defaultPermissions,
      });

      final newAdmin = AdminUser.fromJson(response['data']);
      _admins.add(newAdmin);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update admin
  Future<bool> updateAdmin({
    required String adminId,
    String? email,
    String? firstName,
    String? lastName,
    AdminRole? role,
    bool? isActive,
    Map<String, bool>? permissions,
  }) async {
    try {
      final response = await _apiService.put('/admin/users/$adminId', {
        if (email != null) 'email': email,
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (role != null) 'role': role.toString().split('.').last,
        if (isActive != null) 'isActive': isActive,
        if (permissions != null) 'permissions': permissions,
      });

      final updatedAdmin = AdminUser.fromJson(response['data']);
      final index = _admins.indexWhere((a) => a.id == adminId);
      if (index != -1) {
        _admins[index] = updatedAdmin;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Delete admin
  Future<bool> deleteAdmin(String adminId) async {
    try {
      await _apiService.delete('/admin/users/$adminId');
      _admins.removeWhere((a) => a.id == adminId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Reset password
  Future<bool> resetAdminPassword({
    required String adminId,
    required String newPassword,
  }) async {
    try {
      await _apiService.post('/admin/users/$adminId/reset-password', {
        'newPassword': newPassword,
      });
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ✅ FIXED: Check permission - Proper null handling for boolean
  bool hasPermission(String permission) {
    if (_currentAdmin == null) return false;
    if (_currentAdmin!.role == AdminRole.superAdmin) return true;
    // ✅ FIX: Use containsKey to check if permission exists, then get value or default to false
    return _currentAdmin!.permissions.containsKey(permission)
        ? _currentAdmin!.permissions[permission]!
        : false;
  }
}