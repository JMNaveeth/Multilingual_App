import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:multilingual_chat_app/models/call_history_entry.dart';
import 'package:multilingual_chat_app/models/message.dart';
import 'package:multilingual_chat_app/models/user.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';
import 'package:multilingual_chat_app/providers/call_history_provider.dart';
import 'package:multilingual_chat_app/screens/chat/call_screen.dart';
import 'package:multilingual_chat_app/services/call_socket_service.dart';
import 'package:multilingual_chat_app/services/chat_service.dart';

// ── Nexus Design Tokens ──────────────────────────────────────────────────────
class _N {
  static const bg = Color(0xFF0D0E1A);
  static const surface = Color(0xFF151626);
  static const card = Color(0xFF1C1E31);
  static const cardBorder = Color(0xFF252842);
  static const indigo = Color(0xFF6366F1);
  static const indigoLight = Color(0xFF818CF8);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF8B5CF6);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);
  static const inputBg = Color(0xFF13141F);
  static const inputBorder = Color(0xFF1E2035);
}

// ── Extended Message model for rich content ──────────────────────────────────
/// Wraps [Message] with optional extra payload for image/file/location/contact.
class RichMessage {
  final Message message;

  /// For image messages: local file path
  final String? imagePath;

  /// For file messages
  final String? fileName;
  final String? filePath;
  final int? fileSizeBytes;
  final String? audioPath;

  /// For location messages
  final double? latitude;
  final double? longitude;
  final String? locationLabel;

  /// For contact messages
  final String? contactName;
  final String? contactPhone;

  const RichMessage({
    required this.message,
    this.imagePath,
    this.fileName,
    this.filePath,
    this.fileSizeBytes,
    this.audioPath,
    this.latitude,
    this.longitude,
    this.locationLabel,
    this.contactName,
    this.contactPhone,
  });
}

// ── ChatScreen ────────────────────────────────────────────────────────────────
class ChatScreen extends ConsumerStatefulWidget {
  final User user;
  const ChatScreen({super.key, required this.user});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<RichMessage> _richMessages = [];
  bool _showAttachMenu = false;
  bool _isTyping = false;
  bool _socketReady = false;
  bool _incomingDialogOpen = false;
  bool _isLoadingHistory = true;
  bool _historyFetchStarted = false;
  StreamSubscription<IncomingCall>? _incomingCallSub;
  StreamSubscription<Map<String, dynamic>>? _newMessageSub;
  int _localIdCounter = 0;

  final _chatService = ChatService();
  final _imagePicker = ImagePicker();
  final _audioPlayer = AudioPlayer();
  final SpeechToText _speechToText = SpeechToText();
  bool _isRecording = false;
  bool _isAudioPlaying = false;
  String? _activeAudioPath;
  bool _speechReady = false;
  String _currentVoiceTranscript = '';
  String _lastNonEmptyVoiceTranscript = '';
  bool _speechDetected = false;

  late final AnimationController _onlineGlowCtrl;
  late final AnimationController _attachMenuCtrl;
  late final Animation<double> _attachMenuAnim;

