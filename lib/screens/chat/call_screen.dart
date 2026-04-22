import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/models/user.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';
import 'package:multilingual_chat_app/services/call_socket_service.dart';

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
  final CallSocketService _callService = CallSocketService.instance;
  StreamSubscription<Map<String, dynamic>>? _acceptedSub;
  StreamSubscription<Map<String, dynamic>>? _endedSub;

  bool _connected = false;
  bool _dialing = true;

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

    await _callService.connect(userId: currentUser.id);

    _acceptedSub = _callService.callAccepted.listen((_) {
      if (!mounted) return;
      setState(() {
        _connected = true;
        _dialing = false;
      });
    });

    _endedSub = _callService.callEnded.listen((_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Call ended.')),
      );
    });

    if (!widget.isIncoming) {
      _callService.callUser(
        userToCall: widget.peerUser.id,
        from: currentUser.id,
        name: currentUser.name,
        callType: widget.callType.name,
      );
    } else {
      setState(() {
        _connected = true;
        _dialing = false;
      });
    }
  }

  Future<void> _endCall() async {
    final currentUser = ref.read(authProvider).value;
    if (currentUser != null) {
      _callService.endCall(to: widget.peerUser.id);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final callLabel =
        widget.callType == CallType.video ? 'Video call' : 'Voice call';

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
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _endCall,
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
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
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7A52F4), Color(0xFF5DC6FF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7A52F4).withOpacity(0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  widget.callType == CallType.video
                      ? Icons.videocam_rounded
                      : Icons.call_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                _connected
                    ? 'Connected'
                    : (_dialing ? 'Connecting...' : 'Incoming call'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _connected
                    ? 'You can now continue the call session.'
                    : 'Waiting for the other person to answer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.68),
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _actionButton(Icons.call_end_rounded,
                        const Color(0xFFE23B4F), _endCall),
                    const SizedBox(width: 16),
                    _actionButton(
                      widget.callType == CallType.video
                          ? Icons.videocam_rounded
                          : Icons.mic_rounded,
                      const Color(0xFF2B2D55),
                      () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
