import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/models/friend_request.dart';
import 'package:multilingual_chat_app/services/auth_service.dart';
import 'package:multilingual_chat_app/screens/chat_list_screen.dart';

// ── Design tokens (mirrors _N in home_screen) ─────────────────────────────
class _N {
  static const bg = Color(0xFF0D0E1A);
  static const surface = Color(0xFF151626);
  static const card = Color(0xFF1C1E31);
  static const cardBorder = Color(0xFF252842);
  static const indigo = Color(0xFF6366F1);
  static const indigoLight = Color(0xFF818CF8);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFFB7185);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);
}

// ── Providers ─────────────────────────────────────────────────────────────
final incomingRequestsProvider =
    FutureProvider<List<FriendRequest>>((ref) async {
  final authService = AuthService();
  return authService.getIncomingRequests();
});

final outgoingRequestsProvider =
    FutureProvider<List<FriendRequest>>((ref) async {
  final authService = AuthService();
  return authService.getOutgoingRequests();
});

// ── Requests Screen ────────────────────────────────────────────────────────
class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(incomingRequestsProvider);
    ref.invalidate(outgoingRequestsProvider);
    ref.invalidate(chatListProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _IncomingTab(onRefresh: _refresh),
              _OutgoingTab(onRefresh: _refresh),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _N.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _N.cardBorder),
      ),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(
          color: _N.indigo,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: _N.indigo.withOpacity(0.4), blurRadius: 8),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: _N.textMuted,
        labelStyle:
            const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_rounded, size: 15),
                SizedBox(width: 6),
                Text('Incoming'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.send_rounded, size: 15),
                SizedBox(width: 6),
                Text('Sent'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Incoming Tab ───────────────────────────────────────────────────────────
class _IncomingTab extends ConsumerWidget {
  final VoidCallback onRefresh;
  const _IncomingTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(incomingRequestsProvider);

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _N.indigo)),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: _N.textMuted, size: 40),
            const SizedBox(height: 12),
            Text('Error loading requests',
                style: const TextStyle(
                    color: _N.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextButton(
              onPressed: onRefresh,
              child:
                  const Text('Retry', style: TextStyle(color: _N.indigoLight)),
            ),
          ],
        ),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return _emptyState(
            Icons.mark_email_unread_outlined,
            'No incoming requests',
            'When someone sends you a friend request,\nit will appear here.',
          );
        }
        return RefreshIndicator(
          color: _N.indigo,
          backgroundColor: _N.card,
          onRefresh: () async => onRefresh(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _IncomingRequestCard(
              request: requests[i],
              onAction: onRefresh,
            ),
          ),
        );
      },
    );
  }
}

// ── Outgoing Tab ───────────────────────────────────────────────────────────
class _OutgoingTab extends ConsumerWidget {
  final VoidCallback onRefresh;
  const _OutgoingTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(outgoingRequestsProvider);

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _N.indigo)),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: _N.textMuted, size: 40),
            const SizedBox(height: 12),
            Text('Error loading requests',
                style: const TextStyle(
                    color: _N.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextButton(
              onPressed: onRefresh,
              child:
                  const Text('Retry', style: TextStyle(color: _N.indigoLight)),
            ),
          ],
        ),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return _emptyState(
            Icons.send_outlined,
            'No sent requests',
            'Tap the + button and enter a\nProfile ID to send a friend request.',
          );
        }
        return RefreshIndicator(
          color: _N.indigo,
          backgroundColor: _N.card,
          onRefresh: () async => onRefresh(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _OutgoingRequestCard(
              request: requests[i],
              onAction: onRefresh,
            ),
          ),
        );
      },
    );
  }
}

// ── Incoming Request Card ──────────────────────────────────────────────────
class _IncomingRequestCard extends ConsumerStatefulWidget {
  final FriendRequest request;
  final VoidCallback onAction;
  const _IncomingRequestCard({required this.request, required this.onAction});

  @override
  ConsumerState<_IncomingRequestCard> createState() =>
      _IncomingRequestCardState();
}

