/// Sync status for offline queue items.
enum SyncStatus {
  pendingUpload,
  uploading,
  uploaded,
  failed;

  static SyncStatus fromString(String value) {
    return SyncStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SyncStatus.pendingUpload,
    );
  }
}

/// Local pending scan for Isar offline queue.
///
/// This is the local-only representation stored in Isar
/// before syncing to Supabase.
class PendingScan {
  int? isarId;
  final String clientScanId;
  final String plantId;
  final String localImagePath;
  final DateTime capturedAtUtc;
  final String deviceTz;
  final String? devicePlatform;
  final String appVersion;

  // Telemetry captured locally
  final double? latitude;
  final double? longitude;
  final double? altitude;
  final double? locationAccuracy;
  final double? luxReading;
  final String luxSource;
  final double? devicePitchDeg;
  final double? deviceRollDeg;
  final bool flashFired;

  // Sync state
  SyncStatus syncStatus;
  int retryCount;
  String? lastError;
  DateTime? lastAttempt;

  PendingScan({
    this.isarId,
    required this.clientScanId,
    required this.plantId,
    required this.localImagePath,
    required this.capturedAtUtc,
    required this.deviceTz,
    this.devicePlatform,
    this.appVersion = '1.0.0',
    this.latitude,
    this.longitude,
    this.altitude,
    this.locationAccuracy,
    this.luxReading,
    this.luxSource = 'unavailable',
    this.devicePitchDeg,
    this.deviceRollDeg,
    this.flashFired = false,
    this.syncStatus = SyncStatus.pendingUpload,
    this.retryCount = 0,
    this.lastError,
    this.lastAttempt,
  });

  bool get canRetry => retryCount < 5;

  Duration get nextRetryDelay {
    // Exponential backoff: 2^retryCount seconds, max 5 minutes
    final seconds = (1 << retryCount).clamp(1, 300);
    return Duration(seconds: seconds);
  }

  Map<String, dynamic> toJson() {
    return {
      'isar_id': isarId,
      'client_scan_id': clientScanId,
      'plant_id': plantId,
      'local_image_path': localImagePath,
      'captured_at_utc': capturedAtUtc.toIso8601String(),
      'device_tz': deviceTz,
      'device_platform': devicePlatform,
      'app_version': appVersion,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'location_accuracy': locationAccuracy,
      'lux_reading': luxReading,
      'lux_source': luxSource,
      'device_pitch_deg': devicePitchDeg,
      'device_roll_deg': deviceRollDeg,
      'flash_fired': flashFired,
      'sync_status': syncStatus.name,
      'retry_count': retryCount,
      'last_error': lastError,
      'last_attempt': lastAttempt?.toIso8601String(),
    };
  }

  factory PendingScan.fromJson(Map<String, dynamic> json) {
    return PendingScan(
      isarId: json['isar_id'] as int?,
      clientScanId: json['client_scan_id'] as String,
      plantId: json['plant_id'] as String,
      localImagePath: json['local_image_path'] as String,
      capturedAtUtc: DateTime.parse(json['captured_at_utc'] as String),
      deviceTz: json['device_tz'] as String,
      devicePlatform: json['device_platform'] as String?,
      appVersion: json['app_version'] as String? ?? '1.0.0',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      locationAccuracy: (json['location_accuracy'] as num?)?.toDouble(),
      luxReading: (json['lux_reading'] as num?)?.toDouble(),
      luxSource: json['lux_source'] as String? ?? 'unavailable',
      devicePitchDeg: (json['device_pitch_deg'] as num?)?.toDouble(),
      deviceRollDeg: (json['device_roll_deg'] as num?)?.toDouble(),
      flashFired: json['flash_fired'] as bool? ?? false,
      syncStatus:
          SyncStatus.fromString(json['sync_status'] as String? ?? 'pendingUpload'),
      retryCount: json['retry_count'] as int? ?? 0,
      lastError: json['last_error'] as String?,
      lastAttempt: json['last_attempt'] != null
          ? DateTime.parse(json['last_attempt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toUploadJson(String userId, String imagePath) {
    return {
      'user_id': userId,
      'plant_id': plantId,
      'client_scan_id': clientScanId,
      'captured_at_utc': capturedAtUtc.toIso8601String(),
      'uploaded_at_utc': DateTime.now().toUtc().toIso8601String(),
      'image_path': imagePath,
      'device_platform': devicePlatform,
      'app_version': appVersion,
      'device_tz': deviceTz,
      'lat_precise': latitude,
      'lon_precise': longitude,
      'lat_rounded': latitude != null
          ? (latitude! * 100).roundToDouble() / 100
          : null,
      'lon_rounded': longitude != null
          ? (longitude! * 100).roundToDouble() / 100
          : null,
      'altitude_meters': altitude,
      'location_accuracy_meters': locationAccuracy,
      'lux_reading': luxReading,
      'lux_source': luxSource,
      'device_pitch_deg': devicePitchDeg,
      'device_roll_deg': deviceRollDeg,
      'flash_fired': flashFired,
      'processing_status': 'queued',
    };
  }
}
