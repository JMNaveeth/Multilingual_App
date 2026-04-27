import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/models/call_history_entry.dart';
import 'package:multilingual_chat_app/services/call_history_service.dart';

final callHistoryServiceProvider = Provider<CallHistoryService>((ref) {
  return CallHistoryService();
});

final callHistoryProvider =
    FutureProvider.family<List<CallHistoryEntry>, String>((ref, userId) async {
  final service = ref.watch(callHistoryServiceProvider);
  return service.getHistory(userId);
});
