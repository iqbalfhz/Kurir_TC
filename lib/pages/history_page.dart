import 'package:flutter/material.dart';
import 'package:starter_kit/widgets/app_shell.dart';

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

  final List<_DeliveryHistoryItem> _all = [
    _DeliveryHistoryItem(
      title: 'PT ABC Logistics',
      address: 'Jl. Sudirman No.12, Jakarta',
      status: DeliveryStatus.inTransit,
      time: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    _DeliveryHistoryItem(
      title: 'Bank XYZ Tower',
      address: 'Jl. Gatot Subroto No.1, Jakarta',
      status: DeliveryStatus.assigned,
      time: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    _DeliveryHistoryItem(
      title: 'Kantor KLM',
      address: 'Jl. Rasuna Said Blok X-5, Jakarta',
      status: DeliveryStatus.done,
      time: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
    ),
    _DeliveryHistoryItem(
      title: 'PT Sinar Abadi',
      address: 'Jl. Gajah Mada No.22, Jakarta',
      status: DeliveryStatus.inTransit,
      time: DateTime.now().subtract(const Duration(days: 1, hours: 7)),
    ),
    _DeliveryHistoryItem(
      title: 'PT Mandiri Logistik',
      address: 'Jl. Kemang Raya No.9, Jaksel',
      status: DeliveryStatus.done,
      time: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
    ),
    _DeliveryHistoryItem(
      title: 'PT Global Express',
      address: 'Jl. Pemuda No.7, Depok',
      status: DeliveryStatus.done,
      time: DateTime.now().subtract(const Duration(days: 2, hours: 6)),
    ),
    _DeliveryHistoryItem(
      title: 'CV Sentosa',
      address: 'Jl. Merdeka No.11, Tangerang',
      status: DeliveryStatus.assigned,
      time: DateTime.now().subtract(const Duration(days: 3, hours: 2)),
    ),
    _DeliveryHistoryItem(
      title: 'PT Indo Cargo',
      address: 'Jl. Panjang No.88, Jakbar',
      status: DeliveryStatus.assigned,
      time: DateTime.now().subtract(const Duration(days: 4, hours: 4)),
    ),
    _DeliveryHistoryItem(
      title: 'PT Bumi Raya',
      address: 'Jl. Ahmad Yani No.5, Bekasi',
      status: DeliveryStatus.done,
      time: DateTime.now().subtract(const Duration(days: 5, hours: 8)),
    ),
  ];

  List<_DeliveryHistoryItem> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _all.where((e) {
      final matchText =
          q.isEmpty ||
          e.title.toLowerCase().contains(q) ||
          e.address.toLowerCase().contains(q);
      final matchStatus = _statusFilter == null || e.status == _statusFilter;
      final matchRange =
          _range == null ||
          (e.time.isAfter(_range!.start.subtract(const Duration(seconds: 1))) &&
              e.time.isBefore(_range!.end.add(const Duration(seconds: 1))));
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
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
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
                    const SizedBox(height: 10),
                    _StatusChips(
                      current: _statusFilter,
                      onChanged: (s) => setState(() => _statusFilter = s),
                    ),
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
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Detail: ${it.title}')),
                        ),
                      ),
                    );
                  }, childCount: entry.value.length),
                ),
              ],
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
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
    return '${d.day} ${bulan[d.month - 1]} ${d.year}';
  }
}

class _DeliveryHistoryItem {
  final String title;
  final String address;
  final DeliveryStatus status;
  final DateTime time;
  const _DeliveryHistoryItem({
    required this.title,
    required this.address,
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

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.current, required this.onChanged});
  final DeliveryStatus? current;
  final ValueChanged<DeliveryStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback? onTap,
    }) {
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap?.call(),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(
          label: 'Semua',
          selected: current == null,
          onTap: () => onChanged(null),
        ),
        chip(
          label: 'Diterima',
          selected: current == DeliveryStatus.assigned,
          onTap: () => onChanged(DeliveryStatus.assigned),
        ),
        chip(
          label: 'Berjalan',
          selected: current == DeliveryStatus.inTransit,
          onTap: () => onChanged(DeliveryStatus.inTransit),
        ),
        chip(
          label: 'Selesai',
          selected: current == DeliveryStatus.done,
          onTap: () => onChanged(DeliveryStatus.done),
        ),
      ],
    );
  }
}

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
          color: theme.colorScheme.surfaceVariant,
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
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _fmtTime(item.time),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
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

  String _fmtTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}';
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
