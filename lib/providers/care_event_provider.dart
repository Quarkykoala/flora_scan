import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/care_event.dart';
import '../services/supabase_service.dart';

/// Provides care events for a specific plant.
final careEventsProvider = FutureProvider.autoDispose
    .family<List<CareEvent>, String>((ref, plantId) async {
  final data = await SupabaseService.getCareEvents(plantId);
  return data.map((json) => CareEvent.fromJson(json)).toList();
});

/// Care event actions notifier.
class CareEventNotifier extends StateNotifier<AsyncValue<void>> {
  CareEventNotifier() : super(const AsyncValue.data(null));

  static const _uuid = Uuid();

  /// Log a care event.
  Future<void> logEvent({
    required String plantId,
    required CareEventType eventType,
    Map<String, dynamic>? eventValue,
    DateTime? occurredAt,
  }) async {
    state = const AsyncValue.loading();
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception('Not authenticated');

      await SupabaseService.createCareEvent({
        'id': _uuid.v4(),
        'plant_id': plantId,
        'user_id': userId,
        'event_type': eventType.name,
        'event_value': eventValue,
        'occurred_at_utc':
            (occurredAt ?? DateTime.now()).toUtc().toIso8601String(),
      });

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final careEventNotifierProvider =
    StateNotifierProvider<CareEventNotifier, AsyncValue<void>>((ref) {
  return CareEventNotifier();
});
