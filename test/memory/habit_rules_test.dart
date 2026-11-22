import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/ai/parser/intent_classifier.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/database/models/memory_item.dart';
import 'package:zoe_remind/database/models/reminder.dart';
import 'package:zoe_remind/database/repositories/memory_repository.dart';
import 'package:zoe_remind/database/repositories/reminder_repository.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/features/chat/controllers/chat_preview_brain.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';
import 'package:zoe_remind/memory/habit_rules.dart';
import 'package:zoe_remind/memory/habit_watcher.dart';

/// Takbuhin:  flutter test test/memory/habit_rules_test.dart
///
/// B6 implicit learning: napapansin ni Zoe ang ugali (morning / evening
/// reminders) at NAGMUMUNGKAHI lang — card + Accept, ON ang Long-term memory.
/// Walang database — fake repositories.

/// Hindi tinatawag si Qwen sa test.
class _NoQwen extends IntentClassifier {
  @override
  Future<void> warmUp() async {}

  @override
  Future<ZoeLabel?> label(String text) async => null;
}

class _FakeReminders extends ReminderRepository {
  _FakeReminders(this.items);
  final List<Reminder> items;

  @override
  Future<List<Reminder>> getAll() async => items;
}

class _FakeMemories extends MemoryRepository {
  _FakeMemories([this.items = const []]);
  final List<String> items;

  @override
  Future<List<MemoryItem>> getAll() async => [
        for (final c in items)
          MemoryItem(content: c, createdAt: DateTime(2026), updatedAt: DateTime(2026)),
      ];
}

class _FakeSettings extends SettingsRepository {
  _FakeSettings({this.memoryOn = true});
  final bool memoryOn;
  final values = <String, String>{};

  @override
  Future<bool> isLongTermMemoryOn() async => memoryOn;

  @override
  Future<String?> getValue(String key) async => values[key];

