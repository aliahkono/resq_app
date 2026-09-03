import 'dart:convert';
import 'package:http/http.dart' as http;

/// Base URL of the ResQ backend (server/src/app.js in the hospital-web-dashboard
/// repo). It isn't deployed anywhere yet, so this has to point at a machine
/// actually running it:
///   - Android emulator, server running on the same computer: 10.0.2.2
///   - iOS simulator, server running on the same computer: 127.0.0.1
///   - A real phone: your computer's LAN IP (e.g. 192.168.1.23), phone and
///     computer on the same Wi-Fi, or an ngrok tunnel URL if it's remote
/// Change this before testing against a real backend — it will not work
/// as-is on a physical device.
const String kApiBaseUrl = "https://hospital-web-dashboard.onrender.com/api";

/// Thrown for any non-2xx response. `message` is the backend's own `error`
/// field when it sent one (see server/src/utils/asyncHandler.js and every
/// controller's res.status(...).json({ error: ... }) calls) — that's
/// already written to be shown directly to the donor, not a generic
/// fallback string, except when the backend is unreachable at all.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Thin wrapper around package:http for the donor-facing endpoints
/// (POST /api/donor-auth/*, GET/PATCH /api/donor/*). Intentionally just
/// functions on a class, not a stateful singleton — there's no per-instance
/// state to hold, the session token is passed in by whoever's calling.
class ApiService {
  static const _timeout = Duration(seconds: 15);

  static Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Map<String, dynamic> _decode(http.Response response) {
    final ok = response.statusCode >= 200 && response.statusCode < 300;

    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) {
      try {
        final parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic>) body = parsed;
      } catch (_) {
        // Backend always returns JSON (or an empty 204 body) — an
        // unparsable response means something other than this API
        // answered (a proxy error page, etc.), not a real API error.
      }
    }

    if (!ok) {
      throw ApiException(
        response.statusCode,
        body['error']?.toString() ?? 'Something went wrong (HTTP ${response.statusCode}). Please try again.',
      );
    }
    return body;
  }

  static Future<Map<String, dynamic>> _get(String path, {String? token}) async {
    final response = await http
        .get(Uri.parse('$kApiBaseUrl$path'), headers: _headers(token))
        .timeout(_timeout);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {String? token}) async {
    final response = await http
        .post(Uri.parse('$kApiBaseUrl$path'), headers: _headers(token), body: jsonEncode(body))
        .timeout(_timeout);
    return _decode(response);
  }

  static Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body, {String? token}) async {
    final response = await http
        .patch(Uri.parse('$kApiBaseUrl$path'), headers: _headers(token), body: jsonEncode(body))
        .timeout(_timeout);
    return _decode(response);
  }

  // --- Donor auth (public — no token yet) --------------------------------

  /// POST /api/donor-auth/login — { identifier, password } -> { token, expiresIn, donor }
  /// `identifier` can be an email or a phone number; the backend tells them
  /// apart by checking for an "@", same as the login screen's own toggle.
  static Future<Map<String, dynamic>> loginWithPassword({
    required String identifier,
    required String password,
  }) {
    return _post('/donor-auth/login', {'identifier': identifier, 'password': password});
  }

  /// POST /api/donor-auth/request-otp — { phone, channel, email? } -> { ok, channel }
  /// Sends a 6-digit code. `phone` should be in +63XXXXXXXXXX form (the
  /// registration wizard already builds it that way), though the backend
  /// re-normalizes it regardless of exact input shape. The code is always
  /// bound to `phone` server-side no matter which channel delivers it —
  /// pass `channel: 'email'` with `email` set to have this one delivery
  /// go out by email instead of SMS (matches the login screen's Phone
  /// SMS / Email OTP tabs).
  static Future<Map<String, dynamic>> requestOtp(String phone, {String channel = 'sms', String? email}) {
    return _post('/donor-auth/request-otp', {
      'phone': phone,
      'channel': channel,
      if (channel == 'email' && email != null) 'email': email,
    });
  }

  /// POST /api/donor-auth/verify-otp — { phone, code } ->
  ///   { needsProfile: true, token }  — no donor exists yet for this phone;
  ///     `token` is a short-lived pending token, pass it to completeProfile.
  ///   { needsProfile: false, token, expiresIn, donor } — a donor record
  ///     already existed (e.g. an admin-created walk-in) — `token` here is
  ///     already a full session token, nothing else to do.
  static Future<Map<String, dynamic>> verifyOtp({required String phone, required String code}) {
    return _post('/donor-auth/verify-otp', {'phone': phone, 'code': code});
  }

  /// POST /api/donor-auth/complete-profile — only valid right after
  /// verifyOtp returned needsProfile: true. `pendingToken` is that
  /// response's `token`, sent as the bearer token here (not a normal
  /// session token yet). -> { token, expiresIn, donor }
  static Future<Map<String, dynamic>> completeProfile({
    required String pendingToken,
    required String name,
    required String bloodType,
    required String password,
    String? email,
    int? age,
    double? weightKg,
    String? gender, // "male" | "female"
    Map<String, dynamic>? healthScreening,
  }) {
    return _post(
      '/donor-auth/complete-profile',
      {
        'name': name,
        'bloodType': bloodType,
        'password': password,
        if (email != null && email.isNotEmpty) 'email': email,
        if (age != null) 'age': age,
        if (weightKg != null) 'weightKg': weightKg,
        if (gender != null) 'gender': gender,
        if (healthScreening != null) 'healthScreening': healthScreening,
      },
      token: pendingToken,
    );
  }

  // --- Donor portal (requires the session token from login) --------------

  /// GET /api/donor/me
  static Future<Map<String, dynamic>> getMyProfile(String token) {
    return _get('/donor/me', token: token);
  }

  /// PATCH /api/donor/me — pass only the fields being changed.
  static Future<Map<String, dynamic>> updateMyProfile(String token, Map<String, dynamic> updates) {
    return _patch('/donor/me', updates, token: token);
  }

  /// POST /api/donor-auth/logout
  static Future<void> logout(String token) {
    return _post('/donor-auth/logout', {}, token: token);
  }
}
