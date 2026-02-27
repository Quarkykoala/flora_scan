import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../services/care_chat_service.dart';
import 'auth_provider.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isSending;
  final String? selectedPlantId;

  const ChatState({
    this.messages = const [],
    this.isSending = false,
    this.selectedPlantId,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    String? selectedPlantId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      selectedPlantId: selectedPlantId ?? this.selectedPlantId,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._ref) : super(const ChatState());

  final Ref _ref;

  void setPlantId(String? plantId) {
    state = state.copyWith(selectedPlantId: plantId);
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    final userMessage = ChatMessage(
      role: 'user',
      text: trimmed,
      createdAt: DateTime.now(),
    );
    final nextMessages = [...state.messages, userMessage];
    state = state.copyWith(messages: nextMessages, isSending: true);

    try {
      final localeCode =
          _ref.read(userProfileProvider).valueOrNull?.localeCode ?? 'en';
      final response = await CareChatService.sendMessage(
        messages: nextMessages,
        plantId: state.selectedPlantId,
        locale: localeCode,
      );

      final assistantText = [
        response.answer,
        if (response.suggestedActions.isNotEmpty)
          'Actions: ${response.suggestedActions.join(' | ')}',
      ].join('\n');

      state = state.copyWith(
        isSending: false,
        messages: [
          ...nextMessages,
          ChatMessage(
            role: 'assistant',
            text: assistantText,
            createdAt: DateTime.now(),
          ),
        ],
      );
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        messages: [
          ...nextMessages,
          ChatMessage(
            role: 'assistant',
            text: 'Assistant failed: $e',
            createdAt: DateTime.now(),
          ),
        ],
      );
    }
  }

  void clear() {
    state = state.copyWith(messages: const []);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
