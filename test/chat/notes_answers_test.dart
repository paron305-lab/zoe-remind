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

/// Takbuhin:  flutter test test/chat/notes_answers_test.dart
///
/// B3: "ano wifi password ko?" → Retriever → sagot + mga source.
/// Walang database — fake SearchRepository.

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
  final now = DateTime(2026, 11, 21, 20, 0);
  const lang = ZoeLanguage.tagalog;

  final docs = [
    RetrievalDoc(
      source: RetrievalSource.note,
      id: 1,
      title: 'Wifi',
      text: 'Wi-Fi password ng office ay zoe123',
      updatedAt: DateTime(2026, 11, 18),
    ),
    RetrievalDoc(
      source: RetrievalSource.note,
      id: 3,
      title: 'Bahay',
      text: 'wifi sa bahay: zoe2026',
      updatedAt: DateTime(2026, 11, 2),
    ),
    RetrievalDoc(
      source: RetrievalSource.memory,
      id: 7,
      title: 'Mas gusto ko ng morning reminders',
      text: 'Mas gusto ko ng morning reminders',
      updatedAt: DateTime(2026, 11, 10),
    ),
  ];

  ChatPreviewBrain brain({bool memoryOn = true}) => ChatPreviewBrain(
        retriever: Retriever(repo: _FakeSearch(docs), clock: () => now),
        memoryOn: () async => memoryOn,
        classifier: _NoQwen(),
        mood: () => MoodState.content,
        onMoodEvent: (_) {},
        onTone: (_) {},
        weekNote: (_) async => null,
        clock: () => now,
        activeAlarms: () async => const {},
      );

  Future<AnswerEntry> ask(ChatPreviewBrain b, String text) async {
    final entries = await b.reply(text, lang);
    expect(entries.single, isA<AnswerEntry>(), reason: text);
    return entries.single as AnswerEntry;
  }

  test('"ano wifi password ko?" → note + "Galing sa notes mo" + mga source', () async {
    final a = await ask(brain(), 'ano wifi password ko?');
    expect(a.assumption, 'Galing sa notes mo');
    expect(a.text, contains('zoe123'));
    expect(a.rows.map((r) => r.label), ['Wifi · Nov 18', 'Bahay · Nov 2']);
    expect(a.rows.map((r) => r.tone).toSet(), {AnswerTone.note});
    expect(a.rows.first.route, '/notes/edit/1');
  });

  test('memory ang sagot → "Galing sa sinabi mo sa akin"', () async {
    final a = await ask(brain(), 'ano gusto ko sa umaga?');
    expect(a.assumption, 'Galing sa sinabi mo sa akin');
    expect(a.text, contains('morning reminders'));
    expect(a.rows.single.tone, AnswerTone.memory);
    expect(a.rows.single.route, '/settings/memories');
  });

  test('OFF ang long-term memory → hindi binabasa ang memories', () async {
    final a = await ask(brain(memoryOn: false), 'ano gusto ko sa umaga?');
    expect(ZoeLines.optionsFor(lang, ZoeSituation.noteNotFound, MoodState.content), contains(a.text));
    expect(a.rows, isEmpty);
  });

  test('walang nahanap → noteNotFound, walang iniimbento', () async {
    final a = await ask(brain(), 'ano plate number ko?');
    expect(a.assumption, 'Hinanap sa notes mo');
    expect(ZoeLines.optionsFor(lang, ZoeSituation.noteNotFound, MoodState.content), contains(a.text));
  });
}