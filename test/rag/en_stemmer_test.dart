import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/rag/en_stemmer.dart';

/// Takbuhin:  flutter test test/rag/en_stemmer_test.dart
///
/// R1: English na light stemmer — plural, -ing, -ed, hindi regular.
/// Pure Dart, walang database.
void main() {
  void expectStems(Map<String, String> cases) {
    cases.forEach((word, root) {
      test('"$word" → "$root"', () => expect(EnStemmer.stem(word), root));
    });
  }

  group('plural', () {
    expectStems({
      'batteries': 'battery',
      'policies': 'policy',
      'groceries': 'grocery',
      'shoes': 'shoe',
      'cases': 'case',
      'boxes': 'box',
      'watches': 'watch',
      'dishes': 'dish',
      'glasses': 'glass',
      'keys': 'key',
      'bills': 'bill',
      'eggs': 'egg',
      'flights': 'flight',
      'chargers': 'charger',
      'vitamins': 'vitamin',
      'medicines': 'medicine',
      'movies': 'movie',
    });
  });

  group('-ing', () {
    expectStems({
      'paying': 'pay',
      'shopping': 'shop',
      'running': 'run',
      'taking': 'take',
      'making': 'make',
      'coming': 'come',
      'parking': 'park',
      'watching': 'watch',
      'watering': 'water',
      'feeling': 'feel',
      'missing': 'miss',
      'studying': 'study',
    });
  });

  group('-ed', () {
    expectStems({
      'parked': 'park',
      'called': 'call',
      'ordered': 'order',
      'booked': 'book',
      'renewed': 'renew',
      'listed': 'list',
      'missed': 'miss',
      'stored': 'store',
      'saved': 'save',
      'liked': 'like',
      'planned': 'plan',
      'shopped': 'shop',
      'tried': 'try',
      'studied': 'study',
      'played': 'play',
    });
  });

  group('hindi regular', () {
    expectStems({
      'bought': 'buy',
      'paid': 'pay',
      'went': 'go',
      'gone': 'go',
      'eaten': 'eat',
      'kept': 'keep',
      'left': 'leave',
      'took': 'take',
      'made': 'make',
      'sent': 'send',
      'met': 'meet',
      'told': 'tell',
      'said': 'say',
      'brought': 'bring',
      'found': 'find',
      'lost': 'lose',
      'sold': 'sell',
      'wrote': 'write',
      'children': 'child',
      'am': 'be',
      'was': 'be',
      'did': 'do',
      'has': 'have',
      'used': 'use',
    });
  });

  group('hindi ginagalaw', () {
    for (final w in [
      // mukhang may hulapi pero wala
      'news', 'bus', 'glass', 'gas', 'tennis', 'series', 'boss', 'dress', 'always', 'this',
      'meeting', 'morning', 'evening', 'thing', 'nothing', 'ring', 'bring', 'need', 'speed',
      'hundred', 'red',
      // Tagalog na nagtatapos sa -s (hindi plural)
      'sapatos', 'bigas', 'linis', 'pulis', 'labas', 'alis',
      // "ate" = Ate Joy (Tagalog), hindi "eat"
      'ate',
      // maiikli
      'key', 'pay', 'go',
    ]) {
      test('"$w"', () => expect(EnStemmer.stem(w), w));
    }
  });
}