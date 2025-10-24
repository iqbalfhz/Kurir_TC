import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _keyToken = 'auth_token';
  static const _keyUserName = 'user_name';
  static const _keyCachedDeliveries = 'cached_deliveries_v1';
  final _s = const FlutterSecureStorage();

  Future<void> saveToken(String token) =>
      _s.write(key: _keyToken, value: token);
  Future<String?> getToken() => _s.read(key: _keyToken);
  Future<void> saveUserName(String name) =>
      _s.write(key: _keyUserName, value: name);
  Future<String?> getUserName() => _s.read(key: _keyUserName);

  Future<void> clearToken() async {
    await _s.delete(key: _keyToken);
    await _s.delete(key: _keyUserName);
  }

  /// Remove only the cached username while keeping the auth token intact.
  Future<void> clearUserName() async {
    await _s.delete(key: _keyUserName);
  }

  /// Cache a JSON string representation of the most-recently fetched
  /// deliveries (used to make Home load fast on cold start).
  Future<void> saveCachedDeliveries(String json) =>
      _s.write(key: _keyCachedDeliveries, value: json);

  Future<String?> getCachedDeliveries() => _s.read(key: _keyCachedDeliveries);

  Future<void> clearCachedDeliveries() => _s.delete(key: _keyCachedDeliveries);
}
