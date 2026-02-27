import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flora_scan/services/sensor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String channelName = 'dev.fluttercommunity.plus/sensors/accelerometer';
  const MethodChannel channel = MethodChannel('dev.fluttercommunity.plus/sensors/method');
  const EventChannel eventChannel = EventChannel(channelName);

  setUp(() {
    // Reset any previous handlers
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'setAccelerationSamplingPeriod') {
          return null;
        }
        return null;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
      eventChannel,
      null,
    );
  });

  test('SensorService.capture returns valid data when accelerometer succeeds', () async {
    // The implementation expects a list of 4 values (x, y, z, timestamp_microseconds)
    // based on MethodChannelSensors implementation.
    // timestamp is int (microseconds since epoch)
    final timestamp = DateTime.now().microsecondsSinceEpoch.toDouble();
    _mockStream(eventChannel, [0.0, 0.0, 9.8, timestamp]);

    final result = await SensorService.capture();

    expect(result, isNotNull);
    expect(result.pitchDeg, isNotNull, reason: 'Pitch should not be null');
    expect(result.rollDeg, isNotNull, reason: 'Roll should not be null');
    // atan2(0, 9.8) is 0
    expect(result.pitchDeg, closeTo(0, 0.1));
    expect(result.rollDeg, closeTo(0, 0.1));
  });

  test('SensorService.capture returns partial data when accelerometer fails', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
      eventChannel,
      _MockStreamHandler(shouldThrow: true),
    );

    final result = await SensorService.capture();

    expect(result, isNotNull);
    expect(result.pitchDeg, isNull);
    expect(result.rollDeg, isNull);
  });

  test('SensorService.capture returns partial data on timeout', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
      eventChannel,
      _MockStreamHandler(delay: const Duration(seconds: 3)),
    );

    final result = await SensorService.capture();

    expect(result, isNotNull);
    expect(result.pitchDeg, isNull);
    expect(result.rollDeg, isNull);
  });
}

void _mockStream(EventChannel channel, List<double> values) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
    channel,
    _MockStreamHandler(values: values),
  );
}

class _MockStreamHandler extends MockStreamHandler {
  final List<double>? values;
  final bool shouldThrow;
  final Duration? delay;

  _MockStreamHandler({this.values, this.shouldThrow = false, this.delay});

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) async {
    if (delay != null) {
      await Future.delayed(delay!);
    }
    if (shouldThrow) {
      events.error(code: 'SENSOR_ERROR', message: 'Sensor failed', details: null);
      return;
    }
    if (values != null) {
      events.success(values);
    }
  }

  @override
  void onCancel(Object? arguments) {}
}
