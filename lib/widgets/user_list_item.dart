import 'package:flutter/material.dart';
import 'package:multilingual_chat_app/models/user.dart';
import 'package:multilingual_chat_app/models/message.dart';

class UserListItem extends StatelessWidget {
  final User user;
  final Message? lastMessage;
  final VoidCallback onTap;

  const UserListItem({
    super.key,
    required this.user,
    this.lastMessage,
    required this.onTap,
  });

  String _getLanguageName(String code) {
    const languages = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
      'hi': 'Hindi',
      'ar': 'Arabic',
      'ta': 'Tamil',
      'te': 'Telugu',
      'kn': 'Kannada',
      'ml': 'Malayalam',
      'si': 'Sinhala',
    };
    return languages[code] ?? code.toUpperCase();
  }

  String _getLastSeenText() {
    if (user.isOnline) return 'Online';

    if (user.lastSeen == null) return 'Offline';

    final now = DateTime.now();
    final difference = now.difference(user.lastSeen!);

    if (difference.inDays > 0) {
      return 'Last seen ${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return 'Last seen ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return 'Last seen ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Last seen just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: user.isOnline ? Colors.green : Colors.grey,
        child: user.profileImageUrl != null
            ? null // TODO: Load image from URL
            : Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
      ),
      title: Text(
        user.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: lastMessage != null
          ? Text(
              _getLastMessagePreview(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getLanguageName(user.preferredLanguage),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  _getLastSeenText(),
                  style: TextStyle(
                    color: user.isOnline ? Colors.green : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (lastMessage != null)
            Text(
              _formatMessageTime(lastMessage!.timestamp),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
          const SizedBox(height: 4),
          if (user.isOnline)
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  String _getLastMessagePreview() {
    if (lastMessage == null) return '';
    switch (lastMessage!.type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.file:
        return '📄 Document';
      case MessageType.location:
        return '📍 Location';
      case MessageType.contact:
        return '👤 Contact';
      default:
        // Use translated content if available, otherwise original content
        final meta = lastMessage!.metadata ?? {};
        final translated = meta['translatedContent'] as String?;
        return translated ?? lastMessage!.content;
    }
  }

  String _formatMessageTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (d == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}';
    }
  }
}
