// lib/models/chat_message.dart

enum ChatRole { user, assistant }

class ChatMessage {
  final ChatRole role;
  final String content;
  final DateTime timestamp;
  final String? navigateTo; // route name suggested by the assistant, if any
  final String? navigateReason;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.navigateTo,
    this.navigateReason,
  });

  /// Compact form sent as conversation history to the Cloud Function —
  /// only role + content, no local metadata.
  Map<String, String> toHistoryEntry() => {
    'role': role == ChatRole.user ? 'user' : 'assistant',
    'content': content,
  };
}