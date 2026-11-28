import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/features/chat/controllers/chat_router.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/retriever.dart';

/// Takbuhin:  flutter test test/rag/rag_bench_test.dart
///
/// ISANG FILE LANG ito (kasama na ang data sa ibaba) — walang ibang file na kailangan.
///
/// R0 — sukatan ng RAG. Walang database, walang phone, walang Qwen:
/// ang tanong ay dumadaan sa parehong daan ng Zoe Chat
/// (ChatRouter.clean → QueryTerms.parse → Retriever.rank), tapos tinitingnan
/// kung tama ang lumabas.
///
///   hit@1   = tama ang UNANG sagot (ito ang nakikita ng user)
///   hit@3   = nasa top 3 ang tama
///   honest  = sa mga tanong na WALANG sagot sa data, walang lumabas
///   wrong   = may lumabas pero mali
///   baka    = R2: ang unang sagot ay "Baka ito? 🤔" (hindi sigurado)
///   sureW   = R2: SIGURADO si Zoe pero mali (ito ang pinakamasama)
///
/// Ang [BenchFloor] ay ang baseline. Bawat step (R1, R2…) ay hindi dapat
/// bumaba rito. Kapag tumaas sa isang step → itaas ang floor sa parehong commit.
///
/// Ang ruta ng chat (kung RAG ba ang pupuntahan ng tanong) ay HINDI sakop
/// dito — nasa test/ai/phrase_bank_test.dart iyon.
class BenchFloor {
  BenchFloor._();

  /// R2 (BM25-style + kumpiyansa): 123 / 156 tama sa #1.
  /// (R1: 119 · R0 baseline, repo 7f0f8d8: 100.)
  static const hit1 = 123;

  /// R2: 126 / 156 nasa top 3. (R1: 126 · R0: 113.)
  static const hit3 = 126;

  /// R2: 9 / 20 tapat na "wala". Ang 11 na iba ay "Baka ito? 🤔" na lahat
  /// (hindi na ipinipilit). (R1: 9 · R0: 9.)
  static const honest = 9;

  /// R2: hanggang ilan lang ang SIGURADO pero mali. Hindi dapat tumaas.
  /// (R1: 33 — lahat ng sagot noon ay sigurado.)
  static const maxSureWrong = 1;
}

/// Isang araw na hindi nagbabago (para sa "bago" na bonus ng Retriever).
final _now = DateTime(2026, 11, 27, 9, 0);

/// R0: note + memory lang ang hinahanap. R4: idagdag ang reminder + task
/// (kailangan munang may RetrievalSource.reminder / task).
const _searchable = {BenchKind.note, BenchKind.memory};

/// Ginagawang RetrievalDoc ang BenchDoc — kapareho ng RetrievalDoc.noteRow /
/// memoryRow. Ang id ay posisyon sa [benchDocs] (simula sa 1).
List<RetrievalDoc> _retrievalDocs() {
  final out = <RetrievalDoc>[];
  for (var i = 0; i < benchDocs.length; i++) {
    final d = benchDocs[i];
    if (!_searchable.contains(d.kind)) continue;
    final updated = _now.subtract(Duration(days: d.daysAgo));
    if (d.kind == BenchKind.memory) {
      out.add(RetrievalDoc(
        source: RetrievalSource.memory,
        id: i + 1,
        title: RetrievalDoc.shortTitle(d.text),
        text: d.text,
        importance: d.importance,
        updatedAt: updated,
      ));
    } else {
      final content = d.text.trim();
      out.add(RetrievalDoc(
        source: RetrievalSource.note,
        id: i + 1,
        title: d.title,
        text: content.isEmpty ? d.title : content,
        pinned: d.pinned,
        updatedAt: updated,
      ));
    }
  }
  return out;
}

/// Top 3 na sagot sa tanong (walang laman = walang nahanap).
/// Ang [docs] ay LAHAT ng note + memory, kaya walang CorpusStats (eksakto ang IDF).
List<RetrievalHit> _answer(String question, List<RetrievalDoc> docs) {
  final terms = QueryTerms.parse(ChatRouter.clean(question));
  if (terms.isEmpty) return const [];
  return Retriever.rank(terms, docs, now: _now).take(3).toList();
}

String _key(RetrievalHit h) => benchDocs[h.doc.id - 1].key;

class _Score {
  int n = 0;
  int answerable = 0;
  int hit1 = 0;
  int hit3 = 0;
  int noAnswer = 0;
  int honest = 0;
  int wrong = 0;
  int maybe = 0;
  int sureWrong = 0;

  void add(BenchCase c, List<RetrievalHit> hits) {
    final got = hits.map(_key).toList();
    n++;
    if (hits.isNotEmpty) {
      final right = c.expect.contains(got.first);
      if (!hits.first.isSure) maybe++;
      if (hits.first.isSure && !right) sureWrong++;
    }
    if (c.expect.isEmpty) {
      noAnswer++;
      if (got.isEmpty) {
        honest++;
      } else {
        wrong++;
      }
      return;
    }
    answerable++;
    if (got.isNotEmpty && c.expect.contains(got.first)) hit1++;
    if (got.any(c.expect.contains)) hit3++;
    if (got.isNotEmpty && !c.expect.contains(got.first)) wrong++;
  }
}

String _pct(int a, int b) => b == 0 ? '    —' : '${(100 * a / b).toStringAsFixed(1).padLeft(5)}%';

