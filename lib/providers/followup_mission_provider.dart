import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/followup_mission.dart';
import '../services/supabase_service.dart';

/// Provides pending follow-up missions for the current user.
final pendingFollowupMissionsProvider =
    FutureProvider.autoDispose<List<FollowupMission>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final data = await SupabaseService.getFollowupMissions(
    userId: userId,
    status: FollowupMissionStatus.pending.name,
  );
  return data.map((json) => FollowupMission.fromJson(json)).toList();
});

/// Provides follow-up missions for a plant.
final plantFollowupMissionsProvider = FutureProvider.autoDispose
    .family<List<FollowupMission>, String>((ref, plantId) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final data = await SupabaseService.getFollowupMissions(
    userId: userId,
    plantId: plantId,
  );
  return data.map((json) => FollowupMission.fromJson(json)).toList();
});
