import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/ai/parser/intent_classifier.dart';
import 'package:zoe_remind/features/companion/controllers/tone_detector.dart';
import 'package:zoe_remind/features/companion/models/user_tone.dart';

/// Takbuhin:  flutter test test/ai/intent_check_test.dart
///
/// Bug (phone, 2026-11-18): "Hindi ako pagod", "Hindi na ako pagod" at
/// "Zoe ano kaya pwede gawin kapag tinatamad" → "What time?".
/// Sanhi: sinabi ni Qwen na create_reminder. Ngayon, code ang may huling
/// salita ([IntentClassifier.checkWithCode]), at nababasa na ang "tinatamad".
void main() {
  ZoeIntent? check(ZoeIntent intent, String text) =>
      IntentClassifier.checkWithCode(intent, text);

  group('Qwen create_reminder / create_task na WALANG palatandaan → unknown', () {
    for (final text in [
      'Hindi ako pagod',
      'Hindi na ako pagod',
      'Zoe ano kaya pwede gawin kapag tinatamad',
      'ang ganda ng panahon',
      'i miss my mom',
      'ano gagawin ko bukas?',
      'paano mag-focus sa pag-aaral',
    ]) {
      test('"$text"', () {
        expect(check(ZoeIntent.createReminder, text), ZoeIntent.unknown);
        expect(check(ZoeIntent.createTask, text), ZoeIntent.unknown);
      });
    }
  });

  group('Qwen create_reminder na MAY palatandaan → tanggap', () {
    for (final text in [
      'pakiabisuhan ako 8am bukas, inom ng gamot',
      'may meeting ako sa Biyernes 3pm',
      'pwede mo ba akong i-remind mamaya?',
      'gisingin mo ako 5:30',
      'inom ng tubig every 2 hours',
      'bayad ng kuryente sa Feb 12',
    ]) {
      test('"$text"', () {
        expect(check(ZoeIntent.createReminder, text), ZoeIntent.createReminder);
      });
    }
  });

  group('Qwen create_task na MAY palatandaan → tanggap', () {
    for (final text in [
      'bibili pa ako ng gatas sa Sabado',
      'kailangan kong magbayad ng kuryente',
      'tapusin ang thesis sa friday',
      'I need to call the bank',
    ]) {
      test('"$text"', () {
        expect(check(ZoeIntent.createTask, text), ZoeIntent.createTask);
      });
    }
  });

  test('ibang label ay hindi ginagalaw', () {
    for (final intent in [
      ZoeIntent.getToday,
      ZoeIntent.getMissed,
      ZoeIntent.createNote,
      ZoeIntent.greeting,
      ZoeIntent.unknown,
    ]) {
      expect(check(intent, 'Hindi ako pagod'), intent);
    }
    expect(IntentClassifier.checkWithCode(null, 'Hindi ako pagod'), isNull);
  });

  group('ToneDetector: "tinatamad" = mababa ang lakas (tired)', () {
    for (final text in [
      'tinatamad ako',
      'Zoe ano kaya pwede gawin kapag tinatamad',
      'nakakatamad mag-aral',
      'I feel so lazy today',
      'walang motivation ako',
    ]) {
      test('"$text"', () {
        expect(ToneDetector.detect(text).tone, UserTone.tired);
      });
    }

    test('"hindi ako tinatamad" → neutral', () {
      expect(ToneDetector.detect('hindi ako tinatamad').tone, UserTone.neutral);
    });
  });
}