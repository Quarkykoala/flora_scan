import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/scan_provider.dart';
import '../../providers/plant_provider.dart';
import '../../utils/haptics.dart';
import '../../widgets/radar_sweep_overlay.dart';
import '../../widgets/glassmorphic_card.dart';

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
      debugPrint('Camera initialization failed: $e');
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
        final isPremium = ref.read(isPremiumProvider);

        if (_requestDeepAnalysis && !isPremium) {
          await _showPaywallBottomSheet();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Basic scan saved. Upgrade to unlock deep AI diagnosis.',
              ),
            ),
          );
          return;
        }

        if (_requestDeepAnalysis) {
          context.push('/diagnosis/$scanId');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Basic telemetry scan saved successfully.'),
            ),
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_isCameraReady && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else if (_cameraErrorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _cameraErrorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _initializeCamera,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                      ),
                      child: const Text('Retry', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )
          else
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Initializing camera...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

          // Custom AppBar Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance close button
                  ],
                ),
              ),
            ),
          ),

          // Radar sweep overlay (during processing)
          if (pipelineState == ScanPipelineState.capturing ||
              pipelineState == ScanPipelineState.uploading ||
              pipelineState == ScanPipelineState.processing)
            Center(
              child: RadarSweepOverlay(
                isActive: true,
                size: MediaQuery.of(context).size.width * 0.8,
              ),
            ),

          // Scanner frame overlay
          if (pipelineState == ScanPipelineState.idle)
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.75,
                height: MediaQuery.of(context).size.width * 0.75,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  children: [
                    // Corner markers
                    ..._buildCornerMarkers(),
                  ],
                ),
              ),
            ),

          // Status overlay
          if (pipelineState != ScanPipelineState.idle)
            Positioned(
              bottom: 180,
              left: 0,
              right: 0,
              child: Center(
                child: GlassmorphicCard(
                  borderRadius: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.black.withValues(alpha: 0.4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _getStatusText(pipelineState),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Plant selector
                  plantsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (plants) {
                      if (plants.isEmpty) {
                        return const Text(
                          'No plants added yet',
                          style: TextStyle(color: Colors.white70),
                        );
                      }
                      return GlassmorphicCard(
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPlantId,
                            hint: const Text(
                              'Select plant',
                              style: TextStyle(color: Colors.white70),
                            ),
                            dropdownColor: Colors.grey.shade900,
                            iconEnabledColor: Colors.white,
                            isExpanded: true,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
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
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  GlassmorphicCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    child: SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppTheme.primaryGreen,
                      title: const Text(
                        'Deep AI Analysis',
                        style: TextStyle(color: Colors.white),
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
                  const SizedBox(height: 16),

                  // Capture button
                  GestureDetector(
                    onTap: (_isCapturing || !_isCameraReady) ? null : _captureAndScan,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_isCapturing || !_isCameraReady)
                            ? Colors.grey
                            : Colors.white.withValues(alpha: 0.2), // Glassy ring
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_isCapturing || !_isCameraReady)
                                ? Colors.grey.shade400
                                : Colors.white,
                          ),
                          child: _isCapturing
                              ? const SizedBox()
                              : const Icon(Icons.camera_alt, color: Colors.black54, size: 32),
                        ),
                      ),
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

  List<Widget> _buildCornerMarkers() {
    const markerLength = 24.0;
    const markerWidth = 4.0;
    const color = Colors.white; // Clean white markers

    return [
      // Top-left
      Positioned(
        top: 0, left: 0,
        child: _CornerMarker(
          markerLength: markerLength,
          markerWidth: markerWidth,
          color: color,
          isTop: true,
          isLeft: true,
        ),
      ),
      // Top-right
      Positioned(
        top: 0, right: 0,
        child: _CornerMarker(
          markerLength: markerLength,
          markerWidth: markerWidth,
          color: color,
          isTop: true,
          isLeft: false,
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: 0, left: 0,
        child: _CornerMarker(
          markerLength: markerLength,
          markerWidth: markerWidth,
          color: color,
          isTop: false,
          isLeft: true,
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: 0, right: 0,
        child: _CornerMarker(
          markerLength: markerLength,
          markerWidth: markerWidth,
          color: color,
          isTop: false,
          isLeft: false,
        ),
      ),
    ];
  }

  String _getStatusText(ScanPipelineState state) {
    switch (state) {
      case ScanPipelineState.capturing:
        return 'Capturing telemetry...';
      case ScanPipelineState.queued:
        return 'Queued for upload';
      case ScanPipelineState.uploading:
        return 'Uploading scan...';
      case ScanPipelineState.processing:
        return 'Analyzing plant...';
      case ScanPipelineState.completed:
        return 'Analysis complete!';
      case ScanPipelineState.failed:
        return 'Analysis failed';
      case ScanPipelineState.idle:
        return '';
    }
  }

  Future<void> _showPaywallBottomSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassmorphicCard(
          borderRadius: 24,
          blur: 20,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          backgroundColor: Colors.black.withValues(alpha: 0.65),
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
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Upgrade to Premium'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CornerMarker extends StatelessWidget {
  final double markerLength;
  final double markerWidth;
  final Color color;
  final bool isTop;
  final bool isLeft;

  const _CornerMarker({
    required this.markerLength,
    required this.markerWidth,
    required this.color,
    required this.isTop,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: markerLength,
      height: markerLength,
      child: CustomPaint(
        painter: _CornerPainter(
          color: color,
          strokeWidth: markerWidth,
          isTop: isTop,
          isLeft: isLeft,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final bool isTop;
  final bool isLeft;

  _CornerPainter({
    required this.color,
    required this.strokeWidth,
    required this.isTop,
    required this.isLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();

    // Add slight curve to corners
    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 8);
      path.quadraticBezierTo(0, 0, 8, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width - 8, 0);
      path.quadraticBezierTo(size.width, 0, size.width, 8);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height - 8);
      path.quadraticBezierTo(0, size.height, 8, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width - 8, size.height);
      path.quadraticBezierTo(size.width, size.height, size.width, size.height - 8);
      path.lineTo(size.width, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
