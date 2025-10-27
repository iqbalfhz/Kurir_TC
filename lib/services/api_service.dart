import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:starter_kit/models/delivery.dart';
import 'package:starter_kit/models/user.dart';
import 'package:starter_kit/models/dashboard.dart';
import 'package:starter_kit/services/storage_service.dart';

class ApiService {
  static final String baseUrl = Platform.isAndroid
      ? 'http://10.0.2.2:8000/api' // Android emulator (host machine)
      : 'http://127.0.0.1:8000/api'; // Desktop / iOS simulator

  final Dio _dio;
  final StorageService _storage;

  ApiService(this._storage)
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Accept': 'application/json'},
          validateStatus: (code) => code != null && code < 500,
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  /// Fetch simple dashboard counts from the backend.
  /// Expected response shape (example): { "documents": 10, "done": 3, "in_transit": 3 }
  Future<DashboardCounts> getDashboardCounts() async {
    // try common endpoints that backends may expose
    final candidates = ['/dashboard', '/deliveries/summary', '/summary'];
    Response? last;
    for (final ep in candidates) {
      try {
        final r = await _dio.get(ep);
        last = r;
        if (r.statusCode == 200) {
          dynamic body = r.data;
          if (body is String) body = jsonDecode(body);
          if (body is Map) {
            return DashboardCounts.fromJson(Map<String, dynamic>.from(body));
          }
          // sometimes payload is nested
          if (body is Map && body['data'] is Map) {
            return DashboardCounts.fromJson(
              Map<String, dynamic>.from(body['data'] as Map),
            );
          }
        }
      } catch (_) {
        // ignore and try next
      }
    }
    // If summary endpoints not found, compute counts from deliveries as a fallback
    try {
      return await _computeDashboardFromDeliveries();
    } catch (_) {
      throw Exception(
        'Gagal mengambil dashboard: ${last?.statusCode ?? 'no response'}',
      );
    }
  }

  // =============== AUTH ===============
  Future<User> login({required String email, required String password}) async {
    final r = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    if (r.statusCode != 200) throw Exception(_msg(r));

    final token = r.data['data']?['token'] ?? r.data['access_token'];
    if (token == null) throw Exception('Token tidak ditemukan di respons.');
    await _storage.saveToken(token.toString());

    final me = await _dio.get('/auth/me');
    if (me.statusCode == 200) {
      final user = User.fromJson(Map<String, dynamic>.from(me.data));
      try {
        await _storage.saveUserName(user.name);
      } catch (_) {}
      return user;
    }
    throw Exception(_msg(me));
  }

