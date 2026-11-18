import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/ai/parser/intent_classifier.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/features/chat/controllers/chat_preview_brain.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';
import 'package:zoe_remind/features/companion/controllers/mood_now.dart';
import 'package:zoe_remind/features/companion/controllers/zoe_lines.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';
import 'package:zoe_remind/features/companion/models/user_tone.dart';

/// Takbuhin:  flutter test test/companion/chat_mood_test.dart
///
/// 2c: tone ng user → script + mood event; mood ni Zoe → ibang salita.
/// Walang database, walang Qwen (fake classifier), walang phone.

/// Hindi tinatawag si Qwen sa test.
class _NoQwen extends IntentClassifier {
  @override
  Future<void> warmUp() async {}

  @override
  Future<ZoeIntent?> classify(String text) async => null;
}

void main() {
  late List<ZoeEvent> events;

  ChatPreviewBrain brainWith([MoodState mood = MoodState.content]) {
    events = [];
    return ChatPreviewBrain(
      classifier: _NoQwen(),
      mood: () => mood,
      onMoodEvent: events.add,
    );
  }

  String textOf(ChatEntry e) => (e as TextEntry).text;

  bool isLine(String text, ZoeLanguage lang, ZoeSituation s,
          [MoodState mood = MoodState.content]) =>
      ZoeLines.optionsFor(lang, s, mood).contains(text);

  group('Chat — sagot ayon sa nararamdaman ng user', () {
    test('"pagod na ako" → feelingTired + UserFeelsDown (gentle si Zoe)', () async {
      final reply = await brainWith().reply('pagod na ako', ZoeLanguage.tagalog);
      expect(reply, hasLength(1));
      expect(isLine(textOf(reply.single), ZoeLanguage.tagalog, ZoeSituation.feelingTired),
          isTrue, reason: textOf(reply.single));
      expect(events.single, isA<UserFeelsDown>());
    });

    test('"I\'m so tired" sa English', () async {
      final reply = await brainWith().reply("I'm so tired", ZoeLanguage.english);
      expect(isLine(textOf(reply.single), ZoeLanguage.english, ZoeSituation.feelingTired),
          isTrue);
    });

    test('"hi zoe, stressed na ako" → feelingStressed, hindi bati', () async {
      final reply = await brainWith().reply('hi zoe, stressed na ako', ZoeLanguage.both);
      final text = textOf(reply.single);
      expect(isLine(text, ZoeLanguage.both, ZoeSituation.feelingStressed), isTrue,
          reason: text);
      expect(events.single, isA<UserFeelsDown>());
    });

    test('stressed + utos → "isa-isa lang tayo" + reminder card', () async {
      final reply = await brainWith()
          .reply('stressed na ako, remind me bukas ng 8am mag-review', ZoeLanguage.tagalog);
      expect(reply, hasLength(2));
      expect(isLine(textOf(reply.first), ZoeLanguage.tagalog, ZoeSituation.feelingAck),
          isTrue);
      expect(reply.last, isA<ConfirmEntry>());
      expect(events.single, isA<UserFeelsDown>());
    });

    test('"yay! ang saya ko" → feelingHappy + UserPositive', () async {
      final reply = await brainWith().reply('yay! ang saya ko', ZoeLanguage.both);
      expect(isLine(textOf(reply.single), ZoeLanguage.both, ZoeSituation.feelingHappy),
          isTrue);
      expect(events.single, isA<UserPositive>());
    });

    test('"nahihirapan ako" (hindi alam ng ToneDetector) → comfort + gentle', () async {
      final reply = await brainWith().reply('nahihirapan ako', ZoeLanguage.tagalog);
      expect(isLine(textOf(reply.single), ZoeLanguage.tagalog, ZoeSituation.comfort),
          isTrue);
      expect(events.single, isA<UserFeelsDown>());
    });

    test('"hindi ako pagod" → walang malasakit, walang mood event', () async {
      final reply = await brainWith().reply('hindi ako pagod', ZoeLanguage.tagalog);
      final text = textOf(reply.single);
      expect(isLine(text, ZoeLanguage.tagalog, ZoeSituation.comfort), isFalse, reason: text);
      expect(isLine(text, ZoeLanguage.tagalog, ZoeSituation.feelingTired), isFalse, reason: text);
      expect(events, isEmpty);
    });

    test('walang "AI: …" sa footnote ng hindi-naintindihan', () async {
      final reply = await brainWith().reply('ang ganda ng panahon', ZoeLanguage.both);
      final entry = reply.single as TextEntry;
      expect(entry.footnote, isNot(contains('AI:')));
    });

    test('"salamat, ang galing mo" → pasasalamat, isang event lang', () async {
      final reply = await brainWith().reply('salamat, ang galing mo', ZoeLanguage.tagalog);
      expect(isLine(textOf(reply.single), ZoeLanguage.tagalog, ZoeSituation.thanks), isTrue);
      expect(events, hasLength(1));
      expect(events.single, isA<UserPositive>());
    });

    test('crisis → hotline lang, walang mood event', () async {
      final reply = await brainWith().reply('gusto ko na mamatay', ZoeLanguage.tagalog);
      expect(textOf(reply.single), contains('1553'));
      expect(events, isEmpty);
    });

    test('"happy" sa tanong ay hindi binibilang', () {
      expect(ChatPreviewBrain.toneOf('nice ba yung movie?'), UserTone.neutral);
      expect(ChatPreviewBrain.toneOf('nice!'), UserTone.happy);
      expect(ChatPreviewBrain.toneOf('pagod na ba ako?'), UserTone.tired);
    });
  });

  group('Chat — salita ayon sa mood ni Zoe', () {
    test('gentle + "hello" → malambing na bati', () async {
      final reply = await brainWith(MoodState.gentle).reply('hello', ZoeLanguage.tagalog);
      final text = textOf(reply.single);
      expect(isLine(text, ZoeLanguage.tagalog, ZoeSituation.greeting, MoodState.gentle),
          isTrue, reason: text);
      expect(events, isEmpty);
    });

    test('sorry + "hi" → "Pasensya kanina…"', () async {
      final reply = await brainWith(MoodState.sorry).reply('hi', ZoeLanguage.tagalog);
      expect(textOf(reply.single), contains('Pasensya kanina'));
    });

    test('content + "hi" → karaniwang bati', () async {
      final reply = await brainWith().reply('hi', ZoeLanguage.english);
      expect(isLine(textOf(reply.single), ZoeLanguage.english, ZoeSituation.greeting),
          isTrue);
    });
  });

  group('MoodNow — mood na gagamitin sa salita', () {
    final noon = DateTime(2026, 11, 18, 12);

    test('happy 3 oras na ang nakaraan → content na', () {
      final m = ZoeMood(
        state: MoodState.happy,
        intensity: 1,
        since: noon.subtract(const Duration(hours: 3)),
      );
      expect(MoodNow.of(m, noon), MoodState.content);
    });

    test('gentle kanina lang → gentle pa rin', () {
      final m = ZoeMood(
        state: MoodState.gentle,
        intensity: 2,
        since: noon.subtract(const Duration(minutes: 20)),
      );
      expect(MoodNow.of(m, noon), MoodState.gentle);
    });

    test('focused (nag-iisip) → ang mood bago mag-isip', () {
      final before = ZoeMood(state: MoodState.happy, intensity: 1, since: noon);
      final m = ZoeMood(
        state: MoodState.focused,
        intensity: 1,
        since: noon,
        previous: before,
      );
      expect(MoodNow.of(m, noon.add(const Duration(seconds: 30))), MoodState.happy);
    });

    test('content sa 23:30 → sleepy', () {
      final m = ZoeMood(state: MoodState.content, since: noon);
      expect(MoodNow.of(m, DateTime(2026, 11, 18, 23, 30)), MoodState.sleepy);
    });
  });
}