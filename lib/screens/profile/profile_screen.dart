import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  String _selectedLanguage = 'en';
  bool _isLoading = false;
  late AnimationController _floatingController;
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'es', 'name': 'Spanish'},
    {'code': 'fr', 'name': 'French'},
    {'code': 'de', 'name': 'German'},
    {'code': 'it', 'name': 'Italian'},
    {'code': 'pt', 'name': 'Portuguese'},
    {'code': 'ru', 'name': 'Russian'},
    {'code': 'ja', 'name': 'Japanese'},
    {'code': 'ko', 'name': 'Korean'},
    {'code': 'zh', 'name': 'Chinese'},
    {'code': 'hi', 'name': 'Hindi'},
    {'code': 'ar', 'name': 'Arabic'},
    {'code': 'ta', 'name': 'Tamil'},
    {'code': 'te', 'name': 'Telugu'},
    {'code': 'kn', 'name': 'Kannada'},
    {'code': 'ml', 'name': 'Malayalam'},
  ];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).value;
    _nameController = TextEditingController(text: user?.name ?? '');
    _selectedLanguage = user?.preferredLanguage ?? 'en';

    // Initialize animation controllers
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _floatingController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).updateProfile(
            name: _nameController.text.trim(),
            preferredLanguage: _selectedLanguage,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
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
                      Color(0xFF1A2980),
                      Color(0xFF26D0CE),
                      Color.lerp(Color(0xFF26D0CE), Color(0xFF1A2980),
                          _rotationController.value * 0.3)!,
                    ],
                  ),
                ),
              );
            },
          ),

          // Floating particles
          ...List.generate(12, (index) {
            return AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) {
                final offset = math.sin(
                        (_floatingController.value * 2 * math.pi) +
                            index * 0.5) *
                    40;
                return Positioned(
                  left: (index * 80.0) % MediaQuery.of(context).size.width,
                  top: (index * 100.0) % MediaQuery.of(context).size.height +
                      offset,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withOpacity(0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // 3D Profile Picture with floating effect
                    _build3DProfileAvatar(user),

                    const SizedBox(height: 16),

                    // Change Profile Picture Button with 3D effect
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_pulseController.value * 0.05),
                          child: TextButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Profile picture upload coming soon!')),
                              );
                            },
                            icon: const Icon(Icons.camera_alt,
                                color: Colors.white),
                            label: const Text(
                              'Change Profile Picture',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // 3D Name field
                    _build3DTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        if (value.length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // 3D Email field (disabled)
                    _build3DTextField(
                      initialValue: user.email,
                      label: 'Email',
                      icon: Icons.email,
                      enabled: false,
                    ),

                    const SizedBox(height: 16),

                    // 3D Language Dropdown
                    _build3DLanguageDropdown(),

                    const SizedBox(height: 24),

                    // 3D Account Information Card
                    _build3DAccountInfoCard(user),

                    const SizedBox(height: 32),

                    // 3D Update Button
                    _build3DButton(
                      onPressed: _isLoading ? null : _updateProfile,
                      label: _isLoading ? 'Updating...' : 'Update Profile',
                      icon: Icons.check_circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D9FF), Color(0xFF0099CC)],
                      ),
                      isLoading: _isLoading,
                    ),

                    const SizedBox(height: 16),

                    // 3D Logout Button
                    _build3DButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => _build3DDialog(context),
                        );

                        if (confirmed == true) {
                          await ref.read(authProvider.notifier).logout();
                        }
                      },
                      label: 'Logout',
                      icon: Icons.logout,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // 3D profile avatar with glow, floating, and shimmer
  Widget _build3DProfileAvatar(dynamic user) {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatingController, _pulseController]),
      builder: (context, child) {
        final floatY = math.sin(_floatingController.value * 2 * math.pi) * 10;
        final scale = 1.0 + (_pulseController.value * 0.04);
        return Transform.translate(
          offset: Offset(0, floatY),
          child: Transform.scale(
            scale: scale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00D9FF), Color(0xFF7F00FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 25,
                        offset: const Offset(0, 14),
                      ),
                      BoxShadow(
                        color: const Color(0xFF00D9FF).withOpacity(0.35),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.18),
                        Colors.white.withOpacity(0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Placeholder initials or future image
                        Container(
                          alignment: Alignment.center,
                          color: Colors.white.withOpacity(0.04),
                          child: Text(
                            _initialsFromName(user.name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Shimmer highlight
                        AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, _) {
                            return Transform.translate(
                              offset: Offset(
                                -150 + (_shimmerController.value * 300),
                                0,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.25),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 3D text field wrapper
  Widget _build3DTextField({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    required IconData icon,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(-3, -3),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.4),
      ),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        enabled: enabled,
        validator: validator,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.82)),
          prefixIcon: Icon(icon, color: Colors.white),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }

  // 3D language dropdown
  Widget _build3DLanguageDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(-3, -3),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.4),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedLanguage,
        dropdownColor: const Color(0xFF0F172A),
        iconEnabledColor: Colors.white,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: 'Preferred Language',
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.82)),
          prefixIcon: const Icon(Icons.language, color: Colors.white),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        items: _languages.map((lang) {
          return DropdownMenuItem(
            value: lang['code'],
            child: Text(lang['name'] ?? ''),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) setState(() => _selectedLanguage = value);
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a language';
          }
          return null;
        },
      ),
    );
  }

  // 3D account info card
  Widget _build3DAccountInfoCard(dynamic user) {
    final rows = <Map<String, String>>[
      {'label': 'Member since', 'value': _formatDate(user.createdAt)},
      {'label': 'Status', 'value': user.isOnline ? 'Online' : 'Offline'},
      if (!user.isOnline && user.lastSeen != null)
        {'label': 'Last seen', 'value': _formatDate(user.lastSeen!)},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.verified_user, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Account Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map((row) => _buildInfoRow(row['label']!, row['value']!)),
        ],
      ),
    );
  }

  // 3D primary button
  Widget _build3DButton({
    required VoidCallback? onPressed,
    required String label,
    required IconData icon,
    Gradient? gradient,
    bool isLoading = false,
  }) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.03);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: gradient ??
                  const LinearGradient(
                      colors: [Colors.white24, Colors.white12]),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(-3, -3),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: Colors.white),
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  // 3D confirmation dialog
  Widget _build3DDialog(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.logout, color: Colors.white, size: 36),
          SizedBox(height: 12),
          Text(
            'Logout',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Are you sure you want to logout?',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Logout'),
        ),
      ],
    );
  }

  String _initialsFromName(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
