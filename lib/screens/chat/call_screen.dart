import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:multilingual_chat_app/models/user.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';
import 'package:multilingual_chat_app/services/call_socket_service.dart';
import 'package:multilingual_chat_app/services/webrtc_call_service.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

enum CallType { voice, video }

class CallScreen extends ConsumerStatefulWidget {
  final User peerUser;
  final CallType callType;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.peerUser,
    required this.callType,
    this.isIncoming = false,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final CallSocketService _callSocket = CallSocketService.instance;

  WebRtcCallService? _webRtcService;
  StreamSubscription<Map<String, dynamic>>? _acceptedSub;
  StreamSubscription<Map<String, dynamic>>? _endedSub;
  StreamSubscription<Map<String, dynamic>>? _offerSub;
  StreamSubscription<Map<String, dynamic>>? _answerSub;
  StreamSubscription<Map<String, dynamic>>? _candidateSub;
  StreamSubscription<Map<String, dynamic>>? _subtitleSub;
  StreamSubscription<Map<String, dynamic>>? _audioSub;
  StreamSubscription<Map<String, dynamic>>? _translationStartedSub;
  StreamSubscription<Map<String, dynamic>>? _callTextSentSub;

  bool _dialing = true;
  bool _connected = false;
  bool _muted = false;
  bool _cameraEnabled = true;
  bool _ending = false;

  bool _translationEnabled = false;
  String? _currentSubtitle;
  String? _translationBanner;
  int? _lastLatencyMs;
  Timer? _mockAudioStreamTimer;
  Timer? _speechRestartTimer;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _messageController = TextEditingController();
  final SpeechToText _speechToText = SpeechToText();

