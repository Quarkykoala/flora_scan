/// Priority for an intervention recommendation.
enum InterventionPriority {
  high,
  medium,
  low;

  static InterventionPriority fromString(String value) {
    return InterventionPriority.values.firstWhere(
      (e) => e.name == value,
      orElse: () => InterventionPriority.medium,
    );
  }
}

/// Follow-up status of an intervention recommendation.
enum FollowupStatus {
  pending,
  completed,
  skipped,
  expired;

  static FollowupStatus fromString(String value) {
    return FollowupStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FollowupStatus.pending,
    );
  }
}

/// Source of recommendation generation.
enum InterventionSource {
  gemini,
  rules,
  hybrid;

  static InterventionSource fromString(String value) {
    return InterventionSource.values.firstWhere(
      (e) => e.name == value,
      orElse: () => InterventionSource.gemini,
    );
  }
}

/// Risk level associated with recommendation.
enum InterventionRiskLevel {
  low,
  medium,
  high;

  static InterventionRiskLevel fromString(String value) {
    return InterventionRiskLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => InterventionRiskLevel.low,
    );
  }
}

/// Intervention recommendation model for `intervention_recommendations`.
class InterventionRecommendation {
  final String id;
  final String scanId;
  final String userId;
  final String plantId;
  final String recommendationCode;
  final String recommendationLocalized;
  final String? recommendationDetailsLocalized;
  final InterventionPriority priority;
  final DateTime recommendedAtUtc;
  final int expectedFollowupWindowHours;
  final DateTime followupDueAtUtc;
  final FollowupStatus followupStatus;
  final InterventionSource source;
  final String? aiModelName;
  final String? aiModelVersion;
  final String? promptVersion;
  final String? experimentId;
  final String? variantId;
  final bool isRandomized;
  final bool randomizationAllowed;
  final InterventionRiskLevel riskLevel;
  final String? safetyNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InterventionRecommendation({
    required this.id,
    required this.scanId,
    required this.userId,
    required this.plantId,
    required this.recommendationCode,
    required this.recommendationLocalized,
    this.recommendationDetailsLocalized,
    this.priority = InterventionPriority.medium,
    required this.recommendedAtUtc,
    this.expectedFollowupWindowHours = 72,
    required this.followupDueAtUtc,
    this.followupStatus = FollowupStatus.pending,
    this.source = InterventionSource.gemini,
    this.aiModelName,
    this.aiModelVersion,
    this.promptVersion,
    this.experimentId,
    this.variantId,
    this.isRandomized = false,
    this.randomizationAllowed = false,
    this.riskLevel = InterventionRiskLevel.low,
    this.safetyNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InterventionRecommendation.fromJson(Map<String, dynamic> json) {
    return InterventionRecommendation(
      id: json['id'] as String,
      scanId: json['scan_id'] as String,
      userId: json['user_id'] as String,
      plantId: json['plant_id'] as String,
      recommendationCode: json['recommendation_code'] as String,
      recommendationLocalized: json['recommendation_localized'] as String,
      recommendationDetailsLocalized:
          json['recommendation_details_localized'] as String?,
      priority: InterventionPriority.fromString(json['priority'] as String),
      recommendedAtUtc: DateTime.parse(json['recommended_at_utc'] as String),
      expectedFollowupWindowHours:
          json['expected_followup_window_hours'] as int? ?? 72,
      followupDueAtUtc: DateTime.parse(json['followup_due_at_utc'] as String),
      followupStatus:
          FollowupStatus.fromString(json['followup_status'] as String),
      source: InterventionSource.fromString(json['source'] as String),
      aiModelName: json['ai_model_name'] as String?,
      aiModelVersion: json['ai_model_version'] as String?,
      promptVersion: json['prompt_version'] as String?,
      experimentId: json['experiment_id'] as String?,
      variantId: json['variant_id'] as String?,
      isRandomized: json['is_randomized'] as bool? ?? false,
      randomizationAllowed: json['randomization_allowed'] as bool? ?? false,
      riskLevel:
          InterventionRiskLevel.fromString(json['risk_level'] as String),
      safetyNotes: json['safety_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scan_id': scanId,
      'user_id': userId,
      'plant_id': plantId,
      'recommendation_code': recommendationCode,
      'recommendation_localized': recommendationLocalized,
      'recommendation_details_localized': recommendationDetailsLocalized,
      'priority': priority.name,
      'recommended_at_utc': recommendedAtUtc.toIso8601String(),
      'expected_followup_window_hours': expectedFollowupWindowHours,
      'followup_due_at_utc': followupDueAtUtc.toIso8601String(),
      'followup_status': followupStatus.name,
      'source': source.name,
      'ai_model_name': aiModelName,
      'ai_model_version': aiModelVersion,
      'prompt_version': promptVersion,
      'experiment_id': experimentId,
      'variant_id': variantId,
      'is_randomized': isRandomized,
      'randomization_allowed': randomizationAllowed,
      'risk_level': riskLevel.name,
      'safety_notes': safetyNotes,
    };
  }
}
