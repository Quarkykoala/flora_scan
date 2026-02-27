import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/pending_scan.dart';
import '../utils/geohash.dart';
import '../utils/image_utils.dart';
import 'location_service.dart';
import 'sensor_service.dart';
import 'supabase_service.dart';

/// Result of local scan capture.
class LocalCaptureResult {
  final String clientScanId;
  final String localImagePath;
  final DateTime capturedAt;
  final LocationCapture? location;
  final SensorCapture sensors;

  const LocalCaptureResult({
    required this.clientScanId,
    required this.localImagePath,
    required this.capturedAt,
    this.location,
    required this.sensors,
  });
}

/// Orchestrates the async scan pipeline:
/// 1. Local capture (instant)
/// 2. Queue to offline store
/// 3. Upload when online
/// 4. Server enrichment + AI diagnosis
class ScanPipelineService {
  ScanPipelineService._();

  static const _uuid = Uuid();

  /// Step 1: Capture all local telemetry instantly.
  /// Target: <300ms UI feedback.
  static Future<LocalCaptureResult> captureLocally({
    required String imagePath,
  }) async {
    final clientScanId = _uuid.v4();
    final capturedAt = DateTime.now().toUtc();

    // Capture location and sensors in parallel
    final results = await Future.wait([
      LocationService.capture(),
      SensorService.capture(),
    ]);

    final location = results[0] as LocationCapture?;
    final sensors = results[1] as SensorCapture;

    return LocalCaptureResult(
      clientScanId: clientScanId,
      localImagePath: imagePath,
      capturedAt: capturedAt,
      location: location,
      sensors: sensors,
    );
  }

  /// Step 2: Create a PendingScan for offline queue.
  static PendingScan createPendingScan({
    required LocalCaptureResult capture,
    required String plantId,
  }) {
    return PendingScan(
      clientScanId: capture.clientScanId,
      plantId: plantId,
      localImagePath: capture.localImagePath,
      capturedAtUtc: capture.capturedAt,
      deviceTz: DateTime.now().timeZoneName,
      devicePlatform: Platform.isAndroid ? 'android' : 'ios',
      appVersion: AppConfig.appVersion,
      latitude: capture.location?.latitude,
      longitude: capture.location?.longitude,
      altitude: capture.location?.altitude,
      locationAccuracy: capture.location?.accuracy,
      luxReading: capture.sensors.luxReading,
      luxSource: capture.sensors.luxSource,
      devicePitchDeg: capture.sensors.pitchDeg,
      deviceRollDeg: capture.sensors.rollDeg,
    );
  }

  /// Step 3: Upload scan to Supabase.
  /// Strips EXIF, uploads image, creates scan row, enqueues jobs.
  static Future<String> uploadScan(PendingScan pending) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // Read and process image
    final imageBytes = await ImageUtils.readImageFile(pending.localImagePath);
    final cleanBytes = await ImageUtils.stripExifMetadata(imageBytes);
    final sha256 = ImageUtils.computeSha256(cleanBytes);
    final dimensions = await ImageUtils.getImageDimensions(cleanBytes);
    final quality = await ImageUtils.assessQuality(cleanBytes);
    final mimeType = ImageUtils.getMimeType(cleanBytes);
    final extension = mimeType.split('/').last;

    // Upload image to storage
    final imagePath = await SupabaseService.uploadImage(
      userId: userId,
      scanId: pending.clientScanId,
      imageBytes: cleanBytes,
      extension: extension == 'octet-stream' ? 'jpg' : extension,
      contentType: mimeType,
    );

    // Compute geohash if location available
    String? geohash6;
    final lat = pending.latitude;
    final lon = pending.longitude;
    if (lat != null && lon != null) {
      geohash6 = Geohash.encode(
        lat,
        lon,
        precision: 6,
      );
    }

    // Create scan record
    final scanData = {
      ...pending.toUploadJson(userId, imagePath),
      'image_sha256': sha256,
      'image_width': dimensions?.width,
      'image_height': dimensions?.height,
      'image_quality_score': quality.overallScore,
      'geohash_6': geohash6,
      if (lat != null) 'lat_rounded': Geohash.roundCoordinate(lat),
      if (lon != null) 'lon_rounded': Geohash.roundCoordinate(lon),
    };

    final scanResult = await SupabaseService.createScan(scanData);
    final scanId = scanResult['id'] as String;

    // Trigger server-side processing via Edge Function
    try {
      await SupabaseService.invokeFunction(
        'create-scan',
        body: {'scan_id': scanId},
      );
    } catch (e) {
      debugPrint('Failed to trigger scan processing: $e');
      // Non-blocking — jobs can be retried
    }

    return scanId;
  }

  /// Poll scan status until complete or timeout.
  static Stream<String> pollScanStatus(String scanId) async* {
    const maxAttempts = 30;
    const interval = Duration(seconds: 2);

    for (int i = 0; i < maxAttempts; i++) {
      final status = await SupabaseService.getScanStatus(scanId);
      if (status != null) {
        yield status;
        if (status == 'completed' || status == 'failed') return;
      }
      await Future.delayed(interval);
    }

    yield 'timeout';
  }
}
