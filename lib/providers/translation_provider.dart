import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/services/translation_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Service singleton provider
// ─────────────────────────────────────────────────────────────────────────────

final translationServiceProvider = Provider<TranslationService>((ref) {
  final service = TranslationService();
  ref.onDispose(service.dispose);
  return service;
});

// ─────────────────────────────────────────────────────────────────────────────
// Session state
// ─────────────────────────────────────────────────────────────────────────────

class TranslationSessionState {
  final TranslationStatus status;
  final SubtitleEvent? latestSubtitle;
  final List<SubtitleEvent> history;
  final String? lastError;
  final String myLanguage;
  final String peerLanguage;

  const TranslationSessionState({
    required this.status,
    required this.history,
    this.latestSubtitle,
    this.lastError,
    this.myLanguage = 'en',
    this.peerLanguage = 'ta',
  });

  static const initial = TranslationSessionState(
    status: TranslationStatus.idle,
    history: [],
  );

  TranslationSessionState copyWith({
    TranslationStatus? status,
    SubtitleEvent? latestSubtitle,
    List<SubtitleEvent>? history,
    String? lastError,
    String? myLanguage,
    String? peerLanguage,
  }) {
    return TranslationSessionState(
      status: status ?? this.status,
      latestSubtitle: latestSubtitle ?? this.latestSubtitle,
      history: history ?? this.history,
      lastError: lastError,
      myLanguage: myLanguage ?? this.myLanguage,
      peerLanguage: peerLanguage ?? this.peerLanguage,
    );
  }

  bool get isActive => status == TranslationStatus.active;
  bool get isPaused => status == TranslationStatus.paused;
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class TranslationSessionNotifier
    extends StateNotifier<TranslationSessionState> {
  TranslationSessionNotifier(this._service)
      : super(TranslationSessionState.initial) {
    _init();
  }

  final TranslationService _service;
  static const int _maxHistory = 50;

  StreamSubscription<SubtitleEvent>? _subtitleSub;
  StreamSubscription<TranslationStatus>? _statusSub;
  StreamSubscription<String>? _errorSub;

  void _init() {
    _statusSub = _service.status.listen((s) {
      if (!mounted) return;
      state = state.copyWith(status: s);
    });

    _subtitleSub = _service.subtitles.listen((event) {
      if (!mounted) return;
      final updated = List<SubtitleEvent>.from(state.history)..add(event);
      if (updated.length > _maxHistory) updated.removeAt(0);
      state = state.copyWith(latestSubtitle: event, history: updated);
    });

    _errorSub = _service.errors.listen((msg) {
      if (!mounted) return;
      state = state.copyWith(lastError: msg);
    });
  }

  Future<bool> initialise() => _service.initialise();

  Future<void> startSession({
    required String targetUserId,
    required String myLanguage,
    required String peerLanguage,
  }) async {
    state = state.copyWith(
      myLanguage: myLanguage,
      peerLanguage: peerLanguage,
      lastError: null,
    );
    await _service.startSession(
      targetUserId: targetUserId,
      myLanguage: myLanguage,
      peerLanguage: peerLanguage,
    );
  }

  Future<void> pause() => _service.pause();
  Future<void> resume() => _service.resume();
  Future<void> stopSession() => _service.stopSession();

  void sendCallText({required String text, bool shouldSpeak = true}) =>
      _service.sendCallText(text: text, shouldSpeak: shouldSpeak);

  void clearHistory() =>
      state = state.copyWith(history: [], latestSubtitle: null);

  void clearError() => state = state.copyWith(lastError: null);

  @override
  void dispose() {
    _subtitleSub?.cancel();
    _statusSub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final translationSessionProvider = StateNotifierProvider<
    TranslationSessionNotifier, TranslationSessionState>(
  (ref) {
    final service = ref.watch(translationServiceProvider);
    return TranslationSessionNotifier(service);
  },
);

final translationActiveProvider = Provider<bool>((ref) {
  return ref.watch(translationSessionProvider.select((s) => s.isActive));
});

final latestSubtitleProvider = Provider<SubtitleEvent?>((ref) {
  return ref.watch(
      translationSessionProvider.select((s) => s.latestSubtitle));
});

final subtitleHistoryProvider = Provider<List<SubtitleEvent>>((ref) {
  return ref
      .watch(translationSessionProvider.select((s) => s.history));
});

final translationStatusProvider = Provider<TranslationStatus>((ref) {
  return ref
      .watch(translationSessionProvider.select((s) => s.status));
});