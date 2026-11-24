import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/ai/parser/small_talk.dart';
import 'package:zoe_remind/features/chat/controllers/chat_router.dart';

import 'small_talk_bank_data.dart';

/// Takbuhin:  flutter test test/ai/small_talk_test.dart
///
/// Small talk: ~3,000 paraan ng "wassup", "kumusta ka?", "sino ka?", "tao ka ba?",
/// "good night", "bye", "ang galing mo", "love you zoe", "bored ako".
///   • SmallTalkRules → tamang kind
///   • ChatRouter → greeting + talk
///   • negative (may utos / tanong / nararamdaman pa) → hindi small talk
/// Data: `python3 tool/companion/gen_small_talk_phrases.py`.
void main() {
  smallTalkBank.forEach((kind, phrases) {
    if (kind == 'negative') return;
    test('$kind (${phrases.length})', () {
      final wrong = <String>[];
      for (final text in phrases) {
        final talk = SmallTalkRules.read(ChatRouter.clean(text));
        if (talk?.name != kind) {
          wrong.add('"$text" → ${talk?.name} (dapat $kind)');
          continue;
        }
        final route = ChatRouter.of(text);
        if (route.route != ZoeRoute.greeting || route.talk?.name != kind) {
          wrong.add('"$text" → $route');
        }
      }
      expect(wrong, isEmpty, reason: '${wrong.length} mali:\n${wrong.take(40).join('\n')}');
    });
  });

  test('negative — hindi small talk (${smallTalkBank['negative']!.length})', () {
    final wrong = [
      for (final text in smallTalkBank['negative']!)
        if (ChatRouter.of(text).talk != null) '"$text" → ${ChatRouter.of(text)}',
    ];
    expect(wrong, isEmpty, reason: wrong.join('\n'));
  });

  test('may utos pagkatapos ng bati → utos pa rin', () {
    expect(ChatRouter.of('hello zoe remind me bukas 8am mag-review').route, ZoeRoute.reminder);
    expect(ChatRouter.of('kumusta ka? pagod na ako').route, ZoeRoute.feeling);
  });
}