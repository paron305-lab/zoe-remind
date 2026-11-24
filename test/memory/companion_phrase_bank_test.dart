import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/features/chat/controllers/chat_router.dart';
import 'package:zoe_remind/memory/companion_facts.dart';

import 'companion_phrase_bank_data.dart';

/// Takbuhin:  flutter test test/memory/companion_phrase_bank_test.dart
///
/// Level 3: ~3,200 paraan ng pagsabi ng nickname, style, stress help, wins at
/// routines (EN / Tagalog / Taglish / text-speak). Para sa bawat isa:
///   • CompanionFacts.read → tamang kind (at value: "AC", "diretso", "listen")
///   • ChatRouter → memory card (negative: HINDI memory card)
/// Ginagawa ang data ng `python3 tool/companion/gen_companion_phrases.py`.
void main() {
  companionBank.forEach((kind, phrases) {
    if (kind == 'negative') return;
    test('$kind (${phrases.length})', () {
      final wrong = <String>[];
      for (final (text, value) in phrases) {
        final r = CompanionFacts.read(text);
        if (r.kind.db != kind || (value != null && r.value != value)) {
          wrong.add('"$text" → ${r.kind.db} ${r.value ?? ''} (dapat $kind ${value ?? ''})');
          continue;
        }
        final route = ChatRouter.of(text).route;
        if (route != ZoeRoute.memory) wrong.add('"$text" → route $route (dapat memory)');
      }
      expect(wrong, isEmpty, reason: '${wrong.length} mali:\n${wrong.take(40).join('\n')}');
    });
  });

  test('negative — hindi memory card (${companionBank['negative']!.length})', () {
    final wrong = [
      for (final (text, _) in companionBank['negative']!)
        if (ChatRouter.of(text).route == ZoeRoute.memory) '"$text" → memory',
    ];
    expect(wrong, isEmpty, reason: wrong.join('\n'));
  });

  test('sapat ang dami (3k+)', () {
    final total = companionBank.values.fold<int>(0, (n, l) => n + l.length);
    expect(total, greaterThanOrEqualTo(3000));
  });
}