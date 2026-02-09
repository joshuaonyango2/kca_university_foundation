// lib/providers/auth_provider.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final SharedPreferences prefs;

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider({required this.prefs});

  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  /// Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 1));

      // Simulated login - Check if admin
      if (email.contains('admin')) {
        _user = UserModel(
          id: '1',
          email: email,
          name: 'Admin User',
          role: UserRole.admin,
          isEmailVerified: true,
          isPhoneVerified: false,
          createdAt: DateTime.now(),
        );
      } else {
        _user = UserModel(
          id: '2',
          email: email,
          name: 'Regular User',
          role: UserRole.donor,
          isEmailVerified: true,
          isPhoneVerified: false,
          createdAt: DateTime.now(),
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    _user = null;
    _errorMessage = null;
    notifyListeners();
  }
}