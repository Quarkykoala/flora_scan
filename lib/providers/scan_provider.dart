import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scan.dart';
import '../services/supabase_service.dart';
import '../services/scan_pipeline_service.dart';
import '../services/offline_queue_service.dart';
import '../utils/haptics.dart';

/// Provides scans for a specific plant.
final plantScansProvider =
    FutureProvider.autoDispose.family<List<Scan>, String>((ref, plantId) async {
  final data = await SupabaseService.getScansForPlant(plantId);
  return data.map((json) => Scan.fromJson(json)).toList();
});

/// Provides all scans for the current user.
final allScansProvider = FutureProvider.autoDispose<List<Scan>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final data = await SupabaseService.getAllScans(userId);
  return data.map((json) => Scan.fromJson(json)).toList();
});

/// Provides a single scan by ID.
final scanDetailProvider =
    FutureProvider.autoDispose.family<Scan?, String>((ref, scanId) async {
  final data = await SupabaseService.getScan(scanId);
  if (data == null) return null;
  return Scan.fromJson(data);
});

/// Provides offline queue size.
final offlineQueueSizeProvider = StateProvider<int>((ref) {
  return OfflineQueueService.queueSize;
});

/// Scan pipeline state.
enum ScanPipelineState {
  idle,
  capturing,
  queued,
  uploading,
  processing,
  completed,
  failed,
}

/// Scan pipeline notifier for managing the scan flow.
class ScanPipelineNotifier extends StateNotifier<ScanPipelineState> {
  ScanPipelineNotifier() : super(ScanPipelineState.idle);

  String? _lastScanId;
  String? _lastError;

  String? get lastScanId => _lastScanId;
  String? get lastError => _lastError;

  /// Execute the full scan pipeline.
  Future<String?> executeScan({
    required String imagePath,
    required String plantId,
  }) async {
    try {
      // Step 1: Local capture
      state = ScanPipelineState.capturing;
      await AppHaptics.scanButtonPress();

      final capture = await ScanPipelineService.captureLocally(
        imagePath: imagePath,
      );

      // Step 2: Queue locally
      state = ScanPipelineState.queued;
      await AppHaptics.uploadAccepted();

      final pending = ScanPipelineService.createPendingScan(
        capture: capture,
        plantId: plantId,
      );

      // Step 3: Attempt upload
      state = ScanPipelineState.uploading;

      try {
        final scanId = await ScanPipelineService.uploadScan(pending);
        _lastScanId = scanId;

        // Step 4: Monitor processing
        state = ScanPipelineState.processing;

        await for (final status
            in ScanPipelineService.pollScanStatus(scanId)) {
          if (status == 'completed') {
            state = ScanPipelineState.completed;
            await AppHaptics.diagnosisReceived();
            return scanId;
          } else if (status == 'failed' || status == 'timeout') {
            state = ScanPipelineState.failed;
            _lastError = 'Processing $status';
            await AppHaptics.warningPattern();
            return scanId; // Still return scanId for partial results
          }
        }

        return scanId;
      } catch (e) {
        // Upload failed — add to offline queue for retry
        await OfflineQueueService.enqueue(pending);
        state = ScanPipelineState.queued;
        _lastError = 'Queued for upload when online';
        return null;
      }
    } catch (e) {
      state = ScanPipelineState.failed;
      _lastError = e.toString();
      await AppHaptics.warningPattern();
      return null;
    }
  }

  /// Reset pipeline state.
  void reset() {
    state = ScanPipelineState.idle;
    _lastScanId = null;
    _lastError = null;
  }
}

final scanPipelineProvider =
    StateNotifierProvider<ScanPipelineNotifier, ScanPipelineState>((ref) {
  return ScanPipelineNotifier();
});
