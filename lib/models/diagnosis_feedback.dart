/// Feedback type for diagnosis quality tracking.
enum FeedbackType {
  helpful,
  notHelpful('not_helpful'),
  wrongDiagnosis('wrong_diagnosis'),
  improvedAfterTreatment('improved_after_treatment');

  final String value;
  const FeedbackType([String? v]) : value = v ?? '';

  String get apiValue => value.isEmpty ? name : value;

  static FeedbackType fromString(String value) {
    return FeedbackType.values.firstWhere(
      (e) => e.apiValue == value || e.name == value,
      orElse: () => FeedbackType.helpful,
    );
  }
}

/// Diagnosis feedback model matching the `diagnosis_feedback` table.
class DiagnosisFeedback {
  final String id;
  final String scanId;
  final String userId;
  final FeedbackType feedbackType;
  final String? feedbackNote;
  final DateTime createdAt;

  const DiagnosisFeedback({
    required this.id,
    required this.scanId,
    required this.userId,
    required this.feedbackType,
    this.feedbackNote,
    required this.createdAt,
  });

  factory DiagnosisFeedback.fromJson(Map<String, dynamic> json) {
    return DiagnosisFeedback(
      id: json['id'] as String,
      scanId: json['scan_id'] as String,
      userId: json['user_id'] as String,
      feedbackType: FeedbackType.fromString(json['feedback_type'] as String),
      feedbackNote: json['feedback_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scan_id': scanId,
      'user_id': userId,
      'feedback_type': feedbackType.apiValue,
      'feedback_note': feedbackNote,
    };
  }
}
