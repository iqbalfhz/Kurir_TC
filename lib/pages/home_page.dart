import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:starter_kit/services/api_service.dart';
import 'package:starter_kit/services/storage_service.dart';
import 'package:starter_kit/models/dashboard.dart';
import 'package:starter_kit/models/delivery.dart' as m;
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
  Future<DashboardCounts>? _dashboardFuture;

  // cached deliveries fetched from API so we can compute ranges
  final List<m.Delivery> _allDeliveries = [];
  // simple pagination state for lazy loading
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  late final ScrollController _scrollCtrl;
  final _storage = StorageService();

  // computed counts for each range
  DashboardCounts _dailyCounts = DashboardCounts(
    documents: 0,
    done: 0,
    inTransit: 0,
  );
  DashboardCounts _weeklyCounts = DashboardCounts(
    documents: 0,
    done: 0,
    inTransit: 0,
  );
  DashboardCounts _monthlyCounts = DashboardCounts(
    documents: 0,
    done: 0,
    inTransit: 0,
  );

  @override
  void initState() {
    super.initState();
    _api = ApiService(StorageService());
    _meFuture = _api.me();
    _dashboardFuture = _api.getDashboardCounts();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCachedThenRefresh();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  // Deliveries will be loaded from backend (not limited to today)
  final List<_DeliveryItem> _todayDeliveries = [];

  Future<void> _refresh() async {
    setState(() {
      _meFuture = _api.me();
      _dashboardFuture = _api.getDashboardCounts();
    });
    await Future.wait([
      _meFuture ?? Future.value(),
      _dashboardFuture ?? Future.value(),
    ]);
    await _loadPage(1, replace: true);
  }

  Future<void> _onAddPressed() async {
    final result = await Navigator.pushNamed(context, '/delivery');
    if (result == true) await _refresh();
  }

  DeliveryStatus _mapStatus(String status) {
    final s = status.toLowerCase().trim();
    if (s == '1' || s == 'assigned' || s == 'accepted' || s == 'diterima') {
      return DeliveryStatus.assigned;
    }
    if (s == '2' ||
        s == 'in_transit' ||
        s == 'in-transit' ||
        s == 'intransit' ||
        s == 'in transit' ||
        s == 'berjalan' ||
        s == 'delivered' ||
        s == 'on_the_way' ||
        s == 'on the way') {
      return DeliveryStatus.inTransit;
    }
    if (s == '3' ||
        s == 'done' ||
        s == 'completed' ||
        s == 'selesai' ||
        s == 'delivered') {
      return DeliveryStatus.done;
    }
    return DeliveryStatus.inTransit;
  }

  /// Load cached deliveries (if present) so UI shows quickly, then refresh
  /// page 1 from backend and enable lazy loading for subsequent pages.
  Future<void> _loadCachedThenRefresh() async {
    if (!mounted) return;
    try {
      final raw = await _storage.getCachedDeliveries();
      if (raw != null && raw.isNotEmpty) {
        try {
          final parsed = jsonDecode(raw) as List<dynamic>;
          final cached = parsed
              .map((e) => m.Delivery.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _allDeliveries
            ..clear()
            ..addAll(cached);
          _computeAllRangeCounts();
          _updateTodayFromAll();
        } catch (_) {
          // ignore parsing errors and fall through to fresh fetch
        }
      }

      // fetch first page fresh
      await _loadPage(1, replace: true);
    } finally {
      // finished (no explicit loading flag maintained here)
    }
  }

  Future<void> _loadPage(int page, {bool replace = false}) async {
    if (!mounted) return;
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    try {
      final list = await _api.getDeliveries(perPage: 50, page: page);
      if (!mounted) return;

      if (replace) {
        _allDeliveries
          ..clear()
          ..addAll(list);
      } else {
        // append while avoiding duplicates
        final existingIds = _allDeliveries.map((e) => e.id).toSet();
        for (final d in list) {
          if (!existingIds.contains(d.id)) _allDeliveries.add(d);
        }
      }

      // update cache for page 1 only
      if (page == 1) {
        try {
          final jsonList = list.map((d) {
            return {
              'id': d.id,
              'sender_name': d.senderName,
              'receiver_name': d.receiverName,
              'address': d.address,
              'status': d.status,
              'photo_url': d.photoUrl,
              'created_at': d.createdAt?.toIso8601String(),
            };
          }).toList();
          await _storage.saveCachedDeliveries(jsonEncode(jsonList));
        } catch (_) {}
      }

      // mark pagination end based on returned count
      _hasMore = list.length >= 50;
      _currentPage = page;

      _computeAllRangeCounts();
      _updateTodayFromAll();
    } catch (_) {
      // ignore for now
    } finally {
      _isLoadingMore = false;
    }
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore) return;
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final cur = _scrollCtrl.position.pixels;
    if (max - cur < 300) {
      // near bottom
      _loadPage(_currentPage + 1);
    }
  }

  void _updateTodayFromAll() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final todayOnly = _allDeliveries.where((m.Delivery d) {
      final created = d.createdAt;
      if (created == null) return false;
      final createdJakarta = created.toUtc().add(const Duration(hours: 7));
      return createdJakarta.year == now.year &&
          createdJakarta.month == now.month &&
          createdJakarta.day == now.day;
    }).toList();

    final mapped = todayOnly
        .map(
          (m.Delivery d) => _DeliveryItem(
            (d.receiverName.isNotEmpty) ? d.receiverName : d.senderName,
            d.address,
            _mapStatus(d.status),
            d.status,
            id: d.id,
            photoUrl: d.photoUrl,
          ),
        )
        .where(
          (it) =>
              it.status == DeliveryStatus.inTransit ||
              it.status == DeliveryStatus.done,
        )
        .toList();

    setState(() {
      _todayDeliveries
        ..clear()
        ..addAll(mapped);

      // today's counts are available via _dailyCounts/_todayDeliveries
    });
  }

  void _computeAllRangeCounts() {
    // Use Asia/Jakarta (UTC+7) as the reference "now" for all range
    // computations so day/week/month boundaries match the backend.
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));

    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final int daysToMonday = now.weekday - 1; // Mon=1
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysToMonday));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = (now.month < 12)
        ? DateTime(now.year, now.month + 1, 1)
        : DateTime(now.year + 1, 1, 1);

    int dDocs = 0, dDone = 0, dIn = 0;
    int wDocs = 0, wDone = 0, wIn = 0;
    int mDocs = 0, mDone = 0, mIn = 0;

    for (final d in _allDeliveries) {
      final created = d.createdAt;
      if (created == null) continue;

      // convert delivery timestamp to Jakarta for consistent range checks
      final createdJakarta = created.toUtc().add(const Duration(hours: 7));

      final s = d.status.toLowerCase();
      final isDone =
          s == 'done' || s == 'completed' || s == 'selesai' || s == '3';
      final isIn =
          s == 'in_transit' ||
          s == 'in-transit' ||
          s == 'intransit' ||
          s == 'in transit' ||
          s == 'berjalan' ||
          s == 'delivered' ||
          s == '2';

      if (createdJakarta.isBefore(dayStart) ||
          !createdJakarta.isBefore(dayEnd)) {
        // not in day
      } else {
        dDocs++;
        if (isDone) {
          dDone++;
        } else if (isIn)
          dIn++;
      }
      if (createdJakarta.isBefore(weekStart) ||
          !createdJakarta.isBefore(weekEnd)) {
        // not in week
      } else {
        wDocs++;
        if (isDone) {
          wDone++;
        } else if (isIn)
          wIn++;
      }
      if (createdJakarta.isBefore(monthStart) ||
          !createdJakarta.isBefore(monthEnd)) {
        // not in month
      } else {
        mDocs++;
        if (isDone) {
          mDone++;
        } else if (isIn)
          mIn++;
      }
    }

    setState(() {
      _dailyCounts = DashboardCounts(
        documents: dDocs,
        done: dDone,
        inTransit: dIn,
      );
      _weeklyCounts = DashboardCounts(
        documents: wDocs,
        done: wDone,
        inTransit: wIn,
      );
      _monthlyCounts = DashboardCounts(
        documents: mDocs,
        done: mDone,
        inTransit: mIn,
      );
    });
  }

  Widget _buildRangeStatCards(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Hari',
            value: _dailyCounts.documents.toString(),
            icon: Icons.assignment_outlined,
            color: theme.colorScheme.primaryContainer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            title: 'Minggu',
            value: _weeklyCounts.documents.toString(),
            icon: Icons.check_circle_outlined,
            color: Colors.green.withOpacity(.15),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            title: 'Bulan',
            value: _monthlyCounts.documents.toString(),
            icon: Icons.local_shipping_outlined,
            color: Colors.blue.withOpacity(.15),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // compute today's running/done list once so we can show an empty state
    final running = _todayDeliveries
        .where(
          (d) =>
              d.status == DeliveryStatus.inTransit ||
              d.status == DeliveryStatus.done,
        )
        .toList();

    // show three stat cards (Harian / Mingguan / Bulanan)
    Widget summaryArea = _buildRangeStatCards(theme);

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
                    // Summary area: either backend dashboard (while loading) or
                    // computed counts with a selector (Hari Ini / Minggu Ini / Bulan Ini)
                    summaryArea,
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
            // only show deliveries that are 'Berjalan' (inTransit) or 'Selesai' (done)
            if (running.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 56,
                        color: theme.iconTheme.color?.withOpacity(.6),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada pengiriman hari ini',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tekan "Tambah Pengiriman" untuk menambahkan tugas baru.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            .7,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = running[index];
                  return Padding(
                    padding: EdgeInsets.fromLTRB(16, index == 0 ? 0 : 8, 16, 8),
                    child: _DeliveryCard(
                      item: item,
                      onDetail: () => _showDetail(context, item),
                      onDeliver: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Form bukti serah: ${item.title}'),
                          ),
                        );
                      },
                    ),
                  );
                }, childCount: running.length),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, _DeliveryItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Detail'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.photoUrl != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Image.network(item.photoUrl!),
                ),
              Text('Penerima: ${item.title}'),
              const SizedBox(height: 8),
              Text('Alamat: ${item.address}'),
              const SizedBox(height: 8),
              Text('Status: ${item.rawStatus ?? item.status.toString()}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
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
        // IconButton(
        //   tooltip: 'Notifikasi',
        //   onPressed: () => ScaffoldMessenger.of(
        //     context,
        //   ).showSnackBar(const SnackBar(content: Text('Belum ada notifikasi'))),
        //   icon: const Icon(Icons.notifications_none_rounded),
        // ),
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
    // Prefer showing the raw status string from the backend (if available).
    // Otherwise fall back to the localized labels.
    final raw = (item.rawStatus ?? '').trim();
    // Normalize common backend strings to localized labels.
    final normalizedRaw = raw.isEmpty
        ? ''
        : switch (raw.toLowerCase()) {
            'delivered' => 'Berjalan',
            'selesai' => 'Selesai',
            'done' => 'Selesai',
            'in_transit' => 'Berjalan',
            'in-transit' => 'Berjalan',
            'intransit' => 'Berjalan',
            'in transit' => 'Berjalan',
            'berjalan' => 'Berjalan',
            'assigned' => 'Diterima',
            'accepted' => 'Diterima',
            _ => raw,
          };

    final label = normalizedRaw.isNotEmpty
        ? normalizedRaw
        : switch (item.status) {
            DeliveryStatus.assigned => 'Diterima',
            DeliveryStatus.inTransit => 'Dalam Perjalanan',
            DeliveryStatus.done => 'Selesai',
          };

    final color = switch (item.status) {
      DeliveryStatus.assigned => theme.colorScheme.outline,
      DeliveryStatus.inTransit => theme.colorScheme.primary,
      DeliveryStatus.done => Colors.green,
    };

    final statusChip = _buildChip(context, label, color);

    return DecoratedBox(
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
                // const SizedBox(width: 8),
                // Expanded(
                //   child: FilledButton.icon(
                //     onPressed: onDeliver,
                //     icon: const Icon(Icons.delivery_dining_rounded),
                //     label: const Text('Serahkan'),
                //   ),
                // ),
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
  final String? rawStatus; // original status string from backend
  final int? id;
  final String? photoUrl;
  const _DeliveryItem(
    this.title,
    this.address,
    this.status,
    this.rawStatus, {
    this.id,
    this.photoUrl,
  });
}

enum DeliveryStatus { assigned, inTransit, done }
