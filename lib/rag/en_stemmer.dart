/// R1 — English na "light stemmer" (hindi buong Porter).
///
///   batteries → battery · shoes → shoe · boxes → box · glasses → glass
///   paying → pay · shopping → shop · taking → take · parked → park
///   stored → store · tried → try · bought → buy · paid → pay · went → go
///
/// Para sa search lang: hindi binabago ang note mismo, at ang orihinal na
/// salita ay laging hinahanap pa rin. Kaya OK lang kung minsan ay hindi
/// "tunay" na salita ang ugat (hal. "hule") — ang mahalaga ay PAREHO ang
/// ugat sa tanong at sa note.
///
/// Ligtas sa Tagalog: hindi ginagalaw ang -as / -os / -is / -us
/// ("bigas", "sapatos", "linis", "bus"), at ang -ing na Tagalog
/// ("galing", "dating") ay nasa [TlStemmer.nativeIng].
///
/// Input: maliit na titik, walang tuldik (galing sa QueryTerms.tokens).
class EnStemmer {
  EnStemmer._();

  /// Hindi regular → ugat. Sinasadyang WALA ang "ate" (Ate Joy), "sang",
  /// "man" / "men" — mga salitang Tagalog din.
  static const irregular = <String, String>{
    // be / do / have — "be" ay stopword, kaya "am" sa "what movies am I…"
    // ay hindi na tumatama sa "6:15 AM".
    'am': 'be', 'is': 'be', 'are': 'be', 'was': 'be', 'were': 'be', 'been': 'be', 'being': 'be',
    'did': 'do', 'does': 'do', 'doing': 'do', 'done': 'do',
    'has': 'have', 'had': 'have', 'having': 'have',
    // pandiwa
    'bought': 'buy', 'brought': 'bring', 'paid': 'pay', 'went': 'go', 'gone': 'go',
    'going': 'go', 'goes': 'go', 'eaten': 'eat', 'eating': 'eat', 'kept': 'keep',
    'left': 'leave', 'took': 'take', 'taken': 'take', 'gave': 'give', 'given': 'give',
    'made': 'make', 'sent': 'send', 'met': 'meet', 'told': 'tell', 'said': 'say',
    'found': 'find', 'lost': 'lose', 'sold': 'sell', 'wrote': 'write', 'written': 'write',
    'got': 'get', 'gotten': 'get', 'saw': 'see', 'seen': 'see', 'came': 'come', 'ran': 'run',
    'sat': 'sit', 'stood': 'stand', 'spent': 'spend', 'built': 'build', 'felt': 'feel',
    'held': 'hold', 'heard': 'hear', 'knew': 'know', 'known': 'know', 'meant': 'mean',
    'slept': 'sleep', 'thought': 'think', 'taught': 'teach', 'caught': 'catch',
    'fought': 'fight', 'drove': 'drive', 'driven': 'drive', 'rode': 'ride', 'ridden': 'ride',
    'flew': 'fly', 'flown': 'fly', 'drank': 'drink', 'drunk': 'drink', 'began': 'begin',
    'begun': 'begin', 'broke': 'break', 'broken': 'break', 'chose': 'choose',
    'chosen': 'choose', 'forgot': 'forget', 'forgotten': 'forget', 'wore': 'wear',
    'worn': 'wear', 'woke': 'wake', 'woken': 'wake', 'swam': 'swim', 'threw': 'throw',
    'thrown': 'throw', 'grew': 'grow', 'grown': 'grow', 'fell': 'fall', 'fallen': 'fall',
    'hid': 'hide', 'hidden': 'hide', 'led': 'lead', 'lent': 'lend', 'laid': 'lay',
    'shot': 'shoot', 'understood': 'understand', 'won': 'win', 'fed': 'feed', 'dug': 'dig',
    'stuck': 'stick', 'spoke': 'speak', 'spoken': 'speak', 'stole': 'steal',
    'stolen': 'steal', 'blew': 'blow', 'blown': 'blow', 'drew': 'draw', 'drawn': 'draw',
    'froze': 'freeze', 'frozen': 'freeze', 'shook': 'shake', 'paying': 'pay',
    'using': 'use', 'used': 'use', 'died': 'die', 'dying': 'die', 'lying': 'lie',
    'tied': 'tie', 'lied': 'lie', 'bitten': 'bite', 'hung': 'hang', 'sought': 'seek',
    'borne': 'bear', 'forgave': 'forgive', 'forgiven': 'forgive', 'mistook': 'mistake',
    'withdrew': 'withdraw', 'overslept': 'oversleep', 'rang': 'ring', 'rung': 'ring',
    // pangngalan
    'children': 'child', 'women': 'woman', 'feet': 'foot', 'teeth': 'tooth',
    'mice': 'mouse', 'wives': 'wife', 'knives': 'knife', 'lives': 'life', 'people': 'person',
    'movies': 'movie', 'cookies': 'cookie', 'calories': 'calorie', 'selfies': 'selfie',
    'hoodies': 'hoodie', 'brownies': 'brownie', 'zombies': 'zombie', 'pies': 'pie',
  };

