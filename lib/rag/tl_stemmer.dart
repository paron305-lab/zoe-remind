/// R1 — Tagalog na stemmer (panlapi, gitlapi, ulit ng pantig, hulapi).
///
///   bumili / binili / bibili / binilhan → bili
///   kumain / kinain / kakain / pagkain  → kain
///   nagluto / magluluto / lulutuin      → luto
///   nadiligan / magdidilig / diligan    → dilig
///   nabayaran / ibinayad                → bayad
///   pinaprint → print · nagpagas → gas · inorder → order (Taglish)
///
/// Walang diksiyonaryo, walang model — mga patakaran lang. Ang mga hangganan
/// (haba, bilang ng patinig, simula ng salita) ay para hindi magalaw ang
/// salitang mukhang may panlapi pero wala ("manok", "nanay", "pancit").
/// Kung hindi sigurado → hindi ginagalaw. Para sa search lang ito: ang
/// orihinal na salita ay laging hinahanap pa rin.
///
/// Input: maliit na titik, walang tuldik, walang gitling (ang "nag-shopping"
/// ay dalawang token na: "nag" + "shopping" — tingnan ang [bareAffixes]).
class TlStemmer {
  TlStemmer._();

  /// Mas maikli rito → hindi ginagalaw ("kain", "bili", "luto", "mama").
  static const minLength = 5;

  /// Hindi ginagalaw kahit mukhang may panlapi.
  static const keep = <String>{
    'mama', 'papa', 'nanay', 'tatay', 'bahay', 'kotse', 'ingat', 'magkano', 'kanino',
    'ngayon', 'kailan', 'paano', 'nasaan', 'mayroon', 'marami', 'maynilad', 'pamilya',
    'magulang', 'kapatid', 'pangalan', 'umaga', 'tanghali', 'hapon', 'gabi', 'linggo',
    'sinigang', 'tinapay', 'pinoy', 'pinay', 'minsan', 'palengke', 'pasko', 'papaya',
    // "pagkain" = food (hindi "kain" = eat), "paborito" ay hindi pa + borito
    'pagkain', 'paborito',
    // "pahina" (page) ≠ "mahina" → hina
    'pahina',
  };

  /// Hindi regular na banghay → ugat.
  static const roots = <String, String>{
    'kunin': 'kuha', 'kunan': 'kuha', 'kukunin': 'kuha', 'tingnan': 'tingin',
    'gawin': 'gawa', 'gagawin': 'gawa', 'sundin': 'sunod', 'sundan': 'sunod',
    'inumin': 'inom', 'iinumin': 'inom', 'lagyan': 'lagay', 'darating': 'dating',
    'dumarating': 'dating', 'nanghiram': 'hiram', 'manghiram': 'hiram',
  };

  /// Nawawalang patinig bago ang hulapi (bili + hin → bilhin):
  /// ugat-na-walang-hulapi → tunay na ugat.
  static const syncope = <String, String>{
    'bilh': 'bili', 'labh': 'laba', 'dalh': 'dala', 'lagy': 'lagay', 'sund': 'sunod',
    'tingn': 'tingin', 'kun': 'kuha', 'gaw': 'gawa', 'hingh': 'hingi', 'sakh': 'saka',
  };

  /// Ugat na mukhang may gitlapi -in- / -um- pero wala ("linis" ≠ l-in-is):
  /// hindi tinatanggal ang gitlapi kapag nagsisimula ang salita sa mga ito.
  static const infixLike = [
    'linis', 'linaw', 'sinag', 'tinig', 'kinis', 'dinig', 'sinok', 'hinog', 'tinik',
    'sinop', 'pinta', 'kumot', 'humba',
  ];

