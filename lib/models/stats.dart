class AppStats {
  final int activeUsers;
  final int totalMessages;
  final int totalGroups;
  final int unreadMessages;
  final DateTime lastUpdated;

  const AppStats({
    required this.activeUsers,
    required this.totalMessages,
    required this.totalGroups,
    this.unreadMessages = 0,
    required this.lastUpdated,
  });

  factory AppStats.fromJson(Map<String, dynamic> json) {
    return AppStats(
      activeUsers: json['activeUsers'] ?? 0,
      totalMessages: json['totalMessages'] ?? 0,
      totalGroups: json['totalGroups'] ?? 0,
      unreadMessages: json['unreadMessages'] ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activeUsers': activeUsers,
      'totalMessages': totalMessages,
      'totalGroups': totalGroups,
      'unreadMessages': unreadMessages,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  AppStats copyWith({
    int? activeUsers,
    int? totalMessages,
    int? totalGroups,
    int? unreadMessages,
    DateTime? lastUpdated,
  }) {
    return AppStats(
      activeUsers: activeUsers ?? this.activeUsers,
      totalMessages: totalMessages ?? this.totalMessages,
      totalGroups: totalGroups ?? this.totalGroups,
      unreadMessages: unreadMessages ?? this.unreadMessages,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  static AppStats get empty => AppStats(
    activeUsers: 0,
    totalMessages: 0,
    totalGroups: 0,
    unreadMessages: 0,
    lastUpdated: DateTime.now(),
  );
}
