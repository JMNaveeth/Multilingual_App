import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:multilingual_chat_app/models/user.dart';

class AuthService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );
  static const bool _enableLocalAuthFallback = bool.fromEnvironment(
    'ENABLE_LOCAL_AUTH_FALLBACK',
    defaultValue: false,
  );

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

  String _normalizeBaseUrl(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;

  Uri _apiUri(String path) => Uri.parse('${_normalizeBaseUrl(baseUrl)}$path');

  Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  String _extractApiError(http.Response response, {String fallback = 'Request failed'}) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final message = body['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}
    return '$fallback (${response.statusCode})';
  }

  Exception _mobileHostHint(Object error) {
    final lower = error.toString().toLowerCase();
    if (baseUrl.contains('localhost') &&
        (lower.contains('socket') ||
            lower.contains('connection') ||
            lower.contains('failed host lookup') ||
            lower.contains('connection refused'))) {
      return Exception(
        'Cannot reach $baseUrl from this device. For phone testing, run with '
        '--dart-define=API_BASE_URL=http://<YOUR-LAPTOP-LAN-IP>:3000/api',
      );
    }
    return Exception(error.toString());
  }

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
    // Backend-first auth enables the same account across laptop and phone.
    try {
      final response = await http.post(
        _apiUri('/auth/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;
        final token = data?['token']?.toString();
        final userMap = data?['user'] as Map<String, dynamic>?;
        if (token == null || userMap == null) {
          throw Exception('Invalid login response from server');
        }

        final user = User.fromJson(userMap);
        await saveToken(token);
        await _saveCurrentUserId(user.id);
        if (kDebugMode) {
          debugPrint('[AuthService] backend login success for ${email.trim()}');
        }
        return {
          'token': token,
          'user': user.toJson(),
        };
      }

      throw Exception(_extractApiError(response, fallback: 'Login failed'));
    } catch (error) {
      if (!_enableLocalAuthFallback) {
        throw _mobileHostHint(error);
      }
      if (kDebugMode) {
        debugPrint('[AuthService] backend login failed, using local fallback: $error');
      }
    }

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
    try {
      final response = await http.post(
        _apiUri('/auth/register'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'preferredLanguage': preferredLanguage,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;
        final token = data?['token']?.toString();
        final userMap = data?['user'] as Map<String, dynamic>?;
        if (token == null || userMap == null) {
          throw Exception('Invalid register response from server');
        }

        final user = User.fromJson(userMap);
        await saveToken(token);
        await _saveCurrentUserId(user.id);
        if (kDebugMode) {
          debugPrint('[AuthService] backend register success for ${email.trim()}');
        }
        return {
          'token': token,
          'user': user.toJson(),
        };
      }

      throw Exception(_extractApiError(response, fallback: 'Register failed'));
    } catch (error) {
      if (!_enableLocalAuthFallback) {
        throw _mobileHostHint(error);
      }
      if (kDebugMode) {
        debugPrint('[AuthService] backend register failed, using local fallback: $error');
      }
    }

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

    try {
      final response = await http.get(
        _apiUri('/auth/me'),
        headers: await _authHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;
        final userMap = data?['user'] as Map<String, dynamic>?;
        if (userMap == null) {
          throw Exception('Invalid profile response from server');
        }
        final user = User.fromJson(userMap);
        await _saveCurrentUserId(user.id);
        return user;
      }

      if (!_enableLocalAuthFallback) {
        await removeToken();
        await _clearCurrentUserId();
        return null;
      }
    } catch (error) {
      if (!_enableLocalAuthFallback) {
        throw _mobileHostHint(error);
      }
      if (kDebugMode) {
        debugPrint('[AuthService] backend getCurrentUser failed, local fallback: $error');
      }
    }

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
    try {
      await http.post(
        _apiUri('/auth/logout'),
        headers: await _authHeaders(),
      );
    } catch (_) {}

    await removeToken();
    await _clearCurrentUserId();
  }

  Future<User> updateProfile({
    String? name,
    String? preferredLanguage,
    String? profileImageUrl,
  }) async {
    try {
      final response = await http.put(
        _apiUri('/auth/profile'),
        headers: await _authHeaders(),
        body: jsonEncode({
          if (name != null) 'name': name,
          if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
          if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;
        final userMap = data?['user'] as Map<String, dynamic>?;
        if (userMap == null) {
          throw Exception('Invalid update profile response from server');
        }
        final updated = User.fromJson(userMap);
        await _saveCurrentUserId(updated.id);
        return updated;
      }

      throw Exception(_extractApiError(response, fallback: 'Update profile failed'));
    } catch (error) {
      if (!_enableLocalAuthFallback) {
        throw _mobileHostHint(error);
      }
      if (kDebugMode) {
        debugPrint('[AuthService] backend updateProfile failed, local fallback: $error');
      }
    }

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
    try {
      final response = await http.get(
        _apiUri('/users'),
        headers: await _authHeaders(),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;
        final usersRaw = data?['users'];
        if (usersRaw is! List) return [];
        return usersRaw
            .whereType<Map>()
            .map((e) => User.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
            .toList();
      }

      throw Exception(_extractApiError(response, fallback: 'Failed to load users'));
    } catch (error) {
      if (!_enableLocalAuthFallback) {
        throw _mobileHostHint(error);
      }
      if (kDebugMode) {
        debugPrint('[AuthService] backend getAllUsers failed, local fallback: $error');
      }
    }

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
