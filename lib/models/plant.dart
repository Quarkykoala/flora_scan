/// Environment profile for a plant.
class EnvironmentProfile {
  final String locationType;
  final String lightSource;
  final String potType;
  final String soilMix;
  final String sunExposureBand;

  const EnvironmentProfile({
    this.locationType = 'unknown',
    this.lightSource = 'unknown',
    this.potType = 'unknown',
    this.soilMix = 'unknown',
    this.sunExposureBand = 'unknown',
  });

  factory EnvironmentProfile.fromJson(Map<String, dynamic> json) {
    return EnvironmentProfile(
      locationType: json['location_type'] as String? ?? 'unknown',
      lightSource: json['light_source'] as String? ?? 'unknown',
      potType: json['pot_type'] as String? ?? 'unknown',
      soilMix: json['soil_mix'] as String? ?? 'unknown',
      sunExposureBand: json['sun_exposure_band'] as String? ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location_type': locationType,
      'light_source': lightSource,
      'pot_type': potType,
      'soil_mix': soilMix,
      'sun_exposure_band': sunExposureBand,
    };
  }

  EnvironmentProfile copyWith({
    String? locationType,
    String? lightSource,
    String? potType,
    String? soilMix,
    String? sunExposureBand,
  }) {
    return EnvironmentProfile(
      locationType: locationType ?? this.locationType,
      lightSource: lightSource ?? this.lightSource,
      potType: potType ?? this.potType,
      soilMix: soilMix ?? this.soilMix,
      sunExposureBand: sunExposureBand ?? this.sunExposureBand,
    );
  }

  static const List<String> locationTypes = [
    'indoor',
    'outdoor_balcony',
    'outdoor_garden',
    'greenhouse',
  ];

  static const List<String> lightSources = [
    'sun',
    'grow_light',
    'indirect',
    'mixed',
    'unknown',
  ];

  static const List<String> potTypes = [
    'terracotta',
    'plastic',
    'ceramic',
    'hydroponic',
    'fabric',
    'unknown',
  ];

  static const List<String> soilMixes = [
    'standard',
    'succulent',
    'aroid',
    'cocopeat',
    'hydroponic',
    'unknown',
  ];

  static const List<String> sunExposureBands = [
    '0-2h',
    '2-5h',
    '5h+',
    'unknown',
  ];
}

/// Plant model matching the `plants` table.
class Plant {
  final String id;
  final String userId;
  final String nickname;
  final String? speciesScientific;
  final String? speciesCommon;
  final double? speciesConfidence;
  final EnvironmentProfile environmentProfile;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Plant({
    required this.id,
    required this.userId,
    required this.nickname,
    this.speciesScientific,
    this.speciesCommon,
    this.speciesConfidence,
    this.environmentProfile = const EnvironmentProfile(),
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Plant.fromJson(Map<String, dynamic> json) {
    final envJson = json['environment_profile'];
    final envProfile = envJson is Map<String, dynamic>
        ? EnvironmentProfile.fromJson(envJson)
        : const EnvironmentProfile();

    return Plant(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      nickname: json['nickname'] as String,
      speciesScientific: json['species_scientific'] as String?,
      speciesCommon: json['species_common'] as String?,
      speciesConfidence: (json['species_confidence'] as num?)?.toDouble(),
      environmentProfile: envProfile,
      isArchived: json['is_archived'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'nickname': nickname,
      'species_scientific': speciesScientific,
      'species_common': speciesCommon,
      'species_confidence': speciesConfidence,
      'environment_profile': environmentProfile.toJson(),
      'is_archived': isArchived,
    };
  }

  Plant copyWith({
    String? nickname,
    String? speciesScientific,
    String? speciesCommon,
    double? speciesConfidence,
    EnvironmentProfile? environmentProfile,
    bool? isArchived,
  }) {
    return Plant(
      id: id,
      userId: userId,
      nickname: nickname ?? this.nickname,
      speciesScientific: speciesScientific ?? this.speciesScientific,
      speciesCommon: speciesCommon ?? this.speciesCommon,
      speciesConfidence: speciesConfidence ?? this.speciesConfidence,
      environmentProfile: environmentProfile ?? this.environmentProfile,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  String get displayName =>
      speciesCommon ?? speciesScientific ?? nickname;
}
