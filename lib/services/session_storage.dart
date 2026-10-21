import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the donor's ResQ session token on-device (Android Keystore /
/// iOS Keychain, via flutter_secure_storage — not SharedPreferences, since
/// a bearer token shouldn't sit in plain-text local storage). Without this,
/// a successful login would be forgotten every time the app restarts,
/// since nothing else in the app keeps the token around.
///
/// Biometric login: when a donor turns on "Biometric Login" in Settings,
/// their session token is kept on this device (still in the Keystore /
/// Keychain) when they sign out, so the next time they open the Login
/// screen a fingerprint / Face ID scan signs them straight back in — the
/// token is re-validated against GET /api/donor/me, see
/// AuthService.signInWithStoredSessionToken. The flag is tied to the donor
/// who turned it on: a different account signing in on the same device
/// clears it.
class SessionStorage {
  static const _tokenKey = 'resq_donor_token';
  static const _biometricKey = 'resq_biometric_enabled';
  static const _biometricDonorKey = 'resq_biometric_donor_id';
  static const _offlinePassKey = 'resq_offline_qr_pass';
  // macOS: the data-protection keychain (the plugin default) needs a
  // keychain-access-groups entitlement, which ad-hoc signed builds can't
  // carry — every read/write fails with -34018. The login keychain needs
  // no entitlement.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(useDataProtectionKeyChain: false),
  );

  /// Saves the token from a fresh sign-in. [donorId] is the account that
  /// just signed in — if biometric login was set up for a different
  /// account on this device, it's switched off so that account's saved
  /// session can't be reused.
  static Future<void> saveToken(String token, {String? donorId}) async {
    final biometricDonor = await _storage.read(key: _biometricDonorKey);
    if (biometricDonor != null && biometricDonor != donorId) {
      await _storage.delete(key: _biometricKey);
      await _storage.delete(key: _biometricDonorKey);
    }
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> readToken() => _storage.read(key: _tokenKey);

  /// Wipes the saved session and the biometric-login setting — used when
  /// the saved token is dead (401) or biometric login is off at sign-out.
  static Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _biometricKey);
    await _storage.delete(key: _biometricDonorKey);
    // The saved QR pass belongs to this session — a full sign-out (or a
    // dead token, or a deleted account) shouldn't leave it on the phone.
    await _storage.delete(key: _offlinePassKey);
  }

  /// Saves the donor's QR pass details so it can still be shown with no
  /// internet (see LoginView's "Show my saved QR pass"). The pass itself is
  /// generated on the phone from the donor code — only signing in needs the
  /// server — so this is all it takes. Refreshed each time the dashboard
  /// loads the profile.
  static Future<void> saveOfflinePass(OfflinePass pass) =>
      _storage.write(key: _offlinePassKey, value: jsonEncode(pass.toJson()));

  static Future<OfflinePass?> readOfflinePass() async {
    try {
      final raw = await _storage.read(key: _offlinePassKey);
      if (raw == null) return null;
      return OfflinePass.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // unreadable or from an older shape — treat as none
    }
  }

  /// Sign-out. Returns true when biometric login is on and the session was
  /// kept on-device for the next fingerprint / Face ID sign-in (the caller
  /// must then NOT invalidate the token server-side); false when everything
  /// was cleared.
  static Future<bool> signOut() async {
    if (await isBiometricEnabled() && await readToken() != null) return true;
    await clearToken();
    return false;
  }

  static Future<void> setBiometricEnabled(bool enabled, {String? donorId}) async {
    await _storage.write(key: _biometricKey, value: enabled.toString());
    if (enabled && donorId != null && donorId.isNotEmpty) {
      await _storage.write(key: _biometricDonorKey, value: donorId);
    } else if (!enabled) {
      await _storage.delete(key: _biometricDonorKey);
    }
  }

  static Future<bool> isBiometricEnabled() async {
    final raw = await _storage.read(key: _biometricKey);
    return raw == 'true';
  }
}

/// What the offline QR pass needs — see SessionStorage.saveOfflinePass.
class OfflinePass {
  final String donorCode;
  final String donorName;
  final String bloodType;
  final bool isEligible;
  final DateTime savedAt;

  const OfflinePass({
    required this.donorCode,
    required this.donorName,
    required this.bloodType,
    required this.isEligible,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'donorCode': donorCode,
        'donorName': donorName,
        'bloodType': bloodType,
        'isEligible': isEligible,
        'savedAt': savedAt.toIso8601String(),
      };

  factory OfflinePass.fromJson(Map<String, dynamic> json) => OfflinePass(
        donorCode: json['donorCode'] as String,
        donorName: json['donorName'] as String,
        bloodType: json['bloodType'] as String,
        isEligible: json['isEligible'] as bool,
        savedAt: DateTime.parse(json['savedAt'] as String),
      );
}
