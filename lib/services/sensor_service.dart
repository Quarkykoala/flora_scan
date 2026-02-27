import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Device sensor capture result.
class SensorCapture {
  final double? luxReading;
  final String luxSource;
  final double? pitchDeg;
  final double? rollDeg;

  const SensorCapture({
    this.luxReading,
    this.luxSource = 'unavailable',
    this.pitchDeg,
    this.rollDeg,
  });
}

/// Service for capturing device sensor data with graceful degradation.
class SensorService {
  SensorService._();

  /// Capture current sensor readings.
  /// Returns available data with source annotations.
  static Future<SensorCapture> capture() async {
    double? pitchDeg;
    double? rollDeg;
    String luxSource = 'unavailable';
    double? luxReading;

    // Capture accelerometer for orientation
    try {
      final completer = Completer<void>();
      StreamSubscription? subscription;

      subscription = accelerometerEventStream().listen(
        (event) {
          // Convert accelerometer to pitch/roll in degrees
          pitchDeg = _radToDeg(atan2(event.y, event.z));
          rollDeg = _radToDeg(atan2(event.x, event.z));

          subscription?.cancel();
          if (!completer.isCompleted) completer.complete();
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Timeout after 2 seconds
      await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => subscription?.cancel(),
      );
    } catch (_) {
      // Sensor unavailable — degrade gracefully
    }

    // TODO: Implement actual light sensor reading using platform channels or light_sensor package.
    // Note: light_sensor package not available on all devices.
    // For now, these default to 'unavailable' and null as initialized above.

    return SensorCapture(
      luxReading: luxReading,
      luxSource: luxSource,
      pitchDeg: pitchDeg,
      rollDeg: rollDeg,
    );
  }

  static double _radToDeg(double rad) => rad * 180 / pi;
}
