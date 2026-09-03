import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// On-device preferences that have no backend field to live in yet
/// (biometric login toggle, location services toggle, alert radius) —
/// keyed per donor id so they don't leak between different accounts that
/// share the same device. Reuses flutter_secure_storage rather than adding
/// a new dependency (see SessionStorage); nothing stored here is actually
/// sensitive, this is just the storage already wired into the app.
class LocalPrefs {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String _key(String donorId, String name) => 'resq_pref_${donorId}_$name';

  static Future<void> setBool(String donorId, String name, bool value) =>
      _storage.write(key: _key(donorId, name), value: value.toString());

  static Future<bool?> getBool(String donorId, String name) async {
    final raw = await _storage.read(key: _key(donorId, name));
    if (raw == null) return null;
    return raw == 'true';
  }

  static Future<void> setString(String donorId, String name, String value) =>
      _storage.write(key: _key(donorId, name), value: value);

  static Future<String?> getString(String donorId, String name) => _storage.read(key: _key(donorId, name));
}
