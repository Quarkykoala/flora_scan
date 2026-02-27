import 'package:flutter_test/flutter_test.dart';
import 'package:flora_scan/models/plant.dart';

void main() {
  group('Plant', () {
    test('fromJson parses full JSON correctly', () {
      final json = {
        'id': 'plant-123',
        'user_id': 'user-456',
        'nickname': 'My Fern',
        'species_scientific': 'Fernus fernus',
        'species_common': 'Fern',
        'species_confidence': 0.95,
        'environment_profile': {
          'location_type': 'indoor',
          'light_source': 'indirect',
          'pot_type': 'terracotta',
          'soil_mix': 'standard',
          'sun_exposure_band': '2-5h',
        },
        'is_archived': true,
        'created_at': '2023-01-01T12:00:00.000Z',
        'updated_at': '2023-01-02T12:00:00.000Z',
      };

      final plant = Plant.fromJson(json);

      expect(plant.id, 'plant-123');
      expect(plant.userId, 'user-456');
      expect(plant.nickname, 'My Fern');
      expect(plant.speciesScientific, 'Fernus fernus');
      expect(plant.speciesCommon, 'Fern');
      expect(plant.speciesConfidence, 0.95);
      expect(plant.environmentProfile.locationType, 'indoor');
      expect(plant.isArchived, true);
      expect(plant.createdAt, DateTime.utc(2023, 1, 1, 12, 0, 0));
      expect(plant.updatedAt, DateTime.utc(2023, 1, 2, 12, 0, 0));
    });

    test('fromJson parses minimal JSON correctly with defaults', () {
      final json = {
        'id': 'plant-123',
        'user_id': 'user-456',
        'nickname': 'My Plant',
        'created_at': '2023-01-01T12:00:00.000Z',
        'updated_at': '2023-01-02T12:00:00.000Z',
      };

      final plant = Plant.fromJson(json);

      expect(plant.id, 'plant-123');
      expect(plant.userId, 'user-456');
      expect(plant.nickname, 'My Plant');
      expect(plant.speciesScientific, isNull);
      expect(plant.speciesCommon, isNull);
      expect(plant.speciesConfidence, isNull);
      expect(plant.environmentProfile.locationType, 'unknown'); // Default
      expect(plant.isArchived, false); // Default
    });

    test('fromJson handles null environment_profile gracefully', () {
      final json = {
        'id': 'plant-123',
        'user_id': 'user-456',
        'nickname': 'My Plant',
        'environment_profile': null,
        'created_at': '2023-01-01T12:00:00.000Z',
        'updated_at': '2023-01-02T12:00:00.000Z',
      };

      final plant = Plant.fromJson(json);

      expect(plant.environmentProfile.locationType, 'unknown');
      expect(plant.environmentProfile.lightSource, 'unknown');
    });

    test('fromJson handles invalid environment_profile type gracefully', () {
      final json = {
        'id': 'plant-123',
        'user_id': 'user-456',
        'nickname': 'My Plant',
        'environment_profile': 'invalid-string', // Should be a map
        'created_at': '2023-01-01T12:00:00.000Z',
        'updated_at': '2023-01-02T12:00:00.000Z',
      };

      final plant = Plant.fromJson(json);

      expect(plant.environmentProfile.locationType, 'unknown');
    });

    test('toJson serializes correctly', () {
      final plant = Plant(
        id: 'plant-123',
        userId: 'user-456',
        nickname: 'My Fern',
        speciesScientific: 'Fernus fernus',
        speciesCommon: 'Fern',
        speciesConfidence: 0.95,
        environmentProfile: const EnvironmentProfile(
          locationType: 'indoor',
          lightSource: 'indirect',
          potType: 'terracotta',
          soilMix: 'standard',
          sunExposureBand: '2-5h',
        ),
        isArchived: true,
        createdAt: DateTime.utc(2023, 1, 1, 12, 0, 0),
        updatedAt: DateTime.utc(2023, 1, 2, 12, 0, 0),
      );

      final json = plant.toJson();

      expect(json['id'], 'plant-123');
      expect(json['user_id'], 'user-456');
      expect(json['nickname'], 'My Fern');
      expect(json['species_scientific'], 'Fernus fernus');
      expect(json['species_common'], 'Fern');
      expect(json['species_confidence'], 0.95);
      expect(json['is_archived'], true);

      final envJson = json['environment_profile'] as Map<String, dynamic>;
      expect(envJson['location_type'], 'indoor');
      expect(envJson['light_source'], 'indirect');

      // Ensure DB-managed fields are EXCLUDED
      expect(json.containsKey('created_at'), false);
      expect(json.containsKey('updated_at'), false);
    });

    test('displayName prioritization works correctly', () {
      // 1. All present -> speciesCommon
      final plant1 = Plant(
        id: '1', userId: '1', nickname: 'Nick',
        speciesCommon: 'Common',
        speciesScientific: 'Scientific',
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      expect(plant1.displayName, 'Common');

      // 2. speciesCommon missing -> speciesScientific
      final plant2 = Plant(
        id: '1', userId: '1', nickname: 'Nick',
        speciesCommon: null,
        speciesScientific: 'Scientific',
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      expect(plant2.displayName, 'Scientific');

      // 3. Both species missing -> nickname
      final plant3 = Plant(
        id: '1', userId: '1', nickname: 'Nick',
        speciesCommon: null,
        speciesScientific: null,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      expect(plant3.displayName, 'Nick');
    });

    test('copyWith updates fields and refreshes updatedAt', () async {
      final initialTime = DateTime.utc(2023, 1, 1, 12, 0, 0);
      final plant = Plant(
        id: '1', userId: '1', nickname: 'Old Nick',
        isArchived: false,
        createdAt: initialTime, updatedAt: initialTime,
      );

      // Wait a small amount to ensure DateTime.now() is different
      await Future.delayed(const Duration(milliseconds: 10));

      final updatedPlant = plant.copyWith(
        nickname: 'New Nick',
        isArchived: true,
      );

      expect(updatedPlant.id, plant.id); // Should not change
      expect(updatedPlant.nickname, 'New Nick'); // Should update
      expect(updatedPlant.isArchived, true); // Should update
      expect(updatedPlant.createdAt, initialTime); // Should not change
      expect(updatedPlant.updatedAt.isAfter(initialTime), true); // Should be newer
    });
  });
}
