import 'dart:async';
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:resq/services/local_prefs.dart';
import 'package:resq/services/api_service.dart';

/// Reads the donor's live GPS position for "nearest hospital" sorting
/// (GET /api/donor/requests?lat=&lng=, HomeView._loadOpenRequests), and —
/// when the donor has opted in — keeps a background position stream running
/// so PATCH /api/donor/location can trigger a reminder push the moment they
/// come within range of a still-open request near the hospital, even while
/// the app is closed. Kept separate from settings_view.dart's own
/// Geolocator permission-request flow, which is what actually asks the OS
/// for access — this only ever reads/streams a position that's already
/// permitted.
class LocationService {
  static StreamSubscription<Position>? _subscription;

  /// Returns null (instead of throwing) whenever a fresh position can't be
  /// read for any reason: the donor turned "Location Services" off in
  /// Settings, the OS permission was never granted or was revoked, the
  /// device's GPS is off, or the fix just times out — every one of those
  /// should silently fall back to the backend's non-location ordering
  /// rather than surface an error on a background feed refresh.
  static Future<Position?> getCurrentPositionIfEnabled(String donorId) async {
    try {
      final enabled = await LocalPrefs.getBool(donorId, 'locationServices') ?? false;
      if (!enabled) return null;

      if (!await Geolocator.isLocationServiceEnabled()) return null;

      final permission = await Geolocator.checkPermission();
      final granted = permission == LocationPermission.whileInUse || permission == LocationPermission.always;
      if (!granted) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      debugPrint('LocationService.getCurrentPositionIfEnabled failed: $e');
      return null;
    }
  }

  /// The donor's saved "Urgent Alert Radius" (Settings), in km — stored as
  /// e.g. "15 km" (settings_view.dart's own _radiusKm parses the same way).
  /// Only meaningful alongside a real position, so callers should only send
  /// this to the backend when getCurrentPositionIfEnabled returned one.
  static Future<int?> getAlertRadiusKm(String donorId) async {
    final raw = await LocalPrefs.getString(donorId, 'alertRadius');
    if (raw == null) return null;
    return int.tryParse(raw.split(' ').first);
  }

  /// Requests the "always" (background) permission tier that
  /// startProximityMonitoring needs. Must be called after the donor has
  /// already granted the ordinary "while in use" access — Android requires
  /// the two be requested as separate, sequential prompts; asking for
  /// "always" before a foreground grant exists is rejected outright on
  /// Android 10+. On Android 11+, the second call commonly routes the donor
  /// to the app's system Settings page rather than an inline dialog, since
  /// Google restricts showing "Allow all the time" directly — geolocator
  /// handles opening it.
  static Future<bool> requestBackgroundPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
      return false; // donor denied even the foreground tier
    }
    if (permission == LocationPermission.always) return true;

    permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always;
  }

  /// Starts a background position stream that reports the donor's location
  /// to the backend (PATCH /api/donor/location) whenever they've moved
  /// meaningfully, so a hospital-proximity reminder can fire even while the
  /// app isn't in the foreground. Call once after the donor enables
  /// "Notify me near a hospital" in Settings, and again on app start if it
  /// was already on (see settings_view.dart). Returns false (and starts
  /// nothing) if the toggle is off, OS location services are off, or
  /// "always" permission isn't granted — "while in use" alone isn't enough,
  /// since the OS stops delivering updates once the app is backgrounded.
  static Future<bool> startProximityMonitoring({
    required String donorId,
    required String token,
  }) async {
    final enabled = await LocalPrefs.getBool(donorId, 'locationServices') ?? false;
    if (!enabled) return false;
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always) return false;

    await _subscription?.cancel();

    final radiusKm = await getAlertRadiusKm(donorId);

    final locationSettings = _backgroundSettings();

    _subscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (position) {
        ApiService.updateMyLocation(
          token,
          lat: position.latitude,
          lng: position.longitude,
          radiusKm: radiusKm,
        ).catchError((e) {
          debugPrint('LocationService.startProximityMonitoring: location update failed: $e');
        });
      },
      onError: (e) {
        debugPrint('LocationService.startProximityMonitoring stream error: $e');
      },
    );

    return true;
  }

  /// Stops the background stream — call on logout or when the donor turns
  /// "Notify me near a hospital" back off, so a signed-out/opted-out device
  /// doesn't keep reporting position.
  static Future<void> stopProximityMonitoring() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  // distanceFilter: 300m — only report on real movement, not GPS jitter, to
  // keep this battery- and request-cheap. intervalDuration (Android only)
  // additionally caps how often updates can arrive even while moving.
  static LocationSettings _backgroundSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 300,
        intervalDuration: const Duration(minutes: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'ResQ is watching for nearby blood requests',
          notificationText: "You'll be notified if you're near a hospital that needs your blood type.",
          enableWakeLock: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 300,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.medium, distanceFilter: 300);
  }
}
