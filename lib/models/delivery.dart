class Delivery {
  final int id;
  final String senderName;
  final String receiverName;
  final String address;
  final String? note;
  final String status; // "assigned" | "in_transit" | "done" (sesuaikan BE)
  final String? photoUrl;
  final DateTime? createdAt;

  Delivery({
    required this.id,
    required this.senderName,
    required this.receiverName,
    required this.address,
    this.note,
    required this.status,
    this.photoUrl,
    this.createdAt,
  });

  factory Delivery.fromJson(Map<String, dynamic> j) {
    // Accept both 'note' and 'notes' from backend
    String? noteValue;
    if (j['note'] != null)
      noteValue = '${j['note']}';
    else if (j['notes'] != null)
      noteValue = '${j['notes']}';

    // Normalize photo_url if present and relative
    String? photo;
    if (j['photo_url'] != null) {
      photo = '${j['photo_url']}';
      if (photo.startsWith('/')) {
        // Keep it as-is; ApiService will prefix host. This avoids duplicating host logic here.
      }
    }

    return Delivery(
      id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
      senderName: '${j['sender_name'] ?? ''}',
      receiverName: '${j['receiver_name'] ?? ''}',
      address: '${j['address'] ?? ''}',
      note: noteValue,
      status: '${j['status'] ?? 'in_transit'}',
      photoUrl: photo,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'].toString())
          : null,
    );
  }
}
