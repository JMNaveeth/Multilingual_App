import 'dart:convert';

import 'package:multilingual_chat_app/models/call_history_entry.dart';
import 'package:multilingual_chat_app/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CallHistoryService {
  static const int _maxEntriesPerUser = 200;

  String _storageKey(String userId) => 'call_history_$userId';
  SupabaseClient get _client => SupabaseService.client;

  Map<String, dynamic> _toSupabaseRow(
    String userId,
    CallHistoryEntry entry,
  ) {
    return {
      'id': entry.id,
      'user_id': userId,
      'peer_user_id': entry.peerUserId,
      'peer_name': entry.peerName,
      'peer_profile_image_url': entry.peerProfileImageUrl,
      'call_type': entry.callType,
      'direction': entry.direction.name,
      'result': entry.result.name,
      'started_at': entry.startedAt.toIso8601String(),
      'ended_at': entry.endedAt?.toIso8601String(),
      'duration_seconds': entry.durationSeconds,
    };
  }

  CallHistoryEntry _fromSupabaseRow(Map<String, dynamic> row) {
    return CallHistoryEntry.fromJson({
      'id': row['id'],
      'peerUserId': row['peer_user_id'],
      'peerName': row['peer_name'],
      'peerProfileImageUrl': row['peer_profile_image_url'],
      'callType': row['call_type'],
      'direction': row['direction'],
      'result': row['result'],
      'startedAt': row['started_at'],
      'endedAt': row['ended_at'],
      'durationSeconds': row['duration_seconds'],
    });
  }

  Future<List<CallHistoryEntry>> _getLocalHistory(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(userId));
    if (raw == null || raw.isEmpty) {
      return <CallHistoryEntry>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <CallHistoryEntry>[];
      }

      final entries = decoded
          .whereType<Map>()
          .map((item) => CallHistoryEntry.fromJson(
                item.map((k, v) => MapEntry(k.toString(), v)),
              ))
          .toList();
      entries.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return entries;
    } catch (_) {
      return <CallHistoryEntry>[];
    }
  }

  Future<void> _saveLocalHistory(
    String userId,
    List<CallHistoryEntry> entries,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final sorted = [...entries]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final trimmed = sorted.take(_maxEntriesPerUser).toList();
    await prefs.setString(
      _storageKey(userId),
      jsonEncode(trimmed.map((item) => item.toJson()).toList()),
    );
  }

  List<CallHistoryEntry> _mergeUnique(
    List<CallHistoryEntry> remote,
    List<CallHistoryEntry> local,
  ) {
    final byId = <String, CallHistoryEntry>{};
    for (final entry in [...remote, ...local]) {
      byId[entry.id] = entry;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return merged;
  }

  Future<List<CallHistoryEntry>> getHistory(String userId) async {
    final local = await _getLocalHistory(userId);

    if (!SupabaseService.isConfigured) {
      return local;
    }

    try {
      final rows = await _client
          .from('call_history')
          .select()
          .eq('user_id', userId)
          .order('started_at', ascending: false)
          .limit(_maxEntriesPerUser);

      final remote = rows
          .whereType<Map>()
          .map((e) => _fromSupabaseRow(
                e.map((k, v) => MapEntry(k.toString(), v)),
              ))
          .toList();

      final merged = _mergeUnique(remote, local);
      await _saveLocalHistory(userId, merged);
      return merged;
    } catch (_) {
      return local;
    }
  }

  Future<void> addEntry({
    required String userId,
    required CallHistoryEntry entry,
  }) async {
    final local = await _getLocalHistory(userId);
    final merged = _mergeUnique([entry], local);
    await _saveLocalHistory(userId, merged);

    if (!SupabaseService.isConfigured) {
      return;
    }

    try {
      await _client
          .from('call_history')
          .upsert(_toSupabaseRow(userId, entry), onConflict: 'id');
    } catch (_) {
      // Local cache is already updated; remote write can retry on next session.
    }
  }

  Future<void> clearHistory(String userId) async {
    await _saveLocalHistory(userId, const <CallHistoryEntry>[]);

    if (!SupabaseService.isConfigured) {
      return;
    }

    try {
      await _client.from('call_history').delete().eq('user_id', userId);
    } catch (_) {
      // Keep local clear behavior even if remote clear fails.
    }
  }
}
