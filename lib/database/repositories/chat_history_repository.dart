import 'package:flutter/foundation.dart';
import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/models/chat_message.dart';

/// Ang tanging nagbabasa/nagsusulat ng ai_conversations + ai_messages.
/// Zoe Chat (later) → startConversation() + addMessage().
/// Settings › Privacy & Memory → count, list, clearAll().
class ChatHistoryRepository {
  static const _conv = StorageConstants.conversationsTable;
  static const _msg = StorageConstants.messagesTable;

  /// Tumataas kada may nabago, para mag-refresh ang Settings / Chat.
  static final changes = ValueNotifier<int>(0);

  String _now() => DateTime.now().toIso8601String();

  Future<int> startConversation({String? title}) async {
    final db = await ZoeDatabase.instance.database;
    final now = _now();
    final id = await db.insert(_conv, {'title': title, 'created_at': now, 'updated_at': now});
    changes.value++;
    return id;
  }

  /// role = 'user' o 'zoe'.
  Future<int> addMessage(int conversationId, String role, String content) async {
    final db = await ZoeDatabase.instance.database;
    final now = _now();
    final id = await db.transaction((txn) async {
      final id = await txn.insert(_msg, {
        'conversation_id': conversationId,
        'role': role,
        'content': content,
        'created_at': now,
      });
      await txn.update(_conv, {'updated_at': now},
          where: 'id = ?', whereArgs: [conversationId]);
      return id;
    });
    changes.value++;
    return id;
  }

  Future<int> messageCount() async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM $_msg');
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Pinakabago sa taas. Title = sariling title o unang mensahe ng user.
  Future<List<ChatConversation>> conversations() async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT c.id, c.title, c.updated_at,
             (SELECT COUNT(*) FROM $_msg m WHERE m.conversation_id = c.id) AS n,
             (SELECT content FROM $_msg m WHERE m.conversation_id = c.id
                AND m.role = 'user' ORDER BY m.created_at ASC LIMIT 1) AS first_user,
             (SELECT content FROM $_msg m WHERE m.conversation_id = c.id
                ORDER BY m.created_at DESC LIMIT 1) AS last_msg
      FROM $_conv c
      ORDER BY c.updated_at DESC
    ''');
    return [
      for (final r in rows)
        if (((r['n'] as int?) ?? 0) > 0)
          ChatConversation(
            id: r['id'] as int,
            title: (r['title'] as String?)?.trim().isNotEmpty == true
                ? r['title'] as String
                : ((r['first_user'] as String?) ?? 'Chat with Zoe'),
            messageCount: (r['n'] as int?) ?? 0,
            lastMessage: (r['last_msg'] as String?) ?? '',
            updatedAt: DateTime.tryParse(r['updated_at'] as String) ?? DateTime.now(),
          ),
    ];
  }

  Future<List<ChatMessage>> messages(int conversationId) async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.query(_msg,
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'created_at ASC, id ASC');
    return rows.map(ChatMessage.fromRow).toList();
  }

  Future<void> deleteConversation(int id) async {
    final db = await ZoeDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete(_msg, where: 'conversation_id = ?', whereArgs: [id]);
      await txn.delete(_conv, where: 'id = ?', whereArgs: [id]);
    });
    changes.value++;
  }

  /// Burahin lahat ng chat. Hindi ginagalaw ang tasks/reminders/notes.
  Future<void> clearAll() async {
    final db = await ZoeDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete(_msg);
      await txn.delete(_conv);
    });
    changes.value++;
  }
}