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
const String kApiBaseUrl = "http://10.0.2.2:4000/api";

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

  // Deliberately NOT adding request-otp / verify-otp / complete-profile
  // wrappers here yet — that flow is still being worked out, don't want to
  // build against a shape that's about to change.

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
