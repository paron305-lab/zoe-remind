/// Saan galing ang nahanap.
enum RetrievalSource { note, memory }

/// Isang note o memory na pwedeng isagot (galing sa SearchRepository).
class RetrievalDoc {
  const RetrievalDoc({
    required this.source,
    required this.id,
    required this.title,
    required this.text,
    required this.updatedAt,
    this.pinned = false,
    this.importance = 3,
  });

  final RetrievalSource source;

  /// id sa notes / memories table.
  final int id;

  /// Note: ang title. Memory: unang 60 letra ng content.
  final String title;

  /// Note: ang content (o title kung walang content). Memory: ang content.
  final String text;
  final DateTime updatedAt;

  /// Notes lang.
  final bool pinned;

  /// Memories lang (1–5).
  final int importance;

  bool get isMemory => source == RetrievalSource.memory;

  static String shortTitle(String text) {
    final t = text.trim().split('\n').first.trim();
    return t.length <= 60 ? t : '${t.substring(0, 60)}…';
  }

  factory RetrievalDoc.noteRow(Map<String, Object?> r) {
    final title = (r['title'] as String?) ?? '';
    final content = ((r['content'] as String?) ?? '').trim();
    return RetrievalDoc(
      source: RetrievalSource.note,
      id: r['id'] as int,
      title: title,
      text: content.isEmpty ? title : content,
      pinned: (r['pinned'] as int? ?? 0) == 1,
      updatedAt: DateTime.tryParse((r['updated_at'] as String?) ?? '') ?? DateTime(2000),
    );
  }

  factory RetrievalDoc.memoryRow(Map<String, Object?> r) {
    final content = ((r['content'] as String?) ?? '').trim();
    return RetrievalDoc(
      source: RetrievalSource.memory,
      id: r['id'] as int,
      title: shortTitle(content),
      text: content,
      importance: (r['importance'] as int?) ?? 3,
      updatedAt: DateTime.tryParse((r['updated_at'] as String?) ?? '') ?? DateTime(2000),
    );
  }
}

/// Isang resulta ng Retriever, may score.
class RetrievalHit {
  const RetrievalHit({
    required this.doc,
    required this.score,
    required this.matched,
    required this.matchedInTitle,
  });

  final RetrievalDoc doc;
  final int score;

  /// Ilang salita ng tanong ang tumama.
  final int matched;

  /// Ilan doon ang nasa title.
  final int matchedInTitle;

  @override
  String toString() => '${doc.source.name}#${doc.id} "${doc.title}" score $score';
}