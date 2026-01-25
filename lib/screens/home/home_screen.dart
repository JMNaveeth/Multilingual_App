import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' show Matrix4;
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
  late PageController _pageController;
  double _currentPage = 0.0;
  late AnimationController _floatingController;
  late AnimationController _rotationController;
  late AnimationController _pulseController;

  final List<Map<String, dynamic>> _headerCards = [
    {
      'title': 'Instant Translate',
      'subtitle': 'Start speaking — auto translate',
      'icon': Icons.translate,
      'colors': [Color(0xFF7F00FF), Color(0xFF00B4FF)],
      'badge': 'Live'
    },
    {
      'title': 'Group Chats',
      'subtitle': 'Create multilingual groups',
      'icon': Icons.group,
      'colors': [Color(0xFF11998e), Color(0xFF38ef7d)],
    },
    {
      'title': 'Favorites',
      'subtitle': 'Pinned chats & quick access',
      'icon': Icons.star,
      'colors': [Color(0xFFFFA726), Color(0xFFFF7043)],
    },
    {
      'title': 'Meet & Translate',
      'subtitle': 'Real-time voice translation',
      'icon': Icons.mic,
      'colors': [Color(0xFF2196F3), Color(0xFF03A9F4)],
    },
  ];

  final List<Widget> _screens = [
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.78);
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? 0.0;
      });
    });

    // Floating animation for cards
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Rotation animation for 3D elements
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Pulse animation for interactive elements
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatingController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(user != null ? 'Hi, ${user.name}' : 'Multilingual Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated gradient background with depth
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F2027),
                      Color(0xFF203A43),
                      Color(0xFF2C5364),
                      Color.lerp(Color(0xFF2C5364), Color(0xFF0F2027),
                          _rotationController.value * 0.3)!,
                    ],
                  ),
                ),
              );
            },
          ),

          // Floating 3D particles background
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
                const SizedBox(height: 8),
                // Enhanced 3D PageView header
                _build3DCardCarousel(context),
                const SizedBox(height: 20),
                // Stats row with 3D depth
                _build3DStatsRow(context),
                const SizedBox(height: 12),
                // Main content with enhanced glass morphism
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: _buildGlassMorphicContainer(
                      child: _screens[_selectedIndex],
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
            child: (Platform.isAndroid || Platform.isIOS)
                ? FloatingActionButton.extended(
                    onPressed: () async {
                      try {
                        if (Platform.isAndroid || Platform.isIOS) {
                          final contacts = await _requestContactsPermission();
                          if (contacts) {
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
                                    content:
                                        Text('Contacts permission denied')),
                              );
                            }
                          }
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
                    elevation: 8,
                  )
                : FloatingActionButton.extended(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Not available on this platform'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('New Chat'),
                    backgroundColor: Colors.cyanAccent,
                    elevation: 8,
                  ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white.withOpacity(0.06),
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.white70,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Future<bool> _requestContactsPermission() async {
    try {
      // Check platform before requesting permission
      if (Platform.isAndroid || Platform.isIOS) {
        final granted = await fc.FlutterContacts.requestPermission();
        return granted;
      }
      return false;
    } catch (e) {
      print('Error requesting contacts permission: $e');
      return false;
    }
  }

  // Build enhanced 3D card carousel
  Widget _build3DCardCarousel(BuildContext context) {
    return SizedBox(
      height: 200,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _headerCards.length,
        itemBuilder: (context, index) {
          final card = _headerCards[index];
          final colors = List<Color>.from(card['colors']);
          final double diff = index - _currentPage;
          final double scale = (1 - (diff.abs() * 0.15)).clamp(0.82, 1.0);
          final double tilt = (diff * 0.35).clamp(-0.7, 0.7);
          final double rotateX = (diff * 0.15).clamp(-0.3, 0.3);

          return AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              final floatOffset =
                  math.sin(_floatingController.value * 2 * math.pi + index) * 8;

              return Transform.translate(
                offset: Offset(0, floatOffset),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Selected: ${card['title']}')),
                      );
                    },
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(tilt)
                        ..rotateX(rotateX)
                        ..scale(scale, scale),
                      child: Stack(
                        children: [
                          // Main card container with enhanced shadow
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                colors: colors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors[0].withOpacity(0.5),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                  spreadRadius: -5,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                          ),

                          // Glassmorphism layer
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withOpacity(0.1),
                                        Colors.white.withOpacity(0.05),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Animated shine effect
                          AnimatedBuilder(
                            animation: _rotationController,
                            builder: (context, child) {
                              return Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment(
                                            -1 +
                                                (_rotationController.value * 2),
                                            -1),
                                        end: Alignment(
                                            1 + (_rotationController.value * 2),
                                            1),
                                        colors: [
                                          Colors.transparent,
                                          Colors.white.withOpacity(0.1),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Content
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              children: [
                                // 3D Icon container
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withOpacity(0.3),
                                        Colors.white.withOpacity(0.1),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(-2, -2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    card['icon'],
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        card['title'],
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                          shadows: [
                                            Shadow(
                                              color:
                                                  Colors.black.withOpacity(0.3),
                                              offset: const Offset(0, 2),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        card['subtitle'],
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color:
                                                  Colors.white.withOpacity(0.9),
                                              fontSize: 13,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (card.containsKey('badge'))
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      card['badge'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Build 3D stats row
  Widget _build3DStatsRow(BuildContext context) {
    final stats = [
      {'value': '24', 'label': 'Active', 'color': Color(0xFF00D9FF)},
      {'value': '156', 'label': 'Messages', 'color': Color(0xFF7F00FF)},
      {'value': '12', 'label': 'Groups', 'color': Color(0xFFFF6B6B)},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: stats.map((stat) {
          return Expanded(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.05),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          (stat['color'] as Color).withOpacity(0.3),
                          (stat['color'] as Color).withOpacity(0.1),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (stat['color'] as Color).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          stat['value'] as String,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: (stat['color'] as Color),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stat['label'] as String,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // Build glassmorphic container
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