  /// Hindi ginagalaw (mukhang may hulapi pero hindi).
  static const keep = <String>{
    'news', 'series', 'species', 'lens', 'physics', 'mathematics', 'always', 'perhaps',
    'thus', 'plus', 'yes', 'this', 'chaos', 'christmas', 'diabetes', 'herpes', 'rabies',
    'morning', 'evening', 'meeting', 'building', 'wedding', 'ceiling', 'thing', 'nothing',
    'something', 'anything', 'everything', 'king', 'ring', 'sing', 'bring', 'spring',
    'string', 'sibling', 'darling', 'during', 'ping', 'wing', 'swing', 'sling', 'pudding',
    'earring', 'icing', 'awning', 'clothing', 'lightning', 'boring',
    'need', 'feed', 'seed', 'speed', 'bleed', 'breed', 'weed', 'indeed', 'hundred',
    'sacred', 'naked', 'wicked', 'beloved', 'kindred', 'shed', 'sled', 'bed', 'red', 'wed',
  };

  static const _vowels = 'aeiou';

  /// Mga katinig na hindi pinapaikli kapag doble ("call", "miss", "buzz").
  static const _keepDouble = 'lsz';

  static bool _isVowel(String c) => _vowels.contains(c);

  static int _vowelCount(String s) {
    var n = 0;
    for (var i = 0; i < s.length; i++) {
      if (_isVowel(s[i])) n++;
    }
    return n;
  }

  /// Ugat ng isang English na salita. Hindi sigurado → ang salita mismo.
  static String stem(String w) {
    final irr = irregular[w];
    if (irr != null) return irr;
    if (w.length < 4 || keep.contains(w)) return w;

    // ── Plural
    if (w.length >= 5 && w.endsWith('ies')) return '${w.substring(0, w.length - 3)}y';
    if (w.endsWith('sses')) return w.substring(0, w.length - 2);
    if (w.length >= 5 &&
        (w.endsWith('xes') || w.endsWith('ches') || w.endsWith('shes') || w.endsWith('zzes'))) {
      return w.substring(0, w.length - 2);
    }
    if (w.endsWith('s')) {
      // -ss / -us / -is / -as / -os → hindi plural ("glass", "bus", "linis", "bigas", "sapatos")
      final before = w[w.length - 2];
      if (before == 'e' || before == 'y' || (!_isVowel(before) && before != 's')) {
        return w.substring(0, w.length - 1);
      }
      return w;
    }

    // ── -ing
    if (w.length >= 5 && w.endsWith('ing')) {
      final s = _fixEnd(w.substring(0, w.length - 3));
      if (s != null) return s;
      return w;
    }

    // ── -ed
    if (w.length >= 5 && w.endsWith('ed') && !w.endsWith('eed')) {
      final s = w.substring(0, w.length - 2);
      if (s.endsWith('i')) return '${s.substring(0, s.length - 1)}y'; // tried → try
      final fixed = _fixEnd(s);
      if (fixed != null) return fixed;
    }
    return w;
  }

  /// Pagkatapos tanggalin ang -ing / -ed:
  ///   doble ang huling katinig → isa na lang ("shopp" → "shop")
  ///   maikling katinig-patinig-katinig → dagdag "e" ("tak" → "take")
  /// null = hindi mukhang tamang ugat (masyadong maikli / walang patinig).
  static String? _fixEnd(String s) {
    if (s.length < 2 || _vowelCount(s) == 0) return null;
    final last = s[s.length - 1];
    if (s.length >= 3 &&
        last == s[s.length - 2] &&
        !_isVowel(last) &&
        !_keepDouble.contains(last)) {
      return s.substring(0, s.length - 1);
    }
    if (s.length >= 3 &&
        s.length <= 4 &&
        _vowelCount(s) == 1 &&
        !_isVowel(last) &&
        !'wxy'.contains(last) &&
        _isVowel(s[s.length - 2]) &&
        !_isVowel(s[s.length - 3])) {
      return '${s}e';
    }
    return s.length >= 3 ? s : null;
  }
}