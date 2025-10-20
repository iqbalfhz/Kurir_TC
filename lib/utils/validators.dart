class Validators {
  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
    final r = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!r.hasMatch(v.trim())) return 'Format email tidak valid';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password wajib diisi';
    if (v.length < 6) return 'Minimal 6 karakter';
    return null;
  }

  static String? notEmpty(String? v, {String label = 'Field'}) {
    if (v == null || v.trim().isEmpty) return '$label wajib diisi';
    return null;
  }
}
