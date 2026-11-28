import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/database/models/memory_item.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';
import 'package:zoe_remind/memory/companion_facts.dart';
import 'package:zoe_remind/rag/context_pack.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';

/// Takbuhin:  flutter test test/rag/context_pack_test.dart
///
/// R7 — Context Pack (pure, walang database): format, ids, memory na may
/// kinalaman lang, lakas ng memory, win kapag down, s1, budget ≤ 120 tokens,
/// crisis → blocked, memory OFF.
void main() {
  // Sabado, Nov 28 2026, 4 PM.
  final now = DateTime(2026, 11, 28, 16, 0);

  MemoryItem mem(
    int id,
    String content, {
    FactKind kind = FactKind.general,
    String? value,
    int importance = 3,
    int useCount = 0,
    int daysAgo = 60,
    int? usedDaysAgo,
  }) {
    final t = now.subtract(Duration(days: daysAgo));
    return MemoryItem(
      id: id,
      content: content,
      kind: kind,
      value: value,
      importance: importance,
      createdAt: t,
      updatedAt: t,
      useCount: useCount,
      lastUsedAt: usedDaysAgo == null ? null : now.subtract(Duration(days: usedDaysAgo)),
    );
  }

  final ac = mem(1, 'Tawagin akong AC', kind: FactKind.nickname, value: 'AC');
  final diretso = mem(2, 'Diretsuhin mo lang ako', kind: FactKind.style, value: 'diretso');
  final listen =
      mem(3, 'Kapag stressed ako, makinig ka muna', kind: FactKind.stressHelp, value: 'listen');

  RetrievalDoc note(int id, String title, String text) => RetrievalDoc(
        source: RetrievalSource.note,
        id: id,
        title: title,
        text: text,
        updatedAt: now,
      );

  RetrievalDoc reminder(int id, String title,
          {String? date, String? time, String repeat = 'none', bool done = false}) =>
      RetrievalDoc(
        source: RetrievalSource.reminder,
        id: id,
        title: title,
        text: '',
        date: date,
        time: time,
        repeat: repeat,
        done: done,
        updatedAt: now,
      );

  RetrievalDoc task(int id, String title, {String text = '', String? date, bool done = false}) =>
      RetrievalDoc(
        source: RetrievalSource.task,
        id: id,
        title: title,
        text: text,
        date: date,
        done: done,
        updatedAt: now,
      );

  RetrievalHit hit(RetrievalDoc doc, {bool sure = true}) => RetrievalHit(
        doc: doc,
        score: 1,
        matched: 1,
        matchedInTitle: 0,
        coverage: sure ? 1 : 0.5,
        confidence: sure ? RetrievalConfidence.strong : RetrievalConfidence.maybe,
      );

  group('buong pack', () {
    test('pagod + meeting bukas → u, m1, mood, s1 (halimbawa sa plano)', () {
      final pack = ContextPack.build(
        'pagod na ako sa trabaho, may meeting pa bukas',
        now: now,
        memories: [ac, diretso, listen, mem(4, 'Ayoko ng maagang meeting')],
        zoeMood: MoodState.gentle,
        hits: [hit(reminder(9, 'Meeting kay boss', date: '2026-11-29', time: '09:00'))],
      );
      expect(pack.blocked, isFalse);
      expect(pack.ids, ['u', 'm1', 'mood', 's1']);
      expect(
        pack.toPrompt(),
        '[u] name: AC · style: diretso · stress: listen\n'
        '[m1] Ayoko ng maagang meeting\n'
        '[mood] user: tired 1 · zoe: gentle\n'
        '[s1] reminder · Meeting kay boss · tomorrow 09:00',
      );
      expect(pack.fact('m1')!.ref, 'memory#4');
      expect(pack.fact('s1')!.ref, 'reminder#9');
      expect(pack.fact('u')!.ref, isNull);
      expect(pack.tokens, lessThanOrEqualTo(ContextPack.maxTokens));
    });

    test('hinahanap ng s1: walang salitang pakiramdam / oras / stopword', () {
      expect(ContextPack.searchQuery('pagod na ako sa trabaho, may meeting pa bukas'),
          'trabaho meeting');
      expect(ContextPack.searchQuery('pagod na ako'), '');
    });

    test('"kumusta?" → u + mood lang (walang memory na walang kinalaman)', () {
      final pack = ContextPack.build(
        'kumusta?',
        now: now,
        memories: [ac, mem(5, 'Allergic ako sa hipon'), mem(6, 'Nag-gy-gym ako tuwing MWF')],
      );
      expect(pack.ids, ['u', 'mood']);
      expect(pack.fact('u')!.text, 'name: AC');
      expect(pack.fact('mood')!.text, 'user: neutral · zoe: content');
    });

    test('stress ay kasama lang kapag down ang user', () {
      final happy = ContextPack.build('ang saya ko ngayon', now: now, memories: [ac, listen]);
      expect(happy.fact('u')!.text, 'name: AC');
      final down = ContextPack.build('ang lungkot ko ngayon', now: now, memories: [ac, listen]);
      expect(down.fact('u')!.text, 'name: AC · stress: listen');
    });

    test('PackFact.line — may "(unsure)" kapag hindi sigurado', () {
      const f = PackFact('s1', PackFactKind.snippet, 'note · Wifi', ref: 'note#3', sure: false);
      expect(f.line, '[s1] note · Wifi (unsure)');
      const m = PackFact('m1', PackFactKind.memory, 'Allergic ako sa hipon');
      expect(m.line, '[m1] Allergic ako sa hipon');
    });
  });

  group('memories', () {
    test('may kinalaman (parehong salita) → m1', () {
      final pack = ContextPack.build(
        'ang sarap ng hipon',
        now: now,
        memories: [mem(5, 'Allergic ako sa hipon'), mem(6, 'Paborito ko ang sinigang')],
      );
      expect(pack.fact('m1')!.text, 'Allergic ako sa hipon');
      expect(pack.fact('m1')!.ref, 'memory#5');
      expect(pack.fact('m2'), isNull);
    });

    test('Memory Recall synonym: "shrimp" ↔ "Allergic ako sa hipon"', () {
      final pack = ContextPack.build(
        'gusto ko ng shrimp pasta',
        now: now,
        memories: [mem(5, 'Allergic ako sa hipon')],
      );
      expect(pack.fact('m1')!.text, 'Allergic ako sa hipon');
    });

    test('Memory Recall: "lechon tayo mamaya!" ↔ "Vegetarian ako"', () {
      final pack = ContextPack.build(
        'lechon tayo mamaya!',
        now: now,
        memories: [mem(7, 'Vegetarian ako')],
      );
      expect(pack.fact('m1')!.text, 'Vegetarian ako');
    });

    test('pantay ang tumama → mas malakas muna (use_count, bagong gamit)', () {
      final pack = ContextPack.build(
        'gawa tayo ng kape',
        now: now,
        memories: [
          mem(10, 'Kape ko tuwing umaga: barako'),
          mem(11, 'Mas gusto ko ng kape na matamis', useCount: 5, usedDaysAgo: 1),
        ],
      );
      expect(pack.fact('m1')!.ref, 'memory#11');
      expect(pack.fact('m2')!.ref, 'memory#10');
    });

    test('mas maraming salitang tumama → nauuna kahit mas mahina', () {
      final pack = ContextPack.build(
        'nasaan yung sapatos at payong',
        now: now,
        memories: [
          mem(12, 'Sapatos size ko 8', useCount: 9, usedDaysAgo: 0, importance: 5),
          mem(13, 'Iniwan ko ang sapatos at payong sa kotse'),
        ],
      );
      expect(pack.fact('m1')!.ref, 'memory#13');
      expect(pack.fact('m2')!.ref, 'memory#12');
    });

    test('hanggang 2 memory lang', () {
      final pack = ContextPack.build(
        'kape',
        now: now,
        memories: [
          mem(20, 'Kape sa umaga'),
          mem(21, 'Kape na barako'),
          mem(22, 'Walang asukal ang kape ko'),
        ],
      );
      expect(pack.ids.where((id) => id.startsWith('m') && id != 'mood').toList(), ['m1', 'm2']);
    });

    test('nickname / style / stress_help ay hindi nagiging m (nasa u na)', () {
      final pack = ContextPack.build('hi AC', now: now, memories: [ac, diretso]);
      expect(pack.fact('m1'), isNull);
      expect(pack.fact('u')!.text, 'name: AC · style: diretso');
    });

    test('down ang user + may win → isinasama ang win kahit hindi tugma', () {
      final pack = ContextPack.build(
        'ang lungkot ko ngayon',
        now: now,
        memories: [mem(30, 'Nakapasa ako sa board exam', kind: FactKind.win), mem(5, 'Allergic ako sa hipon')],
      );
      expect(pack.fact('m1')!.text, 'Nakapasa ako sa board exam');
      expect(pack.fact('m1')!.ref, 'memory#30');
      expect(pack.fact('m2'), isNull);
    });

    test('masaya ang user → walang win', () {
      final pack = ContextPack.build(
        'ang saya ko ngayon',
        now: now,
        memories: [mem(30, 'Nakapasa ako sa board exam', kind: FactKind.win)],
      );
      expect(pack.fact('m1'), isNull);
    });

    test('down + may tugmang memory → tugma muna, tapos win sa m2', () {
      final pack = ContextPack.build(
        'ang lungkot ko, ayoko ng meeting',
        now: now,
        memories: [
          mem(30, 'Nakapasa ako sa board exam', kind: FactKind.win),
          mem(4, 'Ayoko ng maagang meeting'),
        ],
      );
      expect(pack.fact('m1')!.ref, 'memory#4');
      expect(pack.fact('m2')!.ref, 'memory#30');
    });

    test('natutunang salita (R6): "net" ↔ "wifi"', () {
      final memories = [mem(40, 'Wifi sa bahay: ZoeHome')];
      final without = ContextPack.build('ano net ko', now: now, memories: memories);
      expect(without.fact('m1'), isNull);
      final withLearned = ContextPack.build(
        'ano net ko',
        now: now,
        memories: memories,
        learned: const {
          'net': ['wifi'],
        },
      );
      expect(withLearned.fact('m1')!.ref, 'memory#40');
    });

    test('mahabang mensahe: hindi nawawala ang salita sa dulo (lampas 6)', () {
      const msg = 'grabe sobrang dami ng ginawa ko kanina sa opisina tapos traffic pa '
          'pauwi at may meeting';
      // Ang QueryTerms.parse ay hanggang 6 na salita lang…
      expect(QueryTerms.parse(msg).any((g) => g.word == 'meeting'), isFalse);
      // …pero ang pack ay tinitingnan ang lahat.
      final pack = ContextPack.build(msg, now: now, memories: [mem(4, 'Ayoko ng maagang meeting')]);
      expect(pack.fact('m1')!.ref, 'memory#4');
    });

    test('lakas ng memory', () {
      expect(ContextPack.memoryStrength(mem(1, 'x'), now), closeTo(3.0, 1e-9));
      expect(ContextPack.memoryStrength(mem(1, 'x', usedDaysAgo: 0), now), closeTo(4.0, 1e-9));
      final used = ContextPack.memoryStrength(mem(1, 'x', useCount: 5), now);
      expect(used, greaterThan(3.0));
      expect(ContextPack.memoryStrength(mem(1, 'x', importance: 5), now), closeTo(5.0, 1e-9));
    });
  });

  group('s1', () {
    test('note → snippet; nilalaktawan ang memory hit', () {
      final pack = ContextPack.build(
        'ano wifi password ko?',
        now: now,
        hits: [
          hit(RetrievalDoc(
            source: RetrievalSource.memory,
            id: 50,
            title: 'Wifi ko',
            text: 'Wifi ko',
            updatedAt: now,
          )),
          hit(note(3, 'Wifi', 'Wifi: ZoeHome / pass 1234')),
        ],
      );
      expect(pack.fact('s1')!.text, 'note · Wifi: ZoeHome / pass 1234');
      expect(pack.fact('s1')!.ref, 'note#3');
    });

    test('note na iba ang title → "title: snippet"; walang "\\n"', () {
      final pack = ContextPack.build(
        'saan ang susi ng kotse',
        now: now,
        hits: [hit(note(4, 'Bahay', 'Susi ng kotse: drawer\nGate: 1234'))],
      );
      final s1 = pack.fact('s1')!.text;
      expect(s1, startsWith('note · Bahay: '));
      expect(s1, contains('Susi ng kotse'));
      expect(s1.contains('\n'), isFalse);
    });

    test('"Baka ito?" → (unsure)', () {
      final pack = ContextPack.build(
        'may meeting ba',
        now: now,
        hits: [hit(reminder(9, 'Meeting kay boss', date: '2026-11-28', time: '15:00'), sure: false)],
      );
      expect(pack.fact('s1')!.sure, isFalse);
      expect(pack.fact('s1')!.line, '[s1] reminder · Meeting kay boss · today 15:00 (unsure)');
    });

    test('task na tapos → may "done" at petsa', () {
      final pack = ContextPack.build(
        'meralco',
        now: now,
        hits: [hit(task(5, 'Bayaran ang Meralco', date: '2026-12-03', done: true))],
      );
      expect(pack.fact('s1')!.text, 'task · Bayaran ang Meralco · 2026-12-03 · done');
      expect(pack.fact('s1')!.ref, 'task#5');
    });

    test('walang hit → walang s1', () {
      final pack = ContextPack.build('ano wifi password ko?', now: now);
      expect(pack.fact('s1'), isNull);
    });

    test('kailan (whenOf)', () {
      String w({String? date, String? time, String repeat = 'none'}) =>
          ContextPack.whenOf(reminder(1, 'x', date: date, time: time, repeat: repeat), now);
      expect(w(date: '2026-11-28', time: '09:00'), 'today 09:00');
      expect(w(date: '2026-11-29'), 'tomorrow');
      expect(w(date: '2026-11-27', time: '18:30'), 'yesterday 18:30');
      expect(w(date: '2026-12-03', time: '07:00'), '2026-12-03 07:00');
      expect(w(date: '2026-11-01', time: '07:00', repeat: 'daily'), 'daily 07:00');
      expect(w(date: '2026-11-28', time: '09:00', repeat: 'weekly'), 'weekly Sat 09:00');
      expect(w(date: '2026-11-15', repeat: 'monthly'), 'monthly 15');
      expect(w(time: '07:00'), '07:00');
      expect(w(), '');
    });
  });

  group('mga bantay', () {
    test('crisis → blocked, walang pack', () {
      final pack = ContextPack.build(
        'gusto ko nang mamatay',
        now: now,
        memories: [ac, mem(5, 'Allergic ako sa hipon')],
        hits: [hit(note(3, 'Wifi', 'Wifi: ZoeHome'))],
      );
      expect(pack.blocked, isTrue);
      expect(pack.isEmpty, isTrue);
      expect(pack.toPrompt(), '');
      expect(identical(pack, ContextPack.crisis), isTrue);
    });

    test('OFF ang long-term memory → walang u at m', () {
      final pack = ContextPack.build(
        'ang sarap ng hipon',
        now: now,
        memoryOn: false,
        memories: [ac, diretso, mem(5, 'Allergic ako sa hipon')],
      );
      expect(pack.ids, ['mood']);
    });
  });

  group('budget', () {
    final longNick = mem(1, 'Tawagin akong Maria Clarisse Anne',
        kind: FactKind.nickname, value: 'Maria Clarisse Annabelle');
    final malambing = mem(2, 'Lambingin mo ako', kind: FactKind.style, value: 'malambing');
    final lighten =
        mem(3, 'Kapag stressed ako, patawanin mo ako', kind: FactKind.stressHelp, value: 'lighten');
    const filler = 'Pumupunta ako sa gym kasama si Ana tuwing umaga bago pumasok sa trabaho, '
        'tapos minsan sa gabi rin kapag hindi ako pagod at wala akong ibang lakad.';
    final longMemories = [
      longNick,
      malambing,
      lighten,
      mem(60, filler),
      mem(61, 'Sa gym ko nakilala si Ben. $filler'),
    ];
    final longNote = note(
      70,
      'Gym plan',
      List.filled(6, 'Lunes: legs at cardio sa gym ng isang oras, tapos stretching.').join(' '),
    );
    const msg = 'grabe pagod ako sa gym';

    ContextPack build(int max) => ContextPack.build(
          msg,
          now: now,
          memories: longMemories,
          hits: [hit(longNote)],
          maxTokens: max,
        );

    test('walang limit (1000) → buo: u+stress, m1, m2, mood, s1', () {
      final full = build(1000);
      expect(full.ids, ['u', 'm1', 'm2', 'mood', 's1']);
      expect(full.fact('u')!.text, contains('stress: lighten'));
      expect(full.tokens, greaterThan(ContextPack.maxTokens));
    });

    test('≤ 120 tokens kahit mahaba ang notes at memories; mood laging kasama', () {
      final pack = build(ContextPack.maxTokens);
      expect(pack.tokens, lessThanOrEqualTo(ContextPack.maxTokens));
      expect(pack.fact('mood'), isNotNull);
      expect(pack.fact('m1'), isNotNull);
    });

    test('order ng pagtanggal: m2 bago stress', () {
      for (final max in [50, 60, 80, 100, 120]) {
        final pack = build(max);
        expect(pack.tokens, lessThanOrEqualTo(max), reason: 'max $max');
        expect(pack.fact('mood'), isNotNull, reason: 'max $max');
        final hasStress = pack.fact('u')!.text.contains('stress:');
        if (pack.fact('m2') != null) expect(hasStress, isTrue, reason: 'max $max');
      }
    });

    test('sobrang liit na limit → u + mood na lang (hindi inaalis ang mood)', () {
      final pack = build(10);
      expect(pack.ids, ['u', 'mood']);
    });

    test('estimateTokens = letra ÷ 3 (pataas)', () {
      expect(ContextPack.estimateTokens(''), 0);
      expect(ContextPack.estimateTokens('abc'), 1);
      expect(ContextPack.estimateTokens('abcd'), 2);
    });
  });

  group('MemoryItem (R7)', () {
    test('fromRow — use_count at last_used_at', () {
      final m = MemoryItem.fromRow({
        'id': 1,
        'content': 'Allergic ako sa hipon',
        'created_at': '2026-11-01T10:00:00.000',
        'updated_at': '2026-11-01T10:00:00.000',
        'use_count': 4,
        'last_used_at': '2026-11-27T08:00:00.000',
      });
      expect(m.useCount, 4);
      expect(m.lastUsedAt, DateTime(2026, 11, 27, 8));
    });

    test('fromRow — walang column → 0 / null', () {
      final m = MemoryItem.fromRow({
        'id': 1,
        'content': 'x',
        'created_at': '2026-11-01T10:00:00.000',
        'updated_at': '2026-11-01T10:00:00.000',
      });
      expect(m.useCount, 0);
      expect(m.lastUsedAt, isNull);
    });
  });
}