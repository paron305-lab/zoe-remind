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

/// Takbuhin:  flutter test test/chat/memory_chat_test.dart
///
/// B5: "tandaan mo na mas gusto ko…" → memory card (hindi pa nase-save
/// hangga't walang Accept). Data → note pa rin. OFF → note card na lang.

/// Hindi tinatawag si Qwen sa test.
class _NoQwen extends IntentClassifier {
  @override
  Future<void> warmUp() async {}

  @override
  Future<ZoeIntent?> classify(String text) async => null;
}

/// Walang database: walang nahahanap.
class _NoSearch extends SearchRepository {
  @override
  Future<List<RetrievalDoc>> candidates(List<TermGroup> terms, {bool includeMemories = true}) async =>
      const [];
}

void main() {
  final now = DateTime(2026, 11, 21, 20, 0);
  const lang = ZoeLanguage.tagalog;

  ChatPreviewBrain brain({bool memoryOn = true}) => ChatPreviewBrain(
        retriever: Retriever(repo: _NoSearch()),
        memoryOn: () async => memoryOn,
        classifier: _NoQwen(),
        mood: () => MoodState.content,
        onMoodEvent: (_) {},
        onTone: (_) {},
        weekNote: (_) async => null,
        clock: () => now,
        activeAlarms: () async => const {},
      );

  test('"tandaan mo na mas gusto ko ng morning reminders" → memory card', () async {
    final reply = await brain().reply('Zoe, tandaan mo na mas gusto ko ng morning reminders', lang);
    final card = reply.single as ConfirmEntry;
    expect(card.kind, DraftKind.memory);
    expect(card.memory!.content, 'Mas gusto ko ng morning reminders');
    expect(card.isPending, isTrue);
  });

  test('"remember that I\'m vegetarian" (English) → memory card', () async {
    final reply = await brain().reply("remember that I'm vegetarian", ZoeLanguage.english);
    expect((reply.single as ConfirmEntry).memory!.content, "I'm vegetarian");
  });

  test('OFF ang long-term memory → paliwanag + note card', () async {
    final reply = await brain(memoryOn: false)
        .reply('tandaan mo na mas gusto ko ng morning reminders', lang);
    expect(reply, hasLength(2));
    expect(ZoeLines.optionsFor(lang, ZoeSituation.memoryOff, MoodState.content),
        contains((reply.first as TextEntry).text));
    final card = reply.last as ConfirmEntry;
    expect(card.kind, DraftKind.note);
    expect(card.note!.content, 'Mas gusto ko ng morning reminders');
  });

  test('data ("wifi password") → note card pa rin', () async {
    final reply =
        await brain().reply('tandaan mo, ang wifi password sa bahay ay zoe2026', lang);
    expect((reply.single as ConfirmEntry).kind, DraftKind.note);
  });

  test('"do you remember that I like coffee?" → tanong, hindi memory card', () async {
    final reply = await brain().reply('do you remember that I like coffee?', ZoeLanguage.english);
    expect(reply.whereType<ConfirmEntry>(), isEmpty);
  });

  test('may oras → reminder, hindi memory', () async {
    final reply = await brain().reply('tandaan mo, gisingin mo ako 6am', lang);
    expect((reply.single as ConfirmEntry).kind, DraftKind.reminder);
  });
}