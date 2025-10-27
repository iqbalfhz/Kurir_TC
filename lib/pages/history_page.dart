import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:starter_kit/widgets/app_shell.dart';
import 'package:starter_kit/services/api_service.dart';
import 'package:starter_kit/services/storage_service.dart';
import 'package:starter_kit/models/delivery.dart' as m;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum DeliveryStatus { assigned, inTransit, done }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _searchCtrl = TextEditingController();
  DeliveryStatus? _statusFilter; // null = semua
  DateTimeRange? _range;
  bool _loading = false;
  // infinite scroll state
  final ScrollController _scrollController = ScrollController();
  int _page = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final List<_DeliveryHistoryItem> _all = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
    _scrollController.addListener(_onScroll);
  }

  DeliveryStatus _mapStatus(String status) {
    final s = status.toLowerCase().trim();
    // numeric codes sometimes used by backends
    if (s == '1' || s == 'assigned' || s == 'accepted' || s == 'diterima') {
      return DeliveryStatus.assigned;
    }
    if (s == '2' ||
        s == 'in_transit' ||
        s == 'in-transit' ||
        s == 'intransit' ||
        s == 'in transit' ||
        s == 'berjalan' ||
        s == 'on_the_way' ||
        s == 'on_the_way') {
      return DeliveryStatus.inTransit;
    }
    if (s == '3' || s == 'done' || s == 'completed' || s == 'selesai') {
      return DeliveryStatus.done;
    }
    // default fallback
    return DeliveryStatus.inTransit;
  }

  Future<void> _loadHistory() async {
    // Initial load (page 1)
    if (!mounted) return;
    _page = 1;
    _hasMore = true;
    setState(() => _loading = true);
    developer.log('Loading deliveries', name: 'HistoryPage');
    try {
      final api = ApiService(StorageService());
      // Only load deliveries for the currently authenticated user
      final list = await api.getDeliveries(onlyMine: true, page: 1);
      final mapped = list.map((m.Delivery d) {
        return _DeliveryHistoryItem(
          id: d.id,
          title: (d.receiverName.isNotEmpty) ? d.receiverName : d.senderName,
          senderName: d.senderName,
          address: d.address,
          note: d.note,
          photoUrl: d.photoUrl,
          deliveredByName: d.deliveredByName,
          rawStatus: d.status,
          status: _mapStatus(d.status),
          time: d.createdAt ?? DateTime.now(),
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _all
          ..clear()
          ..addAll(mapped);
        // determine hasMore based on returned list length
        _hasMore = list.isNotEmpty && list.isNotEmpty; // conservative
        _page = 2;
      });
    } catch (e, st) {
      developer.log(
        'Error loading deliveries: $e',
        name: 'HistoryPage',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengambil riwayat: ${e.toString()}')),
          );
        } catch (_) {
          // ignore: avoid_print
          developer.log('Failed to show snackbar', name: 'HistoryPage');
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = 200.0;
    if (_scrollController.position.pixels + threshold >=
        _scrollController.position.maxScrollExtent) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    try {
      final api = ApiService(StorageService());
      // Only load deliveries for the currently authenticated user
      final list = await api.getDeliveries(onlyMine: true, page: _page);
      final mapped = list.map((m.Delivery d) {
        return _DeliveryHistoryItem(
          id: d.id,
          title: (d.receiverName.isNotEmpty) ? d.receiverName : d.senderName,
          senderName: d.senderName,
          address: d.address,
          note: d.note,
          photoUrl: d.photoUrl,
          deliveredByName: d.deliveredByName,
          rawStatus: d.status,
          status: _mapStatus(d.status),
          time: d.createdAt ?? DateTime.now(),
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        // dedupe by id
        final existingIds = _all.map((e) => e.id).toSet();
        for (final it in mapped) {
          if (!existingIds.contains(it.id)) _all.add(it);
        }
        if (list.isEmpty) _hasMore = false;
        _page++;
      });
    } catch (e) {
      developer.log('Error loading page $_page: $e', name: 'HistoryPage');
      // keep hasMore; user can retry by scrolling again
    } finally {
      _isLoadingMore = false;
    }
  }

  List<_DeliveryHistoryItem> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _all.where((e) {
      final matchText =
          q.isEmpty ||
          e.title.toLowerCase().contains(q) ||
          e.address.toLowerCase().contains(q);
      final matchStatus = _statusFilter == null || e.status == _statusFilter;
      // Compare using Asia/Jakarta timezone so the date-range filter matches
      // the backend semantics.
      final matchRange = () {
        if (_range == null) return true;
        final createdJakarta = _toJakarta(e.time);
        final startJakarta = _jakartaDayStart(_range!.start);
        // make end exclusive at next day start
        final endJakarta = _jakartaDayStart(
          _range!.end,
        ).add(const Duration(days: 1));
        return !createdJakarta.isBefore(startJakarta) &&
            createdJakarta.isBefore(endJakarta);
      }();
      return matchText && matchStatus && matchRange;
    }).toList()..sort((a, b) => b.time.compareTo(a.time));
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 1, 1, 1);
    final last = DateTime(now.year + 1, 12, 31);
    final res = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange:
          _range ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: DateTime(now.year, now.month, now.day),
          ),
      helpText: 'Rentang Tanggal',
      saveText: 'Terapkan',
    );
    if (res != null) setState(() => _range = res);
  }

  Future<void> _refresh() async {
    await _loadHistory();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _filtered;
    final grouped = _groupByDate(items);

    return AppShell(
      currentIndex: 1,
      appBar: AppBar(
        title: const Text('Riwayat'),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'Show raw /deliveries response',
              onPressed: () async {
                final api = ApiService(StorageService());
                String raw = '';
                try {
                  // Fetch raw response for only the authenticated user's deliveries
                  raw = await api.getDeliveriesRaw(onlyMine: true);
                } catch (e) {
                  raw = 'Error fetching raw: ${e.toString()}';
                }
                if (!mounted) return;
                await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Raw /deliveries response'),
                    content: SingleChildScrollView(child: SelectableText(raw)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Tutup'),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await Clipboard.setData(ClipboardData(text: raw));
                          } catch (_) {}
                          Navigator.pop(ctx);
                        },
                        child: const Text('Copy'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.bug_report_rounded),
            ),
          // // IconButton(
          // //   tooltip: 'Muat semua',
          // //   onPressed: () async {
          // //     if (!mounted) return;
          // //     setState(() => _loading = true);
          // //     try {
          // //       final api = ApiService(StorageService());
          // //       final all = await api.getAllDeliveries(perPage: 50);
          // //       if (!mounted) return;
          // //       setState(() {
          // //         _all
          // //           ..clear()
          // //           ..addAll(
          // //             all.map(
          // //               (d) => _DeliveryHistoryItem(
          // //                 id: d.id,
          // //                 title: (d.receiverName.isNotEmpty)
          // //                     ? d.receiverName
          // //                     : d.senderName,
          // //                 senderName: d.senderName,
          // //                 address: d.address,
          // //                 note: d.note,
          // //                 photoUrl: d.photoUrl,
          // //                 rawStatus: d.status,
          // //                 status: _mapStatus(d.status),
          // //                 time: d.createdAt ?? DateTime.now(),
          // //               ),
          // //             ),
          // //           );
          // //       });
          // //     } catch (e) {
          // //       developer.log(
          // //         'Error loading all deliveries: $e',
          // //         name: 'HistoryPage',
          // //       );
          // //       if (mounted)
          // //         ScaffoldMessenger.of(context).showSnackBar(
          // //           SnackBar(
          // //             content: Text('Gagal memuat semua: ${e.toString()}'),
          // //           ),
          // //         );
          // //     } finally {
          // //       if (mounted) setState(() => _loading = false);
          // //     }
          // //   },
          // //   icon: const Icon(Icons.cloud_download_rounded),
          // ),
          if (_range != null)
            IconButton(
              tooltip: 'Hapus filter tanggal',
              onPressed: () => setState(() => _range = null),
              icon: const Icon(Icons.filter_alt_off_rounded),
            ),
          IconButton(
            tooltip: 'Pilih rentang tanggal',
            onPressed: _pickDateRange,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    _SearchField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                    ),
                    // const SizedBox(height: 10),
                    // _StatusChips(
                    //   current: _statusFilter,
                    //   onChanged: (s) => setState(() => _statusFilter = s),
                    // ),
                    if (_range != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _FilterPill(
                          icon: Icons.date_range_rounded,
                          label:
                              '${_fmtDate(_range!.start)} – ${_fmtDate(_range!.end)}',
                          onClear: () => setState(() => _range = null),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (items.isEmpty)
              const SliverToBoxAdapter(
                child: _EmptyState(
                  title: 'Tidak ada riwayat',
                  message:
                      'Coba ubah kata kunci, status, atau rentang tanggal.',
                ),
              )
            else
              for (final entry in grouped.entries) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      entry.key,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final it = entry.value[i];
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        i == 0 ? 0 : 8,
                        16,
                        i == entry.value.length - 1 ? 8 : 0,
                      ),
                      child: _HistoryCard(
                        item: it,
                        onTap: () => showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(it.title),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (it.photoUrl != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Image.network(it.photoUrl!),
                                    ),
                                  // Always show delivered_by_name under the receiver (title)
                                  Text(
                                    'Nama Penyerah: ${it.deliveredByName?.isNotEmpty == true ? it.deliveredByName : 'Belum diisi'}',
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Pengirim: ${it.senderName}'),
                                  const SizedBox(height: 6),
                                  Text('Alamat: ${it.address}'),
                                  const SizedBox(height: 6),
                                  if (it.note != null)
                                    Text('Catatan: ${it.note}'),
                                  const SizedBox(height: 6),
                                  Text('Status (raw): ${it.rawStatus}'),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Waktu: ${_fmtDate(it.time)} ${_fmtTime(it.time)}',
                                  ),
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
                        ),
                      ),
                    );
                  }, childCount: entry.value.length),
                ),
              ],
            // bottom spacing and loading indicator for pagination
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  if (_isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<_DeliveryHistoryItem>> _groupByDate(
    List<_DeliveryHistoryItem> items,
  ) {
    final Map<String, List<_DeliveryHistoryItem>> map = {};
    for (final it in items) {
      final label = _dateLabel(it.time);
      map.putIfAbsent(label, () => []);
      map[label]!.add(it);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.first.time.compareTo(a.value.first.time));
    return {for (final e in entries) e.key: e.value};
  }

  String _dateLabel(DateTime d) {
    // Use Asia/Jakarta for date grouping/labels so they match BE calendar days.
    final nowJakarta = _toJakarta(DateTime.now());
    final today = DateTime(nowJakarta.year, nowJakarta.month, nowJakarta.day);
    final thatJakarta = _toJakarta(d);
    final that = DateTime(thatJakarta.year, thatJakarta.month, thatJakarta.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
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
    return '${that.day} ${bulan[that.month - 1]} ${that.year}';
  }

  String _fmtDate(DateTime d) {
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
    final j = _toJakarta(d);
    return '${j.day} ${bulan[j.month - 1]} ${j.year}';
  }

  String _fmtTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final j = _toJakarta(d);
    return '${two(j.hour)}:${two(j.minute)}';
  }

  // Convert any DateTime to Asia/Jakarta time for comparisons and display.
  DateTime _toJakarta(DateTime d) => d.toUtc().add(const Duration(hours: 7));

  DateTime _jakartaDayStart(DateTime d) {
    final j = _toJakarta(d);
    return DateTime(j.year, j.month, j.day);
  }
}

