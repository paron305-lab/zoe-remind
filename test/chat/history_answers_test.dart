import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/ai/parser/intent_classifier.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/models/reminder.dart';
import 'package:zoe_remind/database/models/reminder_occurrence.dart';
import 'package:zoe_remind/database/models/task.dart';
import 'package:zoe_remind/database/repositories/reminder_repository.dart';
import 'package:zoe_remind/database/repositories/task_repository.dart';
import 'package:zoe_remind/features/chat/controllers/chat_preview_brain.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';
import 'package:zoe_remind/features/companion/controllers/zoe_lines.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';

/// Takbuhin:  flutter test test/chat/history_answers_test.dart
///
/// A4: "ano na-miss ko?" at "ano ginawa ko kahapon?" ay galing sa HISTORY
/// (task_history, reminder_occurrences, completion_history), hindi sa
/// kasalukuyang estado. Walang database dito — fake repositories.

/// Hindi tinatawag si Qwen sa test.
class _NoQwen extends IntentClassifier {
  @override
  Future<void> warmUp() async {}

  @override
  Future<ZoeIntent?> classify(String text) async => null;
}

class _FakeTasks extends TaskRepository {
  _FakeTasks({this.missed = const [], this.completed = const []});

  /// Mga row ng task_history (status 'missed').
  final List<Map<String, Object?>> missed;

  /// Mga row ng completion_history (task).
  final List<CompletedTask> completed;

  @override
  Future<int> recordMissed({DateTime? now}) async => 0;

  @override
  Future<List<Map<String, Object?>>> getMissed({String? from, String? to}) async => missed
      .where((r) =>
          (from == null || (r['day'] as String).compareTo(from) >= 0) &&
          (to == null || (r['day'] as String).compareTo(to) <= 0))
      .toList();

  @override
  Future<List<CompletedTask>> getCompleted({
    required DateTime from,
    required DateTime to,
  }) async =>
      completed.where((c) {
        final d = ZoeDate.dayOnly(c.completedAt);
        return !d.isBefore(from) && !d.isAfter(to);
      }).toList();

  @override
  Future<List<Task>> getAll() async => const [];
}

class _FakeReminders extends ReminderRepository {
  _FakeReminders({this.occurrences = const [], this.reminders = const []});

  /// Mga row ng reminder_occurrences.
  final List<ReminderOccurrence> occurrences;

  /// Mga reminder (para sa ngayong araw).
  final List<Reminder> reminders;

  @override
  Future<void> recordMissed({
    Map<int, DateTime> pending = const {},
    DateTime? now,
  }) async {}

  @override
  Future<List<ReminderOccurrence>> getOccurrences({
    required DateTime from,
    required DateTime to,
    OccurrenceStatus? status,
  }) async =>
      occurrences
          .where((o) =>
              o.day.compareTo(ZoeDate.key(from)) >= 0 &&
              o.day.compareTo(ZoeDate.key(to)) <= 0 &&
              (status == null || o.status == status))
          .toList();

  @override
  Future<List<Reminder>> getForDay(DateTime day) async =>
      reminders.where((r) => r.occursOn(day)).toList();
}

