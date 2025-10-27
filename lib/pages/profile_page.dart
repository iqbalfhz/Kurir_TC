import 'package:flutter/material.dart';
import 'package:starter_kit/models/user.dart';
import 'package:starter_kit/services/api_service.dart';
import 'package:starter_kit/services/storage_service.dart';
import 'package:starter_kit/services/theme_controller.dart';
import 'package:starter_kit/widgets/app_shell.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ApiService _api;
  Future<User>? _meFuture;

  @override
  void initState() {
    super.initState();
    _api = ApiService(StorageService());
    _meFuture = _api.me();
  }

  Future<void> _refresh() async {
    setState(() => _meFuture = _api.me());
    await _meFuture;
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }
  // Name editing is disabled in-app. Profile changes must be performed by
  // an administrator or via the backend API. The inline edit flow was
  // intentionally removed to avoid client-server state mismatch.

  void _changePassword() async {
    final formKey = GlobalKey<FormState>();
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti Kata Sandi'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Kata sandi saat ini',
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Kata sandi baru'),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Konfirmasi kata sandi baru',
                ),
                validator: (v) => (v != newCtrl.text) ? 'Tidak cocok' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (ok == true) {
      // TODO: panggil API ganti password
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kata sandi diperbarui (MVP).')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppShell(
      currentIndex: 2,
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<User>(
          future: _meFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return ListView(
                children: const [
                  SizedBox(height: 240),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }
            if (snap.hasError) {
              return ListView(
                children: const [
                  SizedBox(height: 240),
                  Center(child: Text('Gagal memuat data')),
                ],
              );
            }
            final me =
                snap.data ??
                User(id: 0, name: 'Kurir', email: '-', avatarUrl: null);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _ProfileHeader(
                  name: me.name,
                  email: me.email,
                  avatarUrl: me.avatarUrl,
                ),
                const SizedBox(height: 16),
                // const _QuickStats(),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Akun',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Nama'),
                      subtitle: Text(me.name),
                      // Name is controlled by the backend/admin. Make it non-editable
                      // in-app and show a lock icon to indicate this.
                      trailing: const Icon(Icons.lock_outline),
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.alternate_email_rounded),
                      title: const Text('Email'),
                      subtitle: Text(me.email),
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Ganti Kata Sandi'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _changePassword,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Preferensi',
                  children: [
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeController.mode,
                      builder: (context, mode, _) => SwitchListTile.adaptive(
                        secondary: const Icon(Icons.dark_mode_outlined),
                        title: const Text('Mode Gelap'),
                        value: mode == ThemeMode.dark,
                        onChanged: (v) => themeController.set(
                          v ? ThemeMode.dark : ThemeMode.light,
                        ),
                      ),
                    ),
                    const Divider(height: 0),
                    // ListTile(
                    //   leading: const Icon(Icons.notifications_active_outlined),
                    //   title: const Text('Notifikasi'),
                    //   subtitle: const Text(
                    //     'Ringkasan harian & status pengiriman',
                    //   ),
                    //   trailing: Switch(
                    //     value: true,
                    //     onChanged: (v) =>
                    //         ScaffoldMessenger.of(context).showSnackBar(
                    //           const SnackBar(
                    //             content: Text(
                    //               'Preferensi notifikasi diperbarui (MVP).',
                    //             ),
                    //           ),
                    //         ),
                    //   ),
                    // ),
                  ],
                ),
                const SizedBox(height: 16),
                const _SectionCard(
                  title: 'Tentang',
                  children: [
                    ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Versi Aplikasi'),
                      subtitle: Text('1.0.0 (MVP)'),
                    ),
                    Divider(height: 0),
                    ListTile(
                      leading: Icon(Icons.privacy_tip_outlined),
                      title: Text('Kebijakan Privasi'),
                      subtitle: Text(
                        'Data foto & lokasi digunakan untuk bukti pengantaran.',
                      ),
                    ),
                  ],
                ),
                // const SizedBox(height: 24),
                // FilledButton.icon(
                //   onPressed: _logout,
                //   icon: const Icon(Icons.logout_rounded),
                //   label: const Text('Keluar Akun'),
                // ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    this.avatarUrl,
  });
  final String name;
  final String email;
  final String? avatarUrl;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].isNotEmpty ? parts[0][0] : ' ').toUpperCase() +
        (parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : ' ')
            .toUpperCase();
  }

  Widget _buildAvatar(BuildContext context) {
    final theme = Theme.of(context);
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: theme.colorScheme.onPrimary.withOpacity(.15),
      );
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: theme.colorScheme.onPrimary.withOpacity(.15),
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildAvatar(context),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimary.withOpacity(.9),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.verified_user_outlined,
            color: theme.colorScheme.onPrimary,
          ),
        ],
      ),
    );
  }
}

// class _QuickStats extends StatelessWidget {
//   const _QuickStats({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     return Row(
//       children: const [
//         Expanded(
//           child: _StatTile(
//             icon: Icons.check_circle_outline,
//             label: 'Selesai',
//             value: '24',
//           ),
//         ),
//         SizedBox(width: 10),
//         Expanded(
//           child: _StatTile(
//             icon: Icons.local_shipping_outlined,
//             label: 'Berjalan',
//             value: '5',
//           ),
//         ),
//         SizedBox(width: 10),
//         Expanded(
//           child: _StatTile(
//             icon: Icons.cancel_outlined,
//             label: 'Gagal',
//             value: '1',
//           ),
//         ),
//       ],
//     );
//   }
// }

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 0),
          ...children,
        ],
      ),
    );
  }
}
