import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
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
    } catch (e) {
      debugPrint('Error capturing accelerometer: $e');
    }

    // Attempt light sensor reading
    // Note: light_sensor package not available on all devices,
    // using estimated fallback approach
    try {
      // The actual light sensor integration would use platform channels
      // or the light_sensor package. For now, mark as unavailable.
      luxSource = 'unavailable';
      luxReading = null;
    } catch (e) {
      debugPrint('Error capturing light sensor: $e');
      luxSource = 'unavailable';
    }

    return SensorCapture(
      luxReading: luxReading,
      luxSource: luxSource,
      pitchDeg: pitchDeg,
      rollDeg: rollDeg,
    );
  }

  static double _radToDeg(double rad) => rad * 180 / pi;
}
