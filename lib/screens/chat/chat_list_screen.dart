import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/models/user.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';
import 'package:multilingual_chat_app/screens/chat/chat_screen.dart';
import 'package:multilingual_chat_app/widgets/user_list_item.dart';

import 'package:multilingual_chat_app/services/auth_service.dart';

final usersProvider = FutureProvider<List<User>>((ref) async {
  final authService = AuthService();
  return authService.getAllUsers();
});

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider).value;
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      body: usersAsync.when(
        data: (users) {
          // Filter out current user
          final otherUsers = users.where((user) => user.id != currentUser?.id).toList();

          if (otherUsers.isEmpty) {
            return const Center(child: Text('No users found. Please register other accounts.'));
          }

          return ListView.builder(
            itemCount: otherUsers.length,
            itemBuilder: (context, index) {
              final user = otherUsers[index];
              return UserListItem(
                user: user,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(user: user),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement search/add new contact functionality
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add contact feature coming soon!')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

