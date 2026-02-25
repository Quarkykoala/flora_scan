/// User profile model matching the `users` table.
class UserProfile {
  final String id;
  final String localeCode;
  final bool researchConsent;
  final String? climateZone;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    this.localeCode = 'en',
    this.researchConsent = true,
    this.climateZone,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      localeCode: json['locale_code'] as String? ?? 'en',
      researchConsent: json['research_consent'] as bool? ?? true,
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
      'climate_zone': climateZone,
    };
  }

  UserProfile copyWith({
    String? localeCode,
    bool? researchConsent,
    String? climateZone,
  }) {
    return UserProfile(
      id: id,
      localeCode: localeCode ?? this.localeCode,
      researchConsent: researchConsent ?? this.researchConsent,
      climateZone: climateZone ?? this.climateZone,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
