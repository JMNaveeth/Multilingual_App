import 'dart:convert';

import 'package:multilingual_chat_app/models/message.dart';
import 'package:multilingual_chat_app/services/auth_service.dart';
import 'package:multilingual_chat_app/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  ChatService({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;
  static const int _maxLocalMessagesPerUser = 2000;

  SupabaseClient get _client => SupabaseService.client;

  String _localMessagesKey(String userId) => 'chat_local_messages_$userId';
  String _legacyMigrationDoneKey(String userId) =>
      'chat_legacy_migration_done_$userId';
  String _deletedMessagesKey(String userId) => 'chat_deleted_messages_$userId';

  String _messageMergeKey(Message message) {
    final clientId = message.metadata?['clientMessageId']?.toString();
    if (clientId != null && clientId.isNotEmpty) {
      return clientId;
    }
    return message.id;
  }

  List<Message> _sortByTimestampAsc(List<Message> messages) {
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  List<Message> _mergeMessages(List<Message> primary, List<Message> secondary) {
    final byKey = <String, Message>{};
    for (final message in secondary) {
      byKey[_messageMergeKey(message)] = message;
    }
    for (final message in primary) {
      byKey[_messageMergeKey(message)] = message;
    }
    return _sortByTimestampAsc(byKey.values.toList());
  }

  Future<List<Message>> _getLocalMessages(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localMessagesKey(userId));
    if (raw == null || raw.isEmpty) {
      return <Message>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Message>[];
      }

      final messages = decoded
          .whereType<Map>()
          .map(
            (item) => Message.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .toList();
      return _sortByTimestampAsc(messages);
    } catch (_) {
      return <Message>[];
    }
  }

  Future<void> _saveLocalMessages(String userId, List<Message> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final merged = _mergeMessages(messages, const <Message>[]);
    final trimmed = merged.length > _maxLocalMessagesPerUser
        ? merged.sublist(merged.length - _maxLocalMessagesPerUser)
        : merged;

    await prefs.setString(
      _localMessagesKey(userId),
      jsonEncode(trimmed.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> _upsertLocalMessages(
      String userId, List<Message> messages) async {
    final existing = await _getLocalMessages(userId);
    final merged = _mergeMessages(messages, existing);
    await _saveLocalMessages(userId, merged);
  }

  Future<void> _upsertSingleLocalMessage(String userId, Message message) async {
    await _upsertLocalMessages(userId, [message]);
  }

  Future<Set<String>> getHiddenMessageIds(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getStringList(_deletedMessagesKey(userId)) ?? const [];
    return hidden.where((id) => id.isNotEmpty).toSet();
  }

  Future<void> _hideMessageForUser(String userId, String messageId) async {
    if (messageId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final hidden =
        prefs.getStringList(_deletedMessagesKey(userId)) ?? <String>[];
    if (hidden.contains(messageId)) return;

    hidden.add(messageId);
    await prefs.setStringList(_deletedMessagesKey(userId), hidden);
  }

  Future<void> _removeMessageFromLocalCache(
    String userId,
    String messageId,
  ) async {
    if (messageId.isEmpty) return;

    final messages = await _getLocalMessages(userId);
    final filtered =
        messages.where((message) => message.id != messageId).toList();
    await _saveLocalMessages(userId, filtered);
  }

  Future<bool> deleteMessage({
    required Message message,
    required bool deleteForEveryone,
  }) async {
    final currentUser = await _authService.getCurrentUser();
    final ownerId = currentUser?.id ?? message.senderId;
    final clientMessageId = message.metadata?['clientMessageId']?.toString() ?? message.id;

    await _removeMessageFromLocalCache(ownerId, message.id);

    if (!deleteForEveryone) {
      await _hideMessageForUser(ownerId, message.id);
      return true;
    }

    if (SupabaseService.isConfigured) {
      try {
        await _client
            .from('messages')
            .delete()
            .or('id.eq.${message.id},metadata->>clientMessageId.eq.$clientMessageId');
        await _hideMessageForUser(ownerId, message.id);
        return true;
      } catch (_) {
        return false;
      }
    }

    // No remote store available, so fall back to local removal only.
    await _hideMessageForUser(ownerId, message.id);
    return true;
  }

  Future<List<Message>> _loadRemoteMessagesForUser(String userId) async {
    final rows = await _client
        .from('messages')
        .select()
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('created_at', ascending: true);

    return rows
        .whereType<Map>()
        .map((e) => _fromRow(e.map((k, v) => MapEntry(k.toString(), v)))
            .copyWith(status: MessageStatus.sent))
        .toList();
  }

  Future<List<Message>> _loadRemoteConversation(
    String currentUserId,
    String otherUserId,
  ) async {
    final rows = await _client
        .from('messages')
        .select()
        .or(
          'and(sender_id.eq.$currentUserId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$currentUserId)',
        )
        .order('created_at', ascending: true);

    return rows
        .whereType<Map>()
        .map((e) => _fromRow(e.map((k, v) => MapEntry(k.toString(), v)))
            .copyWith(status: MessageStatus.sent))
        .toList();
  }

  Message _fromRow(Map<String, dynamic> row) {
    return Message.fromJson({
      'id': row['id'],
      'senderId': row['sender_id'],
      'receiverId': row['receiver_id'],
      'content': row['content'] ?? '',
      'type': row['type'] ?? 'text',
      'status': row['status'] ?? 'sent',
      'createdAt': row['created_at'],
      'mediaUrl': row['media_url'],
      'metadata': row['metadata'],
    });
  }

  Map<String, dynamic> _toInsertRow(Message message) {
    final metadata = <String, dynamic>{...?message.metadata};
    metadata.putIfAbsent('clientMessageId', () => message.id);
    metadata.putIfAbsent(
      'clientTimestamp',
      () => message.timestamp.toIso8601String(),
    );

    return {
      'sender_id': message.senderId,
      'receiver_id': message.receiverId,
      'content': message.content,
      'type': message.type.toString().split('.').last,
      'status': message.status.toString().split('.').last,
      'media_url': message.mediaUrl,
      'metadata': metadata,
    };
  }

  Future<Message?> _findExistingByClientMessageId(Message message) async {
    final clientId = message.id;
    if (clientId.isEmpty) {
      return null;
    }

    final rows = await _client
        .from('messages')
        .select()
        .eq('sender_id', message.senderId)
        .eq('receiver_id', message.receiverId)
        .contains('metadata', {'clientMessageId': clientId}).limit(1);

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    if (row is! Map) {
      return null;
    }

    return _fromRow(row.map((k, v) => MapEntry(k.toString(), v)));
  }

  Future<List<Message>> getConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final hiddenIds = await getHiddenMessageIds(currentUserId);
    final localAll = await _getLocalMessages(currentUserId);
    final localConversation = localAll.where((message) {
      if (hiddenIds.contains(message.id)) {
        return false;
      }
      return (message.senderId == currentUserId &&
              message.receiverId == otherUserId) ||
          (message.senderId == otherUserId &&
              message.receiverId == currentUserId);
    }).toList();

    if (!SupabaseService.isConfigured) {
      return _sortByTimestampAsc(localConversation);
    }

    try {
      final remoteConversation =
          await _loadRemoteConversation(currentUserId, otherUserId);
      await _upsertLocalMessages(currentUserId, remoteConversation);
      final merged = _mergeMessages(remoteConversation, localConversation)
          .where((message) => !hiddenIds.contains(message.id))
          .toList();
      return _sortByTimestampAsc(merged);
    } catch (_) {
      return _sortByTimestampAsc(localConversation);
    }
  }

  Stream<List<Message>> getConversationStream({
    required String currentUserId,
    required String otherUserId,
  }) {
    return _client.from('messages').stream(primaryKey: ['id']).map((rows) {
      final messages = rows
          .map((row) => _fromRow(row))
          .where(
              (m) => m.senderId == currentUserId && m.receiverId == otherUserId)
          .toList();
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  Stream<List<Message>> getFullConversationStream({
    required String currentUserId,
    required String otherUserId,
  }) {
    return _client.from('messages').stream(primaryKey: ['id']).map((rows) {
      final messages = rows
          .map((row) => _fromRow(row))
          .where((m) =>
              (m.senderId == currentUserId && m.receiverId == otherUserId) ||
              (m.senderId == otherUserId && m.receiverId == currentUserId))
          .toList();
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  Future<Message> sendMessage(Message message) async {
    await _upsertSingleLocalMessage(message.senderId, message);

    if (!SupabaseService.isConfigured) {
      return message;
    }

    try {
      final existing = await _findExistingByClientMessageId(message);
      if (existing != null) {
        await _upsertSingleLocalMessage(message.senderId, existing);
        return existing;
      }

      final inserted = await _client
          .from('messages')
          .insert(_toInsertRow(message))
          .select()
          .single();

      final persisted = _fromRow(Map<String, dynamic>.from(inserted));
      await _upsertSingleLocalMessage(message.senderId, persisted);
      return persisted;
    } catch (_) {
      // Keep local message for retry path and avoid blocking UX.
      return message;
    }
  }

  Future<void> migrateLegacyLocalMessages({
    required String currentUserId,
    List<String> knownPeerIds = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_legacyMigrationDoneKey(currentUserId)) == true) {
      return;
    }

    final legacyKeys = prefs.getKeys().where((key) {
      final k = key.toLowerCase();
      return k.contains('message') || k.contains('chat');
    });

    final imported = <Message>[];
    for (final key in legacyKeys) {
      if (key == _localMessagesKey(currentUserId)) {
        continue;
      }

      final value = prefs.get(key);
      if (value is! String || value.isEmpty) {
        continue;
      }

      try {
        final decoded = jsonDecode(value);
        if (decoded is! List) {
          continue;
        }

        for (final item in decoded) {
          if (item is! Map) {
            continue;
          }
          final map = item.map((k, v) => MapEntry(k.toString(), v));
          final message = Message.fromJson(map);
          final belongsToCurrentUser = message.senderId == currentUserId ||
              message.receiverId == currentUserId;
          if (!belongsToCurrentUser) {
            continue;
          }

          if (knownPeerIds.isNotEmpty) {
            final belongsToKnownPeer =
                knownPeerIds.contains(message.senderId) ||
                    knownPeerIds.contains(message.receiverId);
            if (!belongsToKnownPeer) {
              continue;
            }
          }

          imported.add(message);
        }
      } catch (_) {
        // Ignore unreadable keys and continue.
      }
    }

    if (imported.isNotEmpty) {
      await _upsertLocalMessages(currentUserId, imported);
    }

    await prefs.setBool(_legacyMigrationDoneKey(currentUserId), true);

    if (!SupabaseService.isConfigured) {
      return;
    }

    // Best-effort background sync for imported outgoing history.
    if (imported.isEmpty) {
      return;
    }

    final outgoingImported =
        imported.where((m) => m.senderId == currentUserId).toList();
    if (outgoingImported.isEmpty) {
      return;
    }

    for (final message in outgoingImported) {
      sendMessage(message);
    }
  }

  Future<List<Message>> getAllLocalMessages() async {
    final currentUser = await _authService.getCurrentUser();
    if (currentUser == null) {
      return <Message>[];
    }

    final local = await _getLocalMessages(currentUser.id);
    if (!SupabaseService.isConfigured) {
      return local;
    }

    try {
      final remote = await _loadRemoteMessagesForUser(currentUser.id);
      final merged = _mergeMessages(remote, local);
      await _saveLocalMessages(currentUser.id, merged);
      return merged;
    } catch (_) {
      return local;
    }
  }

  Future<void> saveLocalMessage(Message message) async {
    final currentUser = await _authService.getCurrentUser();
    final ownerId = currentUser?.id ?? message.senderId;
    await _upsertSingleLocalMessage(ownerId, message);
  }
}
