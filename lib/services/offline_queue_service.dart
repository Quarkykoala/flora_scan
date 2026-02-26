import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/pending_scan.dart';
import 'scan_pipeline_service.dart';

/// Manages the offline scan queue with automatic sync.
///
/// Uses an in-memory queue (production would use Isar for persistence).
/// Implements exponential backoff retry and connectivity awareness.
class OfflineQueueService {
  OfflineQueueService._();

  static final List<PendingScan> _queue = [];
  static Timer? _syncTimer;
  static bool _isSyncing = false;
  static StreamSubscription? _connectivitySubscription;

  /// Add a scan to the offline queue.
  static void enqueue(PendingScan scan) {
    _queue.add(scan);
    debugPrint('Scan queued: ${scan.clientScanId} '
        '(queue size: ${_queue.length})');
    // Attempt immediate sync
    _attemptSync();
  }

  /// Get current queue size.
  static int get queueSize => _queue.length;

  /// Get pending scans.
  static List<PendingScan> get pendingScans =>
      List.unmodifiable(_queue.where(
        (s) => s.syncStatus == SyncStatus.pendingUpload ||
            s.syncStatus == SyncStatus.failed,
      ));

  /// Initialize the offline queue service.
  /// Sets up connectivity monitoring and periodic sync.
  static void initialize() {
    // Monitor connectivity changes
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((results) {
      final hasConnection = results.any(
        (r) => r != ConnectivityResult.none,
      );
      if (hasConnection) {
        _attemptSync();
      }
    });

    // Periodic sync every 30 seconds
    _syncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _attemptSync(),
    );
  }

  /// Dispose resources.
  static void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
  }

  /// Attempt to sync all pending scans.
  static Future<void> _attemptSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pending = _queue.where(
        (s) =>
            (s.syncStatus == SyncStatus.pendingUpload ||
                s.syncStatus == SyncStatus.failed) &&
            s.canRetry,
      ).toList();

      await Future.wait(pending.map((scan) async {
        // Check if retry delay has elapsed
        if (scan.lastAttempt != null) {
          final elapsed = DateTime.now().difference(scan.lastAttempt!);
          if (elapsed < scan.nextRetryDelay) return;
        }

        try {
          scan.syncStatus = SyncStatus.uploading;
          scan.lastAttempt = DateTime.now();

          await ScanPipelineService.uploadScan(scan);

          scan.syncStatus = SyncStatus.uploaded;
          debugPrint('Scan uploaded: ${scan.clientScanId}');
        } catch (e) {
          scan.syncStatus = SyncStatus.failed;
          scan.retryCount++;
          scan.lastError = e.toString();
          debugPrint('Scan upload failed: ${scan.clientScanId} '
              '(attempt ${scan.retryCount}): $e');
        }
      }));
    } finally {
      _isSyncing = false;
    }
  }

  /// Force sync all pending scans (user-triggered).
  static Future<void> forceSync() async {
    // Reset retry delays for user-triggered sync
    for (final scan in _queue) {
      if (scan.syncStatus == SyncStatus.failed) {
        scan.lastAttempt = null;
      }
    }
    await _attemptSync();
  }

  /// Remove uploaded scans from queue.
  static void cleanup() {
    _queue.removeWhere((s) => s.syncStatus == SyncStatus.uploaded);
  }
}
