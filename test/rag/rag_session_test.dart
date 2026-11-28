import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/rag_session.dart';

/// Takbuhin:  flutter test test/rag/rag_session_test.dart
///
/// R5 — follow-up pagkatapos ng sagot ni Zoe (pure, walang database):
///   "yung isa pa" → more · "buksan mo" → open · "hindi yan" → reject
///   "eh kay papa?" → swap (+ pagsasama ng tanong: RagFollowUp.swapQueries)
void main() {
  group('RagFollowUp.read — more ("yung isa pa")', () {
    for (final t in [
      'yung isa pa',
      'isa pa',
      'iba pa?',
      'may iba pa ba?',
      'meron pa ba',
      'next',
      'another one',
      'the other one',
      'ano pa',
      'may iba ka pang nakita?',
      'pakita mo pa',
      'uy isa pa nga po',
      'iba naman',
      'what else?',
      'anything else?',
      'show more',
    ]) {
      test('"$t" → more', () => expect(RagFollowUp.read(t)?.kind, FollowUpKind.more));
    }
  });

  group('RagFollowUp.read — open ("buksan mo")', () {
    for (final t in [
      'buksan mo',
      'pakibuksan',
      'paki open',
      'open it',
      'open',
      'buksan mo yung note',
      'patingin ng buong note',
      'patingin',
      'ipakita mo ang buong note',
      'full note',
      'buong note',
      'show me the full note',
      'i-open mo',
      'tingnan ko',
    ]) {
      test('"$t" → open', () => expect(RagFollowUp.read(t)?.kind, FollowUpKind.open));
    }
  });

  group('RagFollowUp.read — reject ("hindi yan")', () {
    for (final t in [
      'hindi yan',
      'mali',
      'hindi yan ang hinahanap ko',
      'not that one',
      "that's not it",
      'wrong',
      'no',
      'hindi',
      'mali yan',
      'hindi ito',
      'di yan',
      'nope, not that',
      'hindi yan eh',
      'not what I meant',
      'hnd yan', // text-speak → "hindi yan"
    ]) {
      test('"$t" → reject', () => expect(RagFollowUp.read(t)?.kind, FollowUpKind.reject));
    }
  });

  group('RagFollowUp.read — swap ("eh kay papa?")', () {
    for (final t in [
      'eh kay papa?',
      'yung kay papa naman',
      'papa naman?',
      'what about dad?',
      'how about the bike?',
      'eh sa bahay?',
      'eh yung vitamins?',
      'yung sa motor?',
      'eh yung task?',
      'kay kuya naman',
      'at kay ate?',
      'e para kay lola?',
      'eh ano yung kay papa?', // may "ano" pero walang bagong bagay → follow-up pa rin
      'sa office naman',
    ]) {
      test('"$t" → swap', () => expect(RagFollowUp.read(t)?.kind, FollowUpKind.swap));
    }
  });

  group('RagFollowUp.read — HINDI follow-up', () {
    for (final t in [
      'bukas', // "tomorrow", hindi "buksan"
      'ano gagawin ko bukas?',
      'eh saan ko nilagay yung passport?', // bagong buong tanong
      'hindi ko alam',
      'di ko gets',
      'no thanks',
      'salamat',
      'oo', // sa brain ito (ContextReplies.isYes), hindi rito
      'hi zoe',
      'ano wifi password ko?',
      'remind me bukas 8am',
      'pagod na ako',
      'isa',
      'kumain ka na?',
      'buksan mo ang ilaw',
      'show my tasks today',
      'hindi na ako pupunta bukas sa party ni papa',
      '',
    ]) {
      test('"$t" → null', () => expect(RagFollowUp.read(t), isNull));
    }
  });

  group('RagFollowUp.swapQueries — pagsasama ng tanong', () {
    void expectFirst(String previous, String followUp, String first, {List<String>? all}) {
      final q = RagFollowUp.swapQueries(previous, followUp);
      expect(q, isNotEmpty, reason: '$previous + $followUp');
      expect(q.first, first, reason: '$previous + $followUp → $q');
      if (all != null) expect(q, all);
      expect(q.toSet().length, q.length, reason: 'walang ulit');
    }

    test('may-ari ↔ may-ari: "gamot ni mama" + "eh kay papa?" → "gamot papa"', () {
      expectFirst('ano gamot ni mama?', 'eh kay papa?', 'gamot papa',
          all: ['gamot papa', 'gamot mama papa']);
    });

    test('"ng" = may-ari: "susi ng kotse" + "eh yung sa motor?" → "susi motor"', () {
      expectFirst('saan ko nilagay yung susi ng kotse?', 'eh yung sa motor?', 'susi motor');
    });

    test('bagay ↔ huling bagay, at may iba pang posibilidad ("bayad tubig")', () {
      expectFirst('bayad ng kuryente', 'eh tubig?', 'kuryente tubig',
          all: ['kuryente tubig', 'bayad tubig', 'bayad kuryente tubig']);
    });

    test('walang kapareho → idinadagdag: "wifi password" + "eh sa bahay?"', () {
      expectFirst('ano wifi password ko?', 'eh sa bahay?', 'wifi password bahay');
    });

    test('pinalitan ang lugar: "... sa office" + "eh sa bahay?" → "wifi password bahay"', () {
      expectFirst('ano wifi password ko sa office?', 'eh sa bahay?', 'wifi password bahay');
    });

    test('uri ↔ uri: "may reminder … tungkol sa dentist?" + "eh yung task?" → "dentist task"', () {
      expectFirst('may reminder ba ako tungkol sa dentist?', 'eh yung task?', 'dentist task');
    });

    test('English: "mom\'s medicine" + "what about dad?" → "medicine dad"', () {
      expectFirst("what's mom's medicine?", 'what about dad?', 'medicine dad');
    });

    test('dalawang bago: "gamot mama" + "eh yung vitamins ni papa?" → "vitamins papa"', () {
      expectFirst('gamot mama', 'eh yung vitamins ni papa?', 'vitamins papa');
    });

    test('walang bagong salita → walang posibilidad', () {
      expect(RagFollowUp.swapQueries('ano gamot ni mama?', 'eh naman?'), isEmpty);
    });
  });

  group('RagSession', () {
    final t0 = DateTime(2026, 11, 28, 15, 0);

    RetrievalHit hit(int id) => RetrievalHit(
          doc: RetrievalDoc(
            source: RetrievalSource.note,
            id: id,
            title: 'Note $id',
            text: 'laman $id',
            updatedAt: t0,
          ),
          score: 10.0 - id,
          matched: 1,
          matchedInTitle: 0,
        );

    test('isFresh: hanggang 15 minuto lang', () {
      final s = RagSession(query: 'wifi', hits: [hit(1)], at: t0);
      expect(s.isFresh(t0.add(const Duration(minutes: 14))), isTrue);
      expect(s.isFresh(t0.add(const Duration(minutes: 16))), isFalse);
    });

    test('nextIndex / positionOf: isa-isa, laktaw ang tinanggihan', () {
      final s = RagSession(query: 'wifi', hits: [hit(1), hit(2), hit(3)], at: t0);
      expect(s.current!.doc.id, 1);
      expect(s.nextIndex(), 1);
      expect(s.positionOf(1), (2, 3));

      // "hindi yan" sa #1 at #2 → #3 na lang ang natitira.
      s.rejected.add(RagSession.keyOf(s.hits[0].doc));
      s.shown = 1;
      s.rejected.add(RagSession.keyOf(s.hits[1].doc));
      expect(s.nextIndex(), 2);
      expect(s.positionOf(2), (1, 1));
      s.shown = 2;
      expect(s.nextIndex(), isNull);
    });

    test('remainingFrom: ang ipinapakita muna, walang tinanggihan', () {
      final s = RagSession(query: 'wifi', hits: [hit(1), hit(2), hit(3)], at: t0);
      s.rejected.add(RagSession.keyOf(s.hits[0].doc));
      expect(s.remainingFrom(2).map((h) => h.doc.id), [3, 2]);
    });

    test('walang nahanap → walang current', () {
      final s = RagSession(query: 'plate number', hits: const [], at: t0);
      expect(s.hasHits, isFalse);
      expect(s.current, isNull);
      expect(s.nextIndex(), isNull);
    });
  });
}