/// Adherence status for an intervention outcome.
enum AdherenceStatus {
  fully,
  partially,
  notDone('not_done'),
  unknown;

  final String value;
  const AdherenceStatus([String? v]) : value = v ?? '';

  String get apiValue => value.isEmpty ? name : value;

  static AdherenceStatus fromString(String value) {
    return AdherenceStatus.values.firstWhere(
      (e) => e.apiValue == value || e.name == value,
      orElse: () => AdherenceStatus.unknown,
    );
  }
}

/// Outcome status recorded after an intervention.
enum OutcomeStatus {
  improved,
  unchanged,
  worse,
  uncertain;

  static OutcomeStatus fromString(String value) {
    return OutcomeStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => OutcomeStatus.uncertain,
    );
  }
}

/// Reporter of outcome data.
enum OutcomeReporter {
  user,
  aiInferred('ai_inferred'),
  hybrid;

  final String value;
  const OutcomeReporter([String? v]) : value = v ?? '';

  String get apiValue => value.isEmpty ? name : value;

  static OutcomeReporter fromString(String value) {
    return OutcomeReporter.values.firstWhere(
      (e) => e.apiValue == value || e.name == value,
      orElse: () => OutcomeReporter.user,
    );
  }
}

/// Intervention outcome model for `intervention_outcomes`.
class InterventionOutcome {
  final String id;
  final String interventionId;
  final String userId;
  final String plantId;
  final AdherenceStatus adherenceStatus;
  final String? adherenceNotes;
  final OutcomeStatus outcomeStatus;
  final double? outcomeConfidence;
  final String? outcomeNotes;
  final String? followupScanId;
  final double? followupImageQualityScore;
  final int? daysSinceRecommendation;
  final OutcomeReporter reportedBy;
  final Map<String, dynamic>? aiOutcomeAssessmentRaw;
  final DateTime recordedAtUtc;
  final DateTime createdAt;

  const InterventionOutcome({
    required this.id,
    required this.interventionId,
    required this.userId,
    required this.plantId,
    this.adherenceStatus = AdherenceStatus.unknown,
    this.adherenceNotes,
    this.outcomeStatus = OutcomeStatus.uncertain,
    this.outcomeConfidence,
    this.outcomeNotes,
    this.followupScanId,
    this.followupImageQualityScore,
    this.daysSinceRecommendation,
    this.reportedBy = OutcomeReporter.user,
    this.aiOutcomeAssessmentRaw,
    required this.recordedAtUtc,
    required this.createdAt,
  });

  factory InterventionOutcome.fromJson(Map<String, dynamic> json) {
    return InterventionOutcome(
      id: json['id'] as String,
      interventionId: json['intervention_id'] as String,
      userId: json['user_id'] as String,
      plantId: json['plant_id'] as String,
      adherenceStatus:
          AdherenceStatus.fromString(json['adherence_status'] as String),
      adherenceNotes: json['adherence_notes'] as String?,
      outcomeStatus: OutcomeStatus.fromString(json['outcome_status'] as String),
      outcomeConfidence: (json['outcome_confidence'] as num?)?.toDouble(),
      outcomeNotes: json['outcome_notes'] as String?,
      followupScanId: json['followup_scan_id'] as String?,
      followupImageQualityScore:
          (json['followup_image_quality_score'] as num?)?.toDouble(),
      daysSinceRecommendation: json['days_since_recommendation'] as int?,
      reportedBy: OutcomeReporter.fromString(json['reported_by'] as String),
      aiOutcomeAssessmentRaw:
          json['ai_outcome_assessment_raw'] as Map<String, dynamic>?,
      recordedAtUtc: DateTime.parse(json['recorded_at_utc'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'intervention_id': interventionId,
      'user_id': userId,
      'plant_id': plantId,
      'adherence_status': adherenceStatus.apiValue,
      'adherence_notes': adherenceNotes,
      'outcome_status': outcomeStatus.name,
      'outcome_confidence': outcomeConfidence,
      'outcome_notes': outcomeNotes,
      'followup_scan_id': followupScanId,
      'followup_image_quality_score': followupImageQualityScore,
      'days_since_recommendation': daysSinceRecommendation,
      'reported_by': reportedBy.apiValue,
      'ai_outcome_assessment_raw': aiOutcomeAssessmentRaw,
      'recorded_at_utc': recordedAtUtc.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
