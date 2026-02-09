// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'storage_service.dart';

class ApiService {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _getHeaders({bool requiresAuth = false}) async {
    final headers = Map<String, String>.from(ApiConfig.headers);

    if (requiresAuth) {
      final token = await _storage.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<dynamic> get(String endpoint, {bool requiresAuth = false}) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await http
          .get(Uri.parse(endpoint), headers: headers)
          .timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> post(
      String endpoint,
      Map<String, dynamic> body, {
        bool requiresAuth = false,
      }) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await http
          .post(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode(body),
      )
          .timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> put(
      String endpoint,
      Map<String, dynamic> body, {
        bool requiresAuth = false,
      }) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await http
          .put(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode(body),
      )
          .timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // ✅ ADDED: Missing delete method
  Future<dynamic> delete(String endpoint, {bool requiresAuth = false}) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await http
          .delete(Uri.parse(endpoint), headers: headers)
          .timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  dynamic _handleResponse(http.Response response) {
    final body = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: body['message'] ?? 'An error occurred',
      );
    }
  }

  String _handleError(dynamic error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'Network error. Please check your connection.';
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}