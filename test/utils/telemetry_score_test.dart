import 'package:flutter_test/flutter_test.dart';
import 'package:flora_scan/utils/telemetry_score.dart';

void main() {
  group('TelemetryScore.compute', () {
    test('returns 1.0 when all fields are present', () {
      final score = TelemetryScore.compute(
        hasLocation: true,
        hasLux: true,
        hasOrientation: true,
        hasWeather: true,
        hasAirQuality: true,
        hasAltitude: true,
      );
      expect(score, 1.0);
    });

    test('returns 0.0 when no fields are present', () {
      final score = TelemetryScore.compute(
        hasLocation: false,
        hasLux: false,
        hasOrientation: false,
        hasWeather: false,
        hasAirQuality: false,
        hasAltitude: false,
      );
      expect(score, 0.0);
    });

    test('correctly weights location (0.25)', () {
      final score = TelemetryScore.compute(
        hasLocation: true,
        hasLux: false,
        hasOrientation: false,
        hasWeather: false,
        hasAirQuality: false,
        hasAltitude: false,
      );
      expect(score, closeTo(0.25, 0.001));
    });

    test('correctly weights weather (0.25)', () {
      final score = TelemetryScore.compute(
        hasLocation: false,
        hasLux: false,
        hasOrientation: false,
        hasWeather: true,
        hasAirQuality: false,
        hasAltitude: false,
      );
      expect(score, closeTo(0.25, 0.001));
    });

    test('correctly weights airQuality (0.15)', () {
      final score = TelemetryScore.compute(
        hasLocation: false,
        hasLux: false,
        hasOrientation: false,
        hasWeather: false,
        hasAirQuality: true,
        hasAltitude: false,
      );
      expect(score, closeTo(0.15, 0.001));
    });

    test('correctly weights lux (0.15)', () {
      final score = TelemetryScore.compute(
        hasLocation: false,
        hasLux: true,
        hasOrientation: false,
        hasWeather: false,
        hasAirQuality: false,
        hasAltitude: false,
      );
      expect(score, closeTo(0.15, 0.001));
    });

    test('correctly weights orientation (0.10)', () {
      final score = TelemetryScore.compute(
        hasLocation: false,
        hasLux: false,
        hasOrientation: true,
        hasWeather: false,
        hasAirQuality: false,
        hasAltitude: false,
      );
      expect(score, closeTo(0.10, 0.001));
    });

    test('correctly weights altitude (0.10)', () {
      final score = TelemetryScore.compute(
        hasLocation: false,
        hasLux: false,
        hasOrientation: false,
        hasWeather: false,
        hasAirQuality: false,
        hasAltitude: true,
      );
      expect(score, closeTo(0.10, 0.001));
    });

    test('sums weights correctly', () {
      // Location (0.25) + Orientation (0.10) + Lux (0.15) = 0.50
      final score = TelemetryScore.compute(
        hasLocation: true,
        hasLux: true,
        hasOrientation: true,
        hasWeather: false,
        hasAirQuality: false,
        hasAltitude: false,
      );
      expect(score, closeTo(0.50, 0.001));
    });
  });

  group('TelemetryScore.label', () {
    test('returns Excellent for score >= 0.8', () {
        expect(TelemetryScore.label(0.8), 'Excellent');
        expect(TelemetryScore.label(1.0), 'Excellent');
    });

    test('returns Good for 0.6 <= score < 0.8', () {
        expect(TelemetryScore.label(0.6), 'Good');
        expect(TelemetryScore.label(0.79), 'Good');
    });

    test('returns Partial for 0.4 <= score < 0.6', () {
        expect(TelemetryScore.label(0.4), 'Partial');
        expect(TelemetryScore.label(0.59), 'Partial');
    });

    test('returns Minimal for score < 0.4', () {
        expect(TelemetryScore.label(0.39), 'Minimal');
        expect(TelemetryScore.label(0.0), 'Minimal');
    });
  });
}
