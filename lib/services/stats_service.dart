import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:multilingual_chat_app/models/stats.dart';

class StatsService {
  final String baseUrl;
  final StreamController<AppStats> _statsController =
      StreamController<AppStats>.broadcast();
  Timer? _refreshTimer;

  static const Duration refreshInterval = Duration(seconds: 5);

  StatsService({this.baseUrl = 'http://localhost:3000'});

  Stream<AppStats> get statsStream => _statsController.stream;

  // Start real-time stats updates
  void startRealTimeUpdates() {
    // Initial fetch
    fetchStats();

    // Set up periodic updates
    _refreshTimer = Timer.periodic(refreshInterval, (_) {
      fetchStats();
    });
  }

  // Fetch stats from backend
  Future<AppStats> fetchStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/stats'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final stats = AppStats.fromJson(data);
        _statsController.add(stats);
        return stats;
      } else {
        throw Exception('Failed to load stats: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching stats: $e');
      // Return default stats on error
      final defaultStats = AppStats(
        activeUsers: 0,
        totalMessages: 0,
        totalGroups: 0,
        lastUpdated: DateTime.now(),
      );
      _statsController.add(defaultStats);
      return defaultStats;
    }
  }

  // Fetch user-specific stats
  Future<AppStats> fetchUserStats(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId/stats'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AppStats.fromJson(data);
      } else {
        throw Exception('Failed to load user stats');
      }
    } catch (e) {
      print('Error fetching user stats: $e');
      return AppStats(
        activeUsers: 0,
        totalMessages: 0,
        totalGroups: 0,
        lastUpdated: DateTime.now(),
      );
    }
  }

  // Stop real-time updates
  void stopRealTimeUpdates() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void dispose() {
    stopRealTimeUpdates();
    _statsController.close();
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
