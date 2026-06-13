import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:multilingual_chat_app/models/friend_request.dart';
import 'package:multilingual_chat_app/models/user.dart' as app_model;
import 'package:multilingual_chat_app/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'dart:io';
import 'dart:math' as math;

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
    if (error is AuthException) {
      final code = error.code ?? '';
      final msg = error.message;
      if (code == 'email_not_confirmed' ||
          msg.toLowerCase().contains('email not confirmed')) {
        return 'Email not confirmed. Please check your inbox for the verification link.';
      }
      if (code == 'invalid_credentials' ||
          msg.toLowerCase().contains('invalid login credentials')) {
        return 'Invalid email or password.';
      }
      return msg;
    }

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

  bool _isProfileIdFormat(String value) {
    return RegExp(r'^EC-\d{8}$').hasMatch(value);
  }

  String _normalizeProfileId(String value) {
    final trimmed = value.trim();
    if (_isProfileIdFormat(trimmed)) {
      return trimmed;
    }

    if (RegExp(r'^\d{8}$').hasMatch(trimmed)) {
      return 'EC-$trimmed';
    }

    return trimmed.startsWith('EC-') ? trimmed : 'EC-$trimmed';
  }

  Future<String> _generateUniqueProfileId() async {
    final random = math.Random();

    while (true) {
      final buffer = StringBuffer();
      for (var index = 0; index < 8; index++) {
        buffer.write(random.nextInt(10));
      }

      final candidate = 'EC-${buffer.toString()}';
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('profile_id', candidate)
          .limit(1);

      if (existing.isEmpty) {
        return candidate;
      }
    }
  }

  Map<String, dynamic> _userToProfileMap(app_model.User user) {
    return {
      'id': user.id,
      'profileId': user.profileId,
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
      'profileId': row['profileId'] ?? row['profile_id'],
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
      final existing = Map<String, dynamic>.from(rows.first);
      final existingProfileId =
          (existing['profileId'] ?? existing['profile_id'] ?? '').toString();

      if (existingProfileId.trim().isEmpty) {
        final generatedProfileId = await _generateUniqueProfileId();
        final updated = await _client
            .from('profiles')
            .update({
              'profile_id': generatedProfileId,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', authUser.id)
            .select()
            .single();

        return _profileToUser(
          Map<String, dynamic>.from(updated),
          fallbackEmail: authUser.email,
        );
      }

      if (!_isProfileIdFormat(existingProfileId)) {
        final normalizedProfileId = _normalizeProfileId(existingProfileId);
        final updated = await _client
            .from('profiles')
            .update({
              'profile_id': normalizedProfileId,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', authUser.id)
            .select()
            .single();

        return _profileToUser(
          Map<String, dynamic>.from(updated),
          fallbackEmail: authUser.email,
        );
      }

      return _profileToUser(
        existing,
        fallbackEmail: authUser.email,
      );
    }

    final generatedProfileId = await _generateUniqueProfileId();

    final payload = {
      'id': authUser.id,
      'profile_id': generatedProfileId,
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

  Future<app_model.User?> getUserByProfileId(String profileId) async {
    if (!SupabaseService.isConfigured) {
      return null;
    }

    final normalizedProfileId = _normalizeProfileId(profileId);
    if (!_isProfileIdFormat(normalizedProfileId)) {
      return null;
    }

    final rows = await _client
        .from('profiles')
        .select()
        .eq('profile_id', normalizedProfileId)
        .limit(1);

    if (rows.isEmpty) {
      return null;
    }

    return _profileToUser(
      Map<String, dynamic>.from(rows.first),
      fallbackEmail: rows.first['email']?.toString(),
    );
  }

  /// Sends a friend REQUEST (does NOT add directly).
  /// The receiver must accept before chatting is allowed.
  Future<app_model.User> addFriendByProfileId(String profileId) async {
    final current = await getCurrentUser();
    if (current == null) throw Exception('Not authenticated');

    final target = await getUserByProfileId(profileId);
    if (target == null) throw Exception('No user found with that Profile ID.');
    if (target.id == current.id) throw Exception('You cannot add yourself.');

    // Check if already friends
    final alreadyFriend = await _client
        .from('friends')
        .select('id')
        .or('and(user_id.eq.${current.id},friend_id.eq.${target.id}),and(user_id.eq.${target.id},friend_id.eq.${current.id})')
        .limit(1);
    if (alreadyFriend.isNotEmpty) {
      throw Exception('You are already friends with ${target.name}.');
    }

    // Check for a pending request in either direction
    final existing = await _client
        .from('friend_requests')
        .select('id, status')
        .or('and(sender_id.eq.${current.id},receiver_id.eq.${target.id}),and(sender_id.eq.${target.id},receiver_id.eq.${current.id})')
        .eq('status', 'pending')
        .limit(1);
    if (existing.isNotEmpty) {
      throw Exception('A pending request already exists with ${target.name}.');
    }

    await _client.from('friend_requests').insert({
      'sender_id': current.id,
      'receiver_id': target.id,
      'status': 'pending',
    });

    return target;
  }

  // ── Friend request helpers ────────────────────────────────────────────────

  Future<List<FriendRequest>> getIncomingRequests() async {
    final current = await getCurrentUser();
    if (current == null) return [];

    final rows = await _client
        .from('friend_requests')
        .select()
        .eq('receiver_id', current.id)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    final result = <FriendRequest>[];
    for (final row in rows) {
      final req = _requestFromRow(row);
      final senderRows = await _client
          .from('profiles')
          .select()
          .eq('id', req.senderId)
          .limit(1);
      if (senderRows.isNotEmpty) {
        req.senderUser = _profileToUser(
            Map<String, dynamic>.from(senderRows.first));
      }
      result.add(req);
    }
    return result;
  }

  Future<List<FriendRequest>> getOutgoingRequests() async {
    final current = await getCurrentUser();
    if (current == null) return [];

    final rows = await _client
        .from('friend_requests')
        .select()
        .eq('sender_id', current.id)
        .inFilter('status', ['pending', 'accepted', 'cancelled'])
        .order('created_at', ascending: false);

    final result = <FriendRequest>[];
    for (final row in rows) {
      final req = _requestFromRow(row);
      final receiverRows = await _client
          .from('profiles')
          .select()
          .eq('id', req.receiverId)
          .limit(1);
      if (receiverRows.isNotEmpty) {
        req.receiverUser = _profileToUser(
            Map<String, dynamic>.from(receiverRows.first));
      }
      result.add(req);
    }
    return result;
  }

  Future<void> acceptRequest(String requestId) async {
    final current = await getCurrentUser();
    if (current == null) throw Exception('Not authenticated');

    // Fetch the request
    final rows = await _client
        .from('friend_requests')
        .select()
        .eq('id', requestId)
        .limit(1);
    if (rows.isEmpty) throw Exception('Request not found.');

    final row = rows.first;
    final senderId = row['sender_id']?.toString() ?? '';
    final receiverId = row['receiver_id']?.toString() ?? '';

    if (receiverId != current.id) {
      throw Exception('You are not the receiver of this request.');
    }

    // Mark accepted
    await _client
        .from('friend_requests')
        .update({'status': 'accepted'})
        .eq('id', requestId);

    // Create the friendship (both directions)
    final existingFriend = await _client
        .from('friends')
        .select('id')
        .or('and(user_id.eq.$senderId,friend_id.eq.$receiverId),and(user_id.eq.$receiverId,friend_id.eq.$senderId)')
        .limit(1);
    if (existingFriend.isEmpty) {
      await _client.from('friends').insert({
        'user_id': receiverId, // current.id (auth.uid()) to satisfy the RLS policy
        'friend_id': senderId,
      });

      // Auto-send a welcome message to break the ice
      await _client.from('messages').insert({
        'sender_id': receiverId, // current.id (auth.uid()) to satisfy the messages RLS insert policy
        'receiver_id': senderId,
        'content': '💬 You are now connected on ec communication! Start typing to say hello!',
        'type': 'text',
        'status': 'sent',
      });
    }
  }

  Future<void> cancelRequest(String requestId) async {
    await _client
        .from('friend_requests')
        .update({'status': 'cancelled'})
        .eq('id', requestId);
  }

  // ── Internal helper ───────────────────────────────────────────────────────
  FriendRequest _requestFromRow(Map<String, dynamic> row) {
    return FriendRequest.fromJson(row);
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
    } on AuthException {
      rethrow;
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

  Future<void> resendVerificationEmail(String email) async {
    if (!SupabaseService.isConfigured) {
      throw Exception('Supabase is not configured.');
    }
    try {
      await _withNetworkRetry(() {
        return _client.auth.resend(
          type: OtpType.signup,
          email: email.trim(),
        );
      });
    } catch (error) {
      throw Exception(_toUserFriendlyAuthError(error));
    }
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

  Future<String> uploadProfileImage(File imageFile) async {
    final current = await getCurrentUser();
    if (current == null) {
      throw Exception('Not authenticated');
    }

    try {
      const bucketName = 'avatars';

      // Ensure the bucket exists, create if necessary
      try {
        await _ensureBucketExists(bucketName);
      } catch (bucketError) {
        if (kDebugMode) {
          debugPrint('[AuthService] Bucket setup error: $bucketError');
        }
        // Continue anyway, bucket might already exist
      }

      // Create a unique filename based on user ID and timestamp
      final fileName =
          'profile_${current.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'profile_images/$fileName';

      // Upload the file to Supabase storage
      await _client.storage.from(bucketName).upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(upsert: false),
          );

      // Get the public URL
      final publicUrl = _client.storage.from(bucketName).getPublicUrl(filePath);

      if (kDebugMode) {
        debugPrint(
            '[AuthService] Profile image uploaded successfully: $publicUrl');
      }

      return publicUrl;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[AuthService] Profile image upload error: $error');
      }
      throw Exception('Failed to upload profile image: $error');
    }
  }

  Future<void> _ensureBucketExists(String bucketName) async {
    try {
      // Try to get the bucket list
      final buckets = await _client.storage.listBuckets();
      final bucketExists = buckets.any((b) => b.name == bucketName);

      if (!bucketExists) {
        if (kDebugMode) {
          debugPrint(
              '[AuthService] Bucket "$bucketName" not found, creating...');
        }

        // Create the bucket with public access
        await _client.storage.createBucket(
          bucketName,
          const BucketOptions(public: true),
        );

        if (kDebugMode) {
          debugPrint('[AuthService] Bucket "$bucketName" created successfully');
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[AuthService] Error ensuring bucket exists: $error');
      }
      // If we can't create the bucket, let the upload attempt fail with a clearer message
      rethrow;
    }
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
    final profileEmail =
        current.email.trim().isNotEmpty ? current.email.trim() : authEmail;
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

  Future<List<app_model.User>> getFriends() async {
    final current = await getCurrentUser();
    if (current == null) {
      return <app_model.User>[];
    }

    final friendRows = await _client
        .from('friends')
        .select('user_id, friend_id')
        .or('user_id.eq.${current.id},friend_id.eq.${current.id}');

    final Set<String> friendIds = {};
    for (final row in friendRows) {
      if (row['user_id'] != current.id) friendIds.add(row['user_id']);
      if (row['friend_id'] != current.id) friendIds.add(row['friend_id']);
    }

    if (friendIds.isEmpty) return <app_model.User>[];

    final profileRows = await _client
        .from('profiles')
        .select()
        .inFilter('id', friendIds.toList())
        .order('is_online', ascending: false)
        .order('last_seen', ascending: false);

    return profileRows
        .whereType<Map>()
        .map((e) => _profileToUser(e.map((k, v) => MapEntry(k.toString(), v))))
        .toList();
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
