import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/ai/parser/intent_classifier.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/database/repositories/search_repository.dart';
import 'package:zoe_remind/features/chat/controllers/chat_preview_brain.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';
import 'package:zoe_remind/features/companion/controllers/zoe_lines.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/retriever.dart';

/// Takbuhin:  flutter test test/chat/ask_first_test.dart
///
/// Phrase bank: kapag HINDI malinaw na utos, magtatanong muna si Zoe
/// ("Reminder ba 'to, task, o note?") bago gumawa ng card.
/// Malinaw na utos ("remind me…", "add task…") → card agad (Accept pa rin).

/// Si "Qwen" sa test: laging [guess] ang sagot.
class _FakeQwen extends IntentClassifier {
  _FakeQwen([this.guess]);
  final ZoeIntent? guess;

  @override
  Future<void> warmUp() async {}

  @override
  Future<ZoeLabel?> label(String text) async => guess == null ? null : ZoeLabel(guess!);
}

/// Walang database: walang nahahanap.
class _NoSearch extends SearchRepository {
  @override
  Future<List<RetrievalDoc>> candidates(List<TermGroup> terms, {bool includeMemories = true}) async =>
      const [];
}

void main() {
  final now = DateTime(2026, 11, 21, 20, 0); // Sabado, 8 PM
  final tomorrow = DateTime(2026, 11, 22);
  const lang = ZoeLanguage.tagalog;

  ChatPreviewBrain brain({ZoeIntent? qwen}) => ChatPreviewBrain(
        retriever: Retriever(repo: _NoSearch()),
        memoryOn: () async => true,
        classifier: _FakeQwen(qwen),
        mood: () => MoodState.content,
        onMoodEvent: (_) {},
        onTone: (_) {},
        weekNote: (_) async => null,
        clock: () => now,
        activeAlarms: () async => const {},
      );

  ClarifyEntry asked(List<ChatEntry> reply, [ZoeLanguage l = lang]) {
    final ask = reply.whereType<ClarifyEntry>().single;
    expect(ask.asksKind, isTrue);
    expect(ZoeLines.optionsFor(l, ZoeSituation.askKind, MoodState.content), contains(ask.question));
    return ask;
  }

  List<DraftKind?> kinds(ClarifyEntry c) => [for (final x in c.chips) x.skip ? null : x.kind];

  test('"meeting kay boss 3pm bukas" → tanong muna, hindi "Anong oras?" o card', () async {
    final reply = await brain().reply('meeting kay boss 3pm bukas', lang);
    expect(reply, hasLength(1));
    final ask = asked(reply);
    expect(kinds(ask), [DraftKind.reminder, DraftKind.task, DraftKind.note, null]);
    expect(ask.chips.every((c) => !c.isTime), isTrue);
    expect(ask.source, 'meeting kay boss 3pm bukas');
  });

  test('pinili ang ⏰ Reminder → reminder card (bukas 3 PM, "Meeting kay boss")', () async {
    final b = brain();
    final card = (await b.draftFor(DraftKind.reminder, 'meeting kay boss 3pm bukas', lang)).single
        as ConfirmEntry;
    expect(card.kind, DraftKind.reminder);
    expect(card.isPending, isTrue); // wala pang nase-save
    expect(card.reminder!.title, 'Meeting kay boss');
    expect(card.reminder!.time, const TimeOfDay(hour: 15, minute: 0));
    expect(card.reminder!.date, tomorrow);
  });

  test('pinili ang ✅ Task / 📝 Note → task / note card', () async {
    final b = brain();
    final task = (await b.draftFor(DraftKind.task, 'kailangan kong magbayad ng kuryente', lang)).single
        as ConfirmEntry;
    expect(task.kind, DraftKind.task);
    expect(task.task!.title, 'Magbayad ng kuryente');

    final note = (await b.draftFor(DraftKind.note, 'meeting kay boss 3pm bukas', lang)).single
        as ConfirmEntry;
    expect(note.kind, DraftKind.note);
  });

  test('"kailangan kong…", "I need to…", "task", "alarm bukas" → tanong muna', () async {
    for (final t in [
      'kailangan kong magbayad ng kuryente sa Biyernes',
      'I need to finish my report on Friday',
      'task',
      'reminder',
      'alarm bukas',
      'do the laundry 5pm',
    ]) {
      final reply = await brain().reply(t, lang);
      expect(reply.single, isA<ClarifyEntry>(), reason: t);
      expect((reply.single as ClarifyEntry).asksKind, isTrue, reason: t);
    }
  });

  test('bug sa phone: "You have to remember everyday i love to remind about my happiness"', () async {
    final b = brain();
    const text = 'You have to remember everyday i love to remind about my happiness';
    final ask = asked(await b.reply(text, ZoeLanguage.english), ZoeLanguage.english);
    expect(kinds(ask), contains(DraftKind.memory)); // may 💜 Remember
    final card = (await b.draftFor(DraftKind.memory, text, ZoeLanguage.english)).single as ConfirmEntry;
    expect(card.kind, DraftKind.memory);
    expect(card.memory!.content, contains('happiness'));
    expect(card.memory!.content.toLowerCase(), isNot(contains('have to remember')));
  });

  test('malinaw na utos (kahit text-speak) → card agad', () async {
    final reminder = (await brain().reply('pls rmnd me 2mrw 8am to buy milk', lang)).single as ConfirmEntry;
    expect(reminder.kind, DraftKind.reminder);
    expect(reminder.reminder!.title, 'Buy milk');
    expect(reminder.reminder!.time, const TimeOfDay(hour: 8, minute: 0));
    expect(reminder.reminder!.date, tomorrow);

    final task = (await brain().reply('lagay mo sa tasks ko: magbayad ng kuryente', lang)).single
        as ConfirmEntry;
    expect(task.kind, DraftKind.task);
    expect(task.task!.title, 'Magbayad ng kuryente');
  });

  test('"call me AC" → memory card (kahit walang "tandaan mo")', () async {
    final card = (await brain().reply('call me AC', ZoeLanguage.english)).single as ConfirmEntry;
    expect(card.kind, DraftKind.memory);
    expect(card.memory!.content, 'Call me AC');
  });

  test('hula ni Qwen na reminder → tanong muna, hindi card', () async {
    final reply = await brain(qwen: ZoeIntent.createReminder).reply('yung sa ospital ni lola', lang);
    asked(reply);
  });

  test('pagod + "kailangan kong…" → nagkukuwento (feeling), hindi tanong', () async {
    final reply = await brain().reply('pagod na ako, kailangan ko pang tapusin to', lang);
    expect(reply.whereType<ClarifyEntry>(), isEmpty);
    expect(reply.single, isA<TextEntry>());
  });

  test('English: mga label ng chips', () async {
    final ask = asked(await brain().reply('dentist appointment 10am', ZoeLanguage.english), ZoeLanguage.english);
    expect(ask.chips.map((c) => c.label), ['⏰ Reminder', '✅ Task', '📝 Note', '✖ Never mind']);
  });
}