void main() {
  group('R0 bench data', () {
    test('walang dobleng key; lahat ng expect ay may doc', () {
      final keys = benchDocs.map((d) => d.key).toList();
      expect(keys.toSet().length, keys.length, reason: 'may dobleng key');
      final missing = [
        for (final c in benchCases)
          for (final k in c.expect)
            if (!keys.contains(k)) '"${c.question}" → $k',
      ];
      expect(missing, isEmpty);
    });

    test('≥ 150 tanong at may laman ang bawat category', () {
      expect(benchCases.length, greaterThanOrEqualTo(150));
      for (final cat in BenchCategory.values) {
        expect(benchCases.where((c) => c.category == cat), isNotEmpty, reason: cat.name);
      }
      final questions = benchCases.map((c) => c.question).toList();
      expect(questions.toSet().length, questions.length, reason: 'may dobleng tanong');
    });

    test('ang "nothing" lang ang walang expect', () {
      for (final c in benchCases) {
        expect(c.expect.isEmpty, c.category == BenchCategory.nothing, reason: c.question);
      }
    });
  });

  test('RAG benchmark — score (hindi dapat bumaba sa BenchFloor)', () {
    final docs = _retrievalDocs();
    final all = _Score();
    final byCat = {for (final c in BenchCategory.values) c: _Score()};
    final byLang = {for (final l in BenchLang.values) l: _Score()};
    final fails = <String>[];

    for (final c in benchCases) {
      final hits = _answer(c.question, docs);
      final got = hits.map(_key).toList();
      all.add(c, hits);
      byCat[c.category]!.add(c, hits);
      byLang[c.lang]!.add(c, hits);
      final ok = c.expect.isEmpty ? got.isEmpty : got.isNotEmpty && c.expect.contains(got.first);
      if (!ok) {
        final want = c.expect.isEmpty ? '(wala)' : c.expect.join(' | ');
        final top = got.isEmpty ? '(wala)' : got.join(', ');
        final how = hits.isEmpty ? '' : (hits.first.isSure ? ' · SIGURADO' : ' · baka');
        fails.add('  [${c.category.name}] "${c.question}"\n      gusto: $want · lumabas: $top$how');
      }
    }

    String row(String name, _Score s) => '${name.padRight(12)} ${'${s.n}'.padLeft(4)} '
        '${_pct(s.hit1, s.answerable)}  ${_pct(s.hit3, s.answerable)}  '
        '${_pct(s.honest, s.noAnswer)}  ${'${s.wrong}'.padLeft(5)}  '
        '${'${s.maybe}'.padLeft(4)}  ${'${s.sureWrong}'.padLeft(5)}';

    final out = StringBuffer()
      ..writeln('')
      ..writeln('══════════ Zoe RAG bench ══════════')
      ..writeln('bucket          n   hit@1   hit@3  honest  wrong  baka  sureW')
      ..writeln(row('LAHAT', all))
      ..writeln('');
    byCat.forEach((k, v) => out.writeln(row(k.name, v)));
    out.writeln('');
    byLang.forEach((k, v) => out.writeln(row('lang:${k.name}', v)));
    out
      ..writeln('')
      ..writeln('Raw: hit@1 ${all.hit1}/${all.answerable} · hit@3 ${all.hit3}/${all.answerable} · '
          'honest ${all.honest}/${all.noAnswer} · wrong ${all.wrong} · '
          'baka ${all.maybe} · sureWrong ${all.sureWrong}')
      ..writeln('Floor: hit@1 ${BenchFloor.hit1} · hit@3 ${BenchFloor.hit3} · '
          'honest ${BenchFloor.honest} · sureWrong ≤ ${BenchFloor.maxSureWrong}')
      ..writeln('')
      ..writeln('Mali / walang nahanap (${fails.length}):')
      ..writeln(fails.join('\n'));
    // ignore: avoid_print
    print(out);

    expect(all.hit1, greaterThanOrEqualTo(BenchFloor.hit1), reason: 'bumaba ang hit@1');
    expect(all.hit3, greaterThanOrEqualTo(BenchFloor.hit3), reason: 'bumaba ang hit@3');
    expect(all.honest, greaterThanOrEqualTo(BenchFloor.honest), reason: 'bumaba ang honest');
    expect(all.sureWrong, lessThanOrEqualTo(BenchFloor.maxSureWrong),
        reason: 'dumami ang sigurado pero mali');
  });
}

// ═══════════════════════════════════════════════════════════════════
// DATA
// ═══════════════════════════════════════════════════════════════════

// R0 — RAG benchmark data. Pekeng data lang (hindi totoong user).
//
// Paano dagdagan:
//   • Bagong note / memory / reminder / task → BenchDoc sa [benchDocs] (natatanging key).
//   • Bagong tanong → BenchCase sa [benchCases]. [expect] = alinman sa mga key ay tama;
//     walang laman = walang dapat lumabas (tapat na "wala akong nakita").
//   • Huwag baguhin ang lumang tanong para lang pumasa — iyon ang sukatan.
//
// 77 docs (note 42, memory 13, reminder 12, task 10) · 176 tanong
// (exact 28, synonym 19, affixTl 22, inflectEn 23, taglish 18, paraphrase 18, remTask 16, nothing 20, textspeak 12)

/// Saan galing ang doc. Sa R0, note + memory lang ang hinahanap ng Retriever;
/// ang reminder + task ay idadagdag sa R4.
enum BenchKind { note, memory, reminder, task }

