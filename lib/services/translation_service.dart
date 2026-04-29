import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'call_socket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

class SubtitleEvent {
  final String original;
  final String translated;
  final bool isLocal;
  final int? latencyMs;

  const SubtitleEvent({
    required this.original,
    required this.translated,
    required this.isLocal,
    this.latencyMs,
  });
}

enum TranslationStatus { idle, initialising, active, paused, error }

// ─────────────────────────────────────────────────────────────────────────────
// TranslationService
// ─────────────────────────────────────────────────────────────────────────────

class TranslationService {
  TranslationService({
    CallSocketService? socketService,
    SpeechToText? speechToText,
    AudioPlayer? audioPlayer,
  })  : _socket = socketService ?? CallSocketService.instance,
        _stt = speechToText ?? SpeechToText(),
        _player = audioPlayer ?? AudioPlayer();

  final CallSocketService _socket;
  final SpeechToText _stt;
  final AudioPlayer _player;

  String? _targetUserId;
  String _myLanguage = 'en';
  String _peerLanguage = 'ta';

  bool _sttReady = false;
  bool _sessionActive = false;

  final List<Uint8List> _audioQueue = [];
  bool _isPlayingAudio = false;

  static const _minSendIntervalMs = 800;
  DateTime _lastSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastInterimText = '';
  Timer? _silenceTimer;
  static const _silenceThreshold = Duration(milliseconds: 1200);

  Timer? _restartTimer;
  bool _disposed = false;

  final StreamController<SubtitleEvent> _subtitleController =
      StreamController<SubtitleEvent>.broadcast();
  final StreamController<TranslationStatus> _statusController =
      StreamController<TranslationStatus>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  Stream<SubtitleEvent> get subtitles => _subtitleController.stream;
  Stream<TranslationStatus> get status => _statusController.stream;
  Stream<String> get errors => _errorController.stream;

  TranslationStatus _currentStatus = TranslationStatus.idle;
  TranslationStatus get currentStatus => _currentStatus;

  StreamSubscription<Map<String, dynamic>>? _subtitleSub;
  StreamSubscription<Map<String, dynamic>>? _audioSub;
  StreamSubscription<Map<String, dynamic>>? _translationStartedSub;

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<bool> initialise() async {
    _setStatus(TranslationStatus.initialising);
    try {
      _sttReady = await _stt.initialize(
        onError: _onSttError,
        onStatus: _onSttStatus,
      );
    } catch (e) {
      _emitError('Speech recognition failed to initialise: $e');
      _setStatus(TranslationStatus.error);
      return false;
    }
    if (!_sttReady) {
      _emitError('Speech recognition not available on this device.');
      _setStatus(TranslationStatus.error);
      return false;
    }
    _attachSocketListeners();
    _setStatus(TranslationStatus.idle);
    return true;
  }

  Future<void> startSession({
    required String targetUserId,
    required String myLanguage,
    required String peerLanguage,
  }) async {
    if (_disposed) return;
    if (!_sttReady) {
      final ok = await initialise();
      if (!ok) return;
    }
    _targetUserId = targetUserId;
    _myLanguage = myLanguage;
    _peerLanguage = peerLanguage;
    _sessionActive = true;
    _socket.startTranslation(
      targetUserId: targetUserId,
      sourceLanguage: myLanguage,
      targetLanguage: peerLanguage,
    );
    _setStatus(TranslationStatus.active);
    await _startListening();
  }

  Future<void> pause() async {
    if (!_sessionActive) return;
    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    await _stt.stop();
    _setStatus(TranslationStatus.paused);
  }

  Future<void> resume() async {
    if (!_sessionActive || _disposed) return;
    _setStatus(TranslationStatus.active);
    await _startListening();
  }

  Future<void> stopSession() async {
    _sessionActive = false;
    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    await _stt.stop();
    await _player.stop();
    _audioQueue.clear();
    _isPlayingAudio = false;
    _setStatus(TranslationStatus.idle);
  }

