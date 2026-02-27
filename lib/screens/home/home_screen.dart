import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../l10n/app_localizations.dart';

import '../../config/theme.dart';
import '../../models/plant.dart';
import '../../providers/plant_provider.dart';
import '../../providers/scan_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/glassmorphic_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final plantsAsync = ref.watch(plantsProvider);
    final queueSize = ref.watch(offlineQueueSizeProvider);

    return AmbientBackground(
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.eco, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text(l10n.appTitle),
            ],
          ),
          actions: [
            if (queueSize > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GlassmorphicCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  borderRadius: 20,
                  backgroundColor: AppTheme.warningAmber.withValues(alpha: 0.2),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_upload, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '$queueSize',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
        body: plantsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading plants:\n$error',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(plantsProvider),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
          data: (plants) {
            if (plants.isEmpty) {
              return _buildEmptyState(context, l10n);
            }
            return _buildPlantList(context, ref, plants, l10n);
          },
        ),
        floatingActionButton: ScaleTransition(
          scale: const AlwaysStoppedAnimation(1.0), // Can animate this later
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/plant/add'),
            icon: const Icon(Icons.add),
            label: Text(l10n.addPlant),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassmorphicCard(
          padding: const EdgeInsets.all(32),
          blur: 24,
          backgroundColor: Colors.white.withValues(alpha: 0.22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_florist,
                  size: 64,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.welcomeTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.welcomeSubtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black54,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => context.push('/plant/add'),
                icon: const Icon(Icons.add),
                label: Text(l10n.addPlant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlantList(
      BuildContext context, WidgetRef ref, List<Plant> plants, AppLocalizations l10n) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(plantsProvider),
      child: AnimationLimiter(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: plants.length,
          itemBuilder: (context, index) {
            final plant = plants[index];
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 600),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: _PlantCard(plant: plant, l10n: l10n),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PlantCard extends StatelessWidget {
  final Plant plant;
  final AppLocalizations l10n;

  const _PlantCard({required this.plant, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassmorphicCard(
        padding: EdgeInsets.zero, // Reset padding for InkWell
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/plant/${plant.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Plant avatar
                Hero(
                  tag: 'plant-icon-${plant.id}',
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryGreen.withValues(alpha: 0.8),
                          AppTheme.accentTeal.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.eco,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Plant info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plant.nickname,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                      ),
                      if (plant.speciesCommon != null ||
                          plant.speciesScientific != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          plant.speciesCommon ??
                              plant.speciesScientific ??
                              '',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _getLocationIcon(
                                plant.environmentProfile.locationType),
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatLocationType(
                                plant.environmentProfile.locationType),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Scan action
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.document_scanner_outlined),
                    color: AppTheme.primaryGreen,
                    onPressed: () =>
                        context.push('/scan?plantId=${plant.id}'),
                    tooltip: l10n.scanPlant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getLocationIcon(String locationType) {
    switch (locationType) {
      case 'indoor':
        return Icons.home;
      case 'outdoor_balcony':
        return Icons.balcony;
      case 'outdoor_garden':
        return Icons.park;
      case 'greenhouse':
        return Icons.house_siding;
      default:
        return Icons.location_on;
    }
  }

  String _formatLocationType(String locationType) {
    switch (locationType) {
      case 'indoor':
        return 'Indoor';
      case 'outdoor_balcony':
        return 'Balcony';
      case 'outdoor_garden':
        return 'Garden';
      case 'greenhouse':
        return 'Greenhouse';
      default:
        return 'Unknown';
    }
  }
}
