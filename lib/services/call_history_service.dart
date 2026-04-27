import 'dart:convert';

import 'package:multilingual_chat_app/models/call_history_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CallHistoryService {
  static const int _maxEntriesPerUser = 200;

  String _storageKey(String userId) => 'call_history_$userId';

  Future<List<CallHistoryEntry>> getHistory(String userId) async {
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

  Future<void> addEntry({
    required String userId,
    required CallHistoryEntry entry,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory(userId);

    final updated = <CallHistoryEntry>[entry, ...history];
    final trimmed = updated.take(_maxEntriesPerUser).toList();
    await prefs.setString(
      _storageKey(userId),
      jsonEncode(trimmed.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> clearHistory(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey(userId));
  }
}
