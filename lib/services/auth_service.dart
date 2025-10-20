import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_config.dart';

class AuthService {
  static String get baseUrl => AppConfig.backendBaseUrl;

  // Check if email exists
  static Future<Map<String, dynamic>> checkEmail(String email) async {
    try {
      final url = '$baseUrl/api/auth/check-email';
      debugPrint('🔍 [AuthService] Calling: $url');
      debugPrint('🔍 [AuthService] Email: $email');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      debugPrint('📡 [AuthService] Response status: ${response.statusCode}');
      debugPrint('📡 [AuthService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'error': json.decode(response.body)['error'] ?? 'Unknown error',
        };
      }
    } catch (e) {
      debugPrint('❌ [AuthService] Error: $e');
      return {'error': 'Network error: $e'};
    }
  }

  // Request OTP for existing user
  static Future<Map<String, dynamic>> requestOTP(String email) async {
    try {
      final url = '$baseUrl/api/auth/request-otp';
      debugPrint('🔍 [AuthService] Calling: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      debugPrint('📡 [AuthService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'error': json.decode(response.body)['error'] ?? 'Unknown error',
        };
      }
    } catch (e) {
      debugPrint('❌ [AuthService] Error: $e');
      return {'error': 'Network error: $e'};
    }
  }

  // Login with OTP
  static Future<Map<String, dynamic>> login(String email, String otp) async {
    try {
      final url = '$baseUrl/api/auth/login';
      debugPrint('🔍 [AuthService] Calling: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'otp': otp}),
      );

      debugPrint('📡 [AuthService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          await saveUserEmail(email);
        }
        return data;
      } else {
        return {
          'error': json.decode(response.body)['error'] ?? 'Unknown error',
        };
      }
    } catch (e) {
      debugPrint('❌ [AuthService] Error: $e');
      return {'error': 'Network error: $e'};
    }
  }

  // Register new user with OTP only
  static Future<Map<String, dynamic>> register(String email, String otp) async {
    try {
      final url = '$baseUrl/api/auth/register';
      debugPrint('🔍 [AuthService] Calling: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'otp': otp}),
      );

      debugPrint('📡 [AuthService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          await saveUserEmail(email);
        }
        return data;
      } else {
        return {
          'error': json.decode(response.body)['error'] ?? 'Unknown error',
        };
      }
    } catch (e) {
      debugPrint('❌ [AuthService] Error: $e');
      return {'error': 'Network error: $e'};
    }
  }

  // Save user email to SharedPreferences
  static Future<void> saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
    await prefs.setBool('is_logged_in', true);
  }

  // Get saved user email
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email');
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  // Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await prefs.setBool('is_logged_in', false);
  }
}