void main() {
  // Miyerkules, Nov 18, 2026, 3:00 PM.
  final now = DateTime(2026, 11, 18, 15, 0);
  const lang = ZoeLanguage.tagalog;

  ChatPreviewBrain brainWith({
    _FakeTasks? tasks,
    _FakeReminders? reminders,
    Map<int, DateTime> active = const {},
  }) =>
      ChatPreviewBrain(
        tasks: tasks ?? _FakeTasks(),
        reminders: reminders ?? _FakeReminders(),
        classifier: _NoQwen(),
        mood: () => MoodState.content,
        onMoodEvent: (_) {},
        onTone: (_) {},
        weekNote: (_) async => null,
        clock: () => now,
        activeAlarms: () async => active,
      );

  Reminder reminder(int id, String title, String date, String time,
          {ReminderRepeat repeat = ReminderRepeat.none, String? lastDoneDate}) =>
      Reminder(
        id: id,
        title: title,
        date: date,
        time: time,
        repeat: repeat,
        lastDoneDate: lastDoneDate,
        status: lastDoneDate == null ? 'pending' : 'done',
        createdAt: '2026-11-01T08:00:00.000',
        updatedAt: '2026-11-01T08:00:00.000',
      );

  ReminderOccurrence occurrence(int id, String title, String day, OccurrenceStatus status) =>
      ReminderOccurrence(
        reminderId: id,
        title: title,
        day: day,
        time: '08:00',
        status: status,
        recordedAt: '${day}T23:59:00.000',
      );

  Future<AnswerEntry> ask(ChatPreviewBrain brain, String text) async {
    final entries = await brain.reply(text, lang);
    expect(entries, hasLength(1), reason: text);
    expect(entries.single, isA<AnswerEntry>(), reason: text);
    return entries.single as AnswerEntry;
  }

  group('"ano na-miss ko?" — huling 7 araw, tasks + reminders', () {
    test('kasama ang tasks, lumang reminders at ngayong araw; hindi ang lampas 7 araw', () async {
      final brain = brainWith(
        tasks: _FakeTasks(missed: [
          {'task_id': 1, 'title': 'Labada', 'day': '2026-11-16', 'time': '10:00', 'status': 'missed'},
          {'task_id': 2, 'title': 'Lumang task', 'day': '2026-11-05', 'time': null, 'status': 'missed'},
        ]),
        reminders: _FakeReminders(
          occurrences: [
            occurrence(10, 'Bayad kuryente', '2026-11-15', OccurrenceStatus.missed),
            occurrence(11, 'Lumang reminder', '2026-11-10', OccurrenceStatus.missed),
            occurrence(12, 'Inom gamot', '2026-11-17', OccurrenceStatus.done),
          ],
          reminders: [
            reminder(1, 'Tawag kay mama', '2026-11-18', '09:00'), // lumipas, walang ginawa
            reminder(2, 'Gym', '2026-11-18', '20:00'), // mamaya pa
            reminder(3, 'Naka-snooze', '2026-11-18', '14:00'), // may alarm pa
          ],
        ),
        active: {3: DateTime(2026, 11, 18, 14, 0)},
      );

      final a = await ask(brain, 'ano na-miss ko?');
      expect(a.text, contains('Tawag kay mama'));
      expect(a.text, contains('Labada'));
      expect(a.text, contains('Bayad kuryente'));
      expect(a.text, isNot(contains('Lumang')));
      expect(a.text, isNot(contains('Gym')));
      expect(a.text, isNot(contains('Naka-snooze')));
      expect(a.text, isNot(contains('Inom gamot')));
      expect(a.assumption, contains('Nov 12'));
      expect(a.assumption, contains('Nov 18'));
      expect(a.rows.map((r) => r.label), ['1 missed task', '2 missed reminders']);
    });

    test('walang na-miss → missedNone', () async {
      final a = await ask(brainWith(), 'may na-miss ba ako?');
      expect(ZoeLines.optionsFor(lang, ZoeSituation.missedNone, MoodState.content), contains(a.text));
      expect(a.rows, isEmpty);
    });

    test('"may na-miss ba akong reminder?" → listahan, hindi bagong reminder', () async {
      final brain = brainWith(
        reminders: _FakeReminders(occurrences: [
          occurrence(10, 'Bayad kuryente', '2026-11-15', OccurrenceStatus.missed),
        ]),
      );
      final a = await ask(brain, 'may na-miss ba akong reminder?');
      expect(a.text, contains('Bayad kuryente'));
    });
  });

  group('"ano ginawa ko kahapon?" — galing sa history', () {
    final tasks = _FakeTasks(completed: [
      (taskId: 1, title: 'Review thesis', completedAt: DateTime(2026, 11, 17, 10, 0)),
      (taskId: 2, title: 'Iba pang task', completedAt: DateTime(2026, 11, 16, 21, 0)),
    ]);
    final reminders = _FakeReminders(
      occurrences: [
        occurrence(5, 'Inom gamot', '2026-11-17', OccurrenceStatus.done),
        occurrence(5, 'Inom gamot', '2026-11-18', OccurrenceStatus.done),
        occurrence(6, 'Na-dismiss', '2026-11-17', OccurrenceStatus.dismissed),
      ],
      // Daily reminder na na-done din NGAYON — dati, nawawala ito sa "kahapon".
      reminders: [
        reminder(5, 'Inom gamot', '2026-11-01', '08:00',
            repeat: ReminderRepeat.daily, lastDoneDate: '2026-11-18'),
      ],
    );

    test('kasama ang daily reminder kahit na-done ulit ngayon', () async {
      final a = await ask(brainWith(tasks: tasks, reminders: reminders), 'ano ginawa ko kahapon?');
      expect(a.text, contains('Review thesis'));
      expect(a.text, contains('Inom gamot'));
      expect(a.text, isNot(contains('Iba pang task')));
      expect(a.text, isNot(contains('Na-dismiss')));
      expect(a.assumption, contains('Nov 17, 2026'));
      expect(a.rows.map((r) => r.label), ['1 task completed', '1 reminder done']);
    });

    test('"ano natapos ko noong lunes?" → Lunes, Nov 16', () async {
      final a = await ask(brainWith(tasks: tasks, reminders: reminders), 'ano natapos ko noong lunes?');
      expect(a.text, contains('Iba pang task'));
      expect(a.text, isNot(contains('Review thesis')));
      expect(a.assumption, contains('Nov 16, 2026'));
    });
  });

  test('"na-miss kita" → hindi listahan ng na-miss', () async {
    final entries = await brainWith().reply('na-miss kita zoe', lang);
    expect(entries.whereType<AnswerEntry>(), isEmpty);
  });
}