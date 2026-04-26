import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:multilingual_chat_app/models/user.dart';
import 'package:multilingual_chat_app/services/auth_service.dart';

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Auth state provider
final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.loading()) {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    if (kDebugMode) debugPrint('[AuthNotifier] initializeAuth start');
    try {
      final user = await _authService.getCurrentUser();
      state = AsyncValue.data(user);
      if (kDebugMode) {
        debugPrint(
            '[AuthNotifier] initializeAuth done: hasUser=${user != null}');
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      if (kDebugMode) {
        debugPrint('[AuthNotifier] initializeAuth error: $error');
      }
    }
  }

  Future<void> login(String email, String password) async {
    final previousState = state;
    if (kDebugMode) debugPrint('[AuthNotifier] login start: $email');
    try {
      await _authService.login(email, password);
      final user = await _authService.getCurrentUser();
      state = AsyncValue.data(user);
      if (kDebugMode) {
        debugPrint('[AuthNotifier] login done: hasUser=${user != null}');
      }
    } catch (error, stackTrace) {
      state = previousState;
      if (kDebugMode) debugPrint('[AuthNotifier] login error: $error');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<Map<String, dynamic>> register(String name, String email,
      String password, String preferredLanguage) async {
    final previousState = state;
    if (kDebugMode) debugPrint('[AuthNotifier] register start: $email');
    try {
      final result =
          await _authService.register(name, email, password, preferredLanguage);
      final user = await _authService.getCurrentUser();
      state = AsyncValue.data(user);
      if (kDebugMode) {
        debugPrint('[AuthNotifier] register done: hasUser=${user != null}');
      }
      return result;
    } catch (error, stackTrace) {
      state = previousState;
      if (kDebugMode) debugPrint('[AuthNotifier] register error: $error');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> updateProfile({
    String? name,
    String? preferredLanguage,
    String? profileImageUrl,
  }) async {
    try {
      final updatedUser = await _authService.updateProfile(
        name: name,
        preferredLanguage: preferredLanguage,
        profileImageUrl: profileImageUrl,
      );
      state = AsyncValue.data(updatedUser);
    } catch (error, stackTrace) {
      // Keep current state on error but could show a snackbar
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AsyncValue.data(null);
  }

  Future<void> refreshUser() async {
    if (kDebugMode) debugPrint('[AuthNotifier] refreshUser start');
    try {
      final user = await _authService.getCurrentUser();
      state = AsyncValue.data(user);
      if (kDebugMode) {
        debugPrint('[AuthNotifier] refreshUser done: hasUser=${user != null}');
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      if (kDebugMode) debugPrint('[AuthNotifier] refreshUser error: $error');
    }
  }
}
