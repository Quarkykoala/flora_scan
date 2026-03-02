import 'supabase_service.dart';

class AnalyticsService {
  AnalyticsService._();

  static Future<void> track(
    String eventName, {
    Map<String, dynamic> context = const {},
  }) async {
    try {
      await SupabaseService.invokeFunction(
        'log-analytics-event',
        body: {
          'event_name': eventName,
          'event_context': context,
        },
      );
    } catch (_) {
      // Fallback to direct table insert if edge function is unavailable.
      await SupabaseService.logAnalyticsEvent(
        eventName: eventName,
        eventContext: context,
      );
    }
  }
}
