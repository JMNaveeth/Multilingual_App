import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/models/message.dart';
import 'package:multilingual_chat_app/models/user.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';
import 'package:multilingual_chat_app/widgets/message_bubble.dart';

// Mock messages for demonstration - replace with real data
final mockMessagesProvider = Provider<List<Message>>((ref) => [
  Message(
    id: '1',
    senderId: '1',
    receiverId: 'current_user',
    content: 'Hello! How are you?',
    type: MessageType.text,
    status: MessageStatus.read,
    timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
  ),
  Message(
    id: '2',
    senderId: 'current_user',
    receiverId: '1',
    content: 'Hi! I\'m doing well, thank you. How about you?',
    type: MessageType.text,
    status: MessageStatus.read,
    timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
  ),
  Message(
    id: '3',
    senderId: '1',
    receiverId: 'current_user',
    content: 'I\'m great! Ready to test the translation feature?',
    type: MessageType.text,
    status: MessageStatus.read,
    timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
  ),
]);

class ChatScreen extends ConsumerStatefulWidget {
  final User user;

  const ChatScreen({super.key, required this.user});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // TODO: Implement actual message sending
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Message sent: $message')),
    );

    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startVideoCall() {
    // TODO: Implement video call functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Video call feature coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).value;
    final messages = ref.watch(mockMessagesProvider);

    // Filter messages for this conversation
    final conversationMessages = messages.where((message) {
      return (message.senderId == widget.user.id && message.receiverId == currentUser?.id) ||
             (message.senderId == currentUser?.id && message.receiverId == widget.user.id);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.user.name),
            Text(
              widget.user.isOnline ? 'Online' : 'Offline',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: _startVideoCall,
            tooltip: 'Start Video Call',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: Show chat options menu
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: conversationMessages.isEmpty
                ? const Center(
                    child: Text('No messages yet. Start the conversation!'),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: conversationMessages.length,
                    itemBuilder: (context, index) {
                      final message = conversationMessages[index];
                      final isMe = message.senderId == currentUser?.id;

                      return MessageBubble(
                        message: message,
                        isMe: isMe,
                      );
                    },
                  ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: () {
                    // TODO: Implement file attachment
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
