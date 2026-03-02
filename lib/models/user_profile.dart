/// User profile model matching the `users` table.
class UserProfile {
  final String id;
  final String localeCode;
  final bool researchConsent;
  final bool isPremium;
  final int freeScansRemaining;
  final String? climateZone;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    this.localeCode = 'en',
    this.researchConsent = false,
    this.isPremium = false,
    this.freeScansRemaining = 0,
    this.climateZone,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      localeCode: json['locale_code'] as String? ?? 'en',
      researchConsent: json['research_consent'] as bool? ?? false,
      isPremium: json['is_premium'] as bool? ?? false,
      freeScansRemaining: json['free_scans_remaining'] as int? ?? 0,
      climateZone: json['climate_zone'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'locale_code': localeCode,
      'research_consent': researchConsent,
      'is_premium': isPremium,
      'free_scans_remaining': freeScansRemaining,
      'climate_zone': climateZone,
    };
  }

  UserProfile copyWith({
    String? localeCode,
    bool? researchConsent,
    bool? isPremium,
    int? freeScansRemaining,
    String? climateZone,
  }) {
    return UserProfile(
      id: id,
      localeCode: localeCode ?? this.localeCode,
      researchConsent: researchConsent ?? this.researchConsent,
      isPremium: isPremium ?? this.isPremium,
      freeScansRemaining: freeScansRemaining ?? this.freeScansRemaining,
      climateZone: climateZone ?? this.climateZone,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserProfile &&
        other.id == id &&
        other.localeCode == localeCode &&
        other.researchConsent == researchConsent &&
        other.isPremium == isPremium &&
        other.freeScansRemaining == freeScansRemaining &&
        other.climateZone == climateZone &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        localeCode.hashCode ^
        researchConsent.hashCode ^
        isPremium.hashCode ^
        freeScansRemaining.hashCode ^
        climateZone.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
