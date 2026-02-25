/// Application configuration constants.
///
/// In production, these should be loaded from environment variables
/// or a secure configuration service.
class AppConfig {
  AppConfig._();

  // Supabase
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key',
  );

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
}
