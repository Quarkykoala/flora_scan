/// Mission type for follow-up actions.
enum FollowupMissionType {
  checkPhoto('check_photo'),
  confirmAction('confirm_action'),
  logOutcome('log_outcome');

  final String value;
  const FollowupMissionType(this.value);

  static FollowupMissionType fromString(String value) {
    return FollowupMissionType.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => FollowupMissionType.logOutcome,
    );
  }
}

/// Mission lifecycle status.
enum FollowupMissionStatus {
  pending,
  completed,
  snoozed,
  skipped,
  expired;

  static FollowupMissionStatus fromString(String value) {
    return FollowupMissionStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FollowupMissionStatus.pending,
    );
  }
}

/// Follow-up mission model for `followup_missions`.
class FollowupMission {
  final String id;
  final String userId;
  final String plantId;
  final String interventionId;
  final FollowupMissionType missionType;
  final DateTime dueAtUtc;
  final FollowupMissionStatus status;
  final bool notificationScheduled;
  final DateTime? completedAtUtc;
  final DateTime createdAt;

  const FollowupMission({
    required this.id,
    required this.userId,
    required this.plantId,
    required this.interventionId,
    this.missionType = FollowupMissionType.logOutcome,
    required this.dueAtUtc,
    this.status = FollowupMissionStatus.pending,
    this.notificationScheduled = false,
    this.completedAtUtc,
    required this.createdAt,
  });

  factory FollowupMission.fromJson(Map<String, dynamic> json) {
    return FollowupMission(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      plantId: json['plant_id'] as String,
      interventionId: json['intervention_id'] as String,
      missionType:
          FollowupMissionType.fromString(json['mission_type'] as String),
      dueAtUtc: DateTime.parse(json['due_at_utc'] as String),
      status: FollowupMissionStatus.fromString(json['status'] as String),
      notificationScheduled: json['notification_scheduled'] as bool? ?? false,
      completedAtUtc: json['completed_at_utc'] != null
          ? DateTime.parse(json['completed_at_utc'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'plant_id': plantId,
      'intervention_id': interventionId,
      'mission_type': missionType.value,
      'due_at_utc': dueAtUtc.toIso8601String(),
      'status': status.name,
      'notification_scheduled': notificationScheduled,
      'completed_at_utc': completedAtUtc?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
