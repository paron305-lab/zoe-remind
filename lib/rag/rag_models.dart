/// Saan galing ang nahanap.
/// R4: kasama na ang reminders at tasks ("search everything").
enum RetrievalSource { note, memory, reminder, task }

/// R2: gaano kasigurado si Zoe sa sagot.
enum RetrievalConfidence {
  /// Halos lahat ng salita ng tanong ay tumama → sinasagot nang diretso
  /// ("Ito ang nakita ko sa notes mo: …").
  strong,

  /// May tumama pero kulang, o halos magkapantay ang dalawang sagot →
  /// "Baka ito? 🤔 …". Ipinapakita pa rin ang note, pero hindi ipinipilit.
  maybe,
}

/// Isang note, memory, reminder o task na pwedeng isagot
/// (galing sa SearchRepository).
class RetrievalDoc {
  const RetrievalDoc({
    required this.source,
    required this.id,
    required this.title,
    required this.text,
    required this.updatedAt,
    this.pinned = false,
    this.importance = 3,
    this.date,
    this.time,
    this.repeat,
    this.done = false,
  });

  final RetrievalSource source;

  /// id sa notes / memories / reminders / tasks table.
  final int id;

  /// Note / reminder / task: ang title. Memory: unang 60 letra ng content.
  final String title;

  /// Note: ang content (o title kung walang content). Memory: ang content.
  /// R4 — reminder: walang laman (title lang ang meron). Task: ang
  /// description (walang laman kung wala).
  final String text;
  final DateTime updatedAt;

  /// Notes lang.
  final bool pinned;

  /// Memories lang (1–5).
  final int importance;

  /// R4 — reminders / tasks lang: 'yyyy-MM-dd' at 'HH:mm' (null = wala).
  final String? date;
  final String? time;

  /// R4 — reminders lang: 'none' / 'daily' / 'weekly' / 'monthly'.
  final String? repeat;

  /// R4 — task na tapos, o one-time reminder na na-done.
  final bool done;

  bool get isMemory => source == RetrievalSource.memory;
  bool get isNote => source == RetrievalSource.note;

  /// R4: reminder o task. Walang "body" ang mga ito (title lang ang
  /// mahalaga), kaya sa Retriever: walang title bonus at walang
  /// "maikling note" bonus — para hindi sila laging nananalo sa note.
  bool get isItem => source == RetrievalSource.reminder || source == RetrievalSource.task;

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

  /// R4: row ng reminders table (id, title, date, time, repeat, status, updated_at).
  factory RetrievalDoc.reminderRow(Map<String, Object?> r) {
    final repeat = (r['repeat'] as String?) ?? 'none';
    return RetrievalDoc(
      source: RetrievalSource.reminder,
      id: r['id'] as int,
      title: ((r['title'] as String?) ?? '').trim(),
      text: '',
      date: r['date'] as String?,
      time: r['time'] as String?,
      repeat: repeat,
      // Ang umuulit na reminder ay hindi kailanman "tapos na" nang buo.
      done: repeat == 'none' && r['status'] == 'done',
      updatedAt: DateTime.tryParse((r['updated_at'] as String?) ?? '') ?? DateTime(2000),
    );
  }

  /// R4: row ng tasks table (id, title, description, date, time, status,
  /// updated_at, created_at).
  factory RetrievalDoc.taskRow(Map<String, Object?> r) {
    final updated = (r['updated_at'] as String?) ?? (r['created_at'] as String?) ?? '';
    return RetrievalDoc(
      source: RetrievalSource.task,
      id: r['id'] as int,
      title: ((r['title'] as String?) ?? '').trim(),
      text: ((r['description'] as String?) ?? '').trim(),
      date: r['date'] as String?,
      time: r['time'] as String?,
      done: r['status'] == 'done',
      updatedAt: DateTime.tryParse(updated) ?? DateTime(2000),
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
/// (bihirang salita = mas mabigat). R4: kasama ang reminders + tasks.
///
///   [docCount] = ilang notes (+ memories kung ON) (+ reminders + tasks) lahat.
///   [docFreq]  = ilan ang may bawat salita, kapareho ng order ng TermGroup.
///                Walang laman = hindi alam (kukuwentahin mula sa mga kandidato).
///
/// Galing sa SearchRepository.corpusStats (COUNT lang, FTS4; reminders +
/// tasks ay binibilang mula sa nabasa na ng candidates).
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

  /// Ilan doon ang nasa title. (R4: laging 0 sa reminder / task.)
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