// lib/repositories/auth_repository.dart

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../core/network/dio_client.dart';
import '../core/constants/storage_keys.dart';

class AuthRepository {
  final Dio _dio;
  final SharedPreferences _prefs;

  AuthRepository({
    Dio? dio,
    SharedPreferences? prefs,
  })  : _dio = dio ?? DioClient.instance,
        _prefs = prefs ?? (throw Exception('SharedPreferences required'));

  /// Login with email and password
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      final loginResponse = LoginResponse.fromJson(response.data);

      // Save tokens and user data
      await _saveAuthData(loginResponse);

      return AuthResult.success(user: loginResponse.user);
    } on DioException catch (e) {
      return AuthResult.failure(
        error: _extractErrorMessage(e),
      );
    } catch (e) {
      return AuthResult.failure(
        error: 'An unexpected error occurred',
      );
    }
  }

  /// Register new user
  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'name': name,
          'phone_number': phoneNumber,
        },
      );

      final loginResponse = LoginResponse.fromJson(response.data);

      // Save tokens and user data
      await _saveAuthData(loginResponse);

      return AuthResult.success(user: loginResponse.user);
    } on DioException catch (e) {
      return AuthResult.failure(
        error: _extractErrorMessage(e),
      );
    } catch (e) {
      return AuthResult.failure(
        error: 'An unexpected error occurred',
      );
    }
  }

  /// Verify phone number with OTP
  Future<AuthResult> verifyPhone({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/verify-phone',
        data: {
          'phone_number': phoneNumber,
          'otp': otp,
        },
      );

      return AuthResult.success(
        message: response.data['message'] ?? 'Phone verified successfully',
      );
    } on DioException catch (e) {
      return AuthResult.failure(
        error: _extractErrorMessage(e),
      );
    }
  }

  /// Request OTP for phone verification
  Future<AuthResult> requestPhoneOtp(String phoneNumber) async {
    try {
      await _dio.post(
        '/auth/request-otp',
        data: {'phone_number': phoneNumber},
      );

      return AuthResult.success(
        message: 'OTP sent to $phoneNumber',
      );
    } on DioException catch (e) {
      return AuthResult.failure(
        error: _extractErrorMessage(e),
      );
    }
  }

  /// Forgot password
  Future<AuthResult> forgotPassword(String email) async {
    try {
      await _dio.post(
        '/auth/forgot-password',
        data: {'email': email},
      );

      return AuthResult.success(
        message: 'Password reset link sent to $email',
      );
    } on DioException catch (e) {
      return AuthResult.failure(
        error: _extractErrorMessage(e),
      );
    }
  }

  /// Get current user
  Future<UserModel?> getCurrentUser() async {
    try {
      final response = await _dio.get('/auth/me');
      return UserModel.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (e) {
      // Continue with local logout even if API fails
    } finally {
      await _clearAuthData();
    }
  }

  /// Refresh access token
  Future<bool> refreshToken() async {
    try {
      final refreshToken = _prefs.getString(StorageKeys.refreshToken);
      if (refreshToken == null) return false;

      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final accessToken = response.data['access_token'];
      final newRefreshToken = response.data['refresh_token'];

      await _prefs.setString(StorageKeys.accessToken, accessToken);
      if (newRefreshToken != null) {
        await _prefs.setString(StorageKeys.refreshToken, newRefreshToken);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = _prefs.getString(StorageKeys.accessToken);
    return token != null && token.isNotEmpty;
  }

  // Private helper methods

  Future<void> _saveAuthData(LoginResponse response) async {
    await _prefs.setString(StorageKeys.accessToken, response.accessToken);
    await _prefs.setString(StorageKeys.refreshToken, response.refreshToken);
    await _prefs.setString(StorageKeys.userId, response.user.id);
    await _prefs.setString(StorageKeys.authToken, response.accessToken);
  }

  Future<void> _clearAuthData() async {
    await _prefs.remove(StorageKeys.accessToken);
    await _prefs.remove(StorageKeys.refreshToken);
    await _prefs.remove(StorageKeys.userId);
    await _prefs.remove(StorageKeys.user);
    await _prefs.remove(StorageKeys.authToken);
  }

  String _extractErrorMessage(DioException e) {
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map) {
        return data['message'] ?? data['error'] ?? 'An error occurred';
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please try again.';
      default:
        return 'Network error. Please try again.';
    }
  }
}

// ============================================
// AUTH MODELS
// ============================================

/// Login Response Model
class LoginResponse {
  final UserModel user;
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  LoginResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int? ?? 3600,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_in': expiresIn,
    };
  }
}

/// Authentication result wrapper
class AuthResult {
  final bool isSuccess;
  final UserModel? user;
  final String? message;
  final String? error;

  AuthResult._({
    required this.isSuccess,
    this.user,
    this.message,
    this.error,
  });

  factory AuthResult.success({
    UserModel? user,
    String? message,
  }) {
    return AuthResult._(
      isSuccess: true,
      user: user,
      message: message,
    );
  }

  factory AuthResult.failure({
    required String error,
  }) {
    return AuthResult._(
      isSuccess: false,
      error: error,
    );
  }
}