// lib/services/auth_service.dart

import '../config/api_config.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  Future<Map<String, dynamic>> register({
    required String email,
    required String phoneNumber,
    required String password,
    required String firstName,
    required String lastName,
    String? organization,
    bool isCorporate = false,
  }) async {
    final response = await _api.post(
      '${ApiConfig.authEndpoint}/register',
      {
        'email': email,
        'phone_number': phoneNumber,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'organization': organization,
        'is_corporate': isCorporate,
      },
    );

    if (response['success']) {
      final user = User.fromJson(response['data']['user']);
      final token = response['data']['token'];

      await _storage.saveToken(token);
      await _storage.saveUser(user);

      return {'success': true, 'user': user};
    }

    return {'success': false, 'message': response['message']};
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      '${ApiConfig.authEndpoint}/login',
      {
        'email': email,
        'password': password,
      },
    );

    if (response['success']) {
      final user = User.fromJson(response['data']['user']);
      final token = response['data']['token'];

      await _storage.saveToken(token);
      await _storage.saveUser(user);

      return {'success': true, 'user': user};
    }

    return {'success': false, 'message': response['message']};
  }

  Future<User?> getCurrentUser() async {
    return await _storage.getUser();
  }

  Future<void> logout() async {
    await _storage.clearAll();
  }

  Future<bool> isAuthenticated() async {
    final token = await _storage.getToken();
    return token != null;
  }
}