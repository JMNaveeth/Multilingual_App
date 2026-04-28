import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:multilingual_chat_app/providers/auth_provider.dart';

// ── Nexus Design Tokens ───────────────────────────────────────────────────────
class _N {
  static const bg = Color(0xFF0D0E1A);
  static const surface = Color(0xFF151626);
  static const card = Color(0xFF1C1E31);
  static const cardBorder = Color(0xFF252842);
  static const indigo = Color(0xFF6366F1);
  static const indigoLight = Color(0xFF818CF8);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF8B5CF6);
  static const rose = Color(0xFFF43F5E);
  static const amber = Color(0xFFF59E0B);
  static const emerald = Color(0xFF10B981);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  TextEditingController? _nameController;
  TextEditingController? _statusController;
  String _selectedLanguage = 'en';
  bool _isLoading = false;
  bool _isEditingName = false;
  bool _isEditingStatus = false;
  bool _controllersInitialized = false;
  File? _selectedImage;
  bool _isUploadingImage = false;

  late final AnimationController _glowCtrl;
  late final AnimationController _onlineCtrl;
  final ImagePicker _imagePicker = ImagePicker();

  // ── Language list ──────────────────────────────────────────────────────────
  static const _languages = [
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'es', 'name': 'Spanish', 'flag': '🇪🇸'},
    {'code': 'fr', 'name': 'French', 'flag': '🇫🇷'},
    {'code': 'de', 'name': 'German', 'flag': '🇩🇪'},
    {'code': 'it', 'name': 'Italian', 'flag': '🇮🇹'},
    {'code': 'pt', 'name': 'Portuguese', 'flag': '🇵🇹'},
    {'code': 'ru', 'name': 'Russian', 'flag': '🇷🇺'},
    {'code': 'ja', 'name': 'Japanese', 'flag': '🇯🇵'},
    {'code': 'ko', 'name': 'Korean', 'flag': '🇰🇷'},
    {'code': 'zh', 'name': 'Chinese', 'flag': '🇨🇳'},
    {'code': 'hi', 'name': 'Hindi', 'flag': '🇮🇳'},
    {'code': 'ar', 'name': 'Arabic', 'flag': '🇸🇦'},
    {'code': 'ta', 'name': 'Tamil', 'flag': '🇮🇳'},
    {'code': 'te', 'name': 'Telugu', 'flag': '🇮🇳'},
    {'code': 'kn', 'name': 'Kannada', 'flag': '🇮🇳'},
    {'code': 'ml', 'name': 'Malayalam', 'flag': '🇮🇳'},
    {'code': 'si', 'name': 'Sinhala', 'flag': '🇱🇰'},
  ];

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _onlineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _nameController?.dispose();
    _statusController?.dispose();
    _glowCtrl.dispose();
    _onlineCtrl.dispose();
    super.dispose();
  }

  void _initControllers(dynamic user) {
    if (_controllersInitialized) return;
    _controllersInitialized = true;
    _nameController = TextEditingController(text: user.name ?? '');
    _statusController = TextEditingController(text: 'Available');
    _selectedLanguage = user.preferredLanguage ?? 'en';
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final p = name.trim().split(' ');
    return p.length == 1
        ? p[0][0].toUpperCase()
        : (p[0][0] + p[1][0]).toUpperCase();
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String get _langName => (_languages.firstWhere(
        (l) => l['code'] == _selectedLanguage,
        orElse: () => {'name': 'English', 'flag': '🇬🇧'},
      )['name'])!;

  String get _langFlag => (_languages.firstWhere(
        (l) => l['code'] == _selectedLanguage,
        orElse: () => {'name': 'English', 'flag': '🇬🇧'},
      )['flag'])!;

  // ── Image Picker Methods ──────────────────────────────────────────────────

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _N.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: _N.cardBorder)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: _N.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.image_rounded,
                      color: _N.indigoLight, size: 18),
                  const SizedBox(width: 10),
                  const Text(
                    'Update Profile Photo',
                    style: TextStyle(
                      color: _N.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: _N.cardBorder),

            // Options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  _imagePickerOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Take a Photo',
                    color: _N.cyan,
                    onTap: () {
                      Navigator.pop(_);
                      _pickImageFromCamera();
                    },
                  ),
                  const SizedBox(height: 8),
                  _imagePickerOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Choose from Gallery',
                    color: _N.violet,
                    onTap: () {
                      Navigator.pop(_);
                      _pickImageFromGallery();
                    },
                  ),
                  const SizedBox(height: 8),
                  if (_selectedImage != null)
                    _imagePickerOption(
                      icon: Icons.delete_rounded,
                      label: 'Remove Photo',
                      color: _N.rose,
                      onTap: () {
                        Navigator.pop(_);
                        setState(() => _selectedImage = null);
                        _snack('Profile photo removed', _N.rose);
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePickerOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _N.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: color.withOpacity(0.6), size: 14),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );

      if (pickedFile != null) {
        await _handleImagePicked(File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        _snack('Failed to access camera: $e', _N.rose);
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        await _handleImagePicked(File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        _snack('Failed to access gallery: $e', _N.rose);
      }
    }
  }

  Future<void> _handleImagePicked(File imageFile) async {
    if (!mounted) return;

    // Check file size (limit to 5MB)
    final fileSizeInMB = imageFile.lengthSync() / (1024 * 1024);
    if (fileSizeInMB > 5) {
      _snack('Image size must be less than 5MB', _N.rose);
      return;
    }

    setState(() {
      _selectedImage = imageFile;
    });

    _snack('Profile photo updated', _N.emerald);
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).updateProfile(
            name: _nameController!.text.trim(),
            preferredLanguage: _selectedLanguage,
          );
      if (mounted) _snack('Profile updated', _N.emerald);
    } catch (e) {
      if (mounted) _snack('Failed: $e', _N.rose);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: _N.textPrimary)),
      backgroundColor: _N.card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      action: SnackBarAction(
        label: 'OK',
        textColor: color,
        onPressed: () {},
      ),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return authState.when(
      loading: () => const Scaffold(
        backgroundColor: _N.bg,
        body: Center(
          child: CircularProgressIndicator(color: _N.indigoLight),
        ),
      ),
      error: (e, __) => Scaffold(
        backgroundColor: _N.bg,
        body: Center(
          child: Text('Error: $e',
              style: const TextStyle(color: _N.textSecondary)),
        ),
      ),
      data: (user) {
        if (user == null) {
          return const Scaffold(
            backgroundColor: _N.bg,
            body: Center(
              child:
                  Text('Not logged in', style: TextStyle(color: _N.textMuted)),
            ),
          );
        }
        _initControllers(user);

        return Scaffold(
          backgroundColor: _N.bg,
          body: Form(
            key: _formKey,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Collapsible hero header ──
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  backgroundColor: _N.surface,
                  automaticallyImplyLeading: false,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: _buildHeroBg(user),
                  ),
                  title: _buildCollapsedTitle(user),
                  actions: [_buildHeaderMenu()],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Container(height: 1, color: _N.cardBorder),
                  ),
                ),

                // ── Body ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name field
                        _sectionLabel(
                            'Display Name', Icons.person_outline_rounded),
                        const SizedBox(height: 8),
                        _editableField(
                          controller: _nameController!,
                          isEditing: _isEditingName,
                          hint: 'Enter your name',
                          onToggle: () =>
                              setState(() => _isEditingName = !_isEditingName),
                          onSave: _saveProfile,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Name required';
                            if (v.length < 2) return 'Min 2 characters';
                            return null;
                          },
                        ),
                        _sectionNote(
                            'Visible to your contacts. Not your username or pin.'),

                        const SizedBox(height: 20),

                        // About / Status
                        _sectionLabel('About', Icons.info_outline_rounded),
                        const SizedBox(height: 8),
                        _editableField(
                          controller: _statusController!,
                          isEditing: _isEditingStatus,
                          hint: 'Available',
                          onToggle: () => setState(
                              () => _isEditingStatus = !_isEditingStatus),
                          onSave: () {},
                        ),

                        const SizedBox(height: 20),

                        // Email (readonly)
                        _sectionLabel('Email', Icons.email_outlined),
                        const SizedBox(height: 8),
                        _readonlyField(
                          value: user.email,
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _N.emerald.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _N.emerald.withOpacity(0.3)),
                            ),
                            child: const Text('Verified',
                                style: TextStyle(
                                    color: _N.emerald,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Language picker
                        _sectionLabel(
                            'Preferred Language', Icons.translate_rounded),
                        const SizedBox(height: 8),
                        _languageTile(),

                        const SizedBox(height: 20),

                        // Account info
                        _sectionLabel(
                            'Account', Icons.manage_accounts_outlined),
                        const SizedBox(height: 8),
                        _accountCard(user),

                        const SizedBox(height: 28),

                        // Save button
                        _gradientButton(
                          label: 'Save Changes',
                          icon: Icons.check_rounded,
                          isLoading: _isLoading,
                          onTap: _saveProfile,
                          colors: [_N.indigo, _N.violet],
                          glowColor: _N.indigo,
                        ),

                        const SizedBox(height: 12),

                        // Sign out button
                        _outlineButton(
                          label: 'Sign Out',
                          icon: Icons.logout_rounded,
                          color: _N.rose,
                          onTap: _showSignOutDialog,
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

  // ── Hero header ───────────────────────────────────────────────────────────

  Widget _buildHeroBg(dynamic user) {
    return Stack(fit: StackFit.expand, children: [
      // Dark gradient bg
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF111224), _N.surface],
          ),
        ),
      ),

      // Glowing orb behind avatar
      AnimatedBuilder(
        animation: _glowCtrl,
        builder: (_, __) => Center(
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _N.indigo.withOpacity(0.18 + _glowCtrl.value * 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),

      // Avatar + info
      Positioned.fill(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 56),
            // Avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: _glowCtrl,
                  builder: (_, __) => Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: _selectedImage == null
                          ? const LinearGradient(
                              colors: [_N.indigo, _N.violet],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: _N.indigo
                              .withOpacity(0.45 + _glowCtrl.value * 0.25),
                          blurRadius: 24 + _glowCtrl.value * 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  _initials(user.name),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              _initials(user.name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                  ),
                ),

                // Camera badge
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: GestureDetector(
                    onTap: _showImagePickerOptions,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: _isUploadingImage ? _N.amber : _N.card,
                        border: Border.all(
                          color: _isUploadingImage
                              ? _N.amber.withOpacity(0.6)
                              : _N.indigo.withOpacity(0.5),
                        ),
                        boxShadow: _isUploadingImage
                            ? [
                                BoxShadow(
                                  color: _N.amber.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : [],
                      ),
                      child: !_isUploadingImage
                          ? const Icon(Icons.camera_alt_rounded,
                              color: _N.indigoLight, size: 16)
                          : const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(_N.amber),
                              ),
                            ),
                    ),
                  ),
                ),

                // Online indicator
                Positioned(
                  top: -2,
                  right: -2,
                  child: AnimatedBuilder(
                    animation: _onlineCtrl,
                    builder: (_, __) => Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: user.isOnline ? _N.cyan : _N.textMuted,
                        border: Border.all(color: _N.surface, width: 2.5),
                        boxShadow: user.isOnline
                            ? [
                                BoxShadow(
                                  color: _N.cyan.withOpacity(
                                      0.5 + _onlineCtrl.value * 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : [],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Name
            Text(
              user.name.isEmpty ? 'Your Name' : user.name,
              style: const TextStyle(
                color: _N.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),

            // Email
            Text(
              user.email,
              style: const TextStyle(color: _N.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 8),

            // Online badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: user.isOnline
                    ? _N.cyan.withOpacity(0.1)
                    : _N.textMuted.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: user.isOnline
                      ? _N.cyan.withOpacity(0.3)
                      : _N.textMuted.withOpacity(0.2),
                ),
              ),
              child: Text(
                user.isOnline ? '● Active now' : '○ Offline',
                style: TextStyle(
                  color: user.isOnline ? _N.cyan : _N.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildCollapsedTitle(dynamic user) => Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [_N.indigo, _N.violet],
              ),
            ),
            child: Center(
              child: Text(_initials(user.name),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          const Text('My Profile',
              style: TextStyle(
                color: _N.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              )),
        ],
      );

  Widget _buildHeaderMenu() => PopupMenuButton<String>(
        color: _N.card,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _N.cardBorder),
        ),
        icon: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: _N.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _N.cardBorder),
          ),
          child: const Icon(Icons.more_horiz_rounded,
              color: _N.textSecondary, size: 18),
        ),
        onSelected: (v) {
          if (v == 'signout') _showSignOutDialog();
        },
        itemBuilder: (_) => [
          _popItem(Icons.share_outlined, 'Share profile'),
          _popItem(Icons.qr_code_rounded, 'QR Code'),
          _popItem(Icons.privacy_tip_outlined, 'Privacy'),
          _popItem(Icons.notifications_outlined, 'Notifications'),
          _popItem(Icons.logout_rounded, 'Sign out',
              value: 'signout', color: _N.rose),
        ],
      );

  PopupMenuItem<String> _popItem(IconData icon, String label,
          {String? value, Color? color}) =>
      PopupMenuItem<String>(
        value: value ?? label,
        child: Row(children: [
          Icon(icon, size: 17, color: color ?? _N.indigoLight),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(color: color ?? _N.textPrimary, fontSize: 13.5)),
        ]),
      );

  // ── Section labels ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String label, IconData icon) => Row(children: [
        Icon(icon, size: 14, color: _N.indigoLight),
        const SizedBox(width: 6),
        Text(label.toUpperCase(),
            style: const TextStyle(
              color: _N.indigoLight,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            )),
      ]);

  Widget _sectionNote(String note) => Padding(
        padding: const EdgeInsets.only(top: 6, left: 2),
        child: Text(note,
            style: const TextStyle(color: _N.textMuted, fontSize: 11.5)),
      );

  // ── Editable field ─────────────────────────────────────────────────────────

  Widget _editableField({
    required TextEditingController controller,
    required bool isEditing,
    required String hint,
    required VoidCallback onToggle,
    required VoidCallback onSave,
    String? Function(String?)? validator,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _N.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEditing ? _N.indigo : _N.cardBorder,
          width: isEditing ? 1.5 : 1,
        ),
        boxShadow: isEditing
            ? [
                BoxShadow(
                    color: _N.indigo.withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 0)
              ]
            : [],
      ),
      child: Row(children: [
        const SizedBox(width: 16),
        Expanded(
          child: isEditing
              ? TextFormField(
                  controller: controller,
                  autofocus: true,
                  validator: validator,
                  style: const TextStyle(color: _N.textPrimary, fontSize: 15),
                  cursorColor: _N.indigoLight,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle:
                        const TextStyle(color: _N.textMuted, fontSize: 15),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onFieldSubmitted: (_) {
                    onSave();
                    onToggle();
                  },
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    controller.text.isEmpty ? hint : controller.text,
                    style: TextStyle(
                      color: controller.text.isEmpty
                          ? _N.textMuted
                          : _N.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                ),
        ),
        GestureDetector(
          onTap: () {
            if (isEditing) onSave();
            onToggle();
          },
          child: Container(
            width: 42,
            height: 42,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color:
                  isEditing ? _N.indigo.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isEditing ? Icons.check_rounded : Icons.edit_outlined,
              color: isEditing ? _N.indigoLight : _N.textMuted,
              size: 18,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Readonly field ─────────────────────────────────────────────────────────

  Widget _readonlyField({required String value, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: _N.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _N.cardBorder),
      ),
      child: Row(children: [
        Expanded(
          child: Text(value,
              style: const TextStyle(color: _N.textSecondary, fontSize: 15)),
        ),
        if (trailing != null) trailing,
      ]),
    );
  }

  // ── Language tile ──────────────────────────────────────────────────────────

  Widget _languageTile() => GestureDetector(
        onTap: _showLanguagePicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _N.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _N.cardBorder),
          ),
          child: Row(children: [
            Text(_langFlag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_langName,
                  style: const TextStyle(color: _N.textPrimary, fontSize: 15)),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: _N.textMuted, size: 20),
          ]),
        ),
      );

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: _N.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: _N.cardBorder)),
        ),
        child: Column(children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: _N.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              const Icon(Icons.translate_rounded,
                  color: _N.indigoLight, size: 18),
              const SizedBox(width: 10),
              const Text('Select Language',
                  style: TextStyle(
                    color: _N.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  )),
            ]),
          ),

          Container(height: 1, color: _N.cardBorder),

          // List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _languages.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: _N.cardBorder, indent: 20),
              itemBuilder: (ctx, i) {
                final lang = _languages[i];
                final selected = lang['code'] == _selectedLanguage;

                return ListTile(
                  leading:
                      Text(lang['flag']!, style: const TextStyle(fontSize: 22)),
                  title: Text(lang['name']!,
                      style: TextStyle(
                        color: selected ? _N.indigoLight : _N.textPrimary,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 15,
                      )),
                  trailing: selected
                      ? Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _N.indigo.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: _N.indigoLight, size: 14),
                        )
                      : null,
                  onTap: () {
                    setState(() => _selectedLanguage = lang['code']!);
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ── Account card ───────────────────────────────────────────────────────────

  Widget _accountCard(dynamic user) {
    return Container(
      decoration: BoxDecoration(
        color: _N.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _N.cardBorder),
      ),
      child: Column(children: [
        _accountRow(
          icon: Icons.calendar_today_outlined,
          iconColor: _N.violet,
          label: 'Member since',
          value: _formatDate(user.createdAt),
          showDivider: true,
        ),
        _accountRow(
          icon: user.isOnline ? Icons.circle : Icons.circle_outlined,
          iconColor: user.isOnline ? _N.cyan : _N.textMuted,
          label: 'Status',
          value: user.isOnline ? 'Online' : 'Offline',
          showDivider: user.lastSeen != null && !user.isOnline,
        ),
        if (!user.isOnline && user.lastSeen != null)
          _accountRow(
            icon: Icons.access_time_rounded,
            iconColor: _N.amber,
            label: 'Last seen',
            value: _formatDate(user.lastSeen!),
            showDivider: false,
          ),
      ]),
    );
  }

  Widget _accountRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool showDivider,
  }) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(color: _N.textMuted, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                  color: _N.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                )),
          ]),
        ]),
      ),
      if (showDivider)
        const Divider(height: 1, indent: 64, color: _N.cardBorder),
    ]);
  }

  // ── Buttons ───────────────────────────────────────────────────────────────

  Widget _gradientButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    required VoidCallback onTap,
    required List<Color> colors,
    required Color glowColor,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isLoading
                ? [colors[0].withOpacity(0.5), colors[1].withOpacity(0.5)]
                : colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: glowColor.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  )
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        )),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _outlineButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sign-out dialog ────────────────────────────────────────────────────────

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _N.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _N.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _N.rose.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _N.rose.withOpacity(0.3)),
                ),
                child:
                    const Icon(Icons.logout_rounded, color: _N.rose, size: 26),
              ),
              const SizedBox(height: 16),
              const Text('Sign Out?',
                  style: TextStyle(
                    color: _N.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 8),
              const Text(
                'You\'ll need to sign back in to\naccess your messages.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: _N.textMuted, fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: _N.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _N.cardBorder),
                      ),
                      child: const Center(
                        child: Text('Cancel',
                            style: TextStyle(
                              color: _N.textSecondary,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await ref.read(authProvider.notifier).logout();
                    },
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: _N.rose.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _N.rose.withOpacity(0.4)),
                      ),
                      child: const Center(
                        child: Text('Sign Out',
                            style: TextStyle(
                              color: _N.rose,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
