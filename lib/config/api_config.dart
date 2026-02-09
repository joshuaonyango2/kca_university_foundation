// lib/config/api_config.dart

class ApiConfig {
  // IMPORTANT: Change this based on where you're running
  // For Android Emulator: use 10.0.2.2
  // For Physical Device: use your computer's IP address (e.g., 192.168.1.100)
  // For iOS Simulator: use localhost or 127.0.0.1

  // static const String baseUrl = 'http://10.0.2.2:5000'; // Android Emulator
  static const String baseUrl = 'http://localhost:5000'; // iOS Simulator and Chrome
// static const String baseUrl = 'http://192.168.1.100:5000'; // Physical Device
  // API Endpoints
  static const String authEndpoint = '$baseUrl/api/auth';
  static const String campaignsEndpoint = '$baseUrl/api/campaigns';
  static const String donationsEndpoint = '$baseUrl/api/donations';
  static const String paymentsEndpoint = '$baseUrl/api/payments';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Map<String, String> authHeaders(String token) => {
    ...headers,
    'Authorization': 'Bearer $token',
  };
}