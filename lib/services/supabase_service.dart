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
        .createSignedUrl(path, 3600); // 1 hour expiry
  }

  // ── Users ──

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

  // ── Plants ──

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
    return await client
        .from('plants')
        .select()
        .eq('id', plantId)
        .maybeSingle();
  }

  /// Create plant.
  static Future<Map<String, dynamic>> createPlant(
      Map<String, dynamic> data) async {
    final response =
        await client.from('plants').insert(data).select().single();
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

  // ── Scans ──

  /// Create scan record.
  static Future<Map<String, dynamic>> createScan(
      Map<String, dynamic> data) async {
    final response =
        await client.from('scans').insert(data).select().single();
    return response;
  }

  /// Get scan by ID.
  static Future<Map<String, dynamic>?> getScan(String scanId) async {
    return await client
        .from('scans')
        .select()
        .eq('id', scanId)
        .maybeSingle();
  }

  /// Get scans for a plant.
  static Future<List<Map<String, dynamic>>> getScansForPlant(
      String plantId) async {
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

  // ── Scan Jobs ──

  /// Get jobs for a scan.
  static Future<List<Map<String, dynamic>>> getScanJobs(
      String scanId) async {
    final response = await client
        .from('scan_jobs')
        .select()
        .eq('scan_id', scanId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(response);
  }

  // ── Diagnosis Feedback ──

  /// Submit diagnosis feedback.
  static Future<void> submitFeedback(Map<String, dynamic> data) async {
    await client.from('diagnosis_feedback').insert(data);
  }

  // ── Care Events ──

  /// Create care event.
  static Future<void> createCareEvent(Map<String, dynamic> data) async {
    await client.from('care_events').insert(data);
  }

  /// Get care events for a plant.
  static Future<List<Map<String, dynamic>>> getCareEvents(
      String plantId) async {
    final response = await client
        .from('care_events')
        .select()
        .eq('plant_id', plantId)
        .order('occurred_at_utc', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(response);
  }

  // ── Edge Functions ──

  /// Invoke a Supabase Edge Function.
  static Future<Map<String, dynamic>> invokeFunction(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    final response = await client.functions.invoke(
      functionName,
      body: body,
    );
    return response.data as Map<String, dynamic>;
  }
}
