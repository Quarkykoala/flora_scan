import 'package:flutter_test/flutter_test.dart';
import 'package:flora_scan/services/weather_service.dart';

void main() {
  group('WeatherData', () {
    test('fromOpenMeteo parses valid JSON correctly and computes VPD', () {
      final json = {
        'current': {
          'temperature_2m': 25.0,
          'relative_humidity_2m': 50.0,
          'shortwave_radiation': 500.0,
          'et0_fao_evapotranspiration': 4.5,
          'soil_temperature_0cm': 20.0,
        }
      };

      final weather = WeatherData.fromOpenMeteo(json);

      expect(weather.tempC, 25.0);
      expect(weather.humidityPct, 50.0);
      expect(weather.solarRadiationWm2, 500.0);
      expect(weather.et0Mm, 4.5);
      expect(weather.soilTemp0cmC, 20.0);

      // VPD Calculation Check
      // SVP at 25C = 0.6108 * exp(17.27 * 25 / (25 + 237.3))
      // SVP ≈ 3.169 kPa
      // AVP = 3.169 * (50/100) = 1.5845 kPa
      // VPD = 3.169 - 1.5845 = 1.5845 kPa
      // Let's expect it to be close to 1.58
      expect(weather.vpdKpa, closeTo(1.58, 0.01));
    });

    test('fromOpenMeteo handles missing current block gracefully', () {
      final json = <String, dynamic>{};
      final weather = WeatherData.fromOpenMeteo(json);
      expect(weather.tempC, isNull);
      expect(weather.vpdKpa, isNull);
    });

    test('fromOpenMeteo handles partial data (missing humidity) by skipping VPD', () {
      final json = {
        'current': {
          'temperature_2m': 25.0,
          // humidity missing
        }
      };

      final weather = WeatherData.fromOpenMeteo(json);

      expect(weather.tempC, 25.0);
      expect(weather.humidityPct, isNull);
      expect(weather.vpdKpa, isNull);
    });

    test('fromOpenMeteo handles partial data (missing temperature) by skipping VPD', () {
      final json = {
        'current': {
          'relative_humidity_2m': 50.0,
          // temperature missing
        }
      };

      final weather = WeatherData.fromOpenMeteo(json);

      expect(weather.tempC, isNull);
      expect(weather.humidityPct, 50.0);
      expect(weather.vpdKpa, isNull);
    });

    test('VPD calculation edge case: 0% humidity', () {
      final json = {
        'current': {
          'temperature_2m': 25.0,
          'relative_humidity_2m': 0.0,
        }
      };

      final weather = WeatherData.fromOpenMeteo(json);
      // SVP at 25C ≈ 3.169
      // AVP = 0
      // VPD = SVP ≈ 3.169
       expect(weather.vpdKpa, closeTo(3.169, 0.01));
    });

    test('VPD calculation edge case: 100% humidity', () {
       final json = {
        'current': {
          'temperature_2m': 25.0,
          'relative_humidity_2m': 100.0,
        }
      };

      final weather = WeatherData.fromOpenMeteo(json);
      // SVP at 25C ≈ 3.169
      // AVP = SVP
      // VPD = 0
       expect(weather.vpdKpa, closeTo(0.0, 0.001));
    });
  });
}
