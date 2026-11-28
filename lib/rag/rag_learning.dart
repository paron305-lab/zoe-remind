import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:zoe_remind/database/repositories/search_log_repository.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/rag_session.dart';
import 'package:zoe_remind/rag/retriever.dart';
import 'package:zoe_remind/rag/search_scope.dart';
import 'package:zoe_remind/rag/stemmer.dart';

/// R6 — natututo si Zoe sa phone (walang training ng model, walang internet).
///
///   1. search_log      — bawat paghahanap sa chat: tanong, hinanap, ilan ang
///                        nahanap, at ang nangyari (wala / ipinakita / "oo" /
///                        "hindi yan" / binuksan). Pinapalitan ang SearchMisses
///                        na nasa RAM lang (Developer › Search index).
///   2. learned_terms   — natututong salita: pumalya ang "ano pw ng net?" →
///                        nag-rephrase ng "ano wifi password ko?" → tumama nang
///                        sigurado → `net ↔ wifi`. Ginagamit lang pagkatapos ng
///                        [minCount] beses (kaya hindi natututo sa isang aksidente).
///   3. search_feedback — "oo" / binuksan / pinindot = maliit na dagdag sa score
///                        ng item; "hindi yan" = bawas ([DocFeedback.boost]).
///   4. lakas ng memory — memories.use_count + last_used_at (para sa R7 Context
///                        Pack: madalas gamitin = mas mahalaga).
///
/// Lahat sa phone lang, may limit (search_log: 500 rows / 60 araw), at
/// nabubura sa "Burahin lahat". Nakikita at nabubura sa Developer.
///
/// Ligtas ang pagkatuto ng salita ([pairFrom] + mga bantay sa [_learnFrom]):
///   • isang salita lang ang naiba sa magkabilang tanong (1 ↔ 1),
///   • ang bagong salita ay nasa sagot, ang luma ay WALA,
///   • ang lumang salita ay hindi kilala (walang kahit isang item na may ito),
///   • hindi tao ("mama" ≠ "papa"), hindi oras / uri / mahinang salita,
///   • sa loob ng [failWindow] pagkatapos pumalya.
///
/// Pure ang mga static ([pairFrom], [appearsIn], [LearnedSnapshot.build]) —
/// nate-test sa test/rag/rag_learning_test.dart. Ang [RagLearning] mismo ay
/// may [LearningStore]: SQLite sa app ([SearchLogRepository]), RAM sa test
/// ([MemoryLearningStore]).
class RagLearning {
  RagLearning(LearningStore store, {DateTime Function()? clock})
      : _store = store,
        _clock = clock ?? DateTime.now;

  RagLearning._off()
      : _store = null,
        _clock = DateTime.now;

  /// Ang ginagamit ng app (SQLite).
  static final instance = RagLearning(SearchLogRepository());

  /// Walang ginagawa (fake na Retriever sa test, o kapag ayaw ng learning).
  static final disabled = RagLearning._off();

  /// Ilang beses dapat matutunan ang parehong salita bago gamitin.
  static const minCount = 2;

  /// Gaano katagal pagkatapos pumalya pwedeng matuto mula sa rephrase.
  static const failWindow = Duration(minutes: 3);

  final LearningStore? _store;
  final DateTime Function() _clock;

  /// Nagbabago tuwing may natutunan / binura (para sa Developer card).
  final changes = ValueNotifier<int>(0);

  /// Naka-cache na natutunan (nabubura kapag may bago).
  LearnedSnapshot? _snap;

  /// Ang huling pumalyang paghahanap (wala / hindi sigurado / "hindi yan").
  _Fail? _fail;

  /// id ng huling search_log row (para sa "oo" / "hindi yan" / binuksan).
  int? _logId;

  /// Mga item na nakikita ngayon sa huling sagot (para sa pinindot na row).
  final Set<String> _shown = {};

  bool get enabled => _store != null;

  /// 'note#5', 'memory#2', 'reminder#9', 'task#3' (pareho ng RagSession.keyOf).
  static String keyOf(RetrievalDoc d) => '${d.source.name}#${d.id}';

  // ───────────────────────── Para sa Retriever ─────────────────────────

