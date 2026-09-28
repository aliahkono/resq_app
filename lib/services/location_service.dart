import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:resq/services/local_prefs.dart';

/// Reads the donor's live GPS position for "nearest hospital" sorting
/// (GET /api/donor/requests?lat=&lng=, HomeView._loadOpenRequests). Kept
/// separate from settings_view.dart's own Geolocator permission-request
/// flow, which is what actually asks the OS for access — this only ever
/// reads a position that's already permitted, so a broadcast feed refresh
/// never itself triggers a permission prompt.
class LocationService {
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
}
