import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/followup_mission.dart';

/// Local notification service for follow-up missions.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _timezoneInitialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    await _initializeTimezone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  static Future<void> scheduleMissionReminder(FollowupMission mission) async {
    if (!_initialized || kIsWeb || mission.status != FollowupMissionStatus.pending) {
      return;
    }

    final due = mission.dueAtUtc.toLocal();
    if (due.isBefore(DateTime.now())) return;
    final dueTz = tz.TZDateTime.from(due, tz.local);
    final now = tz.TZDateTime.now(tz.local);

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

    final preDueAt = _computePreDueReminderAt(dueTz, now);
    if (preDueAt != null) {
      await _plugin.zonedSchedule(
        _notificationIdForMissionStage(mission.id, 'pre'),
        'Plant follow-up coming up',
        'Reminder: your recovery check-in is soon',
        preDueAt,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: mission.id,
      );
    }

    await _plugin.zonedSchedule(
      _notificationIdForMissionStage(mission.id, 'due'),
      'Plant follow-up due',
      'Log outcome for your recommended action',
      dueTz,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: mission.id,
    );
  }

  static Future<void> cancelMissionReminder(String missionId) async {
    if (!_initialized || kIsWeb) return;
    await _plugin.cancel(_notificationIdForMissionStage(missionId, 'pre'));
    await _plugin.cancel(_notificationIdForMissionStage(missionId, 'due'));
  }

  static Future<void> syncMissionReminders(List<FollowupMission> missions) async {
    if (!_initialized || kIsWeb) return;

    final pendingMissionIds = missions
        .where((mission) => mission.status == FollowupMissionStatus.pending)
        .map((mission) => mission.id)
        .toSet();

    final scheduled = await _plugin.pendingNotificationRequests();
    for (final notification in scheduled) {
      final missionId = notification.payload;
      if (missionId == null) continue;
      if (!pendingMissionIds.contains(missionId)) {
        await _plugin.cancel(notification.id);
      }
    }

    for (final mission in missions.where(
      (mission) => mission.status == FollowupMissionStatus.pending,
    )) {
      await scheduleMissionReminder(mission);
    }
  }

  static Future<void> _initializeTimezone() async {
    if (_timezoneInitialized) return;

    tz.initializeTimeZones();
    try {
      final deviceTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimeZone));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    _timezoneInitialized = true;
  }

  static tz.TZDateTime? _computePreDueReminderAt(
    tz.TZDateTime dueAt,
    tz.TZDateTime now,
  ) {
    final lead = dueAt.difference(now);
    if (lead <= const Duration(hours: 3)) return null;
    if (lead >= const Duration(days: 2)) {
      return dueAt.subtract(const Duration(hours: 24));
    }
    if (lead >= const Duration(hours: 12)) {
      return dueAt.subtract(const Duration(hours: 6));
    }
    return dueAt.subtract(const Duration(hours: 2));
  }

  static int _notificationIdForMissionStage(String missionId, String stage) {
    final digest = sha1.convert(utf8.encode('mission:$missionId:$stage')).toString();
    return int.parse(digest.substring(0, 8), radix: 16) & 0x7fffffff;
  }
}
