import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/database/repositories/search_repository.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/retriever.dart';

/// Takbuhin:  flutter test test/rag/retriever_test.dart
///
/// B2: scoring ng Retriever. Walang database — fake SearchRepository na
/// ibinabalik lahat ng docs (ang Retriever ang sumasala at nagsi-score).
class _FakeSearch extends SearchRepository {
  _FakeSearch(this.docs);
  final List<RetrievalDoc> docs;
  bool? askedMemories;

  @override
  Future<List<RetrievalDoc>> candidates(List<TermGroup> terms, {bool includeMemories = true}) async {
    askedMemories = includeMemories;
    return docs.where((d) => includeMemories || !d.isMemory).toList();
  }
}

void main() {
  final now = DateTime(2026, 11, 21, 20, 0);

  RetrievalDoc note(int id, String title, String content,
          {bool pinned = false, int daysAgo = 60}) =>
      RetrievalDoc(
        source: RetrievalSource.note,
        id: id,
        title: title,
        text: content,
        pinned: pinned,
        updatedAt: now.subtract(Duration(days: daysAgo)),
      );

  RetrievalDoc memory(int id, String content, {int importance = 3, int daysAgo = 60}) =>
      RetrievalDoc(
        source: RetrievalSource.memory,
        id: id,
        title: RetrievalDoc.shortTitle(content),
        text: content,
        importance: importance,
        updatedAt: now.subtract(Duration(days: daysAgo)),
      );

  final docs = [
    note(1, 'Wifi', 'Wi-Fi password ng office ay zoe123'),
    note(2, 'Shopping list', 'itlog, gatas, tinapay'),
    note(3, 'Bahay', 'wifi sa bahay: zoe2026', daysAgo: 2),
    note(4, 'Passport', 'passport number P1234567'),
    note(5, 'Gym', 'locker code 4521', pinned: true),
    memory(6, 'Mas gusto ko ng morning reminders'),
  ];

  Future<List<RetrievalHit>> search(String q, {bool memories = true, int limit = 3}) =>
      Retriever(repo: _FakeSearch(docs), clock: () => now)
          .search(q, includeMemories: memories, limit: limit);

  List<int> ids(List<RetrievalHit> hits) => hits.map((h) => h.doc.id).toList();

  test('"ano wifi password ko?" → office wifi muna (2 salita), saka bahay', () async {
    final hits = await search('ano wifi password ko?');
    expect(ids(hits), [1, 3]);
    expect(hits.first.matched, 2);
  });

  test('"saan yung wifi sa bahay?" → bahay muna', () async {
    expect(ids(await search('saan yung wifi sa bahay?')).first, 3);
  });

  test('"pin" ay hindi tumatama sa "Shopping" · "password" ≠ "passport"', () async {
    expect(ids(await search('ano pin ko')), [5]); // pin → code (synonym)
    expect(ids(await search('password')), isNot(contains(4)));
  });

  test('walang tumama → walang sagot', () async {
    expect(await search('ano pangalan ng aso ko?'), isEmpty);
    expect(await search('ano ko?'), isEmpty); // puro stopwords
  });

  test('memories: kasama kapag ON, wala kapag OFF', () async {
    expect(ids(await search('anong reminders gusto ko?')), [6]);
    expect(await search('anong reminders gusto ko?', memories: false), isEmpty);
  });

  test('mahinang tama ay tinatanggal kapag may mas magaling', () {
    final terms = QueryTerms.parse('locker code gym');
    final ranked = Retriever.rank(terms, [
      note(10, 'Gym', 'locker code 4521'),
      note(11, 'Code ng pinto', 'gate 1111'),
    ], now: now);
    expect(ranked.map((h) => h.doc.id), [10]); // 3 salita vs 1 → tanggal ang 11
  });

  test('pareho ang tumama → title, saka bago / pinned', () {
    final terms = QueryTerms.parse('code');
    final ranked = Retriever.rank(terms, [
      note(20, 'Iba', 'door code 1', daysAgo: 100),
      note(21, 'Iba pa', 'door code 2', pinned: true, daysAgo: 100),
      note(22, 'Code', 'door 3', daysAgo: 100),
      note(23, 'Luma', 'door code 4', daysAgo: 3),
    ], now: now);
    // 22: nasa title (13) · 23: bago (12) · 21: pinned (12, pero mas luma) · 20: 10
    expect(ranked.map((h) => h.doc.id), [22, 23, 21, 20]);
  });

  test('recencyBonus', () {
    expect(Retriever.recencyBonus(now.subtract(const Duration(days: 1)), now), 2);
    expect(Retriever.recencyBonus(now.subtract(const Duration(days: 20)), now), 1);
    expect(Retriever.recencyBonus(now.subtract(const Duration(days: 90)), now), 0);
  });
}