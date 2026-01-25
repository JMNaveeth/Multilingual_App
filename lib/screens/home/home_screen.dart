import 'dart:ui';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

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

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;
  double _currentPage = 0.0;
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
  }

  @override
  void dispose() {
    _pageController.dispose();
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Animated PageView header with curated app-specific cards
              SizedBox(
                height: 180,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _headerCards.length,
                  itemBuilder: (context, index) {
                    final card = _headerCards[index];
                    final colors = List<Color>.from(card['colors']);
                    final double diff = index - _currentPage;
                    final double scale =
                        (1 - (diff.abs() * 0.12)).clamp(0.86, 1.0);
                    final double tilt = (diff * 0.28).clamp(-0.6, 0.6);
                    return Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Selected: ${card['title']}')),
                          );
                        },
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(tilt)
                            ..scale(scale, scale),
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    colors: colors,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.45),
                                      blurRadius: 22,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: BackdropFilter(
                                    filter:
                                        ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                    child: Container(
                                      color: Colors.white.withOpacity(0.02),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(colors: [
                                          Colors.white24,
                                          Colors.white10
                                        ]),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.25),
                                            blurRadius: 8,
                                            offset: const Offset(0, 6),
                                          )
                                        ],
                                      ),
                                      child: Icon(card['icon'],
                                          color: Colors.white, size: 34),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            card['title'],
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            card['subtitle'],
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Colors.white70,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (card.containsKey('badge'))
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          card['badge'],
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              // main content area with subtle glass effect
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: Colors.white.withOpacity(0.04),
                      child: _screens[_selectedIndex],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Create new chat')));
        },
        icon: const Icon(Icons.add),
        label: const Text('New Chat'),
        backgroundColor: Colors.cyanAccent,
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
}
