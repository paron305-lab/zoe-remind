import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/memory/memory_rules.dart';

/// Takbuhin:  flutter test test/memory/memory_rules_test.dart
///
/// B5: kailan memory (tungkol sa iyo) at kailan note (data), paano kinukuha
/// ang laman, at kailan "pareho" ang dalawang memory (walang doble).
void main() {
  group('isRememberAboutMe — MEMORY', () {
    for (final q in [
      'tandaan mo na mas gusto ko ng morning reminders',
      'zoe, tandaan mo: ayoko ng maingay na alarm',
      'remember that i prefer morning reminders',
      "keep in mind that i'm vegetarian",
      'tandaan mo, tawagin mo akong pao',
      'tandaan mo na ang birthday ko ay feb 12',
      'tandaan mo, gusto kong mag-gym tuwing lunes',
      'please remember my name is aaron',
      "don't forget that i'm allergic to shrimp",
    ]) {
      test('"$q"', () => expect(MemoryRules.isRememberAboutMe(q), isTrue));
    }
  });

  group('isRememberAboutMe — HINDI memory (note / reminder / walang "tandaan")', () {
    for (final q in [
      'tandaan mo, ang wifi password sa bahay ay zoe2026', // data → note
      'tandaan mo na ang locker code ko ay 4521', // data → note
      'paki tandaan mo: plate number ko ay abc 123', // data → note
      'tandaan mo, gisingin mo ako 6am', // may oras → reminder
      'tandaan mo na gusto ko mag-gym bukas', // bukas → hindi memory
      'mas gusto ko ng morning reminders', // walang "tandaan mo"
      'remind me to buy coffee, i like coffee',
    ]) {
      test('"$q"', () => expect(MemoryRules.isRememberAboutMe(q), isFalse));
    }
  });

  group('extract', () {
    final cases = {
      'Zoe, tandaan mo na mas gusto ko ng morning reminders.': 'Mas gusto ko ng morning reminders',
      'remember that I prefer morning reminders': 'I prefer morning reminders',
      'tandaan mo to: ayoko ng maingay na alarm, ha': 'Ayoko ng maingay na alarm',
      'Mas gusto ko ng kape sa umaga, tandaan mo yan': 'Mas gusto ko ng kape sa umaga',
      "keep in mind that I'm vegetarian, zoe!": "I'm vegetarian",
      'paki-tandaan mo, tawagin mo akong Pao': 'Tawagin mo akong Pao',
    };
    cases.forEach((input, expected) {
      test('"$input" → "$expected"', () => expect(MemoryRules.extract(input), expected));
    });

    test('hanggang ${MemoryRules.maxLength} letra', () {
      final long = 'tandaan mo na gusto ko ${'x' * 400}';
      expect(MemoryRules.extract(long).length, MemoryRules.maxLength);
    });
  });

  group('sameMemory — walang doble', () {
    test('parehong salita (may "mas" lang) → pareho', () {
      expect(MemoryRules.sameMemory('Mas gusto ko ng morning reminders', 'Gusto ko ng morning reminders'),
          isTrue);
    });
    test('gusto → ayoko sa parehong bagay → pareho (napalitan)', () {
      expect(MemoryRules.sameMemory('Gusto ko ng morning reminders', 'Ayoko ng morning reminders'),
          isTrue);
      expect(MemoryRules.sameMemory('I prefer morning reminders', 'I like morning reminders'), isTrue);
    });
    test('halos pareho (≥ 80%) → pareho', () {
      expect(
          MemoryRules.sameMemory('Nakatira ako sa Quezon City malapit sa SM',
              'Nakatira ako sa Quezon City malapit sa SM North'),
          isTrue);
    });
    test('magkaiba → hindi', () {
      expect(MemoryRules.sameMemory('Mas gusto ko ng morning reminders', 'Ayoko ng maingay na alarm'),
          isFalse);
      expect(MemoryRules.sameMemory('Vegetarian ako', 'Allergic ako sa hipon'), isFalse);
      expect(MemoryRules.sameMemory('Gusto ko ng kape', 'Gusto ko ng tsaa'), isFalse);
    });
  });

  // Phrase bank (Nov 22): mas maraming paraan ng "tandaan mo".
  group('isRememberAboutMe — bagong paraan ng pagsasabi', () {
    for (final q in [
      'you have to remember i love sinigang',
      'remember i hate waking up early',
      'remember: i prefer short replies',
      'never forget that i am a nurse',
      "note that i'm allergic to shrimp",
      'fyi i love my dog choco',
      'lagi mong tandaan na ayoko ng maanghang',
      'wag mong kakalimutan na vegetarian ako',
      'call me ac',
      'tawagin mo akong ate joy',
      'ac na lang itawag mo sa akin',
      'my name is aaron',
    ]) {
      test('"$q"', () => expect(MemoryRules.isRememberAboutMe(q), isTrue));
    }
    for (final q in ['call me later', 'call me at 7', 'call me tomorrow', 'remember to buy milk at 7pm']) {
      test('hindi: "$q"', () => expect(MemoryRules.isRememberAboutMe(q), isFalse));
    }
  });

  test('mentionsReminder — "remind" na utos, hindi ang salitang "reminders"', () {
    expect(MemoryRules.mentionsReminder('you have to remember everyday i love to remind about my happiness'),
        isTrue);
    expect(MemoryRules.mentionsReminder('tandaan mo na mas gusto ko ng morning reminders'), isFalse);
  });

  group('isRememberAboutMe — auto-learn (kahit walang "tandaan mo")', () {
    for (final q in [
      'paborito ko ang sinigang',
      'favorite ko ang adobo',
      'my favorite color is purple',
      'allergic ako sa hipon',
      "i'm allergic to shrimp",
      'vegetarian ako',
      "i'm vegan",
      'birthday ko ay march 3',
      'my birthday is june 5',
      'hindi ako kumakain ng baboy',
      "i don't eat pork",
    ]) {
      test('"$q"', () => expect(MemoryRules.isRememberAboutMe(q), isTrue));
    }
    for (final q in [
      'paboritong cake ni mama ay ube', // hindi tungkol sa user → note
      'ano bday ko?', // tanong
      'what is my favorite color', // tanong
      'birthday ko na!', // ngayon lang, hindi katotohanan
      'birthday ko bukas', // malapit na oras
      'hindi ako kumakain ng maayos', // nararamdaman, hindi kagustuhan
      "i don't eat enough",
    ]) {
      test('hindi: "$q"', () => expect(MemoryRules.isRememberAboutMe(q), isFalse));
    }
    test('extract — buong sinabi', () {
      expect(MemoryRules.extract('allergic ako sa hipon, zoe'), 'Allergic ako sa hipon');
    });
    test('extract — ang katotohanan lang, hindi ang buong mensahe', () {
      expect(MemoryRules.extract('wait allergic ako sa hipon diba sinabi ko sayo'),
          'Allergic ako sa hipon');
      expect(MemoryRules.extract('uy vegetarian ako kasi bawal sa akin'), 'Vegetarian ako');
    });
    test('sameWords — pareho = alam na; gusto ↔ ayaw = hindi pareho', () {
      expect(MemoryRules.sameWords('Allergic ako sa hipon', 'allergic ako sa hipon'), isTrue);
      expect(MemoryRules.sameWords('Gusto ko ng kape', 'Ayoko ng kape'), isFalse);
    });
  });

  test('extract — tinatanggal ang bagong trigger', () {
    expect(MemoryRules.extract('you have to remember I love sinigang'), 'I love sinigang');
    expect(MemoryRules.extract('fyi I love my dog Choco'), 'I love my dog Choco');
    expect(MemoryRules.extract('lagi mong tandaan na ayoko ng maanghang'), 'Ayoko ng maanghang');
  });
}