/// Anong klase ng tanong — para makita kung saan gumaganda bawat step.
enum BenchCategory {
  /// Parehong salita sa tanong at sa note.
  exact,

  /// Gumagana dahil sa synonym list (B6).
  synonym,

  /// Tagalog na banghay: bumili / binili, nag-gas / nagpagas → R1.
  affixTl,

  /// English na banghay: batteries / battery, parked / park → R1.
  inflectEn,

  /// Halo: pinaprint, nag-grocery, na-pay → R1.
  taglish,

  /// Iba ang salita, pareho ang ibig sabihin → R6 / Z1 (embeddings).
  paraphrase,

  /// Nasa reminders / tasks ang sagot → R4.
  remTask,

  /// Walang sagot sa data; dapat walang lumabas → R2.
  nothing,

  /// Text-speak o mali ang baybay.
  textspeak,
}

enum BenchLang { en, tl, taglish }

class BenchDoc {
  const BenchDoc(this.key, this.kind, this.title, this.text,
      {required this.daysAgo, this.pinned = false, this.importance = 3});

  /// 'n:wifi-home', 'm:allergy', 'r:dentist', 't:resume'
  final String key;
  final BenchKind kind;

  /// Note / reminder / task: ang title. Memory: walang laman (content lang).
  final String title;
  final String text;
  final int daysAgo;
  final bool pinned;
  final int importance;
}

class BenchCase {
  const BenchCase(this.question, this.expect, this.category, this.lang);

  final String question;

  /// Alinman sa mga key ay tamang sagot. Walang laman = walang dapat lumabas.
  final List<String> expect;
  final BenchCategory category;
  final BenchLang lang;
}

