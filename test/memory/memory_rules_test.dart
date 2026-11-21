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
}