  void sendCallText({required String text, bool shouldSpeak = true}) {
    if (_targetUserId == null || text.trim().isEmpty) return;
    _socket.sendCallText(
      targetUserId: _targetUserId!,
      text: text.trim(),
      sourceLanguage: _myLanguage,
      targetLanguage: _peerLanguage,
      shouldSpeak: shouldSpeak,
      isFinal: true,
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    await stopSession();
    await _subtitleSub?.cancel();
    await _audioSub?.cancel();
    await _translationStartedSub?.cancel();
    await _subtitleController.close();
    await _statusController.close();
    await _errorController.close();
    await _player.dispose();
  }

  // ── STT internals ──────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    if (!_sttReady || !_sessionActive || _disposed) return;
    if (_stt.isListening) return;
    try {
      await _stt.listen(
        onResult: _onSttResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        localeId: _myLanguage == 'ta' ? 'ta_IN' : '${_myLanguage}_US',
        listenMode: ListenMode.dictation,
        cancelOnError: false,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[TranslationService] STT listen error: $e');
      _scheduleRestart();
    }
  }

  void _onSttResult(SpeechRecognitionResult result) {
    if (!_sessionActive || _disposed) return;
    final text = result.recognizedWords.trim();
    if (text.isEmpty) return;
    _silenceTimer?.cancel();
    if (result.finalResult) {
      _flushText(text, isFinal: true);
      _lastInterimText = '';
      _scheduleRestart(delay: const Duration(milliseconds: 300));
    } else {
      _lastInterimText = text;
      final elapsed = DateTime.now().difference(_lastSentAt).inMilliseconds;
      if (elapsed >= _minSendIntervalMs) {
        _flushText(text, isFinal: false);
      }
      _silenceTimer = Timer(_silenceThreshold, () {
        if (_lastInterimText.isNotEmpty) {
          _flushText(_lastInterimText, isFinal: true);
          _lastInterimText = '';
        }
      });
    }
  }

  void _flushText(String text, {required bool isFinal}) {
    if (_targetUserId == null) return;
    _lastSentAt = DateTime.now();
    _socket.sendCallText(
      targetUserId: _targetUserId!,
      text: text,
      sourceLanguage: _myLanguage,
      targetLanguage: _peerLanguage,
      shouldSpeak: isFinal,
      isFinal: isFinal,
    );
  }

  void _onSttError(SpeechRecognitionError error) {
    if (kDebugMode) {
      debugPrint('[TranslationService] STT error: ${error.errorMsg}');
    }
    if (_sessionActive && !_disposed) _scheduleRestart();
  }

  void _onSttStatus(String status) {
    if (kDebugMode) {
      debugPrint('[TranslationService] STT status: $status');
    }
    if ((status == 'done' || status == 'notListening') &&
        _sessionActive &&
        !_disposed &&
        !_stt.isListening) {
      _scheduleRestart();
    }
  }

  void _scheduleRestart({Duration delay = const Duration(seconds: 1)}) {
    _restartTimer?.cancel();
    _restartTimer = Timer(delay, () {
      if (_sessionActive && !_disposed) _startListening();
    });
  }

  // ── Socket listeners ───────────────────────────────────────────────────────

  void _attachSocketListeners() {
    _subtitleSub?.cancel();
    _audioSub?.cancel();
    _translationStartedSub?.cancel();

    _translationStartedSub = _socket.translationStarted.listen((data) {
      if (kDebugMode) {
        debugPrint('[TranslationService] translation_started: $data');
      }
    });

    _subtitleSub = _socket.receiveSubtitle.listen(_handleSubtitleEvent);
    _audioSub = _socket.receiveTranslatedAudio.listen(_handleTranslatedAudio);
  }

  void _handleSubtitleEvent(Map<String, dynamic> data) {
    final original = data['original']?.toString() ?? '';
    final translated =
        data['translated']?.toString() ?? data['text']?.toString() ?? '';
    final latency = data['latencyMs'] is int ? data['latencyMs'] as int : null;
    final fromSelf = data['fromSelf'] == true;
    if (translated.isEmpty) return;
    _subtitleController.add(SubtitleEvent(
      original: original,
      translated: translated,
      isLocal: fromSelf,
      latencyMs: latency,
    ));
  }

  void _handleTranslatedAudio(Map<String, dynamic> data) {
    Uint8List? bytes;
    final raw = data['audioData'];
    if (raw is List) {
      bytes = Uint8List.fromList(raw.whereType<int>().toList());
    } else if (raw is String && raw.isNotEmpty) {
      try {
        bytes = _base64DecodeImpl(raw);
      } catch (_) {}
    }
    if (bytes == null || bytes.isEmpty) return;
    _enqueueAudio(bytes);
  }

  // ── TTS audio queue ────────────────────────────────────────────────────────

  void _enqueueAudio(Uint8List bytes) {
    _audioQueue.add(bytes);
    if (!_isPlayingAudio) _drainAudioQueue();
  }

  Future<void> _drainAudioQueue() async {
    if (_isPlayingAudio || _audioQueue.isEmpty || _disposed) return;
    _isPlayingAudio = true;
    while (_audioQueue.isNotEmpty && !_disposed) {
      final chunk = _audioQueue.removeAt(0);
      try {
        final source = _BytesAudioSource(chunk);
        await _player.setAudioSource(source);
        await _player.play();
        await _player.playerStateStream.firstWhere(
          (s) =>
              s.processingState == ProcessingState.completed ||
              s.processingState == ProcessingState.idle,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[TranslationService] audio play error: $e');
        }
      }
    }
    _isPlayingAudio = false;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setStatus(TranslationStatus next) {
    _currentStatus = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }

  void _emitError(String message) {
    if (!_errorController.isClosed) _errorController.add(message);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// In-memory audio source for just_audio
// ─────────────────────────────────────────────────────────────────────────────

class _BytesAudioSource extends StreamAudioSource {
  final Uint8List _bytes;
  _BytesAudioSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pure-Dart base64 decode
// ─────────────────────────────────────────────────────────────────────────────

Uint8List _base64DecodeImpl(String input) {
  const alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  final lookup = List<int>.filled(256, -1);
  for (var i = 0; i < alphabet.length; i++) {
    lookup[alphabet.codeUnitAt(i)] = i;
  }
  final cleaned = input.replaceAll(RegExp(r'\s'), '');
  final padded = cleaned.padRight(
    cleaned.length + (4 - cleaned.length % 4) % 4,
    '=',
  );
  final out = <int>[];
  for (var i = 0; i < padded.length; i += 4) {
    final a = lookup[padded.codeUnitAt(i)];
    final b = lookup[padded.codeUnitAt(i + 1)];
    final c = i + 2 < padded.length ? lookup[padded.codeUnitAt(i + 2)] : -1;
    final d = i + 3 < padded.length ? lookup[padded.codeUnitAt(i + 3)] : -1;
    if (a < 0 || b < 0) break;
    out.add((a << 2) | (b >> 4));
    if (c >= 0) out.add(((b & 0xF) << 4) | (c >> 2));
    if (d >= 0) out.add(((c & 0x3) << 6) | d);
  }
  return Uint8List.fromList(out);
}
