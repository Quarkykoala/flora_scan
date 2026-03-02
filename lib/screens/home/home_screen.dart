import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../l10n/app_localizations.dart';
import '../../models/followup_mission.dart';
import '../../models/plant.dart';
import '../../models/scan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/followup_mission_provider.dart';
import '../../providers/plant_provider.dart';
import '../../providers/scan_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final plantsAsync = ref.watch(plantsProvider);
    final scansAsync = ref.watch(allScansProvider);
    final missionsAsync = ref.watch(allFollowupMissionsProvider);
    final queueSize = ref.watch(offlineQueueSizeProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFFE8F2EA),
      appBar: AppBar(
        toolbarHeight: 74,
        centerTitle: true,
        title: Text(
          l10n.appTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A4E2A),
            fontSize: 38,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, size: 32),
            color: const Color(0xFF0A4E2A),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Stack(
        children: [
          const _Backdrop(),
          plantsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                'Error loading plants:\n$error',
                textAlign: TextAlign.center,
              ),
            ),
            data: (plants) {
              if (plants.isEmpty) {
                return _buildEmptyState(context, l10n);
              }
              return _buildPlantList(
                context,
                ref,
                plants,
                l10n,
                scansAsync: scansAsync,
                missionsAsync: missionsAsync,
                isPremium: profile?.isPremium ?? false,
              );
            },
          ),
          if (queueSize > 0)
            Positioned(
              top: 12,
              left: 16,
              child: _FrostBadge(
                icon: Icons.cloud_upload_outlined,
                text: '$queueSize pending',
              ),
            ),
          if (profile != null)
            Positioned(
              top: 12,
              right: 16,
              child: _FrostBadge(
                icon: profile.isPremium ? Icons.workspace_premium : Icons.eco,
                text: profile.isPremium ? 'Premium' : 'Free',
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/plant/add'),
        icon: const Icon(Icons.add),
        label: Text(l10n.addPlant),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: _FrostPanel(
          padding: const EdgeInsets.fromLTRB(34, 36, 34, 36),
          borderRadius: 34,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.eco, size: 86, color: Color(0xFF26A65B)),
              const SizedBox(height: 18),
              Text(
                l10n.welcomeTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 62,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B4D2A),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.welcomeSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 33,
                  height: 1.25,
                  color: Colors.black.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
                  textStyle: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
                ),
                onPressed: () => context.push('/plant/add'),
                icon: const Icon(Icons.add, size: 30),
                label: const Text('Add Plant'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlantList(
    BuildContext context,
    WidgetRef ref,
    List<Plant> plants,
    AppLocalizations l10n,
    {
    required AsyncValue<List<Scan>> scansAsync,
    required AsyncValue<List<FollowupMission>> missionsAsync,
    required bool isPremium,
    }
  ) {
    final now = DateTime.now().toUtc();
    final weekStart = now.subtract(const Duration(days: 7));
    final weeklyScans = scansAsync.valueOrNull
            ?.where((scan) => scan.capturedAtUtc.isAfter(weekStart))
            .length ??
        0;
    final missionList = missionsAsync.valueOrNull ?? const [];
    final pendingMissions = missionList.where((m) => m.status.name == 'pending').length;
    final completedMissions = missionList.where((m) => m.status.name == 'completed').length;
    final completionRate = missionList.isEmpty
        ? 0
        : ((completedMissions / missionList.length) * 100).round();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(plantsProvider);
        ref.invalidate(allScansProvider);
        ref.invalidate(allFollowupMissionsProvider);
      },
      child: AnimationLimiter(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
          itemCount: plants.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _FrostPanel(
                  borderRadius: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPremium ? 'Recovery Intelligence (7d)' : 'Weekly Snapshot (7d)',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF123D28),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _MetricChip(label: 'Scans', value: '$weeklyScans')),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MetricChip(label: 'Pending', value: '$pendingMissions'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MetricChip(label: 'Completion', value: '$completionRate%'),
                          ),
                        ],
                      ),
                      if (!isPremium) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Upgrade to unlock deep diagnosis, assistant chat, and advanced mission analytics.',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }
            final plant = plants[index - 1];
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 550),
              child: SlideAnimation(
                verticalOffset: 38,
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
      padding: const EdgeInsets.only(bottom: 14),
      child: _FrostPanel(
        padding: EdgeInsets.zero,
        borderRadius: 22,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => context.push('/plant/${plant.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2DBA68), Color(0xFF1E8F55)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.eco, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plant.nickname,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF123D28),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plant.speciesCommon ?? plant.speciesScientific ?? 'Plant',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => context.push('/scan?plantId=${plant.id}'),
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Text(l10n.scan),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE9F5EC),
                  Color(0xFFDCEBDC),
                  Color(0xFFCDE2CE),
                ],
              ),
            ),
          ),
          Positioned(
            top: 70,
            left: -50,
            child: _blob(const Color(0x6649B660), 260),
          ),
          Positioned(
            bottom: -80,
            right: -40,
            child: _blob(const Color(0x663C8F4A), 320),
          ),
          Positioned(
            top: 280,
            right: -60,
            child: _blob(const Color(0x4DCFE8C8), 220),
          ),
        ],
      ),
    );
  }

  Widget _blob(Color color, double size) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _FrostPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const _FrostPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.36),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.4),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _FrostBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FrostBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return _FrostPanel(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0B4D2A)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0B4D2A),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF0B4D2A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.65),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
