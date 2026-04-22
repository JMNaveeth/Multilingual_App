import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:multilingual_chat_app/models/user.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';
import 'package:multilingual_chat_app/services/call_socket_service.dart';
import 'package:multilingual_chat_app/services/webrtc_call_service.dart';

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

  bool _dialing = true;
  bool _connected = false;
  bool _muted = false;
  bool _cameraEnabled = true;
  bool _ending = false;

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
    _webRtcService?.close();
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
  }

  Future<void> _toggleCamera() async {
    await _webRtcService?.toggleCamera();
    if (mounted) {
      setState(() {
        _cameraEnabled = !_cameraEnabled;
      });
    }
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
                          if (_isVideoCall) const SizedBox(width: 16),
                          _callButton(
                            icon: Icons.call_end_rounded,
                            color: const Color(0xFFE23B4F),
                            onTap: _endCall,
                            large: true,
                          ),
                        ],
                      ),
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
