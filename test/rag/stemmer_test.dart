import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/retriever.dart';
import 'package:zoe_remind/rag/stemmer.dart';

/// Takbuhin:  flutter test test/rag/stemmer_test.dart
///
/// R1: buong Stemmer (Tagalog → English), QueryTerms na may ugat, at
/// Retriever na tumatama sa banghay. Pure Dart, walang database.
void main() {
  group('Stemmer.stem — Tagalog, English, Taglish', () {
    final cases = <String, String>{
      // Tagalog
      'binili': 'bili', 'bumili': 'bili', 'bibili': 'bili', 'nadiligan': 'dilig',
      'lulutuin': 'luto', 'nabayaran': 'bayad', 'kinain': 'kain',
      // English
      'batteries': 'battery', 'bought': 'buy', 'paid': 'pay', 'shopping': 'shop',
      'parked': 'park', 'flights': 'flight', 'am': 'be',
      // Taglish: tanggal muna ang Tagalog na panlapi, saka English
      'pinaprint': 'print', 'nagshopping': 'shop', 'nagpagas': 'gas', 'inorder': 'order',
      'nasave': 'save', 'pinafix': 'fix',
    };
    cases.forEach((w, root) {
      test('"$w" → "$root"', () => expect(Stemmer.stem(w), root));
    });

    test('Tagalog na -ing ay hindi English na -ing', () {
      for (final w in ['galing', 'magaling', 'dating', 'huling', 'tuwing', 'gising']) {
        expect(Stemmer.stem(w), isNot(endsWith('e')), reason: w);
      }
      expect(Stemmer.stem('magaling'), 'galing');
      expect(Stemmer.stem('tuwing'), 'tuwing');
    });

    test('hindi dapat magkamali: mama, bus, news, glass', () {
      for (final w in ['mama', 'bus', 'news', 'glass', 'nanay', 'bahay', 'kotse', 'ate']) {
        expect(Stemmer.stem(w), w, reason: w);
      }
    });

    test('may numero → hindi ginagalaw', () {
      expect(Stemmer.stem('zoe2026'), 'zoe2026');
      expect(Stemmer.stem('5kg'), '5kg');
    });

    test('withStems / stemText', () {
      expect(Stemmer.withStems(['binili', 'ko', 'shoes']), ['binili', 'ko', 'shoes', 'bili', 'shoe']);
      expect(Stemmer.withStems(['wifi', 'ko']), ['wifi', 'ko']);
      expect(QueryTerms.searchStems('Sapatos', 'Binili ko ang shoes, binili rin ang medyas'),
          'bili shoe');
      expect(QueryTerms.searchStems('Wifi', 'password: zoe2026'), '');
    });
  });

  group('QueryTerms.parse — may ugat', () {
    test('"bumili" → =bili + buy (Taglish na ugat)', () {
      final g = QueryTerms.parse('saan ako bumili ng sapatos?').first;
      expect(g.word, 'bumili');
      expect(g.alts, containsAll(['=bili', 'buy']));
      expect(g.matchExpr, contains('bili'));
      expect(g.matchExpr, isNot(contains('bili*'))); // eksakto: "bili" ≠ "bilis"
    });

    test('"batteries" → =battery', () {
      final g = QueryTerms.parse('where did I buy the batteries?').last;
      expect(g.alts, ['batteries', '=battery']);
    });

    test('"medicines" → synonym ng ugat (gamot)', () {
      final g = QueryTerms.parse('medicines').single;
      expect(g.alts, containsAll(['=medicine', 'gamot']));
    });

    test('"nag" sa "nag-gas" ay hindi hinahanap', () {
      expect(QueryTerms.parse('kailan ako nag-gas?').map((g) => g.word), ['gas']);
      expect(QueryTerms.parse('nagpa-print ako ng resume').map((g) => g.word), ['print', 'resume']);
    });

    test('"am" (ugat: be) ay stopword — hindi na tumatama sa "6:15 AM"', () {
      expect(QueryTerms.parse('what movies am I watching?').map((g) => g.word),
          ['movies', 'watching']);
    });

    test('walang ulit sa ugat: "shoes shoe" → isa', () {
      expect(QueryTerms.parse('shoes shoe').length, 1);
    });

    test('groupIn + searchTokens: tumatama sa banghay ng note', () {
      bool hit(String q, String doc) => QueryTerms.parse(q)
          .any((g) => QueryTerms.groupIn(g, QueryTerms.searchTokens(doc)));
      expect(hit('bumili', 'Binili ko ang sapatos'), isTrue);
      expect(hit('magdidilig', 'Diligan ang halaman'), isTrue);
      expect(hit('pinaprint', 'Pina-print ko ang resume'), isTrue);
      expect(hit('bumili', 'Bilisan mo'), isFalse); // "bili" ≠ "bilis"
      expect(hit('naglaba', 'nasa labas ako'), isFalse); // "laba" ≠ "labas"
      expect(hit('gamot ni mama', 'mamaya na lang'), isFalse);
    });
  });

  group('Retriever — acceptance ng R1 (plano 3a)', () {
    final now = DateTime(2026, 11, 28, 9, 0);
    var nextId = 0;
    RetrievalDoc note(String title, String text) => RetrievalDoc(
          source: RetrievalSource.note,
          id: ++nextId,
          title: title,
          text: text,
          updatedAt: now.subtract(const Duration(days: 60)),
        );

    final docs = [
      note('Sapatos', 'Binili ko ang sapatos sa SM'),
      note('Ace', 'Bought battery sa Ace'),
      note('Grocery list Sabado', 'itlog, gatas, bigas'),
      note('Meralco', 'Paid Meralco Nov 15'),
      note('TV', 'remote batteries AAA'),
      note('Gym', 'Nag-gy-gym tuwing Lunes'),
      note('Upa', 'Bayad sa upa tuwing ika-5'),
      note('Flight', 'Cebu Pacific Dec 20, 6:15 AM'),
      note('Movies', 'Dune, Inside Out 3'),
    ];

    String? top(String q) {
      final hits = Retriever.rank(QueryTerms.parse(q), docs, now: now);
      return hits.isEmpty ? null : hits.first.doc.title;
    }

    final expected = <String, String>{
      'saan ako bumili ng sapatos?': 'Sapatos',
      'where did I buy the batteries?': 'Ace',
      'kailan ako nag-grocery?': 'Grocery list Sabado',
      'na-pay ko na ba yung meralco?': 'Meralco',
      'kailan ako nag-gym?': 'Gym',
      'magkano ang ibinayad ko sa upa?': 'Upa',
      'what movies am I watching?': 'Movies',
    };
    expected.forEach((q, title) {
      test('"$q" → $title', () => expect(top(q), title));
    });

    test('walang tamang note → walang sagot', () {
      expect(top('ano ang paborito kong pelikula?'), isNull);
    });
  });
}