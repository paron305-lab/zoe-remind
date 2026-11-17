import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/features/companion/controllers/mood_engine.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';

/// Takbuhin:  flutter test test/companion/mood_engine_test.dart
void main() {
  const engine = MoodEngine();

  /// Nov 17, 2026 sa oras na [h]:[m].
  DateTime at(int h, [int m = 0, int day = 17]) => DateTime(2026, 11, day, h, m);

  /// Sunod-sunod na event sa iisang oras.
  ZoeMood run(List<ZoeEvent> events, DateTime now, [ZoeMood? start]) {
    var mood = start ?? ZoeMood.initial(now);
    for (final e in events) {
      mood = engine.reduce(mood, e, now);
    }
    return mood;
  }

  group('Simula', () {
    test('content ang default', () {
      final m = engine.decay(ZoeMood.initial(at(10)), at(10));
      expect(m.state, MoodState.content);
      expect(m.intensity, 0);
    });
  });

  group('happy', () {
    test('may natapos → happy, intensity 1', () {
      final m = run([const TaskCompleted()], at(10));
      expect(m.state, MoodState.happy);
      expect(m.intensity, 1);
      expect(m.reason, 'task_done');
    });

    test('bawat natapos ay +1 intensity, hanggang 3 lang', () {
      final m = run([
        const TaskCompleted(),
        const ReminderDone(),
        const TaskCompleted(),
        const TaskCompleted(),
        const TaskCompleted(),
      ], at(10));
      expect(m.state, MoodState.happy);
      expect(m.intensity, 3);
    });

    test('lumilipas pagkalipas ng 2 oras', () {
      final happy = run([const TaskCompleted()], at(10));
      expect(engine.decay(happy, at(11, 59)).state, MoodState.happy);
      expect(engine.decay(happy, at(12)).state, MoodState.content);
    });

    test('umaga + may plano → happy; hapon o walang plano → walang pagbabago', () {
      expect(run([const AppOpened(itemsToday: 2)], at(8)).state, MoodState.happy);
      expect(run([const AppOpened(itemsToday: 0)], at(8)).state, MoodState.content);
      expect(run([const AppOpened(itemsToday: 2)], at(15)).state, MoodState.content);
    });
  });

  group('proud — isang celebration kada achievement kada araw', () {
    test('tapos lahat → proud', () {
      final m = run([const AllTasksDone()], at(10));
      expect(m.state, MoodState.proud);
      expect(m.reason, 'all_done');
      expect(m.celebrated, contains('all_done'));
    });

    test('pangalawang AllTasksDone sa parehong araw → hindi na nagce-celebrate', () {
      final proud = run([const AllTasksDone()], at(10));
      final again = engine.reduce(proud, const AllTasksDone(), at(10, 5));
      expect(again.state, MoodState.proud);
      expect(again.intensity, proud.intensity); // walang +1

      // Lumipas na ang proud (content na ng 14:00) → hindi pa rin uulit ngayong araw.
      final later = engine.reduce(proud, const AllTasksDone(), at(14));
      expect(later.state, MoodState.content);
    });

    test('kinabukasan → pwede ulit mag-celebrate', () {
      final proud = run([const AllTasksDone()], at(10));
      final tomorrow = engine.reduce(proud, const AllTasksDone(), at(10, 0, 18));
      expect(tomorrow.state, MoodState.proud);
    });

    test('streak: 3, 7, 30 lang ang sine-celebrate', () {
      expect(run([const StreakReached(2)], at(10)).state, MoodState.content);
      expect(run([const StreakReached(3)], at(10)).state, MoodState.proud);
      expect(run([const StreakReached(4)], at(10)).state, MoodState.content);
      expect(run([const StreakReached(7)], at(10)).reason, 'streak:7');
      expect(run([const StreakReached(30)], at(10)).state, MoodState.proud);
    });

    test('unang reminder na natapos → proud', () {
      expect(run([const FirstReminderDone()], at(10)).state, MoodState.proud);
    });

    test('proud → happy pagkalipas ng 1 oras → content pagkalipas ng 2 pa', () {
      final proud = run([const AllTasksDone()], at(10));
      expect(engine.decay(proud, at(10, 59)).state, MoodState.proud);
      expect(engine.decay(proud, at(11)).state, MoodState.happy);
      expect(engine.decay(proud, at(12, 59)).state, MoodState.happy);
      expect(engine.decay(proud, at(13)).state, MoodState.content);
    });
  });

  group('gentle', () {
    test('may na-miss → gentle', () {
      final m = run([const ReminderMissed()], at(10));
      expect(m.state, MoodState.gentle);
      expect(m.reason, 'missed_reminder');
    });

    test('na-miss ay laging panalo sa celebration', () {
      final m = run([const AllTasksDone(), const ReminderMissed()], at(10));
      expect(m.state, MoodState.gentle);
    });

    test('celebration habang gentle → hindi pinapansin, at HINDI binibilang', () {
      final gentle = run([const ReminderMissed(), const AllTasksDone()], at(10));
      expect(gentle.state, MoodState.gentle);
      expect(gentle.celebrated, isNot(contains('all_done')));

      // Pagkalipas ng gentle (13:00), pwede pa ring mag-celebrate ngayong araw.
      final later = engine.reduce(gentle, const AllTasksDone(), at(13));
      expect(later.state, MoodState.proud);
    });

    test('overdue: 2 → wala; 3 → gentle 1; 6 → gentle 2', () {
      expect(run([const OverdueTasks(2)], at(10)).state, MoodState.content);
      expect(run([const OverdueTasks(3)], at(10)).intensity, 1);
      expect(run([const OverdueTasks(6)], at(10)).intensity, 2);
    });

    test('pagod / malungkot ang user → gentle 2, kahit proud si Zoe', () {
      final m = run([const AllTasksDone(), const UserFeelsDown()], at(10));
      expect(m.state, MoodState.gentle);
      expect(m.intensity, 2);
    });

    test('lumilipas pagkalipas ng 3 oras', () {
      final gentle = run([const ReminderMissed()], at(10));
      expect(engine.decay(gentle, at(12, 59)).state, MoodState.gentle);
      expect(engine.decay(gentle, at(13)).state, MoodState.content);
    });

    test('happy habang gentle → nananatiling gentle', () {
      final m = run([const ReminderMissed(), const TaskCompleted()], at(10));
      expect(m.state, MoodState.gentle);
    });
  });

  group('sleepy (gabi 23:00–05:00)', () {
    test('content → sleepy sa 23:00, balik content sa 05:00', () {
      final day = ZoeMood.initial(at(22));
      expect(engine.decay(day, at(22, 59)).state, MoodState.content);
      final night = engine.decay(day, at(23));
      expect(night.state, MoodState.sleepy);
      expect(engine.decay(night, at(4, 59, 18)).state, MoodState.sleepy);
      expect(engine.decay(night, at(5, 0, 18)).state, MoodState.content);
    });

    test('happy sa gabi → happy pa rin, tapos sleepy pagkalipas', () {
      final happy = run([const TaskCompleted()], at(22, 30));
      expect(engine.decay(happy, at(23, 30)).state, MoodState.happy);
      expect(engine.decay(happy, at(0, 30, 18)).state, MoodState.sleepy);
    });

    test('pwedeng palitan ang oras ng gabi (para sa Quiet hours sa P4)', () {
      const custom = MoodEngine(nightStartHour: 22, nightEndHour: 6);
      expect(custom.isNight(at(21, 59)), isFalse);
      expect(custom.isNight(at(22)), isTrue);
      expect(custom.isNight(at(5, 59)), isTrue);
      expect(custom.isNight(at(6)), isFalse);
    });
  });

  group('focused (nag-iisip si Zoe)', () {
    test('babalik sa dating mood pagkatapos mag-isip', () {
      final m = run([
        const TaskCompleted(),
        const ThinkingStarted(),
      ], at(10));
      expect(m.state, MoodState.focused);
      final done = engine.reduce(m, const ThinkingFinished(), at(10, 1));
      expect(done.state, MoodState.happy);
    });

    test('hindi napapalitan ang gentle o sorry', () {
      expect(run([const ReminderMissed(), const ThinkingStarted()], at(10)).state,
          MoodState.gentle);
      expect(run([const ZoeFailed(ZoeFailure.inference), const ThinkingStarted()], at(10)).state,
          MoodState.sorry);
    });

    test('may natapos habang nag-iisip → hindi nawawala', () {
      final m = run([
        const ThinkingStarted(),
        const TaskCompleted(),
      ], at(10));
      expect(m.state, MoodState.focused);
      final done = engine.reduce(m, const ThinkingFinished(), at(10, 1));
      expect(done.state, MoodState.happy);
    });

    test('celebration habang nag-iisip → lumalabas pagkatapos, isang beses lang', () {
      final m = run([
        const ThinkingStarted(),
        const AllTasksDone(),
        const AllTasksDone(),
      ], at(10));
      expect(m.state, MoodState.focused);
      final done = engine.reduce(m, const ThinkingFinished(), at(10, 1));
      expect(done.state, MoodState.proud);
      expect(done.celebrated, contains('all_done'));
      expect(done.intensity, 2); // hindi na-+1 ng pangalawang AllTasksDone
    });

    test('na-stuck (walang ThinkingFinished) → bumabalik pagkalipas ng 5 minuto', () {
      final m = run([const ThinkingStarted()], at(10));
      expect(engine.decay(m, at(10, 4)).state, MoodState.focused);
      expect(engine.decay(m, at(10, 5)).state, MoodState.content);
    });
  });

  group('sorry', () {
    test('AI error → sorry; matagumpay na action → content', () {
      final sorry = run([const ZoeFailed(ZoeFailure.inference)], at(10));
      expect(sorry.state, MoodState.sorry);
      expect(sorry.reason, 'failed:inference');

      final fixed = engine.reduce(sorry, const ActionSucceeded(), at(10, 2));
      expect(fixed.state, MoodState.content);
      expect(fixed.reason, 'fixed');
    });

    test('sorry ang pinakamataas — panalo kahit sa gentle', () {
      final m = run([const ReminderMissed(), const ZoeFailed(ZoeFailure.alarm)], at(10));
      expect(m.state, MoodState.sorry);
    });

    test('hindi habambuhay: content pagkalipas ng 6 na oras', () {
      final sorry = run([const ZoeFailed(ZoeFailure.sync)], at(10));
      expect(engine.decay(sorry, at(15, 59)).state, MoodState.sorry);
      expect(engine.decay(sorry, at(16)).state, MoodState.content);
    });
  });

  group('Pure function', () {
    test('hindi binabago ang lumang mood (immutable)', () {
      final before = run([const TaskCompleted()], at(10));
      engine.reduce(before, const ReminderMissed(), at(10, 1));
      expect(before.state, MoodState.happy);
      expect(before.intensity, 1);
    });

    test('parehong input → parehong output', () {
      final a = run([const TaskCompleted(), const ReminderMissed()], at(10));
      final b = run([const TaskCompleted(), const ReminderMissed()], at(10));
      expect(a.state, b.state);
      expect(a.intensity, b.intensity);
      expect(a.reason, b.reason);
    });
  });
}