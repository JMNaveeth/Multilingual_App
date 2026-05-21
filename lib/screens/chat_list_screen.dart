import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/models/user.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';
import 'package:multilingual_chat_app/screens/chat_screen.dart';
import 'package:multilingual_chat_app/widgets/user_list_item.dart';

import 'package:multilingual_chat_app/services/auth_service.dart';
import 'package:multilingual_chat_app/services/chat_service.dart';
import 'package:multilingual_chat_app/models/message.dart';

final chatListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final currentUser = ref.watch(authProvider).value;
  if (currentUser == null) return [];

  final authService = AuthService();
  final chatService = ChatService();

  final users = await authService.getFriends();
  final messages = await chatService.getAllLocalMessages();

  final otherUsers = users.where((u) => u.id != currentUser.id).toList();

  final result = <Map<String, dynamic>>[];
  for (final u in otherUsers) {
    final userMessages = messages
        .where((m) =>
            (m.senderId == currentUser.id && m.receiverId == u.id) ||
            (m.senderId == u.id && m.receiverId == currentUser.id))
        .toList();

    Message? lastMessage;
    if (userMessages.isNotEmpty) {
      userMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      lastMessage = userMessages.first;
    }

    result.add({
      'user': u,
      'lastMessage': lastMessage,
    });
  }

  result.sort((a, b) {
    final msgA = a['lastMessage'] as Message?;
    final msgB = b['lastMessage'] as Message?;
    if (msgA == null && msgB == null) return 0;
    if (msgA == null) return 1;
    if (msgB == null) return -1;
    return msgB.timestamp.compareTo(msgA.timestamp);
  });

  return result;
});

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatListAsync = ref.watch(chatListProvider);

    return Scaffold(
      body: chatListAsync.when(
        data: (chatList) {
          if (chatList.isEmpty) {
            return const Center(
                child: Text('No users found. Please add friends to start chatting.'));
          }

          return ListView.builder(
            itemCount: chatList.length,
            itemBuilder: (context, index) {
              final item = chatList[index];
              final user = item['user'] as User;
              final lastMessage = item['lastMessage'] as Message?;

              return UserListItem(
                user: user,
                lastMessage: lastMessage,
                onTap: () {
                  Navigator.of(context)
                      .push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(user: user),
                    ),
                  )
                      .then((_) {
                    // Refresh the list when returning to update last message
                    ref.invalidate(chatListProvider);
                  });
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
