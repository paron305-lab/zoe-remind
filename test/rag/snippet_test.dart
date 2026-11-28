import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/snippet.dart';

/// Takbuhin:  flutter test test/rag/snippet_test.dart
///
/// R3: ang linyang tumama lang, naka-bold ang mga salita ng tanong,
/// "Buong note →" ([Snippet.partial]) kapag may hindi ipinakita.
void main() {
  const checklist = 'Bahay checklist\n'
      'Ilaw sa garahe: palitan ang bumbilya bago mag-Pasko\n'
      'Susi ng kotse: nasa drawer sa kusina\n'
      'Gate password: 4455\n'
      'Tubig: tawagan si Mang Ben kapag tumutulo ulit ang gripo sa banyo\n'
      'Basura: Martes at Biyernes ng umaga';

  const passwords = 'Mga password sa bahay\n'
      'Netflix: ac@gmail.com\n'
      'Wi-Fi: ZoeHome\n'
      'pass: zoe2026\n'
      'Router admin: 192.168.1.1, user admin\n'
      'Gate code 4455, huwag ibigay sa iba\n'
      'CCTV app: Ezviz, account ni Papa';

  const paragraph =
      'Nag-grocery kami kahapon sa SM kasama si Mama at bumili ng maraming gulay para sa linggo. '
      'Binili ko ang sapatos sa SM Megamall, yung itim na Nike, size 9. '
      'Pagkatapos kumain kami sa Jollibee at umuwi ng alas-otso ng gabi kasi traffic sa EDSA.';

  const runOn = 'ang dami kong ginawa ngayong araw una nagising ako ng maaga tapos naglinis ng '
      'bahay tapos nagluto ng almusal tapos pumunta sa opisina para sa meeting tungkol sa '
      'budget ng susunod na taon at pagkatapos nun bumili ako ng bagong charger sa mall kasi '
      'sira na yung luma at umuwi na rin ako pagkatapos';

  const errands = 'Errands list for the week\n'
      '- Bought battery sa Ace Hardware, 4 pcs AA\n'
      '- Paid Meralco Nov 15\n'
      '- Returned library books\n'
      '- Picked up laundry at the shop near the church\n'
      '- Called the dentist for Saturday';

  group('maikling note → buo', () {
    test('buong note, naka-bold ang tumama, hindi partial', () {
      final s = Snippet.of('Wi-Fi password ng office ay zoe123', 'ano wifi password ko?');
      expect(s.text, 'Wi-Fi password ng office ay zoe123');
      expect(s.boldWords, ['Wi-Fi', 'password']); // "wi fi" = magkasunod na salita
      expect(s.bold, const [SnippetSpan(0, 5), SnippetSpan(6, 14)]);
      expect(s.partial, isFalse);
    });

    test('blangkong linya at espasyo sa dulo → tinatanggal', () {
      final s = Snippet.of('  Gamot ni Mama  \n\n  Losartan 50mg  ', 'gamot ni mama');
      expect(s.text, 'Gamot ni Mama\nLosartan 50mg');
      expect(s.boldWords, ['Gamot', 'Mama']);
      expect(s.partial, isFalse);
    });

    test('"pin" ay eksakto — hindi bold ang "pinya"', () {
      final s = Snippet.of('Bumili ng pinya. ATM pin 4321', 'pin ng atm');
      expect(s.boldWords, ['ATM', 'pin']);
    });

    test('walang laman → empty', () {
      expect(Snippet.of('   ', 'wifi').isEmpty, isTrue);
      expect(Snippet.of('', 'wifi').bold, isEmpty);
    });
  });

  group('mahabang note → linyang tumama lang', () {
    test('"saan ang susi ng kotse?" → isang linya, walang "…"', () {
      final s = Snippet.of(checklist, 'saan ang susi ng kotse?');
      expect(s.text, 'Susi ng kotse: nasa drawer sa kusina');
      expect(s.boldWords, ['Susi', 'kotse']);
      expect(s.partial, isTrue);
    });

    test('"gate password" → ang linya ng gate lang (mas kaunting linya)', () {
      final s = Snippet.of(checklist, 'gate password');
      expect(s.text, 'Gate password: 4455');
      expect(s.boldWords, ['Gate', 'password']);
    });

    test('magkatabing linya: "Wi-Fi" + "pass" (synonym) > heading na "password"', () {
      final s = Snippet.of(passwords, 'ano wifi password ko?');
      expect(s.text, 'Wi-Fi: ZoeHome\npass: zoe2026');
      expect(s.boldWords, ['Wi-Fi', 'pass']);
      expect(s.partial, isTrue);
    });

    test('R1 ugat: "bumili" ↔ "Binili" — pangungusap na tumama, "…" sa unahan', () {
      final s = Snippet.of(paragraph, 'saan ako bumili ng sapatos?');
      expect(s.text, '…Binili ko ang sapatos sa SM Megamall, yung itim na Nike, size 9.');
      expect(s.boldWords, ['Binili', 'sapatos']);
      expect(s.partial, isTrue);
    });

    test('English: "buy the batteries" ↔ "Bought battery"', () {
      final s = Snippet.of(errands, 'where did I buy the batteries?');
      expect(s.text, '- Bought battery sa Ace Hardware, 4 pcs AA');
      expect(s.boldWords, ['Bought', 'battery']);
    });

    test('isang mahabang pangungusap → hiniwa sa paligid ng tumama, buong salita', () {
      final s = Snippet.of(runOn, 'saan ako bumili ng charger?');
      expect(
        s.text,
        '…sa budget ng susunod na taon at pagkatapos nun bumili ako ng bagong charger sa mall '
        'kasi sira na yung luma at umuwi na rin ako pagkatapos',
      );
      expect(s.boldWords, ['bumili', 'charger']);
      expect(s.text.length, lessThanOrEqualTo(Snippet.maxChars + 2));
    });

    test('walang tumama sa text (hal. title lang) → simula ng note, walang bold', () {
      final s = Snippet.of(checklist, 'passport');
      expect(
        s.text,
        'Bahay checklist\n'
        'Ilaw sa garahe: palitan ang bumbilya bago mag-Pasko\n'
        'Susi ng kotse: nasa drawer sa kusina',
      );
      expect(s.bold, isEmpty);
      expect(s.partial, isTrue);
    });

    test('laging ≤ maxChars (+ "…") at bawat bold ay nasa loob ng text', () {
      for (final (text, q) in [
        (checklist, 'tubig gripo'),
        (passwords, 'cctv account ni papa'),
        (paragraph, 'jollibee'),
        (runOn, 'almusal'),
        (errands, 'dentist'),
        (runOn * 3, 'charger'),
      ]) {
        final s = Snippet.of(text, q);
        expect(s.text.length, lessThanOrEqualTo(Snippet.maxChars + 2), reason: q);
        expect(s.bold, isNotEmpty, reason: q);
        for (final b in s.bold) {
          expect(b.start, greaterThanOrEqualTo(0), reason: q);
          expect(b.end, lessThanOrEqualTo(s.text.length), reason: q);
        }
      }
    });
  });

  group('boldIn / shift', () {
    test('boldIn: walang terms → walang bold', () {
      expect(Snippet.boldIn('Wifi: ZoeHome', const []), isEmpty);
    });

    test('boldIn: prefix (4+ letra) "code" → "codes"', () {
      final terms = QueryTerms.parse('locker code');
      final spans = Snippet.boldIn('Locker codes: 1234', terms);
      expect(spans, const [SnippetSpan(0, 6), SnippetSpan(7, 12)]);
    });

    test('shift → nalilipat ang bold kapag isinama sa linya ni Zoe', () {
      final s = Snippet.of('Wi-Fi password ng office ay zoe123', 'wifi password');
      const prefix = 'Ito ang nakita ko sa notes mo: ';
      final moved = s.shift(prefix.length);
      final line = '$prefix${s.text}';
      expect([for (final b in moved.bold) line.substring(b.start, b.end)], ['Wi-Fi', 'password']);
      expect(identical(s.shift(0), s), isTrue);
    });
  });
}