import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/followup_mission.dart';

/// Local notification service for follow-up missions.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> scheduleMissionReminder(FollowupMission mission) async {
    if (!_initialized || mission.status != FollowupMissionStatus.pending) return;

    final due = mission.dueAtUtc.toLocal();
    if (due.isBefore(DateTime.now())) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'followup_missions',
        'Follow-up Missions',
        channelDescription: 'Reminders for intervention follow-up check-ins',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.schedule(
      mission.id.hashCode,
      'Plant follow-up due',
      'Log outcome for your recommended action',
      due,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: mission.id,
    );
  }

  static Future<void> cancelMissionReminder(String missionId) async {
    await _plugin.cancel(missionId.hashCode);
  }

  static Future<void> syncMissionReminders(List<FollowupMission> missions) async {
    for (final mission in missions) {
      if (mission.status == FollowupMissionStatus.pending) {
        await scheduleMissionReminder(mission);
      } else {
        await cancelMissionReminder(mission.id);
      }
    }
  }
}
