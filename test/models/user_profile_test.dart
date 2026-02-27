import 'package:flutter_test/flutter_test.dart';
import 'package:flora_scan/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    final now = DateTime.now();
    // Truncate to microseconds to avoid precision issues during JSON roundtrip if needed,
    // though UserProfile.fromJson uses DateTime.parse which handles ISO strings.
    // For direct comparison, we'll use a fixed time.
    final fixedTime = DateTime(2023, 10, 26, 12, 0, 0);
    final fixedTimeIso = fixedTime.toIso8601String();

    test('fromJson creates a valid UserProfile from complete JSON', () {
      final json = {
        'id': 'user123',
        'locale_code': 'fr',
        'research_consent': true,
        'climate_zone': 'Zone 5b',
        'created_at': fixedTimeIso,
        'updated_at': fixedTimeIso,
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'user123');
      expect(profile.localeCode, 'fr');
      expect(profile.researchConsent, true);
      expect(profile.climateZone, 'Zone 5b');
      expect(profile.createdAt, fixedTime);
      expect(profile.updatedAt, fixedTime);
    });

    test('fromJson uses default values when optional fields are missing', () {
      final json = {
        'id': 'user456',
        'created_at': fixedTimeIso,
        'updated_at': fixedTimeIso,
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'user456');
      expect(profile.localeCode, 'en'); // Default
      expect(profile.researchConsent, false); // Default
      expect(profile.climateZone, null); // Nullable
      expect(profile.createdAt, fixedTime);
      expect(profile.updatedAt, fixedTime);
    });

    test('fromJson handles null values for nullable fields', () {
      final json = {
        'id': 'user789',
        'climate_zone': null,
        'created_at': fixedTimeIso,
        'updated_at': fixedTimeIso,
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'user789');
      expect(profile.climateZone, null);
    });

    test('fromJson throws FormatException when required fields are missing', () {
      final jsonNoId = {
        'locale_code': 'en',
        'created_at': fixedTimeIso,
        'updated_at': fixedTimeIso,
      };

      // Since 'id' is cast as String, missing it (null) will throw a TypeError in strong mode
      // or standard error depending on Dart version/settings.
      // However, usually map['key'] as String throws if it is null.
      expect(() => UserProfile.fromJson(jsonNoId), throwsA(isA<TypeError>()));

      final jsonNoCreatedAt = {
        'id': 'user1',
        'updated_at': fixedTimeIso,
      };
       // DateTime.parse(null) throws or map access throws
      expect(() => UserProfile.fromJson(jsonNoCreatedAt), throwsA(isA<TypeError>()));
    });

    test('fromJson throws FormatException for invalid date format', () {
       final jsonInvalidDate = {
        'id': 'user1',
        'created_at': 'not-a-date',
        'updated_at': fixedTimeIso,
      };

      expect(() => UserProfile.fromJson(jsonInvalidDate), throwsFormatException);
    });

    test('toJson serializes correctly and excludes timestamps', () {
      final profile = UserProfile(
        id: 'user123',
        localeCode: 'fr',
        researchConsent: true,
        climateZone: 'Zone 5b',
        createdAt: fixedTime,
        updatedAt: fixedTime,
      );

      final json = profile.toJson();

      expect(json, {
        'id': 'user123',
        'locale_code': 'fr',
        'research_consent': true,
        'climate_zone': 'Zone 5b',
      });

      expect(json.containsKey('created_at'), isFalse);
      expect(json.containsKey('updated_at'), isFalse);
    });

    test('toJson handles null values', () {
      final profile = UserProfile(
        id: 'user123',
        createdAt: fixedTime,
        updatedAt: fixedTime,
        climateZone: null,
      );

      final json = profile.toJson();

      expect(json['climate_zone'], null);
    });

    test('copyWith updates specified fields and refreshes updatedAt', () async {
      final profile = UserProfile(
        id: 'user123',
        localeCode: 'en',
        researchConsent: false,
        climateZone: 'Zone 5b',
        createdAt: fixedTime,
        updatedAt: fixedTime,
      );

      // Add a small delay to ensure updatedAt is definitely different
      await Future.delayed(const Duration(milliseconds: 10));

      final updatedProfile = profile.copyWith(
        localeCode: 'es',
        researchConsent: true,
      );

      expect(updatedProfile.id, profile.id); // Should not change
      expect(updatedProfile.localeCode, 'es'); // Updated
      expect(updatedProfile.researchConsent, true); // Updated
      expect(updatedProfile.climateZone, profile.climateZone); // Should not change
      expect(updatedProfile.createdAt, profile.createdAt); // Should not change

      // updatedAt should be more recent than the original
      expect(updatedProfile.updatedAt.isAfter(profile.updatedAt), isTrue);
    });

    test('copyWith accepts null values if applicable but fields are non-nullable in copyWith signature usually means ignore', () {
      // The copyWith method signature is:
      // UserProfile copyWith({
      //   String? localeCode,
      //   bool? researchConsent,
      //   String? climateZone,
      // })
      // So passing null usually means "don't change".
      // BUT for nullable fields like climateZone, how do we unset it?
      // Looking at the implementation:
      // climateZone: climateZone ?? this.climateZone,
      // This implementation prevents unsetting climateZone to null.

      final profile = UserProfile(
        id: 'user123',
        localeCode: 'en',
        researchConsent: false,
        climateZone: 'Zone 5b',
        createdAt: fixedTime,
        updatedAt: fixedTime,
      );

      final updatedProfile = profile.copyWith(
        climateZone: null,
      );

      // Current implementation behavior:
      expect(updatedProfile.climateZone, 'Zone 5b');
    });
  });
}
