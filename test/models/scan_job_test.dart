import 'package:flutter_test/flutter_test.dart';
import 'package:flora_scan/models/scan_job.dart';

void main() {
  group('ScanJob', () {
    // Basic instantiation
    test('supports value comparisons', () {
      final now = DateTime.now();
      final job1 = ScanJob(
        id: '1',
        scanId: 'scan_1',
        jobType: ScanJobType.enrichWeather,
        status: ScanJobStatus.queued,
        createdAt: now,
      );
      final job2 = ScanJob(
        id: '1',
        scanId: 'scan_1',
        jobType: ScanJobType.enrichWeather,
        status: ScanJobStatus.queued,
        createdAt: now,
      );

      expect(job1, equals(job2));
    });

    // Serialization tests
    group('fromJson', () {
      test('parses correctly with all fields', () {
        final now = DateTime.now().toUtc();
        final json = {
          'id': '123',
          'scan_id': 'scan_abc',
          'job_type': 'enrich_weather',
          'status': 'succeeded',
          'attempts': 3,
          'started_at': now.toIso8601String(),
          'finished_at': now.add(const Duration(seconds: 10)).toIso8601String(),
          'error_message': null,
          'created_at': now.subtract(const Duration(minutes: 1)).toIso8601String(),
        };

        final job = ScanJob.fromJson(json);

        expect(job.id, '123');
        expect(job.scanId, 'scan_abc');
        expect(job.jobType, ScanJobType.enrichWeather);
        expect(job.status, ScanJobStatus.succeeded);
        expect(job.attempts, 3);
        expect(job.startedAt, now);
        expect(job.finishedAt, now.add(const Duration(seconds: 10)));
        expect(job.errorMessage, isNull);
        expect(job.createdAt, now.subtract(const Duration(minutes: 1)));
      });

      test('parses correctly with minimal fields', () {
        final now = DateTime.now().toUtc();
        final json = {
          'id': '123',
          'scan_id': 'scan_abc',
          'job_type': 'diagnose_ai',
          'status': 'queued',
          'created_at': now.toIso8601String(),
        };

        final job = ScanJob.fromJson(json);

        expect(job.id, '123');
        expect(job.scanId, 'scan_abc');
        expect(job.jobType, ScanJobType.diagnoseAi);
        expect(job.status, ScanJobStatus.queued);
        expect(job.attempts, 0); // Default
        expect(job.startedAt, isNull);
        expect(job.finishedAt, isNull);
        expect(job.errorMessage, isNull);
        expect(job.createdAt, now);
      });

      test('handles unknown enum values by falling back to defaults', () {
        final now = DateTime.now();
        final json = {
          'id': '1',
          'scan_id': 'scan_1',
          'job_type': 'unknown_type', // Should default to diagnoseAi
          'status': 'unknown_status', // Should default to queued
          'created_at': now.toIso8601String(),
        };

        final job = ScanJob.fromJson(json);

        expect(job.jobType, ScanJobType.diagnoseAi);
        expect(job.status, ScanJobStatus.queued);
      });
    });

    group('toJson', () {
      test('returns correct map', () {
        final now = DateTime.now().toUtc();
        final job = ScanJob(
          id: '123',
          scanId: 'scan_abc',
          jobType: ScanJobType.enrichAir,
          status: ScanJobStatus.failed,
          attempts: 2,
          startedAt: now,
          finishedAt: now.add(const Duration(seconds: 5)),
          errorMessage: 'Something went wrong',
          createdAt: now.subtract(const Duration(hours: 1)),
        );

        final json = job.toJson();

        expect(json['id'], '123');
        expect(json['scan_id'], 'scan_abc');
        expect(json['job_type'], 'enrich_air');
        expect(json['status'], 'failed');
        expect(json['attempts'], 2);
        expect(json['started_at'], now.toIso8601String());
        expect(json['finished_at'], now.add(const Duration(seconds: 5)).toIso8601String());
        expect(json['error_message'], 'Something went wrong');
        expect(json['created_at'], now.subtract(const Duration(hours: 1)).toIso8601String());
      });

      test('round trip serialization works', () {
        final now = DateTime.now().toUtc();
        // Truncating to microseconds to avoid potential precision issues during round trip if needed,
        // but ISO8601 usually handles it fine. Let's see.
        final originalJob = ScanJob(
          id: 'round_trip_id',
          scanId: 'round_trip_scan',
          jobType: ScanJobType.enrichWeather,
          status: ScanJobStatus.running,
          attempts: 1,
          startedAt: now,
          createdAt: now.subtract(const Duration(minutes: 5)),
        );

        final json = originalJob.toJson();
        final parsedJob = ScanJob.fromJson(json);

        expect(parsedJob, equals(originalJob));
      });
    });

    group('isComplete', () {
      test('returns true for succeeded', () {
        final job = ScanJob(
          id: '1',
          scanId: '1',
          jobType: ScanJobType.diagnoseAi,
          status: ScanJobStatus.succeeded,
          createdAt: DateTime.now(),
        );
        expect(job.isComplete, isTrue);
      });

      test('returns true for failed', () {
        final job = ScanJob(
          id: '1',
          scanId: '1',
          jobType: ScanJobType.diagnoseAi,
          status: ScanJobStatus.failed,
          createdAt: DateTime.now(),
        );
        expect(job.isComplete, isTrue);
      });

      test('returns false for queued', () {
        final job = ScanJob(
          id: '1',
          scanId: '1',
          jobType: ScanJobType.diagnoseAi,
          status: ScanJobStatus.queued,
          createdAt: DateTime.now(),
        );
        expect(job.isComplete, isFalse);
      });

      test('returns false for running', () {
        final job = ScanJob(
          id: '1',
          scanId: '1',
          jobType: ScanJobType.diagnoseAi,
          status: ScanJobStatus.running,
          createdAt: DateTime.now(),
        );
        expect(job.isComplete, isFalse);
      });
       test('returns false for retrying', () {
        final job = ScanJob(
          id: '1',
          scanId: '1',
          jobType: ScanJobType.diagnoseAi,
          status: ScanJobStatus.retrying,
          createdAt: DateTime.now(),
        );
        expect(job.isComplete, isFalse);
      });
    });
  });
}
