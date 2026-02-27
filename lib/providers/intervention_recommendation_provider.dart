import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/intervention_recommendation.dart';
import '../services/supabase_service.dart';

/// Provides recommendations for a scan.
final scanInterventionRecommendationsProvider = FutureProvider.autoDispose
    .family<List<InterventionRecommendation>, String>((ref, scanId) async {
  final data = await SupabaseService.getInterventionRecommendationsForScan(
    scanId,
  );
  return data.map((json) => InterventionRecommendation.fromJson(json)).toList();
});

/// Provides recommendations for a plant.
final plantInterventionRecommendationsProvider = FutureProvider.autoDispose
    .family<List<InterventionRecommendation>, String>((ref, plantId) async {
  final data = await SupabaseService.getInterventionRecommendationsForPlant(
    plantId,
  );
  return data.map((json) => InterventionRecommendation.fromJson(json)).toList();
});
