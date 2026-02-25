import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/plant.dart';
import '../services/supabase_service.dart';

/// Provides the list of user's plants.
final plantsProvider = FutureProvider.autoDispose<List<Plant>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final data = await SupabaseService.getPlants(userId);
  return data.map((json) => Plant.fromJson(json)).toList();
});

/// Provides a single plant by ID.
final plantDetailProvider =
    FutureProvider.autoDispose.family<Plant?, String>((ref, plantId) async {
  final data = await SupabaseService.getPlant(plantId);
  if (data == null) return null;
  return Plant.fromJson(data);
});

/// Plant actions notifier.
class PlantNotifier extends StateNotifier<AsyncValue<void>> {
  PlantNotifier() : super(const AsyncValue.data(null));

  static const _uuid = Uuid();

  /// Create a new plant.
  Future<Plant?> createPlant({
    required String nickname,
    String? speciesScientific,
    String? speciesCommon,
    EnvironmentProfile? environmentProfile,
  }) async {
    state = const AsyncValue.loading();
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception('Not authenticated');

      final data = {
        'id': _uuid.v4(),
        'user_id': userId,
        'nickname': nickname,
        'species_scientific': speciesScientific,
        'species_common': speciesCommon,
        'environment_profile':
            (environmentProfile ?? const EnvironmentProfile()).toJson(),
        'is_archived': false,
      };

      final result = await SupabaseService.createPlant(data);
      state = const AsyncValue.data(null);
      return Plant.fromJson(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Update plant details.
  Future<void> updatePlant({
    required String plantId,
    String? nickname,
    String? speciesScientific,
    String? speciesCommon,
    EnvironmentProfile? environmentProfile,
  }) async {
    state = const AsyncValue.loading();
    try {
      final updates = <String, dynamic>{};
      if (nickname != null) updates['nickname'] = nickname;
      if (speciesScientific != null) {
        updates['species_scientific'] = speciesScientific;
      }
      if (speciesCommon != null) {
        updates['species_common'] = speciesCommon;
      }
      if (environmentProfile != null) {
        updates['environment_profile'] = environmentProfile.toJson();
      }

      await SupabaseService.updatePlant(plantId, updates);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Archive (soft delete) a plant.
  Future<void> archivePlant(String plantId) async {
    state = const AsyncValue.loading();
    try {
      await SupabaseService.archivePlant(plantId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final plantNotifierProvider =
    StateNotifierProvider<PlantNotifier, AsyncValue<void>>((ref) {
  return PlantNotifier();
});
