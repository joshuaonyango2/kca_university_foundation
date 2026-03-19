// lib/core/network/dio_client.dart
//
// ✅ FIX: dio was removed by flutter pub upgrade --major-versions.
//    Replaced with http package which is already in pubspec.yaml
//    and used throughout the project (notification_service, mpesa_service).
//
// API is kept identical so auth_repository.dart needs minimal changes:
//   - DioClient.get()   → returns Map<String, dynamic>
//   - DioClient.post()  → returns Map<String, dynamic>
//   - DioClient.put()   → returns Map<String, dynamic>
//   - DioClient.delete()→ returns Map<String, dynamic>
//   Throws HttpException on non-2xx responses.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DioClient {
  DioClient._();

  static const _baseUrl        = 'https://us-central1-kca-university-foundation.cloudfunctions.net';
  static const _timeoutSeconds = 30;

  static final Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept':       'application/json',
  };

  // ── Auth token (set after login) ──────────────────────────────────────────
  static String? _authToken;

  static void setAuthToken(String? token) {
    _authToken = token;
    debugPrint('[DioClient] Auth token ${token != null ? "set" : "cleared"}');
  }

  static Map<String, String> get _headers {
    final h = Map<String, String>.from(_defaultHeaders);
    if (_authToken != null) h['Authorization'] = 'Bearer $_authToken';
    return h;
  }

  // ── GET ───────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> get(
      String path, {
        Map<String, String>? queryParams,
      }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path')
          .replace(queryParameters: queryParams);
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: _timeoutSeconds));
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // ── POST ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> post(
      String path, {
        Map<String, dynamic>? data,
      }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final response = await http
          .post(uri, headers: _headers, body: jsonEncode(data ?? {}))
          .timeout(const Duration(seconds: _timeoutSeconds));
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // ── PUT ───────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> put(
      String path, {
        Map<String, dynamic>? data,
      }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final response = await http
          .put(uri, headers: _headers, body: jsonEncode(data ?? {}))
          .timeout(const Duration(seconds: _timeoutSeconds));
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> delete(String path) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final response = await http
          .delete(uri, headers: _headers)
          .timeout(const Duration(seconds: _timeoutSeconds));
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // ── Response handler ──────────────────────────────────────────────────────
  static Map<String, dynamic> _handleResponse(http.Response response) {
    debugPrint('[DioClient] ${response.request?.method} '
        '${response.request?.url} → ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        return {'data': decoded};
      } catch (_) {
        return {'body': response.body};
      }
    }

    throw HttpException(
      statusCode: response.statusCode,
      message:    _extractMessage(response.body),
    );
  }

  static Exception _handleError(dynamic e) {
    if (e is HttpException) return e;
    debugPrint('[DioClient] Network error: $e');
    return HttpException(
      statusCode: 0,
      message:    'Network error: ${e.toString()}',
    );
  }

  static String _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded['message'] as String? ??
          decoded['error']   as String? ??
          body;
    } catch (_) {
      return body.isNotEmpty ? body : 'Request failed';
    }
  }
}

// ── HttpException ─────────────────────────────────────────────────────────────
// Drop-in replacement for DioException — keeps auth_repository.dart working
// with minimal changes.
class HttpException implements Exception {
  final int    statusCode;
  final String message;

  const HttpException({required this.statusCode, required this.message});

  bool get isUnauthorized  => statusCode == 401;
  bool get isForbidden     => statusCode == 403;
  bool get isNotFound      => statusCode == 404;
  bool get isServerError   => statusCode >= 500;
  bool get isNetworkError  => statusCode == 0;

  @override
  String toString() => 'HttpException($statusCode): $message';
}