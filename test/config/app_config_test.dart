import 'package:flutter_test/flutter_test.dart';
import 'package:flora_scan/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('validation throws ArgumentError when environment variables are missing', () {
      // Since we can't inject environment variables into the running process easily during a test
      // (String.fromEnvironment is a compile-time constant),
      // we are verifying that the validation logic correctly identifies the missing values.
      //
      // In a default test environment without --dart-define, these should be empty.

      expect(
        () => AppConfig.validate(),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('constants are initialized', () {
       // Verify that the constants exist and have the expected default behavior (empty string in test env)
       expect(AppConfig.supabaseUrl, equals(''));
       expect(AppConfig.supabaseAnonKey, equals(''));
    });
  });
}
