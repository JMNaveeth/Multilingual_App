import 'dart:io';
import 'package:multilingual_chat_app/screens/contacts/contacts_screen.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';
import 'package:multilingual_chat_app/screens/chat/chat_list_screen.dart';
import 'package:multilingual_chat_app/screens/profile/profile_screen.dart';

// ── WhatsApp brand colours ──────────────────────────────────────────────────
class _WA {
  static const teal        = Color(0xFF075E54); // dark header
  static const tealLight   = Color(0xFF128C7E); // slightly lighter
  static const green       = Color(0xFF25D366); // FAB / online dot
  static const bg          = Color(0xFFFFFFFF); // list background
  static const divider     = Color(0xFFE0E0E0);
  static const textPrimary = Color(0xFF111B21);
  static const textSecondary = Color(0xFF667781);
  static const tabIndicator = Colors.white;
  static const tabLabel    = Colors.white;
  static const unselected  = Color(0xFFB2DFDB); // translucent white on teal
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // bottom-nav index: 0 = Chats, 1 = Profile
  int _bottomIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Make status bar icons light (white) over the teal header.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: _WA.teal,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Main build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Profile tab – full-screen, plain background
    if (_bottomIndex == 1) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: _buildProfileAppBar(),
        body: const ProfileScreen(),
        bottomNavigationBar: _buildBottomNav(),
      );
    }

    // Chats tab
    return Scaffold(
      backgroundColor: _WA.bg,
      appBar: _buildChatsAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── CHATS tab ──
          const ChatListScreen(),

          // ── STATUS tab (placeholder) ──
          _buildComingSoon(Icons.circle_outlined, 'Status'),

          // ── CALLS tab (placeholder) ──
          _buildComingSoon(Icons.call_outlined, 'Calls'),
        ],
      ),
      floatingActionButton: _buildFAB(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── AppBars ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildChatsAppBar() {
    final user = ref.watch(authProvider).value;

    return AppBar(
      backgroundColor: _WA.teal,
      elevation: 0,
      titleSpacing: 18,
      title: Text(
        user != null ? 'Hi, ${user.name.split(' ').first}' : 'WhatsApp',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      actions: [
        // Camera icon
        IconButton(
          icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 22),
          onPressed: () {},
          tooltip: 'Camera',
        ),
        // Search icon
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white, size: 22),
          onPressed: () {},
          tooltip: 'Search',
        ),
        // More-vert / Logout
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
          color: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onSelected: (v) async {
            if (v == 'logout') {
              await ref.read(authProvider.notifier).logout();
            }
          },
          itemBuilder: (_) => [
            _menuItem(Icons.group_add_outlined,  'New group'),
            _menuItem(Icons.devices_outlined,    'Linked devices'),
            _menuItem(Icons.star_outline,        'Starred messages'),
            _menuItem(Icons.settings_outlined,   'Settings'),
            _menuItem(Icons.logout,              'Log out', value: 'logout'),
          ],
        ),
        const SizedBox(width: 4),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: _WA.tabIndicator,
        indicatorWeight: 3,
        labelColor: _WA.tabLabel,
        unselectedLabelColor: _WA.unselected,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.8,
        ),
        tabs: const [
          Tab(text: 'CHATS'),
          Tab(text: 'STATUS'),
          Tab(text: 'CALLS'),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildProfileAppBar() => AppBar(
        backgroundColor: _WA.teal,
        elevation: 0,
        titleSpacing: 18,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      );

  // ── FAB ────────────────────────────────────────────────────────────────────

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _openNewChat,
      backgroundColor: _WA.green,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: const CircleBorder(),
      tooltip: 'New chat',
      child: const Icon(Icons.chat_outlined, size: 26),
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      selectedItemColor: _WA.tealLight,
      unselectedItemColor: _WA.textSecondary,
      selectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(fontSize: 12),
      currentIndex: _bottomIndex,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      onTap: (i) => setState(() => _bottomIndex = i),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline_rounded),
          activeIcon: Icon(Icons.chat_bubble_rounded),
          label: 'Chats',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_rounded),
          activeIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  PopupMenuItem<String> _menuItem(IconData icon, String label,
      {String? value}) {
    return PopupMenuItem<String>(
      value: value ?? label.toLowerCase().replaceAll(' ', '_'),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _WA.textSecondary),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  color: _WA.textPrimary, fontSize: 14.5)),
        ],
      ),
    );
  }

  Widget _buildComingSoon(IconData icon, String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: _WA.divider),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: _WA.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Coming soon',
            style: TextStyle(color: _WA.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Future<void> _openNewChat() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final granted = await _requestContactsPermission();
        if (granted) {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ContactsScreen()),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contacts permission denied')),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not available on this platform')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<bool> _requestContactsPermission() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return await fc.FlutterContacts.requestPermission();
      }
      return false;
    } catch (e) {
      debugPrint('Error requesting contacts permission: $e');
      return false;
    }
  }
}