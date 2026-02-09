import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme { // Light mode (default)
    return ThemeData(
      primaryColor: const Color(0xFF1E40AF), // KCA blue from splash
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E40AF),
        foregroundColor: Colors.white,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
      ),
      colorScheme: ColorScheme.fromSwatch().copyWith(secondary: Colors.blueAccent),
      useMaterial3: true, // Modern Material Design
    );
  }

  static ThemeData get darkTheme { // Optional dark mode
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF1E40AF),
      scaffoldBackgroundColor: Colors.grey[900],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
      ),
      colorScheme: ColorScheme.fromSwatch(brightness: Brightness.dark).copyWith(secondary: Colors.blueAccent),
      useMaterial3: true,
    );
  }
}