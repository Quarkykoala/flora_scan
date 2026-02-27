class ChatMessage {
  final String role; // user | assistant
  final String text;
  final DateTime createdAt;

  const ChatMessage({
    required this.role,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
      };
}
