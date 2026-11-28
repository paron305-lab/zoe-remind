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
/// R2: sigurado → "Ito ang nakita ko…" · hindi sigurado → "Baka ito? 🤔".
/// R3: linyang tumama lang, naka-bold ang salita, "Buong note →" kapag mahaba.
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

  ChatPreviewBrain brain({bool memoryOn = true, List<RetrievalDoc>? docsIn}) => ChatPreviewBrain(
        retriever: Retriever(repo: _FakeSearch(docsIn ?? docs), clock: () => now),
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
    expect(a.text, startsWith('Ito ang nakita ko sa notes mo'));
    expect(a.text, contains('zoe123'));
    expect(a.rows.map((r) => r.label), ['Wifi · Nov 18', 'Bahay · Nov 2']);
    expect(a.rows.map((r) => r.tone).toSet(), {AnswerTone.note});
    expect(a.rows.first.route, '/notes/edit/1');
    // R3: maikli ang note → buo, naka-bold ang tumama, walang "Buong note →".
    expect(bolded(a), ['Wi-Fi', 'password']);
    expect(a.more, isNull);
  });

  test('memory ang sagot → "Galing sa sinabi mo sa akin"', () async {
    final a = await ask(brain(), 'ano gusto ko sa umaga?');
    expect(a.assumption, 'Galing sa sinabi mo sa akin');
    expect(a.text, contains('morning reminders'));
    // R2: "umaga" ay wala sa memory ("morning") → hindi sigurado.
    expect(a.text, startsWith('Baka ito? 🤔 Sinabi mo sa akin'));
    expect(a.rows.single.tone, AnswerTone.memory);
    expect(a.rows.single.route, isNull); // walang listahan ng memories
    expect(a.more, isNull);
  });

  test('OFF ang long-term memory → hindi binabasa ang memories', () async {
    final a = await ask(brain(memoryOn: false), 'ano gusto ko sa umaga?');
    expect(ZoeLines.optionsFor(lang, ZoeSituation.noteNotFound, MoodState.content), contains(a.text));
    expect(a.rows, isEmpty);
  });

  test('R2: may salitang wala sa notes ("cafe") → "Baka ito? 🤔" + parehong source', () async {
    final a = await ask(brain(), 'ano wifi password ko sa cafe?');
    expect(a.assumption, 'Galing sa notes mo');
    expect(a.text, startsWith('Baka ito? 🤔'));
    expect(a.text, contains('zoe123'));
    expect(a.rows.first.route, '/notes/edit/1');
  });

  test('R2: English → "Not sure, but is this it? 🤔"', () async {
    final entries = await brain().reply("what's my wifi password at the cafe?", ZoeLanguage.english);
    final a = entries.single as AnswerEntry;
    expect(a.assumption, 'From your notes');
    expect(a.text, startsWith('Not sure, but is this it? 🤔'));
    expect(a.text, contains('zoe123'));
  });

  test('walang nahanap → noteNotFound, walang iniimbento', () async {
    final a = await ask(brain(), 'ano plate number ko?');
    expect(a.assumption, 'Hinanap sa notes mo');
    expect(ZoeLines.optionsFor(lang, ZoeSituation.noteNotFound, MoodState.content), contains(a.text));
    expect(a.bold, isEmpty);
    expect(a.more, isNull);
  });

  // ── R3: snippet
  final checklist = RetrievalDoc(
    source: RetrievalSource.note,
    id: 4,
    title: 'Bahay checklist',
    text: 'Ilaw sa garahe: palitan ang bumbilya bago mag-Pasko\n'
        'Susi ng kotse: nasa drawer sa kusina\n'
        'Gate password: 4455\n'
        'Tubig: tawagan si Mang Ben kapag tumutulo ulit ang gripo sa banyo\n'
        'Basura: Martes at Biyernes ng umaga',
    updatedAt: DateTime(2026, 11, 20),
  );
  final errands = RetrievalDoc(
    source: RetrievalSource.note,
    id: 5,
    title: 'Errands',
    text: 'Errands list for the week\n'
        '- Bought battery sa Ace Hardware, 4 pcs AA\n'
        '- Paid Meralco Nov 15\n'
        '- Returned library books\n'
        '- Picked up laundry at the shop near the church\n'
        '- Called the dentist for Saturday',
    updatedAt: DateTime(2026, 11, 19),
  );

  test('R3: mahabang note → linyang tumama lang + bold + "Buong note →"', () async {
    final a = await ask(brain(docsIn: [checklist]), 'saan ko nilagay ang susi ng kotse?');
    expect(a.text, 'Ito ang nakita ko sa notes mo: Susi ng kotse: nasa drawer sa kusina');
    expect(a.text, isNot(contains('Basura')));
    expect(bolded(a), ['Susi', 'kotse']);
    expect(a.more?.label, 'Buong note →');
    expect(a.more?.route, '/notes/edit/4');
    expect(a.rows.single.route, '/notes/edit/4');
  });

  test('R3: English → "Full note →", bold sa banghay ("Bought battery")', () async {
    final entries =
        await brain(docsIn: [errands]).reply('where did I buy the batteries?', ZoeLanguage.english);
    final a = entries.single as AnswerEntry;
    expect(a.text, endsWith('- Bought battery sa Ace Hardware, 4 pcs AA'));
    expect(a.text, isNot(contains('Meralco')));
    expect(bolded(a), ['Bought', 'battery']);
    expect(a.more?.label, 'Full note →');
    expect(a.more?.route, '/notes/edit/5');
  });
}

/// Mga salitang naka-bold sa sagot (R3).
List<String> bolded(AnswerEntry a) => [for (final b in a.bold) a.text.substring(b.start, b.end)];