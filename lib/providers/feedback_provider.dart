import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/diagnosis_feedback.dart';
import '../services/supabase_service.dart';

/// Diagnosis feedback actions notifier.
class FeedbackNotifier extends StateNotifier<AsyncValue<void>> {
  FeedbackNotifier() : super(const AsyncValue.data(null));

  static const _uuid = Uuid();

  /// Submit diagnosis feedback.
  Future<void> submitFeedback({
    required String scanId,
    required FeedbackType feedbackType,
    String? feedbackNote,
  }) async {
    state = const AsyncValue.loading();
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception('Not authenticated');

      await SupabaseService.submitFeedback({
        'id': _uuid.v4(),
        'scan_id': scanId,
        'user_id': userId,
        'feedback_type': feedbackType.apiValue,
        'feedback_note': feedbackNote,
      });

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final feedbackNotifierProvider =
    StateNotifierProvider<FeedbackNotifier, AsyncValue<void>>((ref) {
  return FeedbackNotifier();
});
