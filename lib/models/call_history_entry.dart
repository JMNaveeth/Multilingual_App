enum CallDirection { incoming, outgoing }

enum CallResult { completed, missed, declined, cancelled }

class CallHistoryEntry {
  final String id;
  final String peerUserId;
  final String peerName;
  final String? peerProfileImageUrl;
  final String callType;
  final CallDirection direction;
  final CallResult result;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;

  const CallHistoryEntry({
    required this.id,
    required this.peerUserId,
    required this.peerName,
    this.peerProfileImageUrl,
    required this.callType,
    required this.direction,
    required this.result,
    required this.startedAt,
    this.endedAt,
    required this.durationSeconds,
  });

  factory CallHistoryEntry.fromJson(Map<String, dynamic> json) {
    return CallHistoryEntry(
      id: json['id']?.toString() ?? '',
      peerUserId: json['peerUserId']?.toString() ?? '',
      peerName: json['peerName']?.toString() ?? 'Unknown',
      peerProfileImageUrl: json['peerProfileImageUrl']?.toString(),
      callType: json['callType']?.toString() ?? 'voice',
      direction: CallDirection.values.firstWhere(
        (value) => value.name == (json['direction']?.toString() ?? ''),
        orElse: () => CallDirection.outgoing,
      ),
      result: CallResult.values.firstWhere(
        (value) => value.name == (json['result']?.toString() ?? ''),
        orElse: () => CallResult.cancelled,
      ),
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
          DateTime.now(),
      endedAt: DateTime.tryParse(json['endedAt']?.toString() ?? ''),
      durationSeconds: json['durationSeconds'] is num
          ? (json['durationSeconds'] as num).toInt()
          : int.tryParse(json['durationSeconds']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'peerUserId': peerUserId,
      'peerName': peerName,
      'peerProfileImageUrl': peerProfileImageUrl,
      'callType': callType,
      'direction': direction.name,
      'result': result.name,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'durationSeconds': durationSeconds,
    };
  }
}