  /// Mga aktibong natutunang salita + feedback boost. Pumalya → walang laman
  /// (gumagana pa rin ang search, gaya ng dati).
  Future<LearnedSnapshot> snapshot() async {
    final store = _store;
    if (store == null) return LearnedSnapshot.empty;
    final cached = _snap;
    if (cached != null) return cached;
    try {
      final snap = LearnedSnapshot.build(await store.learnedTerms(), await store.feedback());
      _snap = snap;
      return snap;
    } catch (e) {
      debugPrint('RagLearning snapshot failed: $e');
      return LearnedSnapshot.empty;
    }
  }

  // ───────────────────────── Para sa chat brain ─────────────────────────

  /// Bagong paghahanap sa chat (pagkatapos ng Retriever).
  /// [question] = ang tanong ng user (malinis). [query] = ang talagang hinanap.
  /// [isKnown] = may item bang may salitang ito? (para hindi matuto ng
  /// salitang kilala na, hal. "mama" → "papa").
  Future<void> searched({
    required String question,
    required String query,
    required List<RetrievalHit> hits,
    Future<bool> Function(String word)? isKnown,
  }) async {
    final store = _store;
    if (store == null) return;
    final now = _clock();
    final top = hits.isEmpty ? null : hits.first;
    final sure = top?.isSure ?? false;
    _shown
      ..clear()
      ..addAll(hits.take(3).map((h) => keyOf(h.doc)));
    final fail = _fail;
    _fail = sure ? null : _Fail(query, now);
    try {
      _logId = await store.addLog(SearchLogEntry(
        question: question,
        query: query,
        hitCount: hits.length,
        topKey: top == null ? null : keyOf(top.doc),
        sure: sure,
        outcome: top == null ? SearchOutcome.none : SearchOutcome.shown,
        at: now,
      ));
      if (top != null && top.doc.isMemory) await store.memoryUsed(id: top.doc.id);
      if (sure && fail != null && fail.isFreshAt(now) && fail.query != query) {
        await _learnFrom(fail.query, query, top!.doc, isKnown);
      }
    } catch (e) {
      debugPrint('RagLearning searched failed: $e');
    }
    changes.value++;
  }

  /// "yung isa pa" / "hindi yan" → ito na ang mga nakikitang item.
  void showing(Iterable<RetrievalHit> hits) {
    if (_store == null) return;
    _shown
      ..clear()
      ..addAll(hits.map((h) => keyOf(h.doc)));
  }

  /// "oo" / "yan nga" / "tama" → tama ang sagot.
  Future<void> confirmed(String key) async {
    _fail = null;
    await _feedback(key, good: 1, outcome: SearchOutcome.confirmed);
  }

  /// "hindi yan" → mali ang sagot. Ang susunod na sigurado (rephrase) ay
  /// pwedeng pagmulan ng bagong salita.
  Future<void> rejected(String key, {required String query}) async {
    _fail = _Fail(query, _clock());
    await _feedback(key, bad: 1, outcome: SearchOutcome.rejected);
  }

  /// "buksan mo" → binuksan ang item.
  Future<void> opened(String key) async {
    _fail = null;
    await _feedback(key, good: 1, outcome: SearchOutcome.opened);
  }

  /// Pinindot ang row / "Buong note →" sa answer card. Binibilang lang kapag
  /// item ito ng huling sagot ng search (hindi ng schedule / history).
  Future<void> rowOpened(String route) async {
    if (_store == null) return;
    final key = keyOfRoute(route);
    if (key == null || !_shown.contains(key)) return;
    await opened(key);
  }

  /// Memory Recall ("Teka — diba allergic ka sa hipon?") → mas malakas ang memory.
  Future<void> memoryUsed({int? id, String? content}) async {
    final store = _store;
    if (store == null) return;
    try {
      await store.memoryUsed(id: id, content: content);
    } catch (e) {
      debugPrint('RagLearning memoryUsed failed: $e');
    }
  }

  /// "Clear chat" / sagot sa card → kalimutan ang nasa RAM (hindi ang natutunan).
  void resetSession() {
    _fail = null;
    _logId = null;
    _shown.clear();
  }

