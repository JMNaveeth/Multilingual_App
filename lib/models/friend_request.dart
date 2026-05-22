import 'package:multilingual_chat_app/models/user.dart';

enum RequestStatus { pending, accepted, cancelled }

class FriendRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final RequestStatus status;
  final DateTime createdAt;

  /// Populated after fetching related profile rows
  User? senderUser;
  User? receiverUser;

  FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.senderUser,
    this.receiverUser,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      receiverId: json['receiver_id']?.toString() ?? '',
      status: _parseStatus(json['status']?.toString() ?? 'pending'),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static RequestStatus _parseStatus(String s) {
    switch (s) {
      case 'accepted':
        return RequestStatus.accepted;
      case 'cancelled':
        return RequestStatus.cancelled;
      default:
        return RequestStatus.pending;
    }
  }
}
