import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/features/chat/controllers/context_replies.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';

/// Takbuhin:  flutter test test/chat/context_replies_test.dart
///
/// Maiikling sagot pagkatapos ng card ("ay wag na pala", "oo", "mali, 8pm pala")
/// at sagot sa "Reminder ba 'to, task, o note?" ("task na lang").
void main() {
  final now = DateTime(2026, 11, 22, 10, 0);

  test('cancel', () {
    for (final t in ['cancel', 'ay wag na pala', 'huwag na lang po', 'nvm', 'never mind!', 'scratch that',
      'wag mo na ituloy', 'no thanks', 'ay sorry wag na', 'ekis']) {
      expect(ContextReplies.isCancel(t), isTrue, reason: t);
    }
    // Mahabang pangungusap ay hindi "cancel".
    for (final t in ['hindi ko na kailangan ng reminder bukas para sa meeting', 'wala akong gagawin bukas',
      'ano ba yan']) {
      expect(ContextReplies.isCancel(t), isFalse, reason: t);
    }
  });

  test('oo / accept', () {
    for (final t in ['oo', 'opo', 'sige', 'yes pls', 'go', 'goods', 'save mo na', 'oo sige', '👍 sige', 'kk']) {
      expect(ContextReplies.isYes(t), isTrue, reason: t);
    }
    for (final t in ['oo nga pala, may meeting ako', 'sige pero bukas na lang mag-gym ako ng 7pm']) {
      expect(ContextReplies.isYes(t), isFalse, reason: t);
    }
  });

  test('pagtatama ng oras / araw', () {
    for (final t in ['mali, 8pm pala', '8pm na lang', 'gawin mong 7pm', 'bukas na lang', 'sa Sabado na lang',
      'make it 6pm', 'change it to friday', 'move it to tomorrow', '9am', 'mali yung oras, 3pm dapat']) {
      expect(ContextReplies.isCorrection(t, now: now), isTrue, reason: t);
    }
    for (final t in ['mali', 'sige', 'hindi ko na kailangan ng reminder bukas para sa meeting']) {
      expect(ContextReplies.isCorrection(t, now: now), isFalse, reason: t);
    }
  });

  test('sagot sa "reminder, task, o note?"', () {
    final cases = {
      'task': DraftKind.task,
      'task na lang po': DraftKind.task,
      'gawin mong task': DraftKind.task,
      'reminder please': DraftKind.reminder,
      'paalala': DraftKind.reminder,
      'alarm': DraftKind.reminder,
      'i-note mo na lang': DraftKind.note,
      'note': DraftKind.note,
      'tandaan mo lang': DraftKind.memory,
      'remember it': DraftKind.memory,
    };
    cases.forEach((t, want) => expect(ContextReplies.kindFromText(t), want, reason: t));
    // Dalawang uri o mahaba → hindi malinaw.
    expect(ContextReplies.kindFromText('reminder at task'), isNull);
    expect(ContextReplies.kindFromText('hindi ko alam kung reminder ba o ano ba talaga to'), isNull);
    expect(ContextReplies.kindFromText('sige'), isNull);
  });
}