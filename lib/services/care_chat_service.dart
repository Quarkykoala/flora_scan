import '../models/chat_message.dart';
import 'supabase_service.dart';

class CareChatResponse {
  final String answer;
  final String urgency;
  final List<String> suggestedActions;
  final double confidence;

  const CareChatResponse({
    required this.answer,
    required this.urgency,
    required this.suggestedActions,
    required this.confidence,
  });

  factory CareChatResponse.fromJson(Map<String, dynamic> json) {
    return CareChatResponse(
      answer: json['answer'] as String? ?? '',
      urgency: json['urgency'] as String? ?? 'low',
      suggestedActions: (json['suggested_actions'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

class CareChatService {
  CareChatService._();

  static Future<CareChatResponse> sendMessage({
    required List<ChatMessage> messages,
    String? plantId,
    String locale = 'en',
  }) async {
    final result = await SupabaseService.invokeFunction(
      'care-chat',
      body: {
        'plant_id': plantId,
        'locale': locale,
        'messages': messages.map((m) => m.toJson()).toList(),
      },
    );
    return CareChatResponse.fromJson(result);
  }
}
