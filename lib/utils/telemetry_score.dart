/// Computes telemetry completeness score for a scan.
///
/// Score ranges from 0.0 to 1.0 based on how many
/// environmental data points were successfully captured.
class TelemetryScore {
  TelemetryScore._();

  /// Compute completeness score based on available telemetry fields.
  static double compute({
    required bool hasLocation,
    required bool hasLux,
    required bool hasOrientation,
    required bool hasWeather,
    required bool hasAirQuality,
    required bool hasAltitude,
  }) {
    // Weighted scoring: weather and location are most important
    const weights = {
      'location': 0.25,
      'weather': 0.25,
      'airQuality': 0.15,
      'lux': 0.15,
      'orientation': 0.10,
      'altitude': 0.10,
    };

    double score = 0;
    if (hasLocation) score += weights['location']!;
    if (hasWeather) score += weights['weather']!;
    if (hasAirQuality) score += weights['airQuality']!;
    if (hasLux) score += weights['lux']!;
    if (hasOrientation) score += weights['orientation']!;
    if (hasAltitude) score += weights['altitude']!;

    return score.clamp(0.0, 1.0);
  }

  /// Get human-readable completeness label.
  static String label(double score) {
    if (score >= 0.8) return 'Excellent';
    if (score >= 0.6) return 'Good';
    if (score >= 0.4) return 'Partial';
    return 'Minimal';
  }
}
