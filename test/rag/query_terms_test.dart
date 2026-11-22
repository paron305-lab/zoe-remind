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

  group('tokens — kapareho ng FTS4 unicode61 tokenizer (B6)', () {
    test('"Wi-Fi" → wi, fi · maliit na titik · bantas = hati', () {
      expect(QueryTerms.tokens('Wi-Fi password: Zoe123!'), ['wi', 'fi', 'password', 'zoe123']);
    });
    test('tokens: walang tuldik ("Niño" → nino, "CAFÉ" → cafe)', () {
      expect(QueryTerms.tokens('Piñata ni NIÑO sa CAFÉ'), ['pinata', 'ni', 'nino', 'sa', 'cafe']);
    });
    test('rawTokens: may tuldik pa (para sa phone na "simple" lang)', () {
      expect(QueryTerms.rawTokens('Piñata ni NIÑO'), ['piñata', 'ni', 'niño']);
    });
    test('emoji = hati, hindi bahagi ng salita', () {
      expect(QueryTerms.tokens('pizza🍕party'), ['pizza', 'party']);
    });
  });

  group('tuldik (B6)', () {
    test('"niño" → alts niño + nino', () {
      final g = QueryTerms.parse('kaarawan ni Niño?').last;
      expect(g.word, 'niño');
      expect(g.alts, ['niño', 'nino']);
      expect(g.matchExpr, 'niño* OR nino*');
    });
    test('"nino" (walang tuldik) → tumatama sa note na "Niño"', () {
      final g = QueryTerms.parse('nino').single;
      expect(QueryTerms.groupIn(g, QueryTerms.tokens('Bday ni Niño')), isTrue);
    });
    test('"Niño" → tumatama sa note na "nino"', () {
      final g = QueryTerms.parse('Niño').single;
      expect(QueryTerms.groupIn(g, QueryTerms.tokens('bday ni nino')), isTrue);
    });
    test('pareho ang salita na may / walang tuldik → isang grupo lang', () {
      expect(QueryTerms.parse('niño nino').length, 1);
    });
  });

  group('synonyms at FTS expression', () {
    test('wifi → "wi fi" (phrase), internet, router', () {
      final g = QueryTerms.parse('wifi').single;
      expect(g.alts, ['wifi', 'wi fi', 'internet', 'router']);
      expect(g.matchExpr, 'wifi* OR "wi fi" OR internet* OR router*');
    });
    test('pin → code (at maikli = eksakto)', () {
      final g = QueryTerms.parse('pin ko').single;
      expect(g.matchExpr, 'pin OR code*');
    });
    test('bday → birthday, kaarawan, birthdate', () {
      expect(QueryTerms.parse('bday').single.alts, ['bday', 'birthday', 'kaarawan', 'birthdate']);
    });
  });

  group('B6 synonyms — mas murang alternatibo sa embeddings', () {
    bool hit(String q, String doc) => QueryTerms.parse(q)
        .any((g) => QueryTerms.groupIn(g, QueryTerms.tokens(doc)));

    final yes = <String, String>{
      'ano password ng internet?': 'wifi: zoe123',
      'nasaan ang susi?': 'nilagay ko sa drawer yung keys ng kotse',
      'ano gamot ni nanay?': 'Mama: losartan tuwing umaga',
      'kailan bayaran ang kuryente?': 'Meralco due every 15th',
      'saan ang dentista ko?': 'Dentist: Dr. Cruz, Makati',
      'magkano upa?': 'Rent: 8,000 kada buwan',
      'ano plaka ng sasakyan?': 'Car plate ABC 1234',
      'home address ko?': 'Bahay: 123 Rizal St.',
      'paborito kong kulay?': 'favorite color: pink',
      'email ni boss?': 'boss e-mail: boss@corp.ph',
      'ano wifi password?': 'Wifi: ZoeHome / pass 1234',
    };
    yes.forEach((q, doc) {
      test('"$q" → "$doc"', () => expect(hit(q, doc), isTrue));
    });

    final no = <String, String>{
      'ano gamot ni mama?': 'mamaya na lang ako bibili',
      'tawagan si papa': 'bumili ng papaya',
      'password ng wifi': 'passport number P1234',
      'home address': 'homework sa math',
      'work schedule': 'workout sa gym',
      'ano bill natin': 'billboard sa EDSA',
    };
    no.forEach((q, doc) {
      test('"$q" ≠ "$doc" (eksakto ang "=")', () {
        // tingnan lang ang salitang may "=" (mama, papa, pass, home, work, bill)
        final groups = QueryTerms.parse(q).where((g) => g.alts.any((a) => a.startsWith('=')));
        expect(groups, isNotEmpty);
        expect(groups.any((g) => QueryTerms.groupIn(g, QueryTerms.tokens(doc))), isFalse);
      });
    });

    test('"=mama" → eksakto sa FTS (walang *), plainAlts walang "="', () {
      final g = QueryTerms.parse('mama').single;
      expect(g.alts, ['=mama', 'nanay', 'inay', 'mommy', 'mom', '=nay']);
      expect(g.matchExpr, 'mama OR nanay* OR inay* OR mommy* OR mom OR nay');
      expect(g.plainAlts, ['mama', 'nanay', 'inay', 'mommy', 'mom', 'nay']);
    });

    test('"nanay" → kasama ang "=mama" (eksakto pa rin)', () {
      final g = QueryTerms.parse('nanay').single;
      expect(g.alts.first, 'nanay');
      expect(g.alts, contains('=mama'));
      expect(QueryTerms.groupIn(g, QueryTerms.tokens('mamaya')), isFalse);
      expect(QueryTerms.groupIn(g, QueryTerms.tokens('kay mama')), isTrue);
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