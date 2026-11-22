import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/ai/parser/text_normalizer.dart';

/// Takbuhin:  flutter test test/ai/text_normalizer_test.dart
void main() {
  test('text-speak → buong salita', () {
    final cases = {
      'pls rmnd me 2mrw 8am': 'please remind me tomorrow 8am',
      'paremind nmn aq bkas 7am': 'paremind naman ako bukas 7am',
      'anu ganap ko 2day?': 'ano ganap ko today?',
      'ty zoe': 'thank you zoe',
      'tnx po': 'thanks po',
      'salamuch': 'salamat',
      'pki remind aq mya': 'paki remind ako mamaya',
      'gm zoe': 'good morning zoe',
      'nvm': 'never mind',
      'ung susi q': 'yung susi ko',
    };
    cases.forEach((input, want) => expect(TextNormalizer.normalize(input), want, reason: input));
  });

  test('pinahabang titik → isa ("hellooo" → "hello"), pero hindi ang numero', () {
    expect(TextNormalizer.normalize('hellooo zoe'), 'hello zoe');
    expect(TextNormalizer.normalize('salamaaat'), 'salamat');
    expect(TextNormalizer.normalize('code ko 1000'), 'code ko 1000');
  });

  test('hindi ginagalaw ang ibang salita, malaking titik, at bantas', () {
    expect(TextNormalizer.normalize('Tawagan si Mama, 7pm!'), 'Tawagan si Mama, 7pm!');
    expect(TextNormalizer.normalize('call Tom at San Juan'), 'call Tom at San Juan');
    expect(TextNormalizer.normalize('wifi: zoe123'), 'wifi: zoe123');
  });

  test('forDisplay: hindi ginagalaw ang isang letra (title / memory)', () {
    expect(TextNormalizer.normalize('bumili ng vitamin k pls', forDisplay: true), 'bumili ng vitamin k please');
    expect(TextNormalizer.normalize('k', forDisplay: true), 'k');
    expect(TextNormalizer.normalize('k'), 'ok');
    expect(TextNormalizer.normalize('visit www.gov.ph', forDisplay: true), 'visit www.gov.ph');
  });

  test('buong salita lang ("pls" oo, "plsx" hindi)', () {
    expect(TextNormalizer.normalize('plsx'), 'plsx');
    expect(TextNormalizer.normalize('bkas-bkas'), 'bukas-bukas');
  });
}