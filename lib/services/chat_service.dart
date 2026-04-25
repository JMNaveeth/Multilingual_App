import 'package:multilingual_chat_app/models/message.dart';
import 'package:multilingual_chat_app/services/auth_service.dart';
import 'package:multilingual_chat_app/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  ChatService({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;

  SupabaseClient get _client => SupabaseService.client;

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
    return {
      'sender_id': message.senderId,
      'receiver_id': message.receiverId,
      'content': message.content,
      'type': message.type.toString().split('.').last,
      'status': message.status.toString().split('.').last,
      'media_url': message.mediaUrl,
      'metadata': message.metadata,
    };
  }

  Future<List<Message>> getConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final rows = await _client
        .from('messages')
        .select()
        .or(
          'and(sender_id.eq.$currentUserId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$currentUserId)',
        )
        .order('created_at', ascending: true);

    return rows
        .whereType<Map>()
        .map((e) => _fromRow(e.map((k, v) => MapEntry(k.toString(), v))))
        .toList();
  }

  Future<Message> sendMessage(Message message) async {
    final inserted = await _client
        .from('messages')
        .insert(_toInsertRow(message))
        .select()
        .single();

    return _fromRow(Map<String, dynamic>.from(inserted));
  }

  Future<void> migrateLegacyLocalMessages({
    required String currentUserId,
    List<String> knownPeerIds = const [],
  }) async {
    // No-op after Supabase migration.
  }

  Future<List<Message>> getAllLocalMessages() async {
    final currentUser = await _authService.getCurrentUser();
    if (currentUser == null) {
      return <Message>[];
    }

    final rows = await _client
        .from('messages')
        .select()
        .or('sender_id.eq.${currentUser.id},receiver_id.eq.${currentUser.id}')
        .order('created_at', ascending: true);

    return rows
        .whereType<Map>()
        .map((e) => _fromRow(e.map((k, v) => MapEntry(k.toString(), v))))
        .toList();
  }

  Future<void> saveLocalMessage(Message message) async {
    // No-op for Supabase-backed chat; optimistic UI is handled in screen state.
  }
}
