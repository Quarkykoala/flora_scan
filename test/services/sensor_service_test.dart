import 'package:flutter_test/flutter_test.dart';
import 'package:flora_scan/services/sensor_service.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the MethodChannel for sensors_plus
  const MethodChannel channel = MethodChannel('dev.fluttercommunity.plus/sensors/method');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'setAccelerationSamplingPeriod') {
          return null;
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  group('SensorService', () {
    test('capture returns default lux values when sensor is unavailable', () async {
      // Act
      // The capture method calls accelerometerEventStream which will try to use the platform channel.
      // Since we are mocking the method channel, it shouldn't crash, but the stream might not emit anything.
      // The capture method has a timeout of 2 seconds for the accelerometer.
      // We expect it to complete (potentially after timeout or if we could mock the stream events)
      // and return a SensorCapture object.

      final capture = await SensorService.capture();

      // Assert
      expect(capture.luxReading, isNull);
      expect(capture.luxSource, 'unavailable');
    });

    test('SensorCapture default constructor works', () {
      const capture = SensorCapture();
      expect(capture.luxReading, isNull);
      expect(capture.luxSource, 'unavailable');
      expect(capture.pitchDeg, isNull);
      expect(capture.rollDeg, isNull);
    });
  });
}
