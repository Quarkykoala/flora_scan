/// Processing status for a scan.
enum ProcessingStatus {
  queued,
  enriching,
  diagnosing,
  completed,
  failed;

  static ProcessingStatus fromString(String value) {
    return ProcessingStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ProcessingStatus.queued,
    );
  }
}

/// Confidence level derived from numeric confidence.
enum ConfidenceLevel {
  high,
  medium,
  low;

  static ConfidenceLevel fromScore(double? score) {
    if (score == null) return ConfidenceLevel.low;
    if (score >= 0.7) return ConfidenceLevel.high;
    if (score >= 0.4) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }

  String get displayLabel {
    switch (this) {
      case ConfidenceLevel.high:
        return 'High';
      case ConfidenceLevel.medium:
        return 'Medium';
      case ConfidenceLevel.low:
        return 'Low';
    }
  }
}

/// Full scan model matching the `scans` (Golden Record) table.
class Scan {
  // Identity
  final String id;
  final String userId;
  final String plantId;
  final String clientScanId;
  final DateTime capturedAtUtc;
  final DateTime? uploadedAtUtc;

  // Image
  final String imagePath;
  final String? imageSha256;
  final int? imageWidth;
  final int? imageHeight;

  // Device metadata
  final String? devicePlatform;
  final String? appVersion;
  final String? deviceTz;

  // Geospatial
  final double? latPrecise;
  final double? lonPrecise;
  final double? latRounded;
  final double? lonRounded;
  final String? geohash6;
  final double? altitudeMeters;
  final double? locationAccuracyMeters;
  final Map<String, dynamic>? reverseGeo;

  // Hardware telemetry
  final double? luxReading;
  final String? luxSource;
  final double? devicePitchDeg;
  final double? deviceRollDeg;
  final bool? flashFired;

  // Atmospheric telemetry
  final double? tempC;
  final double? humidityPct;
  final double? vpdKpa;
  final double? solarRadiationWm2;
  final double? et0Mm;
  final double? soilTemp0cmC;

  // Air quality
  final int? aqi;
  final double? pm25;
  final double? pm10;
  final double? no2;
  final double? o3;

  // Quality
  final double? imageQualityScore;
  final double? telemetryCompletenessScore;
  final ProcessingStatus processingStatus;
  final String? processingError;

  // AI Diagnosis
  final String? aiModelName;
  final String? aiModelVersion;
  final String? promptVersion;
  final double? diagnosisConfidence;
  final int? healthScore;
  final String? diagnosisCode;
  final String? diagnosisLocalized;
  final String? treatmentLocalized;
  final List<String>? visualSymptoms;
  final Map<String, dynamic>? aiDiagnosisRaw;

  // Audit
  final DateTime createdAt;
  final DateTime updatedAt;

  const Scan({
    required this.id,
    required this.userId,
    required this.plantId,
    required this.clientScanId,
    required this.capturedAtUtc,
    this.uploadedAtUtc,
    required this.imagePath,
    this.imageSha256,
    this.imageWidth,
    this.imageHeight,
    this.devicePlatform,
    this.appVersion,
    this.deviceTz,
    this.latPrecise,
    this.lonPrecise,
    this.latRounded,
    this.lonRounded,
    this.geohash6,
    this.altitudeMeters,
    this.locationAccuracyMeters,
    this.reverseGeo,
    this.luxReading,
    this.luxSource,
    this.devicePitchDeg,
    this.deviceRollDeg,
    this.flashFired,
    this.tempC,
    this.humidityPct,
    this.vpdKpa,
    this.solarRadiationWm2,
    this.et0Mm,
    this.soilTemp0cmC,
    this.aqi,
    this.pm25,
    this.pm10,
    this.no2,
    this.o3,
    this.imageQualityScore,
    this.telemetryCompletenessScore,
    this.processingStatus = ProcessingStatus.queued,
    this.processingError,
    this.aiModelName,
    this.aiModelVersion,
    this.promptVersion,
    this.diagnosisConfidence,
    this.healthScore,
    this.diagnosisCode,
    this.diagnosisLocalized,
    this.treatmentLocalized,
    this.visualSymptoms,
    this.aiDiagnosisRaw,
    required this.createdAt,
    required this.updatedAt,
  });

  ConfidenceLevel get confidenceLevel =>
      ConfidenceLevel.fromScore(diagnosisConfidence);

  bool get isComplete => processingStatus == ProcessingStatus.completed;
  bool get isFailed => processingStatus == ProcessingStatus.failed;
  bool get isProcessing =>
      processingStatus == ProcessingStatus.enriching ||
      processingStatus == ProcessingStatus.diagnosing;

