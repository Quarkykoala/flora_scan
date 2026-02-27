/// Care event type for longitudinal tracking.
enum CareEventType {
  watered,
  fertilized,
  repotted,
  pruned;

  static CareEventType fromString(String value) {
    return CareEventType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CareEventType.watered,
    );
  }
}

/// Care event model matching the `care_events` table.
class CareEvent {
  final String id;
  final String plantId;
  final String userId;
  final CareEventType eventType;
  final Map<String, dynamic>? eventValue;
  final DateTime occurredAtUtc;
  final DateTime createdAt;

  const CareEvent({
    required this.id,
    required this.plantId,
    required this.userId,
    required this.eventType,
    this.eventValue,
    required this.occurredAtUtc,
    required this.createdAt,
  });

  factory CareEvent.fromJson(Map<String, dynamic> json) {
    return CareEvent(
      id: json['id'] as String,
      plantId: json['plant_id'] as String,
      userId: json['user_id'] as String,
      eventType: CareEventType.fromString(json['event_type'] as String),
      eventValue: json['event_value'] as Map<String, dynamic>?,
      occurredAtUtc: DateTime.parse(json['occurred_at_utc'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plant_id': plantId,
      'user_id': userId,
      'event_type': eventType.name,
      'event_value': eventValue,
      'occurred_at_utc': occurredAtUtc.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CareEvent &&
        other.id == id &&
        other.plantId == plantId &&
        other.userId == userId &&
        other.eventType == eventType &&
        // Use map equality for eventValue if needed, but deep equality is expensive.
        // Assuming simple JSON structures, standard equality might suffice or use DeepCollectionEquality from package:collection.
        // For now, we'll rely on identity/standard equality as eventValue is nullable and potentially simple.
        // If strict content equality is needed, `const DeepCollectionEquality().equals` should be used.
        // Given the constraints and typical use, we'll check simplistic equality.
        other.eventValue.toString() == eventValue.toString() &&
        other.occurredAtUtc == occurredAtUtc &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      plantId,
      userId,
      eventType,
      eventValue.toString(),
      occurredAtUtc,
      createdAt,
    );
  }

  @override
  String toString() {
    return 'CareEvent(id: $id, plantId: $plantId, userId: $userId, eventType: $eventType, eventValue: $eventValue, occurredAtUtc: $occurredAtUtc, createdAt: $createdAt)';
  }
}
