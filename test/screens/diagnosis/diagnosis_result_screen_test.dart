import 'package:flora_scan/models/followup_mission.dart';
import 'package:flora_scan/models/intervention_outcome.dart';
import 'package:flora_scan/models/intervention_recommendation.dart';
import 'package:flora_scan/models/scan.dart';
import 'package:flora_scan/providers/followup_mission_provider.dart';
import 'package:flora_scan/providers/intervention_outcome_provider.dart';
import 'package:flora_scan/providers/intervention_recommendation_provider.dart';
import 'package:flora_scan/providers/scan_provider.dart';
import 'package:flora_scan/screens/diagnosis/diagnosis_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiagnosisResultScreen', () {
    testWidgets('renders recommendations and missions', (tester) async {
      const scanId = 'scan-123';
      final scan = _buildScan(id: scanId);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scanDetailProvider(scanId).overrideWith((ref) async => scan),
            scanInterventionRecommendationsProvider(scanId).overrideWith(
              (ref) async => [
                InterventionRecommendation(
                  id: 'int-1',
                  scanId: scanId,
                  userId: 'user-1',
                  plantId: 'plant-1',
                  recommendationCode: 'reduce_watering_frequency',
                  recommendationLocalized: 'Reduce watering frequency',
                  recommendationDetailsLocalized:
                      'Water only when topsoil is dry.',
                  recommendedAtUtc: DateTime(2026, 2, 27),
                  followupDueAtUtc: DateTime(2026, 3, 2),
                  createdAt: DateTime(2026, 2, 27),
                  updatedAt: DateTime(2026, 2, 27),
                ),
              ],
            ),
            plantFollowupMissionsProvider('plant-1').overrideWith(
              (ref) async => [
                FollowupMission(
                  id: 'm-1',
                  userId: 'user-1',
                  plantId: 'plant-1',
                  interventionId: 'int-1',
                  missionType: FollowupMissionType.logOutcome,
                  dueAtUtc: DateTime(2026, 3, 2),
                  createdAt: DateTime(2026, 2, 27),
                ),
              ],
            ),
          ],
          child: const MaterialApp(home: DiagnosisResultScreen(scanId: scanId)),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Recommended Actions'), findsOneWidget);
      expect(find.text('Reduce watering frequency'), findsOneWidget);
      expect(find.text('Follow-up Missions'), findsOneWidget);
      expect(find.text('Log outcome check-in'), findsOneWidget);
    });

    testWidgets('logs outcome with adherence notes and confidence', (tester) async {
      const scanId = 'scan-456';
      final scan = _buildScan(id: scanId);
      final fakeNotifier = _FakeInterventionOutcomeNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scanDetailProvider(scanId).overrideWith((ref) async => scan),
            scanInterventionRecommendationsProvider(scanId).overrideWith(
              (ref) async => [
                InterventionRecommendation(
                  id: 'int-2',
                  scanId: scanId,
                  userId: 'user-1',
                  plantId: 'plant-1',
                  recommendationCode: 'increase_airflow',
                  recommendationLocalized: 'Increase airflow',
                  recommendedAtUtc: DateTime(2026, 2, 27),
                  followupDueAtUtc: DateTime(2026, 3, 2),
                  createdAt: DateTime(2026, 2, 27),
                  updatedAt: DateTime(2026, 2, 27),
                ),
              ],
            ),
            plantFollowupMissionsProvider('plant-1').overrideWith(
              (ref) async => const <FollowupMission>[],
            ),
            interventionOutcomeNotifierProvider.overrideWith(
              (ref) => fakeNotifier,
            ),
          ],
          child: const MaterialApp(home: DiagnosisResultScreen(scanId: scanId)),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Log Outcome'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Partially'));
      await tester.tap(find.text('Worse'));
      await tester.enterText(
        find.byType(TextField),
        'Observed mild yellowing after treatment',
      );
      await tester.tap(find.text('Add confidence score'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save outcome'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.calls.length, 1);
      expect(fakeNotifier.calls.first.interventionId, 'int-2');
      expect(fakeNotifier.calls.first.outcomeStatus, OutcomeStatus.worse);
      expect(fakeNotifier.calls.first.adherenceStatus, AdherenceStatus.partially);
      expect(
        fakeNotifier.calls.first.adherenceNotes,
        'Observed mild yellowing after treatment',
      );
      expect(
        fakeNotifier.calls.first.outcomeNotes,
        'Observed mild yellowing after treatment',
      );
      expect(fakeNotifier.calls.first.outcomeConfidence, 0.8);
    });

    testWidgets('logs outcome with optional fields omitted', (tester) async {
      const scanId = 'scan-789';
      final scan = _buildScan(id: scanId);
      final fakeNotifier = _FakeInterventionOutcomeNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scanDetailProvider(scanId).overrideWith((ref) async => scan),
            scanInterventionRecommendationsProvider(scanId).overrideWith(
              (ref) async => [
                InterventionRecommendation(
                  id: 'int-3',
                  scanId: scanId,
                  userId: 'user-1',
                  plantId: 'plant-1',
                  recommendationCode: 'increase_light_exposure',
                  recommendationLocalized: 'Increase light exposure',
                  recommendedAtUtc: DateTime(2026, 2, 27),
                  followupDueAtUtc: DateTime(2026, 3, 2),
                  createdAt: DateTime(2026, 2, 27),
                  updatedAt: DateTime(2026, 2, 27),
                ),
              ],
            ),
            plantFollowupMissionsProvider('plant-1').overrideWith(
              (ref) async => const <FollowupMission>[],
            ),
            interventionOutcomeNotifierProvider.overrideWith(
              (ref) => fakeNotifier,
            ),
          ],
          child: const MaterialApp(home: DiagnosisResultScreen(scanId: scanId)),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Log Outcome'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save outcome'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.calls.length, 1);
      expect(fakeNotifier.calls.first.interventionId, 'int-3');
      expect(fakeNotifier.calls.first.outcomeStatus, OutcomeStatus.improved);
      expect(fakeNotifier.calls.first.adherenceStatus, AdherenceStatus.fully);
      expect(fakeNotifier.calls.first.adherenceNotes, isNull);
      expect(fakeNotifier.calls.first.outcomeNotes, isNull);
      expect(fakeNotifier.calls.first.outcomeConfidence, isNull);
    });
  });
}

