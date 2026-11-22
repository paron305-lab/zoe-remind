import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/features/chat/controllers/chat_router.dart';
import 'package:zoe_remind/features/chat/controllers/context_replies.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';

import 'phrase_bank_data.dart';

/// Takbuhin:  flutter test test/ai/phrase_bank_test.dart
///
/// Libo-libong totoong paraan ng pagsasabi (English / Tagalog / Taglish /
/// text-speak / conyo) → tama ba ang pupuntahan ng Zoe Chat?
/// Walang phone, walang model, walang database — ChatRouter + ContextReplies lang.
///
/// Mahalaga: kapag HINDI malinaw na utos, "askKind" (magtatanong muna si Zoe),
/// hindi agad reminder / task card.
void main() {
  // Isang araw na hindi nagbabago (para sa "bukas", "sa Sabado").
  final now = DateTime(2026, 11, 22, 10, 0);

  group('Phrase bank → ChatRouter', () {
    routeBank.forEach((want, phrases) {
      test('$want (${phrases.length})', () {
        final wrong = <String>[];
        for (final p in phrases) {
          final r = ChatRouter.of(p);
          final got = r.route == ZoeRoute.askKind && r.memoryChip && want == 'askKindMemory'
              ? 'askKindMemory'
              : r.route.name;
          if (got != want) wrong.add('"$p" → $got');
        }
        expect(wrong, isEmpty, reason: '${wrong.length} mali:\n${wrong.join('\n')}');
      });
    });
  });

  group('Phrase bank → ContextReplies (pagkatapos ng card / tanong)', () {
    String meaning(String t) {
      if (ContextReplies.isCancel(t)) return 'cancel';
      if (ContextReplies.isYes(t)) return 'yes';
      if (ContextReplies.isCorrection(t, now: now)) return 'fix';
      return switch (ContextReplies.kindFromText(t)) {
        DraftKind.reminder => 'kindReminder',
        DraftKind.task => 'kindTask',
        DraftKind.note => 'kindNote',
        DraftKind.memory => 'kindMemory',
        null => 'none',
      };
    }

    contextBank.forEach((want, phrases) {
      test('$want (${phrases.length})', () {
        final wrong = [
          for (final p in phrases)
            if (meaning(p) != want) '"$p" → ${meaning(p)}',
        ];
        expect(wrong, isEmpty, reason: '${wrong.length} mali:\n${wrong.join('\n')}');
      });
    });
  });

  test('ang bug sa phone (Nov 21): memory + "remind" → tanong, hindi "What time?"', () {
    final r = ChatRouter.of('You have to remember everyday i love to remind about my happiness');
    expect(r.route, ZoeRoute.askKind);
    expect(r.memoryChip, isTrue);
  });
}