  /// Unlapi, pinakamahaba muna. Ang nagtatapos sa katinig (nag-, mag-, pag-…)
  /// ay tinatanggal lang kapag katinig ang kasunod — bago ang patinig ay may
  /// gitling ito ("mag-aral"), kaya "magaling" = ma + galing, hindi mag + aling.
  /// Ang "in" / "um" ay unlapi lang bago ang patinig ("inorder", "umalis").
  /// Ang "ini" = i- na may -in- ("inilagay", "inihanda").
  static const prefixes = [
    'nakapag', 'makapag', 'nakipag', 'makipag', 'pinaka', 'ipinag', 'nakaka',
    'ipina', 'pinag', 'nagpa', 'magpa', 'napag',
    'naka', 'maka', 'pina', 'napa', 'ipag', 'nang', 'mang', 'pang', 'magka', 'nagka',
    'nag', 'mag', 'pag', 'ipa', 'ika', 'ini',
    'na', 'ma', 'ni', 'pa', 'in', 'um', 'i',
  ];

  /// Ikalawang unlapi — ulit lang ng dulo ng una: nagpa + paluto, ipa + pakain,
  /// nagka + kasakit. ("nakaparada" → parada, hindi "rada".)
  static const secondPrefixes = ['pag', 'pa', 'ka'];

  /// Unlapi na hiwalay na token dahil sa gitling ("nag-gas" → "nag", "gas").
  /// Hindi hinahanap: walang ibig sabihin mag-isa, at tumatama sa mali
  /// ("nag" sa "nag-gas" → "Nag-gy-gym").
  static const bareAffixes = <String>{
    'nag', 'mag', 'pag', 'naka', 'maka', 'nakapag', 'makapag', 'nakipag', 'makipag',
    'pina', 'pinag', 'ipina', 'ipinag', 'nagpa', 'magpa', 'napa', 'napag', 'ipa', 'ipag',
    'ika', 'mang', 'pang', 'ma', 'ka', 'um', 'pinaka', 'nakaka', 'magka', 'nagka',
    'naki', 'maki', 'mala', 'magsi', 'nagsi',
  };

  /// Tagalog na nagtatapos sa "-ing" (hindi English na -ing):
  /// hindi ipinapasa sa EnStemmer ("galing" ≠ "gale").
  static const nativeIng = <String>{
    'galing', 'magaling', 'dating', 'huling', 'sariling', 'maling', 'laging', 'sining',
    'hiling', 'daing', 'aling', 'iling', 'tuling', 'kuting', 'gising', 'bating', 'pating',
    'piling', 'baling', 'saling', 'tiling', 'kaling', 'kaibiging', 'nating', 'ating',
    'aking', 'sinding', 'bitling', 'puting', 'iting', 'tuwing', 'kasing', 'duling',
  };

  /// Simula ng salita na pwede kahit dalawang katinig (Tagalog + hiram).
  static const clusters = <String>{
    'bl', 'br', 'dr', 'dy', 'gr', 'gl', 'kl', 'kr', 'pl', 'pr', 'tr', 'ts', 'sh', 'ch',
    'st', 'sp', 'sk', 'sw', 'sm', 'sn', 'sl', 'ng', 'ny', 'ky', 'by', 'py', 'ty', 'sy',
    'fl', 'fr', 'th', 'wh',
  };

  static const _vowels = 'aeiou';

  /// Mga letrang wala sa katutubong Tagalog → hiram / English. Hindi ginagalaw
  /// ang gitlapi, ulit at hulapi ng salitang may ganito ("finish", "vitamin").
  static const _foreign = 'cfjqvxz';

  static bool _isVowel(String c) => _vowels.contains(c);

  static int _vowelCount(String s) {
    var n = 0;
    for (var i = 0; i < s.length; i++) {
      if (_isVowel(s[i])) n++;
    }
    return n;
  }

  static bool _hasForeign(String s) {
    for (var i = 0; i < s.length; i++) {
      if (_foreign.contains(s[i])) return true;
    }
    return false;
  }

  /// Mukhang simula ng salita: patinig, katinig + patinig, o [clusters].
  static bool _validStart(String s) {
    if (s.length < 2) return false;
    return _isVowel(s[0]) || _isVowel(s[1]) || clusters.contains(s.substring(0, 2));
  }