class _OutcomeCall {
  final String interventionId;
  final AdherenceStatus adherenceStatus;
  final OutcomeStatus outcomeStatus;
  final String? adherenceNotes;
  final String? outcomeNotes;
  final double? outcomeConfidence;

  const _OutcomeCall({
    required this.interventionId,
    required this.adherenceStatus,
    required this.outcomeStatus,
    required this.adherenceNotes,
    required this.outcomeNotes,
    required this.outcomeConfidence,
  });
}

class _FakeInterventionOutcomeNotifier extends InterventionOutcomeNotifier {
  final List<_OutcomeCall> calls = [];

  @override
  Future<void> submitOutcome({
    required String interventionId,
    AdherenceStatus adherenceStatus = AdherenceStatus.unknown,
    OutcomeStatus outcomeStatus = OutcomeStatus.uncertain,
    String? adherenceNotes,
    String? outcomeNotes,
    double? outcomeConfidence,
    String? followupScanId,
    double? followupImageQualityScore,
  }) async {
    calls.add(
      _OutcomeCall(
        interventionId: interventionId,
        adherenceStatus: adherenceStatus,
        outcomeStatus: outcomeStatus,
        adherenceNotes: adherenceNotes,
        outcomeNotes: outcomeNotes,
        outcomeConfidence: outcomeConfidence,
      ),
    );
    state = const AsyncValue.data(null);
  }
}

Scan _buildScan({required String id}) {
  final now = DateTime(2026, 2, 27);
  return Scan(
    id: id,
    userId: 'user-1',
    plantId: 'plant-1',
    clientScanId: '550e8400-e29b-41d4-a716-446655440000',
    capturedAtUtc: now,
    imagePath: '/tmp/image.jpg',
    processingStatus: ProcessingStatus.completed,
    diagnosisLocalized: 'Mild fungal stress',
    diagnosisConfidence: 0.82,
    healthScore: 64,
    treatmentLocalized: 'Keep leaves dry and improve air circulation.',
    createdAt: now,
    updatedAt: now,
  );
}