class _IncomingRequestCardState extends ConsumerState<_IncomingRequestCard> {
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await AuthService().acceptRequest(widget.request.id);
      _snack('✅ Friend request accepted! You can now chat.');
      widget.onAction();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    try {
      await AuthService().cancelRequest(widget.request.id);
      _snack('Request declined.');
      widget.onAction();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: _N.textPrimary)),
      backgroundColor: _N.card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final sender = req.senderUser;
    final name = sender?.name ?? 'Unknown';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final imageUrl = sender?.profileImageUrl;
    final profileId = sender?.profileId ?? '';

    return _RequestCard(
      initials: initials,
      imageUrl: imageUrl,
      name: name,
      profileId: profileId,
      subtitle: 'Wants to connect with you',
      subtitleColor: _N.indigoLight,
      createdAt: req.createdAt,
      trailing: _busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: _N.indigoLight),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionBtn(
                  icon: Icons.close_rounded,
                  color: _N.red,
                  onTap: _decline,
                  tooltip: 'Decline',
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.check_rounded,
                  color: _N.green,
                  onTap: _accept,
                  tooltip: 'Accept',
                ),
              ],
            ),
    );
  }
}

// ── Outgoing Request Card ──────────────────────────────────────────────────
class _OutgoingRequestCard extends ConsumerStatefulWidget {
  final FriendRequest request;
  final VoidCallback onAction;
  const _OutgoingRequestCard({required this.request, required this.onAction});

  @override
  ConsumerState<_OutgoingRequestCard> createState() =>
      _OutgoingRequestCardState();
}

class _OutgoingRequestCardState extends ConsumerState<_OutgoingRequestCard> {
  bool _busy = false;

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      await AuthService().cancelRequest(widget.request.id);
      _snack('Request cancelled.');
      widget.onAction();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: _N.textPrimary)),
      backgroundColor: _N.card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final receiver = req.receiverUser;
    final name = receiver?.name ?? 'Unknown';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final imageUrl = receiver?.profileImageUrl;
    final profileId = receiver?.profileId ?? '';

    String statusLabel;
    Color statusColor;
    switch (req.status) {
      case RequestStatus.accepted:
        statusLabel = 'Accepted';
        statusColor = _N.green;
        break;
      case RequestStatus.cancelled:
        statusLabel = 'Cancelled';
        statusColor = _N.red;
        break;
      default:
        statusLabel = 'Pending…';
        statusColor = _N.indigoLight;
    }

    return _RequestCard(
      initials: initials,
      imageUrl: imageUrl,
      name: name,
      profileId: profileId,
      subtitle: statusLabel,
      subtitleColor: statusColor,
      createdAt: req.createdAt,
      trailing: req.status == RequestStatus.pending
          ? (_busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: _N.textMuted),
                )
              : _ActionBtn(
                  icon: Icons.cancel_outlined,
                  color: _N.textMuted,
                  onTap: _cancel,
                  tooltip: 'Cancel request',
                ))
          : null,
    );
  }
}

// ── Shared Request Card ────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final String initials;
  final String? imageUrl;
  final String name;
  final String profileId;
  final String subtitle;
  final Color subtitleColor;
  final DateTime createdAt;
  final Widget? trailing;

  const _RequestCard({
    required this.initials,
    this.imageUrl,
    required this.name,
    required this.profileId,
    required this.subtitle,
    required this.subtitleColor,
    required this.createdAt,
    this.trailing,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _N.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _N.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _N.indigo.withOpacity(0.3),
                  _N.violet.withOpacity(0.15),
                ],
              ),
            ),
            child: ClipOval(
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? Image.network(
                      imageUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _initialsWidget,
                    )
                  : _initialsWidget,
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _N.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (profileId.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    profileId,
                    style: const TextStyle(
                      color: _N.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: subtitleColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: subtitleColor.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _timeAgo(createdAt),
                      style: const TextStyle(
                          color: _N.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }

  Widget get _initialsWidget => Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: _N.indigoLight,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

// ── Action Button ──────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────
Widget _emptyState(IconData icon, String title, String body) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: _N.card,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _N.cardBorder),
            ),
            child: Icon(icon, size: 38, color: _N.textMuted),
          ),
          const SizedBox(height: 18),
          Text(title,
              style: const TextStyle(
                color: _N.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 8),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _N.textMuted,
                fontSize: 13,
                height: 1.5,
              )),
        ],
      ),
    ),
  );
}
