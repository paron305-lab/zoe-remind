import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/ai/parser/intent_classifier.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/models/reminder.dart';
import 'package:zoe_remind/database/models/reminder_occurrence.dart';
import 'package:zoe_remind/database/models/task.dart';
import 'package:zoe_remind/database/repositories/reminder_repository.dart';
import 'package:zoe_remind/database/repositories/search_repository.dart';
import 'package:zoe_remind/database/repositories/task_repository.dart';
import 'package:zoe_remind/features/chat/controllers/chat_preview_brain.dart';
import 'package:zoe_remind/features/chat/controllers/chat_router.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/retriever.dart';
import 'package:zoe_remind/rag/search_misses.dart';

/// Takbuhin:  flutter test test/chat/qwen_label_chat_test.dart
///
/// B6: kapag walang tumamang rule, si "Qwen" ang nagla-label — pero code
/// pa rin ang naghahanap at sumasagot. Walang database, walang model:
/// fake Qwen (laging [raw] ang sagot) + fake repositories.

/// Si "Qwen" sa test: laging [raw] ang hilaw na sagot. Dumadaan pa rin sa
/// totoong allowlist + code check + ZoeLabel (gaya ng phone).
class _FakeQwen extends IntentClassifier {
  _FakeQwen(this.raw);
  final String raw;

  /// Mga mensaheng ipinasa kay Qwen.
  final asked = <String>[];

  @override
  Future<void> warmUp() async {}

  @override
  Future<ZoeLabel?> label(String text) async {
    asked.add(text);
    final said = IntentClassifier.parse(raw);
    final intent = IntentClassifier.checkWithCode(said, text);
    return intent == null ? null : ZoeLabel.from(intent, raw, text);
  }
}

/// Isinusulat ang mga salitang hinanap, at ibinabalik ang lahat ng docs.
class _FakeSearch extends SearchRepository {
  _FakeSearch(this.docs);
  final List<RetrievalDoc> docs;
  final searched = <String>[];

  @override
  Future<List<RetrievalDoc>> candidates(List<TermGroup> terms, {bool includeMemories = true}) async {
    searched.add(terms.map((t) => t.word).join(' '));
    return docs;
  }
}

class _FakeTasks extends TaskRepository {
  _FakeTasks({this.missed = const []});
  final List<Map<String, Object?>> missed;

  @override
  Future<int> recordMissed({DateTime? now}) async => 0;

  @override
  Future<List<Map<String, Object?>>> getMissed({String? from, String? to}) async => missed
      .where((r) =>
          (from == null || (r['day'] as String).compareTo(from) >= 0) &&
          (to == null || (r['day'] as String).compareTo(to) <= 0))
      .toList();

  @override
  Future<List<CompletedTask>> getCompleted({required DateTime from, required DateTime to}) async =>
      const [];

  @override
  Future<List<Task>> getAll() async => const [];
}

class _FakeReminders extends ReminderRepository {
  @override
  Future<void> recordMissed({Map<int, DateTime> pending = const {}, DateTime? now}) async {}

  @override
  Future<List<ReminderOccurrence>> getOccurrences({
    required DateTime from,
    required DateTime to,
    OccurrenceStatus? status,
  }) async =>
      const [];

  @override
  Future<List<Reminder>> getForDay(DateTime day) async => const [];
}

