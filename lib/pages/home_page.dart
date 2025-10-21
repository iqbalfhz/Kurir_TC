import 'package:flutter/material.dart';
import 'package:starter_kit/services/api_service.dart';
import 'package:starter_kit/services/storage_service.dart';
import 'package:starter_kit/models/user.dart';
import 'package:starter_kit/widgets/app_shell.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ApiService _api;
  Future<User>? _meFuture;

  @override
  void initState() {
    super.initState();
    _api = ApiService(StorageService());
    _meFuture = _api.me();
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  String _formatDate(DateTime date) {
    const hari = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ];
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${hari[date.weekday % 7]}, ${date.day} ${bulan[date.month - 1]} ${date.year}';
  }

  final List<_DeliveryItem> _todayDeliveries = [
    _DeliveryItem(
      'PT ABC Logistics',
      'Jl. Sudirman No.12, Jakarta',
      DeliveryStatus.inTransit,
    ),
    _DeliveryItem(
      'Bank XYZ Tower',
      'Jl. Gatot Subroto No.1, Jakarta',
      DeliveryStatus.assigned,
    ),
    _DeliveryItem(
      'Kantor KLM',
      'Jl. Rasuna Said Blok X-5, Jakarta',
      DeliveryStatus.done,
    ),
    _DeliveryItem(
      'PT Maju Jaya',
      'Jl. Thamrin No.45, Jakarta',
      DeliveryStatus.assigned,
    ),
    _DeliveryItem(
      'PT Sinar Abadi',
      'Jl. Gajah Mada No.22, Jakarta',
      DeliveryStatus.inTransit,
    ),
    _DeliveryItem(
      'PT Bumi Raya',
      'Jl. Ahmad Yani No.5, Bekasi',
      DeliveryStatus.assigned,
    ),
    _DeliveryItem(
      'CV Sentosa',
      'Jl. Merdeka No.11, Tangerang',
      DeliveryStatus.done,
    ),
    _DeliveryItem(
      'PT Indo Cargo',
      'Jl. Panjang No.88, Jakarta Barat',
      DeliveryStatus.assigned,
    ),
    _DeliveryItem(
      'PT Mandiri Logistik',
      'Jl. Kemang Raya No.9, Jakarta Selatan',
      DeliveryStatus.inTransit,
    ),
    _DeliveryItem(
      'PT Global Express',
      'Jl. Pemuda No.7, Depok',
      DeliveryStatus.done,
    ),
  ];

  Future<void> _refresh() async {
    setState(() {
      _meFuture = _api.me();
    });
    await _meFuture;
  }

  Future<void> _onAddPressed() async {
    final result = await Navigator.pushNamed(context, '/delivery');
    if (result == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppShell(
      currentIndex: 0,
      fab: FloatingActionButton.extended(
        onPressed: _onAddPressed,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Pengiriman'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _ModernSliverAppBar(meFuture: _meFuture, onLogout: _logout),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TodaySummary(items: _todayDeliveries),
                    const SizedBox(height: 12),
                    Text(
                      'Pengiriman Hari Ini',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = _todayDeliveries[index];
                return Padding(
                  padding: EdgeInsets.fromLTRB(16, index == 0 ? 0 : 8, 16, 8),
                  child: _DeliveryCard(
                    item: item,
                    onDetail: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Buka detail: ${item.title}')),
                      );
                    },
                    onDeliver: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Form bukti serah: ${item.title}'),
                        ),
                      );
                    },
                  ),
                );
              }, childCount: _todayDeliveries.length),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}

class _ModernSliverAppBar extends StatelessWidget {
  const _ModernSliverAppBar({required this.meFuture, required this.onLogout});
  final Future<User>? meFuture;
  final Future<void> Function() onLogout;

  String _firstName(String full) => full.trim().split(' ').first;
  String _initials(String full) {
    final parts = full.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].isNotEmpty ? parts[0][0] : '') +
        (parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '');
  }

  String _formatDate(DateTime date) {
    const hari = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ];
    const bulan = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${hari[date.weekday % 7]}, ${date.day} ${bulan[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    return SliverAppBar(
      pinned: true,
      expandedHeight: 160,
      scrolledUnderElevation: 0,
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      titleSpacing: 0,
      flexibleSpace: LayoutBuilder(
        builder: (ctx, constraints) {
          final collapsed = constraints.maxHeight < 120;
          return FlexibleSpaceBar(
            centerTitle: false,
            titlePadding: const EdgeInsetsDirectional.only(
              start: 16,
              bottom: 12,
              end: 16,
            ),
            title: FutureBuilder<User>(
              future: meFuture,
              builder: (context, snap) {
                final subtitle = Text(
                  _formatDate(now),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary.withOpacity(.85),
                  ),
                );
                if (snap.connectionState == ConnectionState.waiting) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        collapsed ? 'Beranda' : 'Selamat datang',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: theme.colorScheme.onPrimary),
                      ),
                      const SizedBox(height: 2),
                      subtitle,
                    ],
                  );
                }
                final hasData = snap.hasData;
                final name = hasData ? _firstName(snap.data!.name) : 'Kurir';
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.onPrimary.withOpacity(
                        .15,
                      ),
                      child: Text(
                        hasData
                            ? _initials(snap.data!.name).toUpperCase()
                            : 'K',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            collapsed ? 'Halo, $name' : 'Halo, $name 👋',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          subtitle,
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer,
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    top: -20,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onPrimary.withOpacity(.06),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    left: -20,
                    bottom: 10,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onPrimary.withOpacity(.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        IconButton(
          tooltip: 'Notifikasi',
          onPressed: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Belum ada notifikasi'))),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        IconButton(
          tooltip: 'Logout',
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.items});
  final List<_DeliveryItem> items;

  int get _done => items.where((e) => e.status == DeliveryStatus.done).length;
  int get _inTransit =>
      items.where((e) => e.status == DeliveryStatus.inTransit).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Dokumen',
            value: items.length.toString(),
            icon: Icons.assignment_outlined,
            color: theme.colorScheme.primaryContainer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            title: 'Selesai',
            value: _done.toString(),
            icon: Icons.check_circle_outlined,
            color: Colors.green.withOpacity(.15),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            title: 'Berjalan',
            value: _inTransit.toString(),
            icon: Icons.local_shipping_outlined,
            color: Colors.blue.withOpacity(.15),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(.7),
                  ),
                ),
                const SizedBox(height: 2),
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

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.item,
    required this.onDetail,
    required this.onDeliver,
  });
  final _DeliveryItem item;
  final VoidCallback onDetail;
  final VoidCallback onDeliver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusChip = switch (item.status) {
      DeliveryStatus.assigned => _buildChip(
        context,
        'Diterima',
        theme.colorScheme.outline,
      ),
      DeliveryStatus.inTransit => _buildChip(
        context,
        'Dalam Perjalanan',
        theme.colorScheme.primary,
      ),
      DeliveryStatus.done => _buildChip(context, 'Selesai', Colors.green),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(item.address, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                statusChip,
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDetail,
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Detail'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onDeliver,
                    icon: const Icon(Icons.delivery_dining_rounded),
                    label: const Text('Serahkan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.4)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DeliveryItem {
  final String title;
  final String address;
  final DeliveryStatus status;
  const _DeliveryItem(this.title, this.address, this.status);
}

enum DeliveryStatus { assigned, inTransit, done }
