// =============================================================================
// discover_screen.dart
// Production-grade Discover Screen — Real-time Multiplayer Gaming
//
// Architecture:
//   • DiscoverScreen          — Root widget, consumes DiscoverController
//   • DiscoverController      — ChangeNotifier: owns all state + WebSocket stub
//   • PresenceService         — Singleton: stream-based online presence updates
//   • GameInviteService       — Handles challenge send / receive flow
//   • Models: MiniGame, Friend, ChallengeRequest
//   • Widgets: _GameCard, _FriendTile, _PartyBanner, _SectionHeader,
//              _PulsingDot, _ShimmerBox, _ToastOverlay
// =============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Design tokens
// ---------------------------------------------------------------------------
abstract class _D {
  static const bg          = Color(0xFF080A14);
  static const surface     = Color(0xFF111320);
  static const card        = Color(0xFF181B2E);
  static const cardBorder  = Color(0xFF242742);
  static const cardHover   = Color(0xFF1E2238);

  static const indigo      = Color(0xFF6366F1);
  static const indigoDeep  = Color(0xFF4F52D4);
  static const indigoLight = Color(0xFF818CF8);
  static const violet      = Color(0xFF8B5CF6);
  static const violetLight = Color(0xFFA78BFA);
  static const cyan        = Color(0xFF22D3EE);
  static const cyanLight   = Color(0xFF67E8F9);
  static const emerald     = Color(0xFF10B981);
  static const emeraldGlow = Color(0xFF34D399);
  static const amber       = Color(0xFFF59E0B);
  static const amberLight  = Color(0xFFFBBF24);
  static const rose        = Color(0xFFF43F5E);

  static const textPrimary   = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted     = Color(0xFF475569);
  static const textDim       = Color(0xFF2D3748);

  static const shimmerBase      = Color(0xFF1C2030);
  static const shimmerHighlight = Color(0xFF252A40);

  static const Duration fast   = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow   = Duration(milliseconds: 480);

  static const BorderRadius radiusSm  = BorderRadius.all(Radius.circular(10));
  static const BorderRadius radiusMd  = BorderRadius.all(Radius.circular(14));
  static const BorderRadius radiusLg  = BorderRadius.all(Radius.circular(18));
  static const BorderRadius radiusXl  = BorderRadius.all(Radius.circular(24));
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

enum GameTag { fast, strategy, memory, classic }

class MiniGame {
  const MiniGame({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tag,
    this.playersOnline = 0,
    this.isNew = false,
  });

  final String   id;
  final String   name;
  final String   subtitle;
  final IconData icon;
  final Color    color;
  final GameTag  tag;
  final int      playersOnline;
  final bool     isNew;
}

enum ChallengeStatus { idle, sending, sent, accepted, declined }

class Friend {
  const Friend({
    required this.id,
    required this.name,
    required this.avatarSeed,
    required this.isOnline,
    required this.lastSeen,
    this.challengeStatus = ChallengeStatus.idle,
    this.currentGame,
  });

  final String          id;
  final String          name;
  final int             avatarSeed;
  final bool            isOnline;
  final DateTime        lastSeen;
  final ChallengeStatus challengeStatus;
  final String?         currentGame;

  Friend copyWith({
    bool?            isOnline,
    ChallengeStatus? challengeStatus,
    String?          currentGame,
  }) =>
      Friend(
        id:              id,
        name:            name,
        avatarSeed:      avatarSeed,
        isOnline:        isOnline ?? this.isOnline,
        lastSeen:        lastSeen,
        challengeStatus: challengeStatus ?? this.challengeStatus,
        currentGame:     currentGame ?? this.currentGame,
      );
}

// ---------------------------------------------------------------------------
// Presence Service — real WebSocket layer would replace the timer here
// ---------------------------------------------------------------------------

class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  final _presenceController = StreamController<Map<String, bool>>.broadcast();
  Stream<Map<String, bool>> get presenceStream => _presenceController.stream;

  Timer? _heartbeatTimer;
  final _rng = math.Random();

  /// Call once on app start. In production, open a WS to
  /// wss://your-api/presence and pipe incoming events here.
  void connect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      // Simulate random presence changes (replace with real WS events)
      _presenceController.add({
        'friend_1': _rng.nextBool() || _rng.nextBool(), // weighted online
        'friend_2': _rng.nextDouble() > 0.6,
        'friend_3': true,
        'friend_4': _rng.nextBool(),
      });
    });
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _presenceController.close();
  }
}

