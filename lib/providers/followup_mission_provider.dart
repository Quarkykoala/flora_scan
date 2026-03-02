import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/followup_mission.dart';
import '../services/notification_service.dart';
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
  final missions = data.map((json) => FollowupMission.fromJson(json)).toList();
  await NotificationService.syncMissionReminders(missions);
  return missions;
});

/// Provides all follow-up missions for the current user.
final allFollowupMissionsProvider =
    FutureProvider.autoDispose<List<FollowupMission>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final data = await SupabaseService.getFollowupMissions(userId: userId);
  final missions = data.map((json) => FollowupMission.fromJson(json)).toList();
  await NotificationService.syncMissionReminders(missions);
  return missions;
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
  final missions = data.map((json) => FollowupMission.fromJson(json)).toList();
  await NotificationService.syncMissionReminders(missions);
  return missions;
});
