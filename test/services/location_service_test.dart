import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flora_scan/services/location_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

/// Mock for GeolocatorPlatform
class MockGeolocatorPlatform extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  bool _serviceEnabled = true;
  LocationPermission _permission = LocationPermission.whileInUse;
  Position? _position;
  Exception? _exception;

  void setServiceEnabled(bool enabled) {
    _serviceEnabled = enabled;
  }

  void setPermission(LocationPermission permission) {
    _permission = permission;
  }

  void setPosition(Position position) {
    _position = position;
  }

  void setException(Exception exception) {
    _exception = exception;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    return _permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    return _permission;
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    return _serviceEnabled;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    if (_exception != null) {
      throw _exception!;
    }
    return _position!;
  }

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async {
    return _position;
  }
}

void main() {
  group('LocationService Tests', () {
    late MockGeolocatorPlatform mockGeolocator;

    setUp(() {
      mockGeolocator = MockGeolocatorPlatform();
      GeolocatorPlatform.instance = mockGeolocator;
    });

    test('capture returns null when service is disabled', () async {
      mockGeolocator.setServiceEnabled(false);
      final result = await LocationService.capture();
      expect(result, isNull);
    });

    test('capture returns null when permission is denied', () async {
      mockGeolocator.setPermission(LocationPermission.denied);
      final result = await LocationService.capture();
      expect(result, isNull);
    });

    test('capture returns null when permission is deniedForever', () async {
      mockGeolocator.setPermission(LocationPermission.deniedForever);
      final result = await LocationService.capture();
      expect(result, isNull);
    });

    test('capture returns null and logs error when exception occurs', () async {
      mockGeolocator.setException(Exception('Location timeout'));
      final result = await LocationService.capture();
      expect(result, isNull);
    });

    test('capture returns valid location when successful', () async {
      final mockPosition = Position(
        longitude: 10.0,
        latitude: 20.0,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 100.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
        floor: null,
        isMocked: true,
      );
      mockGeolocator.setPosition(mockPosition);

      final result = await LocationService.capture();

      expect(result, isNotNull);
      expect(result!.latitude, equals(20.0));
      expect(result.longitude, equals(10.0));
      expect(result.accuracy, equals(5.0));
      expect(result.altitude, equals(100.0));
      expect(result.geohash6, isNotEmpty);
      expect(result.latRounded, isNotNull);
      expect(result.lonRounded, isNotNull);
    });
  });
}
