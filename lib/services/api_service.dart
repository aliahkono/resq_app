import 'dart:convert';
import 'package:http/http.dart' as http;

/// Base URL of the ResQ backend (server/src/app.js in the hospital-web-dashboard
/// repo). Defaults to the deployed backend on Render, so anyone can just
/// `flutter run` and immediately see/create real data that shows up on the
/// deployed admin dashboard too — no local server needed.
///
/// To point at a local dev server instead, run with an override:
///   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:4000/api
/// Local-server tips if you do this:
///   - Android emulator: 127.0.0.1 + `adb reverse tcp:4000 tcp:4000` (some
///     Mac network setups block the usual 10.0.2.2 NAT route; adb reverse
///     tunnels over USB/ADB instead. Re-run after every emulator restart —
///     it doesn't persist.)
///   - iOS simulator: 127.0.0.1 directly (shares the Mac's network stack)
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

  /// A handful of donor-portal endpoints (hospitals, appointments,
  /// donations) return a raw JSON array, not an object — `_decode` above
  /// only handles `Map` bodies and would silently return `{}` for these,
  /// throwing the data away with no error. This mirrors `_decode`'s error
  /// handling but for list responses.
  static List<dynamic> _decodeList(http.Response response) {
    final ok = response.statusCode >= 200 && response.statusCode < 300;

    dynamic parsed;
    if (response.body.isNotEmpty) {
      try {
        parsed = jsonDecode(response.body);
      } catch (_) {
        // see _decode's comment above — same reasoning applies here.
      }
    }

    if (!ok) {
      final errorBody = parsed is Map<String, dynamic> ? parsed : <String, dynamic>{};
      throw ApiException(
        response.statusCode,
        errorBody['error']?.toString() ?? 'Something went wrong (HTTP ${response.statusCode}). Please try again.',
      );
    }
    return parsed is List ? parsed : [];
  }

  static Future<List<dynamic>> _getList(String path, {String? token}) async {
    final response = await http
        .get(Uri.parse('$kApiBaseUrl$path'), headers: _headers(token))
        .timeout(_timeout);
    return _decodeList(response);
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

  static Future<Map<String, dynamic>> _delete(String path, {Map<String, dynamic>? body, String? token}) async {
    final response = await http
        .delete(
          Uri.parse('$kApiBaseUrl$path'),
          headers: _headers(token),
          body: body != null ? jsonEncode(body) : null,
        )
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

  /// POST /api/donor/me/photo — multipart upload of the donor's profile
  /// photo, returning the new hosted URL (e.g. { "photoUrl": "https://..." }).
  /// NOTE: this route does not exist on the backend yet — needs a handler
  /// added there (accepting a multipart field named "photo", storing it
  /// wherever donor photos are meant to live, and returning the resulting
  /// URL) before this call will succeed, same as deleteMyAccount above.
  static Future<String> uploadProfilePhoto(String token, String filePath) async {
    final uri = Uri.parse('$kApiBaseUrl/donor/me/photo');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('photo', filePath));

    final streamedResponse = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamedResponse);
    final body = _decode(response);

    final url = body['photoUrl'] as String?;
    if (url == null || url.isEmpty) {
      throw ApiException(response.statusCode, 'Upload succeeded but no photo URL was returned.');
    }
    return url;
  }

  /// POST /api/donor-auth/logout
  static Future<void> logout(String token) {
    return _post('/donor-auth/logout', {}, token: token);
  }

  /// DELETE /api/donor/me — permanently deletes the signed-in donor's
  /// account and profile. `otpCode` is the 6-digit code sent via
  /// requestOtp to the donor's own registered phone right before this is
  /// called (see DeleteAccountOtpView) — a second factor confirming the
  /// person doing this actually holds the account's phone, not just
  /// whoever is holding an unlocked device with a live session. Expects
  /// the backend to verify the code server-side as part of this single
  /// call (not a separate verify-then-delete round trip), and — per the
  /// donor management requirement — to remove the donor from the Donor
  /// Management list on the Web Admin dashboard as part of the same
  /// deletion, not just deactivate the mobile-side session.
  static Future<void> deleteMyAccount(String token, {required String otpCode}) {
    return _delete('/donor/me', body: {'otpCode': otpCode}, token: token);
  }

  /// GET /api/donor/hospitals — public hospital list for the appointment
  /// booking picker: [{id, code, name, city, address, latitude, longitude}].
  static Future<List<dynamic>> listHospitals(String token) {
    return _getList('/donor/hospitals', token: token);
  }

  /// GET /api/donor/appointments — this donor's own appointments (any
  /// status), most recently scheduled first:
  /// [{id, hospitalId, hospitalName, hospitalAddress, scheduledAt, status}].
  static Future<List<dynamic>> listMyAppointments(String token) {
    return _getList('/donor/appointments', token: token);
  }

  /// POST /api/donor/appointments — books a real slot at `hospitalId` for
  /// `scheduledAt`. Throws ApiException with the backend's own message on
  /// failure — most commonly a 409 "this time slot is fully booked" (see
  /// bookAppointment, appointments.service.js), which is a real capacity
  /// check, not a generic error.
  static Future<Map<String, dynamic>> bookAppointment(
    String token, {
    required String hospitalId,
    required DateTime scheduledAt,
  }) {
    return _post(
      '/donor/appointments',
      {
        'hospitalId': hospitalId,
        // .toUtc() is required here: scheduledAt is built from the picked
        // date/time-slot as a naive LOCAL DateTime (see _confirmBooking,
        // eligible_appoint_view.dart). A naive DateTime's toIso8601String()
        // has no timezone marker at all ("2026-09-10T08:00:00.000", no "Z"
        // or offset) — the backend (running in UTC on Render) then parses
        // that ambiguous string as if it already were UTC. Reading it back
        // and calling .toLocal() (see _toConfirmedAppointment,
        // home_view.dart) then applies the device's UTC+8 offset on top of
        // a value that was never actually UTC, shifting the reflected time
        // slot 8 hours from what the donor actually picked. Converting to
        // UTC before sending makes the string unambiguous end to end, so
        // .toLocal() on the way back correctly reverses it.
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      },
      token: token,
    );
  }

  /// PATCH /api/donor/appointments/:id/cancel
  static Future<Map<String, dynamic>> cancelAppointment(String token, String appointmentId) {
    return _patch('/donor/appointments/$appointmentId/cancel', {}, token: token);
  }

  /// GET /api/donor/requests — open hospital broadcasts matching this
  /// donor's blood type (see listOpenRequestsForDonor,
  /// donorPortal.controller.js), ranked by urgency then, if lat/lng are
  /// supplied, proximity. This app doesn't collect donor GPS yet (no
  /// location package wired in), so lat/lng are left out for now — the
  /// backend just falls back to newest-first ordering, same as it does for
  /// any caller that skips them.
  /// [{requestCode, bloodType, priority, ward, unitsNeeded, unitsFulfilled,
  ///   status, secondsOpen, hospitalId, hospitalName, hospitalAddress,
  ///   latitude, longitude, distanceKm}]
  static Future<List<dynamic>> listOpenRequests(String token) {
    return _getList('/donor/requests', token: token);
  }

  /// GET /api/donor/notifications — {notifications: [...], unreadCount: n}.
  /// One row per broadcast the donor was actually sent (see
  /// listMyNotifications, donorPortal.controller.js).
  static Future<Map<String, dynamic>> getMyNotifications(String token) {
    return _get('/donor/notifications', token: token);
  }

  /// PATCH /api/donor/notifications/read — marks every one of this donor's
  /// notification rows read in one shot (204 No Content on success).
  static Future<void> markNotificationsRead(String token) {
    return _patch('/donor/notifications/read', {}, token: token);
  }
}