import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _statusController;
  String _selectedLanguage = 'en';
  bool _isLoading = false;
  bool _isEditingName = false;
  bool _isEditingStatus = false;

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

  static const _waGreen = Color(0xFF25D366);
  static const _waDark = Color(0xFF075E54);
  static const _waTeal = Color(0xFF128C7E);
  static const _waBg = Color(0xFFF0F2F5);
  static const _waCardBg = Colors.white;
  static const _waSubtitle = Color(0xFF8696A0);
  static const _waDivider = Color(0xFFE9EDEF);
  static const _waText = Color(0xFF111B21);

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).value;
    _nameController = TextEditingController(text: user?.name ?? '');
    _statusController = TextEditingController(text: 'Available');
    _selectedLanguage = user?.preferredLanguage ?? 'en';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _statusController.dispose();
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
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: _waTeal,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _initialsFromName(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  String get _selectedLanguageName =>
      _languages.firstWhere(
        (l) => l['code'] == _selectedLanguage,
        orElse: () => {'name': 'English'},
      )['name'] ??
      'English';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;

    if (user == null) {
      return const Scaffold(
        backgroundColor: _waBg,
        body: Center(child: CircularProgressIndicator(color: _waTeal)),
      );
    }

    return Scaffold(
      backgroundColor: _waBg,
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            // WhatsApp-style collapsible AppBar
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: _waDark,
              automaticallyImplyLeading: false,
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                'Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (v) {
                    if (v == 'logout') _showLogoutDialog();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'logout',
                      child: Text('Log out'),
                    ),
                  ],
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: _waDark,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      // Avatar with camera button
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 58,
                            backgroundColor: _waTeal,
                            child: Text(
                              _initialsFromName(user.name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Photo upload coming soon!'),
                                    backgroundColor: _waTeal,
                                  ),
                                );
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: _waGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.name.isEmpty ? 'Your Name' : user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // ── Your Name ──
                  _buildSectionLabel('Your name'),
                  _buildEditableCard(
                    icon: Icons.person_outline,
                    controller: _nameController,
                    isEditing: _isEditingName,
                    hint: 'Enter your name',
                    onEditToggle: () =>
                        setState(() => _isEditingName = !_isEditingName),
                    onSave: _updateProfile,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter your name';
                      if (v.length < 2) return 'At least 2 characters';
                      return null;
                    },
                  ),
                  _buildSectionNote(
                    'This is not your username or pin. This name will be visible to your contacts.',
                  ),

                  const SizedBox(height: 8),

                  // ── About ──
                  _buildSectionLabel('About'),
                  _buildEditableCard(
                    icon: Icons.info_outline,
                    controller: _statusController,
                    isEditing: _isEditingStatus,
                    hint: 'Available',
                    onEditToggle: () =>
                        setState(() => _isEditingStatus = !_isEditingStatus),
                    onSave: () {},
                  ),

                  const SizedBox(height: 8),

                  // ── Email ──
                  _buildSectionLabel('Email'),
                  _buildReadonlyCard(
                    icon: Icons.email_outlined,
                    value: user.email,
                  ),

                  const SizedBox(height: 8),

                  // ── Preferred Language ──
                  _buildSectionLabel('Preferred Language'),
                  _buildLanguageCard(),

                  const SizedBox(height: 8),

                  // ── Account Info ──
                  _buildSectionLabel('Account'),
                  _buildInfoCard(user),

                  const SizedBox(height: 24),

                  // ── Save Button ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _waGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Log Out Button ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _showLogoutDialog,
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text(
                          'Log out',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        label,
        style: const TextStyle(
          color: _waTeal,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSectionNote(String note) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Text(
        note,
        style: const TextStyle(color: _waSubtitle, fontSize: 12),
      ),
    );
  }

  Widget _buildEditableCard({
    required IconData icon,
    required TextEditingController controller,
    required bool isEditing,
    required String hint,
    required VoidCallback onEditToggle,
    required VoidCallback onSave,
    String? Function(String?)? validator,
  }) {
    return Container(
      color: _waCardBg,
      child: ListTile(
        leading: Icon(icon, color: _waSubtitle),
        title: isEditing
            ? TextFormField(
                controller: controller,
                autofocus: true,
                validator: validator,
                style: const TextStyle(color: _waText, fontSize: 16),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: _waSubtitle),
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onFieldSubmitted: (_) {
                  onSave();
                  onEditToggle();
                },
              )
            : Text(
                controller.text.isEmpty ? hint : controller.text,
                style: TextStyle(
                  color: controller.text.isEmpty ? _waSubtitle : _waText,
                  fontSize: 16,
                ),
              ),
        trailing: IconButton(
          icon: Icon(
            isEditing ? Icons.check : Icons.edit,
            color: isEditing ? _waGreen : _waSubtitle,
            size: 20,
          ),
          onPressed: () {
            if (isEditing) onSave();
            onEditToggle();
          },
        ),
      ),
    );
  }

  Widget _buildReadonlyCard({
    required IconData icon,
    required String value,
    Widget? trailing,
  }) {
    return Container(
      color: _waCardBg,
      child: ListTile(
        leading: Icon(icon, color: _waSubtitle),
        title: Text(
          value,
          style: const TextStyle(color: _waText, fontSize: 16),
        ),
        trailing: trailing,
      ),
    );
  }

  Widget _buildLanguageCard() {
    return Container(
      color: _waCardBg,
      child: ListTile(
        leading: const Icon(Icons.language, color: _waSubtitle),
        title: Text(
          _selectedLanguageName,
          style: const TextStyle(color: _waText, fontSize: 16),
        ),
        trailing: const Icon(Icons.chevron_right, color: _waSubtitle),
        onTap: _showLanguagePicker,
      ),
    );
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: _waSubtitle.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Select Language',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _waText,
              ),
            ),
          ),
          const Divider(height: 1, color: _waDivider),
          Expanded(
            child: ListView.separated(
              itemCount: _languages.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: _waDivider, indent: 16),
              itemBuilder: (_, i) {
                final lang = _languages[i];
                final selected = lang['code'] == _selectedLanguage;
                return ListTile(
                  title: Text(
                    lang['name'] ?? '',
                    style: TextStyle(
                      color: selected ? _waTeal : _waText,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(Icons.check, color: _waGreen)
                      : null,
                  onTap: () {
                    setState(() => _selectedLanguage = lang['code']!);
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(dynamic user) {
    return Container(
      color: _waCardBg,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined,
                color: _waSubtitle),
            title: const Text(
              'Member since',
              style: TextStyle(color: _waSubtitle, fontSize: 13),
            ),
            subtitle: Text(
              _formatDate(user.createdAt),
              style: const TextStyle(color: _waText, fontSize: 15),
            ),
          ),
          const Divider(height: 1, indent: 56, color: _waDivider),
          ListTile(
            leading: Icon(
              Icons.circle,
              color: user.isOnline ? _waGreen : _waSubtitle,
              size: 14,
            ),
            title: const Text(
              'Status',
              style: TextStyle(color: _waSubtitle, fontSize: 13),
            ),
            subtitle: Text(
              user.isOnline ? 'Online' : 'Offline',
              style: const TextStyle(color: _waText, fontSize: 15),
            ),
          ),
          if (!user.isOnline && user.lastSeen != null) ...[
            const Divider(height: 1, indent: 56, color: _waDivider),
            ListTile(
              leading: const Icon(Icons.access_time,
                  color: _waSubtitle, size: 20),
              title: const Text(
                'Last seen',
                style: TextStyle(color: _waSubtitle, fontSize: 13),
              ),
              subtitle: Text(
                _formatDate(user.lastSeen!),
                style: const TextStyle(color: _waText, fontSize: 15),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          'Log out?',
          style: TextStyle(color: _waText, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: _waSubtitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: _waSubtitle)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
            },
            child: const Text(
              'Log out',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}