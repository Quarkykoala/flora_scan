import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/plant_provider.dart';
import '../../providers/scan_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/haptics.dart';
import '../../widgets/radar_sweep_overlay.dart';

class ScanScreen extends ConsumerStatefulWidget {
  final String? plantId;

  const ScanScreen({super.key, this.plantId});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isCapturing = false;
  bool _requestDeepAnalysis = true;
  bool _paywallViewedForThisSession = false;
  String? _cameraErrorMessage;
  String? _selectedPlantId;
  List<CameraDescription> _cameras = [];

  @override
  void initState() {
    super.initState();
    _selectedPlantId = widget.plantId;
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _cameraErrorMessage = null;
      _isCameraReady = false;
    });
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _cameraErrorMessage = 'No camera found on this device/browser.';
        });
        return;
      }

      _cameraController = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraErrorMessage =
              'Camera access is unavailable. Grant camera permission and try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureAndScan() async {
    if (_isCapturing || _cameraController == null || !_isCameraReady) return;
    if (_selectedPlantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a plant first')),
      );
      return;
    }

    setState(() => _isCapturing = true);

    try {
      await AppHaptics.scanButtonPress();

      final image = await _cameraController!.takePicture();
      final pipeline = ref.read(scanPipelineProvider.notifier);
      final scanId = await pipeline.executeScan(
        imagePath: image.path,
        plantId: _selectedPlantId!,
      );

      if (scanId != null && mounted) {
        final profile = ref.read(userProfileProvider).valueOrNull;
        final isPremium = ref.read(isPremiumProvider);
        if (_requestDeepAnalysis && !isPremium) {
          final now = DateTime.now().toUtc();
          final lastShown = profile?.paywallLastShownAtUtc;
          final shouldShowPaywall = !_paywallViewedForThisSession ||
              lastShown == null ||
              now.difference(lastShown).inHours >= 6;

          await _showTeaserBottomSheet();

          if (shouldShowPaywall) {
            _paywallViewedForThisSession = true;
            await AnalyticsService.track(
              'paywall_viewed',
              context: {
                'scan_id': scanId,
                'plant_id': _selectedPlantId,
                'surface': 'scan_deep_analysis',
              },
            );
            final userId = SupabaseService.currentUserId;
            if (userId != null) {
              await SupabaseService.updateUserProfile(userId, {
                'paywall_last_shown_at_utc': now.toIso8601String(),
              });
            }
            await _showPaywallBottomSheet(scanId: scanId);
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Basic scan saved. Upgrade to unlock deep AI diagnosis.'),
            ),
          );
          return;
        }

        if (_requestDeepAnalysis) {
          context.push('/diagnosis/$scanId');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Basic telemetry scan saved successfully.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pipelineState = ref.watch(scanPipelineProvider);
    final plantsAsync = ref.watch(plantsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFCADAC6),
      body: Stack(
        children: [
          if (_isCameraReady && _cameraController != null)
            Positioned.fill(child: CameraPreview(_cameraController!))
          else if (_cameraErrorMessage != null)
            Center(
              child: Text(
                _cameraErrorMessage!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          Positioned(
            top: 12,
            left: 14,
            right: 14,
            child: SafeArea(
              child: _Frost(
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                          return;
                        }
                        context.go('/');
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'Scan Plant',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
            ),
          ),

          if (pipelineState == ScanPipelineState.capturing ||
              pipelineState == ScanPipelineState.uploading ||
              pipelineState == ScanPipelineState.processing)
            Center(
              child: RadarSweepOverlay(
                isActive: true,
                size: MediaQuery.of(context).size.width * 0.74,
              ),
            ),

          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  plantsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (plants) {
                      if (plants.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _Frost(
                          borderRadius: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedPlantId,
                              hint: const Text('Select plant'),
                              isExpanded: true,
                              items: plants.map((plant) {
                                return DropdownMenuItem(
                                  value: plant.id,
                                  child: Text(plant.nickname),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedPlantId = value);
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  GestureDetector(
                    onTap: (_isCapturing || !_isCameraReady) ? null : _captureAndScan,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_isCapturing || !_isCameraReady)
                            ? Colors.grey.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.34),
                        border: Border.all(color: Colors.white, width: 6),
                      ),
                      child: Center(
                        child: Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_isCapturing || !_isCameraReady)
                                ? Colors.grey.shade400
                                : Colors.white.withValues(alpha: 0.8),
                          ),
                          child: _isCapturing
                              ? const SizedBox()
                              : const Icon(Icons.camera_alt, color: Colors.black45, size: 48),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Frost(
                    borderRadius: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppTheme.primaryGreen,
                      title: const Text(
                        'Deep AI Analysis',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: const Text(
                        'Detailed diagnosis + treatment plan',
                        style: TextStyle(color: Colors.white70),
                      ),
                      value: _requestDeepAnalysis,
                      onChanged: (value) {
                        setState(() => _requestDeepAnalysis = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaywallBottomSheet({required String scanId}) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _Frost(
          borderRadius: 24,
          color: Colors.black.withValues(alpha: 0.62),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unlock Deep Analysis',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Premium includes full AI diagnostics, treatment intelligence, and real-time assistant chat.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                child: const Text(
                  r'Premium Annual: $29.99/year',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await AnalyticsService.track(
                      'paywall_cta_tapped',
                      context: {
                        'scan_id': scanId,
                        'surface': 'scan_paywall',
                        'plan': 'annual_29_99',
                      },
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Upgrade to Premium'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showTeaserBottomSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _Frost(
          borderRadius: 20,
          color: Colors.black.withValues(alpha: 0.55),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Diagnosis Preview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'We detected possible stress patterns in the leaves.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text(
                'Full treatment plan and recovery intelligence are available on Premium.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Frost extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;

  const _Frost({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.50), width: 1.1),
          ),
          child: child,
        ),
      ),
    );
  }
}