  // ── Init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _onlineGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _attachMenuCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _attachMenuAnim = CurvedAnimation(
      parent: _attachMenuCtrl,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );

    _messageController.addListener(() {
      final typing = _messageController.text.isNotEmpty;
      if (typing != _isTyping) setState(() => _isTyping = typing);
    });
    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing = state.playing;
      final done = state.processingState == ProcessingState.completed;
      if (done) {
        _audioPlayer.seek(Duration.zero);
      }
      if (_isAudioPlaying != (playing && !done)) {
        setState(() => _isAudioPlaying = playing && !done);
      }
    });

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    unawaited(_initializeSpeechToText());
  }

  @override
  void dispose() {
    _incomingCallSub?.cancel();
    _newMessageSub?.cancel();
    if (_speechToText.isListening) {
      unawaited(_speechToText.stop());
    }
    unawaited(_audioPlayer.dispose());
    _messageController.dispose();
    _scrollController.dispose();
    _onlineGlowCtrl.dispose();
    _attachMenuCtrl.dispose();
    super.dispose();
  }

  // ── Socket ────────────────────────────────────────────────────────────────

  Future<void> _ensureSocket(User? currentUser) async {
    if (currentUser == null || _socketReady) return;
    _socketReady = true;
    await CallSocketService.instance.connect(userId: currentUser.id);

    _newMessageSub ??=
        CallSocketService.instance.newMessages.listen((payload) async {
      if (!mounted) return;
      try {
        final messageJson = payload.map((k, v) => MapEntry(k.toString(), v));
        final message = Message.fromJson(messageJson);

        // Only add if it belongs to this conversation
        if ((message.senderId == widget.user.id &&
                message.receiverId == currentUser.id) ||
            (message.senderId == currentUser.id &&
                message.receiverId == widget.user.id)) {
          // Check if we already have it to avoid duplicates from local sync
          final exists = _richMessages.any((rm) => rm.message.id == message.id);
          if (!exists) {
            final richMessage = await _fromIncomingMessage(message);
            _addRich(richMessage, localOnly: true);
          }
        }
      } catch (e) {
        debugPrint('Error parsing new_message: $e');
      }
    });

    _incomingCallSub ??= CallSocketService.instance.incomingCalls.listen(
      (incomingCall) {
        if (!mounted) return;
        if (incomingCall.fromUserId != widget.user.id || _incomingDialogOpen) {
          return;
        }
        _incomingDialogOpen = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: _N.card,
            title: Text(
              'Incoming ${incomingCall.callType} call',
              style: const TextStyle(color: _N.textPrimary),
            ),
            content: Text(
              '${incomingCall.fromName} is calling you.',
              style: const TextStyle(color: _N.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _recordDeclinedIncomingCall(incomingCall);
                  _incomingDialogOpen = false;
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Decline'),
              ),
              ElevatedButton(
                onPressed: () {
                  CallSocketService.instance.answerCall(
                    to: incomingCall.fromUserId,
                    callType: incomingCall.callType,
                  );
                  _incomingDialogOpen = false;
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CallScreen(
                      peerUser: widget.user,
                      callType: incomingCall.callType == 'video'
                          ? CallType.video
                          : CallType.voice,
                      isIncoming: true,
                    ),
                  ));
                },
                child: const Text('Accept'),
              ),
            ],
          ),
        ).then((_) => _incomingDialogOpen = false);
      },
    );
  }

  Future<void> _recordDeclinedIncomingCall(IncomingCall incomingCall) async {
    final currentUser = ref.read(authProvider).value;
    if (currentUser == null) {
      return;
    }

    final now = DateTime.now();
    final entry = CallHistoryEntry(
      id: '${now.microsecondsSinceEpoch}_${incomingCall.fromUserId}',
      peerUserId: incomingCall.fromUserId,
      peerName: incomingCall.fromName,
      peerProfileImageUrl: widget.user.profileImageUrl,
      callType: incomingCall.callType,
      direction: CallDirection.incoming,
      result: CallResult.declined,
      startedAt: now,
      endedAt: now,
      durationSeconds: 0,
    );

    try {
      final service = ref.read(callHistoryServiceProvider);
      await service.addEntry(userId: currentUser.id, entry: entry);
      ref.invalidate(callHistoryProvider(currentUser.id));
    } catch (_) {
      // Best-effort logging only.
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_localIdCounter++}';

  String? _requireCurrentUserId() {
    final userId = ref.read(authProvider).value?.id;
    if (userId == null || userId.isEmpty) {
      _showError('Please sign in.');
      return null;
    }
    return userId;
  }

  Future<void> _loadConversation(String currentUserId) async {
    try {
      await _chatService.migrateLegacyLocalMessages(
        currentUserId: currentUserId,
        knownPeerIds: [widget.user.id],
      );

      final messages = await _chatService.getConversation(
        currentUserId: currentUserId,
        otherUserId: widget.user.id,
      );
      if (!mounted) return;
      setState(() {
        _richMessages
          ..clear()
          ..addAll(messages.map(_fromMessage));
        _isLoadingHistory = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
      });
      _showError('Could not load conversation: $e');
    }
  }

  RichMessage _fromMessage(Message message) {
    final meta = message.metadata ?? const <String, dynamic>{};
    return RichMessage(
      message: message,
      imagePath: (meta['imagePath'] ?? message.mediaUrl)?.toString(),
      fileName: meta['fileName']?.toString(),
      filePath: meta['filePath']?.toString(),
      audioPath: (meta['audioPath'] ?? message.mediaUrl)?.toString(),
      fileSizeBytes: meta['fileSizeBytes'] is int
          ? meta['fileSizeBytes'] as int
          : int.tryParse('${meta['fileSizeBytes'] ?? ''}'),
      latitude: meta['latitude'] is num
          ? (meta['latitude'] as num).toDouble()
          : double.tryParse('${meta['latitude'] ?? ''}'),
      longitude: meta['longitude'] is num
          ? (meta['longitude'] as num).toDouble()
          : double.tryParse('${meta['longitude'] ?? ''}'),
      locationLabel: meta['locationLabel']?.toString(),
      contactName: meta['contactName']?.toString(),
      contactPhone: meta['contactPhone']?.toString(),
    );
  }

  Future<RichMessage> _fromIncomingMessage(Message message) async {
    final meta = message.metadata ?? const <String, dynamic>{};
    final translatedAudio = meta['translatedAudioData'];
    if (message.type == MessageType.audio &&
        translatedAudio is List &&
        translatedAudio.isNotEmpty) {
      try {
        final bytes = List<int>.from(translatedAudio);
        final path =
            '${Directory.systemTemp.path}/translated_voice_${DateTime.now().microsecondsSinceEpoch}.mp3';
        await File(path).writeAsBytes(bytes, flush: true);
        return RichMessage(
          message: message.copyWith(
            metadata: {
              ...meta,
              'audioPath': path,
            },
          ),
          audioPath: path,
        );
      } catch (e) {
        debugPrint('Failed to save translated voice audio: $e');
      }
    }
    return _fromMessage(message);
  }

  void _addRich(RichMessage rm, {bool persist = true, bool localOnly = false}) {
    setState(() => _richMessages.add(rm));
    _scrollToBottom();

    if (!persist) return;
    if (localOnly) {
      _chatService.saveLocalMessage(rm.message).catchError((e) {
        debugPrint('[ChatScreen] saveLocalMessage error: $e');
      });

      final currentUserId = ref.read(authProvider).value?.id;
      if (currentUserId == null || rm.message.senderId != currentUserId) {
        return;
      }
    }

    _chatService.sendMessage(rm.message).then((persisted) {
      if (!mounted) return;
      final index =
          _richMessages.indexWhere((m) => m.message.id == rm.message.id);
      if (index < 0) return;
      setState(() {
        _richMessages[index] = RichMessage(
          message: persisted,
          imagePath: rm.imagePath,
          fileName: rm.fileName,
          filePath: rm.filePath,
          fileSizeBytes: rm.fileSizeBytes,
          audioPath: rm.audioPath,
          latitude: rm.latitude,
          longitude: rm.longitude,
          locationLabel: rm.locationLabel,
          contactName: rm.contactName,
          contactPhone: rm.contactPhone,
        );
      });
    }).catchError((e) {
      debugPrint('[ChatScreen] sendMessage error: $e');
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleAttachMenu() {
    setState(() => _showAttachMenu = !_showAttachMenu);
    if (_showAttachMenu) {
      _attachMenuCtrl.forward();
    } else {
      _attachMenuCtrl.reverse();
    }
  }

  void _closeAttachMenu() {
    if (_showAttachMenu) _toggleAttachMenu();
  }

  // ── 1. GALLERY ─────────────────────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    _closeAttachMenu();
    final senderId = _requireCurrentUserId();
    if (senderId == null) return;
    try {
      final List<XFile> files = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );
      if (!mounted || files.isEmpty) return;

      for (final file in files) {
        _addRich(RichMessage(
          message: Message(
            id: _newId(),
            senderId: senderId,
            receiverId: widget.user.id,
            content: '[Image]',
            type: MessageType.image,
            status: MessageStatus.sent,
            timestamp: DateTime.now(),
            mediaUrl: file.path,
            metadata: {'imagePath': file.path},
          ),
          imagePath: file.path,
        ));
      }
    } catch (e) {
      _showError('Could not open gallery: $e');
    }
  }

  // ── 2. DOCUMENT ────────────────────────────────────────────────────────────

  Future<void> _pickDocument() async {
    _closeAttachMenu();
    final senderId = _requireCurrentUserId();
    if (senderId == null) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: false,
      );
      if (!mounted || result == null || result.files.isEmpty) return;

      final pf = result.files.first;
      _addRich(RichMessage(
        message: Message(
          id: _newId(),
          senderId: senderId,
          receiverId: widget.user.id,
          content: '[Document: ${pf.name}]',
          type: MessageType.file,
          status: MessageStatus.sent,
          timestamp: DateTime.now(),
          metadata: {
            'fileName': pf.name,
            'filePath': pf.path,
            'fileSizeBytes': pf.size,
          },
        ),
        fileName: pf.name,
        filePath: pf.path,
        fileSizeBytes: pf.size,
      ));
    } catch (e) {
      _showError('Could not pick file: $e');
    }
  }

  // ── 3. CAMERA ──────────────────────────────────────────────────────────────

  Future<void> _openCamera() async {
    _closeAttachMenu();
    final senderId = _requireCurrentUserId();
    if (senderId == null) return;
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (!mounted || file == null) return;

      _addRich(RichMessage(
        message: Message(
          id: _newId(),
          senderId: senderId,
          receiverId: widget.user.id,
          content: '[Photo]',
          type: MessageType.image,
          status: MessageStatus.sent,
          timestamp: DateTime.now(),
          mediaUrl: file.path,
          metadata: {'imagePath': file.path},
        ),
        imagePath: file.path,
      ));
    } catch (e) {
      _showError('Could not open camera: $e');
    }
  }

  // ── 4. LOCATION ────────────────────────────────────────────────────────────

  Future<void> _shareLocation() async {
    _closeAttachMenu();
    final senderId = _requireCurrentUserId();
    if (senderId == null) return;

    // Check & request permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      _showError(
          'Location permission permanently denied. Enable it in app settings.');
      return;
    }
    if (perm == LocationPermission.denied) {
      _showError('Location permission denied.');
      return;
    }

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('Location services are disabled. Please enable GPS.');
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Getting your location…',
            style: TextStyle(color: _N.textPrimary)),
        backgroundColor: _N.card,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      String label = '${pos.latitude.toStringAsFixed(5)}, '
          '${pos.longitude.toStringAsFixed(5)}';

      // Reverse-geocode for a human-readable label
      try {
        final placemarks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String?>[
            p.name,
            p.locality,
            p.administrativeArea,
            p.country,
          ].whereType<String>().where((s) => s.isNotEmpty).toList();
          if (parts.isNotEmpty) label = parts.join(', ');
        }
      } catch (_) {
        // Reverse-geocoding failed; fall back to coordinates
      }

      if (!mounted) return;
      _addRich(RichMessage(
        message: Message(
          id: _newId(),
          senderId: senderId,
          receiverId: widget.user.id,
          content: '[Location]',
          type: MessageType.location,
          status: MessageStatus.sent,
          timestamp: DateTime.now(),
          metadata: {
            'latitude': pos.latitude,
            'longitude': pos.longitude,
            'locationLabel': label,
          },
        ),
        latitude: pos.latitude,
        longitude: pos.longitude,
        locationLabel: label,
      ));
    } catch (e) {
      _showError('Could not get location: $e');
    }
  }

  // ── 5. CONTACT ─────────────────────────────────────────────────────────────

  Future<void> _pickContact() async {
    _closeAttachMenu();
    final senderId = _requireCurrentUserId();
    if (senderId == null) return;

    final bool granted = await FlutterContacts.requestPermission();
    if (!granted) {
      _showError('Contacts permission denied.');
      return;
    }

    try {
      final contact = await FlutterContacts.openExternalPick();
      if (!mounted || contact == null) return;

      final phone =
          contact.phones.isNotEmpty ? contact.phones.first.number : 'No phone';

      _addRich(RichMessage(
        message: Message(
          id: _newId(),
          senderId: senderId,
          receiverId: widget.user.id,
          content: '[Contact: ${contact.displayName}]',
          type: MessageType.contact,
          status: MessageStatus.sent,
          timestamp: DateTime.now(),
          metadata: {
            'contactName': contact.displayName,
            'contactPhone': phone,
          },
        ),
        contactName: contact.displayName,
        contactPhone: phone,
      ));
    } catch (e) {
      _showError('Could not pick contact: $e');
    }
  }

  // ── Text message ──────────────────────────────────────────────────────────

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUser = ref.read(authProvider).value;
    if (currentUser == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please sign in.')));
      return;
    }

    _addRich(
        RichMessage(
          message: Message(
            id: _newId(),
            senderId: currentUser.id,
            receiverId: widget.user.id,
            content: text,
            type: MessageType.text,
            status: MessageStatus.sent,
            timestamp: DateTime.now(),
          ),
        ),
        localOnly: true); // Save locally, but let socket handle delivery

    CallSocketService.instance.sendMessageViaSocket(
      receiverId: widget.user.id,
      content: text,
      type: 'text',
      senderLanguage: currentUser.preferredLanguage,
      receiverLanguage: widget.user.preferredLanguage,
    );

    _messageController.clear();
  }

  Future<void> _handleMicTap() async {
    if (_isRecording) {
      await _stopAndSendVoiceMessage();
      return;
    }
    await _startVoiceRecording();
  }

  Future<void> _initializeSpeechToText() async {
    if (_speechReady) return;
    try {
      // Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (micStatus.isDenied) {
        _speechReady = false;
        debugPrint('Microphone permission denied');
        if (mounted) {
          _showError('Microphone permission is required for voice messages.');
        }
        return;
      }
      if (micStatus.isPermanentlyDenied) {
        _speechReady = false;
        debugPrint('Microphone permission permanently denied');
        if (mounted) {
          _showError(
              'Microphone permission is permanently denied. Please enable it in app settings.');
        }
        openAppSettings();
        return;
      }

      debugPrint('Initializing speech-to-text...');
      _speechReady = await _speechToText.initialize(
        onError: _onSpeechError,
        onStatus: (status) {
          debugPrint('Speech recognition status: $status');
        },
      );

      if (_speechReady) {
        final locales = await _speechToText.locales();
        debugPrint('Available locales: ${locales.length}');
      } else {
        debugPrint('Failed to initialize speech-to-text');
      }
    } catch (e) {
      _speechReady = false;
      debugPrint('Error initializing speech-to-text: $e');
      if (mounted) {
        _showError('Failed to initialize voice capture: $e');
      }
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    final errorMsg = error.errorMsg;
    final lowerError = errorMsg.toLowerCase();
    debugPrint(
        'Speech recognition error: $errorMsg (error code: ${error.permanent ? "permanent" : "temporary"})');

    if (!mounted) return;

    if (_isRecording) {
      setState(() => _isRecording = false);
    }

    // Provide user-friendly error messages
    String userMessage = 'Voice capture failed';
    if (lowerError.contains('network')) {
      userMessage = 'Network error. Check your internet connection.';
    } else if (lowerError.contains('timeout')) {
      userMessage = 'Request timeout. Please try again.';
    } else if (lowerError.contains('no_match') ||
        lowerError.contains('nomatch')) {
      userMessage = 'No speech detected. Speak louder and try again.';
    } else if (lowerError.contains('audio')) {
      userMessage = 'Audio error. Check your microphone.';
    }

    _showError('$userMessage ($errorMsg)');
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final recognized = result.recognizedWords.trim();
    if (recognized.isNotEmpty) {
      _speechDetected = true;
      _lastNonEmptyVoiceTranscript = recognized;
      debugPrint(
          'Speech detected: $recognized (isFinal: ${result.finalResult})');
    }
    _currentVoiceTranscript = recognized;
    if (result.finalResult) {
      debugPrint('Final speech result: $_currentVoiceTranscript');
    }
  }

  Future<String?> _resolveSupportedLocale(String preferredLocale) async {
    try {
      final locales = await _speechToText.locales();
      if (locales.isEmpty) {
        return null;
      }

      bool hasExact = false;
      bool hasLanguageFallback = false;
      final preferredLanguage = preferredLocale.split('_').first.toLowerCase();

      for (final locale in locales) {
        final id = locale.localeId;
        if (id == preferredLocale) {
          hasExact = true;
          break;
        }
        if (id.toLowerCase().startsWith(preferredLanguage)) {
          hasLanguageFallback = true;
        }
      }

      if (hasExact) {
        return preferredLocale;
      }

      if (hasLanguageFallback) {
        for (final locale in locales) {
          final id = locale.localeId;
          if (id.toLowerCase().startsWith(preferredLanguage)) {
            return id;
          }
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _tryStartListening({
    required String? localeId,
    required bool onDevice,
  }) async {
    final result = await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        onDevice: onDevice,
      ),
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 8),
    );

    return result == true || _speechToText.isListening;
  }

  Future<void> _startVoiceRecording() async {
    if (_requireCurrentUserId() == null) return;
    await _initializeSpeechToText();
    if (!_speechReady) {
      _showError(
          'Voice capture is not available. Please check permissions and try again.');
      return;
    }

    try {
      _currentVoiceTranscript = '';
      _lastNonEmptyVoiceTranscript = '';
      _speechDetected = false;

      final currentUser = ref.read(authProvider).value;
      final preferredLocale =
          _languageToLocale(currentUser?.preferredLanguage ?? 'en');
      final supportedLocale = await _resolveSupportedLocale(preferredLocale);

      // Try on-device first, then network-backed recognition for better compatibility.
      var listening = await _tryStartListening(
        localeId: supportedLocale,
        onDevice: true,
      );
      if (!listening) {
        listening = await _tryStartListening(
          localeId: supportedLocale,
          onDevice: false,
        );
      }
      if (!listening && supportedLocale != null) {
        // Final fallback: allow engine default locale.
        listening = await _tryStartListening(
          localeId: null,
          onDevice: false,
        );
      }

      if (!listening) {
        if (mounted) {
          _showError(
              'Could not start speech recognition. Check your microphone.');
        }
        debugPrint('Failed to start listening');
        return;
      }

      if (!mounted) return;
      setState(() => _isRecording = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎙️ Listening... Speak clearly, then tap mic to send'),
          duration: Duration(seconds: 6),
        ),
      );
      debugPrint('Started voice recording');
    } catch (e) {
      debugPrint('Error starting voice recording: $e');
      _showError('Could not start voice capture: $e');
    }
  }

  Future<void> _stopAndSendVoiceMessage() async {
    final currentUser = ref.read(authProvider).value;
    if (currentUser == null) {
      _showError('Please sign in.');
      return;
    }

    try {
      // Stop listening
      if (_speechToText.isListening) {
        await _speechToText.stop();
        debugPrint('Stopped listening. Detected: $_currentVoiceTranscript');
      }

      if (!mounted) return;
      setState(() => _isRecording = false);

        final transcript = _currentVoiceTranscript.trim().isNotEmpty
          ? _currentVoiceTranscript.trim()
          : _lastNonEmptyVoiceTranscript.trim();

      // Provide better feedback based on what was detected
      if (transcript.isEmpty) {
        debugPrint('No usable transcript detected. Opening text fallback.');
        await _promptVoiceFallbackInput(currentUser);
        return;
      }

      await _sendVoiceTranscriptAsMessage(transcript, currentUser);

      // Clear state after sending
      _currentVoiceTranscript = '';
      _lastNonEmptyVoiceTranscript = '';
      _speechDetected = false;
    } catch (e) {
      debugPrint('Error stopping/sending voice message: $e');
      if (!mounted) return;
      setState(() => _isRecording = false);
      _showError('Could not send voice message: $e');
    }
  }

  Future<void> _sendVoiceTranscriptAsMessage(String transcript, User currentUser) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      return;
    }

    debugPrint('Sending voice message: $trimmed');
    final rm = RichMessage(
      message: Message(
        id: _newId(),
        senderId: currentUser.id,
        receiverId: widget.user.id,
        content: trimmed,
        type: MessageType.audio,
        status: MessageStatus.sent,
        timestamp: DateTime.now(),
        metadata: {
          'voiceTranscript': trimmed,
          'originalLanguage': currentUser.preferredLanguage,
          'targetLanguage': widget.user.preferredLanguage,
        },
      ),
    );

    _addRich(rm, localOnly: true);
    CallSocketService.instance.sendMessageViaSocket(
      receiverId: widget.user.id,
      content: trimmed,
      type: 'audio',
      senderLanguage: currentUser.preferredLanguage,
      receiverLanguage: widget.user.preferredLanguage,
      metadata: {
        'voiceTranscript': trimmed,
      },
    );
  }

  Future<void> _promptVoiceFallbackInput(User currentUser) async {
    if (!mounted) return;

    final controller = TextEditingController(
      text: _lastNonEmptyVoiceTranscript,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _N.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Could not catch voice clearly',
                style: TextStyle(
                  color: _N.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You can type quickly and send now, or retry mic.',
                style: TextStyle(color: _N.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                minLines: 1,
                style: const TextStyle(color: _N.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Type message... ',
                  hintStyle: const TextStyle(color: _N.textMuted),
                  filled: true,
                  fillColor: _N.inputBg,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _N.inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _N.indigo),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _handleMicTap();
                      },
                      child: const Text('Retry Mic'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final text = controller.text.trim();
                        Navigator.of(sheetContext).pop();
                        if (text.isEmpty) {
                          return;
                        }
                        await _sendVoiceTranscriptAsMessage(text, currentUser);
                      },
                      child: const Text('Send'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
  }

  String _languageToLocale(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'ta':
        return 'ta_IN';
      case 'hi':
        return 'hi_IN';
      case 'te':
        return 'te_IN';
      case 'kn':
        return 'kn_IN';
      case 'ml':
        return 'ml_IN';
      default:
        return 'en_US';
    }
  }

  Future<void> _toggleAudioPlayback(String path) async {
    try {
      if (_activeAudioPath == path && _isAudioPlaying) {
        await _audioPlayer.pause();
        if (!mounted) return;
        setState(() => _isAudioPlaying = false);
        return;
      }

      if (_activeAudioPath != path) {
        if (path.startsWith('http://') || path.startsWith('https://')) {
          await _audioPlayer.setUrl(path);
        } else {
          await _audioPlayer.setFilePath(path);
        }
      }

      await _audioPlayer.play();
      if (!mounted) return;
      setState(() {
        _activeAudioPath = path;
        _isAudioPlaying = true;
      });
    } catch (e) {
      _showError('Could not play audio: $e');
    }
  }

  void _startVideoCall() => _startCall(CallType.video);
  void _startVoiceCall() => _startCall(CallType.voice);

  void _startCall(CallType callType) {
    final currentUser = ref.read(authProvider).value;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in.')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CallScreen(peerUser: widget.user, callType: callType),
    ));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: _N.textPrimary)),
      backgroundColor: Colors.redAccent.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).value;
    _ensureSocket(currentUser);

    if (currentUser != null && !_historyFetchStarted) {
      _historyFetchStarted = true;
      unawaited(_loadConversation(currentUser.id));
    }

    final conversation = _richMessages
        .where((rm) =>
            (rm.message.senderId == widget.user.id &&
                rm.message.receiverId == currentUser?.id) ||
            (rm.message.senderId == currentUser?.id &&
                rm.message.receiverId == widget.user.id))
        .toList();

    return Scaffold(
      backgroundColor: _N.bg,
      body: Stack(children: [
        _buildBackground(),
        Column(children: [
          _buildAppBar(),
          Expanded(
            child: GestureDetector(
              onTap: () {
                _closeAttachMenu();
                FocusScope.of(context).unfocus();
              },
              child: _isLoadingHistory
                  ? const Center(
                      child: CircularProgressIndicator(color: _N.indigoLight),
                    )
                  : conversation.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: conversation.length,
                          itemBuilder: (ctx, i) {
                            final rm = conversation[i];
                            final isMe = rm.message.senderId == currentUser?.id;
                            final showDate = i == 0 ||
                                !_sameDay(conversation[i - 1].message.timestamp,
                                    rm.message.timestamp);
                            return Column(children: [
                              if (showDate)
                                _buildDateChip(rm.message.timestamp),
                              _buildMessageRow(rm, isMe),
                            ]);
                          },
                        ),
            ),
          ),
          SizeTransition(
            sizeFactor: _attachMenuAnim,
            child: _buildAttachMenu(),
          ),
          _buildInputBar(),
        ]),
      ]),
    );
  }

  // ── Background ────────────────────────────────────────────────────────────

  Widget _buildBackground() => Positioned.fill(
        child: CustomPaint(painter: _WhatsAppWallpaperPainter()),
      );

  // ── AppBar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 12,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: _N.surface.withOpacity(0.95),
        border: const Border(bottom: BorderSide(color: _N.cardBorder)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _N.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _N.cardBorder),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _N.textSecondary, size: 16),
          ),
        ),
        const SizedBox(width: 10),
        _buildAvatar(),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.user.name,
                style: const TextStyle(
                    color: _N.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3)),
            const SizedBox(height: 2),
            Row(children: [
              if (widget.user.isOnline) ...[
                AnimatedBuilder(
                  animation: _onlineGlowCtrl,
                  builder: (_, __) => Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _N.cyan,
                      boxShadow: [
                        BoxShadow(
                          color: _N.cyan
                              .withOpacity(0.5 + _onlineGlowCtrl.value * 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                const Text('Active now',
                    style: TextStyle(
                        color: _N.cyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ] else
                const Text('Offline',
                    style: TextStyle(color: _N.textMuted, fontSize: 11)),
            ]),
          ]),
        ),
        _appBarBtn(Icons.call_outlined, _startVoiceCall),
        const SizedBox(width: 6),
        _appBarBtn(Icons.videocam_outlined, _startVideoCall),
        const SizedBox(width: 6),
        _appBarPopup(),
      ]),
    );
  }

  Widget _buildAvatar() {
    final initials = widget.user.name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return AnimatedBuilder(
      animation: _onlineGlowCtrl,
      builder: (_, __) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [_N.indigo, _N.violet],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: widget.user.isOnline
              ? [
                  BoxShadow(
                    color: _N.indigo
                        .withOpacity(0.3 + _onlineGlowCtrl.value * 0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Center(
          child: Text(initials,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _appBarBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _N.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _N.cardBorder),
          ),
          child: Icon(icon, color: _N.textSecondary, size: 18),
        ),
      );

  Widget _appBarPopup() => PopupMenuButton<String>(
        color: _N.card,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _N.cardBorder),
        ),
        icon: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _N.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _N.cardBorder),
          ),
          child: const Icon(Icons.more_horiz_rounded,
              color: _N.textSecondary, size: 18),
        ),
        itemBuilder: (_) => [
          _popItem(Icons.search_rounded, 'Search'),
          _popItem(Icons.translate_rounded, 'Translate'),
          _popItem(Icons.wallpaper_rounded, 'Wallpaper'),
          _popItem(Icons.notifications_off_outlined, 'Mute'),
          _popItem(Icons.block_rounded, 'Block'),
        ],
      );

  PopupMenuItem<String> _popItem(IconData icon, String label) =>
      PopupMenuItem<String>(
        value: label,
        child: Row(children: [
          Icon(icon, size: 17, color: _N.indigoLight),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(color: _N.textPrimary, fontSize: 13.5)),
        ]),
      );

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(colors: [
                _N.indigo.withOpacity(0.15),
                _N.violet.withOpacity(0.15),
              ]),
              border: Border.all(color: _N.indigo.withOpacity(0.3), width: 1.5),
            ),
            child: const Icon(Icons.forum_outlined,
                size: 40, color: _N.indigoLight),
          ),
          const SizedBox(height: 20),
          Text('Start a conversation',
              style: TextStyle(
                  color: _N.textPrimary.withOpacity(0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Text('Say hello to ${widget.user.name.split(' ').first}!',
              style: const TextStyle(color: _N.textMuted, fontSize: 13)),
        ]),
      );

  // ── Date chip ─────────────────────────────────────────────────────────────

  Widget _buildDateChip(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final label = d == today
        ? 'Today'
        : d == today.subtract(const Duration(days: 1))
            ? 'Yesterday'
            : '${dt.day}/${dt.month}/${dt.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: _N.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _N.cardBorder),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: _N.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  // ── Message row ───────────────────────────────────────────────────────────

  Widget _buildMessageRow(RichMessage rm, bool isMe) {
    final time = '${rm.message.timestamp.hour.toString().padLeft(2, '0')}:'
        '${rm.message.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[_miniAvatar(), const SizedBox(width: 6)],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF005C4B) : const Color(0xFF202C33),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: isMe
                    ? [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2))
                      ]
                    : [],
              ),
              child: _buildBubbleContent(rm, isMe, time),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildBubbleContent(RichMessage rm, bool isMe, String time) {
    switch (rm.message.type) {
      case MessageType.image:
        return _buildImageBubble(rm, isMe, time);
      case MessageType.audio:
        return _buildAudioBubble(rm, isMe, time);
      case MessageType.file:
        return _buildFileBubble(rm, isMe, time);
      case MessageType.location:
        return _buildLocationBubble(rm, isMe, time);
      case MessageType.contact:
        return _buildContactBubble(rm, isMe, time);
      default:
        return _buildTextBubble(rm, isMe, time);
    }
  }

  // ── Text bubble ───────────────────────────────────────────────────────────

  Widget _buildTextBubble(RichMessage rm, bool isMe, String time) {
    final meta = rm.message.metadata ?? const <String, dynamic>{};
    final translated = meta['translatedContent']?.toString();
    final hasTranslation = !isMe &&
        translated != null &&
        translated.isNotEmpty &&
        translated != rm.message.content;

    // Display translated text for receiver if available, otherwise original text
    final displayContent = hasTranslation ? translated : rm.message.content;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(displayContent,
            style: TextStyle(
              color: isMe ? Colors.white : const Color(0xFFE9F0F4),
              fontSize: 14.5,
              height: 1.4,
            )),
        if (hasTranslation) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.translate_rounded,
                  size: 11, color: Colors.tealAccent.shade200),
              const SizedBox(width: 4),
              Flexible(
                child: Text(rm.message.content,
                    style: TextStyle(
                      color: Colors.grey.shade400.withOpacity(0.7),
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                    )),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: _timeRow(isMe, time, rm.message.status),
        ),
      ]),
    );
  }

  // ── Image bubble ──────────────────────────────────────────────────────────

  Widget _buildImageBubble(RichMessage rm, bool isMe, String time) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      if (rm.imagePath != null)
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
          ),
          child: GestureDetector(
            onTap: () => _openImageFullscreen(rm.imagePath!),
            child: Image.file(
              File(rm.imagePath!),
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 120,
                color: _N.card,
                child: const Icon(Icons.broken_image_outlined,
                    color: _N.textMuted, size: 36),
              ),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
        child: _timeRow(isMe, time, rm.message.status),
      ),
    ]);
  }

  Widget _buildAudioBubble(RichMessage rm, bool isMe, String time) {
    final path = rm.audioPath;
    final isPlaying =
        path != null && _isAudioPlaying && _activeAudioPath == path;
    final meta = rm.message.metadata ?? const <String, dynamic>{};
    final translatedText = meta['translatedContent']?.toString();
    final transcript =
        (meta['voiceTranscript'] ?? rm.message.content).toString();
    final displayText =
        !isMe && translatedText != null && translatedText.isNotEmpty
            ? translatedText
            : transcript;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        GestureDetector(
          onTap: path == null ? null : () => _toggleAudioPlayback(path),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _N.indigo.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                path == null
                    ? Icons.graphic_eq_rounded
                    : isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                color: _N.indigoLight,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      path == null ? 'Voice is processing...' : 'Voice message',
                      style: TextStyle(
                        color: isMe ? Colors.white : const Color(0xFFE9F0F4),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (displayText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        displayText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.white70,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ]),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        _timeRow(isMe, time, rm.message.status),
      ]),
    );
  }

  void _openImageFullscreen(String path) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: InteractiveViewer(
            child: Image.file(File(path)),
          ),
        ),
      ),
    ));
  }

  // ── File bubble ───────────────────────────────────────────────────────────

  Widget _buildFileBubble(RichMessage rm, bool isMe, String time) {
    final name = rm.fileName ?? 'Unknown file';
    final size =
        rm.fileSizeBytes != null ? _formatFileSize(rm.fileSizeBytes!) : '';
    final ext =
        name.contains('.') ? name.split('.').last.toUpperCase() : 'FILE';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        GestureDetector(
          onTap: () async {
            if (rm.filePath != null) {
              final uri = Uri.file(rm.filePath!);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            }
          },
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _N.indigo.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _N.indigo.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(ext,
                    style: const TextStyle(
                        color: _N.indigoLight,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color:
                                isMe ? Colors.white : const Color(0xFFE9F0F4),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    if (size.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(size,
                          style: const TextStyle(
                              color: _N.textMuted, fontSize: 11)),
                    ],
                  ]),
            ),
            const SizedBox(width: 6),
            Icon(Icons.download_rounded,
                color: isMe ? Colors.white70 : _N.textMuted, size: 18),
          ]),
        ),
        const SizedBox(height: 6),
        _timeRow(isMe, time, rm.message.status),
      ]),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Location bubble ───────────────────────────────────────────────────────

  Widget _buildLocationBubble(RichMessage rm, bool isMe, String time) {
    final lat = rm.latitude ?? 0.0;
    final lng = rm.longitude ?? 0.0;
    final label = rm.locationLabel ?? '$lat, $lng';

    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      GestureDetector(
        onTap: () async {
          final uri = Uri.parse(
              'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        },
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
          ),
          child: Container(
            height: 130,
            color: const Color(0xFF1A2332),
            child: Stack(fit: StackFit.expand, children: [
              // Map placeholder with pin icon
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFF59E0B).withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        color: Color(0xFFF59E0B), size: 28),
                  ),
                  const SizedBox(height: 6),
                  const Text('Tap to open in Maps',
                      style: TextStyle(color: _N.textMuted, fontSize: 11)),
                ]),
              ),
              // Subtle grid overlay
              CustomPaint(painter: _MapGridPainter()),
            ]),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.location_on_outlined,
                color: Color(0xFFF59E0B), size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: isMe ? Colors.white : const Color(0xFFE9F0F4),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500)),
            ),
          ]),
          const SizedBox(height: 4),
          Align(
              alignment: Alignment.centerRight,
              child: _timeRow(isMe, time, rm.message.status)),
        ]),
      ),
    ]);
  }

  // ── Contact bubble ────────────────────────────────────────────────────────

  Widget _buildContactBubble(RichMessage rm, bool isMe, String time) {
    final name = rm.contactName ?? 'Unknown';
    final phone = rm.contactPhone ?? '';
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)]),
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: TextStyle(
                      color: isMe ? Colors.white : const Color(0xFFE9F0F4),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600)),
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(phone,
                    style: const TextStyle(color: _N.textMuted, fontSize: 12)),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        // Quick actions
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                if (phone.isNotEmpty) {
                  final uri = Uri.parse('tel:$phone');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: _N.indigo.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _N.indigo.withOpacity(0.3)),
                ),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.call_outlined,
                          color: _N.indigoLight, size: 14),
                      SizedBox(width: 4),
                      Text('Call',
                          style:
                              TextStyle(color: _N.indigoLight, fontSize: 12)),
                    ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                if (phone.isNotEmpty) {
                  final uri = Uri.parse('sms:$phone');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.message_outlined,
                          color: Color(0xFF10B981), size: 14),
                      SizedBox(width: 4),
                      Text('SMS',
                          style: TextStyle(
                              color: Color(0xFF10B981), fontSize: 12)),
                    ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        _timeRow(isMe, time, rm.message.status),
      ]),
    );
  }

  // ── Time + status row ─────────────────────────────────────────────────────

  Widget _timeRow(bool isMe, String time, MessageStatus status) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(time,
          style: TextStyle(
            color:
                isMe ? Colors.white.withOpacity(0.65) : const Color(0xFF8696A0),
            fontSize: 10,
          )),
      if (isMe) ...[
        const SizedBox(width: 4),
        _statusIcon(status),
      ],
    ]);
  }

  Widget _miniAvatar() {
    final initials = widget.user.name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: const LinearGradient(colors: [_N.indigo, _N.violet]),
      ),
      child: Center(
        child: Text(initials,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _statusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: Color(0xFFB7D7CE)));
      case MessageStatus.sent:
        return const Icon(Icons.check_rounded,
            size: 13, color: Color(0xFFB7D7CE));
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded,
            size: 13, color: Color(0xFFB7D7CE));
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded, size: 13, color: _N.cyan);
    }
  }

  // ── Attach menu ───────────────────────────────────────────────────────────

  Widget _buildAttachMenu() {
    final options = [
      (Icons.image_outlined, 'Gallery', _N.violet, _pickFromGallery),
      (Icons.insert_drive_file_outlined, 'Document', _N.indigo, _pickDocument),
      (Icons.camera_alt_outlined, 'Camera', _N.cyan, _openCamera),
      (
        Icons.location_on_outlined,
        'Location',
        const Color(0xFFF59E0B),
        _shareLocation
      ),
      (
        Icons.person_outline_rounded,
        'Contact',
        const Color(0xFF10B981),
        _pickContact
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      color: _N.inputBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: options
            .map((o) => GestureDetector(
                  onTap: o.$4,
                  child: Column(children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: o.$3.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: o.$3.withOpacity(0.3)),
                      ),
                      child: Icon(o.$1, color: o.$3, size: 22),
                    ),
                    const SizedBox(height: 6),
                    Text(o.$2,
                        style: const TextStyle(
                            color: _N.textMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500)),
                  ]),
                ))
            .toList(),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: _N.inputBg,
        border: Border(top: BorderSide(color: _N.inputBorder, width: 1)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        GestureDetector(
          onTap: _toggleAttachMenu,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _showAttachMenu ? _N.indigo.withOpacity(0.2) : _N.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _showAttachMenu ? _N.indigo : _N.cardBorder),
            ),
            child: Icon(
              _showAttachMenu ? Icons.close_rounded : Icons.add_rounded,
              color: _showAttachMenu ? _N.indigoLight : _N.textSecondary,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 42, maxHeight: 120),
            decoration: BoxDecoration(
              color: _N.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _N.cardBorder),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: _N.textPrimary, fontSize: 14.5),
                  cursorColor: _N.indigoLight,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Write a message…',
                    hintStyle: TextStyle(color: _N.textMuted, fontSize: 14.5),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(14, 11, 4, 11),
                    isDense: true,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 6),
                child: GestureDetector(
                  onTap: () {
                    final text = _messageController.text;
                    final sel = _messageController.selection;
                    final at = sel.isValid ? sel.start : text.length;
                    final updated = text.replaceRange(at, at, ' 😊');
                    _messageController.value = TextEditingValue(
                      text: updated,
                      selection:
                          TextSelection.collapsed(offset: updated.length),
                    );
                  },
                  child: const Icon(Icons.emoji_emotions_outlined,
                      color: _N.textMuted, size: 20),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _isTyping ? _sendMessage : _handleMicTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: _isTyping
                  ? const LinearGradient(
                      colors: [_N.indigo, _N.violet],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight)
                  : null,
              color: _isTyping ? null : _N.card,
              border: _isTyping ? null : Border.all(color: _N.cardBorder),
              boxShadow: _isTyping
                  ? [
                      BoxShadow(
                          color: _N.indigo.withOpacity(0.5),
                          blurRadius: 14,
                          offset: const Offset(0, 4))
                    ]
                  : [],
            ),
            child: Icon(
              _isTyping
                  ? Icons.send_rounded
                  : (_isRecording
                      ? Icons.stop_rounded
                      : Icons.mic_none_rounded),
              color: _isTyping ? Colors.white : _N.textSecondary,
              size: 20,
            ),
          ),
        ),
      ]),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Map grid painter (location thumbnail decoration) ──────────────────────────
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF22D3EE).withOpacity(0.06)
      ..strokeWidth = 0.8;
    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_MapGridPainter old) => false;
}

