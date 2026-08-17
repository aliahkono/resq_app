import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the donor's ResQ session token on-device (Android Keystore /
/// iOS Keychain, via flutter_secure_storage — not SharedPreferences, since
/// a bearer token shouldn't sit in plain-text local storage). Without this,
/// a successful login would be forgotten every time the app restarts,
/// since nothing else in the app keeps the token around.
class SessionStorage {
  static const _tokenKey = 'resq_donor_token';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  static Future<String?> readToken() => _storage.read(key: _tokenKey);

  static Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