  bool _speechReady = false;
  bool _isSpeechListening = false;
  String _lastInterimTranscript = '';
  DateTime _lastSpeechSentAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _isVideoCall => widget.callType == CallType.video;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCallFlow();
    });
  }

  @override
  void dispose() {
    _acceptedSub?.cancel();
    _endedSub?.cancel();
    _offerSub?.cancel();
    _answerSub?.cancel();
    _candidateSub?.cancel();
    _subtitleSub?.cancel();
    _audioSub?.cancel();
    _translationStartedSub?.cancel();
    _callTextSentSub?.cancel();
    _mockAudioStreamTimer?.cancel();
    _speechRestartTimer?.cancel();
    _stopSpeechRecognition();
    _webRtcService?.close();
    _audioPlayer.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _startCallFlow() async {
    final currentUser = ref.read(authProvider).value;
    if (currentUser == null) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to start a call.')),
        );
      }
      return;
    }

    await _callSocket.connect(userId: currentUser.id);
    await _initializeSpeechRecognition();

    _webRtcService = WebRtcCallService(
      isVideoCall: _isVideoCall,
      onLocalCandidate: (candidate) async {
        _callSocket.sendIceCandidate(
          to: widget.peerUser.id,
          candidate: candidate,
        );
      },
    );

    await _webRtcService!.initialize();

    _acceptedSub = _callSocket.callAccepted.listen((_) async {
      if (!mounted || _webRtcService == null) {
        return;
      }

      final offer = await _webRtcService!.createOffer();
      _callSocket.sendOffer(
        to: widget.peerUser.id,
        offer: {
          'type': offer.type,
          'sdp': offer.sdp,
        },
        callType: widget.callType.name,
      );

      if (mounted) {
        setState(() {
          _dialing = false;
        });
      }
    });

    _offerSub = _callSocket.offers.listen((payload) async {
      if (!mounted || _webRtcService == null) {
        return;
      }

      if (payload['from']?.toString() != widget.peerUser.id) {
        return;
      }

      final offerData = payload['offer'];
      if (offerData is! Map) {
        return;
      }

      await _webRtcService!.setRemoteDescription(
        Map<String, dynamic>.from(offerData),
      );
      final answer = await _webRtcService!.createAnswer();
      _callSocket.sendAnswer(
        to: widget.peerUser.id,
        answer: {
          'type': answer.type,
          'sdp': answer.sdp,
        },
        callType: widget.callType.name,
      );

      if (mounted) {
        setState(() {
          _connected = true;
          _dialing = false;
        });
      }
      _maybeStartSpeechRecognition();
    });

    _answerSub = _callSocket.answers.listen((payload) async {
      if (!mounted || _webRtcService == null) {
        return;
      }

      if (payload['from']?.toString() != widget.peerUser.id) {
        return;
      }

      final answerData = payload['answer'];
      if (answerData is! Map) {
        return;
      }

      await _webRtcService!.setRemoteDescription(
        Map<String, dynamic>.from(answerData),
      );

      if (mounted) {
        setState(() {
          _connected = true;
          _dialing = false;
        });
      }
      _maybeStartSpeechRecognition();
    });

    _candidateSub = _callSocket.candidates.listen((payload) async {
      if (!mounted || _webRtcService == null) {
        return;
      }

      if (payload['from']?.toString() != widget.peerUser.id) {
        return;
      }

      final candidateData = payload['candidate'];
      if (candidateData is! Map) {
        return;
      }

      await _webRtcService!.addCandidate(
        Map<String, dynamic>.from(candidateData),
      );
    });

    _endedSub = _callSocket.callEnded.listen((payload) {
      if (!mounted) {
        return;
      }
      _finishCall(showSnack: true);
    });

    _subtitleSub = _callSocket.receiveSubtitle.listen((payload) {
      if (!mounted) return;
      final latency = payload['latencyMs'];
      setState(() {
        _currentSubtitle = payload['text']?.toString();
        _lastLatencyMs = latency is num ? latency.toInt() : _lastLatencyMs;
      });
      // Clear subtitle after 4 seconds
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _currentSubtitle == payload['text']?.toString()) {
          setState(() {
            _currentSubtitle = null;
          });
        }
      });
    });

    _audioSub = _callSocket.receiveTranslatedAudio.listen((payload) async {
      if (!mounted) return;
      final audioData = payload['audioData'];
      // The backend sends a Buffer which comes through Socket.io as a List of ints
      if (audioData != null && audioData is List) {
        try {
          final bytes = List<int>.from(audioData);
          await _audioPlayer.setAudioSource(_MyCustomSource(bytes));
          _audioPlayer.play();
        } catch (e) {
          debugPrint('Error playing translated audio: $e');
        }
      }
    });

    _translationStartedSub = _callSocket.translationStarted.listen((payload) {
      if (!mounted) return;
      final sourceLanguage = payload['sourceLanguage']?.toString() ?? 'en';
      final targetLanguage = payload['targetLanguage']?.toString() ?? 'ta';
      setState(() {
        _translationEnabled = true;
        _translationBanner = 'Live AI translation: $sourceLanguage -> $targetLanguage';
      });
    });

    _callTextSentSub = _callSocket.callTextSent.listen((payload) {
      if (!mounted) return;
      final latency = payload['latencyMs'];
      if (latency is num) {
        setState(() {
          _lastLatencyMs = latency.toInt();
        });
      }
    });

    if (!widget.isIncoming) {
      _callSocket.callUser(
        userToCall: widget.peerUser.id,
        from: currentUser.id,
        name: currentUser.name,
        callType: widget.callType.name,
      );
    } else {
      if (mounted) {
        setState(() {
          _dialing = false;
        });
      }
    }
  }

  Future<void> _finishCall({required bool showSnack}) async {
    if (_ending) {
      return;
    }

    _ending = true;
    _stopSpeechRecognition();
    await _webRtcService?.close();
    _webRtcService = null;

    if (mounted) {
      Navigator.of(context).pop();
      if (showSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call ended.')),
        );
      }
    }
  }

  Future<void> _endCall() async {
    _callSocket.endCall(to: widget.peerUser.id);
    await _finishCall(showSnack: false);
  }

  Future<void> _toggleMic() async {
    await _webRtcService?.toggleMic();
    if (mounted) {
      setState(() {
        _muted = !_muted;
      });
    }
    if (_muted) {
      _stopSpeechRecognition();
    } else {
      _maybeStartSpeechRecognition();
    }
  }

  Future<void> _toggleCamera() async {
    await _webRtcService?.toggleCamera();
    if (mounted) {
      setState(() {
        _cameraEnabled = !_cameraEnabled;
      });
    }
  }

  void _toggleTranslation() {
    final currentUser = ref.read(authProvider).value;
    final myLanguage = currentUser?.preferredLanguage ?? 'en';
    final peerLanguage = widget.peerUser.preferredLanguage;

    setState(() {
      _translationEnabled = !_translationEnabled;
      if (_translationEnabled) {
        _translationBanner = 'Live AI translation: $myLanguage -> $peerLanguage';
        _callSocket.startTranslation(
          targetUserId: widget.peerUser.id,
          sourceLanguage: myLanguage,
          targetLanguage: peerLanguage,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Translation Enabled ($myLanguage → $peerLanguage)')),
        );
        _maybeStartSpeechRecognition();
      } else {
        _mockAudioStreamTimer?.cancel();
        _currentSubtitle = null;
        _translationBanner = null;
        _lastLatencyMs = null;
        _stopSpeechRecognition();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI Translation Disabled')),
        );
      }
    });
  }

  Future<void> _initializeSpeechRecognition() async {
    if (_speechReady) {
      return;
    }
    try {
      _speechReady = await _speechToText.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
      );
    } catch (_) {
      _speechReady = false;
    }
  }

  void _onSpeechStatus(String status) {
    final listening = status == 'listening';
    if (mounted && _isSpeechListening != listening) {
      setState(() {
        _isSpeechListening = listening;
      });
    }
    if (!listening && _shouldKeepListening()) {
      _scheduleSpeechRestart();
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (_shouldKeepListening()) {
      _scheduleSpeechRestart();
    }
  }

  bool _shouldKeepListening() {
    return mounted && _translationEnabled && _connected && !_muted;
  }

  Future<void> _maybeStartSpeechRecognition() async {
    if (!_shouldKeepListening()) {
      return;
    }
    if (!_speechReady) {
      await _initializeSpeechRecognition();
    }
    if (!_speechReady || _speechToText.isListening) {
      return;
    }

    final currentUser = ref.read(authProvider).value;
    final localeId = _languageToLocale(currentUser?.preferredLanguage ?? 'en');

    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        localeId: localeId,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
        ),
        listenFor: const Duration(seconds: 50),
        pauseFor: const Duration(seconds: 3),
      );
      if (mounted) {
        setState(() {
          _isSpeechListening = true;
          _translationBanner ??= 'Live AI translation running (on-device speech)';
        });
      }
    } catch (_) {
      _scheduleSpeechRestart();
    }
  }

  void _scheduleSpeechRestart() {
    _speechRestartTimer?.cancel();
    _speechRestartTimer = Timer(const Duration(milliseconds: 450), () {
      _maybeStartSpeechRecognition();
    });
  }

  Future<void> _stopSpeechRecognition() async {
    _speechRestartTimer?.cancel();
    _lastInterimTranscript = '';
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
    if (mounted && _isSpeechListening) {
      setState(() {
        _isSpeechListening = false;
      });
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!_translationEnabled || !_connected || _muted) {
      return;
    }
    final fullText = result.recognizedWords.trim();
    if (fullText.isEmpty) {
      return;
    }

    String deltaText = fullText;
    if (_lastInterimTranscript.isNotEmpty &&
        fullText.startsWith(_lastInterimTranscript)) {
      deltaText = fullText.substring(_lastInterimTranscript.length).trim();
    }

    final now = DateTime.now();
    final msSinceLast = now.difference(_lastSpeechSentAt).inMilliseconds;
    final shouldSend = result.finalResult || deltaText.length >= 18 || msSinceLast >= 1300;

    if (shouldSend && deltaText.isNotEmpty) {
      _sendLiveSpeechText(deltaText);
      _lastSpeechSentAt = now;
    }

    _lastInterimTranscript = result.finalResult ? '' : fullText;
  }

  void _sendLiveSpeechText(String text) {
    final currentUser = ref.read(authProvider).value;
    final myLanguage = currentUser?.preferredLanguage ?? 'en';
    final peerLanguage = widget.peerUser.preferredLanguage;
    _callSocket.sendCallText(
      targetUserId: widget.peerUser.id,
      text: text,
      sourceLanguage: myLanguage,
      targetLanguage: peerLanguage,
    );
  }

  String _languageToLocale(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'ta':
        return 'ta_IN';
      case 'en':
        return 'en_US';
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

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUser = ref.read(authProvider).value;
    final myLanguage = currentUser?.preferredLanguage ?? 'en';
    final peerLanguage = widget.peerUser.preferredLanguage;

    // Send text to backend for real translation + TTS
    _callSocket.sendCallText(
      targetUserId: widget.peerUser.id,
      text: text,
      sourceLanguage: myLanguage,
      targetLanguage: peerLanguage,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Translating: "$text" → $peerLanguage'),
        duration: const Duration(seconds: 1),
      ),
    );
    _messageController.clear();
  }

  String get _statusText {
    if (_connected) {
      return 'Connected';
    }
    if (_dialing) {
      return widget.isIncoming ? 'Waiting for answer...' : 'Calling...';
    }
    return 'Connecting...';
  }

  @override
  Widget build(BuildContext context) {
    final callLabel = _isVideoCall ? 'Video call' : 'Voice call';
    final localRenderer = _webRtcService?.localRenderer;
    final remoteRenderer = _webRtcService?.remoteRenderer;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E1A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0E1A), Color(0xFF171831), Color(0xFF0D0E1A)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              if (_isVideoCall && remoteRenderer?.srcObject != null)
                Positioned.fill(
                  child: RTCVideoView(
                    remoteRenderer!,
                    mirror: false,
                  ),
                )
              else
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-0.2, -0.3),
                        radius: 1.3,
                        colors: [Color(0xFF1A1B33), Color(0xFF0D0E1A)],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7A52F4), Color(0xFF5DC6FF)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7A52F4).withOpacity(0.28),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isVideoCall
                              ? Icons.videocam_rounded
                              : Icons.call_rounded,
                          color: Colors.white,
                          size: 54,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_isVideoCall && localRenderer?.srcObject != null)
                Positioned(
                  right: 16,
                  top: 16,
                  width: 110,
                  height: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: RTCVideoView(
                        localRenderer!,
                        mirror: true,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _endCall,
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.peerUser.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              callLabel,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          _statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Subtitle Overlay
              if (_currentSubtitle != null)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 220,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF7A52F4).withOpacity(0.5)),
                      ),
                      child: Text(
                        _currentSubtitle!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

              if (_translationEnabled)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 270,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1D39).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF7A52F4).withOpacity(0.55),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFFB9A6FF),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isSpeechListening
                                ? '${_translationBanner ?? 'Live AI translation enabled'} | Listening'
                                : '${_translationBanner ?? 'Live AI translation enabled'} | Waiting mic',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_lastLatencyMs != null)
                          Text(
                            '${_lastLatencyMs}ms',
                            style: const TextStyle(
                              color: Color(0xFF8EF7B5),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF0D0E1A).withOpacity(0.65),
                        const Color(0xFF0D0E1A),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _connected
                            ? 'Call connected'
                            : (_dialing
                                ? 'Waiting for the other person...'
                                : 'Connecting call...'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _connected
                            ? 'Your media stream is now live.'
                            : 'The call will connect as soon as the other side answers.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.68),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _callButton(
                            icon: _muted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                            color: const Color(0xFF2B2D55),
                            onTap: _toggleMic,
                          ),
                          const SizedBox(width: 16),
                          if (_isVideoCall)
                            _callButton(
                              icon: _cameraEnabled
                                  ? Icons.videocam_rounded
                                  : Icons.videocam_off_rounded,
                              color: const Color(0xFF2B2D55),
                              onTap: _toggleCamera,
                            ),
                          const SizedBox(width: 16),
                          _callButton(
                            icon: _translationEnabled
                                ? Icons.translate_rounded
                                : Icons.g_translate_rounded,
                            color: _translationEnabled
                                ? const Color(0xFF7A52F4)
                                : const Color(0xFF2B2D55),
                            onTap: _toggleTranslation,
                          ),
                          const SizedBox(width: 16),
                          _callButton(
                            icon: Icons.call_end_rounded,
                            color: const Color(0xFFE23B4F),
                            onTap: _endCall,
                            large: true,
                          ),
                        ],
                      ),
                      
                      // Message Input (Only visible when translation is enabled)
                      if (_translationEnabled) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: TextField(
                                  controller: _messageController,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Type a message to translate...',
                                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _sendMessage,
                              child: Container(
                                width: 45,
                                height: 45,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF7A52F4),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _callButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool large = false,
  }) {
    final size = large ? 68.0 : 58.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.32),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: large ? 30 : 24),
      ),
    );
  }
}

// Custom Audio Source for playing raw byte stream from socket
class _MyCustomSource extends StreamAudioSource {
  final List<int> bytes;
  _MyCustomSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
