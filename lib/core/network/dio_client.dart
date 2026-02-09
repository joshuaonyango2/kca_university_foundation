// lib/core/network/dio_client.dart

import 'package:dio/dio.dart';

class DioClient {
  static Dio? _instance;

  static Dio get instance {
    if (_instance == null) {
      _instance = Dio(BaseOptions(
        // For Android Emulator (use 10.0.2.2 to access localhost)
        baseUrl: 'http://10.0.2.2:5000/api',

        // For iOS Simulator (use localhost)
        // baseUrl: 'http://localhost:5000/api',

        // For Real Device (use your computer's IP address)
        // baseUrl: 'http://192.168.1.X:5000/api',

        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));

      // Add interceptors for logging and token handling
      _instance!.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ));

      // Add auth token interceptor
      _instance!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            // Add auth token to headers if available
            // final prefs = await SharedPreferences.getInstance();
            // final token = prefs.getString('access_token');
            // if (token != null) {
            //   options.headers['Authorization'] = 'Bearer $token';
            // }
            return handler.next(options);
          },
          onError: (error, handler) async {
            // Handle 401 unauthorized errors
            if (error.response?.statusCode == 401) {
              // TODO: Implement token refresh logic
            }
            return handler.next(error);
          },
        ),
      );
    }

    return _instance!;
  }

  // Reset instance (useful for testing or logout)
  static void reset() {
    _instance = null;
  }
}