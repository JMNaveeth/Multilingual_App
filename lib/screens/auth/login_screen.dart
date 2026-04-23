import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multilingual_chat_app/providers/auth_provider.dart';
import 'package:multilingual_chat_app/screens/auth/register_screen.dart';

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
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _emailFocused = false;
  bool _passwordFocused = false;

  late final AnimationController _bgCtrl;
  late final AnimationController _entryCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _buttonCtrl;
  late final Animation<double> _entry;
  late final Animation<double> _buttonScale;

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _entry = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic);

    _buttonCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));

    _buttonScale = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _buttonCtrl, curve: Curves.easeInOut));

    _emailFocus.addListener(
        () => setState(() => _emailFocused = _emailFocus.hasFocus));
    _passwordFocus.addListener(
        () => setState(() => _passwordFocused = _passwordFocus.hasFocus));

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _glowCtrl.dispose();
    _entryCtrl.dispose();
    _buttonCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final stopwatch = Stopwatch()..start();
    if (kDebugMode) {
      debugPrint('[LoginScreen] Sign in tapped for: ${_emailCtrl.text.trim()}');
    }
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .login(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (kDebugMode) {
        final authState = ref.read(authProvider);
        debugPrint(
            '[LoginScreen] Sign in completed in ${stopwatch.elapsedMilliseconds}ms, provider hasUser=${authState.value != null}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[LoginScreen] Sign in failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      }
      if (mounted) _snack('Login failed: $e', _N.rose);
    } finally {
      stopwatch.stop();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, Color accent) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: _N.textPrimary)),
      backgroundColor: _N.card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _N.bg,
      body: Stack(children: [
        // ── Animated orb background ──
        _buildBackground(size),

        // ── Dot grid ──
        Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),

        // ── Content ──
        SafeArea(
          child: FadeTransition(
            opacity: _entry,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(_entry),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(children: [
                  SizedBox(height: size.height * 0.08),
                  _buildLogo(),
                  const SizedBox(height: 36),
                  _buildCard(),
                  const SizedBox(height: 24),
                  _buildRegisterLink(),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Background orbs ───────────────────────────────────────────────────────

  Widget _buildBackground(Size size) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        final t = _bgCtrl.value;
        return Stack(children: [
          // Top-left violet orb
          Positioned(
            left: -60 + t * 30,
            top: -80 + t * 40,
            child: _orb(260, _N.violet.withOpacity(0.18 + t * 0.06)),
          ),
          // Bottom-right indigo orb
          Positioned(
            right: -80 + (1 - t) * 30,
            bottom: -60 + (1 - t) * 30,
            child: _orb(300, _N.indigo.withOpacity(0.14 + (1 - t) * 0.06)),
          ),
          // Center-top cyan accent
          Positioned(
            right: size.width * 0.2,
            top: size.height * 0.15,
            child: _orb(120, _N.cyan.withOpacity(0.06 + t * 0.04)),
          ),
        ]);
      },
    );
  }

  Widget _orb(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      );

  // ── Logo ──────────────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Column(children: [
      AnimatedBuilder(
        animation: _glowCtrl,
        builder: (_, __) => Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [_N.indigo, _N.violet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _N.indigo.withOpacity(0.45 + _glowCtrl.value * 0.25),
                blurRadius: 28 + _glowCtrl.value * 12,
                spreadRadius: 2,
              )
            ],
          ),
          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 38),
        ),
      ),
      const SizedBox(height: 18),
      const Text('Nexus',
          style: TextStyle(
            color: _N.textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
          )),
      const SizedBox(height: 6),
      const Text('Your world, every language',
          style: TextStyle(
            color: _N.textMuted,
            fontSize: 13.5,
            letterSpacing: 0.3,
          )),
    ]);
  }

  // ── Glass card ────────────────────────────────────────────────────────────

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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          const Text('Welcome back',
              style: TextStyle(
                color: _N.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              )),
          const SizedBox(height: 4),
          const Text('Sign in to continue',
              style: TextStyle(color: _N.textMuted, fontSize: 13)),
          const SizedBox(height: 28),

          // Email
          _staggeredField(
              0,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Email address'),
                  const SizedBox(height: 8),
                  _buildInputField(
                    controller: _emailCtrl,
                    focusNode: _emailFocus,
                    isFocused: _emailFocused,
                    hint: 'you@example.com',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email required';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(v)) return 'Enter a valid email';
                      return null;
                    },
                  ),
                ],
              )),

          const SizedBox(height: 20),

          // Password
          _staggeredField(
              1,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Password'),
                  const SizedBox(height: 8),
                  _buildInputField(
                    controller: _passwordCtrl,
                    focusNode: _passwordFocus,
                    isFocused: _passwordFocused,
                    hint: '••••••••',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscurePassword,
                    suffix: GestureDetector(
                      onTap: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
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

          // Forgot password
          _staggeredField(
              2,
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 8)),
                  child: const Text('Forgot password?',
                      style: TextStyle(
                        color: _N.indigoLight,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              )),

          const SizedBox(height: 8),

          // Sign in button
          _staggeredField(3, _buildSignInBtn()),

          const SizedBox(height: 20),

          // Divider
          Row(children: [
            Expanded(child: Container(height: 1, color: _N.cardBorder)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('or continue with',
                  style: TextStyle(color: _N.textMuted, fontSize: 11.5)),
            ),
            Expanded(child: Container(height: 1, color: _N.cardBorder)),
          ]),

          const SizedBox(height: 20),

          // Social row
          Row(children: [
            Expanded(
                child: _socialBtn(
                    label: 'Google',
                    icon: Icons.g_mobiledata_rounded,
                    color: const Color(0xFFEA4335))),
            const SizedBox(width: 12),
            Expanded(
                child: _socialBtn(
                    label: 'Apple',
                    icon: Icons.apple_rounded,
                    color: _N.textSecondary)),
          ]),
        ]),
      ),
    );
  }

  Widget _fieldLabel(String label) => Text(
        label,
        style: const TextStyle(
          color: _N.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      );

  /// Wraps a widget with staggered fade-in animation
  Widget _staggeredField(int index, Widget child) {
    final delay = Duration(milliseconds: 60 + (index * 50));
    return FutureBuilder<bool>(
      future: Future.delayed(delay, () => true),
      builder: (_, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Opacity(opacity: 0, child: child);
        }
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
            parent: _entryCtrl,
            curve: Interval(
              (index * 0.12).clamp(0, 0.9),
              ((index + 1) * 0.12).clamp(0.1, 1.0),
              curve: Curves.easeOut,
            ),
          )),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, 0.08 * (index + 1)),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _entryCtrl,
              curve: Interval(
                (index * 0.12).clamp(0, 0.9),
                ((index + 1) * 0.12).clamp(0.1, 1.0),
                curve: Curves.easeOutCubic,
              ),
            )),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
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
            controller: controller,
            focusNode: focusNode,
            obscureText: obscure,
            keyboardType: keyboardType,
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
          Padding(padding: const EdgeInsets.only(right: 12), child: suffix),
      ]),
    );
  }

  Widget _buildSignInBtn() {
    return GestureDetector(
      onTap: _isLoading
          ? null
          : () async {
              _buttonCtrl.forward();
              await Future.delayed(const Duration(milliseconds: 100));
              _buttonCtrl.reverse();
              _login();
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
                    const Text('Signing in...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                  ])
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Sign In',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          )),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 18),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _socialBtn({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: _N.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _N.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 7),
            Text(label,
                style: const TextStyle(
                  color: _N.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have an account? ",
            style: TextStyle(color: _N.textMuted, fontSize: 13.5)),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          ),
          child: const Text('Create one',
              style: TextStyle(
                color: _N.indigoLight,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              )),
        ),
      ],
    );
  }
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
