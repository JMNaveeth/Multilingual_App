import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:multilingual_chat_app/services/auth_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class IncomingCall {
  final String fromUserId;
  final String fromName;
  final String callType;
  final Map<String, dynamic> signalData;

  const IncomingCall({
    required this.fromUserId,
    required this.fromName,
    required this.callType,
    required this.signalData,
  });

  factory IncomingCall.fromJson(Map<String, dynamic> json) {
    return IncomingCall(
      fromUserId: json['from']?.toString() ?? '',
      fromName: json['name']?.toString() ?? 'Unknown',
      callType: json['signal'] is Map<String, dynamic>
          ? (json['signal']['callType']?.toString() ?? 'voice')
          : 'voice',
      signalData: json['signal'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['signal'] as Map)
          : <String, dynamic>{},
    );
  }
}

class CallSocketService {
  CallSocketService._();

  static final CallSocketService instance = CallSocketService._();

  io.Socket? _socket;
  String? _connectedUserId;
  bool _connecting = false;

  final StreamController<IncomingCall> _incomingCallController =
      StreamController<IncomingCall>.broadcast();
  final StreamController<Map<String, dynamic>> _callAcceptedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _callEndedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _offerController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _answerController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _candidateController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Translation StreamControllers
  final StreamController<Map<String, dynamic>> _translationStartedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _receiveSubtitleController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _receiveTranslatedAudioController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Chat StreamControllers
  final StreamController<Map<String, dynamic>> _newMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<IncomingCall> get incomingCalls => _incomingCallController.stream;
  Stream<Map<String, dynamic>> get callAccepted =>
      _callAcceptedController.stream;
  Stream<Map<String, dynamic>> get callEnded => _callEndedController.stream;
  Stream<Map<String, dynamic>> get offers => _offerController.stream;
  Stream<Map<String, dynamic>> get answers => _answerController.stream;
  Stream<Map<String, dynamic>> get candidates => _candidateController.stream;

  // Translation Streams
  Stream<Map<String, dynamic>> get translationStarted => _translationStartedController.stream;
  Stream<Map<String, dynamic>> get receiveSubtitle => _receiveSubtitleController.stream;
  Stream<Map<String, dynamic>> get receiveTranslatedAudio => _receiveTranslatedAudioController.stream;

  // Chat Streams
  Stream<Map<String, dynamic>> get newMessages => _newMessageController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect({required String userId}) async {
    if (_socket?.connected == true && _connectedUserId == userId) {
      return;
    }

    if (_connecting) {
      return;
    }

    _connecting = true;
    try {
      await disconnect();

      final serverUrl = AuthService.baseUrl.replaceFirst(RegExp(r'/api$'), '');
      _socket = io.io(
        serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .build(),
      );

      _socket!.onConnect((_) {
        _connectedUserId = userId;
        _socket!.emit('authenticate', {'token': userId});
      });

      _socket!.onDisconnect((_) {
        if (kDebugMode) {
          debugPrint('Socket disconnected');
        }
      });

      _socket!.on('authenticated', (data) {
        if (kDebugMode) {
          debugPrint('Socket authenticated: $data');
        }
      });

      _socket!.on('unauthenticated', (data) {
        if (kDebugMode) {
          debugPrint('Socket unauthenticated: $data');
        }
      });

      _socket!.on('call_user', (data) {
        if (data is Map<String, dynamic>) {
          _incomingCallController.add(IncomingCall.fromJson(data));
        } else if (data is Map) {
          _incomingCallController.add(
            IncomingCall.fromJson(Map<String, dynamic>.from(data)),
          );
        }
      });

      _socket!.on('call_accepted', (signal) {
        _callAcceptedController.add({
          'signal': signal,
        });
      });

      _socket!.on('call_ended', (data) {
        final payload = data is Map<String, dynamic>
            ? data
            : data is Map
                ? Map<String, dynamic>.from(data)
                : <String, dynamic>{};
        _callEndedController.add(payload);
      });

      _socket!.on('webrtc_offer', (data) {
        final payload = data is Map<String, dynamic>
            ? data
            : data is Map
                ? Map<String, dynamic>.from(data)
                : <String, dynamic>{};
        _offerController.add(payload);
      });

      _socket!.on('webrtc_answer', (data) {
        final payload = data is Map<String, dynamic>
            ? data
            : data is Map
                ? Map<String, dynamic>.from(data)
                : <String, dynamic>{};
        _answerController.add(payload);
      });

      _socket!.on('webrtc_ice_candidate', (data) {
        final payload = data is Map<String, dynamic>
            ? data
            : data is Map
                ? Map<String, dynamic>.from(data)
                : <String, dynamic>{};
        _candidateController.add(payload);
      });

      // AI Translation Listeners
      _socket!.on('translation_started', (data) {
        final payload = data is Map<String, dynamic>
            ? data
            : data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        _translationStartedController.add(payload);
      });

      _socket!.on('receive_subtitle', (data) {
        final payload = data is Map<String, dynamic>
            ? data
            : data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        _receiveSubtitleController.add(payload);
      });

      _socket!.on('receive_translated_audio', (data) {
        final payload = data is Map<String, dynamic>
            ? data
            : data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        _receiveTranslatedAudioController.add(payload);
      });

      // Real-time Chat Listeners
      _socket!.on('new_message', (data) {
        final payload = data is Map<String, dynamic>
            ? data
            : data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        _newMessageController.add(payload);
      });

      _socket!.connect();
    } finally {
      _connecting = false;
    }
  }

