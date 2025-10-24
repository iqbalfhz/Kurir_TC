import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:starter_kit/services/theme_controller.dart';
import 'package:starter_kit/pages/forgot_password_page.dart';
import 'package:starter_kit/services/api_service.dart';
import 'package:starter_kit/services/storage_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierC = TextEditingController();
  final _passwordC = TextEditingController();
  final _identifierNode = FocusNode();
  final _passwordNode = FocusNode();

  late final ApiService api;
  late final AnimationController _ac;

  bool _loading = false;
  bool _isPasswordVisible = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    api = ApiService(StorageService());
  }

  @override
  void dispose() {
    _ac.dispose();
    _identifierC.dispose();
    _passwordC.dispose();
    _identifierNode
      ..unfocus()
      ..dispose();
    _passwordNode
      ..unfocus()
      ..dispose();
    super.dispose();
  }

  String? _validateIdentifier(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Email wajib diisi';
    return null;
  }

  String? _validatePassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Password wajib diisi';
    if (value.length < 6) return 'Minimal 6 karakter';
    return null;
  }

  String _prettyError(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _loading) return;

    final email = _identifierC.text.trim();
    final password = _passwordC.text;

    setState(() {
      _loading = true;
      _errorText = null;
    });
    _identifierNode.unfocus();
    _passwordNode.unfocus();

    try {
      // login() sekarang sudah robust: bisa handle response {data:{token,user}} ataupun {data:{email,name,token}}
      await api.login(email: email, password: password);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      final msg = _prettyError(e);
      setState(() => _errorText = msg);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ac,
              builder: (_, __) {
                final t = _ac.value;
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [Color(0xFF0F1020), Color(0xFF0A0B14)]
                          : const [Color(0xFFEFF3FF), Color(0xFFF8FAFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      _blob(
                        context,
                        size: 420,
                        colorA: isDark
                            ? const Color(0xFF6C63FF)
                            : const Color(0xFF8A80FF),
                        colorB: isDark
                            ? const Color(0xFF00E5FF)
                            : const Color(0xFF5CE1FF),
                        dx: math.sin(t * 2 * math.pi) * 60,
                        dy: math.cos(t * 2 * math.pi) * 40,
                        topFactor: 0.30,
                      ),
                      _blob(
                        context,
                        size: 360,
                        colorA: isDark
                            ? const Color(0xFF00E5FF)
                            : const Color(0xFF00B7FF),
                        colorB: isDark
                            ? const Color(0xFF00FF85)
                            : const Color(0xFF7BFFB5),
                        dx: math.cos(t * 2 * math.pi) * -50,
                        dy: math.sin(t * 2 * math.pi) * 30,
                        topFactor: 0.55,
                      ),
                      _blob(
                        context,
                        size: 300,
                        colorA: isDark
                            ? const Color(0xFFFF5ACD)
                            : const Color(0xFFFF89DA),
                        colorB: isDark
                            ? const Color(0xFFFBDA61)
                            : const Color(0xFFFFE7A8),
                        dx: math.sin(t * 2 * math.pi) * -40,
                        dy: math.sin(t * 2 * math.pi) * -40,
                        topFactor: 0.15,
                      ),
                      Positioned.fill(
                        child: CustomPaint(painter: _CircuitPainter(t, isDark)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const Positioned(
            top: 12,
            right: 12,
            child: SafeArea(child: _ThemeToggle()),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 480;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 24 : 16,
                        vertical: 24,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: isDark ? 18 : 12,
                            sigmaY: isDark ? 18 : 12,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDark
                                    ? [
                                        Colors.white.withOpacity(0.10),
                                        Colors.white.withOpacity(0.04),
                                      ]
                                    : [
                                        Colors.white.withOpacity(0.85),
                                        Colors.white.withOpacity(0.65),
                                      ],
                              ),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.16)
                                    : Colors.black.withOpacity(0.06),
                                width: 1.1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black.withOpacity(0.18)
                                      : Colors.black.withOpacity(0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.login_rounded,
                                  size: 56,
                                  color: cs.primary.withOpacity(
                                    isDark ? 0.9 : 0.8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Masuk',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: cs.onSurface.withOpacity(0.95),
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Email + password untuk melanjutkan',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurface.withOpacity(
                                      isDark ? 0.80 : 0.70,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _identifierC,
                                        focusNode: _identifierNode,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.username,
                                          AutofillHints.email,
                                        ],
                                        decoration: _input(
                                          context,
                                          'Email',
                                          Icons.person_outline,
                                          hint: 'Masukan Email Anda',
                                        ),
                                        validator: _validateIdentifier,
                                        onFieldSubmitted: (_) =>
                                            _passwordNode.requestFocus(),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _passwordC,
                                        focusNode: _passwordNode,
                                        textInputAction: TextInputAction.done,
                                        obscureText: !_isPasswordVisible,
                                        autofillHints: const [
                                          AutofillHints.password,
                                        ],
                                        decoration: _input(
                                          context,
                                          'Password',
                                          Icons.lock_outline,
                                          suffix: IconButton(
                                            tooltip: _isPasswordVisible
                                                ? 'Sembunyikan'
                                                : 'Tampilkan',
                                            icon: Icon(
                                              _isPasswordVisible
                                                  ? Icons.visibility
                                                  : Icons.visibility_off,
                                            ),
                                            onPressed: () => setState(
                                              () => _isPasswordVisible =
                                                  !_isPasswordVisible,
                                            ),
                                          ),
                                        ),
                                        validator: _validatePassword,
                                        onFieldSubmitted: (_) => _submit(),
                                      ),
                                      const SizedBox(height: 8),
                                      if (_errorText != null)
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            _errorText!,
                                            style: TextStyle(color: cs.error),
                                          ),
                                        ),
                                      const SizedBox(height: 16),

                                      SizedBox(
                                        height: 48,
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: _loading ? null : _submit,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: cs.primary,
                                            foregroundColor: cs.onPrimary,
                                            elevation: isDark ? 8 : 4,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: _loading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Text('Masuk'),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          TextButton(
                                            onPressed: _loading
                                                ? null
                                                : () {
                                                    Navigator.of(context).push(
                                                      _slideRoute(
                                                        const ForgotPasswordPage(),
                                                      ),
                                                    );
                                                  },
                                            child: const Text('Lupa password?'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _input(
    BuildContext context,
    String label,
    IconData icon, {
    String? hint,
    Widget? suffix,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.black.withOpacity(0.03);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.22)
        : Colors.black.withOpacity(0.12);
    final focusColor = isDark
        ? Colors.white.withOpacity(0.35)
        : Colors.black.withOpacity(0.35);

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: focusColor, width: 1.4),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

/// ===== Helpers untuk background =====

Widget _blob(
  BuildContext context, {
  required double size,
  required Color colorA,
  required Color colorB,
  required double dx,
  required double dy,
  required double topFactor,
}) {
  final w = MediaQuery.of(context).size.width;
  final h = MediaQuery.of(context).size.height;
  return Positioned(
    left: w * 0.5 - size / 2 + dx,
    top: h * topFactor - size / 2 + dy,
    child: IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [colorA.withOpacity(.45), colorB.withOpacity(0)],
          ),
        ),
      ),
    ),
  );
}

class _CircuitPainter extends CustomPainter {
  _CircuitPainter(this.t, this.isDark);
  final double t;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.05)
      ..style = PaintingStyle.fill;
    const gap = 26.0;
    for (double y = gap; y < size.height; y += gap) {
      for (double x = gap; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), .9, dot);
      }
    }

    final neon = Paint()
      ..color = (isDark ? const Color(0xFF00E5FF) : const Color(0xFF0078D4))
          .withOpacity(.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final path = Path();
    double y(double i) =>
        size.height * (0.25 + 0.1 * math.sin((i * .8) + t * 2 * math.pi));
    path.moveTo(0, y(0));
    for (double x = 0; x <= size.width; x += 16) {
      path.lineTo(x, y(x / 24));
    }
    canvas.drawPath(path, neon);

    final node = Paint()
      ..color = (isDark ? const Color(0xFF00FF85) : const Color(0xFF0ACF83))
          .withOpacity(.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (double x = 0; x <= size.width; x += size.width / 6) {
      canvas.drawCircle(Offset(x, y(x / 24)), 3.2, node);
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter old) =>
      old.t != t || old.isDark != isDark;
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: IconButton.filledTonal(
        tooltip: isDark ? 'Switch ke Light Mode' : 'Switch ke Dark Mode',
        onPressed: themeController.toggle,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) =>
              RotationTransition(turns: anim, child: child),
          child: Icon(
            isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            key: ValueKey(isDark),
          ),
        ),
      ),
    );
  }
}

Route _slideRoute(Widget page, {Offset begin = const Offset(1, 0)}) {
  return PageRouteBuilder(
    opaque: false,
    barrierColor: Colors.transparent,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (context, anim, __, child) {
      final slideTween = Tween(
        begin: begin,
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeInOutQuart));
      final fadeTween = Tween<double>(
        begin: 0,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeInOut));
      final sigma = lerpDouble(0, 14, anim.value)!;
      final dim = lerpDouble(0, 0.12, anim.value)!;
      return Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: Container(color: Colors.black.withOpacity(dim)),
            ),
          ),
          FadeTransition(
            opacity: anim.drive(fadeTween),
            child: SlideTransition(
              position: anim.drive(slideTween),
              child: child,
            ),
          ),
        ],
      );
    },
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 420),
  );
}
