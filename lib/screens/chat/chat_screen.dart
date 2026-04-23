import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/models/message.dart';
import 'package:multilingual_chat_app/models/user.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';
import 'package:multilingual_chat_app/screens/chat/call_screen.dart';
import 'package:multilingual_chat_app/services/call_socket_service.dart';

// ── Nexus Design Tokens (same as home_screen) ────────────────────────────────
class _N {
  static const bg = Color(0xFF0D0E1A);
  static const surface = Color(0xFF151626);
  static const card = Color(0xFF1C1E31);
  static const cardBorder = Color(0xFF252842);
  static const indigo = Color(0xFF6366F1);
  static const indigoLight = Color(0xFF818CF8);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF8B5CF6);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);
  static const inputBg = Color(0xFF13141F);
  static const inputBorder = Color(0xFF1E2035);
}

// Mock messages (replace with real provider)
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

class _ChatScreenState extends ConsumerState<ChatScreen>
    with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Message> _messages = [];
  bool _showAttachMenu = false;
  bool _isTyping = false;
  bool _socketReady = false;
  bool _incomingDialogOpen = false;
  StreamSubscription<IncomingCall>? _incomingCallSub;

  late final AnimationController _onlineGlowCtrl;
  late final AnimationController _attachMenuCtrl;
  late final Animation<double> _attachMenuAnim;

  @override
  void initState() {
    super.initState();

    _onlineGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _attachMenuCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _attachMenuAnim = CurvedAnimation(
      parent: _attachMenuCtrl,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );

    _messages.addAll(List<Message>.from(ref.read(mockMessagesProvider)));

    _messageController.addListener(() {
      final typing = _messageController.text.isNotEmpty;
      if (typing != _isTyping) setState(() => _isTyping = typing);
    });

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _incomingCallSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _onlineGlowCtrl.dispose();
    _attachMenuCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureSocket(User? currentUser) async {
    if (currentUser == null || _socketReady) {
      return;
    }

    _socketReady = true;
    await CallSocketService.instance.connect(userId: currentUser.id);

    _incomingCallSub ??= CallSocketService.instance.incomingCalls.listen(
      (incomingCall) {
        if (!mounted) {
          return;
        }

        if (incomingCall.fromUserId != widget.user.id || _incomingDialogOpen) {
          return;
        }

        _incomingDialogOpen = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: _N.card,
              title: Text(
                'Incoming ${incomingCall.callType} call',
                style: const TextStyle(color: _N.textPrimary),
              ),
              content: Text(
                '${incomingCall.fromName} is calling you.',
                style: const TextStyle(color: _N.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _incomingDialogOpen = false;
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Decline'),
                ),
                ElevatedButton(
                  onPressed: () {
                    CallSocketService.instance.answerCall(
                      to: incomingCall.fromUserId,
                      callType: incomingCall.callType,
                    );
                    _incomingDialogOpen = false;
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CallScreen(
                          peerUser: widget.user,
                          callType: incomingCall.callType == 'video'
                              ? CallType.video
                              : CallType.voice,
                          isIncoming: true,
                        ),
                      ),
                    );
                  },
                  child: const Text('Accept'),
                ),
              ],
            );
          },
        ).then((_) {
          _incomingDialogOpen = false;
        });
      },
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUser = ref.read(authProvider).value;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please sign in to send a message.'),
      ));
      return;
    }

    setState(() {
      _messages.add(
        Message(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          senderId: currentUser.id,
          receiverId: widget.user.id,
          content: text,
          type: MessageType.text,
          status: MessageStatus.sent,
          timestamp: DateTime.now(),
        ),
      );
    });

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

  void _toggleAttachMenu() {
    setState(() => _showAttachMenu = !_showAttachMenu);
    if (_showAttachMenu) {
      _attachMenuCtrl.forward();
    } else {
      _attachMenuCtrl.reverse();
    }
  }

  void _startVideoCall() {
    _startCall(CallType.video);
  }

  void _startVoiceCall() {
    _startCall(CallType.voice);
  }

  void _startCall(CallType callType) {
    final currentUser = ref.read(authProvider).value;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to start a call.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          peerUser: widget.user,
          callType: callType,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).value;
    final messages = _messages;

    _ensureSocket(currentUser);

    final conversation = messages
        .where((m) =>
            (m.senderId == widget.user.id && m.receiverId == currentUser?.id) ||
            (m.senderId == currentUser?.id && m.receiverId == widget.user.id))
        .toList();

    return Scaffold(
      backgroundColor: _N.bg,
      body: Stack(
        children: [
          // ── Subtle background pattern ──
          _buildBackground(),

          Column(children: [
            // ── Custom AppBar ──
            _buildAppBar(),

            // ── Messages ──
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_showAttachMenu) _toggleAttachMenu();
                  FocusScope.of(context).unfocus();
                },
                child: conversation.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: conversation.length,
                        itemBuilder: (ctx, i) {
                          final msg = conversation[i];
                          final isMe = msg.senderId == currentUser?.id;
                          final showDate = i == 0 ||
                              !_sameDay(
                                conversation[i - 1].timestamp,
                                msg.timestamp,
                              );
                          return Column(children: [
                            if (showDate) _buildDateChip(msg.timestamp),
                            _buildMessageRow(msg, isMe),
                          ]);
                        },
                      ),
              ),
            ),

            // ── Attach menu (slides up) ──
            SizeTransition(
              sizeFactor: _attachMenuAnim,
              child: _buildAttachMenu(),
            ),

            // ── Input bar ──
            _buildInputBar(),
          ]),
        ],
      ),
    );
  }

  // ── Background ────────────────────────────────────────────────────────────

  Widget _buildBackground() {
    return Positioned.fill(
      child: CustomPaint(painter: _WhatsAppWallpaperPainter()),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 12,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: _N.surface.withOpacity(0.95),
        border: const Border(
          bottom: BorderSide(color: _N.cardBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        // Back button
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _N.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _N.cardBorder),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _N.textSecondary, size: 16),
          ),
        ),
        const SizedBox(width: 10),

        // Avatar with online ring
        _buildAvatar(),
        const SizedBox(width: 12),

        // Name + status
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.user.name,
                  style: const TextStyle(
                    color: _N.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  )),
              const SizedBox(height: 2),
              Row(children: [
                if (widget.user.isOnline) ...[
                  AnimatedBuilder(
                    animation: _onlineGlowCtrl,
                    builder: (_, __) => Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _N.cyan,
                        boxShadow: [
                          BoxShadow(
                            color: _N.cyan
                                .withOpacity(0.5 + _onlineGlowCtrl.value * 0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text('Active now',
                      style: TextStyle(
                          color: _N.cyan,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ] else
                  const Text('Offline',
                      style: TextStyle(color: _N.textMuted, fontSize: 11)),
              ]),
            ],
          ),
        ),

        // Voice call
        _appBarBtn(Icons.call_outlined, _startVoiceCall),
        const SizedBox(width: 6),
        // Video call
        _appBarBtn(Icons.videocam_outlined, _startVideoCall),
        const SizedBox(width: 6),
        // More
        _appBarPopup(),
      ]),
    );
  }

  Widget _buildAvatar() {
    final initials = widget.user.name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return AnimatedBuilder(
      animation: _onlineGlowCtrl,
      builder: (_, __) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [_N.indigo, _N.violet],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: widget.user.isOnline
              ? [
                  BoxShadow(
                    color: _N.indigo
                        .withOpacity(0.3 + _onlineGlowCtrl.value * 0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Center(
          child: Text(initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              )),
        ),
      ),
    );
  }

  Widget _appBarBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _N.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _N.cardBorder),
          ),
          child: Icon(icon, color: _N.textSecondary, size: 18),
        ),
      );

  Widget _appBarPopup() => PopupMenuButton<String>(
        color: _N.card,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _N.cardBorder),
        ),
        icon: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _N.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _N.cardBorder),
          ),
          child: const Icon(Icons.more_horiz_rounded,
              color: _N.textSecondary, size: 18),
        ),
        itemBuilder: (_) => [
          _popItem(Icons.search_rounded, 'Search'),
          _popItem(Icons.translate_rounded, 'Translate'),
          _popItem(Icons.wallpaper_rounded, 'Wallpaper'),
          _popItem(Icons.notifications_off_outlined, 'Mute'),
          _popItem(Icons.block_rounded, 'Block'),
        ],
      );

  PopupMenuItem<String> _popItem(IconData icon, String label) =>
      PopupMenuItem<String>(
        value: label,
        child: Row(children: [
          Icon(icon, size: 17, color: _N.indigoLight),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(color: _N.textPrimary, fontSize: 13.5)),
        ]),
      );

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [
                _N.indigo.withOpacity(0.15),
                _N.violet.withOpacity(0.15),
              ],
            ),
            border: Border.all(color: _N.indigo.withOpacity(0.3), width: 1.5),
          ),
          child:
              const Icon(Icons.forum_outlined, size: 40, color: _N.indigoLight),
        ),
        const SizedBox(height: 20),
        Text('Start a conversation',
            style: TextStyle(
              color: _N.textPrimary.withOpacity(0.9),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            )),
        const SizedBox(height: 6),
        Text('Say hello to ${widget.user.name.split(' ').first}!',
            style: const TextStyle(color: _N.textMuted, fontSize: 13)),
      ]),
    );
  }

  // ── Date chip ─────────────────────────────────────────────────────────────

  Widget _buildDateChip(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final label = d == today
        ? 'Today'
        : d == today.subtract(const Duration(days: 1))
            ? 'Yesterday'
            : '${dt.day}/${dt.month}/${dt.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: _N.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _N.cardBorder),
          ),
          child: Text(label,
              style: const TextStyle(
                color: _N.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              )),
        ),
      ),
    );
  }

  // ── Message row ───────────────────────────────────────────────────────────

  Widget _buildMessageRow(Message msg, bool isMe) {
    final time =
        '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Their avatar (left)
          if (!isMe) ...[
            _miniAvatar(),
            const SizedBox(width: 6),
          ],

          // Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF005C4B) : const Color(0xFF202C33),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: isMe
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : [],
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(msg.content,
                      style: TextStyle(
                        color: isMe ? Colors.white : const Color(0xFFE9F0F4),
                        fontSize: 14.5,
                        height: 1.4,
                      )),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(time,
                          style: TextStyle(
                            color: isMe
                                ? Colors.white.withOpacity(0.65)
                                : const Color(0xFF8696A0),
                            fontSize: 10,
                          )),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _statusIcon(msg.status),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // My avatar (right) — optional spacer
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _miniAvatar() {
    final initials = widget.user.name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: const LinearGradient(
          colors: [_N.indigo, _N.violet],
        ),
      ),
      child: Center(
        child: Text(initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            )),
      ),
    );
  }

  Widget _statusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: Color(0xFFB7D7CE)));
      case MessageStatus.sent:
        return const Icon(Icons.check_rounded,
            size: 13, color: Color(0xFFB7D7CE));
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded,
            size: 13, color: Color(0xFFB7D7CE));
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded, size: 13, color: _N.cyan);
    }
  }

  // ── Attach menu ───────────────────────────────────────────────────────────

  Widget _buildAttachMenu() {
    final options = [
      (Icons.image_outlined, 'Gallery', _N.violet),
      (Icons.insert_drive_file_outlined, 'Document', _N.indigo),
      (Icons.camera_alt_outlined, 'Camera', _N.cyan),
      (Icons.location_on_outlined, 'Location', const Color(0xFFF59E0B)),
      (Icons.person_outline_rounded, 'Contact', const Color(0xFF10B981)),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      color: _N.inputBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: options
            .map((o) => GestureDetector(
                  onTap: () {
                    _toggleAttachMenu();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${o.$2} coming soon',
                          style: const TextStyle(color: _N.textPrimary)),
                      backgroundColor: _N.card,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  },
                  child: Column(children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: o.$3.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: o.$3.withOpacity(0.3)),
                      ),
                      child: Icon(o.$1, color: o.$3, size: 22),
                    ),
                    const SizedBox(height: 6),
                    Text(o.$2,
                        style: const TextStyle(
                          color: _N.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        )),
                  ]),
                ))
            .toList(),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: _N.inputBg,
        border: const Border(
          top: BorderSide(color: _N.inputBorder, width: 1),
        ),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // Attach button
        GestureDetector(
          onTap: _toggleAttachMenu,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _showAttachMenu ? _N.indigo.withOpacity(0.2) : _N.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _showAttachMenu ? _N.indigo : _N.cardBorder,
              ),
            ),
            child: Icon(
              _showAttachMenu ? Icons.close_rounded : Icons.add_rounded,
              color: _showAttachMenu ? _N.indigoLight : _N.textSecondary,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Text field
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 42, maxHeight: 120),
            decoration: BoxDecoration(
              color: _N.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _N.cardBorder),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: _N.textPrimary, fontSize: 14.5),
                  cursorColor: _N.indigoLight,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Write a message…',
                    hintStyle: TextStyle(color: _N.textMuted, fontSize: 14.5),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(14, 11, 4, 11),
                    isDense: true,
                  ),
                ),
              ),
              // Emoji button
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 6),
                child: GestureDetector(
                  onTap: () {
                    final text = _messageController.text;
                    final selection = _messageController.selection;
                    final insertAt =
                        selection.isValid ? selection.start : text.length;
                    final updatedText =
                        text.replaceRange(insertAt, insertAt, ' 😊');
                    _messageController.value = TextEditingValue(
                      text: updatedText,
                      selection:
                          TextSelection.collapsed(offset: updatedText.length),
                    );
                  },
                  child: const Icon(Icons.emoji_emotions_outlined,
                      color: _N.textMuted, size: 20),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 8),

        // Send / mic button
        GestureDetector(
          onTap: _isTyping
              ? _sendMessage
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Hold to record voice notes is not enabled yet.')),
                  );
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: _isTyping
                  ? const LinearGradient(
                      colors: [_N.indigo, _N.violet],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: _isTyping ? null : _N.card,
              border: _isTyping ? null : Border.all(color: _N.cardBorder),
              boxShadow: _isTyping
                  ? [
                      BoxShadow(
                        color: _N.indigo.withOpacity(0.5),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Icon(
              _isTyping ? Icons.send_rounded : Icons.mic_none_rounded,
              color: _isTyping ? Colors.white : _N.textSecondary,
              size: 20,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── WhatsApp-style wallpaper painter ──────────────────────────────────────────
class _WhatsAppWallpaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0B141A),
    );

    final topGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF1F5D4B).withOpacity(0.34),
          const Color(0xFF0B141A).withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.84, size.height * 0.12),
        radius: size.shortestSide * 0.8,
      ));

    final bottomGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF123B31).withOpacity(0.28),
          const Color(0xFF0B141A).withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.1, size.height * 0.92),
        radius: size.shortestSide * 0.85,
      ));

    canvas.drawRect(Offset.zero & size, topGlow);
    canvas.drawRect(Offset.zero & size, bottomGlow);

    const spacing = 92.0;
    final doodlePaint = Paint()
      ..color = const Color(0xFFB7D7CE).withOpacity(0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    for (double y = -spacing; y < size.height + spacing; y += spacing) {
      for (double x = -spacing; x < size.width + spacing; x += spacing) {
        final offset = Offset(x, y);
        canvas.drawCircle(offset, 6, doodlePaint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: offset, width: 18, height: 12),
            const Radius.circular(4),
          ),
          doodlePaint,
        );
        canvas.drawLine(
          offset + const Offset(-10, 10),
          offset + const Offset(10, -10),
          doodlePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WhatsAppWallpaperPainter old) => false;
}
