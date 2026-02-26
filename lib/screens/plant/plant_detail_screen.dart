import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../config/theme.dart';
import '../../models/plant.dart';
import '../../models/care_event.dart';
import '../../models/scan.dart';
import '../../providers/plant_provider.dart';
import '../../providers/scan_provider.dart';
import '../../providers/care_event_provider.dart';
import '../../utils/haptics.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/health_score_indicator.dart';
import '../../widgets/ambient_background.dart';

class PlantDetailScreen extends ConsumerWidget {
  final String plantId;

  const PlantDetailScreen({super.key, required this.plantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plantAsync = ref.watch(plantDetailProvider(plantId));
    final scansAsync = ref.watch(plantScansProvider(plantId));
    final careEventsAsync = ref.watch(careEventsProvider(plantId));

    return AmbientBackground(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Plant Details'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                // Navigate to edit — reuses AddPlantScreen with plantId
              },
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'archive') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Archive Plant'),
                      content: const Text(
                          'Are you sure you want to archive this plant?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Archive'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref
                        .read(plantNotifierProvider.notifier)
                        .archivePlant(plantId);
                    if (context.mounted) context.go('/');
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'archive',
                  child: Row(
                    children: [
                      Icon(Icons.archive_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Archive'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: plantAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (plant) {
            if (plant == null) {
              return const Center(child: Text('Plant not found'));
            }
            return _buildContent(context, ref, plant, scansAsync, careEventsAsync);
          },
        ),
        floatingActionButton: ScaleTransition(
          scale: const AlwaysStoppedAnimation(1.0),
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/scan?plantId=$plantId'),
            icon: const Icon(Icons.document_scanner),
            label: const Text('Scan'),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Plant plant,
    AsyncValue<List<Scan>> scansAsync,
    AsyncValue<List<CareEvent>> careEventsAsync,
  ) {
    return AnimationLimiter(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 600),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 40.0,
              child: FadeInAnimation(
                child: widget,
              ),
            ),
            children: [
              // Plant header card
              GlassmorphicCard(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Hero(
                      tag: 'plant-icon-${plant.id}',
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryGreen, AppTheme.accentTeal],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.eco, color: Colors.white, size: 48),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plant.nickname,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                          ),
                          const SizedBox(height: 4),
                          if (plant.speciesCommon != null)
                            Text(
                              plant.speciesCommon!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Colors.grey.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                          if (plant.speciesScientific != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              plant.speciesScientific!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Environment profile
              _buildEnvironmentSection(context, plant.environmentProfile),
              const SizedBox(height: 24),

              // Latest scan result
              Text(
                'Recent Scans',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              scansAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => Text('Error loading scans: $e'),
                data: (scans) {
                  if (scans.isEmpty) {
                    return GlassmorphicCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.document_scanner_outlined,
                                  size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                'No scans yet',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: scans.take(3).map((scan) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ScanSummaryCard(scan: scan),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/scan-history?plantId=$plantId'),
                  child: const Text('View All Scans'),
                ),
              ),
              const SizedBox(height: 24),

              // Care events section
              Text(
                'Care Log',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              _buildCareActions(context, ref),
              const SizedBox(height: 16),
              careEventsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (events) {
                  if (events.isEmpty) {
                    return GlassmorphicCard(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No care events logged yet',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    );
                  }
                  return GlassmorphicCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: events.take(5).map((event) {
                        return _CareEventTile(event: event);
                      }).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnvironmentSection(
      BuildContext context, EnvironmentProfile profile) {
    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_outlined, size: 20, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text(
                'Environment',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _EnvChip(
                icon: Icons.location_on,
                label: profile.locationType.replaceAll('_', ' '),
              ),
              _EnvChip(
                icon: Icons.light_mode,
                label: profile.lightSource,
              ),
              _EnvChip(
                icon: Icons.yard,
                label: profile.potType,
              ),
              _EnvChip(
                icon: Icons.grass,
                label: profile.soilMix,
              ),
              _EnvChip(
                icon: Icons.wb_sunny,
                label: '${profile.sunExposureBand} sun',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCareActions(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        _CareActionButton(
          icon: Icons.water_drop,
          label: 'Water',
          color: Colors.blue,
          onTap: () => _logCareEvent(ref, CareEventType.watered),
        ),
        const SizedBox(width: 12),
        _CareActionButton(
          icon: Icons.science,
          label: 'Fertilize',
          color: Colors.green,
          onTap: () => _logCareEvent(ref, CareEventType.fertilized),
        ),
        const SizedBox(width: 12),
        _CareActionButton(
          icon: Icons.swap_vert,
          label: 'Repot',
          color: Colors.brown,
          onTap: () => _logCareEvent(ref, CareEventType.repotted),
        ),
        const SizedBox(width: 12),
        _CareActionButton(
          icon: Icons.content_cut,
          label: 'Prune',
          color: Colors.orange,
          onTap: () => _logCareEvent(ref, CareEventType.pruned),
        ),
      ],
    );
  }

  Future<void> _logCareEvent(WidgetRef ref, CareEventType type) async {
    await AppHaptics.selection();
    await ref.read(careEventNotifierProvider.notifier).logEvent(
          plantId: plantId,
          eventType: type,
        );
    ref.invalidate(careEventsProvider(plantId));
  }
}

class _EnvChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EnvChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryGreen),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _CareActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CareActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassmorphicCard(
        padding: EdgeInsets.zero,
        borderRadius: 16,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanSummaryCard extends StatelessWidget {
  final Scan scan;

  const _ScanSummaryCard({required this.scan});

  @override
  Widget build(BuildContext context) {
    return GlassmorphicCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/diagnosis/${scan.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              HealthScoreIndicator(score: scan.healthScore, size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scan.diagnosisLocalized ?? scan.diagnosisCode ?? 'Pending',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(scan.capturedAtUtc),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: scan.processingStatus),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  final ProcessingStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (status) {
      case ProcessingStatus.completed:
        color = AppTheme.confidenceHigh;
        icon = Icons.check_circle;
      case ProcessingStatus.failed:
        color = AppTheme.errorRed;
        icon = Icons.error;
      case ProcessingStatus.queued:
      case ProcessingStatus.enriching:
      case ProcessingStatus.diagnosing:
        color = AppTheme.infoBlue;
        icon = Icons.hourglass_bottom;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _CareEventTile extends StatelessWidget {
  final CareEvent event;

  const _CareEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getColor(event.eventType).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getIcon(event.eventType),
            color: _getColor(event.eventType),
            size: 20,
          ),
        ),
        title: Text(
          event.eventType.name[0].toUpperCase() + event.eventType.name.substring(1),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          _formatDate(event.occurredAtUtc),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  IconData _getIcon(CareEventType type) {
    switch (type) {
      case CareEventType.watered:
        return Icons.water_drop;
      case CareEventType.fertilized:
        return Icons.science;
      case CareEventType.repotted:
        return Icons.swap_vert;
      case CareEventType.pruned:
        return Icons.content_cut;
    }
  }

  Color _getColor(CareEventType type) {
    switch (type) {
      case CareEventType.watered:
        return Colors.blue;
      case CareEventType.fertilized:
        return Colors.green;
      case CareEventType.repotted:
        return Colors.brown;
      case CareEventType.pruned:
        return Colors.orange;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${date.month}/${date.day}/${date.year}';
  }
}
