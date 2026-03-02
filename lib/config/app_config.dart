/// Application configuration constants.
///
/// In production, these should be loaded from environment variables
/// or a secure configuration service.
class AppConfig {
  AppConfig._();

  // Supabase
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const bool appTestMode = bool.fromEnvironment(
    'APP_TEST_MODE',
    defaultValue: false,
  );
  static const String dodoCheckoutBaseUrl = String.fromEnvironment(
    'DODO_CHECKOUT_BASE_URL',
    defaultValue: '',
  );
  static const String dodoSuccessUrl = String.fromEnvironment(
    'DODO_SUCCESS_URL',
    defaultValue: 'florascan://payment/success',
  );
  static const String dodoCancelUrl = String.fromEnvironment(
    'DODO_CANCEL_URL',
    defaultValue: 'florascan://payment/cancel',
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
