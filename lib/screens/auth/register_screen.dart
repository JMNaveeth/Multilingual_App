import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';
import 'package:multilingual_chat_app/screens/auth/login_screen.dart';

// ── Nexus tokens ─────────────────────────────────────────────────────────────
class _N {
  static const bg = Color(0xFF0D0E1A);
  static const surface = Color(0xFF151626);
  static const card = Color(0xFF1C1E31);
  static const cardBorder = Color(0xFF252842);
  static const indigo = Color(0xFF6366F1);
  static const indigoLight = Color(0xFF818CF8);
  static const violet = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF22D3EE);
  static const rose = Color(0xFFF43F5E);
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _selectedLanguage = 'en';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _passwordStrength = 0; // 0-4
  bool _nameFocused = false;
  bool _emailFocused = false;
  bool _passwordFocused = false;
  bool _confirmFocused = false;

  // Focus nodes
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  late final AnimationController _bgCtrl;
  late final AnimationController _entryCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _buttonCtrl;
  late final Animation<double> _entry;
  late final Animation<double> _buttonScale;

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

  String get _langName =>
      (_languages.firstWhere((l) => l['code'] == _selectedLanguage,
          orElse: () => {'name': 'English', 'flag': '🇬🇧'})['name'])!;

  String get _langFlag =>
      (_languages.firstWhere((l) => l['code'] == _selectedLanguage,
          orElse: () => {'name': 'English', 'flag': '🇬🇧'})['flag'])!;

  @override
  void initState() {
    super.initState();

    _bgCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat(reverse: true);

    _glowCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();

    _entry = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);

    _buttonCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));

    _buttonScale = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _buttonCtrl, curve: Curves.easeInOut));

    _nameFocus
        .addListener(() => setState(() => _nameFocused = _nameFocus.hasFocus));
    _emailFocus.addListener(
        () => setState(() => _emailFocused = _emailFocus.hasFocus));
    _passwordFocus.addListener(
        () => setState(() => _passwordFocused = _passwordFocus.hasFocus));
    _confirmFocus.addListener(
        () => setState(() => _confirmFocused = _confirmFocus.hasFocus));

    _passwordCtrl.addListener(_updatePasswordStrength);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  void _updatePasswordStrength() {
    final p = _passwordCtrl.text;
    int score = 0;
    if (p.length >= 6) score++;
    if (p.length >= 10) score++;
    if (p.contains(RegExp(r'[A-Z]'))) score++;
    if (p.contains(RegExp(r'[0-9]'))) score++;
    if (p.contains(RegExp(r'[!@#\$%^&*]'))) score++;
    setState(() => _passwordStrength = (score).clamp(0, 4));
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _glowCtrl.dispose();
    _entryCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(authProvider.notifier).register(
            _nameCtrl.text.trim(),
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
            _selectedLanguage,
          );

      final requiresEmailConfirmation =
          result['requiresEmailConfirmation'] == true;
      if (mounted && requiresEmailConfirmation) {
        _snack((result['message'] ??
                'Account created in Supabase. Please confirm your email, then log in.')
            .toString());
        _openLoginScreen();
      }
    } catch (e) {
      if (mounted) {
        final raw = e.toString();
        final cleaned = raw.startsWith('Exception: ')
            ? raw.substring('Exception: '.length)
            : raw;
        _snack(cleaned);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: _N.textPrimary)),
      backgroundColor: _N.card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _openLoginScreen() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _N.bg,
      body: Stack(children: [
        _buildBackground(size),
        Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
        SafeArea(
          child: FadeTransition(
            opacity: _entry,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(_entry),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(children: [
                  const SizedBox(height: 28),
                  _buildHeader(),
                  const SizedBox(height: 28),
                  _buildCard(),
                  const SizedBox(height: 24),
                  _buildLoginLink(),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Background ────────────────────────────────────────────────────────────

  Widget _buildBackground(Size size) => AnimatedBuilder(
        animation: _bgCtrl,
        builder: (_, __) {
          final t = _bgCtrl.value;
          return Stack(children: [
            Positioned(
              right: -60 + t * 30,
              top: -60 + t * 30,
              child: _orb(280, _N.violet.withOpacity(0.16 + t * 0.06)),
            ),
            Positioned(
              left: -80 + (1 - t) * 30,
              bottom: -80 + (1 - t) * 30,
              child: _orb(320, _N.indigo.withOpacity(0.13 + (1 - t) * 0.06)),
            ),
            Positioned(
              left: size.width * 0.35,
              top: size.height * 0.4,
              child: _orb(140, _N.cyan.withOpacity(0.05 + t * 0.03)),
            ),
          ]);
        },
      );

  Widget _orb(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      );

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(children: [
      // Logo pill
      AnimatedBuilder(
        animation: _glowCtrl,
        builder: (_, __) => Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              colors: [_N.indigo, _N.violet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _N.indigo.withOpacity(0.4 + _glowCtrl.value * 0.25),
                blurRadius: 16 + _glowCtrl.value * 8,
              )
            ],
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
        ),
      ),
      const SizedBox(width: 12),

      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Create Account',
            style: TextStyle(
              color: _N.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            )),
        const Text('Join ec communication today',
            style: TextStyle(color: _N.textMuted, fontSize: 12.5)),
      ]),
    ]);
  }

  // ── Card ──────────────────────────────────────────────────────────────────

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _N.card.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _N.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 32,
            offset: const Offset(0, 12),
          )
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Full name ──
            _staggeredField(
                0,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Full Name'),
                    const SizedBox(height: 8),
                    _inputField(
                      ctrl: _nameCtrl,
                      focus: _nameFocus,
                      isFocused: _nameFocused,
                      hint: 'John Doe',
                      icon: Icons.person_outline_rounded,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Name required';
                        if (v.length < 2) return 'Min 2 characters';
                        return null;
                      },
                    ),
                  ],
                )),

            const SizedBox(height: 18),

            // ── Email ──
            _staggeredField(
                1,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Email Address'),
                    const SizedBox(height: 8),
                    _inputField(
                      ctrl: _emailCtrl,
                      focus: _emailFocus,
                      isFocused: _emailFocused,
                      hint: 'you@example.com',
                      icon: Icons.alternate_email_rounded,
                      keyboard: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email required';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(v)) return 'Enter a valid email';
                        return null;
                      },
                    ),
                  ],
                )),

            const SizedBox(height: 18),

            // ── Language ──
            _staggeredField(
                2,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Preferred Language'),
                    const SizedBox(height: 8),
                    _langTile(),
                  ],
                )),

            const SizedBox(height: 18),

            // ── Password ──
            _staggeredField(
                3,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Password'),
                    const SizedBox(height: 8),
                    _inputField(
                      ctrl: _passwordCtrl,
                      focus: _passwordFocus,
                      isFocused: _passwordFocused,
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscurePassword,
                      suffix: GestureDetector(
                        onTap: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        child: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: _N.textMuted,
                          size: 18,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password required';
                        if (v.length < 6) return 'Min 6 characters';
                        return null;
                      },
                    ),
                  ],
                )),

            // Strength meter
            if (_passwordCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildStrengthMeter(),
            ],

            const SizedBox(height: 18),

            // ── Confirm password ──
            _staggeredField(
                4,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Confirm Password'),
                    const SizedBox(height: 8),
                    _inputField(
                      ctrl: _confirmCtrl,
                      focus: _confirmFocus,
                      isFocused: _confirmFocused,
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscureConfirm,
                      suffix: GestureDetector(
                        onTap: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        child: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: _N.textMuted,
                          size: 18,
                        ),
                      ),
                      validator: (v) {
                        if (v != _passwordCtrl.text)
                          return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ],
                )),

            const SizedBox(height: 28),

            // ── Create account button ──
            _staggeredField(5, _createAccountBtn()),
          ],
        ),
      ),
    );
  }

  // ── Strength meter ────────────────────────────────────────────────────────

  Widget _buildStrengthMeter() {
    final labels = ['Too short', 'Weak', 'Fair', 'Strong', 'Very strong'];
    final colors = [_N.rose, _N.amber, _N.amber, _N.emerald, _N.cyan];
    final strength = _passwordStrength.clamp(0, 4);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
          children: List.generate(
              4,
              (i) => Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i < strength ? colors[strength] : _N.cardBorder,
                      ),
                    ),
                  ))),
      const SizedBox(height: 5),
      Text(strength == 0 ? '' : labels[strength],
          style: TextStyle(
            color: colors[strength],
            fontSize: 11,
            fontWeight: FontWeight.w600,
          )),
    ]);
  }

  // ── Language tile ─────────────────────────────────────────────────────────

  Widget _langTile() => GestureDetector(
        onTap: _showLanguagePicker,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _N.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _N.cardBorder),
          ),
          child: Row(children: [
            const Icon(Icons.translate_rounded, color: _N.textMuted, size: 18),
            const SizedBox(width: 10),
            Text(_langFlag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_langName,
                  style:
                      const TextStyle(color: _N.textPrimary, fontSize: 14.5)),
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
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: _N.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: _N.cardBorder)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: _N.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(children: [
                Icon(Icons.translate_rounded, color: _N.indigoLight, size: 18),
                SizedBox(width: 10),
                Text('Select Language',
                    style: TextStyle(
                      color: _N.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    )),
              ]),
            ),
            const Divider(height: 1, color: _N.cardBorder),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: _languages.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: _N.cardBorder, indent: 20),
                itemBuilder: (ctx, i) {
                  final lang = _languages[i];
                  final selected = lang['code'] == _selectedLanguage;
                  return ListTile(
                    leading: Text(lang['flag']!,
                        style: const TextStyle(fontSize: 22)),
                    title: Text(lang['name']!,
                        style: TextStyle(
                          color: selected ? _N.indigoLight : _N.textPrimary,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w400,
                          fontSize: 14.5,
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
          ],
        ), // ← Column close paren was missing, should be Column(...) not Column(children: [...])
      ), // ← Container close paren
    ); // ← showModalBottomSheet close paren
  }

  // ── Create account button ─────────────────────────────────────────────────

  Widget _createAccountBtn() => GestureDetector(
        onTap: _isLoading
            ? null
            : () async {
                _buttonCtrl.forward();
                await Future.delayed(const Duration(milliseconds: 100));
                _buttonCtrl.reverse();
                _register();
              },
        child: ScaleTransition(
          scale: _buttonScale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: _isLoading
                    ? [_N.indigo.withOpacity(0.5), _N.violet.withOpacity(0.5)]
                    : [_N.indigo, _N.violet],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: _isLoading
                  ? []
                  : [
                      BoxShadow(
                        color: _N.indigo.withOpacity(0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      )
                    ],
            ),
            child: Center(
              child: _isLoading
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              _N.cyan.withOpacity(0.9)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Creating account...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          )),
                    ])
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 9),
                        const Text('Create Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            )),
                      ],
                    ),
            ),
          ),
        ),
      );

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: _N.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      );

  /// Wraps a widget with staggered fade-in animation
  Widget _staggeredField(int index, Widget child) {
    final start = (index * 0.08).clamp(0.0, 0.9);
    final end = ((index + 1) * 0.08).clamp(0.1, 1.0);

    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, 0.05 * (index + 1)),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _entryCtrl,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _inputField({
    required TextEditingController ctrl,
    required FocusNode focus,
    required bool isFocused,
    required String hint,
    required IconData icon,
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      decoration: BoxDecoration(
        color: _N.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocused ? _N.indigo : _N.cardBorder,
          width: isFocused ? 1.8 : 1,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                    color: _N.indigo.withOpacity(0.25),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 4)),
                BoxShadow(color: _N.indigo.withOpacity(0.12), blurRadius: 8),
              ]
            : [],
      ),
      child: Row(children: [
        const SizedBox(width: 14),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
              color: isFocused ? _N.indigoLight : _N.textMuted, fontSize: 18),
          child: Icon(icon, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: ctrl,
            focusNode: focus,
            obscureText: obscure,
            keyboardType: keyboard,
            style: const TextStyle(color: _N.textPrimary, fontSize: 14.5),
            cursorColor: _N.indigoLight,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: _N.textMuted, fontSize: 14.5),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
              errorStyle: const TextStyle(color: _N.rose, fontSize: 11),
            ),
          ),
        ),
        if (suffix != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: suffix,
          ),
      ]),
    );
  }

  Widget _buildLoginLink() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Already have an account? ',
              style: TextStyle(color: _N.textMuted, fontSize: 13.5)),
          GestureDetector(
            onTap: _openLoginScreen,
            child: const Text('Sign In',
                style: TextStyle(
                  color: _N.indigoLight,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      );
}

// ── Dot grid painter ──────────────────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6366F1).withOpacity(0.04)
      ..strokeCap = StrokeCap.round;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter _) => false;
}
