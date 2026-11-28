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
/// R4: reminders + tasks — "May paalala ka: Dentist appointment — Dec 3, 3:00 PM",
/// naka-grupo ang mga source.
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

  // ── R4: reminders + tasks
  final dentistNote = RetrievalDoc(
    source: RetrievalSource.note,
    id: 1,
    title: 'Dentist',
    text: 'Dr. Santos 0917 555 1234',
    updatedAt: DateTime(2026, 11, 11),
  );
  final dentistReminder = RetrievalDoc(
    source: RetrievalSource.reminder,
    id: 5,
    title: 'Dentist appointment',
    text: '',
    date: '2026-12-03',
    time: '15:00',
    repeat: 'none',
    updatedAt: DateTime(2026, 11, 19),
  );
  final reportTask = RetrievalDoc(
    source: RetrievalSource.task,
    id: 9,
    title: 'Tapusin ang sales report',
    text: '',
    updatedAt: DateTime(2026, 11, 20),
  );
  final resumeDone = RetrievalDoc(
    source: RetrievalSource.task,
    id: 12,
    title: 'Fix my resume',
    text: '',
    date: '2026-11-16',
    done: true,
    updatedAt: DateTime(2026, 11, 16),
  );
  final gamotDaily = RetrievalDoc(
    source: RetrievalSource.reminder,
    id: 7,
    title: 'Uminom ng gamot',
    text: '',
    date: '2026-11-01',
    time: '08:00',
    repeat: 'daily',
    updatedAt: DateTime(2026, 11, 1),
  );

  test('R4: "may reminder ba ako tungkol sa dentist?" → reminder + kailan (hindi ang note)', () async {
    final a = await ask(brain(docsIn: [dentistNote, dentistReminder]),
        'may reminder ba ako tungkol sa dentist?');
    expect(a.assumption, 'Galing sa reminders mo');
    expect(a.text, 'May paalala ka: Dentist appointment — Dec 3, 3:00 PM');
    expect(bolded(a), ['Dentist']);
    expect(a.more, isNull);
    expect(a.rows.single.tone, AnswerTone.reminder);
    expect(a.rows.single.label, 'Dentist appointment · Dec 3');
    expect(a.rows.single.route, '/reminders/edit/5');
  });

  test('R4: "anong task ko sa sales report?" → task, walang petsa', () async {
    final a = await ask(brain(docsIn: [reportTask]), 'anong task ko sa sales report?');
    expect(a.assumption, 'Galing sa tasks mo');
    expect(a.text, 'May gawain ka: Tapusin ang sales report — walang petsa');
    expect(bolded(a), ['sales', 'report']);
    expect(a.rows.single.tone, AnswerTone.event);
    expect(a.rows.single.label, 'Tapusin ang sales report · walang petsa');
    expect(a.rows.single.route, '/tasks/edit/9');
  });

  test('R4: walang uri sa tanong → lahat, naka-grupo (⏰ reminder muna, saka 📝 note)', () async {
    final a = await ask(brain(docsIn: [dentistNote, dentistReminder]),
        'kailan ang dentist appointment ko?');
    expect(a.text, 'May paalala ka: Dentist appointment — Dec 3, 3:00 PM');
    expect(bolded(a), ['Dentist', 'appointment']);
    expect(a.rows.map((r) => r.tone), [AnswerTone.reminder, AnswerTone.note]);
    expect(a.rows.map((r) => r.label), ['Dentist appointment · Dec 3', 'Dentist · Nov 11']);
  });

  test('R4: English + tapos na na task → "You have a task: … — done ✓"', () async {
    final entries = await brain(docsIn: [resumeDone])
        .reply('is there a task for my resume?', ZoeLanguage.english);
    final a = entries.single as AnswerEntry;
    expect(a.assumption, 'From your tasks');
    expect(a.text, 'You have a task: Fix my resume — done ✓');
    expect(bolded(a), ['resume']);
    expect(a.rows.single.tone, AnswerTone.done);
    expect(a.rows.single.label, 'Fix my resume · done ✓');
  });

  test('R4: araw-araw na reminder → "araw-araw, 8:00 AM"', () async {
    final a = await ask(brain(docsIn: [gamotDaily]), 'may alarm ba ako para sa gamot?');
    expect(a.text, 'May paalala ka: Uminom ng gamot — araw-araw, 8:00 AM');
    expect(a.rows.single.label, 'Uminom ng gamot · araw-araw');
    expect(a.rows.single.route, '/reminders/edit/7');
  });

  test('R4: walang reminder tungkol doon → notes pa rin, "Baka ito? 🤔"', () async {
    final a = await ask(brain(docsIn: docs.take(2).toList()), 'may reminder ba ako tungkol sa wifi?');
    expect(a.assumption, 'Galing sa notes mo');
    expect(a.text, startsWith('Baka ito? 🤔'));
    expect(a.text, contains('zoe123'));
    expect(a.rows.map((r) => r.tone).toSet(), {AnswerTone.note});
  });
}

/// Mga salitang naka-bold sa sagot (R3).
List<String> bolded(AnswerEntry a) => [for (final b in a.bold) a.text.substring(b.start, b.end)];