import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:multilingual_chat_app/screens/contacts/contacts_screen.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';
import 'package:multilingual_chat_app/screens/chat/chat_list_screen.dart';
import 'package:multilingual_chat_app/screens/profile/profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _floatingController;
  late AnimationController _rotationController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;

    // ── Profile tab: full-screen, no glass wrapper, no extra chrome ──
    if (_selectedIndex == 1) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: const ProfileScreen(),
        bottomNavigationBar: _buildBottomNav(),
      );
    }

    // ── Chats tab: original animated home layout ──
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          user != null ? 'Hi, ${user.name}' : 'Multilingual Chat',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) async {
              if (v == 'logout') {
                await ref.read(authProvider.notifier).logout();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0F2027),
                      const Color(0xFF203A43),
                      const Color(0xFF2C5364),
                      Color.lerp(
                        const Color(0xFF2C5364),
                        const Color(0xFF0F2027),
                        _rotationController.value * 0.3,
                      )!,
                    ],
                  ),
                ),
              );
            },
          ),

          // Floating particles background
          ...List.generate(15, (index) {
            return AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) {
                final offset = math.sin(
                        (_floatingController.value * 2 * math.pi) + index) *
                    30;
                final scale = 0.5 +
                    math.sin((_floatingController.value * 2 * math.pi) +
                            index * 0.5) *
                        0.3;
                return Positioned(
                  left: (index * 70.0) % MediaQuery.of(context).size.width,
                  top: (index * 90.0) % MediaQuery.of(context).size.height +
                      offset,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 60 + (index % 3) * 20,
                      height: 60 + (index % 3) * 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.03),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Chat list with glass morphism
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: _buildGlassMorphicContainer(
                      child: const ChatListScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = 1.0 + (_pulseController.value * 0.1);
          return Transform.scale(
            scale: scale,
            child: FloatingActionButton.extended(
              onPressed: () async {
                try {
                  if (Platform.isAndroid || Platform.isIOS) {
                    final granted = await _requestContactsPermission();
                    if (granted) {
                      if (mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ContactsScreen()),
                        );
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Contacts permission denied')),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Not available on this platform')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('New Chat'),
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              elevation: 8,
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Shared bottom nav ──
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      backgroundColor: _selectedIndex == 1
          ? const Color(0xFF075E54)
          : Colors.white.withOpacity(0.06),
      selectedItemColor: _selectedIndex == 1 ? Colors.white : Colors.cyanAccent,
      unselectedItemColor:
          _selectedIndex == 1 ? Colors.white60 : Colors.white70,
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          activeIcon: Icon(Icons.chat_bubble),
          label: 'Chats',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
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

  // ── Glassmorphic container ──
  Widget _buildGlassMorphicContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
