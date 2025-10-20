import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  const ResetPasswordPage({super.key, required this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpC = TextEditingController();
  final _passC = TextEditingController();
  final _confirmC = TextEditingController();
  bool _loading = false;
  bool _showPass = false;
  bool _showConfirm = false;
  late final ApiService api;

  @override
  void initState() {
    super.initState();
    api = ApiService(StorageService());
  }

  @override
  void dispose() {
    _otpC.dispose();
    _passC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  String? _vOtp(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'OTP wajib diisi';
    if (s.length < 4) return 'OTP minimal 4 digit';
    return null;
  }

  String? _vPass(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Password baru wajib diisi';
    if (s.length < 6) return 'Minimal 6 karakter';
    return null;
  }

  String? _vConfirm(String? v) {
    if (v != _passC.text) return 'Konfirmasi tidak cocok';
    return null;
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok || _loading) return;

    setState(() => _loading = true);
    try {
      await api.resetPassword(
        email: widget.email,
        otp: _otpC.text.trim(),
        password: _passC.text,
        passwordConfirmation: _confirmC.text,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password berhasil direset. Silakan login.'),
        ),
      );
      Navigator.of(context).popUntil((r) => r.isFirst); // kembali ke login
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Email: ${widget.email}'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _otpC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'OTP',
                        prefixIcon: Icon(Icons.pin),
                      ),
                      validator: _vOtp,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passC,
                      obscureText: !_showPass,
                      decoration: InputDecoration(
                        labelText: 'Password baru',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPass ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setState(() => _showPass = !_showPass),
                        ),
                      ),
                      validator: _vPass,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmC,
                      obscureText: !_showConfirm,
                      decoration: InputDecoration(
                        labelText: 'Konfirmasi password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showConfirm
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setState(() => _showConfirm = !_showConfirm),
                        ),
                      ),
                      validator: _vConfirm,
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
                            : const Text('Simpan Password'),
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
  }
}
