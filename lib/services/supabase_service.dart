import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Core Supabase service for database operations and storage.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;

  /// Initialize Supabase.
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  /// Get current user ID or null.
  static String? get currentUserId => auth.currentUser?.id;

  /// Upload image to private storage bucket.
  /// Returns the storage path.
  static Future<String> uploadImage({
    required String userId,
    required String scanId,
    required Uint8List imageBytes,
    String extension = 'jpg',
    required String contentType,
  }) async {
    final path = '$userId/$scanId.$extension';
    await client.storage.from(AppConfig.imageBucket).uploadBinary(
          path,
          imageBytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );
    return path;
  }

  /// Get signed URL for image access.
  static Future<String> getSignedImageUrl(String path) async {
    return client.storage
        .from(AppConfig.imageBucket)
        .createSignedUrl(path, 3600);
  }

  // Users

  /// Create or update user profile.
  static Future<void> upsertUserProfile(Map<String, dynamic> data) async {
    await client.from('users').upsert(data);
  }

  /// Get user profile.
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  /// Update user profile fields.
  static Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    await client
        .from('users')
        .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  // Plants

  /// Get all plants for user.
  static Future<List<Map<String, dynamic>>> getPlants(String userId) async {
    final response = await client
        .from('plants')
        .select()
        .eq('user_id', userId)
        .eq('is_archived', false)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get single plant.
  static Future<Map<String, dynamic>?> getPlant(String plantId) async {
    return await client.from('plants').select().eq('id', plantId).maybeSingle();
  }

  /// Create plant.
  static Future<Map<String, dynamic>> createPlant(
      Map<String, dynamic> data) async {
    final response = await client.from('plants').insert(data).select().single();
    return response;
  }

  /// Update plant.
  static Future<void> updatePlant(
    String plantId,
    Map<String, dynamic> updates,
  ) async {
    await client
        .from('plants')
        .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', plantId);
  }

  /// Archive plant (soft delete).
  static Future<void> archivePlant(String plantId) async {
    await updatePlant(plantId, {'is_archived': true});
  }

  // Scans

  /// Create scan record directly in table.
  static Future<Map<String, dynamic>> createScan(Map<String, dynamic> data) async {
    final response = await client.from('scans').insert(data).select().single();
    return response;
  }

  /// Create scan through idempotent Edge Function path.
  static Future<Map<String, dynamic>> createScanViaFunction(
    Map<String, dynamic> payload,
  ) async {
    return invokeFunction(
      'create-scan',
      body: payload,
    );
  }

  /// Get scan by ID.
  static Future<Map<String, dynamic>?> getScan(String scanId) async {
    return await client.from('scans').select().eq('id', scanId).maybeSingle();
  }

  /// Get scans for a plant.
  static Future<List<Map<String, dynamic>>> getScansForPlant(String plantId) async {
    final response = await client
        .from('scans')
        .select()
        .eq('plant_id', plantId)
        .order('captured_at_utc', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get all scans for user.
  static Future<List<Map<String, dynamic>>> getAllScans(String userId) async {
    final response = await client
        .from('scans')
        .select()
        .eq('user_id', userId)
        .order('captured_at_utc', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get scan processing status.
  static Future<String?> getScanStatus(String scanId) async {
    final response = await client
        .from('scans')
        .select('processing_status')
        .eq('id', scanId)
        .maybeSingle();
    return response?['processing_status'] as String?;
  }

  /// Subscribe to scan updates (Realtime).
  static RealtimeChannel subscribeScanUpdates(
    String scanId,
    void Function(Map<String, dynamic> payload) onUpdate,
  ) {
    return client
        .channel('scan-$scanId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'scans',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: scanId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  // Scan jobs

  /// Get jobs for a scan.
  static Future<List<Map<String, dynamic>>> getScanJobs(String scanId) async {
    final response = await client
        .from('scan_jobs')
        .select()
        .eq('scan_id', scanId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(response);
  }

  // Diagnosis feedback

  /// Submit diagnosis feedback.
  static Future<void> submitFeedback(Map<String, dynamic> data) async {
    await client.from('diagnosis_feedback').insert(data);
  }

  // Care events

  /// Create care event.
  static Future<void> createCareEvent(Map<String, dynamic> data) async {
    await client.from('care_events').insert(data);
  }

  /// Log analytics event.
  static Future<void> logAnalyticsEvent({
    required String eventName,
    Map<String, dynamic> eventContext = const {},
  }) async {
    final userId = currentUserId;
    await client.from('analytics_events').insert({
      'user_id': userId,
      'event_name': eventName,
      'event_context': eventContext,
      'created_at_utc': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Get care events for a plant.
  static Future<List<Map<String, dynamic>>> getCareEvents(String plantId) async {
    final response = await client
        .from('care_events')
        .select()
        .eq('plant_id', plantId)
        .order('occurred_at_utc', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(response);
  }

  // Intervention recommendations

  /// Get intervention recommendations for a scan.
  static Future<List<Map<String, dynamic>>> getInterventionRecommendationsForScan(
    String scanId,
  ) async {
    final response = await client
        .from('intervention_recommendations')
        .select()
        .eq('scan_id', scanId)
        .order('recommended_at_utc', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get intervention recommendations for a plant.
  static Future<List<Map<String, dynamic>>> getInterventionRecommendationsForPlant(
    String plantId,
  ) async {
    final response = await client
        .from('intervention_recommendations')
        .select()
        .eq('plant_id', plantId)
        .order('recommended_at_utc', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Intervention outcomes

  /// Get outcomes for an intervention recommendation.
  static Future<List<Map<String, dynamic>>>
      getInterventionOutcomesForIntervention(String interventionId) async {
    final response = await client
        .from('intervention_outcomes')
        .select()
        .eq('intervention_id', interventionId)
        .order('recorded_at_utc', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get outcomes for a plant.
  static Future<List<Map<String, dynamic>>> getInterventionOutcomesForPlant(
    String plantId,
  ) async {
    final response = await client
        .from('intervention_outcomes')
        .select()
        .eq('plant_id', plantId)
        .order('recorded_at_utc', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Submit intervention outcome through the dedicated Edge Function.
  static Future<Map<String, dynamic>> submitInterventionOutcome({
    required String interventionId,
    required String adherenceStatus,
    required String outcomeStatus,
    String? adherenceNotes,
    String? outcomeNotes,
    double? outcomeConfidence,
    String? followupScanId,
    double? followupImageQualityScore,
  }) async {
    return invokeFunction(
      'submit-intervention-outcome',
      body: {
        'intervention_id': interventionId,
        'adherence_status': adherenceStatus,
        'outcome_status': outcomeStatus,
        'adherence_notes': adherenceNotes,
        'outcome_notes': outcomeNotes,
        'outcome_confidence': outcomeConfidence,
        'followup_scan_id': followupScanId,
        'followup_image_quality_score': followupImageQualityScore,
      },
    );
  }

  // Follow-up missions

  /// Get follow-up missions for user, optionally filtered by plant/status.
  static Future<List<Map<String, dynamic>>> getFollowupMissions({
    required String userId,
    String? plantId,
    String? status,
  }) async {
    var query = client.from('followup_missions').select().eq('user_id', userId);

    if (plantId != null) {
      query = query.eq('plant_id', plantId);
    }
    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query.order('due_at_utc');
    return List<Map<String, dynamic>>.from(response);
  }

  // Edge Functions

  /// Invoke a Supabase Edge Function.
  static Future<Map<String, dynamic>> invokeFunction(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    final response = await client.functions.invoke(
      functionName,
      body: body,
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw Exception('Invalid response from function $functionName');
  }
}
