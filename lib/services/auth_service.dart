import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:multilingual_chat_app/models/user.dart';

class AuthService {
  // Use emulator loopback for Android emulators; keep localhost elsewhere
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    } catch (_) {}
    return 'http://localhost:3000/api';
  }

  static const String tokenKey = 'auth_token';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
  }

  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      if (kDebugMode) debugPrint('[AuthService] POST $baseUrl/auth/login for $email');
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['token']);
        if (kDebugMode) debugPrint('[AuthService] login success (200), token saved');
        return data;
      } else {
        if (kDebugMode) {
          debugPrint('[AuthService] login failed (${response.statusCode}): ${response.body}');
        }
        throw Exception('Login failed: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] login exception: $e');
      throw Exception('Login error: $e');
    }
  }

  Future<Map<String, dynamic>> register(String name, String email,
      String password, String preferredLanguage) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'preferredLanguage': preferredLanguage,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await saveToken(data['token']);
        return data;
      } else {
        throw Exception('Registration failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Registration error: $e');
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      final token = await getToken();
      if (token == null) {
        if (kDebugMode) debugPrint('[AuthService] /auth/me skipped: no token');
        return null;
      }

      if (kDebugMode) debugPrint('[AuthService] GET $baseUrl/auth/me');
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (kDebugMode) debugPrint('[AuthService] /auth/me success (200)');
        return User.fromJson(data['user']);
      } else {
        if (kDebugMode) {
          debugPrint('[AuthService] /auth/me failed (${response.statusCode}), token cleared');
        }
        await removeToken();
        return null;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] /auth/me exception, token cleared: $e');
      await removeToken();
      return null;
    }
  }

  Future<void> logout() async {
    await removeToken();
  }

  Future<User> updateProfile({
    String? name,
    String? preferredLanguage,
    String? profileImageUrl,
  }) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (name != null) 'name': name,
          if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
          if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return User.fromJson(data['user']);
      } else {
        throw Exception('Profile update failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Profile update error: $e');
    }
  }
}

