import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/memory/companion_facts.dart';

/// Takbuhin:  flutter test test/memory/companion_facts_test.dart
///
/// Level 3: anong klaseng memory (nickname, style, stress help,
/// win, routine, general) — pure, walang database.
/// Mas marami pang halimbawa: test/memory/companion_phrase_bank_test.dart
void main() {
  group('nickname', () {
    final cases = {
      'call me AC': 'AC',
      'call me ac': 'AC',
      'Zoe, call me AC from now on': 'AC',
      'tawagin mo akong Pao': 'Pao',
      'tawagin mo akong pao': 'Pao',
      'tandaan mo, tawagin mo akong JM po': 'JM',
      'AC na lang itawag mo sa akin': 'AC',
      'call me AC na lang': 'AC',
      'my name is Aaron': 'Aaron',
      'ang pangalan ko ay Aaron Paul': 'Aaron Paul',
      'my name is Aaron but call me AC': 'AC',
    };
    cases.forEach((text, name) {
      test('"$text" → $name', () {
        expect(CompanionFacts.nicknameFrom(text), name);
        expect(CompanionFacts.read(text), FactRead(FactKind.nickname, name));
      });
    });

    for (final text in [
      'call me later',
      'call me at 7',
      'call me tomorrow',
      'gusto ko ng morning reminders',
    ]) {
      test('"$text" → walang nickname', () {
        expect(CompanionFacts.nicknameFrom(text), isNull);
      });
    }
  });

  group('style', () {
    for (final text in [
      'diretsuhin mo lang ako',
      'diretso ka lang sa akin',
      'be direct with me',
      'straight to the point lang',
      'short answers please',
      'wag mo akong i-baby',
      'no sugarcoating',
    ]) {
      test('"$text" → diretso', () {
        expect(CompanionFacts.read(text), const FactRead(FactKind.style, 'diretso'));
      });
    }
    for (final text in [
      'maging malambing ka sa akin',
      'be gentle with me',
      'gentle ka lang ha',
      'dahan-dahan ka lang sa akin',
    ]) {
      test('"$text" → malambing', () {
        expect(CompanionFacts.read(text), const FactRead(FactKind.style, 'malambing'));
      });
    }
    test('parehong nabanggit → hindi sigurado', () {
      expect(CompanionFacts.styleFrom('be direct pero malambing'), isNull);
    });
  });

  group('stress help', () {
    final cases = {
      'kapag stressed ako, makinig ka muna': 'listen',
      "when i'm stressed just listen": 'listen',
      'pag pagod ako, bigyan mo ako ng payo': 'advice',
      'when I am overwhelmed give me tips': 'advice',
      'kapag malungkot ako, patawanin mo ako': 'lighten',
      "when i'm down cheer me up": 'lighten',
    };
    cases.forEach((text, value) {
      test('"$text" → $value', () {
        expect(CompanionFacts.read(text), FactRead(FactKind.stressHelp, value));
      });
    });

    test('walang "kapag stressed" → hindi stress help', () {
      expect(CompanionFacts.stressHelpFrom('makinig ka muna'), isNull);
    });
    test('dalawang pinili → hindi sigurado', () {
      expect(CompanionFacts.stressHelpFrom('kapag stressed ako, makinig ka tapos payo'), isNull);
    });
  });

  group('win / routine / general', () {
    for (final text in [
      'nakapasa ako sa board exam',
      'natapos ko na ang thesis ko',
      'I got the job!',
      'na-promote ako',
    ]) {
      test('"$text" → win', () {
        expect(CompanionFacts.read(text).kind, FactKind.win);
      });
    }
    for (final text in [
      'nag-gy-gym ako tuwing MWF',
      'gumigising ako ng 6',
      'I usually sleep late',
      'every morning I jog',
    ]) {
      test('"$text" → routine', () {
        expect(CompanionFacts.read(text).kind, FactKind.routine);
      });
    }
    for (final text in [
      'mas gusto ko ng morning reminders',
      "I'm vegetarian",
      'paborito ko ang sinigang',
    ]) {
      test('"$text" → general', () {
        expect(CompanionFacts.read(text), const FactRead(FactKind.general));
      });
    }
  });

  group('cardText → read (pareho ang kahulugan)', () {
    for (final tagalog in [true, false]) {
      for (final r in const [
        FactRead(FactKind.nickname, 'AC'),
        FactRead(FactKind.nickname, 'Aaron Paul'),
        FactRead(FactKind.style, 'diretso'),
        FactRead(FactKind.style, 'malambing'),
        FactRead(FactKind.stressHelp, 'listen'),
        FactRead(FactKind.stressHelp, 'advice'),
        FactRead(FactKind.stressHelp, 'lighten'),
      ]) {
        test('$r (tagalog: $tagalog)', () {
          final text = CompanionFacts.cardText(r, tagalog: tagalog)!;
          expect(CompanionFacts.read(text), r, reason: text);
        });
      }
    }
    test('win / routine / general → null (ang sinabi ng user ang gagamitin)', () {
      expect(CompanionFacts.cardText(const FactRead(FactKind.win), tagalog: true), isNull);
      expect(CompanionFacts.cardText(const FactRead(FactKind.routine), tagalog: true), isNull);
      expect(CompanionFacts.cardText(const FactRead(FactKind.general), tagalog: true), isNull);
    });
  });

  group('helpChoice (sagot sa tanong ni Zoe)', () {
    final cases = {
      'makinig ka lang': StressHelp.listen,
      'just listen': StressHelp.listen,
      'payo': StressHelp.advice,
      'advice please': StressHelp.advice,
      'pampagaan': StressHelp.lighten,
      'cheer me up': StressHelp.lighten,
    };
    cases.forEach((text, help) {
      test('"$text" → ${help.value}', () => expect(CompanionFacts.helpChoice(text), help));
    });
    test('wala / dalawa → null', () {
      expect(CompanionFacts.helpChoice('ewan ko'), isNull);
      expect(CompanionFacts.helpChoice('makinig tapos payo'), isNull);
    });
  });

  group('isStatement (ChatRouter)', () {
    for (final text in [
      'call me ac',
      'diretsuhin mo lang ako',
      'kapag stressed ako, makinig ka muna',
    ]) {
      test('"$text" → oo (kahit walang tandaan)', () {
        expect(CompanionFacts.isStatement(text, hasTrigger: false), isTrue);
      });
    }
    test('win / routine → kailangan ng "tandaan mo"', () {
      expect(CompanionFacts.isStatement('nakapasa ako sa board exam', hasTrigger: false), isFalse);
      expect(CompanionFacts.isStatement('tandaan mo, nakapasa ako sa board exam', hasTrigger: true),
          isTrue);
      expect(CompanionFacts.isStatement('tandaan mo, nag-gy-gym ako tuwing mwf', hasTrigger: true),
          isTrue);
    });
    for (final text in [
      'call me later',
      'kapag stressed ako, i-remind mo akong magpahinga',
      'be direct, remind me bukas ng 8am',
      'tandaan mo, gym ako bukas',
    ]) {
      test('"$text" → hindi', () {
        expect(CompanionFacts.isStatement(text, hasTrigger: true), isFalse);
      });
    }
  });

  group('FactKind', () {
    test('db round-trip', () {
      for (final k in FactKind.values) {
        expect(FactKind.fromDb(k.db), k);
      }
      expect(FactKind.fromDb(null), FactKind.general);
      expect(FactKind.fromDb('ewan'), FactKind.general);
    });
    test('isa lang: nickname, style, stress_help', () {
      expect(FactKind.values.where((k) => k.single).toSet(),
          {FactKind.nickname, FactKind.style, FactKind.stressHelp});
    });
  });
}