  /// Pagkatapos ng "Burahin lahat" (binura na ng WipeRepository ang tables).
  void reset() {
    resetSession();
    _snap = null;
    changes.value++;
  }

  Future<void> _feedback(
    String key, {
    int good = 0,
    int bad = 0,
    required SearchOutcome outcome,
  }) async {
    final store = _store;
    if (store == null) return;
    try {
      await store.addFeedback(key, good: good, bad: bad);
      final id = _logId;
      if (id != null) await store.updateLog(id, outcome, docKey: key);
      if (key.startsWith('memory#') && good > 0) {
        await store.memoryUsed(id: int.tryParse(key.substring(7)));
      }
    } catch (e) {
      debugPrint('RagLearning feedback failed: $e');
    }
    _snap = null;
    changes.value++;
  }

  Future<void> _learnFrom(
    String failed,
    String success,
    RetrievalDoc top,
    Future<bool> Function(String word)? isKnown,
  ) async {
    final pair = pairFrom(failed, success);
    if (pair == null) return;
    final (word, alt) = pair;
    if (!appearsIn(alt, top) || appearsIn(word, top)) return;
    if (isKnown != null && await isKnown(word)) return;
    final count = await _store!.learnPair(word, alt);
    if (count >= minCount) _snap = null;
  }

  // ───────────────────────── Para sa Developer ─────────────────────────

  /// Mga natutunang salita (aktibo at hindi pa), pinakamarami muna.
  Future<List<LearnedTerm>> learnedTerms() async {
    final store = _store;
    if (store == null) return const [];
    try {
      return await store.learnedTerms();
    } catch (e) {
      debugPrint('RagLearning learnedTerms failed: $e');
      return const [];
    }
  }

  /// Mga huling tanong na walang nahanap (search_log, pinakabago muna).
  Future<List<SearchLogEntry>> recentMisses({int limit = 20}) async {
    final store = _store;
    if (store == null) return const [];
    try {
      return await store.recentLogs(limit: limit, outcome: SearchOutcome.none);
    } catch (e) {
      debugPrint('RagLearning recentMisses failed: $e');
      return const [];
    }
  }

  /// Ilang item ang may feedback.
  Future<Map<String, DocFeedback>> feedback() async {
    final store = _store;
    if (store == null) return const {};
    try {
      return await store.feedback();
    } catch (e) {
      debugPrint('RagLearning feedback read failed: $e');
      return const {};
    }
  }

  /// Developer: burahin ang isang natutunang salita.
  Future<void> forget(String term, String alt) async {
    final store = _store;
    if (store == null) return;
    try {
      await store.deleteLearned(term, alt);
    } catch (e) {
      debugPrint('RagLearning forget failed: $e');
    }
    _snap = null;
    changes.value++;
  }

  /// Developer: burahin lahat ng natutunan (search_log, salita, feedback,
  /// use_count ng memories). Hindi ginagalaw ang notes / memories mismo.
  Future<void> clearLearning() async {
    final store = _store;
    if (store == null) return;
    try {
      await store.clearAll();
    } catch (e) {
      debugPrint('RagLearning clear failed: $e');
    }
    reset();
  }

  // ───────────────────────── Pure ─────────────────────────

  static final _digit = RegExp(r'\d');

  /// Route ng row → key. '/notes/edit/5' → 'note#5',
  /// '/reminders/edit/9?view=1' → 'reminder#9', '/tasks/edit/3' → 'task#3'.
  static String? keyOfRoute(String route) {
    final m = RegExp(r'^/(notes|reminders|tasks)/edit/(\d+)').firstMatch(route);
    if (m == null) return null;
    final source = switch (m.group(1)) {
      'notes' => RetrievalSource.note,
      'reminders' => RetrievalSource.reminder,
      _ => RetrievalSource.task,
    };
    return '${source.name}#${m.group(2)}';
  }

