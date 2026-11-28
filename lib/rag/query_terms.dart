import 'package:zoe_remind/rag/stemmer.dart';

/// Isang salitang hahanapin + mga kapareho nito (synonyms).
/// Tumatama ang grupo kapag tumama ang KAHIT ISA sa [alts].
class TermGroup {
  const TermGroup(this.word, this.alts, {this.direct});

  /// Ang salita mula sa tanong (hal. "password").
  final String word;

  /// Kasama ang [word]. May space = magkasunod na salita ("wi fi").
  /// R1: kasama rin ang ugat, eksakto ("binili" → "=bili").
  final List<String> alts;

  /// R2: ilan sa unahan ng [alts] ang galing sa salita mismo (ang salita,
  /// walang tuldik, ugat). Ang kasunod ay synonyms. null = lahat.
  final int? direct;

  /// R2: ang mga alt na hindi synonym. Mas mabigat sa Retriever ang tumama
  /// sa mismong salita ("trabaho") kaysa sa synonym lang ("office").
  Iterable<String> get directAlts {
    final n = direct;
    return n == null || n >= alts.length ? alts : alts.take(n);
  }

  /// FTS4 MATCH expression: `password* OR passcode* OR pw`.
  String get matchExpr => alts.map(QueryTerms.ftsTerm).join(' OR ');

  /// [alts] na walang "=" (para sa LIKE fallback).
  List<String> get plainAlts => alts.map(QueryTerms.bare).toList();

  @override
  String toString() =>
      alts.length == 1 ? word : '$word(${alts.skip(1).map(QueryTerms.bare).join('|')})';
}

/// Ginagawang mga salitang hahanapin ang tanong ng user (EN / TL / Taglish).
///
/// Pure function (walang database), kaya nate-test sa
/// `flutter test test/rag/query_terms_test.dart`.
///
///   "ano wifi password ko?"           → wifi, password
///   "saan ko nilagay ang susi ng kotse?" → susi, kotse
///   "what's my locker code"           → locker, code
///   "kaarawan ni Niño?"               → kaarawan, niño (+ nino)
///   "saan ako bumili ng sapatos?"     → bumili (+ =bili, buy), sapatos   ← R1
///
/// R1 (Stemmer): bawat salita ay may dagdag na alt na UGAT, eksakto
/// ("=bili"). Ang note ay hinahanap din sa ugat ng mga salita nito
/// ([searchTokens] dito, column na search_stems sa DB), kaya tumatama ang
/// "bumili" sa "Binili ko…", ang "batteries" sa "battery", ang "pinaprint"
/// sa "Pina-print". Hindi hinahanap ang unlapi na hiwalay dahil sa gitling
/// ("nag" sa "nag-gas"), at ang salitang stopword ang ugat ("am" → be).
///
/// Paghati ng salita (B6): gaya ng FTS4 "unicode61" tokenizer —
/// maliit na titik, letra / numero lang (kahit ñ, é), hati sa bantas, space at
/// emoji ("Wi-Fi" → wi, fi). [tokens] ay tinatanggal din ang tuldik
/// ("Niño" → nino), gaya ng `remove_diacritics=1`.
///
/// Sa phone na "simple" tokenizer lang ang kaya, kasama pa rin sa [TermGroup.alts]
/// ang orihinal na salita ("niño"), kaya nahahanap pa rin.
class QueryTerms {
  QueryTerms._();

  /// Hanggang ilang salita lang ang hahanapin.
  static const maxTerms = 6;

  /// Salitang 4+ letra → prefix ("pass" sa "password", "code" sa "codes").
  /// Mas maikli → eksakto lang ("pin" ≠ "pinya", "gym" ≠ "gymnast").
  static const prefixMin = 4;

