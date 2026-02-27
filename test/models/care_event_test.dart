import 'package:flutter_test/flutter_test.dart';
import 'package:flora_scan/models/care_event.dart';

void main() {
  group('CareEvent', () {
    final DateTime mockTime = DateTime.parse('2023-10-27T10:00:00.000Z');
    final DateTime mockCreated = DateTime.parse('2023-10-26T10:00:00.000Z');

    test('fromJson correctly parses a valid JSON object', () {
      final json = {
        'id': 'event_123',
        'plant_id': 'plant_456',
        'user_id': 'user_789',
        'event_type': 'fertilized',
        'event_value': {'amount': '10ml'},
        'occurred_at_utc': '2023-10-27T10:00:00.000Z',
        'created_at': '2023-10-26T10:00:00.000Z',
      };

      final event = CareEvent.fromJson(json);

      expect(event.id, 'event_123');
      expect(event.plantId, 'plant_456');
      expect(event.userId, 'user_789');
      expect(event.eventType, CareEventType.fertilized);
      expect(event.eventValue, {'amount': '10ml'});
      expect(event.occurredAtUtc, mockTime);
      expect(event.createdAt, mockCreated);
    });

    test('fromJson handles null eventValue', () {
      final json = {
        'id': 'event_123',
        'plant_id': 'plant_456',
        'user_id': 'user_789',
        'event_type': 'watered',
        'event_value': null,
        'occurred_at_utc': '2023-10-27T10:00:00.000Z',
        'created_at': '2023-10-26T10:00:00.000Z',
      };

      final event = CareEvent.fromJson(json);

      expect(event.eventValue, isNull);
      expect(event.eventType, CareEventType.watered);
    });

    test('toJson produces correct map with excluded read-only fields', () {
      final event = CareEvent(
        id: 'event_123',
        plantId: 'plant_456',
        userId: 'user_789',
        eventType: CareEventType.repotted,
        eventValue: {'soil': 'potting_mix'},
        occurredAtUtc: mockTime,
        createdAt: mockCreated,
      );

      final json = event.toJson();

      expect(json['plant_id'], 'plant_456');
      expect(json['user_id'], 'user_789');
      expect(json['event_type'], 'repotted');
      expect(json['event_value'], {'soil': 'potting_mix'});
      expect(json['occurred_at_utc'], '2023-10-27T10:00:00.000Z');

      // Ensure read-only fields are NOT present
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('created_at'), isFalse);
    });

    test('Round-trip serialization maintains data integrity when ID and createdAt are restored', () {
      final originalEvent = CareEvent(
        id: 'event_123',
        plantId: 'plant_456',
        userId: 'user_789',
        eventType: CareEventType.pruned,
        eventValue: {'leaves_removed': 3},
        occurredAtUtc: mockTime,
        createdAt: mockCreated,
      );

      final json = originalEvent.toJson();

      // Simulate database adding ID and createdAt back
      json['id'] = originalEvent.id;
      json['created_at'] = originalEvent.createdAt.toIso8601String();

      final reconstructedEvent = CareEvent.fromJson(json);

      expect(reconstructedEvent, equals(originalEvent));
    });

    test('Equality operator correctly identifies equal objects', () {
      final event1 = CareEvent(
        id: '1',
        plantId: 'p1',
        userId: 'u1',
        eventType: CareEventType.watered,
        occurredAtUtc: mockTime,
        createdAt: mockCreated,
      );

      final event2 = CareEvent(
        id: '1',
        plantId: 'p1',
        userId: 'u1',
        eventType: CareEventType.watered,
        occurredAtUtc: mockTime,
        createdAt: mockCreated,
      );

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));
    });

    test('Equality operator correctly identifies different objects', () {
      final baseEvent = CareEvent(
        id: '1',
        plantId: 'p1',
        userId: 'u1',
        eventType: CareEventType.watered,
        occurredAtUtc: mockTime,
        createdAt: mockCreated,
      );

      final differentId = CareEvent(
        id: '2',
        plantId: 'p1',
        userId: 'u1',
        eventType: CareEventType.watered,
        occurredAtUtc: mockTime,
        createdAt: mockCreated,
      );

      final differentType = CareEvent(
        id: '1',
        plantId: 'p1',
        userId: 'u1',
        eventType: CareEventType.pruned,
        occurredAtUtc: mockTime,
        createdAt: mockCreated,
      );

      expect(baseEvent, isNot(equals(differentId)));
      expect(baseEvent, isNot(equals(differentType)));
    });

    group('CareEventType', () {
      test('fromString correctly parses known values', () {
        expect(CareEventType.fromString('watered'), CareEventType.watered);
        expect(CareEventType.fromString('fertilized'), CareEventType.fertilized);
        expect(CareEventType.fromString('repotted'), CareEventType.repotted);
        expect(CareEventType.fromString('pruned'), CareEventType.pruned);
      });

      test('fromString falls back to watered for unknown values', () {
        expect(CareEventType.fromString('sunbathing'), CareEventType.watered);
        expect(CareEventType.fromString(''), CareEventType.watered);
      });
    });
  });
}