  /// Anong salita ang natutunan mula sa pumalyang tanong [failed] at sa
  /// tumamang rephrase [success]? null = wala / hindi sigurado.
  ///
  ///   "ano pw ng net?"   → "ano wifi password ko?" → (net, wifi)
  ///                         (pw = password na, kaya net ↔ wifi lang ang naiba)
  ///   "gamot ni mama"    → "gamot ni papa"         → null (tao)
  ///   "bumili ng sapatos" → "binili sapatos"       → null (parehong ugat)
  ///   "pw ng net sa haus" → "wifi password bahay"  → null (2 ↔ 2, hindi alam kung alin)
  static (String, String)? pairFrom(String failed, String success) {
    final f = _content(QueryTerms.parse(failed));
    final s = _content(QueryTerms.parse(success));
    if (f.isEmpty || s.isEmpty) return null;
    final leftF = [for (final g in f) if (!s.any((h) => _same(g, h))) g];
    final leftS = [for (final h in s) if (!f.any((g) => _same(g, h))) h];
    if (leftF.length != 1 || leftS.length != 1) return null;
    final a = QueryTerms.fold(leftF.single.word);
    final b = QueryTerms.fold(leftS.single.word);
    if (a == b || Stemmer.stem(a) == Stemmer.stem(b)) return null;
    return (a, b);
  }

  /// Nasa [doc] ba ang [word] (o ugat / synonym nito)?
  static bool appearsIn(String word, RetrievalDoc doc) {
    final groups = QueryTerms.parse(word);
    if (groups.isEmpty) return false;
    final tokens = QueryTerms.searchTokens('${doc.title} ${doc.text}');
    return QueryTerms.groupIn(groups.first, tokens);
  }

  /// Mga salitang pwedeng matutunan (walang oras, uri, tao, numero, mahina).
  static List<TermGroup> _content(List<TermGroup> groups) => [
        for (final g in groups)
          if (_learnable(QueryTerms.fold(g.word))) g,
      ];

  static bool _learnable(String w) {
    if (w.length < 2 || _digit.hasMatch(w)) return false;
    for (final k in {w, Stemmer.stem(w)}) {
      if (Retriever.weakWords.contains(k) ||
          SearchScope.kindWords.containsKey(k) ||
          SearchScope.scheduleWords.contains(k) ||
          RagFollowUp.people.contains(k)) {
        return false;
      }
    }
    return true;
  }

  /// Iisang salita ba (may parehong alt: salita, ugat o synonym)?
  static bool _same(TermGroup a, TermGroup b) {
    final x = {for (final alt in a.alts) QueryTerms.fold(QueryTerms.bare(alt))};
    return b.alts.any((alt) => x.contains(QueryTerms.fold(QueryTerms.bare(alt))));
  }
}

class _Fail {
  const _Fail(this.query, this.at);
  final String query;
  final DateTime at;

  bool isFreshAt(DateTime now) => now.difference(at) <= RagLearning.failWindow;
}

// ───────────────────────── Data ─────────────────────────

/// Ano ang nangyari pagkatapos ng paghahanap (search_log.outcome).
enum SearchOutcome {
  /// Walang nahanap.
  none,

  /// May ipinakita (wala pang sagot ang user).
  shown,

  /// "oo" / "yan nga".
  confirmed,

  /// "hindi yan".
  rejected,

  /// "buksan mo" / pinindot ang row.
  opened;

  static SearchOutcome fromDb(String? s) =>
      SearchOutcome.values.firstWhere((o) => o.name == s, orElse: () => SearchOutcome.shown);
}

/// Isang row ng search_log.
class SearchLogEntry {
  const SearchLogEntry({
    this.id,
    required this.question,
    required this.query,
    required this.hitCount,
    this.topKey,
    this.sure = false,
    this.outcome = SearchOutcome.shown,
    this.docKey,
    required this.at,
  });

  final int? id;

  /// Ang tanong ng user (malinis, maliit na titik).
  final String question;

  /// Ang talagang hinanap (salita ni Qwen, pinagsamang follow-up, o ang tanong).
  final String query;
  final int hitCount;

  /// Ang unang sagot ('note#5'). null = walang nahanap.
  final String? topKey;
  final bool sure;
  final SearchOutcome outcome;

  /// Ang item na sinabihan ng "oo" / "hindi yan" / binuksan.
  final String? docKey;
  final DateTime at;

