import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:multilingual_chat_app/models/user.dart';

class AuthService {
  static const String baseUrl = 'http://localhost:3000/api';

  // Local mode for now. You can swap these methods to Supabase later.
  static const String tokenKey = 'auth_token';
  static const String _usersKey = 'local_users_v1';
  static const String _currentUserIdKey = 'local_current_user_id_v1';

  Future<List<Map<String, dynamic>>> _readUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usersKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  Future<void> _writeUsers(List<Map<String, dynamic>> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersKey, jsonEncode(users));
  }

  Future<void> _saveCurrentUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserIdKey, userId);
  }

  Future<String?> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserIdKey);
  }

  Future<void> _clearCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserIdKey);
  }

  String _newUserId() => DateTime.now().microsecondsSinceEpoch.toString();

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
    final normalizedEmail = email.trim().toLowerCase();
    final users = await _readUsers();

    final match = users.firstWhere(
      (u) =>
          (u['email']?.toString().toLowerCase() ?? '') == normalizedEmail &&
          (u['password']?.toString() ?? '') == password,
      orElse: () => <String, dynamic>{},
    );

    if (match.isEmpty) {
      throw Exception('Invalid email or password');
    }

    final userId = match['id']?.toString();
    if (userId == null || userId.isEmpty) {
      throw Exception('Corrupted local user data');
    }

    final token = 'local-token-$userId';
    await saveToken(token);
    await _saveCurrentUserId(userId);

    if (kDebugMode) {
      debugPrint('[AuthService] local login success for $normalizedEmail');
    }

    return {
      'token': token,
      'user': Map<String, dynamic>.from(match)..remove('password'),
    };
  }

  Future<Map<String, dynamic>> register(String name, String email,
      String password, String preferredLanguage) async {
    final trimmedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final users = await _readUsers();

    final exists = users.any(
      (u) => (u['email']?.toString().toLowerCase() ?? '') == normalizedEmail,
    );
    if (exists) {
      throw Exception('Email already registered');
    }

    final newUser = User(
      id: _newUserId(),
      email: normalizedEmail,
      name: trimmedName,
      preferredLanguage: preferredLanguage,
      isOnline: true,
      createdAt: DateTime.now(),
    );

    final record = <String, dynamic>{
      ...newUser.toJson(),
      'password': password,
    };
    users.add(record);
    await _writeUsers(users);

    final token = 'local-token-${newUser.id}';
    await saveToken(token);
    await _saveCurrentUserId(newUser.id);

    if (kDebugMode) {
      debugPrint('[AuthService] local register success for $normalizedEmail');
    }

    return {
      'token': token,
      'user': newUser.toJson(),
    };
  }

  Future<User?> getCurrentUser() async {
    final token = await getToken();
    if (token == null) return null;

    final currentUserId = await _getCurrentUserId();
    if (currentUserId == null) {
      await removeToken();
      return null;
    }

    final users = await _readUsers();
    final match = users.firstWhere(
      (u) => (u['id']?.toString() ?? '') == currentUserId,
      orElse: () => <String, dynamic>{},
    );

    if (match.isEmpty) {
      await removeToken();
      await _clearCurrentUserId();
      return null;
    }

    final userJson = Map<String, dynamic>.from(match)..remove('password');
    return User.fromJson(userJson);
  }

  Future<void> logout() async {
    await removeToken();
    await _clearCurrentUserId();
  }

  Future<User> updateProfile({
    String? name,
    String? preferredLanguage,
    String? profileImageUrl,
  }) async {
    final currentUser = await getCurrentUser();
    if (currentUser == null) throw Exception('Not authenticated');

    final users = await _readUsers();
    final idx = users.indexWhere(
      (u) => (u['id']?.toString() ?? '') == currentUser.id,
    );

    if (idx < 0) throw Exception('Current user not found');

    final updated = currentUser.copyWith(
      name: name,
      preferredLanguage: preferredLanguage,
      profileImageUrl: profileImageUrl,
    );

    final password = users[idx]['password'];
    users[idx] = {
      ...updated.toJson(),
      'password': password,
    };

    await _writeUsers(users);
    return updated;
  }

  Future<List<User>> getAllUsers() async {
    final usersData = await _readUsers();
    return usersData.map((e) {
      final map = Map<String, dynamic>.from(e)..remove('password');
      return User.fromJson(map);
    }).toList();
  }

  // Optional helper for local testing reset.
  Future<void> clearLocalAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usersKey);
    await prefs.remove(_currentUserIdKey);
    await prefs.remove(tokenKey);
    if (kDebugMode) {
      debugPrint('[AuthService] local auth data cleared');
    }
  }
}
