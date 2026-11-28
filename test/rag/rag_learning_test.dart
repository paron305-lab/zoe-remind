import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/database/repositories/search_repository.dart';
import 'package:zoe_remind/memory/memory_recall.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_learning.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/retriever.dart';

/// Takbuhin:  flutter test test/rag/rag_learning_test.dart
///
/// R6 — natututo si Zoe sa phone. Walang database: RAM na store
/// (MemoryLearningStore) at fake na SearchRepository.
///   • pairFrom: "ano pw ng net?" → "ano wifi password ko?" → (net, wifi)
///   • RagLearning: pumalya → rephrase na sigurado → natututo (2 beses bago gamitin)
///   • feedback: "oo" / binuksan = +, "hindi yan" = − (maliit na boost)
///   • QueryTerms / Retriever / MemoryRecall gamit ang natutunan
class _FakeSearch extends SearchRepository {
  _FakeSearch(this.docs);
  final List<RetrievalDoc> docs;

  @override
  Future<List<RetrievalDoc>> candidates(List<TermGroup> terms, {bool includeMemories = true}) async =>
      docs.where((d) => includeMemories || !d.isMemory).toList();
}

void main() {
  final now = DateTime(2026, 11, 28, 15, 0);

  RetrievalDoc note(int id, String title, String text) => RetrievalDoc(
        source: RetrievalSource.note,
        id: id,
        title: title,
        text: text,
        updatedAt: DateTime(2026, 11, 20),
      );

  final wifi = note(1, 'Wifi', 'ZoeHome / pass 1234');
  final shopping = note(2, 'Shopping list', 'itlog, gatas, tinapay');
  final memory = RetrievalDoc(
    source: RetrievalSource.memory,
    id: 7,
    title: 'Allergic ako sa hipon',
    text: 'Allergic ako sa hipon',
    updatedAt: DateTime(2026, 11, 10),
  );

  RetrievalHit hit(RetrievalDoc d, {bool sure = true}) => RetrievalHit(
        doc: d,
        score: 5,
        matched: 2,
        matchedInTitle: 1,
        coverage: sure ? 1 : 0.4,
        confidence: sure ? RetrievalConfidence.strong : RetrievalConfidence.maybe,
      );

  Future<bool> unknown(String _) async => false;

  /// Pumalya ang "ano pw ng net ko?" → nag-rephrase ng "ano wifi password ko?" → tumama.
  Future<void> missThenRephrase(RagLearning l, {Future<bool> Function(String)? isKnown}) async {
    await l.searched(question: 'ano pw ng net ko?', query: 'ano pw ng net ko?', hits: const []);
    await l.searched(
      question: 'ano wifi password ko?',
      query: 'ano wifi password ko?',
      hits: [hit(wifi)],
      isKnown: isKnown ?? unknown,
    );
  }

  group('pairFrom (pure)', () {
    test('"ano pw ng net ko" → "ano wifi password ko" → (net, wifi) — pw = password na', () {
      expect(RagLearning.pairFrom('ano pw ng net ko', 'ano wifi password ko'), ('net', 'wifi'));
    });

    test('password ng net → wifi password → (net, wifi)', () {
      expect(RagLearning.pairFrom('password ng net', 'wifi password'), ('net', 'wifi'));
    });

    test('tao ay hindi natututunan: "gamot ni mama" → "gamot ni papa" → null', () {
      expect(RagLearning.pairFrom('ano gamot ni mama', 'ano gamot ni papa'), isNull);
    });

    test('parehong ugat: bumili ↔ binili → null', () {
      expect(RagLearning.pairFrom('saan ako bumili ng sapatos', 'saan ko binili ang sapatos'), isNull);
    });

    test('walang bagong salita sa rephrase → null', () {
      expect(RagLearning.pairFrom('ano wifi password ko sa cafe', 'ano wifi password ko'), isNull);
    });

    test('2 ↔ 2 (hindi alam kung alin ang kapareho) → null', () {
      expect(RagLearning.pairFrom('pw ng net sa haus', 'wifi password ng bahay'), isNull);
    });

    test('oras / numero ay hindi binibilang', () {
      expect(RagLearning.pairFrom('ano net ko bukas', 'ano wifi ko'), ('net', 'wifi'));
      expect(RagLearning.pairFrom('ano code 4521', 'ano locker code'), isNull);
    });
  });

  group('keyOfRoute / appearsIn (pure)', () {
    test('route → key', () {
      expect(RagLearning.keyOfRoute('/notes/edit/5'), 'note#5');
      expect(RagLearning.keyOfRoute('/reminders/edit/9?view=1'), 'reminder#9');
      expect(RagLearning.keyOfRoute('/tasks/edit/3'), 'task#3');
      expect(RagLearning.keyOfRoute('/history'), isNull);
    });

    test('nasa note ba ang salita (salita, synonym, magkasunod)', () {
      expect(RagLearning.appearsIn('wifi', wifi), isTrue);
      expect(RagLearning.appearsIn('net', wifi), isFalse);
      expect(RagLearning.appearsIn('wifi', note(3, 'Bahay', 'Wi-Fi sa bahay')), isTrue);
    });
  });

  group('DocFeedback / LearnedSnapshot (pure)', () {
    test('boost: maliit, may hangganan', () {
      expect(const DocFeedback(good: 1).boost, closeTo(0.05, 1e-9));
      expect(const DocFeedback(bad: 1).boost, closeTo(-0.08, 1e-9));
      expect(const DocFeedback(good: 10).boost, closeTo(DocFeedback.maxUp, 1e-9));
      expect(const DocFeedback(bad: 10).boost, closeTo(-DocFeedback.maxDown, 1e-9));
      expect(const DocFeedback(good: 2, bad: 1).boost, closeTo(0.02, 1e-9));
    });

    test('isang beses pa lang → hindi pa ginagamit; 2 beses → magkabilang direksyon', () {
      final once = LearnedSnapshot.build([LearnedTerm('net', 'wifi', 1, now)], const {});
      expect(once.synonyms, isEmpty);

      final twice = LearnedSnapshot.build([LearnedTerm('net', 'wifi', 2, now)], const {});
      expect(twice.synonyms['net'], ['wifi']);
      expect(twice.synonyms['wifi'], contains('net'));
    });

    test('feedback → boosts (walang 0)', () {
      final s = LearnedSnapshot.build(const [], const {
        'note#1': DocFeedback(good: 1),
        'note#2': DocFeedback(),
      });
      expect(s.boosts, {'note#1': closeTo(0.05, 1e-9)});
    });
  });

  group('RagLearning (RAM store)', () {
    late MemoryLearningStore store;
    late RagLearning l;
    var clock = now;

    setUp(() {
      clock = now;
      store = MemoryLearningStore();
      l = RagLearning(store, clock: () => clock);
    });

    test('bawat paghahanap ay naka-log (wala → none, may sagot → shown)', () async {
      await l.searched(question: 'ano plate ko?', query: 'ano plate ko?', hits: const []);
      await l.searched(question: 'ano wifi ko?', query: 'ano wifi ko?', hits: [hit(wifi)]);
      expect(store.logs.map((e) => e.outcome), [SearchOutcome.none, SearchOutcome.shown]);
      expect(store.logs.last.topKey, 'note#1');
      expect(store.logs.last.sure, isTrue);
      expect((await l.recentMisses()).single.question, 'ano plate ko?');
    });

    test('pumalya → rephrase: isang beses = naghihintay, 2 beses = aktibo', () async {
      await missThenRephrase(l);
      expect(store.terms[('net', 'wifi')]!.count, 1);
      expect((await l.snapshot()).synonyms, isEmpty);

      await missThenRephrase(l);
      expect(store.terms[('net', 'wifi')]!.count, 2);
      final snap = await l.snapshot();
      expect(snap.synonyms['net'], ['wifi']);
      expect(snap.synonyms['wifi'], contains('net'));
    });

    test('kilalang salita (may item na may ito) → hindi natututo', () async {
      await missThenRephrase(l, isKnown: (_) async => true);
      expect(store.terms, isEmpty);
    });

    test('lampas 3 minuto bago nag-rephrase → hindi natututo', () async {
      await l.searched(question: 'ano pw ng net ko?', query: 'ano pw ng net ko?', hits: const []);
      clock = clock.add(const Duration(minutes: 4));
      await l.searched(
        question: 'ano wifi password ko?',
        query: 'ano wifi password ko?',
        hits: [hit(wifi)],
        isKnown: unknown,
      );
      expect(store.terms, isEmpty);
    });

    test('hindi sigurado ang rephrase → hindi natututo', () async {
      await l.searched(question: 'ano pw ng net ko?', query: 'ano pw ng net ko?', hits: const []);
      await l.searched(
        question: 'ano wifi password ko?',
        query: 'ano wifi password ko?',
        hits: [hit(wifi, sure: false)],
        isKnown: unknown,
      );
      expect(store.terms, isEmpty);
    });

    test('"hindi yan" → bawas + log rejected; ang rephrase ay pinagmumulan ng salita', () async {
      await l.searched(question: 'ano pw ng net ko?', query: 'ano pw ng net ko?', hits: [hit(shopping)]);
      await l.rejected('note#2', query: 'ano pw ng net ko?');
      expect(store.feedbackMap['note#2']!.bad, 1);
      expect(store.logs.single.outcome, SearchOutcome.rejected);
      expect(store.logs.single.docKey, 'note#2');
      expect((await l.snapshot()).boosts['note#2'], closeTo(-0.08, 1e-9));

      await l.searched(
        question: 'ano wifi password ko?',
        query: 'ano wifi password ko?',
        hits: [hit(wifi)],
        isKnown: unknown,
      );
      expect(store.terms[('net', 'wifi')]!.count, 1);
    });

    test('"oo" → dagdag + log confirmed; hindi na matututo sa susunod', () async {
      await l.searched(question: 'ano pw ng net ko?', query: 'ano pw ng net ko?', hits: [hit(wifi, sure: false)]);
      await l.confirmed('note#1');
      expect(store.logs.single.outcome, SearchOutcome.confirmed);
      expect((await l.snapshot()).boosts['note#1'], closeTo(0.05, 1e-9));

      await l.searched(
        question: 'ano wifi password ko?',
        query: 'ano wifi password ko?',
        hits: [hit(wifi)],
        isKnown: unknown,
      );
      expect(store.terms, isEmpty); // tama na ang una — walang pumalya
    });

    test('pinindot na row: item lang ng huling sagot ang binibilang', () async {
      await l.searched(question: 'ano wifi ko?', query: 'ano wifi ko?', hits: [hit(wifi)]);
      await l.rowOpened('/notes/edit/2'); // wala sa sagot
      await l.rowOpened('/history');
      expect(store.feedbackMap, isEmpty);

      await l.rowOpened('/notes/edit/1');
      expect(store.feedbackMap['note#1']!.good, 1);
      expect(store.logs.single.outcome, SearchOutcome.opened);

      // "yung isa pa" → ibang mga item na ang nakikita.
      l.showing([hit(shopping)]);
      await l.rowOpened('/notes/edit/2');
      expect(store.feedbackMap['note#2']!.good, 1);
    });

    test('memory na sagot / naalala → +1 use_count', () async {
      await l.searched(question: 'allergy ko?', query: 'allergy ko?', hits: [hit(memory)]);
      expect(store.memoryUses[7], 1);
      await l.memoryUsed(content: 'Allergic ako sa hipon');
      expect(store.memoryUses['Allergic ako sa hipon'], 1);
    });

    test('resetSession → kinakalimutan ang pumalya (hindi ang natutunan)', () async {
      await missThenRephrase(l);
      await l.searched(question: 'ano pw ng net ko?', query: 'ano pw ng net ko?', hits: const []);
      l.resetSession();
      await l.searched(
        question: 'ano wifi password ko?',
        query: 'ano wifi password ko?',
        hits: [hit(wifi)],
        isKnown: unknown,
      );
      expect(store.terms[('net', 'wifi')]!.count, 1);
    });

    test('forget / clearLearning', () async {
      await missThenRephrase(l);
      await missThenRephrase(l);
      expect((await l.snapshot()).synonyms, isNotEmpty);

      await l.forget('wifi', 'net'); // kahit anong ayos
      expect(store.terms, isEmpty);
      expect((await l.snapshot()).synonyms, isEmpty);

      await l.clearLearning();
      expect(store.logs, isEmpty);
      expect(await l.learnedTerms(), isEmpty);
    });

    test('disabled → walang ginagawa, walang error', () async {
      final off = RagLearning.disabled;
      expect(off.enabled, isFalse);
      await off.searched(question: 'x', query: 'x', hits: const []);
      await off.confirmed('note#1');
      await off.rowOpened('/notes/edit/1');
      expect((await off.snapshot()).isEmpty, isTrue);
    });
  });

  group('QueryTerms / Retriever gamit ang natutunan', () {
    test('QueryTerms: "net" → + wifi at synonyms nito (synonym ang bigat)', () {
      final plain = QueryTerms.parse('ano net ko?').single;
      expect(plain.alts, ['net']);

      final g = QueryTerms.parse('ano net ko?', learned: const {
        'net': ['wifi'],
      }).single;
      expect(g.alts, containsAll(['net', 'wifi', 'wi fi', 'internet']));
      expect(g.directAlts.toList(), ['net']);
    });

    test('rank: feedback boost ang nagpapasya kapag magkapareho', () {
      final a = note(1, 'Gym', 'locker code 4521');
      final b = note(2, 'Gym', 'locker code 4521');
      final terms = QueryTerms.parse('locker code');
      expect(Retriever.rank(terms, [a, b], now: now).first.doc.id, 2); // mas bagong id
      final boosted = Retriever.rank(terms, [a, b], now: now, boosts: const {'note#1': 0.2});
      expect(boosted.first.doc.id, 1);
      // Hindi nagbabago ang coverage.
      expect(boosted.first.coverage, closeTo(1, 1e-9));
    });

    test('Retriever: "ano net ko?" — wala dati; pagkatapos matuto (2×) → Wifi note', () async {
      final l = RagLearning(MemoryLearningStore(), clock: () => now);
      final r = Retriever(repo: _FakeSearch([wifi, shopping]), clock: () => now, learning: l);
      expect(await r.search('ano net ko?'), isEmpty);

      await missThenRephrase(l);
      expect(await r.search('ano net ko?'), isEmpty); // isang beses pa lang

      await missThenRephrase(l);
      final hits = await r.search('ano net ko?');
      expect(hits.first.doc.id, 1);
    });

    test('Retriever na may fake repo at walang learning → walang learning', () {
      expect(Retriever(repo: _FakeSearch(const [])).learning, isNull);
    });
  });

  group('MemoryRecall (R6: iisang vocabulary)', () {
    const memories = ['Allergic ako sa hipon'];

    test('natutunang salita → naaalala ang memory', () {
      expect(MemoryRecall.check('ang sarap ng krill', memories), isNull);
      final hit = MemoryRecall.check('ang sarap ng krill', memories, learned: const {
        'krill': ['hipon'],
      });
      expect(hit, isNotNull);
      expect(hit!.fact.memory, 'Allergic ako sa hipon');
      expect(hit.known, isFalse);
    });

    test('walang natutunan → gaya ng dati', () {
      expect(MemoryRecall.check('ang sarap kumain ng hipon', memories), isNotNull);
      expect(MemoryRecall.check('ang ganda ng panahon', memories), isNull);
    });
  });
}