  factory Scan.fromJson(Map<String, dynamic> json) {
    return Scan(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      plantId: json['plant_id'] as String,
      clientScanId: json['client_scan_id'] as String,
      capturedAtUtc: DateTime.parse(json['captured_at_utc'] as String),
      uploadedAtUtc: json['uploaded_at_utc'] != null
          ? DateTime.parse(json['uploaded_at_utc'] as String)
          : null,
      imagePath: json['image_path'] as String,
      imageSha256: json['image_sha256'] as String?,
      imageWidth: json['image_width'] as int?,
      imageHeight: json['image_height'] as int?,
      devicePlatform: json['device_platform'] as String?,
      appVersion: json['app_version'] as String?,
      deviceTz: json['device_tz'] as String?,
      latPrecise: (json['lat_precise'] as num?)?.toDouble(),
      lonPrecise: (json['lon_precise'] as num?)?.toDouble(),
      latRounded: (json['lat_rounded'] as num?)?.toDouble(),
      lonRounded: (json['lon_rounded'] as num?)?.toDouble(),
      geohash6: json['geohash_6'] as String?,
      altitudeMeters: (json['altitude_meters'] as num?)?.toDouble(),
      locationAccuracyMeters:
          (json['location_accuracy_meters'] as num?)?.toDouble(),
      reverseGeo: json['reverse_geo'] as Map<String, dynamic>?,
      luxReading: (json['lux_reading'] as num?)?.toDouble(),
      luxSource: json['lux_source'] as String?,
      devicePitchDeg: (json['device_pitch_deg'] as num?)?.toDouble(),
      deviceRollDeg: (json['device_roll_deg'] as num?)?.toDouble(),
      flashFired: json['flash_fired'] as bool?,
      tempC: (json['temp_c'] as num?)?.toDouble(),
      humidityPct: (json['humidity_pct'] as num?)?.toDouble(),
      vpdKpa: (json['vpd_kpa'] as num?)?.toDouble(),
      solarRadiationWm2: (json['solar_radiation_wm2'] as num?)?.toDouble(),
      et0Mm: (json['et0_mm'] as num?)?.toDouble(),
      soilTemp0cmC: (json['soil_temp_0cm_c'] as num?)?.toDouble(),
      aqi: json['aqi'] as int?,
      pm25: (json['pm2_5'] as num?)?.toDouble(),
      pm10: (json['pm10'] as num?)?.toDouble(),
      no2: (json['no2'] as num?)?.toDouble(),
      o3: (json['o3'] as num?)?.toDouble(),
      imageQualityScore: (json['image_quality_score'] as num?)?.toDouble(),
      telemetryCompletenessScore:
          (json['telemetry_completeness_score'] as num?)?.toDouble(),
      processingStatus:
          ProcessingStatus.fromString(json['processing_status'] as String),
      processingError: json['processing_error'] as String?,
      aiModelName: json['ai_model_name'] as String?,
      aiModelVersion: json['ai_model_version'] as String?,
      promptVersion: json['prompt_version'] as String?,
      diagnosisConfidence:
          (json['diagnosis_confidence'] as num?)?.toDouble(),
      healthScore: json['health_score'] as int?,
      diagnosisCode: json['diagnosis_code'] as String?,
      diagnosisLocalized: json['diagnosis_localized'] as String?,
      treatmentLocalized: json['treatment_localized'] as String?,
      visualSymptoms: (json['visual_symptoms'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      aiDiagnosisRaw: json['ai_diagnosis_raw'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'plant_id': plantId,
      'client_scan_id': clientScanId,
      'captured_at_utc': capturedAtUtc.toIso8601String(),
      'uploaded_at_utc': uploadedAtUtc?.toIso8601String(),
      'image_path': imagePath,
      'image_sha256': imageSha256,
      'image_width': imageWidth,
      'image_height': imageHeight,
      'device_platform': devicePlatform,
      'app_version': appVersion,
      'device_tz': deviceTz,
      'lat_precise': latPrecise,
      'lon_precise': lonPrecise,
      'lat_rounded': latRounded,
      'lon_rounded': lonRounded,
      'geohash_6': geohash6,
      'altitude_meters': altitudeMeters,
      'location_accuracy_meters': locationAccuracyMeters,
      'reverse_geo': reverseGeo,
      'lux_reading': luxReading,
      'lux_source': luxSource,
      'device_pitch_deg': devicePitchDeg,
      'device_roll_deg': deviceRollDeg,
      'flash_fired': flashFired,
      'temp_c': tempC,
      'humidity_pct': humidityPct,
      'vpd_kpa': vpdKpa,
      'solar_radiation_wm2': solarRadiationWm2,
      'et0_mm': et0Mm,
      'soil_temp_0cm_c': soilTemp0cmC,
      'aqi': aqi,
      'pm2_5': pm25,
      'pm10': pm10,
      'no2': no2,
      'o3': o3,
      'image_quality_score': imageQualityScore,
      'telemetry_completeness_score': telemetryCompletenessScore,
      'processing_status': processingStatus.name,
      'processing_error': processingError,
      'ai_model_name': aiModelName,
      'ai_model_version': aiModelVersion,
      'prompt_version': promptVersion,
      'diagnosis_confidence': diagnosisConfidence,
      'health_score': healthScore,
      'diagnosis_code': diagnosisCode,
      'diagnosis_localized': diagnosisLocalized,
      'treatment_localized': treatmentLocalized,
      'visual_symptoms': visualSymptoms,
      'ai_diagnosis_raw': aiDiagnosisRaw,
    };
  }
}
