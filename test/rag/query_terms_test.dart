import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/rag/query_terms.dart';

/// Takbuhin:  flutter test test/rag/query_terms_test.dart
///
/// B2: mga salitang hahanapin mula sa tanong (EN / TL / Taglish).
void main() {
  List<String> words(String q) => QueryTerms.parse(q).map((g) => g.word).toList();

  group('parse — tinatanggal ang "ano", "ko", "the"…', () {
    final cases = <String, List<String>>{
      'ano wifi password ko?': ['wifi', 'password'],
      "what's my wifi password?": ['wifi', 'password'],
      'saan ko nilagay ang susi ng kotse?': ['susi', 'kotse'],
      'ano yung locker code ko sa gym': ['locker', 'code', 'gym'],
      'Zoe, ano na nga yung plate number ko?': ['plate', 'number'],
      'do you remember my bday?': ['bday'],
      "ano'ng address ni tita?": ['address', 'tita'],
      'ano ano ano': [],
      '?': [],
    };
    cases.forEach((q, expected) {
      test('"$q" → $expected', () => expect(words(q), expected));
    });

    test('hanggang ${QueryTerms.maxTerms} salita lang, walang ulit', () {
      expect(words('isa dalawa tatlo apat lima anim pito walo isa'),
          ['isa', 'dalawa', 'tatlo', 'apat', 'lima', 'anim']);
    });
  });

  group('tokens — kapareho ng FTS4 simple tokenizer', () {
    test('"Wi-Fi" → wi, fi · maliit na titik · bantas = hati', () {
      expect(QueryTerms.tokens('Wi-Fi password: Zoe123!'), ['wi', 'fi', 'password', 'zoe123']);
    });
    test('ñ ay bahagi ng salita', () {
      expect(QueryTerms.tokens('Piñata ni Niño'), ['piñata', 'ni', 'niño']);
    });
  });

  group('synonyms at FTS expression', () {
    test('wifi → "wi fi" (phrase)', () {
      final g = QueryTerms.parse('wifi').single;
      expect(g.alts, ['wifi', 'wi fi']);
      expect(g.matchExpr, 'wifi* OR "wi fi"');
    });
    test('pin → code (at maikli = eksakto)', () {
      final g = QueryTerms.parse('pin ko').single;
      expect(g.matchExpr, 'pin OR code*');
    });
    test('bday → birthday, kaarawan', () {
      expect(QueryTerms.parse('bday').single.alts, ['bday', 'birthday', 'kaarawan']);
    });
  });

  group('groupIn — prefix lang kapag 4+ letra', () {
    bool hit(String q, String doc) =>
        QueryTerms.groupIn(QueryTerms.parse(q).single, QueryTerms.tokens(doc));

    test('"pin" ≠ "shopping", ≠ "pinya"', () {
      expect(hit('pin', 'Shopping list'), isFalse);
      expect(hit('pin', 'bumili ng pinya'), isFalse);
      expect(hit('pin', 'ATM pin: 0000'), isTrue);
    });
    test('"code" → "codes" (prefix)', () => expect(hit('code', 'door codes'), isTrue));
    test('"wifi" → "Wi-Fi" (phrase)', () => expect(hit('wifi', 'Wi-Fi ng office'), isTrue));
    test('"password" → "passcode" (synonym)', () => expect(hit('password', 'phone passcode 1234'), isTrue));
    test('"password" ≠ "passport"', () => expect(hit('password', 'passport number'), isFalse));
    test('"gym" ≠ "gymnast"', () => expect(hit('gym', 'gymnast'), isFalse));
  });
}