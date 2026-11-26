import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/memory/memory_recall.dart';

/// Takbuhin:  flutter test test/memory/memory_recall_test.dart
///
/// Memory Recall: naaalala ni Zoe ang sinabi mo kapag may kinalaman sa
/// sinasabi mo ngayon (code lang, walang Qwen).
void main() {
  const memories = [
    'Tawagin akong AC',
    'Allergic ako sa hipon',
    'Hindi ako kumakain ng baboy',
    'Paborito ko ang sinigang',
  ];

  group('factOf — anong klaseng memory', () {
    test('allergy → avoid + mga kapareho (hipon = shrimp)', () {
      final f = MemoryRecall.factOf('Allergic ako sa hipon')!;
      expect(f.kind, RecallKind.avoid);
      expect(f.keywords, containsAll(['hipon', 'shrimp', 'sugpo']));
    });
    test('"I\'m allergic to peanuts" → mani din', () {
      final f = MemoryRecall.factOf("I'm allergic to peanuts")!;
      expect(f.keywords, containsAll(['peanuts', 'mani']));
    });
    test('"Allergic ako sa hipon kasi namamaga ako" → hipon lang', () {
      final f = MemoryRecall.factOf('Allergic ako sa hipon kasi namamaga ako')!;
      expect(f.keywords.contains('namamaga'), isFalse);
    });
    test('hindi kumakain → avoid', () {
      final f = MemoryRecall.factOf('Hindi ako kumakain ng baboy')!;
      expect(f.kind, RecallKind.avoid);
      expect(f.keywords, containsAll(['baboy', 'pork', 'lechon']));
    });
    test('vegetarian → avoid (karne)', () {
      final f = MemoryRecall.factOf('Vegetarian ako')!;
      expect(f.keywords, containsAll(['manok', 'chicken', 'lechon']));
    });
    test('paborito → favorite (ang mismong sinabi lang)', () {
      final f = MemoryRecall.factOf('Paborito ko ang sinigang')!;
      expect(f.kind, RecallKind.favorite);
      expect(f.keywords, {'sinigang'});
      expect(MemoryRecall.factOf('Paborito kong kulay ay purple')!.keywords, {'purple'});
    });
    test('iba → null', () {
      expect(MemoryRecall.factOf('Tawagin akong AC'), isNull);
      expect(MemoryRecall.factOf('Mas gusto ko ng morning reminders'), isNull);
    });
  });

  group('check — may kinalaman ba sa sinasabi ngayon', () {
    test('"parang ang sarap kumain ng hipon" → paalala (allergy)', () {
      final hit = MemoryRecall.check('parang ang sarap kumain ng hipon', memories)!;
      expect(hit.known, isFalse);
      expect(hit.fact.memory, 'Allergic ako sa hipon');
    });
    test('English: "craving shrimp tonight" → paalala', () {
      expect(MemoryRecall.check('craving shrimps tonight', memories)?.fact.memory,
          'Allergic ako sa hipon');
    });
    test('"lechon tayo!" → hindi kumakain ng baboy', () {
      expect(MemoryRecall.check('lechon tayo!', memories)?.fact.memory, 'Hindi ako kumakain ng baboy');
    });
    test('"di ba sinabi ko allergic ako sa hipon?" → alam na (known)', () {
      final hit = MemoryRecall.check('di ba sinabi ko allergic ako sa hipon?', memories)!;
      expect(hit.known, isTrue);
    });
    test('"nagluto si mama ng sinigang" → paborito', () {
      expect(MemoryRecall.check('nagluto si mama ng sinigang', memories)?.fact.kind,
          RecallKind.favorite);
    });
    test('umiiwas na → walang paalala', () {
      expect(MemoryRecall.check('hindi ako kakain ng hipon', memories), isNull);
      expect(MemoryRecall.check('iiwas ako sa shrimp', memories), isNull);
    });
    test('walang kinalaman → null', () {
      expect(MemoryRecall.check('ang ganda ng panahon', memories), isNull);
      expect(MemoryRecall.check('pagod na ako', memories), isNull);
    });
    test('"baka" (maybe) ≠ beef', () {
      expect(MemoryRecall.check('baka umulan mamaya', ['Hindi ako kumakain ng baka']), isNull);
      expect(MemoryRecall.check('sarap ng steak', ['Hindi ako kumakain ng baka']), isNotNull);
    });
    test('hipon ≠ pusit; seafood = hipon at pusit', () {
      expect(MemoryRecall.check('sarap ng pusit', memories), isNull);
      expect(MemoryRecall.check('sarap ng pusit', ['Allergic ako sa seafood']), isNotNull);
    });
    test('walang memory → null', () {
      expect(MemoryRecall.check('ang sarap ng hipon', const []), isNull);
    });
  });

  group('toYou — ang memory, sinabi kay user', () {
    final cases = {
      'Allergic ako sa hipon': 'allergic ka sa hipon',
      'Hindi ako kumakain ng baboy': 'hindi ka kumakain ng baboy',
      'Paborito ko ang sinigang': 'paborito mo ang sinigang',
      "I'm allergic to shrimp": "you're allergic to shrimp",
      "I don't eat pork": "you don't eat pork",
      'My favorite color is purple': 'your favorite color is purple',
    };
    cases.forEach((input, want) {
      test('"$input" → "$want"', () => expect(MemoryRecall.toYou(input), want));
    });
  });

  test('lineFor — may laman ang linya (walang naiwang {fact})', () {
    final hit = MemoryRecall.check('ang sarap ng hipon', memories)!;
    for (final lang in ZoeLanguage.values) {
      final line = MemoryRecall.lineFor(hit, lang);
      expect(line.contains('{fact}'), isFalse);
      expect(line.contains('hipon'), isTrue);
    }
    expect(MemoryRecall.knownLine('Allergic ako sa hipon', ZoeLanguage.both),
        contains('allergic ka sa hipon'));
  });
}