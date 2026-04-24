import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:multilingual_chat_app/models/message.dart';
import 'package:multilingual_chat_app/services/auth_service.dart';

class ChatService {
  ChatService({AuthService? authService})
      : _authService = authService ?? AuthService();

  static const String _localMessagesKey = 'local_messages_v1';
  static const String _localMessagesMigratedKey = 'local_messages_migrated_v2';

  final AuthService _authService;

  Future<List<Message>> getConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    await migrateLegacyLocalMessages(
      currentUserId: currentUserId,
      knownPeerIds: [otherUserId],
    );

    return _getLocalConversation(currentUserId, otherUserId);
  }

  Future<Message> sendMessage(Message message) async {
    await _saveLocalMessage(message);
    return message;
  }

  Future<void> migrateLegacyLocalMessages({
    required String currentUserId,
    List<String> knownPeerIds = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_localMessagesMigratedKey) == true) return;

    final raw = prefs.getString(_localMessagesKey);
    if (raw == null || raw.isEmpty) {
      await prefs.setBool(_localMessagesMigratedKey, true);
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      await prefs.setBool(_localMessagesMigratedKey, true);
      return;
    }

    final peerCandidates = knownPeerIds.where((id) => id.isNotEmpty).toList();
    final repaired = <Map<String, dynamic>>[];

    String? firstPeerFrom(Map<String, dynamic> map) {
      for (final key in ['receiverId', 'receiver', 'senderId', 'sender']) {
        final value = map[key];
        if (value is String &&
            value.isNotEmpty &&
            value != 'current_user' &&
            value != currentUserId) {
          return value;
        }
        if (value is Map) {
          final nested = value.map((k, v) => MapEntry(k.toString(), v));
          final nestedId =
              (nested['_id'] ?? nested['id'] ?? '').toString().trim();
          if (nestedId.isNotEmpty &&
              nestedId != 'current_user' &&
              nestedId != currentUserId) {
            return nestedId;
          }
        }
      }
      if (peerCandidates.isNotEmpty) return peerCandidates.first;
      return null;
    }

    for (var i = 0; i < decoded.length; i++) {
      final row = decoded[i];
      if (row is! Map) continue;
      final map = row.map((k, v) => MapEntry(k.toString(), v));

      final idRaw = (map['id'] ?? map['_id'] ?? '').toString().trim();
      final senderRaw = (map['senderId'] ?? '').toString().trim();
      final receiverRaw = (map['receiverId'] ?? '').toString().trim();
      final timestampRaw =
          (map['timestamp'] ?? map['createdAt'] ?? '').toString();
      final timestamp = DateTime.tryParse(timestampRaw) ?? DateTime.now();

      final peerId = firstPeerFrom(map);

      String senderId = senderRaw;
      String receiverId = receiverRaw;

      if (senderId.isEmpty ||
          senderId == 'current_user' ||
          senderId == 'null') {
        senderId = currentUserId;
      }
      if (receiverId.isEmpty ||
          receiverId == 'current_user' ||
          receiverId == 'null') {
        if (peerId != null && peerId.isNotEmpty) {
          receiverId = peerId;
        }
      }

      if (senderId == receiverId && peerId != null && peerId != senderId) {
        receiverId = peerId;
      }

      if (receiverId.isEmpty) {
        continue;
      }

      final id = idRaw.isEmpty || idRaw == 'null'
          ? '${timestamp.microsecondsSinceEpoch}_m$i'
          : idRaw;

      repaired.add({
        'id': id,
        'senderId': senderId,
        'receiverId': receiverId,
        'content': (map['content'] ?? '').toString(),
        'type': (map['type'] ?? 'text').toString(),
        'status': (map['status'] ?? 'sent').toString(),
        'timestamp': timestamp.toIso8601String(),
        'mediaUrl': map['mediaUrl'],
        'metadata': map['metadata'] is Map
            ? (map['metadata'] as Map).map((k, v) => MapEntry(k.toString(), v))
            : null,
      });
    }

    final byId = <String, Map<String, dynamic>>{};
    for (final m in repaired) {
      byId[m['id'].toString()] = m;
    }

    final merged = byId.values.toList()
      ..sort((a, b) {
        final at = DateTime.tryParse('${a['timestamp']}') ?? DateTime.now();
        final bt = DateTime.tryParse('${b['timestamp']}') ?? DateTime.now();
        return at.compareTo(bt);
      });

    await prefs.setString(_localMessagesKey, jsonEncode(merged));
    await prefs.setBool(_localMessagesMigratedKey, true);
  }

  Future<List<Message>> _getLocalConversation(
    String currentUserId,
    String otherUserId,
  ) async {
    final all = await _readLocalMessages();
    debugPrint('[ChatService] _getLocalConversation: total=${all.length}, '
        'currentUser=$currentUserId, otherUser=$otherUserId');
    final filtered = all
        .where((m) =>
            (m.senderId == currentUserId && m.receiverId == otherUserId) ||
            (m.senderId == otherUserId && m.receiverId == currentUserId))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    debugPrint('[ChatService] _getLocalConversation: filtered=${filtered.length}');
    return filtered;
  }

  Future<List<Message>> getAllLocalMessages() async {
    return _readLocalMessages();
  }

  Future<void> saveLocalMessage(Message message) async {
    await _saveLocalMessage(message);
  }

  /// Reads all locally stored messages.
  /// IMPORTANT: Always returns a NEW mutable list (never const []).
  Future<List<Message>> _readLocalMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localMessagesKey);
    if (raw == null || raw.isEmpty) {
      debugPrint('[ChatService] _readLocalMessages: no data found');
      return <Message>[]; // MUTABLE empty list
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      debugPrint('[ChatService] _readLocalMessages: decoded is not a List');
      return <Message>[]; // MUTABLE empty list
    }

    final messages = decoded
        .whereType<Map>()
        .map(
            (e) => Message.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
        .toList();
    debugPrint('[ChatService] _readLocalMessages: loaded ${messages.length} messages');
    return messages;
  }

  Future<void> _saveLocalMessage(Message message) async {
    debugPrint('[ChatService] _saveLocalMessage: id=${message.id}, '
        'sender=${message.senderId}, receiver=${message.receiverId}, '
        'content="${message.content}"');
    try {
      final all = await _readLocalMessages();
      final existingIndex = all.indexWhere((m) => m.id == message.id);
      if (existingIndex >= 0) {
        all[existingIndex] = message;
      } else {
        all.add(message);
      }
      all.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(all.map((m) => m.toJson()).toList());
      await prefs.setString(_localMessagesKey, json);
      debugPrint('[ChatService] _saveLocalMessage: SUCCESS, total=${all.length}');
    } catch (e, st) {
      debugPrint('[ChatService] _saveLocalMessage FAILED: $e\n$st');
    }
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
