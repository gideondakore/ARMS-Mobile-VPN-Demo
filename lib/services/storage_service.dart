import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions());

  static const _tokenKey = 'auth_token';
  static const _usernameKey = 'username';
  static const _ovpnKey = 'personalized_ovpn';

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> saveUsername(String username) =>
      _storage.write(key: _usernameKey, value: username);

  Future<String?> getUsername() => _storage.read(key: _usernameKey);

  Future<void> saveOvpnConfig(String config) =>
      _storage.write(key: _ovpnKey, value: config);

  Future<String?> getOvpnConfig() => _storage.read(key: _ovpnKey);

  Future<bool> hasPersonalizedConfig() => _storage.containsKey(key: _ovpnKey);

  Future<void> clearAll() => _storage.deleteAll();
}
