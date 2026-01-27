import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/models/stats.dart';
import 'package:multilingual_chat_app/services/stats_service.dart';

// Stats service provider
final statsServiceProvider = Provider<StatsService>((ref) {
  final service = StatsService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Real-time stats stream provider
final statsStreamProvider = StreamProvider<AppStats>((ref) {
  final statsService = ref.watch(statsServiceProvider);

  // Start real-time updates when provider is initialized
  statsService.startRealTimeUpdates();

  // Stop updates when provider is disposed
  ref.onDispose(() => statsService.stopRealTimeUpdates());

  return statsService.statsStream;
});

// Current stats state provider
final currentStatsProvider = StateProvider<AppStats>((ref) {
  return AppStats(
    activeUsers: 0,
    totalMessages: 0,
    totalGroups: 0,
    lastUpdated: DateTime.now(),
  );
});

// User-specific stats provider
final userStatsProvider =
    FutureProvider.family<AppStats, String>((ref, userId) async {
  final statsService = ref.watch(statsServiceProvider);
  return await statsService.fetchUserStats(userId);
});

// Manual refresh provider
final statsRefreshProvider = FutureProvider<AppStats>((ref) async {
  final statsService = ref.watch(statsServiceProvider);
  return await statsService.fetchStats();
});
