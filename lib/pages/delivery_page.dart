import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:dio/dio.dart';
import 'package:starter_kit/services/api_service.dart';
import 'package:starter_kit/services/storage_service.dart';
import 'package:starter_kit/models/delivery.dart';
import 'package:starter_kit/models/user.dart';

/// Halaman: Tambah Pengiriman (MVP)
/// Dengan auto-kompres:
/// - Preview (tajam untuk UI)
/// - Upload (kecil untuk server)
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
  final _deliveredByCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // Foto dokumen
  Uint8List? _photoPreviewBytes; // untuk UI
  Uint8List? _photoUploadBytes; // untuk server

  bool _submitting = false;

  @override
  void dispose() {
    _senderCtrl.dispose();
    _recipientCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    _deliveredByCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Auto-fill sender name from authenticated user if available.
    _fillSenderFromAuth();
  }

  Future<void> _fillSenderFromAuth() async {
    try {
      final storage = StorageService();
      final cached = await storage.getUserName();
      if (!mounted) return;
      if (cached != null && cached.trim().isNotEmpty) {
        if (_senderCtrl.text.trim().isEmpty) {
          setState(() => _senderCtrl.text = cached);
        }
        return;
      }

      final api = ApiService(storage);
      final User user = await api.me();
      if (!mounted) return;
      if (_senderCtrl.text.trim().isEmpty) {
        setState(() => _senderCtrl.text = user.name);
      }
      // cache for future loads
      try {
        await storage.saveUserName(user.name);
      } catch (_) {}
    } catch (_) {
      // ignore — leave field empty if we can't fetch user
    }
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
      // Capture platform/theme info before any awaits to avoid using
      // BuildContext across async gaps (use_build_context_synchronously).
      final preferWebp = Theme.of(context).platform == TargetPlatform.android;
      final XFile? img = await _picker.pickImage(
        source: source,
        imageQuality: 100, // ambil setinggi mungkin; kita kompres sendiri
      );
      if (img == null) return;

      final original = await img.readAsBytes();

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

  String? _required(String? v) {
    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
    return null;
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    // Backend requires a photo on create; show a clear client-side message
    // and do not attempt to submit if the user hasn't attached one.
    if (_photoUploadBytes == null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Foto Dokumen Diperlukan'),
          content: const Text(
            'Foto dokumen wajib diunggah saat menambahkan pengiriman. Silakan tambahkan foto terlebih dahulu.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Oke'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ApiService(StorageService());
      final Delivery delivery = await api.createDelivery(
        senderName: _senderCtrl.text.trim(),
        receiverName: _recipientCtrl.text
            .trim(), // pakai receiver_name sesuai BE
        address: _addressCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        photoBytes: _photoUploadBytes, // kirim hasil kompres jika ada
        photoFilename: 'doc.jpg', // atau 'doc.webp' bila preferWebp
        deliveredByName: _deliveredByCtrl.text.trim().isEmpty
            ? null
            : _deliveredByCtrl.text.trim(),
        // Do not send status here; let the backend apply its default value.
      );

      if (!mounted) return;
      // Log and show returned status for debugging (helps check backend behavior)
      try {
        // ignore: avoid_print
        print('createDelivery response status: ${delivery.status}');
      } catch (_) {}

      // Show a friendly success dialog (simple message) and allow the user
      // to close or go to the history screen. The dialog buttons handle
      // popping the dialog and the page when appropriate.

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Berhasil'),
            ],
          ),
          content: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Terima kasih — dokumen berhasil dikirim.',
              style: TextStyle(fontSize: 15),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text('Tutup'),
            ),
          ],
        ),
      );

      // (Dialog actions already close the page when the user chooses to)
    } catch (e) {
      if (!mounted) return;
      String msg;
      if (e is DioException) {
        final resp = e.response?.data;
        if (resp is String) {
          msg = resp;
        } else if (resp is Map) {
          msg = resp['message']?.toString() ?? resp.toString();
        } else {
          msg = e.message ?? e.toString();
        }
      } else {
        msg = e.toString();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $msg')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                readOnly: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Messenger',
                  hintText: 'Contoh: Iqbal Fahrozi',
                  prefixIcon: Icon(Icons.person_outline),
                  suffixText: 'Otomatis',
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),

              // Nama yang akan menerima / delivered_by_name
              TextFormField(
                controller: _deliveredByCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nama Pengirim',
                  hintText: 'Nama orang pengirim',
                  prefixIcon: Icon(Icons.person_2_outlined),
                ),
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
                decoration: const InputDecoration(
                  labelText: 'Alamat Tujuan',
                  hintText: 'Tulis alamat lengkap kantor klien',
                  prefixIcon: Icon(Icons.location_on_outlined),
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
              const SizedBox(height: 12),
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
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
