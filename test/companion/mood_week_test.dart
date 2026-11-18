import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/features/companion/controllers/zoe_lines.dart';
import 'package:zoe_remind/features/companion/models/mood_week.dart';
import 'package:zoe_remind/features/companion/models/user_tone.dart';

/// Takbuhin:  flutter test test/companion/mood_week_test.dart
///
/// Level 2 — Mood log: buod ng huling 7 araw (pure, walang database).
void main() {
  // Miyerkules, Nov 18 2026, 2 PM
  final now = DateTime(2026, 11, 18, 14);

  MoodLogEntry e(String day, UserTone tone, [int count = 1]) => MoodLogEntry(day, tone, count);

  group('MoodWeek.cutoffKey', () {
    test('today + 6 araw bago nito', () {
      expect(MoodWeek.cutoffKey(now), '2026-11-12');
    });

    test('tumatawid ng buwan / taon', () {
      expect(MoodWeek.cutoffKey(DateTime(2026, 12, 3)), '2026-11-27');
      expect(MoodWeek.cutoffKey(DateTime(2027, 1, 2)), '2026-12-27');
    });
  });

  group('MoodWeek.from — binibilang lang ang huling 7 araw', () {
    test('walang laman → empty, walang vibe', () {
      final w = MoodWeek.from(const [], now);
      expect(w.isEmpty, isTrue);
      expect(w.vibe, isNull);
    });

    test('luma (mas maaga sa cutoff) at "bukas" ay hindi kasama', () {
      final w = MoodWeek.from([
        e('2026-11-11', UserTone.tired, 5), // 7 araw na — labas
        e('2026-11-12', UserTone.tired), // cutoff — kasama
        e('2026-11-18', UserTone.stressed, 2), // ngayon — kasama
        e('2026-11-19', UserTone.sad), // bukas — labas
      ], now);
      expect(w.count(UserTone.tired), 1);
      expect(w.count(UserTone.stressed), 2);
      expect(w.count(UserTone.sad), 0);
      expect(w.total, 3);
      expect(w.downDays, 2);
    });

    test('magkakaibang araw ang binibilang, hindi ang dami ng mensahe', () {
      final w = MoodWeek.from([e('2026-11-18', UserTone.tired, 10)], now);
      expect(w.downDays, 1);
      expect(w.vibe, isNull, reason: 'isang masamang araw ≠ masamang linggo');
    });
  });

  group('MoodWeek.vibe', () {
    test('3 araw pagod / stressed → busy', () {
      final w = MoodWeek.from([
        e('2026-11-15', UserTone.tired),
        e('2026-11-16', UserTone.stressed),
        e('2026-11-18', UserTone.tired),
      ], now);
      expect(w.vibe, WeekVibe.busy);
    });

    test('2 araw lang → wala pa', () {
      final w = MoodWeek.from([
        e('2026-11-16', UserTone.tired),
        e('2026-11-18', UserTone.tired),
      ], now);
      expect(w.vibe, isNull);
    });

    test('mas marami ang malungkot / inis / kabado → heavy', () {
      final w = MoodWeek.from([
        e('2026-11-14', UserTone.sad),
        e('2026-11-15', UserTone.worried),
        e('2026-11-17', UserTone.upset),
        e('2026-11-18', UserTone.tired),
      ], now);
      expect(w.vibe, WeekVibe.heavy);
    });

    test('pantay ang busy at heavy → busy (mas magaan na salita)', () {
      final w = MoodWeek.from([
        e('2026-11-14', UserTone.sad),
        e('2026-11-15', UserTone.tired),
        e('2026-11-17', UserTone.sad),
        e('2026-11-18', UserTone.stressed),
      ], now);
      expect(w.vibe, WeekVibe.busy);
    });

    test('3 araw masaya → good', () {
      final w = MoodWeek.from([
        e('2026-11-13', UserTone.happy),
        e('2026-11-15', UserTone.happy),
        e('2026-11-18', UserTone.happy),
      ], now);
      expect(w.vibe, WeekVibe.good);
    });

    test('3 araw down ang nananaig kahit may masaya rin', () {
      final w = MoodWeek.from([
        e('2026-11-13', UserTone.happy),
        e('2026-11-14', UserTone.happy),
        e('2026-11-15', UserTone.happy),
        e('2026-11-16', UserTone.tired),
        e('2026-11-17', UserTone.tired),
        e('2026-11-18', UserTone.stressed),
      ], now);
      expect(w.vibe, WeekVibe.busy);
    });
  });

  group('MoodWeek.noteFor — tugma sa tone ng mensahe ngayon', () {
    final busy = MoodWeek.from([
      e('2026-11-15', UserTone.tired),
      e('2026-11-16', UserTone.tired),
      e('2026-11-18', UserTone.tired),
    ], now);
    final good = MoodWeek.from([
      e('2026-11-15', UserTone.happy),
      e('2026-11-16', UserTone.happy),
      e('2026-11-18', UserTone.happy),
    ], now);

    test('pagod ngayon + busy na linggo → busy', () {
      expect(busy.noteFor(UserTone.tired), WeekVibe.busy);
      expect(busy.noteFor(UserTone.sad), WeekVibe.busy);
    });

    test('masaya ngayon + busy na linggo → wala (hindi sumasalungat)', () {
      expect(busy.noteFor(UserTone.happy), isNull);
    });

    test('masaya ngayon + good na linggo → good', () {
      expect(good.noteFor(UserTone.happy), WeekVibe.good);
    });

    test('pagod ngayon + good na linggo → wala', () {
      expect(good.noteFor(UserTone.tired), isNull);
    });

    test('neutral → wala', () {
      expect(busy.noteFor(UserTone.neutral), isNull);
    });
  });

  group('MoodLogEntry.fromRow', () {
    test('tamang row', () {
      final entry = MoodLogEntry.fromRow({'day': '2026-11-18', 'tone': 'tired', 'count': 2});
      expect(entry?.tone, UserTone.tired);
      expect(entry?.count, 2);
    });

    test('sira / neutral / 0 → null', () {
      expect(MoodLogEntry.fromRow({'day': '2026-11-18', 'tone': 'angry', 'count': 1}), isNull);
      expect(MoodLogEntry.fromRow({'day': '2026-11-18', 'tone': 'neutral', 'count': 1}), isNull);
      expect(MoodLogEntry.fromRow({'day': '2026-11-18', 'tone': 'tired', 'count': 0}), isNull);
      expect(MoodLogEntry.fromRow({'tone': 'tired', 'count': 1}), isNull);
    });
  });

  group('ZoeLines — mga linya tungkol sa linggo', () {
    test('bawat WeekVibe ay may linya sa lahat ng language', () {
      for (final v in WeekVibe.values) {
        final s = ZoeLines.situationForWeek(v);
        expect(ZoeLines.hasAllLanguages(s), isTrue, reason: '$v');
      }
    });

    test('busy → "Mukhang busy ang linggo mo…" sa Tagalog', () {
      final lines = ZoeLines.optionsFor(ZoeLanguage.tagalog, ZoeSituation.weekBusy);
      expect(lines.any((l) => l.startsWith('Mukhang busy ang linggo mo')), isTrue);
    });

    test('walang diagnosis o label sa linya', () {
      const banned = ['depress', 'anxiety', 'disorder', 'moody', 'problema mo'];
      for (final v in WeekVibe.values) {
        for (final l in ZoeLanguage.values) {
          for (final line in ZoeLines.optionsFor(l, ZoeLines.situationForWeek(v))) {
            for (final word in banned) {
              expect(line.toLowerCase().contains(word), isFalse, reason: line);
            }
          }
        }
      }
    });
  });
}