  Map<String, Object?> toRow() => {
        'question': question,
        'search_query': query,
        'hit_count': hitCount,
        'top_key': topKey,
        'sure': sure ? 1 : 0,
        'outcome': outcome.name,
        'doc_key': docKey,
        'created_at': at.toIso8601String(),
        'updated_at': at.toIso8601String(),
      };

  factory SearchLogEntry.fromRow(Map<String, Object?> r) => SearchLogEntry(
        id: r['id'] as int?,
        question: (r['question'] as String?) ?? '',
        query: (r['search_query'] as String?) ?? '',
        hitCount: (r['hit_count'] as int?) ?? 0,
        topKey: r['top_key'] as String?,
        sure: (r['sure'] as int? ?? 0) == 1,
        outcome: SearchOutcome.fromDb(r['outcome'] as String?),
        docKey: r['doc_key'] as String?,
        at: DateTime.tryParse((r['created_at'] as String?) ?? '') ?? DateTime(2000),
      );

  SearchLogEntry copyWith({SearchOutcome? outcome, String? docKey}) => SearchLogEntry(
        id: id,
        question: question,
        query: query,
        hitCount: hitCount,
        topKey: topKey,
        sure: sure,
        outcome: outcome ?? this.outcome,
        docKey: docKey ?? this.docKey,
        at: at,
      );

  @override
  String toString() => 'SearchLogEntry("$question" → "$query", $hitCount, ${outcome.name})';
}

/// Isang natutunang pares ng salita (laging [term] < [alt], walang tuldik).
class LearnedTerm {
  const LearnedTerm(this.term, this.alt, this.count, this.updatedAt);

  final String term;
  final String alt;

  /// Ilang beses natutunan. Aktibo kapag ≥ [RagLearning.minCount].
  final int count;
  final DateTime updatedAt;

  bool get active => count >= RagLearning.minCount;

  /// (a, b) → laging magkapareho ang ayos: ang mas maliit muna.
  static (String, String) normalize(String a, String b) =>
      a.compareTo(b) <= 0 ? (a, b) : (b, a);

  @override
  String toString() => '$term ↔ $alt ×$count';
}

/// "oo" / binuksan (good) at "hindi yan" (bad) ng isang item.
class DocFeedback {
  const DocFeedback({this.good = 0, this.bad = 0});

  final int good;
  final int bad;

  /// Dagdag sa bawat "oo" / binuksan.
  static const goodStep = 0.05;

  /// Bawas sa bawat "hindi yan" (mas malaki: mas sigurado ang "mali").
  static const badStep = 0.08;

  /// Hangganan: maliit lang palagi — hindi natatalo ang tamang salita.
  static const maxUp = 0.20;
  static const maxDown = 0.24;

  /// Idinadagdag sa multiplier ng score sa Retriever (1.0 + boost).
  double get boost => math.max(-maxDown, math.min(maxUp, good * goodStep - bad * badStep));

  @override
  String toString() => 'DocFeedback(+$good, -$bad)';
}

/// Ang ginagamit ng Retriever: natutunang synonyms + boost bawat item.
class LearnedSnapshot {
  const LearnedSnapshot({this.synonyms = const {}, this.boosts = const {}});

  static const empty = LearnedSnapshot();

  /// salita (o ugat nito) → mga natutunang kapareho. "net" → ["wifi"].
  final Map<String, List<String>> synonyms;

  /// 'note#5' → +0.05 / −0.08 …
  final Map<String, double> boosts;

  bool get isEmpty => synonyms.isEmpty && boosts.isEmpty;

  /// Aktibong [terms] lang (count ≥ [RagLearning.minCount]), magkabilang direksyon.
  factory LearnedSnapshot.build(
    Iterable<LearnedTerm> terms,
    Map<String, DocFeedback> feedback,
  ) {
    final syn = <String, List<String>>{};
    void add(String from, String to) {
      for (final k in {from, Stemmer.stem(from)}) {
        final list = syn.putIfAbsent(k, () => <String>[]);
        if (!list.contains(to)) list.add(to);
      }
    }

    for (final t in terms) {
      if (!t.active) continue;
      add(t.term, t.alt);
      add(t.alt, t.term);
    }
    final boosts = <String, double>{};
    feedback.forEach((key, f) {
      final b = f.boost;
      if (b != 0) boosts[key] = b;
    });
    return LearnedSnapshot(synonyms: syn, boosts: boosts);
  }