  /// Ugat ng isang Tagalog / Taglish na salita. Hindi sigurado → ang salita mismo.
  static String stem(String w) {
    if (w.length < minLength || keep.contains(w)) return w;
    final known = roots[w];
    if (known != null) return known;

    var f = w;

    // 1. Unlapi (hanggang dalawa: nagpa + paluto → luto).
    final first = _stripPrefix(f, prefixes);
    if (first != null) {
      final used = f.substring(0, f.length - first.length);
      f = first;
      final second = _stripPrefix(f, [
        for (final p in secondPrefixes)
          if (used.endsWith(p)) p,
      ]);
      if (second != null) f = second;
    }
    final r1 = roots[f];
    if (r1 != null) return r1;

    if (!_hasForeign(f)) {
      // 2. Gitlapi -um- / -in-: bumili → bili, kinain → kain.
      if (f.length >= minLength &&
          !infixLike.any(f.startsWith) &&
          !_isVowel(f[0]) &&
          (f.startsWith('um', 1) || f.startsWith('in', 1)) &&
          _isVowel(f[3])) {
        final rest = f[0] + f.substring(3);
        if (rest.length >= 4 && _vowelCount(rest) >= 2) f = rest;
      }

      // 3. Ulit ng pantig: bibili → bili, iinom → inom, nagluluto → luto.
      if (f.length >= minLength) {
        String? rest;
        if (_isVowel(f[0]) && f[1] == f[0]) {
          rest = f.substring(1);
        } else if (!_isVowel(f[0]) && _isVowel(f[1]) && f.startsWith(f.substring(0, 2), 2)) {
          rest = f.substring(2);
        }
        if (rest != null && rest.length >= 4 && _vowelCount(rest) >= 2) f = rest;
      }
      final r2 = roots[f];
      if (r2 != null) return r2;

      // 4. Hulapi: diligan → dilig, lutuin → luto, bilhan → bili, bayaran → bayad.
      if (f.length >= minLength) {
        for (final sfx in const ['han', 'hin', 'an', 'in']) {
          if (!f.endsWith(sfx)) continue;
          var r = f.substring(0, f.length - sfx.length);
          r = syncope[r] ?? r;
          if (r.length < 3 || _vowelCount(r) < 2) continue;
          f = _fixRoot(r);
          break;
        }
      }
    }
    return roots[f] ?? f;
  }

  /// Unang tumugmang unlapi na pasok sa patakaran, o null.
  static String? _stripPrefix(String f, List<String> list) {
    for (final p in list) {
      if (f.length <= p.length || !f.startsWith(p)) continue;
      final rest = f.substring(p.length);
      if (_prefixOk(p, rest)) return rest;
    }
    return null;
  }

  static bool _prefixOk(String p, String rest) {
    if (!_validStart(rest)) return false;
    final next = rest[0];
    if (p == 'in' || p == 'um') {
      // "inorder", "iniwan", "umalis" — bago lang ng patinig.
      return _isVowel(next) && rest.length >= 4 && _vowelCount(rest) >= 2;
    }
    if (!_isVowel(p[p.length - 1]) && _isVowel(next)) return false; // "mag-aral" may gitling
    if (p == 'i' && _isVowel(next)) return false; // "i-abot" may gitling
    // na, ma, ni, pa, i — at "ini" (i + -in-: inilagay → lagay; "iniwan" → in + iwan)
    if (p.length <= 2 || p == 'ini') return rest.length >= 4 && _vowelCount(rest) >= 2;
    if (p.endsWith('ng')) return rest.length >= 3 && _vowelCount(rest) >= 2; // nang, mang, pang
    return rest.length >= 3 && _vowelCount(rest) >= 1;
  }

  /// Pagkatapos ng hulapi:
  ///   huling "u" → "o" (luto → lutuin, inom → inumin, tulong → tulungan)
  ///   huling "r" pagkatapos ng patinig → "d" (bayad → bayaran, lakad → lakaran)
  static String _fixRoot(String root) {
    var r = root;
    var i = r.length - 1;
    while (i >= 0 && !_isVowel(r[i])) {
      i--;
    }
    if (i >= 0 && r[i] == 'u') r = '${r.substring(0, i)}o${r.substring(i + 1)}';
    if (r.length >= 2 && r.endsWith('r') && _isVowel(r[r.length - 2])) {
      r = '${r.substring(0, r.length - 1)}d';
    }
    return r;
  }
}