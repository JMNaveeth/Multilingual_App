import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:multilingual_chat_app/models/call_history_entry.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';
import 'package:multilingual_chat_app/providers/call_history_provider.dart';
import 'package:multilingual_chat_app/screens/chat_list_screen.dart';
import 'package:multilingual_chat_app/screens/discover_screen.dart';
import 'package:multilingual_chat_app/screens/profile_screen.dart';

// ── Nexus Design Tokens ─────────────────────────────────────────────────────
class _N {
  static const bg = Color(0xFF0D0E1A);
  static const surface = Color(0xFF151626);
  static const card = Color(0xFF1C1E31);
  static const cardBorder = Color(0xFF252842);
  static const indigo = Color(0xFF6366F1);
  static const indigoLight = Color(0xFF818CF8);
  static const violet = Color(0xFF8B5CF6);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);
  static const navBg = Color(0xFF10111F);
  static const navBorder = Color(0xFF1E2035);
  static const segBg = Color(0xFF1C1E31);
  static const segActive = Color(0xFF6366F1);
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  int _segmentIndex = 0;
  int _bottomIndex = 0;

  late final AnimationController _glowController;
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _glowController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _N.bg,
      extendBodyBehindAppBar: true,
      body: FadeTransition(
        opacity:
            CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
        child: _buildBody(),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _bottomIndex == 0 ? _buildAddFAB() : null,
    );
  }

  // ── Body router ───────────────────────────────────────────────────────────
  Widget _buildBody() {
    switch (_bottomIndex) {
      case 3:
        return const ProfileScreen();
      case 1:
        return Column(children: [
          _buildHeader(title: 'Discover'),
          const Expanded(child: RepaintBoundary(child: DiscoverScreen())),
        ]);
      case 2:
        return Column(children: [
          _buildHeader(title: 'Voice'),
          Expanded(child: _buildCallHistoryContent()),
        ]);
      default:
        return _buildMessagesView();
    }
  }

  Widget _buildMessagesView() {
    return Column(children: [
      _buildHeader(title: 'ec communication'),
      const SizedBox(height: 6),
      _buildSearchBar(),
      const SizedBox(height: 12),
      _buildSegmentControl(),
      const SizedBox(height: 4),
      Expanded(child: _buildSegmentContent()),
    ]);
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader({required String title, bool showActions = true}) {
    final userName = ref.read(authProvider).value?.name;
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 12,
        bottom: 14,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF111224), Color(0x000D0E1A)],
        ),
      ),
      child: Row(children: [
        // Animated logo
        AnimatedBuilder(
          animation: _glowController,
          builder: (_, __) => Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [_N.indigo, _N.violet],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      _N.indigo.withOpacity(0.4 + _glowController.value * 0.3),
                  blurRadius: 12 + _glowController.value * 8,
                  spreadRadius: 1,
                )
              ],
            ),
            child:
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 12),

        // Title & subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                    color: _N.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  )),
              if (userName != null)
                Text(userName,
                    style: const TextStyle(
                      color: _N.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    )),
            ],
          ),
        ),

        if (showActions) _moreMenu(),
      ]),
    );
  }

  Widget _moreMenu() => PopupMenuButton<String>(
        color: _N.card,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _N.cardBorder),
        ),
        icon: Container(
          width: 38,
          height: 38,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: _N.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _N.cardBorder),
          ),
          child: const Icon(Icons.more_horiz_rounded,
              color: _N.textSecondary, size: 20),
        ),
        onSelected: (v) async {
          if (v == 'logout') await ref.read(authProvider.notifier).logout();
        },
        itemBuilder: (_) => [
          _popItem(Icons.group_add_outlined, 'New group'),
          _popItem(Icons.devices_outlined, 'Linked devices'),
          _popItem(Icons.star_border_rounded, 'Starred'),
          _popItem(Icons.tune_rounded, 'Settings'),
          _popItem(Icons.logout_rounded, 'Sign out', value: 'logout'),
        ],
      );

  PopupMenuItem<String> _popItem(IconData icon, String label,
          {String? value}) =>
      PopupMenuItem<String>(
        value: value ?? label,
        child: Row(children: [
          Icon(icon, size: 18, color: _N.indigoLight),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(color: _N.textPrimary, fontSize: 14)),
        ]),
      );

  // ── Search bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: _N.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _N.cardBorder),
          ),
          child: Row(children: [
            const SizedBox(width: 14),
            const Icon(Icons.search_rounded, color: _N.textMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                style: const TextStyle(color: _N.textPrimary, fontSize: 14),
                cursorColor: _N.indigo,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search conversations…',
                  hintStyle: TextStyle(color: _N.textMuted, fontSize: 14),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ]),
        ),
      );

  // ── Segment control ───────────────────────────────────────────────────────
  static const _segLabels = ['Messages', 'Moments', 'Calls'];
  static const _segIcons = [
    Icons.forum_outlined,
    Icons.auto_awesome_outlined,
    Icons.mic_none_rounded,
  ];

  Widget _buildSegmentControl() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _N.segBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _N.cardBorder),
          ),
          child: Row(
            children: List.generate(_segLabels.length, (i) {
              final active = _segmentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _segmentIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: active ? _N.segActive : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                  color: _N.indigo.withOpacity(0.4),
                                  blurRadius: 8)
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_segIcons[i],
                            size: 15,
                            color: active ? Colors.white : _N.textMuted),
                        const SizedBox(width: 5),
                        Text(_segLabels[i],
                            style: TextStyle(
                              color: active ? Colors.white : _N.textMuted,
                              fontSize: 12.5,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      );

  Widget _buildSegmentContent() {
    switch (_segmentIndex) {
      case 0:
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: const ChatListScreen(),
          ),
        );
      case 1:
        return _buildComingSoon(Icons.auto_awesome_outlined, 'Moments');
      case 2:
        return _buildCallHistoryContent();
      default:
        return const SizedBox();
    }
  }

  // ── Add FAB ───────────────────────────────────────────────────────────────
  Widget _buildAddFAB() => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [_N.indigo, _N.violet],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _N.indigo.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _openNewChat,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
      );

  // ── Bottom Nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final items = [
      (Icons.forum_outlined, Icons.forum_rounded, 'Messages'),
      (Icons.explore_outlined, Icons.explore_rounded, 'Discover'),
      (Icons.graphic_eq_rounded, Icons.graphic_eq_rounded, 'Calls'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: _N.navBg,
        border: Border(top: BorderSide(color: _N.navBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: List.generate(items.length, (i) {
              final active = _bottomIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _bottomIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: active
                              ? _N.indigo.withOpacity(0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          active ? items[i].$2 : items[i].$1,
                          color: active ? _N.indigoLight : _N.textMuted,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(items[i].$3,
                          style: TextStyle(
                            color: active ? _N.indigoLight : _N.textMuted,
                            fontSize: 10.5,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w400,
                          )),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildComingSoon(IconData icon, String label) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _N.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _N.cardBorder),
            ),
            child: Icon(icon, size: 36, color: _N.textMuted),
          ),
          const SizedBox(height: 16),
          Text(label,
              style: const TextStyle(
                color: _N.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 6),
          const Text('Coming soon',
              style: TextStyle(color: _N.textMuted, fontSize: 13)),
        ]),
      );

  Widget _buildCallHistoryContent() {
    final currentUser = ref.watch(authProvider).value;
    if (currentUser == null) {
      return _buildComingSoon(Icons.mic_none_rounded, 'Calls');
    }

    final historyAsync = ref.watch(callHistoryProvider(currentUser.id));
    return historyAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: _N.indigo),
      ),
      error: (error, _) => Center(
        child: Text(
          'Could not load call history',
          style: const TextStyle(color: _N.textSecondary, fontSize: 13),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return _buildComingSoon(Icons.graphic_eq_rounded, 'Voice Calls');
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) {
            final entry = entries[index];
            final isMissed = entry.result == CallResult.missed ||
                entry.result == CallResult.declined;
            final statusColor = isMissed ? const Color(0xFFFB7185) : _N.indigo;

            // rich card with avatar, metadata, and quick actions
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  // open details or call back
                  // placeholder: show details bottom sheet
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: _N.surface,
                    shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (_) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundImage: entry.peerProfileImageUrl !=
                                            null &&
                                        entry.peerProfileImageUrl!.isNotEmpty
                                    ? NetworkImage(entry.peerProfileImageUrl!)
                                    : null,
                                backgroundColor: _N.navBg,
                                child: entry.peerProfileImageUrl == null ||
                                        entry.peerProfileImageUrl!.isEmpty
                                    ? Text(
                                        entry.peerName.isNotEmpty
                                            ? entry.peerName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            color: _N.textPrimary,
                                            fontWeight: FontWeight.w700))
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(entry.peerName,
                                        style: const TextStyle(
                                            color: _N.textPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text(
                                        '${_callDirectionLabel(entry.direction)} • ${_callResultLabel(entry.result)}',
                                        style: const TextStyle(
                                            color: _N.textSecondary)),
                                  ],
                                ),
                              ),
                              Text(_formatDuration(entry.durationSeconds),
                                  style:
                                      const TextStyle(color: _N.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text('Started: ${_formatCallTime(entry.startedAt)}',
                              style: const TextStyle(color: _N.textMuted)),
                          const SizedBox(height: 6),
                          Text(
                              'Ended: ${entry.endedAt != null ? _formatCallTime(entry.endedAt!) : '-'}',
                              style: const TextStyle(color: _N.textMuted)),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: _N.indigo),
                                  onPressed: () {
                                    // call back (voice)
                                  },
                                  icon: const Icon(Icons.call_rounded),
                                  label: const Text('Call Back'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: _N.textPrimary,
                                      side: BorderSide(color: _N.cardBorder)),
                                  onPressed: () {},
                                  icon: const Icon(Icons.info_outline_rounded),
                                  label: const Text('Details'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  );
                },
                child: Ink(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _N.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _N.cardBorder),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar with gradient ring
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: isMissed
                              ? LinearGradient(colors: [
                                  const Color(0xFFFB7185).withOpacity(0.12),
                                  Colors.transparent
                                ])
                              : LinearGradient(colors: [
                                  _N.indigo.withOpacity(0.14),
                                  _N.violet.withOpacity(0.06)
                                ]),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: CircleAvatar(
                            radius: 22,
                            backgroundImage:
                                entry.peerProfileImageUrl != null &&
                                        entry.peerProfileImageUrl!.isNotEmpty
                                    ? NetworkImage(entry.peerProfileImageUrl!)
                                    : null,
                            backgroundColor: _N.navBg,
                            child: entry.peerProfileImageUrl == null ||
                                    entry.peerProfileImageUrl!.isEmpty
                                ? Text(
                                    entry.peerName.isNotEmpty
                                        ? entry.peerName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: _N.textPrimary,
                                        fontWeight: FontWeight.w700))
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(entry.peerName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: _N.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color:
                                              statusColor.withOpacity(0.16))),
                                  child: Row(children: [
                                    Icon(
                                        entry.callType == 'video'
                                            ? Icons.videocam_rounded
                                            : Icons.call_rounded,
                                        size: 14,
                                        color: statusColor),
                                    const SizedBox(width: 6),
                                    Text(_callResultLabel(entry.result),
                                        style: TextStyle(
                                            color: statusColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700))
                                  ]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                                '${_callDirectionLabel(entry.direction)} • ${_formatCallTime(entry.startedAt)}',
                                style: TextStyle(
                                    color: _N.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_formatDuration(entry.durationSeconds),
                              style: const TextStyle(
                                  color: _N.textSecondary,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Row(children: [
                            IconButton(
                              onPressed: () {
                                // quick voice callback
                              },
                              icon: Icon(Icons.call_rounded, color: _N.indigo),
                              splashRadius: 20,
                            ),
                            IconButton(
                              onPressed: () {
                                // quick video callback
                              },
                              icon: Icon(Icons.videocam_rounded,
                                  color: _N.violet),
                              splashRadius: 20,
                            ),
                          ])
                        ],
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _callDirectionLabel(CallDirection direction) {
    return direction == CallDirection.incoming ? 'Incoming' : 'Outgoing';
  }

  String _callResultLabel(CallResult result) {
    switch (result) {
      case CallResult.completed:
        return 'Completed';
      case CallResult.missed:
        return 'Missed';
      case CallResult.declined:
        return 'Declined';
      case CallResult.cancelled:
        return 'Cancelled';
    }
  }

  String _formatCallTime(DateTime dateTime) {
    return DateFormat('MMM d, h:mm a').format(dateTime);
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) {
      return '0:00';
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _openNewChat() async {
    await _showAddFriendDialog();
  }

  Future<void> _showAddFriendDialog() async {
    final profileIdController = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          bool isAdding = false;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: _N.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: _N.cardBorder),
                ),
                title: const Text(
                  'Add Friend',
                  style: TextStyle(
                    color: _N.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter the other user\'s Profile ID like EC-12345678.',
                      style: TextStyle(color: _N.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: profileIdController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(color: _N.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'EC-12345678',
                        hintStyle:
                            const TextStyle(color: _N.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: _N.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _N.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _N.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: _N.indigoLight, width: 1.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'After confirming, the user will appear in your chat list.',
                      style: TextStyle(color: _N.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isAdding
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: isAdding
                        ? null
                        : () async {
                            final entered = profileIdController.text.trim();
                            if (entered.isEmpty) {
                              _snack('Enter a Profile ID first');
                              return;
                            }

                            setDialogState(() => isAdding = true);
                            try {
                              final friend = await ref
                                  .read(authProvider.notifier)
                                  .addFriendByProfileId(entered);

                              ref.invalidate(chatListProvider);

                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                                _snack('Added ${friend.name} to your friends');
                              }
                            } catch (e) {
                              if (mounted) {
                                final raw = e.toString();
                                final cleanMsg = raw.startsWith('Exception: ')
                                    ? raw.substring(11)
                                    : raw;
                                _snack(cleanMsg);
                              }
                            } finally {
                              if (dialogContext.mounted) {
                                setDialogState(() => isAdding = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _N.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isAdding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Confirm'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      profileIdController.dispose();
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
}
