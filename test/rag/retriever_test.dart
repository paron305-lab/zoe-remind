import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/database/repositories/search_repository.dart';
import 'package:zoe_remind/features/chat/controllers/chat_router.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/retriever.dart';
import 'package:zoe_remind/rag/search_scope.dart';

/// Takbuhin:  flutter test test/rag/retriever_test.dart
///
/// B2: scoring ng Retriever. Walang database — fake SearchRepository na
/// ibinabalik lahat ng docs (ang Retriever ang sumasala at nagsi-score).
/// R2: IDF, synonym na mas magaan, magkatabi, coverage → strong / maybe / wala.
/// R4: reminders + tasks — walang title bonus / maikling bonus; scope.
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
    // R2: lahat ng salita sa #1 → sigurado; "wifi" lang sa #2 → hindi.
    expect(hits.first.confidence, RetrievalConfidence.strong);
    expect(hits[1].confidence, RetrievalConfidence.maybe);
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
    // 22: nasa title · 23: bago (×1.1) · 21: pinned (×1.1, pero mas mahaba) · 20
    expect(ranked.map((h) => h.doc.id), [22, 23, 21, 20]);
  });

  test('recencyBonus', () {
    expect(Retriever.recencyBonus(now.subtract(const Duration(days: 1)), now), 2);
    expect(Retriever.recencyBonus(now.subtract(const Duration(days: 20)), now), 1);
    expect(Retriever.recencyBonus(now.subtract(const Duration(days: 90)), now), 0);
  });

  // ───────────────────────── R2 ─────────────────────────

  group('R2 — ranking + kumpiyansa', () {
    final day = DateTime(2026, 11, 27, 9, 0);
    RetrievalDoc n(int id, String title, String text, int daysAgo, {bool pinned = false}) =>
        RetrievalDoc(
          source: RetrievalSource.note,
          id: id,
          title: title,
          text: text,
          pinned: pinned,
          updatedAt: day.subtract(Duration(days: daysAgo)),
        );
    RetrievalDoc m(int id, String text, int daysAgo) => RetrievalDoc(
          source: RetrievalSource.memory,
          id: id,
          title: RetrievalDoc.shortTitle(text),
          text: text,
          updatedAt: day.subtract(Duration(days: daysAgo)),
        );

    // Maliit na bahagi ng bench data.
    final mini = [
      n(1, 'Wifi bahay', 'ZoeHome / password: zoe2026', 40, pinned: true),
      n(2, 'Office wifi', 'SSID BrixenOffice, pass BX-4421', 90),
      n(3, 'Router', 'admin login ng router: 192.168.1.1, admin / ZoeAdmin!', 120),
      n(4, 'Gym', 'locker code 4521', 60),
      n(5, 'Kotse', 'plate number NBC 1234, rehistro hanggang Marso', 100),
      n(6, 'Insurance', 'Policy number PL-77812, renewal every June', 220),
      n(7, 'Adobo ni Lola',
          'Recipe: 1 kilo manok, toyo, suka, bawang, paminta, dahon ng laurel. Lutuin ng 45 minuto.',
          300,
          pinned: true),
      n(8, 'Upa', 'Bayad sa upa tuwing ika-5, kay Aling Nena, P8,000', 110),
      n(9, 'Spare key', 'Ang reserbang susi ng bahay ay iniwan ko kay Kuya Ben', 95),
      m(10, 'Kumain kami ng sinigang sa bahay ni Lola', 1),
      n(11, 'Gamot ni Mama', 'losartan 50mg tuwing umaga, metformin pagkatapos kumain', 30,
          pinned: true),
      n(12, 'Gamot ni Papa', 'amlodipine 5mg bago matulog', 45),
      m(13, 'Night shift ang trabaho ko', 60),
      n(14, 'Payong', 'Naiwan ko ang payong sa opisina', 6),
    ];

    List<RetrievalHit> rank(String q, [List<RetrievalDoc>? from, CorpusStats? stats]) =>
        Retriever.rank(QueryTerms.parse(ChatRouter.clean(q)), from ?? mini,
            now: day, stats: stats);

    group('IDF: bihirang salita ang mas mabigat', () {
      test('"router admin password" → Router ("admin" ay nasa isa lang)', () {
        expect(rank('router admin password').first.doc.id, 3); // R1: Wifi bahay
      });

      test('"renta sa bahay" → Upa ("bahay" ay nasa maraming note)', () {
        expect(rank('renta sa bahay').first.doc.id, 8); // R1: Wifi bahay
      });
    });

    group('synonym ay mas magaan kaysa mismong salita', () {
      test('"anong oras ako pumapasok sa trabaho?" → "trabaho" bago "office" / "opisina"', () {
        expect(rank('anong oras ako pumapasok sa trabaho?').first.doc.id, 13); // R1: Office wifi
      });

      test('coverage: mismong salita 1.0, synonym lang 0.8', () {
        final work = [
          m(70, 'Night shift ang trabaho ko', 60),
          n(71, 'Office', 'SSID BrixenOffice, pass BX-4421', 60),
          n(72, 'Grocery', 'itlog, gatas', 60),
          n(73, 'Gym', 'locker code 4521', 60),
          n(74, 'Meralco', 'Paid Nov 15', 60),
        ];
        final hits = rank('saan ang trabaho ko?', work);
        expect(ids(hits), [70, 71]);
        expect(hits[0].coverage, closeTo(1.0, 1e-9));
        expect(hits[1].coverage, closeTo(Retriever.synonymWeight, 1e-9));
      });
    });

    group('kumpiyansa', () {
      test('lahat ng salita tumama → strong', () {
        final hits = rank('ano wifi password sa bahay?');
        expect(hits.first.doc.id, 1);
        expect(hits.first.isSure, isTrue);
        expect(rank('gamot ni mama').first.isSure, isTrue);
        expect(rank('policy number ng insurance').single.doc.id, 6);
      });

      test('may mahalagang salitang wala sa notes → "Baka ito?" (maybe)', () {
        for (final (q, id) in [
          ('ano ang wifi password sa cafe?', 1),
          ('ano ang plate number ng motor ko?', 5),
          ('recipe ng kare-kare', 7),
          ('router admin password', 3), // walang "password" sa Router note
        ]) {
          final top = rank(q).first;
          expect(top.doc.id, id, reason: q);
          expect(top.confidence, RetrievalConfidence.maybe, reason: q);
        }
      });

      test('walang tumama → walang sagot', () {
        expect(rank('sino ang presidente?'), isEmpty);
      });

      test('halos magkapantay ang #1 at #2 → maybe ("gamot" → kay mama o kay papa?)', () {
        final gamot = [
          n(30, 'Gamot ni Mama', 'losartan 50mg tuwing umaga', 60),
          n(31, 'Gamot ni Papa', 'amlodipine 5mg bago matulog', 60),
        ];
        final hits = rank('gamot', gamot);
        expect(hits, hasLength(2));
        expect(hits.first.confidence, RetrievalConfidence.maybe);
        expect(rank('gamot ni mama', gamot).first.isSure, isTrue);
      });

      test('mahinang salita lang ang tumama → hindi isinasama', () {
        final tips = [n(40, 'Tips', 'how to cook rice', 60), n(41, 'Pusa', 'si Mingming', 60)];
        expect(rank('how do I fix the aircon?', tips), isEmpty);
      });
    });

    group('magkatabi + CorpusStats', () {
      test('"wifi password" na magkatabi sa note → nauuna', () {
        final near = [
          n(60, 'Sala', 'wifi password: zoe1 sa sala ng bahay', 60),
          n(61, 'Gate', 'password ng gate 4421 at wifi sa sala', 60),
        ];
        expect(ids(rank('wifi password', near)), [60, 61]);
      });

      test('df mula sa database ang ginagamit kapag mas malaki', () {
        final two = [n(50, 'A', 'wifi sa sala', 60), n(51, 'B', 'password ng gate', 60)];
        // "wifi" nasa 90 sa 100 notes → mahina; "password" nasa 1 → malakas.
        expect(rank('wifi password', two, const CorpusStats(docCount: 100, docFreq: [90, 1]))
            .first
            .doc
            .id, 51);
        expect(rank('wifi password', two, const CorpusStats(docCount: 100, docFreq: [1, 90]))
            .first
            .doc
            .id, 50);
      });

      test('CorpusStats.unknown (kandidato lang) → hindi natatanggal ang may 1 salita', () {
        final two = [
          note(1, 'Wifi', 'Wi-Fi password ng office ay zoe123'),
          note(3, 'Bahay', 'wifi sa bahay: zoe2026'),
        ];
        expect(ids(rank('ano wifi password ko?', two, CorpusStats.unknown)), [1, 3]);
      });
    });
  });

  group('R4 — reminders + tasks', () {
    RetrievalDoc reminder(int id, String title, {int daysAgo = 3}) => RetrievalDoc(
          source: RetrievalSource.reminder,
          id: id,
          title: title,
          text: '',
          updatedAt: now.subtract(Duration(days: daysAgo)),
        );

    List<RetrievalHit> answer(String q, List<RetrievalDoc> all) =>
        Retriever.rankFor(SearchScope.of(ChatRouter.clean(q)), all, now: now);

    final bills = note(10, 'Bills', 'Paid Meralco Nov 15', daysAgo: 13);
    final payMeralco = reminder(11, 'Bayaran ang Meralco', daysAgo: 30);
    final dentistNote = note(1, 'Dentist', 'Dr. Santos 0917 555 1234');
    final dentistReminder = reminder(2, 'Dentist appointment');

    test('maikling reminder ay hindi laging tatalo sa note ("na-pay ko na ba yung meralco?")', () {
      // Walang title bonus at walang "maikli" na bonus ang reminder (title lang
      // ito) — kung meron, "Bayaran ang Meralco" ang mauuna kahit note ang sagot.
      final hits = answer('na-pay ko na ba yung meralco?', [bills, payMeralco]);
      expect(ids(hits), [10, 11]);
      expect(hits[1].matchedInTitle, 0);
    });

    test('"may reminder ba ako tungkol sa dentist?" → reminder lang (hindi ang note)', () {
      final hits = answer('may reminder ba ako tungkol sa dentist?', [dentistNote, dentistReminder]);
      expect(hits.single.doc.source, RetrievalSource.reminder);
      expect(hits.single.isSure, isTrue);
    });

    test('walang uri sa tanong → lahat ("kailan ang dentist appointment ko?")', () {
      final hits = answer('kailan ang dentist appointment ko?', [dentistNote, dentistReminder]);
      expect(ids(hits), [2, 1]);
      expect(hits.first.isSure, isTrue);
      expect(hits[1].isSure, isFalse);
    });

    test('walang tumama sa uri → lahat, kasama ang salitang uri ("anong reminders gusto ko?")', () {
      final hits = answer('anong reminders gusto ko?', [docs.last, dentistReminder]);
      expect(ids(hits), [6]); // memory: "Mas gusto ko ng morning reminders"
    });

    test('search(): reminders galing sa repository + scope', () async {
      final r = Retriever(repo: _FakeSearch([...docs, dentistNote, dentistReminder]), clock: () => now);
      final hits = await r.search('may reminder ba ako tungkol sa dentist?');
      expect(hits.single.doc.id, 2);
      expect((await r.search('dentist')).map((h) => h.doc.source).toSet(),
          {RetrievalSource.note, RetrievalSource.reminder});
    });
  });
}