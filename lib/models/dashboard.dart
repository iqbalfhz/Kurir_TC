class DashboardCounts {
  final int documents;
  final int done;
  final int inTransit;

  DashboardCounts({
    required this.documents,
    required this.done,
    required this.inTransit,
  });

  factory DashboardCounts.fromJson(Map<String, dynamic> json) {
    // Accept multiple possible keys from backend
    final docs = json['documents'] ?? json['dokumen'] ?? json['total'] ?? 0;
    final done = json['done'] ?? json['selesai'] ?? json['completed'] ?? 0;
    final inTransit =
        json['in_transit'] ?? json['berjalan'] ?? json['running'] ?? 0;

    return DashboardCounts(
      documents: int.tryParse('$docs') ?? 0,
      done: int.tryParse('$done') ?? 0,
      inTransit: int.tryParse('$inTransit') ?? 0,
    );
  }
}
