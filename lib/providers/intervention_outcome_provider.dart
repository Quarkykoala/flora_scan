import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/intervention_outcome.dart';
import '../services/supabase_service.dart';

/// Provides outcomes for a given intervention.
final interventionOutcomesProvider = FutureProvider.autoDispose
    .family<List<InterventionOutcome>, String>((ref, interventionId) async {
  final data = await SupabaseService.getInterventionOutcomesForIntervention(
    interventionId,
  );
  return data.map((json) => InterventionOutcome.fromJson(json)).toList();
});

/// Provides outcomes for a plant.
final plantInterventionOutcomesProvider = FutureProvider.autoDispose
    .family<List<InterventionOutcome>, String>((ref, plantId) async {
  final data = await SupabaseService.getInterventionOutcomesForPlant(plantId);
  return data.map((json) => InterventionOutcome.fromJson(json)).toList();
});

/// Outcome actions notifier.
class InterventionOutcomeNotifier extends StateNotifier<AsyncValue<void>> {
  InterventionOutcomeNotifier() : super(const AsyncValue.data(null));

  Future<void> submitOutcome({
    required String interventionId,
    AdherenceStatus adherenceStatus = AdherenceStatus.unknown,
    OutcomeStatus outcomeStatus = OutcomeStatus.uncertain,
    String? adherenceNotes,
    String? outcomeNotes,
    double? outcomeConfidence,
    String? followupScanId,
    double? followupImageQualityScore,
  }) async {
    final normalizedAdherenceNotes = _normalizeOptionalText(adherenceNotes);
    final normalizedOutcomeNotes = _normalizeOptionalText(outcomeNotes);
    final normalizedOutcomeConfidence = _normalizeOptionalConfidence(outcomeConfidence);

    state = const AsyncValue.loading();
    try {
      await SupabaseService.submitInterventionOutcome(
        interventionId: interventionId,
        adherenceStatus: adherenceStatus.apiValue,
        outcomeStatus: outcomeStatus.name,
        adherenceNotes: normalizedAdherenceNotes,
        outcomeNotes: normalizedOutcomeNotes,
        outcomeConfidence: normalizedOutcomeConfidence,
        followupScanId: followupScanId,
        followupImageQualityScore: followupImageQualityScore,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  String? _normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  double? _normalizeOptionalConfidence(double? value) {
    if (value == null || !value.isFinite) {
      return null;
    }
    return value.clamp(0.0, 1.0).toDouble();
  }
}

final interventionOutcomeNotifierProvider =
    StateNotifierProvider<InterventionOutcomeNotifier, AsyncValue<void>>((ref) {
  return InterventionOutcomeNotifier();
});
