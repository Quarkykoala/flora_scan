import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../utils/geohash.dart';

/// Location capture result with privacy-aware fields.
class LocationCapture {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double accuracy;
  final double latRounded;
  final double lonRounded;
  final String geohash6;
  final Map<String, dynamic>? reverseGeo;

  const LocationCapture({
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.accuracy,
    required this.latRounded,
    required this.lonRounded,
    required this.geohash6,
    this.reverseGeo,
  });
}

/// Service for location capture with graceful degradation.
class LocationService {
  LocationService._();

  /// Check and request location permission.
  /// Returns true if permission is granted.
  static Future<bool> ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  /// Capture current location with privacy-aware processing.
  /// Returns null if location is unavailable or denied.
  static Future<LocationCapture?> capture() async {
    try {
      final hasPermission = await ensurePermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Compute privacy-aware fields
      final latRounded = Geohash.roundCoordinate(position.latitude);
      final lonRounded = Geohash.roundCoordinate(position.longitude);
      final geohash6 = Geohash.encode(
        position.latitude,
        position.longitude,
        precision: 6,
      );

      // Attempt reverse geocoding
      Map<String, dynamic>? reverseGeo;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          reverseGeo = {
            'country': place.country,
            'country_code': place.isoCountryCode,
            'admin_area': place.administrativeArea,
            'locality': place.locality,
          };
        }
      } catch (_) {
        // Reverse geocoding failure is non-blocking
      }

      return LocationCapture(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude != 0 ? position.altitude : null,
        accuracy: position.accuracy,
        latRounded: latRounded,
        lonRounded: lonRounded,
        geohash6: geohash6,
        reverseGeo: reverseGeo,
      );
    } catch (_) {
      return null;
    }
  }
}
