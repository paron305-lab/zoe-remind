/// Isang chat session kay Zoe (ai_conversations), para sa history list.
class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.title,
    required this.messageCount,
    required this.lastMessage,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final int messageCount;
  final String lastMessage;
  final DateTime updatedAt;
}

/// Isang mensahe sa ai_messages. role = 'user' o 'zoe'.
class ChatMessage {
  const ChatMessage({
    this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final int? id;
  final int conversationId;
  final String role;
  final String content;
  final DateTime createdAt;

  bool get fromZoe => role == 'zoe';

  static ChatMessage fromRow(Map<String, Object?> row) => ChatMessage(
        id: row['id'] as int?,
        conversationId: row['conversation_id'] as int,
        role: row['role'] as String,
        content: row['content'] as String,
        createdAt: DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
      );
}