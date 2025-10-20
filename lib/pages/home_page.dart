import 'package:flutter/material.dart';
import 'package:starter_kit/services/api_service.dart';
import 'package:starter_kit/services/storage_service.dart';
import 'package:starter_kit/models/user.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<User> _loadMe() async {
    final api = ApiService(StorageService());
    return api.me();
  }

  Future<void> _logout(BuildContext context) async {
    final api = ApiService(StorageService());
    await api.logout();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<User>(
        future: _loadMe(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Gagal memuat user: ${snap.error}'));
          }
          final me = snap.data!;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Berhasil login! (UI/UX OK)'),
                const SizedBox(height: 12),
                Text(me.name, style: Theme.of(context).textTheme.titleMedium),
                Text(me.email),
              ],
            ),
          );
        },
      ),
    );
  }
}
