/// Isang salitang hahanapin + mga kapareho nito (synonyms).
/// Tumatama ang grupo kapag tumama ang KAHIT ISA sa [alts].
class TermGroup {
  const TermGroup(this.word, this.alts);

  /// Ang salita mula sa tanong (hal. "password").
  final String word;

  /// Kasama ang [word]. May space = magkasunod na salita ("wi fi").
  final List<String> alts;

  /// FTS4 MATCH expression: `password* OR passcode* OR pw`.
  String get matchExpr => alts.map(QueryTerms.ftsTerm).join(' OR ');

  @override
  String toString() => alts.length == 1 ? word : '$word(${alts.skip(1).join('|')})';
}

/// Ginagawang mga salitang hahanapin ang tanong ng user (EN / TL / Taglish).
///
/// Pure function (walang database), kaya nate-test sa
/// `flutter test test/rag/query_terms_test.dart`.
///
///   "ano wifi password ko?"           → wifi, password
///   "saan ko nilagay ang susi ng kotse?" → susi, kotse
///   "what's my locker code"           → locker, code
///
/// Pareho ang paghati ng salita dito at sa FTS4 "simple" tokenizer ng SQLite:
/// maliit na titik, hati sa bantas at space ("Wi-Fi" → wi, fi).
class QueryTerms {
  QueryTerms._();

  /// Hanggang ilang salita lang ang hahanapin.
  static const maxTerms = 6;

  /// Salitang 4+ letra → prefix ("pass" sa "password", "code" sa "codes").
  /// Mas maikli → eksakto lang ("pin" ≠ "pinya", "gym" ≠ "gymnast").
  static const prefixMin = 4;

  /// Hindi letra / numero (ASCII) → hati. Ang non-ASCII (ñ, emoji) ay bahagi
  /// ng salita, gaya ng FTS4 simple tokenizer.
  static final _split = RegExp(r'[^a-z0-9\u0080-\uffff]+');

  /// Mga salita sa text, maliit na titik.
  static List<String> tokens(String text) =>
      text.toLowerCase().split(_split).where((t) => t.isNotEmpty).toList();

  /// Mga salitang hindi nakakatulong sa paghahanap ("ano", "ko", "the"…).
  /// Ginagamit din ng chat brain at ng memory de-dupe.
  static const stopWords = {
    // Tagalog / Taglish
    'ano', 'anong', 'ang', 'ng', 'nang', 'mga', 'ko', 'kong', 'mo', 'mong', 'ako', 'akong',
    'akin', 'aking', 'yung', 'iyong', 'ung', 'yong', 'ba', 'sa', 'ay', 'na', 'nga', 'ulit',
    'po', 'saan', 'nasaan', 'kailan', 'sino', 'zoe', 'ni', 'kay', 'si', 'para', 'at', 'o',
    'ito', 'yan', 'iyan', 'yun', 'iyon', 'dito', 'doon', 'lang', 'lamang', 'naman', 'din',
    'rin', 'daw', 'raw', 'kasi', 'eh', 'ha', 'pa', 'may', 'meron', 'mayroon', 'wala',
    'nilagay', 'inilagay', 'sinabi', 'paki', 'pakisabi', 'naaalala', 'naalala',
    'natatandaan', 'tanda', 'tandaan', 'alam', 'hanapin', 'hanap', 'pwede', 'puwede',
    'sabihin', 'ipakita', 'nung', 'noong', 'nakaraan', 'pala', 'diba', 'di',
    // English
    'what', 'whats', 'is', 'are', 'was', 'were', 'the', 'my', 'a', 'an', 'of', 'where',
    'when', 'who', 'do', 'does', 'did', 'you', 'your', 'i', 'me', 'about', 'note', 'notes',
    'remember', 'told', 'again', 'please', 'still', 'to', 'in', 'on', 'for', 'with', 'it',
    'this', 'that', 'and', 'or', 'can', 'could', 'tell', 'show', 'find', 'search', 'know',
    'saved', 'save', 'put', 'kept', 'keep', 'have', 'had', 'there', 's',
  };

  /// Maliit na listahan ng magkakapareho. Bawat salita sa isang grupo ay
  /// tumatama sa iba ("bday" → "birthday", "wifi" → "Wi-Fi").
  static const _synonyms = <List<String>>[
    ['wifi', 'wi fi'],
    ['password', 'passcode', 'pw', 'pwd'],
    ['birthday', 'bday', 'kaarawan'],
    ['address', 'tirahan', 'adres'],
    ['number', 'numero', 'num'],
    ['phone', 'cellphone', 'selpon', 'telepono', 'cp'],
    ['susi', 'key', 'keys'],
    ['code', 'pin'],
    ['gamot', 'medicine', 'meds'],
  ];

  /// Ang mga salitang hahanapin, walang ulit, hanggang [maxTerms].
  static List<TermGroup> parse(String question) {
    final seen = <String>{};
    final groups = <TermGroup>[];
    for (final w in tokens(question)) {
      if (w.length < 2 || stopWords.contains(w) || !seen.add(w)) continue;
      groups.add(TermGroup(w, _altsFor(w)));
      if (groups.length == maxTerms) break;
    }
    return groups;
  }

  static List<String> _altsFor(String word) {
    for (final group in _synonyms) {
      if (group.contains(word)) return [word, ...group.where((w) => w != word)];
    }
    return [word];
  }

  /// Isang alt bilang FTS4 term: phrase → `"wi fi"`, 4+ letra → `code*`.
  static String ftsTerm(String alt) {
    if (alt.contains(' ')) return '"$alt"';
    return alt.length >= prefixMin ? '$alt*' : alt;
  }

  /// Tumatama ba ang [group] sa mga salita ng isang note / memory?
  /// Parehong patakaran ng FTS4 (prefix kapag 4+ letra), para tugma ang
  /// score sa nakita ng database.
  static bool groupIn(TermGroup group, List<String> docTokens) =>
      group.alts.any((alt) => _altIn(alt, docTokens));

  static bool _altIn(String alt, List<String> doc) {
    final parts = alt.split(' ');
    if (parts.length == 1) return doc.any((t) => _tokenMatches(alt, t));
    for (var i = 0; i + parts.length <= doc.length; i++) {
      var all = true;
      for (var j = 0; j < parts.length; j++) {
        if (doc[i + j] != parts[j]) {
          all = false;
          break;
        }
      }
      if (all) return true;
    }
    return false;
  }

  static bool _tokenMatches(String term, String token) =>
      term.length >= prefixMin ? token.startsWith(term) : token == term;
}