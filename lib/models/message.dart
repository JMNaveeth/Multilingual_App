enum MessageType {
  text,
  image,
  audio,
  video,
  file,
  location,
  contact,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
}

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final String? mediaUrl;
  final Map<String, dynamic>? metadata;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.type,
    required this.status,
    required this.timestamp,
    this.mediaUrl,
    this.metadata,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    final receiver = json['receiver'];
    final timestampRaw = json['timestamp'] ?? json['createdAt'];

    String _asStringOrEmpty(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    String _extractId(dynamic value) {
      if (value is String) return value;
      if (value is Map) {
        final map = value.map((k, v) => MapEntry(k.toString(), v));
        final raw = map['_id'] ?? map['id'];
        if (raw != null) return raw.toString();
      }
      return '';
    }

    return Message(
      id: _asStringOrEmpty(json['_id'] ?? json['id']),
      senderId: _asStringOrEmpty(json['senderId'] ?? _extractId(sender)),
      receiverId: _asStringOrEmpty(json['receiverId'] ?? _extractId(receiver)),
      content: (json['content'] ?? '').toString(),
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == (json['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (json['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      timestamp:
          DateTime.tryParse((timestampRaw ?? '').toString()) ?? DateTime.now(),
      mediaUrl: json['mediaUrl']?.toString(),
      metadata: json['metadata'] is Map
          ? (json['metadata'] as Map).map((k, v) => MapEntry(k.toString(), v))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'mediaUrl': mediaUrl,
      'metadata': metadata,
    };
  }

  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    MessageType? type,
    MessageStatus? status,
    DateTime? timestamp,
    String? mediaUrl,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      metadata: metadata ?? this.metadata,
    );
  }
}