  /// Hindi letra / numero (kahit anong wika) → hati.
  static final _split = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  /// Tuldik → walang tuldik (Latin letters lang, gaya ng remove_diacritics=1).
  static const _folds = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'ç': 'c',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ñ': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ý': 'y', 'ÿ': 'y',
  };

  static final _foldable = RegExp('[${_folds.keys.join()}]');

  /// Maliit na titik + walang tuldik: "Niño" → "nino", "CAFÉ" → "cafe".
  static String fold(String text) {
    final lower = text.toLowerCase();
    if (!_foldable.hasMatch(lower)) return lower;
    return lower.replaceAllMapped(_foldable, (m) => _folds[m[0]!]!);
  }

  /// Mga salita sa text: maliit na titik, MAY tuldik pa ("niño").
  static List<String> rawTokens(String text) =>
      text.toLowerCase().split(_split).where((t) => t.isNotEmpty).toList();

  /// Mga salita sa text: maliit na titik, walang tuldik ("nino").
  /// Ito ang ginagamit sa paghahambing (Retriever, memory de-dupe).
  static List<String> tokens(String text) =>
      fold(text).split(_split).where((t) => t.isNotEmpty).toList();

  /// R1: [tokens] + ang ugat ng mga ito (para sa Retriever at LIKE fallback).
  ///   "Binili ko ang shoes" → binili, ko, ang, shoes, bili, shoe
  static List<String> searchTokens(String text) => Stemmer.withStems(tokens(text));

  /// R1: laman ng column na search_stems (DB v15) — mga ugat lang na iba sa
  /// salita, walang ulit. "Binili ko ang shoes" → "bili shoe".
  static String searchStems(String title, String content) =>
      Stemmer.stemText(tokens('$title $content'));

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
    // R1: ugat ng am / is / are / was / been (Stemmer) — "am" ≠ "6:15 AM"
    'be',
  };

  /// Mga magkakapareho (EN / TL / Taglish). Bawat salita sa isang grupo ay
  /// tumatama sa iba ("internet" → "wifi", "susi" → "keys", "bday" → "birthday").
  ///
  /// Mas murang alternatibo ito sa embeddings (B6): dagdagan lang dito kapag
  /// may tanong na hindi nahanap (Developer › 8. Search index › Hindi nahanap).
  ///
  /// "=" sa unahan = EKSAKTO lang, hindi prefix, para sa salitang simula ng
  /// ibang salita: "=mama" ≠ "mamaya", "=pass" ≠ "passport", "=home" ≠ "homework".
  /// Lahat ay maliit na titik at walang tuldik.
  static const _synonyms = <List<String>>[
    // Bahay / gamit
    ['wifi', 'wi fi', 'internet', 'router'],
    ['password', 'passcode', 'pw', 'pwd', '=pass'],
    ['code', 'pin'],
    ['susi', 'key', 'keys', 'yawi'],
    ['address', 'tirahan', 'adres'],
    ['bahay', 'house', '=home'],
    ['number', 'numero', 'num'],
    ['phone', 'cellphone', 'selpon', 'telepono', 'cp', 'mobile', 'cel'],
    ['email', 'e mail', 'gmail'],
    ['size', 'sukat'],
    ['recipe', 'resipe'],
    // Tao
    ['=mama', 'nanay', 'inay', 'mommy', 'mom', '=nay'],
    ['=papa', 'tatay', 'itay', 'daddy', 'dad', '=tay'],
    ['lola', 'grandma'],
    ['lolo', 'grandpa'],
    ['asawa', 'husband', 'wife', 'mister', 'misis'],
    ['anak', 'son', 'daughter', 'kid', 'kids'],
    ['name', 'pangalan'],
    ['birthday', 'bday', 'kaarawan', 'birthdate'],
    ['favorite', 'favourite', 'paborito', 'fave', 'fav'],
    // Kalusugan
    ['gamot', 'medicine', 'meds', 'medication'],
    ['doctor', 'doktor', 'dok', 'dr'],
    ['dentist', 'dentista'],
    ['hospital', 'ospital'],
    ['allergy', 'allergies', 'allergic'],
    // Pera / bayarin
    ['=bill', 'bills', 'bayarin', 'babayaran'],
    ['kuryente', 'meralco', 'electricity', 'electric'],
    ['tubig', 'water'],
    ['rent', 'renta', 'upa'],
    ['utang', 'debt', 'loan'],
    ['bank', 'bangko'],
    ['sweldo', 'sahod', 'salary', 'payday'],
    // Labas
    ['kotse', 'car', 'sasakyan', '=auto'],
    ['motor', 'motorsiklo', 'motorcycle'],
    ['plate', 'plaka'],
    ['=work', 'trabaho', 'office', 'opisina'],
    ['school', 'eskwela', 'paaralan', 'skul'],
    ['grocery', 'groceries', 'palengke', 'market'],
    ['meeting', 'miting'],
    ['passport', 'pasaporte'],
    ['license', 'licence', 'lisensya', 'lisensiya'],
    ['ticket', 'tiket'],
    // R1: ugat ng Tagalog na pandiwa ↔ English (Taglish). "=" = eksakto, para
    // "bili" ≠ "bilis", "laba" ≠ "labas". Tumatama sa banghay dahil sa
    // Stemmer: "binili" → bili ↔ "bought" → buy.
    ['=bili', 'buy', 'purchase'],
    ['=bayad', 'pay', 'payment'],
    ['=luto', 'cook'],
    ['=kain', 'eat'],
    ['=inom', 'drink'],
    ['=hiram', 'borrow'],
    ['=laba', 'laundry', 'wash'],
  ];

  /// "=mama" → "mama".
  static String bare(String alt) => alt.startsWith('=') ? alt.substring(1) : alt;

  /// Ang mga salitang hahanapin, walang ulit, hanggang [maxTerms].
  /// May tuldik ("niño") → kasama rin ang walang tuldik ("nino").
  /// Walang ulit sa UGAT din: "shoes shoe" → isang grupo lang.
  static List<TermGroup> parse(String question) {
    final seen = <String>{};
    final groups = <TermGroup>[];
    for (final w in rawTokens(question)) {
      final key = fold(w);
      if (key.length < 2 || stopWords.contains(key) || Stemmer.isBareAffix(key)) continue;
      final stem = Stemmer.stem(key);
      if (stopWords.contains(stem) || !seen.add(stem)) continue;
      final (alts, direct) = _altsFor(w, key, stem);
      groups.add(TermGroup(w, alts, direct: direct));
      if (groups.length == maxTerms) break;
    }
    return groups;
  }

  /// Ang synonym group na may [key], o null.
  static List<String>? _groupOf(String key) {
    for (final g in _synonyms) {
      if (g.any((w) => bare(w) == key)) return g;
    }
    return null;
  }

  /// Ang mga alt + kung ilan sa unahan ang galing sa salita mismo (R2).
  static (List<String>, int) _altsFor(String word, String key, String stem) {
    // Synonym ng salita mismo; kung wala, ng ugat ("medicines" → medicine → gamot).
    var gkey = key;
    var group = _groupOf(key);
    if (group == null && stem != key) {
      group = _groupOf(stem);
      if (group != null) gkey = stem;
    }
    // "mama" na nasa listahan bilang "=mama" → eksakto rin ang tinype.
    final exact = group?.contains('=$gkey') ?? false;
    String mark(String w) => exact ? '=$w' : w;
    final out = [mark(word), if (key != word) mark(key)];
    // R1: ang ugat, eksakto — tumatama sa ugat ng note ("Binili" → bili).
    if (stem != key && !out.any((a) => bare(a) == stem)) out.add('=$stem');
    final direct = out.length;
    if (group != null) {
      for (final w in group) {
        final b = bare(w);
        if (b == gkey || b == key || out.any((a) => bare(a) == b)) continue;
        out.add(w);
      }
    }
    return (out, direct);
  }

  /// Isang alt bilang FTS4 term: phrase → `"wi fi"`, 4+ letra → `code*`,
  /// "=mama" → `mama` (eksakto).
  static String ftsTerm(String alt) {
    if (alt.startsWith('=')) return bare(alt);
    if (alt.contains(' ')) return '"$alt"';
    return alt.length >= prefixMin ? '$alt*' : alt;
  }

  /// Tumatama ba ang [group] sa mga salita ng isang note / memory?
  /// [docTokens] = galing sa [tokens] (walang tuldik), o [searchTokens]
  /// para kasama ang ugat (R1).
  /// Parehong patakaran ng FTS4 (prefix kapag 4+ letra), para tugma ang
  /// score sa nakita ng database.
  static bool groupIn(TermGroup group, List<String> docTokens) => group.alts.any(
      (alt) => _altIn(fold(bare(alt)), docTokens, exact: alt.startsWith('=')));

  static bool _altIn(String alt, List<String> doc, {bool exact = false}) {
    final parts = alt.split(' ');
    if (parts.length == 1) {
      return doc.any((t) => exact ? t == alt : _tokenMatches(alt, t));
    }
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