// ── WhatsApp-style wallpaper painter ──────────────────────────────────────────
class _WhatsAppWallpaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0B141A),
    );

    final topGlow = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFF1F5D4B).withOpacity(0.34),
        const Color(0xFF0B141A).withOpacity(0.0),
      ]).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.84, size.height * 0.12),
        radius: size.shortestSide * 0.8,
      ));

    final bottomGlow = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFF123B31).withOpacity(0.28),
        const Color(0xFF0B141A).withOpacity(0.0),
      ]).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.1, size.height * 0.92),
        radius: size.shortestSide * 0.85,
      ));

    canvas.drawRect(Offset.zero & size, topGlow);
    canvas.drawRect(Offset.zero & size, bottomGlow);

    const spacing = 92.0;
    final doodlePaint = Paint()
      ..color = const Color(0xFFB7D7CE).withOpacity(0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    for (double y = -spacing; y < size.height + spacing; y += spacing) {
      for (double x = -spacing; x < size.width + spacing; x += spacing) {
        final offset = Offset(x, y);
        canvas.drawCircle(offset, 6, doodlePaint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: offset, width: 18, height: 12),
            const Radius.circular(4),
          ),
          doodlePaint,
        );
        canvas.drawLine(
          offset + const Offset(-10, 10),
          offset + const Offset(10, -10),
          doodlePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WhatsAppWallpaperPainter old) => false;
}
