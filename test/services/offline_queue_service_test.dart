import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flora_scan/models/pending_scan.dart';
import 'package:flora_scan/services/offline_queue_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineQueueService Security Tests', () {
    late List<String> logMessages;

    setUp(() async {
      logMessages = [];
      SharedPreferences.setMockInitialValues({});
      await OfflineQueueService.clearQueue();
      // Override debugPrint to capture logs
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          logMessages.add(message);
        }
      };
    });

    tearDown(() {
      // Restore debugPrint
      debugPrint = debugPrintThrottled;
    });

    test('should NOT log sensitive information on upload failure', () async {
      // Arrange
      const sensitiveToken = 'SECRET_SENSITIVE_TOKEN_12345';
      final scan = PendingScan(
        clientScanId: 'test-scan-id',
        plantId: 'test-plant',
        localImagePath: '/tmp/test.jpg',
        capturedAtUtc: DateTime.now().toUtc(),
        deviceTz: 'UTC',
      );

      // Inject a mock uploader that throws a sensitive error
      OfflineQueueService.uploadCallback = (s) async {
        throw Exception('Upload failed because of invalid token: $sensitiveToken');
      };

      // Act
      await OfflineQueueService.enqueue(scan);
      // Wait for the async sync to complete (it's triggered by enqueue)
      // Since _attemptSync is fire-and-forget, we need to wait a bit or use forceSync
      await OfflineQueueService.forceSync();

      // Assert
      final combinedLogs = logMessages.join('\n');
      expect(
        combinedLogs.contains(sensitiveToken),
        isFalse,
        reason: 'Security Vulnerability: Sensitive token found in logs!',
      );
    });
  });
}