  Future<User> me() async {
    final r = await _dio.get('/auth/me');
    if (r.statusCode == 200) {
      final user = User.fromJson(Map<String, dynamic>.from(r.data));
      try {
        await _storage.saveUserName(user.name);
      } catch (_) {}
      return user;
    }
    throw Exception(_msg(r));
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } finally {
      await _storage.clearToken();
    }
  }

  Future<void> sendOtp(String email) async {
    final r = await _dio.post('/auth/send-otp', data: {'email': email});
    if (r.statusCode != 200) throw Exception(_msg(r));
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    final r = await _dio.post(
      '/auth/reset-password',
      data: {
        'email': email,
        'otp': otp,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
    if (r.statusCode != 200) throw Exception(_msg(r));
  }

  // =============== DELIVERIES ===============
  Future<Delivery> createDelivery({
    required String senderName,
    required String receiverName,
    required String address,
    String? note,
    Uint8List? photoBytes,
    String photoFilename = 'doc.jpg',
    String? initialStatus,
    String? deliveredByName,
  }) async {
    final form = FormData();

    form.fields
      ..add(MapEntry('sender_name', senderName))
      ..add(MapEntry('receiver_name', receiverName))
      ..add(MapEntry('address', address));
    if (initialStatus != null && initialStatus.isNotEmpty) {
      form.fields.add(MapEntry('status', initialStatus));
    }
    if (note != null && note.trim().isNotEmpty) {
      form.fields.add(MapEntry('note', note.trim()));
    }
    if (deliveredByName != null && deliveredByName.trim().isNotEmpty) {
      form.fields.add(MapEntry('delivered_by_name', deliveredByName.trim()));
    }
    if (photoBytes != null && photoBytes.isNotEmpty) {
      form.files.add(
        MapEntry(
          'photo',
          MultipartFile.fromBytes(
            photoBytes,
            filename: photoFilename,
            contentType: _contentTypeFromName(photoFilename),
          ),
        ),
      );
    }

    // Debug: log form fields and files to help diagnose server validation.
    try {
      // ignore: avoid_print
      print('createDelivery form fields:');
      for (final f in form.fields) {
        // avoid printing binary photo bytes
        final key = f.key;
        final val = key == 'photo' ? '<photo_bytes>' : f.value;
        // ignore: avoid_print
        print('  $key: $val');
      }
      for (final file in form.files) {
        // ignore: avoid_print
        print('  file: ${file.key} -> ${file.value.filename}');
      }
    } catch (_) {}

    final r = await _dio.post(
      '/deliveries',
      data: form, // Dio will set multipart/form-data
    );

    if (r.statusCode != 201 && r.statusCode != 200) {
      // Try to produce a helpful message when validation errors come back
      String bodyDesc;
      try {
        final body = r.data is String ? jsonDecode(r.data) : r.data;
        bodyDesc = _formatValidation(body);
      } catch (_) {
        bodyDesc = r.data?.toString() ?? '';
      }
      throw Exception('Gagal membuat pengiriman: ${r.statusCode} $bodyDesc');
    }

    final data = r.data is String ? jsonDecode(r.data) : r.data;
    return Delivery.fromJson(Map<String, dynamic>.from(data));
  }

  /// Update a delivery (partial): currently supports updating delivered_by_name and status
  Future<void> updateDelivery({
    required int id,
    String? deliveredByName,
    String? status,
  }) async {
    final data = <String, dynamic>{};
    if (deliveredByName != null) data['delivered_by_name'] = deliveredByName;
    if (status != null) data['status'] = status;

    final r = await _dio.patch('/deliveries/$id', data: data);
    if (r.statusCode != 200) {
      throw Exception(
        'Gagal memperbarui pengiriman (${r.statusCode}): ${r.statusMessage}',
      );
    }
  }

  String _formatValidation(dynamic body) {
    if (body is Map) {
      final msg = <String>[];
      if (body['message'] != null) msg.add('${body['message']}');
      if (body['errors'] is Map) {
        (body['errors'] as Map).forEach((k, v) {
          msg.add('$k: ${v is List ? v.join(', ') : v}');
        });
      }
      if (msg.isNotEmpty) return msg.join(' | ');
      return body.toString();
    }
    if (body is String) return body;
    return body?.toString() ?? '';
  }

  Future<List<Delivery>> getDeliveries({
    bool onlyMine = false,
    int? perPage,
    int page = 1,
  }) async {
    // Some backends can be slow when returning large pages; allow a longer
    // receive timeout for deliveries endpoints without changing the global
    // default used elsewhere.
    final r = await _dio.get(
      '/deliveries',
      queryParameters: {
        if (onlyMine) 'my': 1,
        if (perPage != null) 'per_page': perPage,
        if (page != 1) 'page': page,
      },
      options: Options(receiveTimeout: const Duration(seconds: 60)),
    );

    if (r.statusCode != 200) {
      // Include the requested URI in the error to make 404/endpoint issues
      // easier to diagnose when the app is run on emulator/device.
      final uri = r.requestOptions.uri;
      throw Exception(
        'Gagal memuat data (${r.statusCode} ${r.statusMessage}) dari $uri',
      );
    }

    dynamic body = r.data;
    if (body is String) {
      body = jsonDecode(body);
    }

    List<dynamic>? items;

    if (body is List) {
      items = body;
    } else if (body is Map) {
      if (body['data'] is List) {
        items = body['data'];
      } else if (body['deliveries'] is List) {
        items = body['deliveries'];
      }
    }

    if (items == null) {
      final uri = r.requestOptions.uri;
      throw Exception('Format data tidak dikenali dari $uri: $body');
    }

    final host = baseUrl.replaceFirst(RegExp(r'/api\/?$'), '');
    final normalized = items.map((raw) {
      if (raw is Map &&
          raw['photo_url'] is String &&
          (raw['photo_url'] as String).startsWith('/')) {
        final s = raw['photo_url'] as String;
        raw['photo_url'] = '$host$s';
      }
      return raw;
    }).toList();

    return normalized
        .map((e) => Delivery.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Debug helper: return the raw response body (unparsed) for GET /deliveries.
  Future<String> getDeliveriesRaw({bool onlyMine = false, int? perPage}) async {
    final r = await _dio.get(
      '/deliveries',
      queryParameters: {
        if (onlyMine) 'my': 1,
        if (perPage != null) 'per_page': perPage,
      },
      options: Options(
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    if (r.data is String) return r.data as String;
    if (r.data is Map || r.data is List) return jsonEncode(r.data);
    return r.data?.toString() ?? '';
  }

  /// Follow pagination and return all deliveries as a flat list. Use with care.
  Future<List<Delivery>> getAllDeliveries({
    int perPage = 50,
    int maxPages = 200,
  }) async {
    final List<Delivery> out = [];
    int page = 1;
    final host = baseUrl.replaceFirst(RegExp(r'/api\/?$'), '');

    while (true) {
      // Allow longer receive timeout per page; these can aggregate into
      // a long-running operation when fetching many pages.
      final r = await _dio.get(
        '/deliveries',
        queryParameters: {'page': page, 'per_page': perPage},
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );

      if (r.statusCode != 200) {
        throw Exception('Gagal memuat halaman $page: ${r.statusCode}');
      }

      dynamic body = r.data;
      if (body is String) body = jsonDecode(body);

      List<dynamic>? items;
      if (body is Map && body['data'] is List) {
        items = body['data'];
      } else if (body is List)
        items = body;

      if (items == null || items.isEmpty) break;

      final normalized = items.map((raw) {
        if (raw is Map &&
            raw['photo_url'] is String &&
            (raw['photo_url'] as String).startsWith('/')) {
          raw['photo_url'] = '$host${raw['photo_url']}';
        }
        return raw;
      }).toList();

      out.addAll(
        normalized.map((e) => Delivery.fromJson(Map<String, dynamic>.from(e))),
      );

      if (body is Map) {
        if (body['last_page'] != null) {
          final last = body['last_page'] is int
              ? body['last_page'] as int
              : int.tryParse('${body['last_page']}') ?? page;
          if (page >= last) break;
        } else if (body['next_page_url'] == null) {
          break;
        }
      }

      page++;
      if (page > maxPages) break;
    }

    return out;
  }

  // =============== Helpers ===============
  MediaType _contentTypeFromName(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    } else if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    } else if (lower.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    return MediaType('application', 'octet-stream');
  }

  String _msg(Response r) {
    if (r.data is Map && (r.data as Map)['message'] is String) {
      return (r.data as Map)['message'] as String;
    }
    if (r.data is String && (r.data as String).trim().isNotEmpty) {
      return (r.data as String).trim();
    }
    return 'HTTP ${r.statusCode}: ${r.statusMessage ?? 'Error'}';
  }

  Future<DashboardCounts> _computeDashboardFromDeliveries({
    int perPage = 200,
  }) async {
    // follow pagination to compute counts from all deliveries
    final list = await getAllDeliveries(perPage: perPage, maxPages: 200);
    int docs = list.length;
    int done = 0;
    int inTransit = 0;
    for (final d in list) {
      final s = d.status.toLowerCase();
      if (s == 'done' || s == 'completed' || s == 'selesai' || s == '3') {
        done++;
      } else if (s == 'in_transit' ||
          s == 'in-transit' ||
          s == 'intransit' ||
          s == 'in transit' ||
          s == 'berjalan' ||
          s == 'delivered' ||
          s == '2') {
        inTransit++;
      }
    }
    return DashboardCounts(documents: docs, done: done, inTransit: inTransit);
  }
}
