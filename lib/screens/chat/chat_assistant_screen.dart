import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/plant_provider.dart';
import '../../services/analytics_service.dart';
import '../../widgets/glassmorphic_card.dart';

class ChatAssistantScreen extends ConsumerStatefulWidget {
  const ChatAssistantScreen({super.key});

  @override
  ConsumerState<ChatAssistantScreen> createState() => _ChatAssistantScreenState();
}

class _ChatAssistantScreenState extends ConsumerState<ChatAssistantScreen> {
  final _controller = TextEditingController();
  bool _lockedTracked = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final plantsAsync = ref.watch(plantsProvider);
    final isPremium = ref.watch(isPremiumProvider);

    if (!isPremium) {
      if (!_lockedTracked) {
        _lockedTracked = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AnalyticsService.track(
            'assistant_locked_viewed',
            context: {'surface': 'assistant'},
          );
        });
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Plant Assistant')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GlassmorphicCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.lock_outline, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Premium Feature Locked',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text('Real-time AI care assistant is available on Premium.'),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton(
            onPressed: () {
              AnalyticsService.track(
                'assistant_upgrade_cta_tapped',
                context: {'surface': 'assistant_lock'},
              );
            },
            child: const Text('Upgrade to Premium'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => ref.read(chatProvider.notifier).clear(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: plantsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (plants) => GlassmorphicCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: chat.selectedPlantId,
                    hint: const Text('Assistant context: any plant'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Any plant'),
                      ),
                      ...plants.map(
                        (p) => DropdownMenuItem<String?>(
                          value: p.id,
                          child: Text(p.nickname),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      ref.read(chatProvider.notifier).setPlantId(value);
                    },
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: chat.messages.length,
              itemBuilder: (context, index) {
                final message = chat.messages[chat.messages.length - 1 - index];
                final isUser = message.role == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: GlassmorphicCard(
                      backgroundColor: isUser
                          ? Colors.green.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.20),
                      child: Text(message.text),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Ask about care, diagnosis, or recovery...',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: chat.isSending ? null : _send,
                    icon: chat.isSending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _send() {
    final text = _controller.text;
    _controller.clear();
    ref.read(chatProvider.notifier).send(text);
  }
}