// ---------------------------------------------------------------------------
// Game Invite Service
// ---------------------------------------------------------------------------

class GameInviteService {
  /// Sends a challenge request. Replace body with real HTTP/WS call.
  Future<bool> sendChallenge({
    required String fromUserId,
    required String toFriendId,
    required String gameId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 900)); // simulated RTT
    return math.Random().nextDouble() > 0.15; // 85% success rate simulation
  }
}

// ---------------------------------------------------------------------------
// Discover Controller (ChangeNotifier — drop-in with Provider or Riverpod)
// ---------------------------------------------------------------------------

class DiscoverController extends ChangeNotifier {
  DiscoverController({
    PresenceService?  presenceService,
    GameInviteService? inviteService,
  })  : _presence = presenceService ?? PresenceService.instance,
        _invite   = inviteService   ?? GameInviteService();

  final PresenceService  _presence;
  final GameInviteService _invite;
  StreamSubscription<Map<String, bool>>? _presenceSub;

  // ── State ──────────────────────────────────────────────────────────────
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _toastMessage;
  String? get toastMessage => _toastMessage;
  bool    _toastIsError = false;
  bool    get toastIsError => _toastIsError;

  List<MiniGame> _games = [];
  List<MiniGame> get games => _games;

  List<Friend> _friends = [];
  List<Friend> get friends => _friends;

  int get onlineFriendCount => _friends.where((f) => f.isOnline).length;

  // ── Lifecycle ──────────────────────────────────────────────────────────
  Future<void> init() async {
    await _loadInitialData();
    _presence.connect();
    _presenceSub = _presence.presenceStream.listen(_onPresenceUpdate);
  }

  Future<void> _loadInitialData() async {
    // Simulates a network fetch; replace with actual API call
    await Future.delayed(const Duration(milliseconds: 600));
    _games = _defaultGames;
    _friends = _defaultFriends;
    _isLoading = false;
    notifyListeners();
  }

  void _onPresenceUpdate(Map<String, bool> update) {
    bool changed = false;
    _friends = _friends.map((f) {
      final newStatus = update[f.id];
      if (newStatus != null && newStatus != f.isOnline) {
        changed = true;
        return f.copyWith(isOnline: newStatus);
      }
      return f;
    }).toList();
    if (changed) notifyListeners();
  }

  // ── Actions ────────────────────────────────────────────────────────────
  Future<void> sendChallenge(Friend friend, {String gameId = 'any'}) async {
    if (!friend.isOnline) return;
    HapticFeedback.lightImpact();

    // Set sending state
    _updateFriendStatus(friend.id, ChallengeStatus.sending);

    final success = await _invite.sendChallenge(
      fromUserId: 'current_user',
      toFriendId: friend.id,
      gameId: gameId,
    );

    if (success) {
      HapticFeedback.mediumImpact();
      _updateFriendStatus(friend.id, ChallengeStatus.sent);
      _showToast('Challenge sent to ${friend.name}! ⚡');
      // Auto-reset after 5 s
      Future.delayed(const Duration(seconds: 5), () {
        _updateFriendStatus(friend.id, ChallengeStatus.idle);
      });
    } else {
      HapticFeedback.heavyImpact();
      _updateFriendStatus(friend.id, ChallengeStatus.idle);
      _showToast('Could not reach ${friend.name}. Try again.', isError: true);
    }
  }

  void launchGame(MiniGame game) {
    HapticFeedback.selectionClick();
    _showToast('${game.name} is launching soon 🎮');
  }

  void createPartyRoom() {
    HapticFeedback.mediumImpact();
    _showToast('Party rooms dropping next update 🎉');
  }