class _DeliveryHistoryItem {
  final int id;
  final String title;
  final String senderName;
  final String address;
  final String? note;
  final String? photoUrl;
  final String? deliveredByName;
  final String rawStatus;
  final DeliveryStatus status;
  final DateTime time;
  const _DeliveryHistoryItem({
    required this.id,
    required this.title,
    required this.senderName,
    required this.address,
    this.note,
    this.photoUrl,
    this.deliveredByName,
    required this.rawStatus,
    required this.status,
    required this.time,
  });
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: 'Cari nama/alamat...',
        border: const OutlineInputBorder(),
        suffixIcon: (controller.text.isEmpty)
            ? null
            : IconButton(
                tooltip: 'Bersihkan',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
    );
  }
}

// class _StatusChips extends StatelessWidget {
//   const _StatusChips({required this.current, required this.onChanged});
//   final DeliveryStatus? current;
//   final ValueChanged<DeliveryStatus?> onChanged;

//   @override
//   Widget build(BuildContext context) {
//     Widget chip({
//       required String label,
//       required bool selected,
//       required VoidCallback? onTap,
//     }) {
//       return ChoiceChip(
//         label: Text(label),
//         selected: selected,
//         onSelected: (_) => onTap?.call(),
//       );
//     }

//     return Wrap(
//       spacing: 8,
//       runSpacing: 8,
//       children: [
//         chip(
//           label: 'Semua',
//           selected: current == null,
//           onTap: () => onChanged(null),
//         ),
//         // 'Diterima' removed per request
//         chip(
//           label: 'Berjalan',
//           selected: current == DeliveryStatus.inTransit,
//           onTap: () => onChanged(DeliveryStatus.inTransit),
//         ),
//         chip(
//           label: 'Selesai',
//           selected: current == DeliveryStatus.done,
//           onTap: () => onChanged(DeliveryStatus.done),
//         ),
//       ],
//     );
//   }
// }

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.icon, required this.label, this.onClear});
  final IconData icon;
  final String label;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.primaryContainer),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelSmall),
          if (onClear != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onClear,
              child: const Icon(Icons.close_rounded, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, this.onTap});
  final _DeliveryHistoryItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chip = switch (item.status) {
      DeliveryStatus.assigned => _chip(
        context,
        'Diterima',
        theme.colorScheme.outline,
      ),
      DeliveryStatus.inTransit => _chip(
        context,
        'Berjalan',
        theme.colorScheme.primary,
      ),
      DeliveryStatus.done => _chip(context, 'Selesai', Colors.green),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.local_shipping_rounded),
              ),
              const SizedBox(width: 10),
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
                    const SizedBox(height: 8),
                    // Row(
                    //   children: [
                    //     Icon(
                    //       Icons.access_time_rounded,
                    //       size: 16,
                    //       color: theme.colorScheme.onSurfaceVariant,
                    //     ),
                    //     const SizedBox(width: 4),
                    //     Text(
                    //       _fmtTime(item.time),
                    //       style: theme.textTheme.labelSmall?.copyWith(
                    //         color: theme.colorScheme.onSurfaceVariant,
                    //       ),
                    //     ),
                    //   ],
                    // ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              chip,
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Color color) {
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
