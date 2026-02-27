import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pending_scan.dart';
import 'scan_pipeline_service.dart';

/// Manages the offline scan queue with automatic sync.
///
/// Queue is persisted to shared preferences so pending scans survive restarts.
/// This is a light-weight persistence layer; Isar can replace it later.
class OfflineQueueService {
  OfflineQueueService._();

  static const _storageKey = 'offline_pending_scans_v1';

  static final List<PendingScan> _queue = [];
  static Timer? _syncTimer;
  static bool _isSyncing = false;
  static StreamSubscription? _connectivitySubscription;

  /// The function used to upload a scan.
  /// Defaults to [ScanPipelineService.uploadScan].
  /// Can be overridden for testing.
  @visibleForTesting
  static Future<String> Function(PendingScan) uploadCallback =
      ScanPipelineService.uploadScan;

  /// Clears the queue.
  /// Only for testing purposes.
  @visibleForTesting
  static Future<void> clearQueue() async {
    _queue.clear();
    await _persistQueue();
  }

  /// Add a scan to the offline queue.
  static Future<void> enqueue(PendingScan scan) async {
    _queue.add(scan);
    await _persistQueue();
    debugPrint('Scan queued: ${scan.clientScanId} (queue size: ${_queue.length})');
    _attemptSync();
  }

  /// Get current queue size.
  static int get queueSize => _queue.length;

  /// Get pending scans.
  static List<PendingScan> get pendingScans =>
      List.unmodifiable(_queue.where(
        (s) =>
            s.syncStatus == SyncStatus.pendingUpload ||
            s.syncStatus == SyncStatus.failed,
      ));

  /// Initialize the offline queue service.
  /// Loads persisted queue, sets up connectivity monitoring and periodic sync.
  static Future<void> initialize() async {
    await _loadPersistedQueue();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        _attemptSync();
      }
    });

    _syncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _attemptSync(),
    );

    _attemptSync();
  }

  /// Dispose resources.
  static void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
  }

  static Future<void> _loadPersistedQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      _queue
        ..clear()
        ..addAll(decoded
            .whereType<Map>()
            .map((entry) => PendingScan.fromJson(Map<String, dynamic>.from(entry))));
    } catch (e) {
      debugPrint('Failed to load offline queue: $e');
    }
  }

  static Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_queue.map((scan) => scan.toJson()).toList());
      await prefs.setString(_storageKey, raw);
    } catch (e) {
      debugPrint('Failed to persist offline queue: $e');
    }
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
        if (scan.lastAttempt != null) {
          final elapsed = DateTime.now().difference(scan.lastAttempt!);
          if (elapsed < scan.nextRetryDelay) return;
        }

        try {
          scan.syncStatus = SyncStatus.uploading;
          scan.lastAttempt = DateTime.now();
          await _persistQueue();

          await uploadCallback(scan);

          scan.syncStatus = SyncStatus.uploaded;
          scan.lastError = null;
          debugPrint('Scan uploaded: ${scan.clientScanId}');
        } catch (e) {
          scan.syncStatus = SyncStatus.failed;
          scan.retryCount++;
          scan.lastError = e.toString();
          debugPrint('Scan upload failed: ${scan.clientScanId} '
              '(attempt ${scan.retryCount}). Error type: ${e.runtimeType}');
        } finally {
          await _persistQueue();
        }
      }));
    } finally {
      _isSyncing = false;
    }
  }

  /// Force sync all pending scans (user-triggered).
  static Future<void> forceSync() async {
    for (final scan in _queue) {
      if (scan.syncStatus == SyncStatus.failed) {
        scan.lastAttempt = null;
      }
    }
    await _persistQueue();
    await _attemptSync();
  }

  /// Remove uploaded scans from queue.
  static Future<void> cleanup() async {
    _queue.removeWhere((s) => s.syncStatus == SyncStatus.uploaded);
    await _persistQueue();
  }
}