  @override
  Future<void> setValue(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  // Linggo, Nov 22, 2026, 7 PM.
  final now = DateTime(2026, 11, 22, 19, 0);

  /// (ginawa N araw na ang nakaraan, oras)
  List<(DateTime, String)> made(List<(int, String)> list) =>
      [for (final (ago, time) in list) (now.subtract(Duration(days: ago)), time)];

  group('HabitRules.check', () {
    test('5 reminder na 8 AM o mas maaga → morning (5)', () {
      final s = HabitRules.check(
        made([(1, '06:00'), (2, '07:30'), (3, '08:00'), (4, '05:45'), (5, '06:30'), (6, '13:00')]),
        now: now,
      );
      expect(s?.habit, Habit.morning);
      expect(s?.count, 5);
    });

    test('4 lang → wala pa', () {
      expect(
        HabitRules.check(made([(1, '06:00'), (2, '07:00'), (3, '07:30'), (4, '05:00')]), now: now),
        isNull,
      );
    });

    test('5 morning pero 10 reminder lahat (50%) → wala (hindi pa malinaw)', () {
      final s = HabitRules.check(
        made([
          for (var i = 1; i <= 5; i++) (i, '07:00'),
          for (var i = 1; i <= 5; i++) (i, '14:00'),
        ]),
        now: now,
      );
      expect(s, isNull);
    });

    test('8:01 AM ay hindi na morning; 4:00 AM ay morning pa', () {
      expect(HabitRules.habitAt(8 * 60 + 1), isNull);
      expect(HabitRules.habitAt(4 * 60), Habit.morning);
      expect(HabitRules.habitAt(3 * 60 + 59), isNull);
    });

    test('mga luma (lampas 30 araw) ay hindi binibilang', () {
      final s = HabitRules.check(
        made([(31, '06:00'), (32, '06:00'), (40, '06:00'), (1, '06:00'), (2, '06:00')]),
        now: now,
      );
      expect(s, isNull);
    });

    test('6 PM pataas → evening', () {
      final s = HabitRules.check(
        made([(1, '19:00'), (2, '20:00'), (3, '18:00'), (4, '21:30'), (5, '23:00')]),
        now: now,
      );
      expect(s?.habit, Habit.evening);
    });

    test('maling oras ay nilalaktawan', () {
      expect(HabitRules.minutes('25:00'), isNull);
      expect(HabitRules.minutes('abc'), isNull);
      expect(HabitRules.minutes('07:05'), 7 * 60 + 5);
    });
  });

  group('coveredBy / canAsk', () {
    test('may memory na tungkol sa umaga (gusto man o ayaw) → hindi na', () {
      expect(HabitRules.coveredBy(Habit.morning, ['Mas gusto ko ng morning reminders']), isTrue);
      expect(HabitRules.coveredBy(Habit.morning, ['Ayoko ng paalala sa umaga']), isTrue);
      expect(HabitRules.coveredBy(Habit.morning, ['Call me AC']), isFalse);
      expect(HabitRules.coveredBy(Habit.evening, ['Mas gusto ko ng morning reminders']), isFalse);
    });

    test('canAsk: wala pa → oo; declined → hindi na; naipakita → 30 araw', () {
      expect(HabitRules.canAsk(null, now: now), isTrue);
      expect(HabitRules.canAsk('declined', now: now), isFalse);
      expect(HabitRules.canAsk('shown:2026-11-10', now: now), isFalse);
      expect(HabitRules.canAsk('shown:2026-10-20', now: now), isTrue);
      expect(HabitRules.shownOn(now), 'shown:2026-11-22');
    });

    test('memory text (sa boses ng user)', () {
      const s = HabitSuggestion(Habit.morning, 5);
      expect(s.memory(ZoeLanguage.english), 'I prefer morning reminders (8 AM or earlier)');
      expect(s.memory(ZoeLanguage.both), 'Mas gusto ko ng morning reminders (8 AM o mas maaga)');
    });
  });

  group('HabitWatcher', () {
    Reminder r(int ago, String time) {
      final t = now.subtract(Duration(days: ago)).toIso8601String();
      return Reminder(title: 'x', date: '2026-11-23', time: time, createdAt: t, updatedAt: t);
    }

    final morning = [for (var i = 1; i <= 5; i++) r(i, '06:30')];

    test('ON + ugali + wala pang memory → mungkahi, at minamarkahang naipakita', () async {
      final settings = _FakeSettings();
      final w = HabitWatcher(
        reminders: _FakeReminders(morning),
        memories: _FakeMemories(),
        settings: settings,
        clock: () => now,
      );
      expect((await w.next())?.habit, Habit.morning);
      expect(settings.values['habit_suggest_morning'], 'shown:2026-11-22');
      // Hindi ulit-ulitin sa parehong buwan.
      expect(await w.next(), isNull);
    });

    test('OFF ang Long-term memory → walang mungkahi', () async {
      final w = HabitWatcher(
        reminders: _FakeReminders(morning),
        memories: _FakeMemories(),
        settings: _FakeSettings(memoryOn: false),
        clock: () => now,
      );
      expect(await w.next(), isNull);
    });

    test('may memory na → walang mungkahi', () async {
      final w = HabitWatcher(
        reminders: _FakeReminders(morning),
        memories: _FakeMemories(['Mas gusto ko ng morning reminders']),
        settings: _FakeSettings(),
        clock: () => now,
      );
      expect(await w.next(), isNull);
    });

    test('"Huwag" (decline) → hindi na kailanman', () async {
      final settings = _FakeSettings();
      final w = HabitWatcher(
        reminders: _FakeReminders(morning),
        memories: _FakeMemories(),
        settings: settings,
        clock: () => now,
      );
      await w.decline(Habit.morning);
      expect(settings.values['habit_suggest_morning'], 'declined');
      expect(await w.next(), isNull);
    });
  });

  test('ChatPreviewBrain.habitOffer → linya + memory card (mungkahi)', () {
    final brain = ChatPreviewBrain(
      reminders: _FakeReminders(const []),
      classifier: _NoQwen(),
      activeAlarms: () async => const {},
      clock: () => now,
      mood: () => MoodState.content,
      onMoodEvent: (_) {},
      onTone: (_) {},
      weekNote: (_) async => null,
      memoryOn: () async => true,
    );
    final out = brain.habitOffer(const HabitSuggestion(Habit.morning, 5), ZoeLanguage.both);
    expect(out, hasLength(2));
    expect((out[0] as TextEntry).text, contains('5 beses'));
    final card = out[1] as ConfirmEntry;
    expect(card.memory!.content, 'Mas gusto ko ng morning reminders (8 AM o mas maaga)');
    expect(card.memory!.isSuggestion, isTrue);
    expect(card.isPending, isTrue); // walang nase-save hangga't walang Accept
  });
}