void main() {
  // Sabado, Nov 21, 2026, 8 PM.
  final now = DateTime(2026, 11, 21, 20, 0);
  const lang = ZoeLanguage.tagalog;

  final docs = [
    RetrievalDoc(
      source: RetrievalSource.note,
      id: 1,
      title: 'Gamot ni Mama',
      text: 'Losartan 50mg tuwing umaga',
      updatedAt: DateTime(2026, 11, 18),
    ),
    RetrievalDoc(
      source: RetrievalSource.note,
      id: 2,
      title: 'Last time sa mall',
      text: 'tungkol sa sapatos',
      updatedAt: DateTime(2026, 11, 20),
    ),
  ];

  ChatPreviewBrain brainWith(_FakeQwen qwen, {_FakeSearch? search, _FakeTasks? tasks}) =>
      ChatPreviewBrain(
        tasks: tasks ?? _FakeTasks(),
        reminders: _FakeReminders(),
        retriever: Retriever(repo: search ?? _FakeSearch(docs), clock: () => now),
        memoryOn: () async => true,
        classifier: qwen,
        mood: () => MoodState.content,
        onMoodEvent: (_) {},
        onTone: (_) {},
        weekNote: (_) async => null,
        clock: () => now,
        activeAlarms: () async => const {},
      );

  Future<AnswerEntry> ask(ChatPreviewBrain brain, String text) async {
    final entries = await brain.reply(text, lang);
    expect(entries, hasLength(1), reason: text);
    expect(entries.single, isA<AnswerEntry>(), reason: text);
    return entries.single as AnswerEntry;
  }

  group('search_notes | mga salita', () {
    const q = 'yung sinabi ko last time tungkol sa gamot ni mama';

    test('Qwen: "gamot, mama" → iyon ang hinanap, note mismo ang sagot', () async {
      final qwen = _FakeQwen('search_notes | gamot, mama');
      final search = _FakeSearch(docs);
      final a = await ask(brainWith(qwen, search: search), q);
      expect(qwen.asked, [q]); // walang rule → si Qwen
      expect(search.searched.first, 'gamot mama');
      expect(a.text, contains('Losartan'));
      expect(a.rows.first.route, '/notes/edit/1');
    });

    test('inimbento ni Qwen ("losartan") → hindi hinanap', () async {
      final search = _FakeSearch(docs);
      await ask(brainWith(_FakeQwen('search_notes | losartan, mama'), search: search), q);
      expect(search.searched.first, 'mama');
    });

    test('walang salita mula kay Qwen → buong tanong ang hinanap', () async {
      final search = _FakeSearch(docs);
      await ask(brainWith(_FakeQwen('search_notes'), search: search), q);
      expect(search.searched.first, contains('gamot'));
      expect(search.searched.first, contains('mama'));
      // R4: "tungkol" = stopword na (gaya ng "about") → hindi na hinahanap.
      expect(search.searched.first, isNot(contains('tungkol')));
    });

    test('walang nahanap → tapat na "wala", may salitang hinanap, nasa Hindi nahanap', () async {
      SearchMisses.clear();
      final a = await ask(
        brainWith(_FakeQwen('search_notes | gamot, mama'), search: _FakeSearch(const [])),
        q,
      );
      // R5: hinahanap na rin ang reminders + tasks.
      expect(a.assumption, 'Hinanap sa notes, reminders at tasks mo: gamot, mama');
      expect(a.rows, isEmpty);
      expect(SearchMisses.items.single.question, ChatRouter.clean(q));
    });
  });

  group('get_missed | saklaw', () {
    final tasks = _FakeTasks(missed: [
      {'task_id': 1, 'title': 'Bayad tubig', 'day': '2026-11-19', 'time': null, 'status': 'missed'},
      {'task_id': 2, 'title': 'Labada', 'day': '2026-11-15', 'time': null, 'status': 'missed'},
    ]);

    test('"these past few days" + Qwen "last 3 days" → Nov 19–21 lang', () async {
      final a = await ask(
        brainWith(_FakeQwen('get_missed | last 3 days'), tasks: tasks),
        'may naiwan ba akong hindi nagawa these past few days?',
      );
      expect(a.text, contains('Bayad tubig'));
      expect(a.text, isNot(contains('Labada')));
    });

    test('walang binanggit na panahon → hindi ginamit ang hula; default 7 araw', () async {
      final a = await ask(
        brainWith(_FakeQwen('get_missed | yesterday'), tasks: tasks),
        'may naiwan ba akong hindi nagawa?',
      );
      expect(a.text, contains('Bayad tubig'));
      expect(a.text, contains('Labada'));
    });
  });

  test('may tumamang rule → hindi tinatanong si Qwen', () async {
    final qwen = _FakeQwen('search_notes | wifi');
    await brainWith(qwen).reply('ano wifi password ko?', lang);
    expect(qwen.asked, isEmpty);
  });

  test('ZoeDate sanity (Sabado)', () => expect(ZoeDate.key(now), '2026-11-21'));
}