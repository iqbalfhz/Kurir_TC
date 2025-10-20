import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _keyToken = 'auth_token';
  final _s = const FlutterSecureStorage();

  Future<void> saveToken(String token) =>
      _s.write(key: _keyToken, value: token);
  Future<String?> getToken() => _s.read(key: _keyToken);
  Future<void> clearToken() => _s.delete(key: _keyToken);
}
