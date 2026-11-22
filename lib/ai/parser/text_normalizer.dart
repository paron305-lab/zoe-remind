/// Text-speak at shortcut → buong salita, BAGO basahin ng rules.
///
///   "pls rmnd me 2mrw 8am"        → "please remind me tomorrow 8am"
///   "paremind nmn aq bkas 7am"    → "paremind naman ako bukas 7am"
///   "anu ganap ko 2day?"          → "ano ganap ko today?"
///   "ty" / "tnx" / "salamuch"     → "thank you" / "thanks" / "salamat"
///   "hellooo" / "salamaaat"       → "hello" / "salamat"
///
/// Pure function (walang database), kaya nate-test sa
/// `flutter test test/ai/text_normalizer_test.dart`.
///
/// Buong SALITA lang ang pinapalitan (hindi bahagi ng salita), at ang ibang
/// salita ay hindi ginagalaw — kaya "Mama" ay "Mama" pa rin sa title.
/// Sinadyang hindi kasama ang mga salitang may ibang kahulugan
/// ("tom" = Tom, "san" = San Juan, "bat" = bat, "r").
class TextNormalizer {
  TextNormalizer._();

  static final _word = RegExp(r"[A-Za-z0-9']+");

  /// "hellooo" → "hello", "salamaaat" → "salamat", "yesss" → "yes" (titik lang, hindi numero).
  static final _stretched = RegExp(r'([A-Za-z])\1{2,}');

  /// Maliit na titik → kapalit.
  static const _words = {
    // ── Tagalog text-speak
    'nmn': 'naman', 'nman': 'naman', 'lng': 'lang', 'nlng': 'na lang', 'nalng': 'na lang',
    'nlang': 'na lang', 'd2': 'dito', 'dto': 'dito', 'kc': 'kasi', 'ksi': 'kasi',
    'kse': 'kasi', 'aq': 'ako', 'q': 'ko', 'xa': 'siya', 'sya': 'siya', 'cya': 'siya',
    'pde': 'pwede', 'pwd': 'pwede', 'pwde': 'pwede', 'pede': 'pwede', 'bkas': 'bukas',
    'bks': 'bukas', 'bukaz': 'bukas', 'mya': 'mamaya', 'mmya': 'mamaya', 'mamya': 'mamaya',
    'pki': 'paki', 'pkiremind': 'paki remind', 'anu': 'ano', 'anung': 'anong', 'cnu': 'sino',
    'sno': 'sino', 'kelan': 'kailan', 'kln': 'kailan', 'pano': 'paano', 'ung': 'yung',
    'yng': 'yung', 'wla': 'wala', 'mron': 'meron', 'mern': 'meron', 'd': 'di', 'ndi': 'hindi',
    'hnd': 'hindi', 'hndi': 'hindi', 'hnde': 'hindi', 'nde': 'hindi', 'hwag': 'huwag',
    'bka': 'baka', 'sna': 'sana', 'tlga': 'talaga', 'tlg': 'talaga', 'mna': 'muna',
    'cguro': 'siguro', 'sguro': 'siguro', 'tpos': 'tapos', 'tps': 'tapos', 'ntapos': 'natapos',
    'gnwa': 'ginawa', 'gnawa': 'ginawa', 'ggwin': 'gagawin', 'gagwin': 'gagawin',
    'ngyn': 'ngayon', 'ngaun': 'ngayon', 'ngayn': 'ngayon', 'ngyon': 'ngayon',
    'nkalimutan': 'nakalimutan', 'nklimutan': 'nakalimutan', 'nmiss': 'namiss',
    'slmt': 'salamat', 'salamuch': 'salamat', 'slamat': 'salamat', 'tnx': 'thanks',
    'tnks': 'thanks', 'thx': 'thanks', 'thnx': 'thanks', 'ty': 'thank you',
    'tysm': 'thank you', 'tyvm': 'thank you',
    // ── English text-speak
    'pls': 'please', 'plz': 'please', 'plss': 'please', 'pleaze': 'please',
    'tmrw': 'tomorrow', 'tmr': 'tomorrow', 'tmrow': 'tomorrow', '2mrw': 'tomorrow',
    '2moro': 'tomorrow', '2morrow': 'tomorrow', 'tomoro': 'tomorrow', 'tommorow': 'tomorrow',
    '2day': 'today', '2dy': 'today', 'tdy': 'today', '2nyt': 'tonight', '2nite': 'tonight',
    'tonite': 'tonight', 'rmnd': 'remind', 'rmind': 'remind', 'remnd': 'remind',
    'rmdr': 'reminder', 'rmndr': 'reminder', 'u': 'you', 'ur': 'your', 'yr': 'your',
    'msg': 'message', 'appt': 'appointment', 'mtg': 'meeting', 'sked': 'sched',
    'gm': 'good morning', 'gn': 'good night', 'gnyt': 'good night', 'gud': 'good',
    'gd': 'good', 'k': 'ok', 'kk': 'ok', 'oki': 'ok', 'okie': 'ok', 'okey': 'okay',
    'nvm': 'never mind', 'idk': "i don't know",
  };

  /// Palitan ang mga shortcut. Ang ibang salita at bantas ay hindi ginagalaw.
  ///
  /// [forDisplay] = para sa title / memory na makikita ng user: hindi pinapalitan
  /// ang isang-letrang salita ("vitamin k" ay hindi magiging "vitamin ok",
  /// "plan b" / "grade d" ay hindi ginagalaw), at hindi pinapaikli ang
  /// pinahabang titik ("www.gov.ph" ay "www.gov.ph" pa rin).
  static String normalize(String text, {bool forDisplay = false}) =>
      (forDisplay ? text : text.replaceAllMapped(_stretched, (m) => m[1]!))
          .replaceAllMapped(_word, (m) {
        final w = m[0]!;
        if (forDisplay && w.length == 1) return w;
        return _words[w.toLowerCase()] ?? w;
      });
}