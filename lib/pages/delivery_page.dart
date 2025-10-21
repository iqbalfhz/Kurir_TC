import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Halaman: Tambah Pengiriman (MVP)
/// Dengan auto-kompres: simpan dua versi foto
/// - Preview: untuk ditampilkan tajam di UI
/// - Upload: untuk dikirim kecil ke server (hemat bandwidth)
class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  final _formKey = GlobalKey<FormState>();

  // Field controllers
  final _senderCtrl = TextEditingController();
  final _recipientCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // Foto dokumen
  Uint8List? _photoPreviewBytes; // untuk UI
  Uint8List? _photoUploadBytes; // untuk server

  // Koordinat (opsional)
  double? _lat;
  double? _lng;

  bool _submitting = false;

  @override
  void dispose() {
    _senderCtrl.dispose();
    _recipientCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ===== Kompresi Gambar =====
  Future<Uint8List?> _compress({
    required Uint8List bytes,
    required int longSide, // 1600 untuk preview, 1280 untuk upload
    required int quality, // 80 preview, 70 upload
    bool webp = false,
  }) {
    return FlutterImageCompress.compressWithList(
      bytes,
      quality: quality,
      minWidth: longSide,
      minHeight: longSide,
      format: webp ? CompressFormat.webp : CompressFormat.jpeg,
      keepExif: false,
    );
  }

  // Kompres adaptif untuk upload: target ukuran (KB)
  Future<Uint8List?> _compressForUpload(
    Uint8List original, {
    int targetKB = 350,
    bool preferWebp = false,
  }) async {
    final formats = preferWebp ? [true, false] : [false]; // coba WebP lalu JPEG
    Uint8List? last;
    for (final webp in formats) {
      int longSide = 1280;
      for (final q in [70, 60, 50]) {
        final out = await _compress(
          bytes: original,
          longSide: longSide,
          quality: q,
          webp: webp,
        );
        if (out == null) continue;
        last = out;
        final kb = out.lengthInBytes ~/ 1024;
        if (kb <= targetKB) return out;
        longSide = (longSide * 0.85).round().clamp(800, 1600);
      }
    }
    return last; // hasil terbaik terakhir jika masih > target
  }

  Future<void> _pickPhoto() async {
    // 1) Pilih sumber foto
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil dari Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    // 2) Ambil file dari picker
    try {
      final XFile? img = await _picker.pickImage(
        source: source,
        imageQuality: 100, // ambil setinggi mungkin; kita kompres sendiri
      );
      if (img == null) return;

      final original = await img.readAsBytes();

      // 3) Kompres dua versi
      final preferWebp = Theme.of(context).platform == TargetPlatform.android;
      final preview = await _compress(
        bytes: original,
        longSide: 1600,
        quality: 80,
        webp: false, // preview aman pakai JPEG
      );
      final upload = await _compressForUpload(
        original,
        targetKB: 350,
        preferWebp: preferWebp,
      );

      if (!mounted) return;
      setState(() {
        _photoPreviewBytes = preview ?? original;
        _photoUploadBytes = upload ?? preview ?? original;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil/kompres foto: $e')),
      );
    }
  }

  Future<void> _pickLocation() async {
    // TODO: Integrasi geolocator untuk ambil lokasi, lalu isi _lat/_lng atau alamat reverse-geocode.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Integrasikan geolocator untuk ambil lokasi.'),
      ),
    );
  }

  String? _required(String? v) {
    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
    return null;
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_photoUploadBytes == null) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tanpa Foto Dokumen?'),
          content: const Text(
            'Kamu belum menambahkan foto dokumen. Lanjut tanpa foto?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lanjut'),
            ),
          ],
        ),
      );
      if (sure != true) return;
    }

    setState(() => _submitting = true);

    // TODO: Simpan ke backend / local DB (Hive/SQLite) menggunakan _photoUploadBytes
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    Navigator.pop(context, true); // kirim sinyal ke Home untuk refresh
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Pengiriman')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              // Foto dokumen
              Text('Foto Dokumen', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _PhotoBox(bytes: _photoPreviewBytes, onTap: _pickPhoto),
              const SizedBox(height: 16),

              // Pengirim
              TextFormField(
                controller: _senderCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nama Pengirim',
                  hintText: 'Contoh: Iqbal Fahrozi',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),

              // Penerima
              TextFormField(
                controller: _recipientCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nama Penerima',
                  hintText: 'Contoh: Resepsionis PT ABC',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),

              // Alamat
              TextFormField(
                controller: _addressCtrl,
                minLines: 2,
                maxLines: 3,
                keyboardType: TextInputType.streetAddress,
                autofillHints: const [AutofillHints.fullStreetAddress],
                decoration: InputDecoration(
                  labelText: 'Alamat Tujuan',
                  hintText: 'Tulis alamat lengkap kantor klien',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: IconButton(
                    onPressed: _pickLocation,
                    icon: const Icon(Icons.my_location_rounded),
                    tooltip: 'Ambil lokasi',
                  ),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),

              // Catatan (opsional)
              TextFormField(
                controller: _noteCtrl,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  hintText: 'Mis. serahkan ke front desk lantai 3',
                  prefixIcon: Icon(Icons.sticky_note_2_outlined),
                ),
              ),
              const SizedBox(height: 24),

              // Info koordinat kecil (opsional)
              if (_lat != null && _lng != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Koordinat: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.playlist_add_check_rounded),
          label: Text(_submitting ? 'Menyimpan...' : 'Mulai Antar'),
        ),
      ),
    );
  }
}

class _PhotoBox extends StatelessWidget {
  const _PhotoBox({required this.bytes, required this.onTap});
  final Uint8List? bytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceVariant,
          border: Border.all(color: theme.colorScheme.outline.withOpacity(.4)),
        ),
        alignment: Alignment.center,
        child: bytes == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_camera_outlined, size: 32),
                  const SizedBox(height: 6),
                  Text(
                    'Tambah Foto Dokumen',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  bytes!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
      ),
    );
  }
}
