import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:starter_kit/services/api_service.dart';
import 'package:starter_kit/services/storage_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _otpC = TextEditingController();
  final _passC = TextEditingController();
  final _pass2C = TextEditingController();

  bool _loading = false;
  bool _otpSent = false;
  bool _showPass = false;
  bool _showPass2 = false;

  late final ApiService api;
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    api = ApiService(StorageService());
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _ac.dispose();
    _emailC.dispose();
    _otpC.dispose();
    _passC.dispose();
    _pass2C.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Email wajib diisi';
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!re.hasMatch(value)) return 'Format email tidak valid';
    return null;
  }

  String? _validateOtp(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'OTP wajib diisi';
    if (s.length < 4) return 'OTP minimal 4 digit';
    return null;
  }

  String? _validatePass(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Password wajib diisi';
    if (s.length < 6) return 'Minimal 6 karakter';
    return null;
  }

  Future<void> _sendOtp() async {
    if (_validateEmail(_emailC.text) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan email yang valid')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await api.sendOtp(_emailC.text.trim());
      if (!mounted) return;
      setState(() => _otpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTP dikirim ke ${_emailC.text.trim()}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final emailErr = _validateEmail(_emailC.text);
    final otpErr = _validateOtp(_otpC.text);
    final passErr = _validatePass(_passC.text);
    final pass2Err = _pass2C.text == _passC.text
        ? null
        : 'Konfirmasi password tidak sama';
    if (emailErr != null ||
        otpErr != null ||
        passErr != null ||
        pass2Err != null) {
      _formKey.currentState?.validate();
      return;
    }

    setState(() => _loading = true);
    try {
      await api.resetPassword(
        email: _emailC.text.trim(),
        otp: _otpC.text.trim(),
        password: _passC.text,
        passwordConfirmation: _pass2C.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password berhasil direset. Silakan login.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
      appBar: AppBar(
        title: const Text('Lupa Password'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // background gradient + blobs (match login)
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
                        size: 380,
                        colorA: isDark
                            ? const Color(0xFF6C63FF)
                            : const Color(0xFF8A80FF),
                        colorB: isDark
                            ? const Color(0xFF00E5FF)
                            : const Color(0xFF5CE1FF),
                        dx: math.sin(t * 2 * math.pi) * 40,
                        dy: math.cos(t * 2 * math.pi) * 30,
                        topFactor: 0.25,
                      ),
                      _blob(
                        context,
                        size: 320,
                        colorA: isDark
                            ? const Color(0xFFFF5ACD)
                            : const Color(0xFFFF89DA),
                        colorB: isDark
                            ? const Color(0xFFFBDA61)
                            : const Color(0xFFFFE7A8),
                        dx: math.cos(t * 2 * math.pi) * -36,
                        dy: math.sin(t * 2 * math.pi) * 22,
                        topFactor: 0.60,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // card
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(20),
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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_reset_rounded,
                                size: 56,
                                color: cs.primary.withOpacity(
                                  isDark ? .95 : .85,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _otpSent ? 'Reset Password' : 'Kirim OTP',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface.withOpacity(0.95),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _otpSent
                                    ? 'Masukkan OTP yang dikirim ke email dan buat password baru'
                                    : 'Masukkan email terdaftar untuk menerima OTP',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurface.withOpacity(
                                    isDark ? .80 : .70,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Email selalu tampil
                              TextFormField(
                                controller: _emailC,
                                enabled:
                                    !_otpSent, // kunci setelah OTP terkirim
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                decoration: _input(
                                  context,
                                  'Email',
                                  Icons.alternate_email,
                                  hint: 'nama@domain.com',
                                ),
                                validator: _validateEmail,
                              ),

                              // Field tambahan ketika OTP sudah dikirim
                              if (_otpSent) ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _otpC,
                                  keyboardType: TextInputType.number,
                                  decoration: _input(
                                    context,
                                    'OTP',
                                    Icons.pin,
                                    hint: 'Masukkan kode OTP',
                                  ),
                                  validator: _validateOtp,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _passC,
                                  obscureText: !_showPass,
                                  decoration: _input(
                                    context,
                                    'Password baru',
                                    Icons.lock,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _showPass
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                      onPressed: () => setState(
                                        () => _showPass = !_showPass,
                                      ),
                                    ),
                                  ),
                                  validator: _validatePass,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _pass2C,
                                  obscureText: !_showPass2,
                                  decoration: _input(
                                    context,
                                    'Konfirmasi password',
                                    Icons.lock_outline,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _showPass2
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                      ),
                                      onPressed: () => setState(
                                        () => _showPass2 = !_showPass2,
                                      ),
                                    ),
                                  ),
                                  validator: (v) => v == _passC.text
                                      ? null
                                      : 'Konfirmasi password tidak sama',
                                ),
                              ],

                              const SizedBox(height: 16),
                              SizedBox(
                                height: 48,
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _loading
                                      ? null
                                      : (_otpSent ? _resetPassword : _sendOtp),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cs.primary,
                                    foregroundColor: cs.onPrimary,
                                    elevation: isDark ? 8 : 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          _otpSent
                                              ? 'Simpan Password'
                                              : 'Kirim OTP',
                                        ),
                                ),
                              ),
                              if (_otpSent)
                                TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () => setState(() {
                                          _otpSent = false;
                                          _otpC.clear();
                                          _passC.clear();
                                          _pass2C.clear();
                                        }),
                                  child: const Text(
                                    'Ubah email / Kirim ulang OTP',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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

/// --- kecil: blob helper (sama seperti di login) ---
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
