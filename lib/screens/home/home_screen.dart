import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/plant.dart';
import '../../providers/plant_provider.dart';
import '../../providers/scan_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plantsAsync = ref.watch(plantsProvider);
    final queueSize = ref.watch(offlineQueueSizeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.eco, color: AppTheme.primaryGreen),
            const SizedBox(width: 8),
            const Text('FloraScan'),
          ],
        ),
        actions: [
          if (queueSize > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.cloud_upload, size: 16),
                label: Text('$queueSize pending'),
                backgroundColor: AppTheme.warningAmber.withValues(alpha: 0.2),
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
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (plants) {
          if (plants.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildPlantList(context, ref, plants);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/plant/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Plant'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              'Welcome to FloraScan!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Add your first plant to start scanning and get AI-powered health diagnostics.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.push('/plant/add'),
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Plant'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantList(
      BuildContext context, WidgetRef ref, List<Plant> plants) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(plantsProvider),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: plants.length,
        itemBuilder: (context, index) {
          final plant = plants[index];
          return _PlantCard(plant: plant);
        },
      ),
    );
  }
}

class _PlantCard extends StatelessWidget {
  final Plant plant;

  const _PlantCard({required this.plant});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/plant/${plant.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Plant avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGreen.withValues(alpha: 0.7),
                      AppTheme.accentTeal.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.eco,
                  color: Colors.white,
                  size: 28,
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
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (plant.speciesCommon != null ||
                        plant.speciesScientific != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        plant.speciesCommon ??
                            plant.speciesScientific ??
                            '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _getLocationIcon(
                              plant.environmentProfile.locationType),
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatLocationType(
                              plant.environmentProfile.locationType),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade500,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Scan action
              IconButton(
                icon: const Icon(Icons.document_scanner_outlined),
                color: AppTheme.primaryGreen,
                onPressed: () =>
                    context.push('/scan?plantId=${plant.id}'),
                tooltip: 'Scan plant',
              ),
            ],
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
