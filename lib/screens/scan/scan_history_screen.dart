import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../config/theme.dart';
import '../../models/scan.dart';
import '../../providers/scan_provider.dart';
import '../../widgets/health_score_indicator.dart';
import '../../widgets/confidence_chip.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/glassmorphic_card.dart';

class ScanHistoryScreen extends ConsumerWidget {
  final String? plantId;

  const ScanHistoryScreen({super.key, this.plantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scansAsync = plantId != null
        ? ref.watch(plantScansProvider(plantId!))
        : ref.watch(allScansProvider);

    return AmbientBackground(
      child: Scaffold(
        appBar: AppBar(
          title: Text(plantId != null ? 'Plant Scan History' : 'All Scans'),
        ),
        body: scansAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: $e'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (plantId != null) {
                      ref.invalidate(plantScansProvider(plantId!));
                    } else {
                      ref.invalidate(allScansProvider);
                    }
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (scans) {
            if (scans.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GlassmorphicCard(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.document_scanner_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No scans yet',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Scan a plant to get AI-powered diagnostics',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                if (plantId != null) {
                  ref.invalidate(plantScansProvider(plantId!));
                } else {
                  ref.invalidate(allScansProvider);
                }
              },
              child: AnimationLimiter(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: scans.length,
                  itemBuilder: (context, index) {
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 500),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          child: _ScanHistoryCard(scan: scans[index]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScanHistoryCard extends StatelessWidget {
  final Scan scan;

  const _ScanHistoryCard({required this.scan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassmorphicCard(
        padding: EdgeInsets.zero, // Reset padding for InkWell
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/diagnosis/${scan.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    HealthScoreIndicator(score: scan.healthScore, size: 56),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scan.diagnosisLocalized ??
                                scan.diagnosisCode ??
                                _getStatusLabel(scan.processingStatus),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDateTime(scan.capturedAtUtc),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (scan.diagnosisConfidence != null) ...[
                                ConfidenceChip(
                                  level: scan.confidenceLevel,
                                  score: scan.diagnosisConfidence,
                                ),
                                const SizedBox(width: 8),
                              ],
                              _StatusIndicator(status: scan.processingStatus),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
                // Telemetry summary bar
                if (scan.isComplete) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _TelemetryMini(
                        icon: Icons.thermostat,
                        value: scan.tempC != null
                            ? '${scan.tempC!.toStringAsFixed(1)}°C'
                            : '--',
                      ),
                      _TelemetryMini(
                        icon: Icons.water_drop,
                        value: scan.humidityPct != null
                            ? '${scan.humidityPct!.toInt()}%'
                            : '--',
                      ),
                      _TelemetryMini(
                        icon: Icons.light_mode,
                        value: scan.luxReading != null
                            ? '${scan.luxReading!.toInt()} lux'
                            : '--',
                      ),
                      _TelemetryMini(
                        icon: Icons.air,
                        value: scan.aqi != null ? 'AQI ${scan.aqi}' : '--',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusLabel(ProcessingStatus status) {
    switch (status) {
      case ProcessingStatus.queued:
        return 'Queued...';
      case ProcessingStatus.enriching:
        return 'Enriching data...';
      case ProcessingStatus.diagnosing:
        return 'Analyzing...';
      case ProcessingStatus.completed:
        return 'Complete';
      case ProcessingStatus.failed:
        return 'Failed';
    }
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _StatusIndicator extends StatelessWidget {
  final ProcessingStatus status;

  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case ProcessingStatus.completed:
        color = AppTheme.confidenceHigh;
        label = 'Done';
      case ProcessingStatus.failed:
        color = AppTheme.errorRed;
        label = 'Failed';
      case ProcessingStatus.queued:
      case ProcessingStatus.enriching:
      case ProcessingStatus.diagnosing:
        color = AppTheme.infoBlue;
        label = 'Processing';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TelemetryMini extends StatelessWidget {
  final IconData icon;
  final String value;

  const _TelemetryMini({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
