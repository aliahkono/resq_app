import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the donor's ResQ session token on-device (Android Keystore /
/// iOS Keychain, via flutter_secure_storage — not SharedPreferences, since
/// a bearer token shouldn't sit in plain-text local storage). Without this,
/// a successful login would be forgotten every time the app restarts,
/// since nothing else in the app keeps the token around.
class SessionStorage {
  static const _tokenKey = 'resq_donor_token';
  static const _biometricKey = 'resq_biometric_enabled';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  static Future<String?> readToken() => _storage.read(key: _tokenKey);

  // Also clears the biometric-login flag below — tied to this one stored
  // session, not to a specific donor's lasting preference, so it doesn't
  // carry over to whoever logs in next on this device.
  static Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _biometricKey);
  }

  // Off by default for every fresh login — a donor has to explicitly opt in
  // each time they sign in on a device, rather than this silently staying
  // on (or off) from whoever last used it.
  static Future<void> setBiometricEnabled(bool enabled) =>
      _storage.write(key: _biometricKey, value: enabled.toString());

  static Future<bool> isBiometricEnabled() async {
    final raw = await _storage.read(key: _biometricKey);
    return raw == 'true';
  }
}
