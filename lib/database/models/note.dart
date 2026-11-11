/// Saan galing ang note.
/// typed = tinype ng user sa Notes tab.
/// zoe   = sine-save ni Zoe galing sa chat ("Zoe, i-note mo ito…").
enum NoteSource {
  typed,
  zoe;

  static NoteSource fromName(String? s) => s == 'zoe' ? NoteSource.zoe : NoteSource.typed;
}

/// One row of the `notes` table.
/// Times are ISO-8601 strings (same as tasks/reminders).
class Note {
  static const maxTitle = 120;
  static const maxContent = 10000;

  final int? id;
  final String title;
  final String content;
  final NoteSource source;
  final bool pinned;
  final String createdAt;
  final String updatedAt;

  const Note({
    this.id,
    required this.title,
    this.content = '',
    this.source = NoteSource.typed,
    this.pinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get fromZoe => source == NoteSource.zoe;

  DateTime get createdAtTime => DateTime.tryParse(createdAt) ?? DateTime.now();
  DateTime get updatedAtTime => DateTime.tryParse(updatedAt) ?? createdAtTime;

  /// Na-edit pagkatapos gawin (mahigit 1 minuto ang pagitan).
  bool get wasEdited => updatedAtTime.difference(createdAtTime).inMinutes >= 1;

  /// Kapag walang title, ang unang linya ng content ang gagamitin.
  static String titleFrom(String title, String content) {
    final t = title.trim();
    if (t.isNotEmpty) return t;
    final firstLine = content.trim().split('\n').first.trim();
    if (firstLine.isEmpty) return 'Untitled note';
    return firstLine.length <= 60 ? firstLine : '${firstLine.substring(0, 60)}…';
  }

  Note copyWith({
    int? id,
    String? title,
    String? content,
    NoteSource? source,
    bool? pinned,
    String? updatedAt,
  }) =>
      Note(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content ?? this.content,
        source: source ?? this.source,
        pinned: pinned ?? this.pinned,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'source': source.name,
        'pinned': pinned ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Note.fromMap(Map<String, Object?> m) => Note(
        id: m['id'] as int?,
        title: (m['title'] as String?) ?? '',
        content: (m['content'] as String?) ?? '',
        source: NoteSource.fromName(m['source'] as String?),
        pinned: (m['pinned'] as int? ?? 0) == 1,
        createdAt: m['created_at'] as String,
        updatedAt: (m['updated_at'] as String?) ?? (m['created_at'] as String),
      );
}