import 'package:zoe_remind/memory/companion_facts.dart';

/// Isang long-term memory ni Zoe (memories table).
/// source: 'chat' = natutunan sa usapan, 'user' = sinabi mo mismo.
/// kind (Level 3): nickname, style, stress_help, win, routine, general.
/// value: "AC" (nickname), "diretso" (style), "listen" (stress_help); null sa iba.
class MemoryItem {
  const MemoryItem({
    this.id,
    required this.content,
    this.source = 'chat',
    this.importance = 3,
    this.kind = FactKind.general,
    this.value,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String content;
  final String source;
  final int importance;
  final FactKind kind;
  final String? value;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get fromChat => source == 'chat';

  static MemoryItem fromRow(Map<String, Object?> row) => MemoryItem(
        id: row['id'] as int?,
        content: row['content'] as String,
        source: (row['source'] as String?) ?? 'chat',
        importance: (row['importance'] as int?) ?? 3,
        kind: FactKind.fromDb(row['kind'] as String?),
        value: row['value'] as String?,
        createdAt: DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
        updatedAt: DateTime.tryParse(row['updated_at'] as String) ?? DateTime.now(),
      );
}