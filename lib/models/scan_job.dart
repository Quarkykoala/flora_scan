/// Job type for scan processing steps.
enum ScanJobType {
  enrichWeather('enrich_weather'),
  enrichAir('enrich_air'),
  diagnoseAi('diagnose_ai');

  final String value;
  const ScanJobType(this.value);

  static ScanJobType fromString(String value) {
    return ScanJobType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ScanJobType.diagnoseAi,
    );
  }
}

/// Job status for scan processing.
enum ScanJobStatus {
  queued,
  running,
  succeeded,
  failed,
  retrying;

  static ScanJobStatus fromString(String value) {
    return ScanJobStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ScanJobStatus.queued,
    );
  }
}

/// Scan job model matching the `scan_jobs` table.
class ScanJob {
  final String id;
  final String scanId;
  final ScanJobType jobType;
  final ScanJobStatus status;
  final int attempts;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? errorMessage;
  final DateTime createdAt;

  const ScanJob({
    required this.id,
    required this.scanId,
    required this.jobType,
    this.status = ScanJobStatus.queued,
    this.attempts = 0,
    this.startedAt,
    this.finishedAt,
    this.errorMessage,
    required this.createdAt,
  });

  bool get isComplete =>
      status == ScanJobStatus.succeeded || status == ScanJobStatus.failed;

  factory ScanJob.fromJson(Map<String, dynamic> json) {
    return ScanJob(
      id: json['id'] as String,
      scanId: json['scan_id'] as String,
      jobType: ScanJobType.fromString(json['job_type'] as String),
      status: ScanJobStatus.fromString(json['status'] as String),
      attempts: json['attempts'] as int? ?? 0,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      finishedAt: json['finished_at'] != null
          ? DateTime.parse(json['finished_at'] as String)
          : null,
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scan_id': scanId,
      'job_type': jobType.value,
      'status': status.name,
      'attempts': attempts,
      'started_at': startedAt?.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ScanJob &&
        other.id == id &&
        other.scanId == scanId &&
        other.jobType == jobType &&
        other.status == status &&
        other.attempts == attempts &&
        other.startedAt == startedAt &&
        other.finishedAt == finishedAt &&
        other.errorMessage == errorMessage &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        scanId.hashCode ^
        jobType.hashCode ^
        status.hashCode ^
        attempts.hashCode ^
        startedAt.hashCode ^
        finishedAt.hashCode ^
        errorMessage.hashCode ^
        createdAt.hashCode;
  }
}
