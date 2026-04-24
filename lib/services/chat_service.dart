import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:multilingual_chat_app/models/message.dart';
import 'package:multilingual_chat_app/services/auth_service.dart';

class ChatService {
  ChatService({AuthService? authService})
      : _authService = authService ?? AuthService();

  static const String _localMessagesKey = 'local_messages_v1';
  static const int _defaultLimit = 100;

  final AuthService _authService;

  Future<List<Message>> getConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    if (!await _canUseBackend()) {
      return _getLocalConversation(currentUserId, otherUserId);
    }

    try {
      final token = await _authService.getToken();
      final uri = Uri.parse(
        '${AuthService.baseUrl}/chat/conversations/$otherUserId?limit=$_defaultLimit',
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _getLocalConversation(currentUserId, otherUserId);
      }

      final decoded = jsonDecode(response.body);
      final rawMessages = (decoded is Map<String, dynamic>)
          ? ((decoded['data'] is Map<String, dynamic>)
              ? ((decoded['data']['messages'] as List?) ?? const [])
              : const [])
          : const [];

      final messages = rawMessages
          .whereType<Map>()
          .map((e) => Message.fromJson(e.map(
                (k, v) => MapEntry(k.toString(), v),
              )))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      await _upsertLocalMessages(messages);
      return messages;
    } catch (_) {
      return _getLocalConversation(currentUserId, otherUserId);
    }
  }

  Future<Message> sendMessage(Message message) async {
    if (!await _canUseBackend()) {
      await _saveLocalMessage(message);
      return message;
    }

    try {
      final token = await _authService.getToken();
      final uri = Uri.parse('${AuthService.baseUrl}/chat/messages');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'receiverId': message.receiverId,
          'content': message.content,
          'type': message.type.name,
          'mediaUrl': message.mediaUrl,
          'metadata': message.metadata ?? const <String, dynamic>{},
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _saveLocalMessage(message);
        return message;
      }

      final decoded = jsonDecode(response.body);
      final messageJson = (decoded is Map<String, dynamic>)
          ? ((decoded['data'] is Map<String, dynamic>)
              ? (decoded['data']['message'] as Map?)
              : null)
          : null;

      if (messageJson == null) {
        await _saveLocalMessage(message);
        return message;
      }

      final persisted = Message.fromJson(
        messageJson.map((k, v) => MapEntry(k.toString(), v)),
      );
      await _saveLocalMessage(persisted);
      return persisted;
    } catch (_) {
      await _saveLocalMessage(message);
      return message;
    }
  }

  Future<bool> _canUseBackend() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) return false;
    return !token.startsWith('local-token-');
  }

  Future<List<Message>> _getLocalConversation(
    String currentUserId,
    String otherUserId,
  ) async {
    final all = await _readLocalMessages();
    return all
        .where((m) =>
            (m.senderId == currentUserId && m.receiverId == otherUserId) ||
            (m.senderId == otherUserId && m.receiverId == currentUserId))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<List<Message>> _readLocalMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localMessagesKey);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map(
            (e) => Message.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
        .toList();
  }

  Future<void> _saveLocalMessage(Message message) async {
    final all = await _readLocalMessages();
    final existingIndex = all.indexWhere((m) => m.id == message.id);
    if (existingIndex >= 0) {
      all[existingIndex] = message;
    } else {
      all.add(message);
    }
    all.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localMessagesKey,
      jsonEncode(all.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> _upsertLocalMessages(List<Message> messages) async {
    if (messages.isEmpty) return;
    final all = await _readLocalMessages();
    final byId = {for (final m in all) m.id: m};
    for (final message in messages) {
      byId[message.id] = message;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localMessagesKey,
      jsonEncode(merged.map((m) => m.toJson()).toList()),
    );
  }
}
