import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/database/repositories/mood_repository.dart';
import 'package:zoe_remind/features/companion/controllers/mood_engine.dart';
import 'package:zoe_remind/features/companion/models/mood_day.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';

/// Takbuhin:  flutter test test/companion/mood_persistence_test.dart
void main() {
  const engine = MoodEngine();
  DateTime at(int h, [int m = 0, int day = 17]) => DateTime(2026, 11, day, h, m);

  group('MoodRules (silip sa araw → events)', () {
    test('walang nangyari → walang event', () {
      final (events, seen) = MoodRules.eventsFor(
        const DaySnapshot(day: '2026-11-17', itemsToday: 3, doneToday: 1),
        const MoodSeen(day: '2026-11-17'),
      );
      expect(events, isEmpty);
      expect(seen, const MoodSeen(day: '2026-11-17'));
    });

    test('bagong na-miss → isang ReminderMissed lang kahit dalawa', () {
      final (events, seen) = MoodRules.eventsFor(
        const DaySnapshot(day: '2026-11-17', itemsToday: 3, missedToday: 2),
        const MoodSeen(day: '2026-11-17'),
      );
      expect(events.whereType<ReminderMissed>().length, 1);
      expect(seen.missed, 2);
    });

    test('nakita na ang na-miss → hindi na uulit', () {
      const snap = DaySnapshot(day: '2026-11-17', itemsToday: 3, missedToday: 2);
      final (_, seen) = MoodRules.eventsFor(snap, const MoodSeen(day: '2026-11-17'));
      final (again, _) = MoodRules.eventsFor(snap, seen);
      expect(again.whereType<ReminderMissed>(), isEmpty);
    });

    test('bagong araw → reset ang nakita', () {
      final (events, seen) = MoodRules.eventsFor(
        const DaySnapshot(day: '2026-11-18', itemsToday: 1, missedToday: 1),
        const MoodSeen(day: '2026-11-17', missed: 5),
      );
      expect(events.whereType<ReminderMissed>().length, 1);
      expect(seen.day, '2026-11-18');
    });

    test('dumami ang overdue → OverdueTasks na may bilang', () {
      final (events, _) = MoodRules.eventsFor(
        const DaySnapshot(day: '2026-11-17', overdueTasks: 4),
        const MoodSeen(day: '2026-11-17', overdue: 2),
      );
      final e = events.whereType<OverdueTasks>().single;
      expect(e.count, 4);
    });

    test('tapos lahat → AllTasksDone; walang laman ang araw → wala', () {
      final (done, _) = MoodRules.eventsFor(
        const DaySnapshot(day: '2026-11-17', itemsToday: 2, doneToday: 2),
        const MoodSeen(day: '2026-11-17'),
      );
      expect(done.whereType<AllTasksDone>().length, 1);

      final (empty, _) = MoodRules.eventsFor(
        const DaySnapshot(day: '2026-11-17'),
        const MoodSeen(day: '2026-11-17'),
      );
      expect(empty.whereType<AllTasksDone>(), isEmpty);
    });

    test('streak: kapag may natapos NGAYON lang', () {
      final (today, _) = MoodRules.eventsFor(
        const DaySnapshot(day: '2026-11-17', streak: 3, completedToday: true),
        const MoodSeen(day: '2026-11-17'),
      );
      expect(today.whereType<StreakReached>().single.days, 3);

      final (yesterday, _) = MoodRules.eventsFor(
        const DaySnapshot(day: '2026-11-17', streak: 3),
        const MoodSeen(day: '2026-11-17'),
      );
      expect(yesterday.whereType<StreakReached>(), isEmpty);
    });

    test('na-miss + tapos lahat sabay → gentle ang nananalo sa engine', () {
      final (events, _) = MoodRules.eventsFor(
        const DaySnapshot(day: '2026-11-17', itemsToday: 2, doneToday: 2, missedToday: 1),
        const MoodSeen(day: '2026-11-17'),
      );
      var m = ZoeMood.initial(at(10));
      for (final e in events) {
        m = engine.reduce(m, e, at(10));
      }
      expect(m.state, MoodState.gentle);
    });
  });

  group('MoodRepository row (save → load)', () {
    test('pareho ang mood pagkatapos i-save at basahin', () {
      final mood = ZoeMood(
        state: MoodState.proud,
        intensity: 2,
        since: at(9, 30),
        reason: 'streak:7',
        celebrated: const {'streak:7', 'all_done'},
        celebratedOn: '2026-11-17',
      );
      const seen = MoodSeen(day: '2026-11-17', missed: 1, overdue: 3);

      final row = MoodRepository.toRow(mood, seen, at(10));
      expect(row['celebrated'], 'all_done,streak:7');

      final (back, backSeen) = MoodRepository.fromRow(row);
      expect(back.state, MoodState.proud);
      expect(back.intensity, 2);
      expect(back.since, at(9, 30));
      expect(back.reason, 'streak:7');
      expect(back.celebrated, {'streak:7', 'all_done'});
      expect(back.celebratedOn, '2026-11-17');
      expect(backSeen, seen);
    });

    test('focused ay hindi sine-save — ang mood bago mag-isip ang naiiwan', () {
      var m = engine.reduce(ZoeMood.initial(at(10)), const TaskCompleted(), at(10));
      m = engine.reduce(m, const ThinkingStarted(), at(10, 1));
      expect(m.state, MoodState.focused);

      final (back, _) = MoodRepository.fromRow(
          MoodRepository.toRow(m, const MoodSeen(), at(10, 1)));
      expect(back.state, MoodState.happy);
      expect(back.reason, 'task_done');
    });

    test('sirang row → ligtas na default (content)', () {
      final (back, seen) = MoodRepository.fromRow({
        'state': 'galit',
        'intensity': 99,
        'since': 'hindi petsa',
      });
      expect(back.state, MoodState.content);
      expect(back.intensity, 3);
      expect(back.celebrated, isEmpty);
      expect(seen, const MoodSeen());
    });

    test('decay pagbukas ulit: happy kahapon → content na ngayon', () {
      final saved = ZoeMood(state: MoodState.happy, intensity: 2, since: at(15, 0, 16));
      final (back, _) =
          MoodRepository.fromRow(MoodRepository.toRow(saved, const MoodSeen(), at(15, 0, 16)));
      final now = engine.decay(back, at(10));
      expect(now.state, MoodState.content);
    });
  });
}