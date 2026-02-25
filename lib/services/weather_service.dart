import 'dart:math' show pow;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Weather enrichment data from Open-Meteo.
class WeatherData {
  final double? tempC;
  final double? humidityPct;
  final double? vpdKpa;
  final double? solarRadiationWm2;
  final double? et0Mm;
  final double? soilTemp0cmC;

  const WeatherData({
    this.tempC,
    this.humidityPct,
    this.vpdKpa,
    this.solarRadiationWm2,
    this.et0Mm,
    this.soilTemp0cmC,
  });

  bool get hasData => tempC != null || humidityPct != null;

  factory WeatherData.fromOpenMeteo(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>?;
    if (current == null) return const WeatherData();

    final tempC = (current['temperature_2m'] as num?)?.toDouble();
    final humidity = (current['relative_humidity_2m'] as num?)?.toDouble();

    // Compute VPD (Vapor Pressure Deficit)
    double? vpd;
    if (tempC != null && humidity != null) {
      vpd = _computeVpd(tempC, humidity);
    }

    return WeatherData(
      tempC: tempC,
      humidityPct: humidity,
      vpdKpa: vpd,
      solarRadiationWm2:
          (current['shortwave_radiation'] as num?)?.toDouble(),
      et0Mm: (current['et0_fao_evapotranspiration'] as num?)?.toDouble(),
      soilTemp0cmC:
          (current['soil_temperature_0cm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temp_c': tempC,
      'humidity_pct': humidityPct,
      'vpd_kpa': vpdKpa,
      'solar_radiation_wm2': solarRadiationWm2,
      'et0_mm': et0Mm,
      'soil_temp_0cm_c': soilTemp0cmC,
    };
  }

  /// Compute Vapor Pressure Deficit (VPD) in kPa.
  /// VPD = saturated VP - actual VP
  static double _computeVpd(double tempC, double humidityPct) {
    // Tetens formula for saturated vapor pressure
    final svp = 0.6108 * _exp((17.27 * tempC) / (tempC + 237.3));
    final avp = svp * (humidityPct / 100.0);
    return svp - avp;
  }

  static double _exp(double x) {
    // Natural exponential approximation via dart:math
    return _pow(2.718281828459045, x);
  }

  static double _pow(double base, double exponent) {
    // Using Dart's built-in pow
    return base == 0 ? 0 : double.parse(
      (base).toStringAsFixed(10),
    ) != 0 ? _dartPow(base, exponent) : 0;
  }

  static double _dartPow(double base, double exp) {
    // Simple delegation to dart:math pow
    return pow(base, exp).toDouble();
  }
}

/// Service for fetching weather data from Open-Meteo API.
class WeatherService {
  WeatherService._();

  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Fetch current weather for coordinates.
  static Future<WeatherData> fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    try {
      Uri.parse(_baseUrl).replace(queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': [
          'temperature_2m',
          'relative_humidity_2m',
          'shortwave_radiation',
          'et0_fao_evapotranspiration',
        ].join(','),
        'timezone': 'auto',
      });

      final client = Supabase.instance.client;
      // Use Edge Function for server-side weather enrichment
      final response = await client.functions.invoke(
        'enrich-weather',
        body: {
          'latitude': latitude,
          'longitude': longitude,
        },
      );

      if (response.data != null) {
        return WeatherData.fromOpenMeteo(
          response.data as Map<String, dynamic>,
        );
      }

      return const WeatherData();
    } catch (e) {
      debugPrint('Weather fetch failed: $e');
      return const WeatherData();
    }
  }
}