const benchDocs = <BenchDoc>[
  // ── Notes
  BenchDoc('n:wifi-home', BenchKind.note, 'Wifi bahay',
      'ZoeHome / password: zoe2026', daysAgo: 40, pinned: true),
  BenchDoc('n:wifi-office', BenchKind.note, 'Office wifi',
      'SSID BrixenOffice, pass BX-4421', daysAgo: 90),
  BenchDoc('n:router', BenchKind.note, 'Router',
      'admin login ng router: 192.168.1.1, admin / ZoeAdmin!', daysAgo: 120),
  BenchDoc('n:locker', BenchKind.note, 'Gym',
      'locker code 4521', daysAgo: 60),
  BenchDoc('n:gym-sched', BenchKind.note, 'Gym schedule',
      'Nag-gy-gym ako tuwing Lunes, Miyerkules, Biyernes 6pm', daysAgo: 20),
  BenchDoc('n:passport', BenchKind.note, 'Passport',
      'Nilagay ko ang passport sa drawer ng aparador, kasama ng birth certificate', daysAgo: 200),
  BenchDoc('n:sapatos', BenchKind.note, 'Sapatos',
      'Binili ko ang running shoes sa SM North, size 9, P3,499', daysAgo: 25),
  BenchDoc('n:battery', BenchKind.note, 'Ace Hardware',
      'Bought AA battery x8 and extension cord', daysAgo: 12),
  BenchDoc('n:tv', BenchKind.note, 'TV',
      'Smart TV remote batteries AAA', daysAgo: 150),
  BenchDoc('n:grocery', BenchKind.note, 'Grocery list Sabado',
      'itlog, gatas, bigas 5kg, sabon, toothpaste', daysAgo: 3),
  BenchDoc('n:meralco', BenchKind.note, 'Meralco',
      'Paid Meralco Nov 15 via GCash, ref 88123', daysAgo: 12),
  BenchDoc('n:maynilad', BenchKind.note, 'Maynilad',
      'Nabayaran ko na ang tubig noong Nov 10', daysAgo: 17),
  BenchDoc('n:adobo', BenchKind.note, 'Adobo ni Lola',
      'Recipe: 1 kilo manok, toyo, suka, bawang, paminta, dahon ng laurel. Lutuin ng 45 minuto.', daysAgo: 300, pinned: true),
  BenchDoc('n:sinigang', BenchKind.note, 'Sinigang',
      'Sinigang na baboy: sampalok mix, labanos, kangkong, sitaw', daysAgo: 80),
  BenchDoc('n:mama-gamot', BenchKind.note, 'Gamot ni Mama',
      'losartan 50mg tuwing umaga, metformin pagkatapos kumain', daysAgo: 30, pinned: true),
  BenchDoc('n:papa-gamot', BenchKind.note, 'Gamot ni Papa',
      'amlodipine 5mg bago matulog', daysAgo: 45),
  BenchDoc('n:car-plate', BenchKind.note, 'Kotse',
      'plate number NBC 1234, rehistro hanggang Marso', daysAgo: 100),
  BenchDoc('n:parking', BenchKind.note, 'Parking',
      'Naka-park ang kotse sa Level 3, slot B12, SM Megamall', daysAgo: 1),
  BenchDoc('n:dentist', BenchKind.note, 'Dentist',
      'Dr. Reyes, Tomas Morato clinic, 0917 555 0101', daysAgo: 70),
  BenchDoc('n:bday-nino', BenchKind.note, 'Bday ni Niño',
      'Disyembre 12, gusto niya ng Lego', daysAgo: 50),
  BenchDoc('n:landlord', BenchKind.note, 'Upa',
      'Bayad sa upa tuwing ika-5, kay Aling Nena, P8,000', daysAgo: 110),
  BenchDoc('n:bike-lock', BenchKind.note, 'Bike',
      'Combination ng lock ng bisikleta 0729', daysAgo: 160),
  BenchDoc('n:laundry', BenchKind.note, 'Laundry',
      'Nilabhan ko ang kurtina noong Linggo; susunod ang kumot', daysAgo: 5),
  BenchDoc('n:movies', BenchKind.note, 'Movies to watch',
      'Dune Part Three, Inside Out 3, Heneral Luna rewatch', daysAgo: 35),
  BenchDoc('n:boss-email', BenchKind.note, 'Boss',
      'email ni Sir Carlo: carlo@brixen.ai', daysAgo: 140),
  BenchDoc('n:insurance', BenchKind.note, 'Insurance',
      'Policy number PL-77812, renewal every June', daysAgo: 220),
  BenchDoc('n:flight', BenchKind.note, 'Flight Cebu',
      'Cebu Pacific 5J 561, Dec 20, 6:15 AM, booking ref XKQ2PL', daysAgo: 9, pinned: true),
  BenchDoc('n:vitamins', BenchKind.note, 'Vitamins',
      'Vitamin C at zinc tuwing umaga', daysAgo: 65),
  BenchDoc('n:paluto', BenchKind.note, 'Paluto sa birthday',
      'Order kay Ate Joy: pancit, lumpia, leche flan para sa 30 tao', daysAgo: 14),
  BenchDoc('n:spare-key', BenchKind.note, 'Spare key',
      'Ang reserbang susi ng bahay ay iniwan ko kay Kuya Ben', daysAgo: 95),
  BenchDoc('n:netflix', BenchKind.note, 'Netflix',
      'account login: zoe.user@gmail.com, shared with sis', daysAgo: 130),
  BenchDoc('n:printer', BenchKind.note, 'Printer',
      'Pina-print ko ang resume sa Ministop, P5 bawat pahina', daysAgo: 8),
  BenchDoc('n:pagibig', BenchKind.note, 'Pag-IBIG',
      'Pag-IBIG MID number 1234-5678-9012', daysAgo: 250),
  BenchDoc('n:blood-type', BenchKind.note, 'Health',
      'Blood type ko O+', daysAgo: 400),
  BenchDoc('n:plants', BenchKind.note, 'Halaman',
      'Diligan ang mga halaman tuwing umaga; ang orchid tuwing Sabado lang', daysAgo: 28),
  BenchDoc('n:tita-address', BenchKind.note, 'Address ni Tita Lorna',
      'Blk 5 Lot 12, Camella Homes, Bacoor, Cavite', daysAgo: 180),
  BenchDoc('n:books', BenchKind.note, 'Books',
      'Hiniram ni Mia ang libro kong Atomic Habits', daysAgo: 22),
  BenchDoc('n:gas', BenchKind.note, 'Gasolina',
      'Nagpagas ako noong Martes, P1,500 full tank sa Petron', daysAgo: 4),
  BenchDoc('n:vet', BenchKind.note, 'Vet ni Brownie',
      'Anti-rabies ni Brownie sa Pet Express, susunod Enero', daysAgo: 75),
  BenchDoc('n:lazada', BenchKind.note, 'Lazada orders',
      'Inorder ko ang phone case at charger, darating sa Biyernes', daysAgo: 2),
  BenchDoc('n:meeting-notes', BenchKind.note, 'Meeting notes Nov 20',
      'Napag-usapan ang Zoe launch, deadline Disyembre 15', daysAgo: 7),
  BenchDoc('n:umbrella', BenchKind.note, 'Payong',
      'Naiwan ko ang payong sa opisina', daysAgo: 6),
  // ── Memories (sinabi ng user)
  BenchDoc('m:allergy', BenchKind.memory, '',
      'Allergic ako sa hipon', daysAgo: 60, importance: 4),
  BenchDoc('m:fav-food', BenchKind.memory, '',
      'Paborito ko ang sinigang', daysAgo: 40),
  BenchDoc('m:morning', BenchKind.memory, '',
      'Mas gusto ko ng morning reminders', daysAgo: 90),
  BenchDoc('m:coffee', BenchKind.memory, '',
      'Hindi ako umiinom ng kape', daysAgo: 30),
  BenchDoc('m:call-me', BenchKind.memory, '',
      'Call me AC', daysAgo: 120),
  BenchDoc('m:bday-me', BenchKind.memory, '',
      'Birthday ko ay March 3', daysAgo: 200, importance: 4),
  BenchDoc('m:bike', BenchKind.memory, '',
      'Mahilig akong mag-bike tuwing Linggo', daysAgo: 70),
  BenchDoc('m:ate', BenchKind.memory, '',
      'Kumain kami ng sinigang sa bahay ni Lola', daysAgo: 1),
  BenchDoc('m:dog', BenchKind.memory, '',
      'May aso ako, si Brownie', daysAgo: 150),
  BenchDoc('m:night-shift', BenchKind.memory, '',
      'Night shift ang trabaho ko', daysAgo: 60),
  BenchDoc('m:stress', BenchKind.memory, '',
      'Kapag stressed ako, gusto ko ng tahimik na music', daysAgo: 20),
  BenchDoc('m:fav-color', BenchKind.memory, '',
      'Favorite color ko ay lavender', daysAgo: 100),
  BenchDoc('m:sister', BenchKind.memory, '',
      'May kapatid akong si Mia', daysAgo: 110),
  // ── Reminders (R4)
  BenchDoc('r:dentist', BenchKind.reminder, 'Dentist appointment',
      'Dec 3, 3:00 PM', daysAgo: 3),
  BenchDoc('r:meralco', BenchKind.reminder, 'Bayaran ang Meralco',
      'tuwing ika-15', daysAgo: 30),
  BenchDoc('r:gamot', BenchKind.reminder, 'Uminom ng gamot',
      'araw-araw 8:00 AM', daysAgo: 60),
  BenchDoc('r:vet', BenchKind.reminder, 'Dalhin si Brownie sa vet',
      'Jan 10', daysAgo: 10),
  BenchDoc('r:passport-renew', BenchKind.reminder, 'Renew passport',
      'Feb 1', daysAgo: 40),
  BenchDoc('r:call-mama', BenchKind.reminder, 'Tawagan si Mama',
      'Linggo 7 PM', daysAgo: 5),
  BenchDoc('r:meeting', BenchKind.reminder, 'Team meeting',
      'Lunes 10 AM', daysAgo: 2),
  BenchDoc('r:laundry', BenchKind.reminder, 'Kunin ang laundry',
      'bukas 5 PM', daysAgo: 1),
  BenchDoc('r:bday-nino', BenchKind.reminder, 'Bilhan ng regalo si Niño',
      'Dec 10', daysAgo: 6),
  BenchDoc('r:car', BenchKind.reminder, 'Car registration',
      'Marso', daysAgo: 50),
  BenchDoc('r:plants', BenchKind.reminder, 'Diligan ang halaman',
      'araw-araw 7 AM', daysAgo: 28),
  BenchDoc('r:trash', BenchKind.reminder, 'Ilabas ang basura',
      'Martes at Biyernes 8 PM', daysAgo: 15),
  // ── Tasks (R4)
  BenchDoc('t:resume', BenchKind.task, 'Ayusin ang resume',
      '', daysAgo: 4),
  BenchDoc('t:report', BenchKind.task, 'Tapusin ang sales report',
      '', daysAgo: 2),
  BenchDoc('t:groceries', BenchKind.task, 'Mamili ng groceries',
      '', daysAgo: 3),
  BenchDoc('t:cleaning', BenchKind.task, 'Linisin ang kwarto',
      '', daysAgo: 6),
  BenchDoc('t:budget', BenchKind.task, 'Gumawa ng budget sa Excel',
      '', daysAgo: 9),
  BenchDoc('t:study', BenchKind.task, 'Mag-aral ng Flutter',
      '', daysAgo: 11),
  BenchDoc('t:pack', BenchKind.task, 'Mag-impake para sa Cebu',
      '', daysAgo: 1),
  BenchDoc('t:return-book', BenchKind.task, 'Kunin ang libro kay Mia',
      '', daysAgo: 5),
  BenchDoc('t:fix-sink', BenchKind.task, 'Ipaayos ang lababo',
      '', daysAgo: 8),
  BenchDoc('t:taxes', BenchKind.task, 'I-file ang ITR',
      '', daysAgo: 20),
];

