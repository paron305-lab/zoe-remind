/// Saan galing ang nahanap.
enum RetrievalSource { note, memory }

/// R2: gaano kasigurado si Zoe sa sagot.
enum RetrievalConfidence {
  /// Halos lahat ng salita ng tanong ay tumama → sinasagot nang diretso
  /// ("Ito ang nakita ko sa notes mo: …").
  strong,

  /// May tumama pero kulang, o halos magkapantay ang dalawang sagot →
  /// "Baka ito? 🤔 …". Ipinapakita pa rin ang note, pero hindi ipinipilit.
  maybe,
}

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

/// R2: laki ng lahat ng notes + memories, para sa IDF ng Retriever
/// (bihirang salita = mas mabigat).
///
///   [docCount] = ilang notes (+ memories kung ON) lahat.
///   [docFreq]  = ilan ang may bawat salita, kapareho ng order ng TermGroup.
///                Walang laman = hindi alam (kukuwentahin mula sa mga kandidato).
///
/// Galing sa SearchRepository.corpusStats (COUNT lang, FTS4).
class CorpusStats {
  const CorpusStats({required this.docCount, this.docFreq = const []});

  /// Hindi alam ang laki (walang FTS4, o fake na repository sa test):
  /// mga kandidato lang ang alam, kaya tinatantiya ng Retriever.
  static const unknown = CorpusStats(docCount: 0);

  final int docCount;
  final List<int> docFreq;

  bool get isUnknown => docCount <= 0;

  @override
  String toString() => 'CorpusStats(N=$docCount, df=$docFreq)';
}

/// Isang resulta ng Retriever, may score at kumpiyansa.
class RetrievalHit {
  const RetrievalHit({
    required this.doc,
    required this.score,
    required this.matched,
    required this.matchedInTitle,
    this.coverage = 1,
    this.confidence = RetrievalConfidence.strong,
  });

  final RetrievalDoc doc;

  /// R2: BM25-style (IDF × dalas, may title / magkatabi / bago / pinned).
  /// Para sa pag-aayos lang ng pagkakasunod — hindi pare-pareho ang laki
  /// sa bawat tanong.
  final double score;

  /// Ilang salita ng tanong ang tumama.
  final int matched;

  /// Ilan doon ang nasa title.
  final int matchedInTitle;

  /// R2: 0–1 — gaano kalaking bahagi ng tanong (ayon sa bigat ng salita) ang
  /// nasa doc. 1 = lahat ng salita tumama.
  final double coverage;

  /// R2: strong → diretsong sagot · maybe → "Baka ito? 🤔".
  final RetrievalConfidence confidence;

  bool get isSure => confidence == RetrievalConfidence.strong;

  @override
  String toString() => '${doc.source.name}#${doc.id} "${doc.title}" '
      'score ${score.toStringAsFixed(2)} · ${(coverage * 100).round()}% · ${confidence.name}';
}