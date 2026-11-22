import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/ai/parser/intent_classifier.dart';

/// Takbuhin:  flutter test test/ai/zoe_label_test.dart
///
/// B6: ang label ni Qwen para sa malabong tanong. Code ang nagsasala:
/// salitang wala sa mensahe → tapon; saklaw na wala sa allowlist → tapon.
void main() {
  ZoeLabel label(String raw, String message) =>
      ZoeLabel.from(IntentClassifier.parse(raw)!, raw, message);

  group('search_notes → mga salita (galing lang sa mensahe)', () {
    test('"gamot, mama" — nasa mensahe pareho', () {
      final l = label('search_notes | gamot, mama',
          'yung sinabi ko last time tungkol sa gamot ni mama');
      expect(l.intent, ZoeIntent.searchNotes);
      expect(l.words, ['gamot', 'mama']);
      expect(l.range, isNull);
    });

    test('inimbentong salita ("medicine", "losartan") → tapon', () {
      final l = label('search_notes | medicine, losartan, mama',
          'yung tungkol sa gamot ni mama');
      expect(l.words, ['mama']);
    });

    test('lahat inimbento → walang salita (hahanapin ang buong tanong)', () {
      expect(label('search_notes | passport', 'yung binigay ko dati').words, isEmpty);
    });

    test('stopword ("ko", "the") at ulit → tapon', () {
      final l = label('search_notes | ko, plate, plate, the, number',
          'yung plate number na binigay ko dati?');
      expect(l.words, ['plate', 'number']);
    });

    test('simula ng salita, 4+ letra ("passw" ↔ "password") → ok', () {
      expect(label('search_notes | password', 'yung passwords ng wifi').words, ['password']);
    });

    test('maikling salita, hindi eksakto ("pi" vs "pin") → tapon', () {
      expect(label('search_notes | pi', 'yung pin ng atm').words, isEmpty);
    });

    test('tuldik: "nino" ↔ "Niño"', () {
      expect(label('search_notes | nino', 'yung bday ni Niño').words, ['nino']);
    });

    test('hanggang ${ZoeLabel.maxWords} salita', () {
      final l = label('search_notes | isa dalawa tatlo apat lima',
          'isa dalawa tatlo apat lima');
      expect(l.words, hasLength(ZoeLabel.maxWords));
    });

    test('walang "|" → walang salita', () {
      expect(label('search_notes', 'yung plate number').words, isEmpty);
    });

    test('ibang format ("search_notes: plate") → ok pa rin', () {
      expect(label('search_notes: plate', 'yung plate number').words, ['plate']);
    });

    test('pangalawang linya ay hindi binabasa', () {
      expect(label('search_notes | plate\nnumber', 'yung plate number').words, ['plate']);
    });
  });

  group('get_missed / get_done / get_today → saklaw (allowlist)', () {
    test('"last 3 days" + may binanggit na panahon', () {
      final l = label('get_missed | last 3 days',
          'may naiwan ba akong hindi nagawa these past few days?');
      expect(l.intent, ZoeIntent.getMissed);
      expect(l.range, 'last 3 days');
    });

    test('"day before yesterday" (hindi "yesterday")', () {
      expect(label('get_done | day before yesterday', 'ano nagawa ko nung isang araw').range,
          'day before yesterday');
    });

    test('walang binanggit na panahon → walang saklaw (hindi hula)', () {
      expect(label('get_missed | yesterday', 'may naiwan ba akong hindi nagawa?').range, isNull);
    });

    test('wala sa allowlist ("last 2 years") → walang saklaw', () {
      expect(label('get_done | last 2 years', 'ano natapos ko these past years?').range, isNull);
    });

    test('get_today | this week', () {
      expect(label('get_today | this week', 'anong lakad ko this week?').range, 'this week');
    });

    test('search_notes ay walang saklaw; get_missed ay walang salita', () {
      expect(label('search_notes | yesterday', 'yung sinabi ko yesterday').range, isNull);
      expect(label('get_missed | bayarin', 'yung bayarin nung isang araw').words, isEmpty);
    });
  });

  group('ibang label', () {
    test('create_task | … → walang detalye', () {
      final l = label('create_task | gatas', 'bibili pa ako ng gatas');
      expect(l.intent, ZoeIntent.createTask);
      expect(l.words, isEmpty);
      expect(l.range, isNull);
    });

    test('toString para sa Developer', () {
      expect('${label('search_notes | gamot, mama', 'gamot ni mama')}', 'search_notes | gamot, mama');
      expect('${label('greeting', 'nandito ka ba')}', 'greeting');
    });
  });
}