  void callUser({
    required String userToCall,
    required String from,
    required String name,
    required String callType,
  }) {
    _socket?.emit('call_user', {
      'userToCall': userToCall,
      'signalData': {
        'callType': callType,
        'state': 'ringing',
      },
      'from': from,
      'name': name,
    });
  }

  void answerCall({
    required String to,
    required String callType,
  }) {
    _socket?.emit('answer_call', {
      'to': to,
      'signal': {
        'callType': callType,
        'state': 'accepted',
      },
    });
  }

  void endCall({
    required String to,
  }) {
    _socket?.emit('end_call', {
      'to': to,
    });
  }

  void sendOffer({
    required String to,
    required dynamic offer,
    required String callType,
  }) {
    _socket?.emit('webrtc_offer', {
      'to': to,
      'offer': offer,
      'callType': callType,
    });
  }

  void sendAnswer({
    required String to,
    required dynamic answer,
    required String callType,
  }) {
    _socket?.emit('webrtc_answer', {
      'to': to,
      'answer': answer,
      'callType': callType,
    });
  }

  void sendIceCandidate({
    required String to,
    required dynamic candidate,
  }) {
    _socket?.emit('webrtc_ice_candidate', {
      'to': to,
      'candidate': candidate,
    });
  }

  // --- AI Translation Emitters ---

  void startTranslation({
    required String targetUserId,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    _socket?.emit('start_translation', {
      'targetUserId': targetUserId,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
    });
  }

  void sendTranslationAudio({
    required String targetUserId,
    required List<int> audioData,
  }) {
    _socket?.emit('translation_audio', {
      'targetUserId': targetUserId,
      'audioData': audioData,
    });
  }

  void sendCallText({
    required String targetUserId,
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    _socket?.emit('send_call_text', {
      'targetUserId': targetUserId,
      'text': text,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
    });
  }

  // --- Real-time Chat Emitters ---
  
  void sendMessageViaSocket({
    required String receiverId,
    required String content,
    String type = 'text',
    String? mediaUrl,
    String senderLanguage = 'en',
    Map<String, dynamic>? metadata,
  }) {
    _socket?.emit('send_message', {
      'receiverId': receiverId,
      'content': content,
      'type': type,
      'mediaUrl': mediaUrl,
      'senderLanguage': senderLanguage,
      'metadata': metadata ?? {},
    });
  }

  Future<void> disconnect() async {
    _connectedUserId = null;
    _socket?.dispose();
    _socket = null;
  }
}
