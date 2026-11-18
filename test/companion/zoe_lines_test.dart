import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/features/companion/controllers/zoe_lines.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';

/// Takbuhin:  flutter test test/companion/zoe_lines_test.dart
void main() {
  group('ZoeLines — kumpleto ang bawat situation', () {
    for (final s in ZoeSituation.values) {
      test('$s ay may linya sa English, Tagalog, at Both', () {
        expect(ZoeLines.hasAllLanguages(s), isTrue, reason: '$s');
      });
    }

    test('pick() ay hindi nagbabalik ng blank para sa kahit anong situation', () {
      for (final s in ZoeSituation.values) {
        for (final l in ZoeLanguage.values) {
          expect(ZoeLines.pick(l, s).trim(), isNotEmpty, reason: '$s / $l');
        }
      }
    });
  });

  group('ZoeLines.stable()', () {
    test('pare-pareho ang sagot kahit tawagin nang maraming beses', () {
      final first = ZoeLines.stable(ZoeLanguage.english, ZoeSituation.greeting);
      for (var i = 0; i < 20; i++) {
        expect(ZoeLines.stable(ZoeLanguage.english, ZoeSituation.greeting), first);
      }
    });

    test('pinapalitan ang {vars}', () {
      final line = ZoeLines.stable(
        ZoeLanguage.english,
        ZoeSituation.homeKeepGoing,
        {'done': '2'},
      );
      expect(line, '2 done already — keep going 💪');
      expect(line, isNot(contains('{done}')));
    });
  });

  group('Home greeting ayon sa oras', () {
    test('homeGreetingFor — morning / afternoon / evening boundaries', () {
      expect(ZoeLines.homeGreetingFor(0), ZoeSituation.homeMorning);
      expect(ZoeLines.homeGreetingFor(11), ZoeSituation.homeMorning);
      expect(ZoeLines.homeGreetingFor(12), ZoeSituation.homeAfternoon);
      expect(ZoeLines.homeGreetingFor(17), ZoeSituation.homeAfternoon);
      expect(ZoeLines.homeGreetingFor(18), ZoeSituation.homeEvening);
      expect(ZoeLines.homeGreetingFor(23), ZoeSituation.homeEvening);
    });

    test('English', () {
      expect(ZoeLines.stable(ZoeLanguage.english, ZoeSituation.homeMorning),
          'Good morning ☀️');
      expect(ZoeLines.stable(ZoeLanguage.english, ZoeSituation.homeAfternoon),
          'Good afternoon 🌤️');
      expect(ZoeLines.stable(ZoeLanguage.english, ZoeSituation.homeEvening),
          'Good evening 🌙');
    });

    test('Tagalog', () {
      expect(ZoeLines.stable(ZoeLanguage.tagalog, ZoeSituation.homeMorning),
          'Magandang umaga ☀️');
      expect(ZoeLines.stable(ZoeLanguage.tagalog, ZoeSituation.homeAfternoon),
          'Magandang hapon 🌤️');
      expect(ZoeLines.stable(ZoeLanguage.tagalog, ZoeSituation.homeEvening),
          'Magandang gabi 🌙');
    });

    test('Both (Taglish) — English ang bati', () {
      expect(ZoeLines.stable(ZoeLanguage.both, ZoeSituation.homeMorning),
          'Good morning ☀️');
    });
  });

  group('Home banner ayon sa progress', () {
    test('homeBannerFor', () {
      expect(ZoeLines.homeBannerFor(total: 0, done: 0), ZoeSituation.homeFreeDay);
      expect(ZoeLines.homeBannerFor(total: 3, done: 0), ZoeSituation.homeStartFirst);
      expect(ZoeLines.homeBannerFor(total: 3, done: 1), ZoeSituation.homeKeepGoing);
      expect(ZoeLines.homeBannerFor(total: 3, done: 3), ZoeSituation.homeAllDone);
      // done > total (hindi dapat mangyari, pero safe pa rin)
      expect(ZoeLines.homeBannerFor(total: 2, done: 5), ZoeSituation.homeAllDone);
    });

    test('homeHasItems — singular at plural sa English', () {
      expect(
        ZoeLines.stable(ZoeLanguage.english, ZoeSituation.homeHasItems,
            {'count': '1', 's': ''}),
        'You have 1 thing today!',
      );
      expect(
        ZoeLines.stable(ZoeLanguage.english, ZoeSituation.homeHasItems,
            {'count': '3', 's': 's'}),
        'You have 3 things today!',
      );
    });

    test('homeHasItems — Tagalog ay walang {s} na natitira', () {
      final line = ZoeLines.stable(ZoeLanguage.tagalog, ZoeSituation.homeHasItems,
          {'count': '3', 's': 's'});
      expect(line, 'May 3 kang gagawin ngayong araw!');
      expect(line, isNot(contains('{')));
    });
  });

  group('ZoeLines.pick()', () {
    test('iniiwasan ang paulit-ulit kapag may 2+ na options', () {
      // greeting ay may 2 linya kada language; 10 tawag → dapat parehong lumabas
      final seen = <String>{};
      for (var i = 0; i < 10; i++) {
        seen.add(ZoeLines.pick(ZoeLanguage.tagalog, ZoeSituation.greeting));
      }
      expect(seen.length, 2);
    });

    test('crisis ay isang linya lang kada language (sadyang hindi paiba-iba)', () {
      final vars = {
        'landline': 'L',
        'globe': 'G',
        'smart': 'S',
        'emergency': 'E',
      };
      final a = ZoeLines.pick(ZoeLanguage.english, ZoeSituation.crisis, vars);
      final b = ZoeLines.pick(ZoeLanguage.english, ZoeSituation.crisis, vars);
      expect(a, b);
      expect(a, isNot(contains('{')));
    });
  });

  group('Mood lines (2c)', () {
    test('bawat mood variant ay may English, Tagalog, at Both', () {
      expect(ZoeLines.moodVariants, isNotEmpty);
      for (final (s, m) in ZoeLines.moodVariants) {
        expect(ZoeLines.moodVariantHasAllLanguages(s, m), isTrue, reason: '$s / $m');
      }
    });

    test('walang mood variant para sa focused (status lang, hindi boses)', () {
      for (final (_, m) in ZoeLines.moodVariants) {
        expect(m, isNot(MoodState.focused));
      }
    });

    test('pickFor: gentle greeting ay iba sa karaniwan', () {
      final gentle =
          ZoeLines.optionsFor(ZoeLanguage.tagalog, ZoeSituation.greeting, MoodState.gentle);
      final normal = ZoeLines.optionsFor(ZoeLanguage.tagalog, ZoeSituation.greeting);
      expect(gentle.toSet().intersection(normal.toSet()), isEmpty);
      expect(gentle, contains(ZoeLines.pickFor(
          ZoeLanguage.tagalog, ZoeSituation.greeting, MoodState.gentle)));
    });

    test('pickFor: walang variant → karaniwang linya (hindi blangko)', () {
      for (final m in MoodState.values) {
        for (final l in ZoeLanguage.values) {
          expect(ZoeLines.pickFor(l, ZoeSituation.askTime, m).trim(), isNotEmpty);
        }
      }
      expect(
        ZoeLines.stableFor(ZoeLanguage.english, ZoeSituation.askTime, MoodState.proud),
        'What time?',
      );
    });

    test('gentle missedList ay walang paninisi at napapalitan ang {items}', () {
      final line = ZoeLines.stableFor(
          ZoeLanguage.tagalog, ZoeSituation.missedList, MoodState.gentle, {'items': 'Gym'});
      expect(line, 'Na-miss mo: Gym. Okay lang — isa-isahin natin.');
    });
  });

  group('Ibang araw (dating _scheduleOn)', () {
    test('dayFree / dayList', () {
      expect(
        ZoeLines.stable(ZoeLanguage.english, ZoeSituation.dayFree, {'day': 'Sat, Nov 21'}),
        'Nothing scheduled on Sat, Nov 21.',
      );
      expect(
        ZoeLines.stable(ZoeLanguage.tagalog, ZoeSituation.dayList,
            {'day': 'Sat, Nov 21', 'items': 'Gym, Laba'}),
        'Sa Sat, Nov 21, meron kang: Gym, Laba.',
      );
    });
  });

  group('Home banner ayon sa mood', () {
    test('gentle + may na-miss → "Okay lang, isa-isa lang tayo"', () {
      final s = ZoeLines.homeBannerFor(
          total: 3, done: 1, missed: 1, mood: MoodState.gentle);
      expect(s, ZoeSituation.homeGentleMissed);
      expect(ZoeLines.stable(ZoeLanguage.tagalog, s), 'Okay lang, isa-isa lang tayo 🌱');
    });

    test('gentle pero walang na-miss (pagod ang user) → homeGentle', () {
      expect(
        ZoeLines.homeBannerFor(total: 3, done: 0, mood: MoodState.gentle),
        ZoeSituation.homeGentle,
      );
    });

    test('proud + tapos lahat → homeProud; content + tapos lahat → homeAllDone', () {
      expect(ZoeLines.homeBannerFor(total: 2, done: 2, mood: MoodState.proud),
          ZoeSituation.homeProud);
      expect(ZoeLines.homeBannerFor(total: 2, done: 2), ZoeSituation.homeAllDone);
    });

    test('gabi (sleepy) → tahimik, kahit may natitira o wala', () {
      expect(ZoeLines.homeBannerFor(total: 3, done: 1, mood: MoodState.sleepy),
          ZoeSituation.homeNight);
      expect(ZoeLines.homeBannerFor(total: 0, done: 0, mood: MoodState.sleepy),
          ZoeSituation.homeNight);
    });

    test('happy / content → dating progress lines', () {
      expect(ZoeLines.homeBannerFor(total: 3, done: 0, mood: MoodState.happy),
          ZoeSituation.homeStartFirst);
      expect(ZoeLines.homeBannerFor(total: 3, done: 1, mood: MoodState.happy),
          ZoeSituation.homeKeepGoing);
      // Tapos lahat pero gentle (pagod ang user) → hindi proud, pero tapos pa rin.
      expect(ZoeLines.homeBannerFor(total: 2, done: 2, mood: MoodState.gentle),
          ZoeSituation.homeAllDone);
    });
  });
}