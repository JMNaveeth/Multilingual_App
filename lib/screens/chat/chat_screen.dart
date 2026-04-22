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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFF3ECFF)],
            ),
            border: Border.all(color: const Color(0xFFE6DBFF)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6D3DF2).withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF8E6CF7), Color(0xFF6D3DF2)],
                  ),
                ),
                child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Start your first message',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2A2338),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'No messages yet. Say hi to ${widget.user.name} and begin the conversation.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5D566F),
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.84),
        border: const Border(
          top: BorderSide(color: Color(0xFFE8DEFF)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1EBFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.attach_file, size: 20),
                onPressed: () {
                  // TODO: Implement file attachment
                },
                tooltip: 'Attach',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Color(0xFFD6C8FF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Color(0xFFD6C8FF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Color(0xFF7A52F4), width: 1.4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF8A66F6), Color(0xFF6A3EF0)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6A3EF0).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                tooltip: 'Send',
              ),
            ),
          ],
        ),
      ),
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
      backgroundColor: const Color(0xFFF6F2FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F2FC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFD8CBFF),
              child: Text(
                widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Color(0xFF3B2D63),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.user.name),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.user.isOnline ? const Color(0xFF2ECC71) : const Color(0xFFB0AEC2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.user.isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_rounded),
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
      body: Stack(
        children: [
          Positioned(
            top: -60,
            right: -20,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8E6CF7).withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -50,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5DC6FF).withOpacity(0.06),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: conversationMessages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
              _buildMessageInput(),
            ],
          ),
        ],
      ),
    );
  }

}

