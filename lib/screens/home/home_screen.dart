import 'dart:io';
import 'dart:ui';
import 'package:multilingual_chat_app/screens/contacts/contacts_screen.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';
import 'package:multilingual_chat_app/screens/chat/chat_list_screen.dart';
import 'package:multilingual_chat_app/screens/profile/profile_screen.dart';

// ── Nexus Design Tokens ─────────────────────────────────────────────────────
class _N {
  static const bg = Color(0xFF0D0E1A);
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
      floatingActionButton: _bottomIndex == 0 ? _buildComposeFAB() : null,
    );
  }

  // ── Body router ───────────────────────────────────────────────────────────
  Widget _buildBody() {
    switch (_bottomIndex) {
      case 3:
        return Column(children: [
          _buildHeader(title: 'My Profile', showActions: false),
          const Expanded(child: ProfileScreen()),
        ]);
      case 1:
        return Column(children: [
          _buildHeader(title: 'Discover'),
          Expanded(child: _buildComingSoon(Icons.explore_outlined, 'Discover')),
        ]);
      case 2:
        return Column(children: [
          _buildHeader(title: 'Voice'),
          Expanded(
              child: _buildComingSoon(Icons.graphic_eq_rounded, 'Voice Calls')),
        ]);
      default:
        return _buildMessagesView();
    }
  }

  Widget _buildMessagesView() {
    return Column(children: [
      _buildHeader(title: 'Nexus'),
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
    final user = ref.watch(authProvider).value;
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
              if (user != null)
                Text(user.name,
                    style: const TextStyle(
                      color: _N.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    )),
            ],
          ),
        ),

        if (showActions) ...[
          _headerIconBtn(Icons.notifications_none_rounded, () {}),
          _headerIconBtn(Icons.search_rounded, () {}),
          _moreMenu(),
        ],
      ]),
    );
  }

  Widget _headerIconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: _N.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _N.cardBorder),
          ),
          child: Icon(icon, color: _N.textSecondary, size: 20),
        ),
      );

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
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _N.indigo.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('⌘ K',
                  style: TextStyle(
                      color: _N.indigoLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
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
        return _buildComingSoon(Icons.mic_none_rounded, 'Calls');
      default:
        return const SizedBox();
    }
  }

  // ── Compose FAB ───────────────────────────────────────────────────────────
  Widget _buildComposeFAB() => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
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
            borderRadius: BorderRadius.circular(18),
            onTap: _openNewChat,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Compose',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      )),
                ],
              ),
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

  Future<void> _openNewChat() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final granted = await _requestContactsPermission();
        if (granted) {
          if (mounted) {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ContactsScreen()));
          }
        } else {
          _snack('Contacts permission denied');
        }
      } else {
        _snack('Not available on this platform');
      }
    } catch (e) {
      _snack('Error: $e');
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

  Future<bool> _requestContactsPermission() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return await fc.FlutterContacts.requestPermission();
      }
      return false;
    } catch (e) {
      debugPrint('Contacts permission error: $e');
      return false;
    }
  }
}
