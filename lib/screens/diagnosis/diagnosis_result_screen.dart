import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../models/followup_mission.dart';
import '../../models/intervention_outcome.dart';
import '../../models/intervention_recommendation.dart';
import '../../models/scan.dart';
import '../../providers/followup_mission_provider.dart';
import '../../providers/intervention_outcome_provider.dart';
import '../../providers/intervention_recommendation_provider.dart';
import '../../providers/scan_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/confidence_chip.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/health_score_indicator.dart';

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
            return _buildResultContent(context, ref, scan);
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

  Widget _buildResultContent(BuildContext context, WidgetRef ref, Scan scan) {
    final commerceLinks = _extractCommerceLinks(scan);
    final recommendationsAsync =
        ref.watch(scanInterventionRecommendationsProvider(scan.id));
    final missionsAsync = ref.watch(plantFollowupMissionsProvider(scan.plantId));
    final outcomeState = ref.watch(interventionOutcomeNotifierProvider);
    final outcomeNotifier = ref.read(interventionOutcomeNotifierProvider.notifier);

    return AnimationLimiter(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 600),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 50,
              child: FadeInAnimation(child: widget),
            ),
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Hero(
                    tag: 'health-score-${scan.id}',
                    child: HealthScoreIndicator(score: scan.healthScore, size: 160),
                  ),
                ),
              ),
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
                    ConfidenceChip(
                      level: scan.confidenceLevel,
                      score: scan.diagnosisConfidence,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      scan.processingStatus == ProcessingStatus.completed
                          ? (scan.treatmentLocalized ??
                              'No treatment recommendations available.')
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
              if (scan.isComplete) ...[
                Row(
                  children: [
                    Expanded(
                      child: _TelemetryCard(
                        icon: Icons.thermostat,
                        value: scan.tempC != null
                            ? '${scan.tempC!.toStringAsFixed(1)} C'
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
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recommended Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              recommendationsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
                error: (error, stackTrace) => const GlassmorphicCard(
                  padding: EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Unable to load recommendations right now.'),
                  ),
                ),
                data: (recommendations) {
                  if (recommendations.isEmpty) {
                    return const GlassmorphicCard(
                      padding: EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No recommended actions available yet.'),
                      ),
                    );
                  }

                  return Column(
                    children: recommendations.map((recommendation) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassmorphicCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      recommendation.recommendationLocalized,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  _PriorityBadge(priority: recommendation.priority),
                                ],
                              ),
                              if ((recommendation.recommendationDetailsLocalized ?? '')
                                  .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  recommendation.recommendationDetailsLocalized!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: outcomeState.isLoading
                                          ? null
                                          : () => _showOutcomeBottomSheet(
                                                context: context,
                                                recommendation: recommendation,
                                                onSubmit: (outcomeDraft) async {
                                                  await outcomeNotifier.submitOutcome(
                                                    interventionId: recommendation.id,
                                                    adherenceStatus:
                                                        outcomeDraft.adherenceStatus,
                                                    outcomeStatus:
                                                        outcomeDraft.outcomeStatus,
                                                    adherenceNotes:
                                                        outcomeDraft.notes,
                                                    outcomeNotes: outcomeDraft.notes,
                                                    outcomeConfidence:
                                                        outcomeDraft.outcomeConfidence,
                                                  );
                                                  ref.invalidate(
                                                    plantFollowupMissionsProvider(
                                                      scan.plantId,
                                                    ),
                                                  );
                                                  ref.invalidate(
                                                    scanInterventionRecommendationsProvider(
                                                      scan.id,
                                                    ),
                                                  );
                                                  if (context.mounted) {
                                                    Navigator.of(context).pop();
                                                  }
                                                },
                                              ),
                                      icon: outcomeState.isLoading
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.task_alt),
                                      label: const Text('Log Outcome'),
                                    ),
                                  ),
                                  if (commerceLinks.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppTheme.primaryGreen,
                                        ),
                                        onPressed: () => _openCommerceLink(
                                          context,
                                          commerceLinks.first,
                                        ),
                                        icon: const Icon(Icons.shopping_bag_outlined),
                                        label: const Text('Buy Treatment Now'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Follow-up Missions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              missionsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
                error: (error, stackTrace) => const GlassmorphicCard(
                  padding: EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Unable to load follow-up missions right now.'),
                  ),
                ),
                data: (missions) {
                  final scanMissionIds = recommendationsAsync.valueOrNull
                          ?.map((r) => r.id)
                          .toSet() ??
                      <String>{};
                  final filtered = missions
                      .where((m) => scanMissionIds.contains(m.interventionId))
                      .toList();

                  if (filtered.isEmpty) {
                    return const GlassmorphicCard(
                      padding: EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No follow-up missions scheduled.'),
                      ),
                    );
                  }

                  return Column(
                    children: filtered.map((mission) {
                      final dueDate =
                          DateFormat('MMM d, y').format(mission.dueAtUtc.toLocal());

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassmorphicCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                mission.status == FollowupMissionStatus.completed
                                    ? Icons.check_circle
                                    : Icons.schedule,
                                color: mission.status == FollowupMissionStatus.completed
                                    ? Colors.green
                                    : Colors.blueGrey,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _missionTitle(mission.missionType),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Due: $dueDate'),
                                    const SizedBox(height: 2),
                                    Text('Status: ${_titleCase(mission.status.name)}'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              if (outcomeState.hasError) ...[
                const SizedBox(height: 8),
                Text(
                  '${outcomeState.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOutcomeBottomSheet({
    required BuildContext context,
    required InterventionRecommendation recommendation,
    required Future<void> Function(_OutcomeDraft) onSubmit,
  }) async {
    final notesController = TextEditingController();
    var selectedOutcome = OutcomeStatus.improved;
    var selectedAdherence = AdherenceStatus.fully;
    var includeConfidence = false;
    var confidence = 0.8;

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Capture outcome',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(recommendation.recommendationLocalized),
                    const SizedBox(height: 16),
                    Text(
                      'Adherence',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AdherenceStatus.values.map((status) {
                        return ChoiceChip(
                          label: Text(_titleCase(status.apiValue)),
                          selected: selectedAdherence == status,
                          onSelected: (_) =>
                              setState(() => selectedAdherence = status),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Outcome',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: OutcomeStatus.values.map((status) {
                        return ChoiceChip(
                          label: Text(_titleCase(status.name)),
                          selected: selectedOutcome == status,
                          onSelected: (_) =>
                              setState(() => selectedOutcome = status),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Add confidence score'),
                      subtitle: const Text('Optional value between 0 and 1'),
                      value: includeConfidence,
                      onChanged: (value) =>
                          setState(() => includeConfidence = value),
                    ),
                    if (includeConfidence) ...[
                      Slider(
                        min: 0,
                        max: 1,
                        divisions: 10,
                        label: confidence.toStringAsFixed(1),
                        value: confidence,
                        onChanged: (value) => setState(() => confidence = value),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(confidence.toStringAsFixed(1)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => onSubmit(
                          _OutcomeDraft(
                            adherenceStatus: selectedAdherence,
                            outcomeStatus: selectedOutcome,
                            notes: notesController.text,
                            outcomeConfidence:
                                includeConfidence ? confidence : null,
                          ),
                        ),
                        icon: const Icon(Icons.save),
                        label: const Text('Save outcome'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    notesController.dispose();
  }

  List<_CommerceLink> _extractCommerceLinks(Scan scan) {
    final raw = scan.aiDiagnosisRaw;
    if (raw == null) return const [];
    final treatmentPlan = raw['treatment_plan'];
    if (treatmentPlan is! Map<String, dynamic>) return const [];
    final links = treatmentPlan['commerce_links'];
    if (links is! List) return const [];

    return links
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          final productType = (map['product_type'] as String?)?.trim() ?? '';
          final searchQuery = (map['search_query'] as String?)?.trim() ?? '';
          final template =
              (map['affiliate_url_template'] as String?)?.trim() ??
                  'https://www.amazon.in/s?k={query}';
          if (productType.isEmpty || searchQuery.isEmpty) return null;
          return _CommerceLink(
            productType: productType,
            searchQuery: searchQuery,
            affiliateUrlTemplate: template,
          );
        })
        .whereType<_CommerceLink>()
        .toList();
  }

  Future<void> _openCommerceLink(
    BuildContext context,
    _CommerceLink link,
  ) async {
    final encodedQuery = Uri.encodeQueryComponent(link.searchQuery);
    final url = link.affiliateUrlTemplate.replaceAll('{query}', encodedQuery);
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open treatment link')),
      );
    }
  }
}

String _missionTitle(FollowupMissionType type) {
  switch (type) {
    case FollowupMissionType.checkPhoto:
      return 'Upload follow-up photo';
    case FollowupMissionType.confirmAction:
      return 'Confirm action completed';
    case FollowupMissionType.logOutcome:
      return 'Log outcome check-in';
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final InterventionPriority priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (priority) {
      case InterventionPriority.high:
        color = Colors.red;
      case InterventionPriority.medium:
        color = Colors.orange;
      case InterventionPriority.low:
        color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _titleCase(priority.name),
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class _OutcomeDraft {
  final AdherenceStatus adherenceStatus;
  final OutcomeStatus outcomeStatus;
  final String? notes;
  final double? outcomeConfidence;

  const _OutcomeDraft({
    required this.adherenceStatus,
    required this.outcomeStatus,
    this.notes,
    this.outcomeConfidence,
  });
}

class _CommerceLink {
  final String productType;
  final String searchQuery;
  final String affiliateUrlTemplate;

  const _CommerceLink({
    required this.productType,
    required this.searchQuery,
    required this.affiliateUrlTemplate,
  });
}

String _titleCase(String input) {
  if (input.isEmpty) return input;
  final normalized = input.replaceAll('_', ' ');
  return normalized[0].toUpperCase() + normalized.substring(1);
}
