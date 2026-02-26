import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/scan.dart';
import '../../providers/scan_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/health_score_indicator.dart';
import '../../widgets/confidence_chip.dart';

class DiagnosisResultScreen extends ConsumerWidget {
  final String scanId;

  const DiagnosisResultScreen({super.key, required this.scanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanAsync = ref.watch(scanDetailProvider(scanId));

    return AmbientBackground(
      mood: _getMoodForScan(scanAsync.valueOrNull),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analysis Result'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: scanAsync.when(
          loading: () => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Analyzing plant data...'),
              ],
            ),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading result: $e'),
              ],
            ),
          ),
          data: (scan) {
            if (scan == null) {
              return const Center(child: Text('Scan not found'));
            }
            return _buildResultContent(context, scan);
          },
        ),
      ),
    );
  }

  AmbientMood _getMoodForScan(Scan? scan) {
    if (scan == null) return AmbientMood.calm;
    if (scan.healthScore != null && scan.healthScore! < 50) return AmbientMood.rainy;
    if (scan.luxReading != null && scan.luxReading! < 100) return AmbientMood.night;
    return AmbientMood.sunny;
  }

  Widget _buildResultContent(BuildContext context, Scan scan) {
    return AnimationLimiter(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 600),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: widget,
              ),
            ),
            children: [
              // 1. Hero Health Score
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Hero(
                    tag: 'health-score-${scan.id}',
                    child: HealthScoreIndicator(
                      score: scan.healthScore,
                      size: 160,
                    ),
                  ),
                ),
              ),

              // 2. Main Diagnosis Card
              GlassmorphicCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      scan.diagnosisLocalized ?? 'Analyzing...',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (scan.confidenceLevel != null)
                      ConfidenceChip(
                        level: scan.confidenceLevel,
                        score: scan.diagnosisConfidence,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      scan.processingStatus == ProcessingStatus.completed
                          ? (scan.treatmentLocalized ?? 'No treatment recommendations available.')
                          : 'Processing your scan. Please wait...',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.black54,
                            height: 1.5,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Telemetry Grid
              if (scan.isComplete) ...[
                Row(
                  children: [
                    Expanded(
                      child: _TelemetryCard(
                        icon: Icons.thermostat,
                        value: scan.tempC != null
                            ? '${scan.tempC!.toStringAsFixed(1)}°C'
                            : '--',
                        label: 'Temperature',
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TelemetryCard(
                        icon: Icons.water_drop,
                        value: scan.humidityPct != null
                            ? '${scan.humidityPct!.toInt()}%'
                            : '--',
                        label: 'Humidity',
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TelemetryCard(
                        icon: Icons.light_mode,
                        value: scan.luxReading != null
                            ? '${scan.luxReading!.toInt()} lux'
                            : '--',
                        label: 'Light',
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TelemetryCard(
                        icon: Icons.air,
                        value: scan.aqi != null ? '${scan.aqi}' : '--',
                        label: 'Air Quality',
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // 4. Visual Symptoms
              if (scan.visualSymptoms != null && scan.visualSymptoms!.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Detected Symptoms',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                GlassmorphicCard(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: scan.visualSymptoms!.map((symptom) {
                      return Chip(
                        label: Text(symptom),
                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        labelStyle: const TextStyle(color: AppTheme.primaryGreen),
                        side: BorderSide.none,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _TelemetryCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