  @override
  String toString() => 'LearnedSnapshot(synonyms: $synonyms, boosts: $boosts)';
}

// ───────────────────────── Store ─────────────────────────

/// Saan sine-save ang natutunan. SQLite sa app ([SearchLogRepository]),
/// RAM sa test ([MemoryLearningStore]).
abstract class LearningStore {
  /// Bagong search_log row. Ibinabalik ang id.
  Future<int?> addLog(SearchLogEntry entry);

  /// "oo" / "hindi yan" / binuksan → palitan ang outcome ng row.
  Future<void> updateLog(int id, SearchOutcome outcome, {String? docKey});

  /// Pinakabago muna. [outcome] = iyon lang.
  Future<List<SearchLogEntry>> recentLogs({int limit = 30, SearchOutcome? outcome});

  Future<void> addFeedback(String docKey, {int good = 0, int bad = 0});
  Future<Map<String, DocFeedback>> feedback();

  /// +1 sa pares (kahit anong ayos). Ibinabalik ang bagong bilang.
  Future<int> learnPair(String a, String b);
  Future<List<LearnedTerm>> learnedTerms();
  Future<void> deleteLearned(String a, String b);

  /// memories.use_count + 1 (ayon sa [id] o sa eksaktong [content]).
  Future<void> memoryUsed({int? id, String? content});

  /// Burahin lahat ng natutunan (hindi ang notes / memories mismo).
  Future<void> clearAll();
}

/// RAM lang — para sa test (at kapag walang database).
class MemoryLearningStore implements LearningStore {
  final List<SearchLogEntry> logs = [];
  final Map<String, DocFeedback> feedbackMap = {};
  final Map<(String, String), LearnedTerm> terms = {};

  /// memory id (o content) → ilang beses nagamit.
  final Map<Object, int> memoryUses = {};

  int _nextId = 1;

  @override
  Future<int?> addLog(SearchLogEntry entry) async {
    final id = _nextId++;
    logs.add(SearchLogEntry(
      id: id,
      question: entry.question,
      query: entry.query,
      hitCount: entry.hitCount,
      topKey: entry.topKey,
      sure: entry.sure,
      outcome: entry.outcome,
      docKey: entry.docKey,
      at: entry.at,
    ));
    return id;
  }

  @override
  Future<void> updateLog(int id, SearchOutcome outcome, {String? docKey}) async {
    final i = logs.indexWhere((e) => e.id == id);
    if (i >= 0) logs[i] = logs[i].copyWith(outcome: outcome, docKey: docKey);
  }

  @override
  Future<List<SearchLogEntry>> recentLogs({int limit = 30, SearchOutcome? outcome}) async => logs.reversed
      .where((e) => outcome == null || e.outcome == outcome)
      .take(limit)
      .toList();

  @override
  Future<void> addFeedback(String docKey, {int good = 0, int bad = 0}) async {
    final f = feedbackMap[docKey] ?? const DocFeedback();
    feedbackMap[docKey] = DocFeedback(good: f.good + good, bad: f.bad + bad);
  }

  @override
  Future<Map<String, DocFeedback>> feedback() async => Map.of(feedbackMap);

  @override
  Future<int> learnPair(String a, String b) async {
    final key = LearnedTerm.normalize(a, b);
    final old = terms[key];
    final count = (old?.count ?? 0) + 1;
    terms[key] = LearnedTerm(key.$1, key.$2, count, DateTime.now());
    return count;
  }

  @override
  Future<List<LearnedTerm>> learnedTerms() async =>
      terms.values.toList()..sort((x, y) => y.count.compareTo(x.count));

  @override
  Future<void> deleteLearned(String a, String b) async {
    terms.remove(LearnedTerm.normalize(a, b));
  }

  @override
  Future<void> memoryUsed({int? id, String? content}) async {
    final Object? key = id ?? content;
    if (key == null) return;
    memoryUses[key] = (memoryUses[key] ?? 0) + 1;
  }

  @override
  Future<void> clearAll() async {
    logs.clear();
    feedbackMap.clear();
    terms.clear();
    memoryUses.clear();
  }
}