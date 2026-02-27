import 'package:flutter_test/flutter_test.dart';
import 'package:flora_scan/utils/geohash.dart';

void main() {
  group('Geohash Tests', () {
    test('encode returns correct geohash for San Francisco', () {
      // 37.7749, -122.4194
      // Precision 6
      // Expected: 9q8yyk
      expect(Geohash.encode(37.7749, -122.4194, precision: 6), '9q8yyk');
    });

    test('encode returns correct geohash for New York', () {
      // 40.7128, -74.0060
      // Precision 6
      // Expected: dr5reg
      expect(Geohash.encode(40.7128, -74.0060, precision: 6), 'dr5reg');
    });

    test('encode returns correct geohash for London', () {
      // 51.5074, -0.1278
      // Precision 6
      // Expected: gcpvj0
      expect(Geohash.encode(51.5074, -0.1278, precision: 6), 'gcpvj0');
    });

    test('encode handles different precision', () {
       expect(Geohash.encode(37.7749, -122.4194, precision: 5), '9q8yy');
       expect(Geohash.encode(37.7749, -122.4194, precision: 8), '9q8yyk8y');
    });

    test('encode handles edge cases (0,0)', () {
       // 0,0 -> s00000...
       expect(Geohash.encode(0.0, 0.0, precision: 6), 's00000');
    });

    test('roundCoordinate rounds to specified decimals', () {
      expect(Geohash.roundCoordinate(37.7749, decimals: 2), 37.77);
      expect(Geohash.roundCoordinate(37.7751, decimals: 2), 37.78);
      expect(Geohash.roundCoordinate(37.7749, decimals: 1), 37.8);
      expect(Geohash.roundCoordinate(123.45678, decimals: 3), 123.457);
    });

    test('decode returns correct coordinates for San Francisco', () {
      // 9q8yyk -> 37.7749, -122.4194
      final result = Geohash.decode('9q8yyk');
      expect(result['latitude'], closeTo(37.7749, 0.01));
      expect(result['longitude'], closeTo(-122.4194, 0.01));
    });

    test('decode returns correct coordinates for New York', () {
      // dr5reg -> 40.7128, -74.0060
      final result = Geohash.decode('dr5reg');
      expect(result['latitude'], closeTo(40.7128, 0.01));
      expect(result['longitude'], closeTo(-74.0060, 0.01));
    });

    test('decode handles edge cases (0,0)', () {
      final result = Geohash.decode('s00000');
      // The error margin for 6 chars is roughly +/- 0.6km, which is approx 0.005 degrees.
      // 0,0 center might be slightly off due to geohash box center.
      // 's00000' actually corresponds to a box.
      // decoding returns the center of that box.
      // For s00000, lat range is [0, 0.0054931640625], lon range is [0, 0.010986328125]
      // center lat: ~0.0027, center lon: ~0.0055
      expect(result['latitude'], closeTo(0.0, 0.01));
      expect(result['longitude'], closeTo(0.0, 0.01));
    });

    test('decode throws error for empty string', () {
      expect(() => Geohash.decode(''), throwsArgumentError);
    });

    test('decode throws error for invalid characters', () {
      expect(() => Geohash.decode('abc@123'), throwsFormatException); // @ is invalid
      // 'a', 'i', 'l', 'o' are invalid in geohash base32
      expect(() => Geohash.decode('ail'), throwsFormatException);
    });

    test('round trip encode -> decode', () {
      double lat = 37.7749;
      double lon = -122.4194;
      // Using higher precision for better round trip accuracy
      String hash = Geohash.encode(lat, lon, precision: 12);
      Map<String, double> decoded = Geohash.decode(hash);

      // Precision 12 is extremely precise, error should be tiny.
      expect(decoded['latitude'], closeTo(lat, 0.000001));
      expect(decoded['longitude'], closeTo(lon, 0.000001));
    });
  });
}
