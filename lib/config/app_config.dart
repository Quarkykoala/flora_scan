/// Application configuration constants.
///
/// In production, these should be loaded from environment variables
/// or a secure configuration service.
class AppConfig {
  AppConfig._();

  // Supabase
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Storage
  static const String imageBucket = 'plant-scans';

  // Open-Meteo
  static const String openMeteoBaseUrl = 'https://api.open-meteo.com/v1';

  // API rate limits
  static const int maxScansPerHour = 20;
  static const int maxScansPerDay = 100;

  // Cache durations
  static const Duration weatherCacheDuration = Duration(hours: 1);
  static const Duration airQualityCacheDuration = Duration(hours: 1);

  // Quality thresholds
  static const double minimumImageQuality = 0.3;
  static const double lowConfidenceThreshold = 0.4;
  static const double mediumConfidenceThreshold = 0.7;

  // App version for telemetry
  static const String appVersion = '1.0.0';

  /// Validates that all required configuration variables are present.
  /// Throws an [ArgumentError] if any required configuration is missing.
  static void validate() {
    if (supabaseUrl.isEmpty) {
      throw ArgumentError(
        'SUPABASE_URL is missing. Please provide it using --dart-define=SUPABASE_URL=...',
      );
    }
    if (supabaseAnonKey.isEmpty) {
      throw ArgumentError(
        'SUPABASE_ANON_KEY is missing. Please provide it using --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
  }
}