  void clearToast() {
    _toastMessage = null;
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  void _updateFriendStatus(String id, ChallengeStatus status) {
    _friends = _friends
        .map((f) => f.id == id ? f.copyWith(challengeStatus: status) : f)
        .toList();
    notifyListeners();
  }

  void _showToast(String message, {bool isError = false}) {
    _toastMessage = message;
    _toastIsError = isError;
    notifyListeners();
    Future.delayed(const Duration(seconds: 3), clearToast);
  }

  @override
  void dispose() {
    _presenceSub?.cancel();
    _presence.disconnect();
    super.dispose();
  }

  // ── Default data ───────────────────────────────────────────────────────
  static const _defaultGames = [
    MiniGame(
      id:            'word_sprint',
      name:          'Word Sprint',
      subtitle:      'Type fast. Beat your friend.',
      icon:          Icons.keyboard_rounded,
      color:         _D.indigo,
      tag:           GameTag.fast,
      playersOnline: 214,
      isNew:         false,
    ),
    MiniGame(
      id:            'emoji_match',
      name:          'Emoji Match',
      subtitle:      'Memory game in 60 s.',
      icon:          Icons.emoji_emotions_outlined,
      color:         _D.violet,
      tag:           GameTag.memory,
      playersOnline: 87,
      isNew:         true,
    ),
    MiniGame(
      id:            'number_duel',
      name:          'Number Duel',
      subtitle:      'Pick bigger. Go faster.',
      icon:          Icons.bolt_rounded,
      color:         _D.cyan,
      tag:           GameTag.fast,
      playersOnline: 163,
    ),
    MiniGame(
      id:            'tic_tac_toe',
      name:          'Tic Tac Toe',
      subtitle:      'Classic 1v1 quick game.',
      icon:          Icons.grid_3x3_rounded,
      color:         _D.emerald,
      tag:           GameTag.classic,
      playersOnline: 56,
    ),
  ];

  static final _defaultFriends = [
    Friend(
      id:         'friend_1',
      name:       'John',
      avatarSeed: 1,
      isOnline:   true,
      lastSeen:   DateTime.now(),
    ),
    Friend(
      id:         'friend_2',
      name:       'Marie',
      avatarSeed: 2,
      isOnline:   false,
      lastSeen:   DateTime.now().subtract(const Duration(minutes: 23)),
    ),
    Friend(
      id:         'friend_3',
      name:       'Satoshi',
      avatarSeed: 3,
      isOnline:   true,
      lastSeen:   DateTime.now(),
      currentGame: 'Word Sprint',
    ),
    Friend(
      id:         'friend_4',
      name:       'Nadia',
      avatarSeed: 4,
      isOnline:   true,
      lastSeen:   DateTime.now(),
    ),
    Friend(
      id:         'friend_5',
      name:       'Luca',
      avatarSeed: 5,
      isOnline:   false,
      lastSeen:   DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];
}

// ---------------------------------------------------------------------------
// Root Screen — wires controller with InheritedNotifier pattern
// ---------------------------------------------------------------------------

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with TickerProviderStateMixin {

  late final DiscoverController _controller;
  late final AnimationController _staggerCtrl;
  late final AnimationController _toastCtrl;
  late final Animation<double>   _toastAnim;

  @override
  void initState() {
    super.initState();

    _controller = DiscoverController();
    _controller.addListener(_onControllerChange);
    _controller.init();

    // Staggered reveal on load
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Toast slide-up
    _toastCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _toastAnim = CurvedAnimation(parent: _toastCtrl, curve: Curves.easeOutCubic);
  }

  void _onControllerChange() {
    if (!_controller.isLoading && !_staggerCtrl.isAnimating) {
      _staggerCtrl.forward(from: 0);
    }
    if (_controller.toastMessage != null) {
      _toastCtrl.forward(from: 0);
    } else {
      _toastCtrl.reverse();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChange)
      ..dispose();
    _staggerCtrl.dispose();
    _toastCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _D.bg,
      body: Stack(
        children: [
          _buildBody(),
          if (_controller.toastMessage != null)
            _ToastOverlay(
              message:  _controller.toastMessage!,
              isError:  _controller.toastIsError,
              animation: _toastAnim,
              onDismiss: _controller.clearToast,
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return const _LoadingShimmer();
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── Online badge ───────────────────────────────────────────
              _staggerChild(
                0,
                child: _OnlineBadge(count: _controller.onlineFriendCount),
              ),
              const SizedBox(height: 20),

              // ── Mini-games section ─────────────────────────────────────
              _staggerChild(
                1,
                child: const _SectionHeader(
                  title:    'Mini games',
                  subtitle: 'Quick 1v1 games · tap to play',
                ),
              ),
              const SizedBox(height: 12),
              _staggerChild(
                2,
                child: GridView.builder(
                  itemCount:   _controller.games.length,
                  shrinkWrap:  true,
                  physics:     const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:   2,
                    mainAxisSpacing:  10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.98,
                  ),
                  itemBuilder: (_, i) => _GameCard(
                    game:       _controller.games[i],
                    onTap:      () => _controller.launchGame(_controller.games[i]),
                    tickerProvider: this,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Friends online section ─────────────────────────────────
              _staggerChild(
                3,
                child: _SectionHeader(
                  title:    'Friends online',
                  subtitle: '${_controller.onlineFriendCount} available to play',
                  trailing: _TextButton(
                    label: 'See all',
                    onTap:  () {},
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _staggerChild(
                4,
                child: SizedBox(
                  height: 118,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:         EdgeInsets.zero,
                    itemCount:       _controller.friends.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => _FriendTile(
                      friend:      _controller.friends[i],
                      onChallenge: () => _controller.sendChallenge(
                        _controller.friends[i],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Party banner ───────────────────────────────────────────
              _staggerChild(
                5,
                child: _PartyBanner(onCreate: _controller.createPartyRoom),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  /// Staggered slide-in + fade for each section
  Widget _staggerChild(int index, {required Widget child}) {
    final start  = (index * 0.12).clamp(0.0, 0.85);
    final end    = (start + 0.4).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: _staggerCtrl,
      curve:  Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (_, c) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - curved.value)),
          child: c,
        ),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// _OnlineBadge
// ---------------------------------------------------------------------------

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PulsingDot(color: _D.emerald),
        const SizedBox(width: 8),
        Text(
          '$count friend${count == 1 ? '' : 's'} online now',
          style: const TextStyle(
            color:    _D.emeraldGlow,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _SectionHeader
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String  title;
  final String  subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color:      _D.textPrimary,
                  fontSize:   17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color:    _D.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _GameCard
// ---------------------------------------------------------------------------

class _GameCard extends StatefulWidget {
  const _GameCard({
    required this.game,
    required this.onTap,
    required this.tickerProvider,
  });

  final MiniGame       game;
  final VoidCallback   onTap;
  final TickerProvider tickerProvider;

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard>
    with SingleTickerProviderStateMixin {

  late final AnimationController _pressCtrl;
  late final Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(_)  => _pressCtrl.forward();
  void _onTapUp(_)    { _pressCtrl.reverse(); widget.onTap(); }
  void _onTapCancel() => _pressCtrl.reverse();

  String _tagLabel(GameTag tag) {
    switch (tag) {
      case GameTag.fast:     return 'FAST';
      case GameTag.strategy: return 'STRATEGY';
      case GameTag.memory:   return 'MEMORY';
      case GameTag.classic:  return 'CLASSIC';
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown:   _onTapDown,
        onTapUp:     _onTapUp,
        onTapCancel: _onTapCancel,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color:        _D.card,
            borderRadius: _D.radiusLg,
            border:       Border.all(color: _D.cardBorder),
            boxShadow: [
              BoxShadow(
                color:       g.color.withOpacity(0.06),
                blurRadius:  20,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: icon + badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color:        g.color.withOpacity(0.15),
                      borderRadius: _D.radiusSm,
                    ),
                    child: Icon(g.icon, color: g.color, size: 20),
                  ),
                  const Spacer(),
                  if (g.isNew)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:        _D.rose.withOpacity(0.15),
                        borderRadius: _D.radiusSm,
                        border:       Border.all(
                            color: _D.rose.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color:      _D.rose,
                          fontSize:   9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                g.name,
                maxLines:        1,
                overflow:        TextOverflow.ellipsis,
                style: const TextStyle(
                  color:      _D.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize:   14.5,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),

              // Subtitle
              Text(
                g.subtitle,
                maxLines:  2,
                overflow:  TextOverflow.ellipsis,
                style: const TextStyle(
                  color:    _D.textSecondary,
                  fontSize: 11.5,
                  height:   1.35,
                ),
              ),
              const Spacer(),

              // Footer: online count + tag
              Row(
                children: [
                  Icon(Icons.people_outline_rounded,
                      size: 11, color: _D.textMuted),
                  const SizedBox(width: 3),
                  Text(
                    '${g.playersOnline}',
                    style: const TextStyle(
                        color: _D.textMuted, fontSize: 11),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:        g.color.withOpacity(0.12),
                      borderRadius: _D.radiusSm,
                    ),
                    child: Text(
                      _tagLabel(g.tag),
                      style: TextStyle(
                        color:      g.color,
                        fontSize:   9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Play button
              SizedBox(
                width: double.infinity,
                height: 34,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [g.color, g.color.withOpacity(0.75)],
                    ),
                    borderRadius: _D.radiusSm,
                    boxShadow: [
                      BoxShadow(
                        color:      g.color.withOpacity(0.30),
                        blurRadius: 8,
                        offset:     const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Play',
                      style: TextStyle(
                        color:      Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize:   13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FriendTile
// ---------------------------------------------------------------------------

class _FriendTile extends StatefulWidget {
  const _FriendTile({required this.friend, required this.onChallenge});
  final Friend       friend;
  final VoidCallback onChallenge;

  @override
  State<_FriendTile> createState() => _FriendTileState();
}

class _FriendTileState extends State<_FriendTile>
    with SingleTickerProviderStateMixin {

  late final AnimationController _btnCtrl;

  @override
  void initState() {
    super.initState();
    _btnCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _btnCtrl.dispose();
    super.dispose();
  }

  static const _avatarColors = [
    _D.indigo, _D.violet, _D.cyan, _D.emerald, _D.amber,
  ];

  Color get _avatarColor =>
      _avatarColors[widget.friend.avatarSeed % _avatarColors.length];

  String _lastSeenLabel() {
    final diff = DateTime.now().difference(widget.friend.lastSeen);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final f      = widget.friend;
    final status = f.challengeStatus;

    return AnimatedContainer(
      duration: _D.normal,
      width: 132,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: status == ChallengeStatus.sent
            ? _D.amber.withOpacity(0.06)
            : _D.card,
        borderRadius: _D.radiusMd,
        border: Border.all(
          color: status == ChallengeStatus.sent
              ? _D.amber.withOpacity(0.3)
              : _D.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar row
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _avatarColor.withOpacity(0.22),
                    child: Text(
                      f.name.characters.first.toUpperCase(),
                      style: TextStyle(
                        color:      _avatarColor,
                        fontWeight: FontWeight.w800,
                        fontSize:   14,
                      ),
                    ),
                  ),
                  Positioned(
                    right:  0,
                    bottom: 0,
                    child:  _PulsingDot(
                      color:    f.isOnline ? _D.emerald : _D.textMuted,
                      size:     8,
                      animate:  f.isOnline,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color:      _D.textPrimary,
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      f.isOnline
                          ? (f.currentGame != null
                              ? 'In ${f.currentGame}'
                              : 'Online')
                          : _lastSeenLabel(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: f.isOnline ? _D.emerald : _D.textMuted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),

          // Challenge button
          SizedBox(
            width:  double.infinity,
            height: 30,
            child: _ChallengeButton(
              status:     status,
              isOnline:   f.isOnline,
              onPressed:  status == ChallengeStatus.idle ? widget.onChallenge : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ChallengeButton — stateful for internal animation
// ---------------------------------------------------------------------------

class _ChallengeButton extends StatelessWidget {
  const _ChallengeButton({
    required this.status,
    required this.isOnline,
    this.onPressed,
  });

  final ChallengeStatus status;
  final bool            isOnline;
  final VoidCallback?   onPressed;

  @override
  Widget build(BuildContext context) {
    final isSent    = status == ChallengeStatus.sent;
    final isSending = status == ChallengeStatus.sending;
    final canPress  = isOnline && status == ChallengeStatus.idle;

    return AnimatedContainer(
      duration: _D.normal,
      curve:    Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSent
            ? _D.emerald.withOpacity(0.12)
            : canPress
                ? _D.amber.withOpacity(0.12)
                : Colors.transparent,
        borderRadius: _D.radiusSm,
        border: Border.all(
          color: isSent
              ? _D.emerald.withOpacity(0.35)
              : canPress
                  ? _D.amber.withOpacity(0.4)
                  : _D.textMuted.withOpacity(0.2),
        ),
      ),
      child: Material(
        color:        Colors.transparent,
        borderRadius: _D.radiusSm,
        child: InkWell(
          onTap:        onPressed,
          borderRadius: _D.radiusSm,
          splashColor:  _D.amber.withOpacity(0.15),
          child: Center(
            child: isSending
                ? const SizedBox(
                    width:  14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color:       _D.amber,
                    ),
                  )
                : Text(
                    isSent ? '✓ Sent' : isOnline ? 'Challenge' : 'Offline',
                    style: TextStyle(
                      color: isSent
                          ? _D.emerald
                          : canPress
                              ? _D.amberLight
                              : _D.textMuted,
                      fontSize:   11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PartyBanner
// ---------------------------------------------------------------------------

class _PartyBanner extends StatelessWidget {
  const _PartyBanner({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        _D.card,
        borderRadius: _D.radiusLg,
        border:       Border.all(color: _D.cardBorder),
        gradient: LinearGradient(
          colors: [
            _D.indigo.withOpacity(0.12),
            _D.violet.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width:  42,
            height: 42,
            decoration: BoxDecoration(
              color:        _D.indigo.withOpacity(0.18),
              borderRadius: _D.radiusMd,
              border:       Border.all(
                  color: _D.indigo.withOpacity(0.2)),
            ),
            child: const Icon(
              Icons.groups_2_rounded,
              color: _D.indigoLight,
              size:  22,
            ),
          ),
          const SizedBox(width: 12),

          // Text
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Party Room',
                  style: TextStyle(
                    color:      _D.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize:   15,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Invite up to 4 friends · play together',
                  style: TextStyle(
                    color:    _D.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Button
          SizedBox(
            height: 36,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _D.indigo,
                foregroundColor: Colors.white,
                elevation:       0,
                shadowColor:     _D.indigo.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: _D.radiusSm),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(
                  fontWeight:    FontWeight.w700,
                  fontSize:      13,
                  letterSpacing: 0.2,
                ),
              ),
              onPressed: onCreate,
              child: const Text('Create'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PulsingDot — animated presence indicator
// ---------------------------------------------------------------------------

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({
    required this.color,
    this.size   = 10,
    this.animate = true,
  });

  final Color  color;
  final double size;
  final bool   animate;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl;
  late final Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulse = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.animate) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulsingDot old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ctrl.isAnimating)  _ctrl.repeat(reverse: true);
    if (!widget.animate && _ctrl.isAnimating)  _ctrl.stop();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width:  widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.animate
              ? widget.color.withOpacity(0.5 + 0.5 * _pulse.value)
              : widget.color,
          boxShadow: widget.animate
              ? [
                  BoxShadow(
                    color:      widget.color.withOpacity(0.4 * _pulse.value),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ToastOverlay
// ---------------------------------------------------------------------------

class _ToastOverlay extends StatelessWidget {
  const _ToastOverlay({
    required this.message,
    required this.isError,
    required this.animation,
    required this.onDismiss,
  });

  final String           message;
  final bool             isError;
  final Animation<double> animation;
  final VoidCallback     onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = isError ? _D.rose : _D.emerald;
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 24,
      left:   16,
      right:  16,
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, child) => Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animation.value)),
            child: child,
          ),
        ),
        child: GestureDetector(
          onTap: onDismiss,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color:        _D.surface,
              borderRadius: _D.radiusMd,
              border: Border.all(color: color.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withOpacity(0.35),
                  blurRadius: 20,
                  offset:     const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: color,
                  size:  18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color:      isError ? _D.rose : _D.textPrimary,
                      fontSize:   13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.close_rounded, color: _D.textMuted, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TextButton — minimal inline action link
// ---------------------------------------------------------------------------

class _TextButton extends StatelessWidget {
  const _TextButton({required this.label, required this.onTap});
  final String       label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color:      _D.indigoLight,
          fontSize:   12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LoadingShimmer — skeleton screen while data loads
// ---------------------------------------------------------------------------

class _LoadingShimmer extends StatefulWidget {
  const _LoadingShimmer();

  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl;
  late final Animation<double>   _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmer = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) {
        final t = _shimmer.value;
        final highlight = Color.lerp(
            _D.shimmerBase, _D.shimmerHighlight, math.sin(t * math.pi))!;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShimmerBox(width: 160, height: 14, color: highlight),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap:  true,
                physics:     const NeverScrollableScrollPhysics(),
                itemCount:   4,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:   2,
                  mainAxisSpacing:  10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.98,
                ),
                itemBuilder: (_, __) => _ShimmerBox(
                  width:  double.infinity,
                  height: double.infinity,
                  color:  highlight,
                  radius: 18,
                ),
              ),
              const SizedBox(height: 24),
              _ShimmerBox(width: 120, height: 14, color: highlight),
              const SizedBox(height: 12),
              Row(
                children: List.generate(3, (_) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child:   _ShimmerBox(
                      width:  double.infinity,
                      height: 118,
                      color:  highlight,
                      radius: 14,
                    ),
                  ),
                )),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.color,
    this.radius = 8,
  });

  final double width;
  final double height;
  final Color  color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  width,
      height: height,
      decoration: BoxDecoration(
        color:        color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}