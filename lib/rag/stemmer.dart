import 'package:zoe_remind/rag/en_stemmer.dart';
import 'package:zoe_remind/rag/tl_stemmer.dart';

/// R1 — ugat (stem) ng salita: Tagalog + English + Taglish.
///
///   "binili" / "bumili" / "bibili" → bili     "bought" / "buying" → buy
///   "batteries" → battery                     "nadiligan" → dilig
///   "pinaprint" → print                       "nagpagas" → gas
///
/// Para sa SEARCH lang (QueryTerms, Retriever, search_stems sa DB). Hindi
/// binabago ang note. Ang orihinal na salita ay laging hinahanap pa rin, kaya
/// ang ugat ay dagdag na paraan lang para tumama.
///
/// Pagpili ng wika (bawat salita):
///   1. Hindi regular na English (bought, paid, went) → iyon na.
///   2. Tagalog na panlapi / gitlapi / ulit / hulapi → [TlStemmer].
///   3. Ang natira ay ipinapasa sa [EnStemmer] (plural, -ing, -ed), maliban
///      kung Tagalog na -ing ("galing", "dating").
///   Hindi sigurado → hindi ginagalaw.
///
/// Pure Dart, walang database — nate-test sa test/rag/stemmer_test.dart.
class Stemmer {
  Stemmer._();

  /// Itaas kapag nagbago ang mga patakaran: ginagawa ulit ang search_stems
  /// ng lahat ng notes / memories pagbukas ng app (ZoeDatabase).
  static const version = 1;

  static final _cache = <String, String>{};
  static const _cacheMax = 4000;

  /// Ugat ng isang token (maliit na titik, walang tuldik — galing sa
  /// QueryTerms.tokens). Hindi sigurado → ang token mismo.
  static String stem(String token) {
    final hit = _cache[token];
    if (hit != null) return hit;
    final s = _stem(token);
    if (_cache.length >= _cacheMax) _cache.clear();
    _cache[token] = s;
    return s;
  }

  static String _stem(String t) {
    if (t.length < 2 || _hasDigit(t)) return t;
    final irr = EnStemmer.irregular[t];
    if (irr != null) return irr;
    if (t.length < 4) return t;

    final tl = TlStemmer.stem(t);
    if (tl != t) {
      final irr2 = EnStemmer.irregular[tl]; // "nagbought" → buy
      if (irr2 != null) return irr2;
    }
    if (TlStemmer.nativeIng.contains(tl) || TlStemmer.keep.contains(tl)) return tl;
    final en = EnStemmer.stem(tl);
    return en.length >= 2 ? en : tl;
  }

  /// Unlapi na hiwalay na token ("nag" sa "nag-gas") — hindi hinahanap.
  static bool isBareAffix(String token) => TlStemmer.bareAffixes.contains(token);

  /// Mga token + ang ugat ng bawat isa na iba sa token.
  ///   ["binili", "ko", "shoes"] → ["binili", "ko", "shoes", "bili", "shoe"]
  static List<String> withStems(List<String> tokens) {
    final extra = <String>[];
    for (final t in tokens) {
      final s = stem(t);
      if (s != t) extra.add(s);
    }
    return extra.isEmpty ? tokens : [...tokens, ...extra];
  }

  /// Para sa column na search_stems (DB v15): mga ugat na iba sa token,
  /// walang ulit, hiwalay sa space. Walang laman kung walang nabago.
  static String stemText(List<String> tokens) {
    final out = <String>{};
    for (final t in tokens) {
      final s = stem(t);
      if (s != t) out.add(s);
    }
    return out.join(' ');
  }

  static bool _hasDigit(String t) {
    for (var i = 0; i < t.length; i++) {
      final c = t.codeUnitAt(i);
      if (c >= 48 && c <= 57) return true;
    }
    return false;
  }
}