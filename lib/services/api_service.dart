// lib/services/api_service.dart
import 'dart:io';
import 'package:dio/dio.dart';
import '../services/storage_service.dart';
import '../models/user.dart';

class ApiService {
  static final String baseUrl = Platform.isAndroid
      ? 'http://10.0.2.2:8000/api/auth' // AVD → host laptop
      : 'http://127.0.0.1:8000/api/auth'; // desktop/iOS sim

  final Dio _dio;
  final StorageService _storage;

  ApiService(this._storage)
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          // supaya 4xx tidak dianggap "network error"
          validateStatus: (code) => code != null && code < 500,
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) async {
          final token = await _storage.getToken();
          if (token != null && token.isNotEmpty) {
            o.headers['Authorization'] = 'Bearer $token';
          }
          // debug URL:
          // print('➡️ ${o.method} ${o.uri}');
          h.next(o);
        },
        onResponse: (r, h) {
          // print('✅ ${r.statusCode} ${r.requestOptions.uri}');
          h.next(r);
        },
        onError: (e, h) {
          // print('❌ ${e.response?.statusCode} ${e.requestOptions.uri}');
          h.next(e);
        },
      ),
    );
  }

  // LOGIN: simpan token dari /login, lalu ambil profil dari /me
  Future<User> login({required String email, required String password}) async {
    final r = await _dio.post(
      '/login',
      data: {'email': email, 'password': password},
    );

    if (r.statusCode != 200) {
      throw Exception(_msg(r));
    }

    final map = (r.data?['data'] as Map?) ?? const {};
    final token = (map['token'] ?? map['access_token'])?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan pada respons server.');
    }
    await _storage.saveToken(token);

    // Ambil profil yang konsisten dari /me (SELALU mengembalikan user)
    final me = await _dio.get('/me');
    if (me.statusCode == 200 && me.data is Map) {
      return User.fromJson(Map<String, dynamic>.from(me.data as Map));
    }
    throw Exception(_msg(me));
  }

  Future<User> me() async {
    final r = await _dio.get('/me');
    if (r.statusCode == 200 && r.data is Map) {
      return User.fromJson(Map<String, dynamic>.from(r.data as Map));
    }
    throw Exception(_msg(r));
  }

  Future<void> logout() async {
    try {
      await _dio.post('/logout');
    } finally {
      await _storage.clearToken();
    }
  }

  Future<void> sendOtp(String email) async {
    final r = await _dio.post('/send-otp', data: {'email': email});
    if (r.statusCode != 200) throw Exception(_msg(r));
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    final r = await _dio.post(
      '/reset-password',
      data: {
        'email': email,
        'otp': otp,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
    if (r.statusCode != 200) throw Exception(_msg(r));
  }

  String _msg(Response r) {
    if (r.data is Map && (r.data as Map)['message'] is String) {
      return (r.data as Map)['message'] as String;
    }
    return 'HTTP ${r.statusCode}: ${r.statusMessage ?? 'Error'}';
  }
}
