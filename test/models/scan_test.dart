import 'package:flutter_test/flutter_test.dart';
import 'package:flora_scan/models/scan.dart';

void main() {
  group('ProcessingStatus Tests', () {
    test('fromString returns correct status for valid strings', () {
      expect(ProcessingStatus.fromString('queued'), ProcessingStatus.queued);
      expect(ProcessingStatus.fromString('enriching'), ProcessingStatus.enriching);
      expect(ProcessingStatus.fromString('diagnosing'), ProcessingStatus.diagnosing);
      expect(ProcessingStatus.fromString('completed'), ProcessingStatus.completed);
      expect(ProcessingStatus.fromString('failed'), ProcessingStatus.failed);
    });

    test('fromString returns queued for invalid strings', () {
      expect(ProcessingStatus.fromString('unknown_status'), ProcessingStatus.queued);
      expect(ProcessingStatus.fromString(''), ProcessingStatus.queued);
    });
  });

  group('ConfidenceLevel Tests', () {
    test('fromScore handles null correctly', () {
      expect(ConfidenceLevel.fromScore(null), ConfidenceLevel.low);
    });

    test('fromScore returns correct level based on thresholds', () {
      expect(ConfidenceLevel.fromScore(0.39), ConfidenceLevel.low);
      expect(ConfidenceLevel.fromScore(0.4), ConfidenceLevel.medium);
      expect(ConfidenceLevel.fromScore(0.69), ConfidenceLevel.medium);
      expect(ConfidenceLevel.fromScore(0.7), ConfidenceLevel.high);
      expect(ConfidenceLevel.fromScore(1.0), ConfidenceLevel.high);
    });

    test('displayLabel returns correct string', () {
      expect(ConfidenceLevel.low.displayLabel, 'Low');
      expect(ConfidenceLevel.medium.displayLabel, 'Medium');
      expect(ConfidenceLevel.high.displayLabel, 'High');
    });
  });

  group('Scan Model Tests', () {
    final baseScanJson = {
      'id': 'scan_123',
      'user_id': 'user_456',
      'plant_id': 'plant_789',
      'client_scan_id': 'client_abc',
      'captured_at_utc': '2023-10-27T10:00:00.000Z',
      'image_path': '/path/to/image.jpg',
      'created_at': '2023-10-27T10:00:00.000Z',
      'updated_at': '2023-10-27T10:00:00.000Z',
      'processing_status': 'queued',
    };

    test('fromJson handles minimal valid JSON', () {
      final scan = Scan.fromJson(baseScanJson);

      expect(scan.id, 'scan_123');
      expect(scan.userId, 'user_456');
      expect(scan.plantId, 'plant_789');
      expect(scan.clientScanId, 'client_abc');
      expect(scan.capturedAtUtc, DateTime.utc(2023, 10, 27, 10, 0, 0));
      expect(scan.imagePath, '/path/to/image.jpg');
      expect(scan.processingStatus, ProcessingStatus.queued);

      // Nullable fields should be null
      expect(scan.uploadedAtUtc, isNull);
      expect(scan.latPrecise, isNull);
      expect(scan.diagnosisConfidence, isNull);
    });

    test('fromJson handles full JSON', () {
      final fullJson = {
        ...baseScanJson,
        'uploaded_at_utc': '2023-10-27T10:05:00.000Z',
        'image_sha256': 'sha256hash',
        'image_width': 1920,
        'image_height': 1080,
        'device_platform': 'android',
        'app_version': '1.0.0',
        'device_tz': 'UTC',
        'lat_precise': 37.7749,
        'lon_precise': -122.4194,
        'lat_rounded': 37.77,
        'lon_rounded': -122.42,
        'geohash_6': '9q8yy',
        'altitude_meters': 100.5,
        'location_accuracy_meters': 10.0,
        'reverse_geo': {'city': 'San Francisco'},
        'lux_reading': 500.0,
        'lux_source': 'sensor',
        'device_pitch_deg': 45.0,
        'device_roll_deg': 0.0,
        'flash_fired': true,
        'temp_c': 22.5,
        'humidity_pct': 60.0,
        'vpd_kpa': 1.2,
        'solar_radiation_wm2': 800.0,
        'et0_mm': 5.0,
        'soil_temp_0cm_c': 20.0,
        'aqi': 50,
        'pm2_5': 12.0,
        'pm10': 20.0,
        'no2': 15.0,
        'o3': 30.0,
        'image_quality_score': 0.95,
        'telemetry_completeness_score': 1.0,
        'processing_status': 'completed',
        'processing_error': null,
        'ai_model_name': 'gemini-flash',
        'ai_model_version': '1.0',
        'prompt_version': 'v2',
        'diagnosis_confidence': 0.85,
        'health_score': 90,
        'diagnosis_code': 'healthy',
        'diagnosis_localized': 'Healthy Plant',
        'treatment_localized': 'Water regularly',
        'visual_symptoms': ['green_leaves'],
        'ai_diagnosis_raw': {'raw': 'data'},
      };

      final scan = Scan.fromJson(fullJson);

      expect(scan.uploadedAtUtc, DateTime.utc(2023, 10, 27, 10, 5, 0));
      expect(scan.latPrecise, 37.7749);
      expect(scan.diagnosisConfidence, 0.85);
      expect(scan.visualSymptoms, ['green_leaves']);
      expect(scan.processingStatus, ProcessingStatus.completed);
    });

    test('toJson produces correct map', () {
      final scan = Scan(
        id: 'scan_123',
        userId: 'user_456',
        plantId: 'plant_789',
        clientScanId: 'client_abc',
        capturedAtUtc: DateTime.utc(2023, 10, 27, 10, 0, 0),
        imagePath: '/path/to/image.jpg',
        createdAt: DateTime.utc(2023, 10, 27, 10, 0, 0),
        updatedAt: DateTime.utc(2023, 10, 27, 10, 0, 0),
        processingStatus: ProcessingStatus.queued,
        diagnosisConfidence: 0.8,
      );

      final json = scan.toJson();

      expect(json['id'], 'scan_123');
      expect(json['processing_status'], 'queued');
      expect(json['diagnosis_confidence'], 0.8);
      // Ensure date format is ISO8601
      expect(json['captured_at_utc'], '2023-10-27T10:00:00.000Z');
    });

    test('Getters return correct values', () {
      final scanQueued = Scan(
        id: '1', userId: 'u', plantId: 'p', clientScanId: 'c',
        capturedAtUtc: DateTime.now(), imagePath: 'i',
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
        processingStatus: ProcessingStatus.queued,
      );

      expect(scanQueued.isComplete, false);
      expect(scanQueued.isFailed, false);
      expect(scanQueued.isProcessing, false);

      final scanEnriching = Scan(
        id: '1', userId: 'u', plantId: 'p', clientScanId: 'c',
        capturedAtUtc: DateTime.now(), imagePath: 'i',
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
        processingStatus: ProcessingStatus.enriching,
      );
       expect(scanEnriching.isComplete, false);
       expect(scanEnriching.isProcessing, true);

       final scanDiagnosing = Scan(
        id: '1', userId: 'u', plantId: 'p', clientScanId: 'c',
        capturedAtUtc: DateTime.now(), imagePath: 'i',
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
        processingStatus: ProcessingStatus.diagnosing,
      );
       expect(scanDiagnosing.isProcessing, true);


      final scanCompleted = Scan(
        id: '1', userId: 'u', plantId: 'p', clientScanId: 'c',
        capturedAtUtc: DateTime.now(), imagePath: 'i',
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
        processingStatus: ProcessingStatus.completed,
        diagnosisConfidence: 0.9,
      );
      expect(scanCompleted.isComplete, true);
      expect(scanCompleted.isFailed, false);
      expect(scanCompleted.isProcessing, false);
      expect(scanCompleted.confidenceLevel, ConfidenceLevel.high);

      final scanFailed = Scan(
        id: '1', userId: 'u', plantId: 'p', clientScanId: 'c',
        capturedAtUtc: DateTime.now(), imagePath: 'i',
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
        processingStatus: ProcessingStatus.failed,
      );
      expect(scanFailed.isComplete, false);
      expect(scanFailed.isFailed, true);
      expect(scanFailed.isProcessing, false);
    });
  });
}
