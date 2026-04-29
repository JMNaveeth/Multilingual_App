import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:multilingual_chat_app/models/user.dart' as app_model;
import 'package:multilingual_chat_app/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class AuthService {
  // Kept for compatibility with existing call/socket code paths.
  static String get baseUrl {
    return (dotenv.env['SERVER_URL'] ?? '').trim();
  }

  SupabaseClient get _client => SupabaseService.client;

  bool _isRetryableNetworkError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('authretryablefetchexception') ||
        text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('temporary failure in name resolution') ||
        text.contains('connection timed out') ||
        text.contains('network is unreachable');
  }

  String _toUserFriendlyAuthError(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();

    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception')) {
      return 'Cannot reach Supabase server from this device. Check mobile internet/Wi-Fi, disable strict Private DNS or VPN, then try again.';
    }

    if (lower.contains('timed out')) {
      return 'Network timeout while contacting Supabase. Please try again.';
    }

    if (lower.contains('invalid login credentials')) {
      return 'Invalid email or password.';
    }

    return text;
  }

  Future<T> _withNetworkRetry<T>(Future<T> Function() action) async {
    const delays = <Duration>[
      Duration(milliseconds: 350),
      Duration(milliseconds: 850),
    ];

    Object? lastError;
    for (var attempt = 0; attempt <= delays.length; attempt++) {
      try {
        return await action();
      } catch (error) {
        lastError = error;
        if (!_isRetryableNetworkError(error) || attempt == delays.length) {
          rethrow;
        }
        await Future<void>.delayed(delays[attempt]);
      }
    }

    throw Exception(_toUserFriendlyAuthError(lastError ?? 'Unknown error'));
  }

  Future<String?> getToken() async {
    return _client.auth.currentSession?.accessToken;
  }

  Future<void> saveToken(String token) async {
    // Token persistence is handled by supabase_flutter.
  }

  Future<void> removeToken() async {
    await _client.auth.signOut();
  }

  DateTime _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  String _normalizedEmail(String email) {
    final noInvisible = email
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '');
    return noInvisible.replaceAll(RegExp(r'\s+'), '').trim().toLowerCase();
  }

  bool _looksLikeEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Map<String, dynamic> _userToProfileMap(app_model.User user) {
    return {
      'id': user.id,
      'email': user.email,
      'name': user.name,
      'profileImageUrl': user.profileImageUrl,
      'preferredLanguage': user.preferredLanguage,
      'isOnline': user.isOnline,
      'lastSeen': user.lastSeen?.toIso8601String(),
      'createdAt': user.createdAt.toIso8601String(),
    };
  }

  app_model.User _profileToUser(Map<String, dynamic> row,
      {String? fallbackEmail}) {
    final mapped = <String, dynamic>{
      '_id': (row['id'] ?? '').toString(),
      'email': (row['email'] ?? fallbackEmail ?? '').toString(),
      'name': (row['name'] ?? 'User').toString(),
      'profileImageUrl': row['profileImageUrl'] ?? row['profile_image_url'],
      'preferredLanguage':
          row['preferredLanguage'] ?? row['preferred_language'] ?? 'en',
      'isOnline': row['isOnline'] ?? row['is_online'] ?? false,
      'lastSeen': row['lastSeen'] ?? row['last_seen'],
      'createdAt': row['createdAt'] ??
          row['created_at'] ??
          DateTime.now().toIso8601String(),
    };
    return app_model.User.fromJson(mapped);
  }

  Future<app_model.User> _ensureProfile(app_model.User authUser) async {
    final rows =
        await _client.from('profiles').select().eq('id', authUser.id).limit(1);

    if (rows.isNotEmpty) {
      return _profileToUser(
        Map<String, dynamic>.from(rows.first),
        fallbackEmail: authUser.email,
      );
    }

    final payload = {
      'id': authUser.id,
      'email': authUser.email,
      'name': authUser.name,
      'preferred_language': authUser.preferredLanguage,
      'profile_image_url': authUser.profileImageUrl,
      'is_online': true,
      'last_seen': DateTime.now().toIso8601String(),
    };

    final inserted =
        await _client.from('profiles').upsert(payload).select().single();

    return _profileToUser(Map<String, dynamic>.from(inserted),
        fallbackEmail: authUser.email);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    if (!SupabaseService.isConfigured) {
      throw Exception(
          'Supabase is not configured. Run with --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...');
    }

    AuthResponse result;
    try {
      result = await _withNetworkRetry(() {
        return _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
      });
    } catch (error) {
      throw Exception(_toUserFriendlyAuthError(error));
    }

    final authUser = result.user;
    final session = result.session;

    if (authUser == null || session == null) {
      throw Exception('Login failed. Please check your credentials.');
    }

    final appUser = await _ensureProfile(
      app_model.User(
        id: authUser.id,
        email: authUser.email ?? email.trim(),
        name: (authUser.userMetadata?['name'] ?? authUser.email ?? 'User')
            .toString(),
        preferredLanguage:
            (authUser.userMetadata?['preferred_language'] ?? 'en').toString(),
        isOnline: true,
        createdAt: _toDateTime(authUser.createdAt),
      ),
    );

    if (kDebugMode) {
      debugPrint('[AuthService] Supabase login success for ${email.trim()}');
    }

    return {
      'token': session.accessToken,
      'user': _userToProfileMap(appUser),
    };
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String preferredLanguage,
  ) async {
    if (!SupabaseService.isConfigured) {
      throw Exception(
          'Supabase is not configured. Run with --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...');
    }

    final normalizedEmail = _normalizedEmail(email);
    if (!_looksLikeEmail(normalizedEmail)) {
      throw Exception('Enter a valid email address (example: name@gmail.com).');
    }

    late final AuthResponse signUp;
    try {
      signUp = await _withNetworkRetry(() {
        return _client.auth.signUp(
          email: normalizedEmail,
          password: password,
          data: {
            'name': name.trim(),
            'preferred_language': preferredLanguage,
          },
        );
      });
    } on AuthException catch (e) {
      final msg = (e.message).toLowerCase();
      final code = (e.code ?? '').toLowerCase();
      if (e.statusCode == '429' ||
          code == 'over_email_send_rate_limit' ||
          msg.contains('over_email_send_rate_limit') ||
          msg.contains('rate limit')) {
        throw Exception(
            'Too many signup attempts right now. Please wait 2-5 minutes and try again.');
      }
      if (code == 'email_address_invalid' ||
          msg.contains('email address') && msg.contains('invalid')) {
        throw Exception(
            'Supabase rejected this email address. Try another email, or check Supabase Authentication -> Providers -> Email settings.');
      }
      if (msg.contains('already') || msg.contains('registered')) {
        throw Exception(
            'This email is already registered. Please use Log In instead of Create Account.');
      }
      throw Exception(e.message);
    } catch (error) {
      throw Exception(_toUserFriendlyAuthError(error));
    }

    final authUser = signUp.user;
    final session = signUp.session;

    if (authUser == null) {
      throw Exception('Registration failed.');
    }

    // If email confirmation is enabled, signUp may not return a session immediately.
    // In this case, the user is still created in Supabase Auth (auth.users).
    if (session == null) {
      if (kDebugMode) {
        debugPrint(
            '[AuthService] Supabase register created auth user without session for ${email.trim()}');
      }

      return {
        'token': null,
        'user': {
          'id': authUser.id,
          'email': authUser.email ?? normalizedEmail,
          'name': name.trim(),
          'preferredLanguage': preferredLanguage,
          'isOnline': false,
        },
        'requiresEmailConfirmation': true,
        'message':
            'Account created in Supabase. Please confirm your email, then log in.',
      };
    }

    final appUser = await _ensureProfile(
      app_model.User(
        id: authUser.id,
        email: authUser.email ?? normalizedEmail,
        name: name.trim(),
        preferredLanguage: preferredLanguage,
        isOnline: true,
        createdAt: _toDateTime(authUser.createdAt),
      ),
    );

    if (kDebugMode) {
      debugPrint('[AuthService] Supabase register success for ${email.trim()}');
    }

    return {
      'token': session.accessToken,
      'user': _userToProfileMap(appUser),
      'requiresEmailConfirmation': false,
    };
  }

  Future<app_model.User?> getCurrentUser() async {
    if (!SupabaseService.isConfigured) {
      return null;
    }

    final current = _client.auth.currentUser;
    if (current == null) {
      return null;
    }

    final fallback = app_model.User(
      id: current.id,
      email: current.email ?? '',
      name:
          (current.userMetadata?['name'] ?? current.email ?? 'User').toString(),
      preferredLanguage:
          (current.userMetadata?['preferred_language'] ?? 'en').toString(),
      isOnline: true,
      createdAt: _toDateTime(current.createdAt),
    );

    try {
      return await _ensureProfile(fallback);
    } catch (_) {
      return fallback;
    }
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  Future<app_model.User> updateProfile({
    String? name,
    String? preferredLanguage,
    String? profileImageUrl,
  }) async {
    final current = await getCurrentUser();
    if (current == null) {
      throw Exception('Not authenticated');
    }

    final authEmail = _client.auth.currentUser?.email?.trim() ?? '';
    final profileEmail = current.email.trim().isNotEmpty
        ? current.email.trim()
        : authEmail;
    if (profileEmail.isEmpty) {
      throw Exception(
          'Your account email is missing. Please sign in again before saving profile changes.');
    }

    final payload = {
      'id': current.id,
      'email': profileEmail,
      if (name != null) 'name': name,
      if (preferredLanguage != null) 'preferred_language': preferredLanguage,
      if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
      'last_seen': DateTime.now().toIso8601String(),
    };

    final updated =
        await _client.from('profiles').upsert(payload).select().single();

    return _profileToUser(Map<String, dynamic>.from(updated),
        fallbackEmail: current.email);
  }

  Future<List<app_model.User>> getAllUsers() async {
    final current = await getCurrentUser();
    if (current == null) {
      return <app_model.User>[];
    }

    final rows = await _client
        .from('profiles')
        .select()
        .neq('id', current.id)
        .order('is_online', ascending: false)
        .order('last_seen', ascending: false);

    return rows
        .whereType<Map>()
        .map((e) => _profileToUser(e.map((k, v) => MapEntry(k.toString(), v))))
        .toList();
  }

  Future<void> clearLocalAuthData() async {
    await _client.auth.signOut();
    if (kDebugMode) {
      debugPrint('[AuthService] Supabase auth session cleared');
    }
  }
}
