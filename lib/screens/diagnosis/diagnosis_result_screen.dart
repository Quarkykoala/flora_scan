import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/scan.dart';
import '../../models/diagnosis_feedback.dart';
import '../../providers/scan_provider.dart';
import '../../providers/feedback_provider.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/health_score_indicator.dart';
import '../../widgets/confidence_chip.dart';
import '../../widgets/context_chip.dart';

class DiagnosisResultScreen extends ConsumerStatefulWidget {
  final String scanId;

  const DiagnosisResultScreen({super.key, required this.scanId});

  @override
  ConsumerState<DiagnosisResultScreen> createState() =>
      _DiagnosisResultScreenState();
}

class _DiagnosisResultScreenState extends ConsumerState<DiagnosisResultScreen> {
  bool _feedbackSubmitted = false;

  @override
  Widget build(BuildContext context) {
    final scanAsync = ref.watch(scanDetailProvider(widget.scanId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnosis'),
      ),
      body: scanAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (scan) {
          if (scan == null) {
            return const Center(child: Text('Scan not found'));
          }

          // If still processing, show loading state with auto-refresh
          if (scan.isProcessing) {
            return _buildProcessingState(context, scan);
          }

          return _buildResults(context, scan);
        },
      ),
    );
  }

  Widget _buildProcessingState(BuildContext context, Scan scan) {
    // Auto-refresh every 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        ref.invalidate(scanDetailProvider(widget.scanId));
      }
    });

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                color: AppTheme.primaryGreen,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _getProcessingMessage(scan.processingStatus),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This usually takes a few seconds...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _getProcessingMessage(ProcessingStatus status) {
    switch (status) {
      case ProcessingStatus.queued:
        return 'Queued for analysis...';
      case ProcessingStatus.enriching:
        return 'Gathering environmental data...';
      case ProcessingStatus.diagnosing:
        return 'AI is analyzing your plant...';
      default:
        return 'Processing...';
    }
  }

  Widget _buildResults(BuildContext context, Scan scan) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main diagnosis card
          _buildDiagnosisCard(context, scan),
          const SizedBox(height: 16),

          // Telemetry context chips
          _buildTelemetrySection(context, scan),
          const SizedBox(height: 16),

          // Treatment card
          if (scan.treatmentLocalized != null)
            _buildTreatmentCard(context, scan),
          if (scan.treatmentLocalized != null) const SizedBox(height: 16),

          // Visual symptoms
          if (scan.visualSymptoms != null && scan.visualSymptoms!.isNotEmpty)
            _buildSymptomsSection(context, scan),
          if (scan.visualSymptoms != null && scan.visualSymptoms!.isNotEmpty)
            const SizedBox(height: 16),

          // Image quality warning
          if (scan.imageQualityScore != null && scan.imageQualityScore! < 0.4)
            _buildQualityWarning(context, scan),

          // Feedback section
          _buildFeedbackSection(context, scan),
          const SizedBox(height: 16),

          // Processing metadata
          _buildMetadataSection(context, scan),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDiagnosisCard(BuildContext context, Scan scan) {
    return GlassmorphicCard(
      child: Column(
        children: [
          Row(
            children: [
              HealthScoreIndicator(score: scan.healthScore),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (scan.diagnosisLocalized != null)
                      Text(
                        scan.diagnosisLocalized!,
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    if (scan.diagnosisCode != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        scan.diagnosisCode!,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade500,
                                  fontFamily: 'monospace',
                                ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ConfidenceChip(
                      level: scan.confidenceLevel,
                      score: scan.diagnosisConfidence,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (scan.isFailed) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppTheme.errorRed, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      scan.processingError ?? 'Analysis failed',
                      style: const TextStyle(
                        color: AppTheme.errorRed,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTelemetrySection(BuildContext context, Scan scan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Environmental Context',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ContextChip.temperature(scan.tempC),
            ContextChip.humidity(scan.humidityPct),
            ContextChip.lux(scan.luxReading, scan.luxSource),
            ContextChip.aqi(scan.aqi),
            if (scan.vpdKpa != null)
              ContextChip(
                label: 'VPD ${scan.vpdKpa!.toStringAsFixed(2)} kPa',
                icon: Icons.speed,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTreatmentCard(BuildContext context, Scan scan) {
    return Card(
      color: AppTheme.primaryGreen.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.healing, color: AppTheme.primaryGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Recommended Treatment',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              scan.treatmentLocalized!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomsSection(BuildContext context, Scan scan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visual Symptoms',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: scan.visualSymptoms!.map((symptom) {
            return Chip(
              label: Text(symptom, style: const TextStyle(fontSize: 12)),
              backgroundColor:
                  AppTheme.warningAmber.withValues(alpha: 0.1),
              side: BorderSide(
                color: AppTheme.warningAmber.withValues(alpha: 0.3),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQualityWarning(BuildContext context, Scan scan) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.warningAmber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.warningAmber.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.photo_camera,
              color: AppTheme.warningAmber, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Low photo quality detected. For better results, ensure good lighting and hold the camera steady.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection(BuildContext context, Scan scan) {
    if (_feedbackSubmitted) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              const Text('Thank you for your feedback!'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Was this diagnosis helpful?',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _submitFeedback(
                        scan.id, FeedbackType.helpful),
                    icon: const Icon(Icons.thumb_up_outlined, size: 18),
                    label: const Text('Helpful'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _submitFeedback(
                        scan.id, FeedbackType.notHelpful),
                    icon: const Icon(Icons.thumb_down_outlined, size: 18),
                    label: const Text('Not Helpful'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _submitFeedback(
                        scan.id, FeedbackType.wrongDiagnosis),
                    icon: const Icon(Icons.error_outline, size: 18),
                    label: const Text('Wrong'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitFeedback(String scanId, FeedbackType type) async {
    await ref.read(feedbackNotifierProvider.notifier).submitFeedback(
          scanId: scanId,
          feedbackType: type,
        );
    setState(() => _feedbackSubmitted = true);
  }

  Widget _buildMetadataSection(BuildContext context, Scan scan) {
    return ExpansionTile(
      title: const Text('Processing Details'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        _metadataRow('Model', scan.aiModelName ?? 'N/A'),
        _metadataRow('Model Version', scan.aiModelVersion ?? 'N/A'),
        _metadataRow('Prompt Version', scan.promptVersion ?? 'N/A'),
        _metadataRow('Image Quality',
            scan.imageQualityScore?.toStringAsFixed(2) ?? 'N/A'),
        _metadataRow('Telemetry Score',
            scan.telemetryCompletenessScore?.toStringAsFixed(2) ?? 'N/A'),
        _metadataRow('Status', scan.processingStatus.name),
        _metadataRow('Captured', scan.capturedAtUtc.toIso8601String()),
      ],
    );
  }

  Widget _metadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
