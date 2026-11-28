import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/rag/tl_stemmer.dart';

/// Takbuhin:  flutter test test/rag/tl_stemmer_test.dart
///
/// R1: Tagalog na stemmer — gitlapi, unlapi, ulit ng pantig, hulapi.
/// Pure Dart, walang database.
void main() {
  void expectStems(Map<String, String> cases) {
    cases.forEach((word, root) {
      test('"$word" → "$root"', () => expect(TlStemmer.stem(word), root));
    });
  }

  group('gitlapi -um- / -in-', () {
    expectStems({
      'bumili': 'bili',
      'binili': 'bili',
      'kumain': 'kain',
      'kinain': 'kain',
      'sumulat': 'sulat',
      'sinulat': 'sulat',
      'humiram': 'hiram',
      'hiniram': 'hiram',
      'ginawa': 'gawa',
      'kinuha': 'kuha',
      'dumating': 'dating',
      'gumising': 'gising',
    });
  });

  group('unlapi (nag-, mag-, na-, ma-, i-, ipa-, naka-…)', () {
    expectStems({
      'nagluto': 'luto',
      'nagbayad': 'bayad',
      'naglaba': 'laba',
      'maglinis': 'linis',
      'naiwan': 'iwan',
      'iniwan': 'iwan',
      'itinago': 'tago',
      'ibinayad': 'bayad',
      'isinulat': 'sulat',
      'nilagay': 'lagay',
      'inilagay': 'lagay',
      'nilinis': 'linis',
      'nakaparada': 'parada',
      'nagpakarga': 'karga',
      'nagpaluto': 'luto',
      'nanghiram': 'hiram',
      'matulog': 'tulog',
      'malaki': 'laki',
      'maliit': 'liit',
      'maganda': 'ganda',
      'magaling': 'galing', // ma + galing, hindi mag + aling
    });
  });

  group('dalawang unlapi (ulit ng dulo ng una)', () {
    expectStems({
      'nagpapaluto': 'luto',
      'ipapakain': 'kain',
      'ipapaayos': 'ayos',
      'nagkasakit': 'sakit',
      'nakakapagod': 'pagod',
    });
  });

  group('ulit ng pantig', () {
    expectStems({
      'bibili': 'bili',
      'kakain': 'kain',
      'susulat': 'sulat',
      'magluluto': 'luto',
      'nagluluto': 'luto',
      'maglalaba': 'laba',
      'magdidilig': 'dilig',
      'iinom': 'inom',
      'umiinom': 'inom',
      'pumapasok': 'pasok',
      'ilalagay': 'lagay',
      'lilinisin': 'linis',
    });
  });

  group('hulapi -an / -in / -han / -hin', () {
    expectStems({
      'kainin': 'kain',
      'kainan': 'kain',
      'diligan': 'dilig',
      'nadiligan': 'dilig',
      'labahan': 'laba',
      'hugasan': 'hugas',
      'tawagan': 'tawag',
      'sabihin': 'sabi',
      'linisin': 'linis', // "linis" ay hindi l-in-is
    });
  });

  group('pagbabago sa ugat bago ang hulapi', () {
    expectStems({
      // u → o
      'lutuin': 'luto',
      'lulutuin': 'luto',
      'tulungan': 'tulong',
      'hapunan': 'hapon',
      'upuan': 'upo',
      // r → d
      'nabayaran': 'bayad',
      'babayaran': 'bayad',
      'lakaran': 'lakad',
      // nawawalang patinig (bili + hin → bilhin)
      'bilhin': 'bili',
      'binilhan': 'bili',
      'nilabhan': 'laba',
    });
  });

  group('hindi regular', () {
    expectStems({
      'kunin': 'kuha',
      'kukunin': 'kuha',
      'gagawin': 'gawa',
      'inumin': 'inom',
      'darating': 'dating',
    });
  });

  group('Taglish na unlapi + English', () {
    expectStems({
      'pinaprint': 'print',
      'pinaorder': 'order',
      'inorder': 'order',
      'nagpagas': 'gas',
      'nagshopping': 'shopping', // EnStemmer pa ang gagawa ng "shop" (Stemmer)
      'nagcheck': 'check',
    });
  });

  group('ligtas — hindi ginagalaw', () {
    for (final w in [
      'mama', 'papa', 'nanay', 'tatay', 'bahay', 'kotse', 'ingat', 'manok', 'pancit',
      'payong', 'pagod', 'sapatos', 'bigas', 'linis', 'pulis', 'kanin', 'ulan', 'buwan',
      'maynilad', 'umaga', 'sinigang', 'tinapay', 'pangalan', 'kapatid', 'itlog',
      'pagkain', 'paborito', 'pahina', 'magkano', 'kain', 'bili', 'luto',
    ]) {
      test('"$w"', () => expect(TlStemmer.stem(w), w));
    }
  });

  group('hiram na salita — walang gitlapi / hulapi', () {
    // may c, f, j, q, v, x, z → hindi tinatanggal ang -in- / -an / -in
    for (final w in ['finish', 'vitamin', 'cabin', 'jasmin']) {
      test('"$w"', () => expect(TlStemmer.stem(w), w));
    }
  });

  test('bareAffixes: "nag" sa "nag-gas" ay hindi salita', () {
    for (final a in ['nag', 'mag', 'pag', 'naka', 'pina', 'nagpa', 'magpa', 'ipa', 'ma', 'ka']) {
      expect(TlStemmer.bareAffixes, contains(a), reason: a);
    }
    for (final w in ['gas', 'gym', 'bahay', 'na', 'sa']) {
      expect(TlStemmer.bareAffixes, isNot(contains(w)), reason: w);
    }
  });
}