const benchCases = <BenchCase>[
  // ── exact
  BenchCase('ano wifi password sa bahay?', ['n:wifi-home'], BenchCategory.exact, BenchLang.tl),
  BenchCase("what's the office wifi password?", ['n:wifi-office'], BenchCategory.exact, BenchLang.en),
  BenchCase('locker code ko sa gym', ['n:locker'], BenchCategory.exact, BenchLang.tl),
  BenchCase('plate number ng kotse', ['n:car-plate'], BenchCategory.exact, BenchLang.tl),
  BenchCase('dentist number', ['n:dentist'], BenchCategory.exact, BenchLang.en),
  BenchCase('email ni Sir Carlo', ['n:boss-email'], BenchCategory.exact, BenchLang.tl),
  BenchCase('insurance policy number', ['n:insurance'], BenchCategory.exact, BenchLang.en),
  BenchCase('flight booking ref sa Cebu', ['n:flight'], BenchCategory.exact, BenchLang.taglish),
  BenchCase('adobo recipe ni lola', ['n:adobo'], BenchCategory.exact, BenchLang.taglish),
  BenchCase('gamot ni mama', ['n:mama-gamot'], BenchCategory.exact, BenchLang.tl),
  BenchCase('gamot ni papa', ['n:papa-gamot'], BenchCategory.exact, BenchLang.tl),
  BenchCase('kailan bday ni nino?', ['n:bday-nino'], BenchCategory.exact, BenchLang.tl),
  BenchCase('netflix login', ['n:netflix'], BenchCategory.exact, BenchLang.en),
  BenchCase('parking slot ng kotse', ['n:parking'], BenchCategory.exact, BenchLang.taglish),
  BenchCase('blood type ko', ['n:blood-type'], BenchCategory.exact, BenchLang.taglish),
  BenchCase('address ni tita lorna', ['n:tita-address'], BenchCategory.exact, BenchLang.tl),
  BenchCase('vet ni brownie', ['n:vet'], BenchCategory.exact, BenchLang.tl),
  BenchCase('pag-ibig number ko', ['n:pagibig'], BenchCategory.exact, BenchLang.taglish),
  BenchCase('combination ng bike lock', ['n:bike-lock'], BenchCategory.exact, BenchLang.taglish),
  BenchCase('lazada order ko', ['n:lazada'], BenchCategory.exact, BenchLang.taglish),
  BenchCase('meeting notes deadline', ['n:meeting-notes'], BenchCategory.exact, BenchLang.en),
  BenchCase('movies to watch', ['n:movies'], BenchCategory.exact, BenchLang.en),
  BenchCase('sinigang recipe', ['n:sinigang'], BenchCategory.exact, BenchLang.taglish),
  BenchCase('toothpaste sa grocery list', ['n:grocery'], BenchCategory.exact, BenchLang.taglish),
  BenchCase('sino ang kapatid ko?', ['m:sister'], BenchCategory.exact, BenchLang.tl),
  BenchCase('saan ko itinago ang passport?', ['n:passport'], BenchCategory.exact, BenchLang.tl),
  BenchCase('ano ang hiniram ni Mia?', ['n:books'], BenchCategory.exact, BenchLang.tl),
  BenchCase('router admin password', ['n:router'], BenchCategory.exact, BenchLang.en),
  // ── synonym
  BenchCase('ano password ng internet?', ['n:wifi-home', 'n:wifi-office'], BenchCategory.synonym, BenchLang.tl),
  BenchCase('ano yung pw ng net?', ['n:wifi-home', 'n:wifi-office'], BenchCategory.synonym, BenchLang.tl),
  BenchCase('susi ng bahay', ['n:spare-key'], BenchCategory.synonym, BenchLang.tl),
  BenchCase('where is my spare key?', ['n:spare-key'], BenchCategory.synonym, BenchLang.en),
  BenchCase('kaarawan ni Niño', ['n:bday-nino'], BenchCategory.synonym, BenchLang.tl),
  BenchCase('medicine ni nanay', ['n:mama-gamot'], BenchCategory.synonym, BenchLang.taglish),
  BenchCase('meds ni dad', ['n:papa-gamot'], BenchCategory.synonym, BenchLang.taglish),
  BenchCase('car plate', ['n:car-plate'], BenchCategory.synonym, BenchLang.en),
  BenchCase('renta sa bahay', ['n:landlord'], BenchCategory.synonym, BenchLang.tl),
  BenchCase('electric bill', ['n:meralco'], BenchCategory.synonym, BenchLang.en),
  BenchCase('water bill', ['n:maynilad'], BenchCategory.synonym, BenchLang.en),
  BenchCase("my mom's meds", ['n:mama-gamot'], BenchCategory.synonym, BenchLang.en),
  BenchCase('ticket sa flight', ['n:flight'], BenchCategory.synonym, BenchLang.taglish),
  BenchCase('paborito kong pagkain', ['m:fav-food'], BenchCategory.synonym, BenchLang.tl),
  BenchCase('favorite color', ['m:fav-color'], BenchCategory.synonym, BenchLang.en),
  BenchCase('anong allergy ko?', ['m:allergy'], BenchCategory.synonym, BenchLang.taglish),
  BenchCase('birthday ko', ['m:bday-me'], BenchCategory.synonym, BenchLang.taglish),
  BenchCase('nabayaran ko na ba ang kuryente?', ['n:meralco'], BenchCategory.synonym, BenchLang.tl),
  BenchCase('doktor ng ngipin', ['n:dentist'], BenchCategory.synonym, BenchLang.tl),
  // ── affixTl
  BenchCase('saan ako bumili ng sapatos?', ['n:sapatos'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('sino ang humiram?', ['n:books'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('kailan ako nag-gas?', ['n:gas'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('kailan ako magdidilig?', ['n:plants'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('ano ang lulutuin ko?', ['n:adobo'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('sino ang nagpaluto?', ['n:paluto'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('ano ang kinain namin kina lola?', ['m:ate'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('kailan ako huling naglaba?', ['n:laundry'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('kailan ako maglalaba ulit?', ['n:laundry'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('saan ako kumain ng sinigang?', ['m:ate'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('kanino ko iniwan ang reserbang susi?', ['n:spare-key'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('sino ang magluluto ng pancit?', ['n:paluto'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('binilhan ko ba ng lego si nino?', ['n:bday-nino'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('nadiligan ko na ba ang orchid?', ['n:plants'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('ano ang binili ko sa SM?', ['n:sapatos'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('saan ko nilagay ang birth certificate?', ['n:passport'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('sino ang nanghiram ng libro?', ['n:books'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('magkano ang ibinayad ko sa upa?', ['n:landlord'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('kailan darating ang inorder ko?', ['n:lazada'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('iinumin ni mama na gamot', ['n:mama-gamot'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('kailan ko nilabhan ang kurtina?', ['n:laundry'], BenchCategory.affixTl, BenchLang.tl),
  BenchCase('saan ko naiwan ang payong?', ['n:umbrella'], BenchCategory.affixTl, BenchLang.tl),
  // ── inflectEn
  BenchCase('where did I buy the batteries?', ['n:battery'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('what did I buy at Ace?', ['n:battery'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase("where's my parked car?", ['n:parking'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('when are my flights?', ['n:flight'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('where did I park?', ['n:parking'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('when did I pay meralco?', ['n:meralco'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('who borrowed my book?', ['n:books'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('what shoes did I buy?', ['n:sapatos'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('what shoe size am I?', ['n:sapatos'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('what movies am I watching?', ['n:movies'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('what did I order online?', ['n:lazada'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('which bills have I paid?', ['n:meralco'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('what medicines does mom take?', ['n:mama-gamot'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('who has my spare keys?', ['n:spare-key'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase("what are the dentist's contact details?", ['n:dentist'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('list my insurance policies', ['n:insurance'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('what vitamins am I taking?', ['n:vitamins'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('where did I put the birth certificates?', ['n:passport'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('batteries for the TV remote', ['n:tv'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('when is my gym schedule?', ['n:gym-sched'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase("who's paying the rent?", ['n:landlord'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('what chargers did I order?', ['n:lazada'], BenchCategory.inflectEn, BenchLang.en),
  BenchCase('ordered phone cases', ['n:lazada'], BenchCategory.inflectEn, BenchLang.en),
  // ── taglish
  BenchCase('na-pay ko na ba yung meralco?', ['n:meralco'], BenchCategory.taglish, BenchLang.taglish),
  BenchCase('kailan ako nag-grocery?', ['n:grocery'], BenchCategory.taglish, BenchLang.taglish),
  BenchCase('anong pinaprint ko?', ['n:printer'], BenchCategory.taglish, BenchLang.taglish),
  BenchCase('anong pinaorder ko?', ['n:lazada'], BenchCategory.taglish, BenchLang.taglish),
  BenchCase('nag-shopping ako ng shoes diba?', ['n:sapatos'], BenchCategory.taglish, BenchLang.taglish),
  BenchCase('saan ako nag-park?', ['n:parking'], BenchCategory.taglish, BenchLang.taglish),
  BenchCase('na-renew ko na ba ang insurance?', ['n:insurance'], BenchCategory.taglish, BenchLang.taglish),
  BenchCase('kailan ako nag-gym?', ['n:gym-sched'], BenchCategory.taglish, BenchLang.taglish),
  BenchCase('na-save ko ba yung email ni boss?', ['n:boss-email'], BenchCategory.taglish, BenchLang.taglish),
  BenchCase('nag-book ako ng flight papuntang cebu', ['n:flight'], BenchCategory.taglish, BenchLang.taglish),
  BenchCase('na-miss ko ba yung vitamins?', ['n:vitamins'], BenchCategory.taglish, BenchLang.taglish),
  BenchCase('ni-lock ko ba yung bike?', ['n:bike-lock'], BenchCategory.taglish, BenchLang.taglish),
  BenchCase('pina-deliver ko yung charger kailan?', ['n:lazada'], BenchCategory.taglish, BenchLang.taglish),
  BenchCase('na-watch ko na ba yung dune?', ['n:movies'], BenchCategory.taglish, BenchLang.taglish),
  BenchCase('nagpa-print ako ng resume saan?', ['n:printer'], BenchCategory.taglish, BenchLang.taglish),
  BenchCase('magpa-print ng resume magkano?', ['n:printer'], BenchCategory.taglish, BenchLang.taglish),
  BenchCase('na-order ko na ba ang phone case?', ['n:lazada'], BenchCategory.taglish, BenchLang.taglish),
  BenchCase('nag-email ba si Sir Carlo?', ['n:boss-email'], BenchCategory.taglish, BenchLang.taglish),
  // ── paraphrase
  BenchCase('pang-login sa net', ['n:wifi-home', 'n:wifi-office'], BenchCategory.paraphrase, BenchLang.taglish),
  BenchCase('kailan ako huling nagpakarga?', ['n:gas'], BenchCategory.paraphrase, BenchLang.tl),
  BenchCase('ano yung ipapakain ko sa party?', ['n:paluto'], BenchCategory.paraphrase, BenchLang.tl),
  BenchCase('anong pagkain ang bawal sa akin?', ['m:allergy'], BenchCategory.paraphrase, BenchLang.tl),
  BenchCase('may alaga ba akong hayop?', ['m:dog'], BenchCategory.paraphrase, BenchLang.tl),
  BenchCase('ano ang ayaw kong inumin?', ['m:coffee'], BenchCategory.paraphrase, BenchLang.tl),
  BenchCase('anong oras ako pumapasok sa trabaho?', ['m:night-shift'], BenchCategory.paraphrase, BenchLang.tl),
  BenchCase('ano ang nakakatulong kapag pagod ang isip ko?', ['m:stress'], BenchCategory.paraphrase, BenchLang.tl),
  BenchCase('pinaka-gusto kong kulay?', ['m:fav-color'], BenchCategory.paraphrase, BenchLang.tl),
  BenchCase("my sister's name", ['m:sister'], BenchCategory.paraphrase, BenchLang.en),
  BenchCase('when did I wash the curtains?', ['n:laundry'], BenchCategory.paraphrase, BenchLang.en),
  BenchCase('where did I leave my umbrella?', ['n:umbrella'], BenchCategory.paraphrase, BenchLang.en),
  BenchCase('how many eggs do I need?', ['n:grocery'], BenchCategory.paraphrase, BenchLang.en),
  BenchCase('plants watering schedule', ['n:plants'], BenchCategory.paraphrase, BenchLang.en),
  BenchCase('saan nakaparada ang kotse ko?', ['n:parking'], BenchCategory.paraphrase, BenchLang.tl),
  BenchCase('password ng streaming account ko', ['n:netflix'], BenchCategory.paraphrase, BenchLang.taglish),
  BenchCase('when did I last refuel?', ['n:gas'], BenchCategory.paraphrase, BenchLang.en),
  BenchCase("what should I call you... I mean what's my nickname?", ['m:call-me'], BenchCategory.paraphrase, BenchLang.en),
  // ── remTask
  BenchCase('may reminder ba ako tungkol sa dentist?', ['r:dentist'], BenchCategory.remTask, BenchLang.taglish),
  BenchCase('kailan ang dentist appointment ko?', ['r:dentist'], BenchCategory.remTask, BenchLang.taglish),
  BenchCase('anong task ko tungkol sa resume?', ['t:resume'], BenchCategory.remTask, BenchLang.taglish),
  BenchCase('may gagawin ba ako sa excel?', ['t:budget'], BenchCategory.remTask, BenchLang.taglish),
  BenchCase('kailan ko ire-renew ang passport?', ['r:passport-renew'], BenchCategory.remTask, BenchLang.taglish),
  BenchCase('reminder ko kay brownie', ['r:vet'], BenchCategory.remTask, BenchLang.taglish),
  BenchCase('kailan ang team meeting?', ['r:meeting'], BenchCategory.remTask, BenchLang.taglish),
  BenchCase('may task ba akong maglinis ng kwarto?', ['t:cleaning'], BenchCategory.remTask, BenchLang.taglish),
  BenchCase('ano ang dapat kong i-file?', ['t:taxes'], BenchCategory.remTask, BenchLang.taglish),
  BenchCase('kailangan ko bang kunin ang libro kay mia?', ['t:return-book'], BenchCategory.remTask, BenchLang.tl),
  BenchCase('reminders about my meds', ['r:gamot'], BenchCategory.remTask, BenchLang.en),
  BenchCase('what tasks do I have for the cebu trip?', ['t:pack'], BenchCategory.remTask, BenchLang.en),
  BenchCase('may reminder ba akong tawagan si mama?', ['r:call-mama'], BenchCategory.remTask, BenchLang.taglish),
  BenchCase('ano ang task ko sa sales report?', ['t:report'], BenchCategory.remTask, BenchLang.taglish),
  BenchCase('reminder sa basura', ['r:trash'], BenchCategory.remTask, BenchLang.taglish),
  BenchCase('kailan ko ipapaayos ang lababo?', ['t:fix-sink'], BenchCategory.remTask, BenchLang.tl),
  // ── nothing
  BenchCase('ano ang pangalan ng aso ng kapitbahay?', [], BenchCategory.nothing, BenchLang.tl),
  BenchCase('magkano ang ginto ngayon?', [], BenchCategory.nothing, BenchLang.tl),
  BenchCase('sino ang presidente ng pilipinas?', [], BenchCategory.nothing, BenchLang.tl),
  BenchCase("what's the capital of japan?", [], BenchCategory.nothing, BenchLang.en),
  BenchCase('ano ang password ng facebook ko?', [], BenchCategory.nothing, BenchLang.taglish),
  BenchCase('saan ko nilagay ang salamin ko?', [], BenchCategory.nothing, BenchLang.tl),
  BenchCase('kailan ang bday ni Carlo?', [], BenchCategory.nothing, BenchLang.taglish),
  BenchCase("what's my driver's license number?", [], BenchCategory.nothing, BenchLang.en),
  BenchCase('ano ang wifi password sa cafe?', [], BenchCategory.nothing, BenchLang.taglish),
  BenchCase('may utang ba si Ben sa akin?', [], BenchCategory.nothing, BenchLang.tl),
  BenchCase('anong oras ang laro ng gilas?', [], BenchCategory.nothing, BenchLang.tl),
  BenchCase('recipe ng kare-kare', [], BenchCategory.nothing, BenchLang.taglish),
  BenchCase('where did I put my glasses?', [], BenchCategory.nothing, BenchLang.en),
  BenchCase('ano ang paborito kong pelikula?', [], BenchCategory.nothing, BenchLang.tl),
  BenchCase('kailan ang anniversary namin?', [], BenchCategory.nothing, BenchLang.taglish),
  BenchCase('magkano ang tuition ko?', [], BenchCategory.nothing, BenchLang.taglish),
  BenchCase("what's my blood pressure?", [], BenchCategory.nothing, BenchLang.en),
  BenchCase('may tubig ba sa ref?', [], BenchCategory.nothing, BenchLang.tl),
  BenchCase('ano ang plate number ng motor ko?', [], BenchCategory.nothing, BenchLang.taglish),
  BenchCase('sino ang crush ko?', [], BenchCategory.nothing, BenchLang.taglish),
  // ── textspeak
  BenchCase('anu pw ng wifi s bahay', ['n:wifi-home'], BenchCategory.textspeak, BenchLang.tl),
  BenchCase('ung locker code q', ['n:locker'], BenchCategory.textspeak, BenchLang.tl),
  BenchCase('kelan bday ni nino', ['n:bday-nino'], BenchCategory.textspeak, BenchLang.tl),
  BenchCase('pls show my netflix login', ['n:netflix'], BenchCategory.textspeak, BenchLang.en),
  BenchCase('wifi pasword', ['n:wifi-home', 'n:wifi-office'], BenchCategory.textspeak, BenchLang.en),
  BenchCase('gamot ni mamah', ['n:mama-gamot'], BenchCategory.textspeak, BenchLang.tl),
  BenchCase('plate nunber', ['n:car-plate'], BenchCategory.textspeak, BenchLang.en),
  BenchCase('adobo recipie', ['n:adobo'], BenchCategory.textspeak, BenchLang.en),
  BenchCase('vitamns ko', ['n:vitamins'], BenchCategory.textspeak, BenchLang.taglish),
  BenchCase('grocerry list', ['n:grocery'], BenchCategory.textspeak, BenchLang.en),
  BenchCase('meralko', ['n:meralco'], BenchCategory.textspeak, BenchLang.tl),
  BenchCase('pasaport ko saan', ['n:passport'], BenchCategory.textspeak, BenchLang.tl),
];