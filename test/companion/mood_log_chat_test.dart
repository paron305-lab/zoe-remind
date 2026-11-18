import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/ai/parser/intent_classifier.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/features/chat/controllers/chat_preview_brain.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';
import 'package:zoe_remind/features/companion/controllers/zoe_lines.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';
import 'package:zoe_remind/features/companion/models/mood_week.dart';
import 'package:zoe_remind/features/companion/models/user_tone.dart';

/// Takbuhin:  flutter test test/companion/mood_log_chat_test.dart
///
/// Level 2 sa Chat: binibilang ang tone, at minsan sinasabi ni Zoe
/// "Mukhang busy ang linggo mo…". Walang database (fake mood log).

/// Hindi tinatawag si Qwen sa test.
class _NoQwen extends IntentClassifier {
  @override
  Future<void> warmUp() async {}

  @override
  Future<ZoeIntent?> classify(String text) async => null;
}

void main() {
  late List<UserTone> logged;
  late List<UserTone> asked;

  /// [vibe] = ang isasagot ng fake mood log (null = walang masasabi).
  ChatPreviewBrain brainWith({WeekVibe? vibe, bool fail = false}) {
    logged = [];
    asked = [];
    return ChatPreviewBrain(
      classifier: _NoQwen(),
      mood: () => MoodState.content,
      onMoodEvent: (_) {},
      onTone: logged.add,
      weekNote: (tone) async {
        asked.add(tone);
        if (fail) throw StateError('db error');
        return vibe;
      },
    );
  }

  String textOf(ChatEntry e) => (e as TextEntry).text;

  bool isLine(String text, ZoeLanguage lang, ZoeSituation s) =>
      ZoeLines.optionsFor(lang, s, MoodState.content).contains(text) ||
      ZoeLines.optionsFor(lang, s, MoodState.gentle).contains(text);

  group('Mood log — ano ang binibilang', () {
    test('"pagod na ako" → bilang ang tired', () async {
      await brainWith().reply('pagod na ako', ZoeLanguage.tagalog);
      expect(logged, [UserTone.tired]);
    });

    test('stressed + utos → bilang pa rin ang stressed', () async {
      await brainWith()
          .reply('stressed na ako, remind me bukas ng 8am mag-review', ZoeLanguage.tagalog);
      expect(logged, [UserTone.stressed]);
    });

    test('neutral na mensahe → walang binibilang', () async {
      await brainWith().reply('add task buy groceries on Saturday', ZoeLanguage.english);
      expect(logged, isEmpty);
    });

    test('"hindi ako pagod" → walang binibilang', () async {
      await brainWith().reply('hindi ako pagod', ZoeLanguage.tagalog);
      expect(logged, isEmpty);
    });

    test('crisis → HINDI binibilang at hindi tinatanong ang linggo', () async {
      await brainWith(vibe: WeekVibe.heavy)
          .reply('ayoko na mabuhay', ZoeLanguage.tagalog);
      expect(logged, isEmpty);
      expect(asked, isEmpty);
    });
  });

  group('Mood log — sinasabi ni Zoe tungkol sa linggo', () {
    test('walang vibe → feeling script lang (isang bubble)', () async {
      final reply = await brainWith().reply('pagod na ako', ZoeLanguage.tagalog);
      expect(reply, hasLength(1));
      expect(isLine(textOf(reply.single), ZoeLanguage.tagalog, ZoeSituation.feelingTired),
          isTrue);
    });

    test('busy na linggo + pagod → weekBusy muna, saka feelingTired', () async {
      final reply = await brainWith(vibe: WeekVibe.busy).reply('pagod na ako', ZoeLanguage.tagalog);
      expect(reply, hasLength(2));
      expect(isLine(textOf(reply.first), ZoeLanguage.tagalog, ZoeSituation.weekBusy), isTrue,
          reason: textOf(reply.first));
      expect(isLine(textOf(reply.last), ZoeLanguage.tagalog, ZoeSituation.feelingTired), isTrue);
      expect(asked, [UserTone.tired]);
    });

    test('heavy na linggo + malungkot → weekHeavy muna', () async {
      final reply =
          await brainWith(vibe: WeekVibe.heavy).reply('nalulungkot ako', ZoeLanguage.both);
      expect(isLine(textOf(reply.first), ZoeLanguage.both, ZoeSituation.weekHeavy), isTrue);
      expect(isLine(textOf(reply.last), ZoeLanguage.both, ZoeSituation.feelingSad), isTrue);
    });

    test('good na linggo + masaya → feelingHappy muna, saka weekGood', () async {
      final reply =
          await brainWith(vibe: WeekVibe.good).reply('yay! ang saya ko', ZoeLanguage.english);
      expect(reply, hasLength(2));
      expect(isLine(textOf(reply.first), ZoeLanguage.english, ZoeSituation.feelingHappy), isTrue);
      expect(isLine(textOf(reply.last), ZoeLanguage.english, ZoeSituation.weekGood), isTrue);
    });

    test('may utos → walang linya tungkol sa linggo (mabilis ang sagot)', () async {
      final reply = await brainWith(vibe: WeekVibe.busy)
          .reply('stressed na ako, remind me bukas ng 8am mag-review', ZoeLanguage.tagalog);
      expect(reply, hasLength(2));
      expect(isLine(textOf(reply.first), ZoeLanguage.tagalog, ZoeSituation.feelingAck), isTrue);
      expect(reply.last, isA<ConfirmEntry>());
      expect(asked, isEmpty);
    });

    test('pumalya ang database → feeling script pa rin, walang error', () async {
      final reply =
          await brainWith(vibe: WeekVibe.busy, fail: true).reply('pagod na ako', ZoeLanguage.tagalog);
      expect(reply, hasLength(1));
      expect(isLine(textOf(reply.single), ZoeLanguage.tagalog, ZoeSituation.feelingTired),
          isTrue);
    });
  });
}