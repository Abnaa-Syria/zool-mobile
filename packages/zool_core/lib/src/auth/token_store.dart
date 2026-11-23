import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the rotating refresh token lives between launches.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Keychain / Android Keystore storage (one key per app).
class SecureTokenStore implements TokenStore {
  SecureTokenStore(this.key, {FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final String key;
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null; // unreadable keystore entry (e.g. after a reinstall): start signed out
    }
  }

  @override
  Future<void> write(String token) => _storage.write(key: key, value: token);

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}

/// In-memory store for tests.
class MemoryTokenStore implements TokenStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;

  @override
  Future<void> clear() async => value = null;
}
