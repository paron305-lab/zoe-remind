import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/ai/parser/intent_classifier.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/database/repositories/search_repository.dart';
import 'package:zoe_remind/features/chat/controllers/chat_preview_brain.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';
import 'package:zoe_remind/features/companion/controllers/zoe_lines.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_learning.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/retriever.dart';

/// Takbuhin:  flutter test test/chat/rag_learning_chat_test.dart
///
/// R6 sa Zoe Chat (brain + RagLearning, RAM store — walang database):
///   "ano pw ng net ko?" (pumalya) → "ano wifi password ko?" (tumama) ×2
///   → "ano net ko?" → Wifi note na.
///   "oo" / "buksan mo" = tama · "hindi yan" = mali · walang nahanap = naka-log.

/// Hindi tinatawag si Qwen sa test.
class _NoQwen extends IntentClassifier {
  @override
  Future<void> warmUp() async {}

  @override
  Future<ZoeLabel?> label(String text) async => null;
}

class _FakeSearch extends SearchRepository {
  _FakeSearch(this.docs);
  final List<RetrievalDoc> docs;

  @override
  Future<List<RetrievalDoc>> candidates(List<TermGroup> terms, {bool includeMemories = true}) async =>
      docs.where((d) => includeMemories || !d.isMemory).toList();
}

void main() {
  final now = DateTime(2026, 11, 28, 15, 0);
  const lang = ZoeLanguage.tagalog;

  RetrievalDoc note(int id, String title, String text) => RetrievalDoc(
        source: RetrievalSource.note,
        id: id,
        title: title,
        text: text,
        updatedAt: DateTime(2026, 11, 20),
      );

  final wifi = note(1, 'Wifi', 'ZoeHome / pass 1234');
  final shopping = note(2, 'Shopping list', 'itlog, gatas, tinapay');
  final bahay = note(3, 'Bahay', 'wifi sa bahay: zoe2026');

  late MemoryLearningStore store;

  ChatPreviewBrain brain([List<RetrievalDoc>? docs]) {
    store = MemoryLearningStore();
    final learning = RagLearning(store, clock: () => now);
    return ChatPreviewBrain(
      retriever: Retriever(
        repo: _FakeSearch(docs ?? [wifi, shopping]),
        clock: () => now,
        learning: learning,
      ),
      memoryOn: () async => true,
      classifier: _NoQwen(),
      mood: () => MoodState.content,
      onMoodEvent: (_) {},
      onTone: (_) {},
      weekNote: (_) async => null,
      clock: () => now,
      activeAlarms: () async => const {},
    );
  }

  Future<List<ChatEntry>> say(ChatPreviewBrain b, String text) => b.reply(text, lang);

  Future<AnswerEntry> ask(ChatPreviewBrain b, String text) async {
    final entries = await say(b, text);
    expect(entries.single, isA<AnswerEntry>(), reason: text);
    return entries.single as AnswerEntry;
  }

  test('pumalya → nag-rephrase ×2 → natutunan ang "net" = "wifi"', () async {
    final b = brain();

    // Round 1: "pw" lang ang tumama (pass) → hindi sigurado.
    final first = await ask(b, 'ano pw ng net ko?');
    expect(first.text, startsWith('Baka ito? 🤔'));
    final sure = await ask(b, 'ano wifi password ko?');
    expect(sure.text, startsWith('Ito ang nakita ko sa notes mo'));
    expect(store.terms[('net', 'wifi')]!.count, 1);

    // "ano net ko?" — hindi pa (isang beses pa lang).
    final notYet = await ask(b, 'ano net ko?');
    expect(notYet.rows, isEmpty);

    // Round 2 → aktibo na.
    await ask(b, 'ano pw ng net ko?');
    await ask(b, 'ano wifi password ko?');
    expect(store.terms[('net', 'wifi')]!.count, 2);

    final learned = await ask(b, 'ano net ko?');
    expect(learned.text, contains('1234'));
    expect(learned.rows.first.route, '/notes/edit/1');
  });

  test('bawat paghahanap ay naka-log; walang nahanap → "none"', () async {
    final b = brain();
    await ask(b, 'ano plate number ko?');
    expect(store.logs.single.outcome, SearchOutcome.none);
    expect(store.logs.single.question, contains('plate number'));
    expect(store.logs.single.hitCount, 0);
  });

  test('"oo" pagkatapos ng sagot → tama (feedback +, log confirmed)', () async {
    final b = brain();
    await ask(b, 'ano wifi password ko?');
    final yes = await say(b, 'oo');
    expect(ZoeLines.optionsFor(lang, ZoeSituation.ragConfirmed),
        contains((yes.single as TextEntry).text));
    expect(store.feedbackMap['note#1']!.good, 1);
    expect(store.logs.last.outcome, SearchOutcome.confirmed);
    expect(store.logs.last.docKey, 'note#1');
  });

  test('"hindi yan" → mali (feedback −, log rejected), tapos ang susunod', () async {
    final b = brain([wifi, bahay]);
    await ask(b, 'ano wifi password ko?');
    final next = await ask(b, 'hindi yan');
    expect(next.text, contains('zoe2026'));
    expect(store.feedbackMap['note#1']!.bad, 1);
    expect(store.logs.last.outcome, SearchOutcome.rejected);
    expect(store.logs.last.docKey, 'note#1');
  });

  test('"buksan mo" → tama (feedback +, log opened) + bubuksan pa rin', () async {
    final b = brain();
    await ask(b, 'ano wifi password ko?');
    await say(b, 'buksan mo');
    expect(b.takeOpen(), '/notes/edit/1');
    expect(store.feedbackMap['note#1']!.good, 1);
    expect(store.logs.last.outcome, SearchOutcome.opened);
  });

  test('"Clear chat" (resetSession) → hindi na matututo sa naunang pumalya', () async {
    final b = brain();
    await ask(b, 'ano pw ng net ko?');
    b.resetSession();
    await ask(b, 'ano wifi password ko?');
    expect(store.terms, isEmpty);
  });
}