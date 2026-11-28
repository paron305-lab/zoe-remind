import 'dart:math' as math;

import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/stemmer.dart';

/// Memory Recall — naaalala ni Zoe ang sinabi mo kapag may kinalaman sa
/// sinasabi mo NGAYON. Pure (walang database) →
/// `flutter test test/memory/memory_recall_test.dart`.
///
///   memory: "Allergic ako sa hipon"
///     "ang sarap kumain ng hipon"        → warning: "Teka — diba allergic ka sa hipon? Ingat ka ha! 😅"
///     "diba sinabi ko allergic ako sa hipon" → known: "Oo naman, naaalala ko — allergic ka sa hipon. 😊"
///   memory: "Hindi ako kumakain ng baboy" / "Vegetarian ako"
///     "lechon tayo mamaya!"              → warning
///   memory: "Paborito ko ang sinigang"
///     "nagluto si mama ng sinigang"      → favorite: "Uy, paborito mo 'yan diba? 😋"
///
/// Code ang naghahanap (salita sa salita) — walang hula, walang Qwen.
/// Ang memory MISMO ang sinasabi ni Zoe (ginawang "ka / mo"), hindi iniimbento.
///
/// R6 — iisang vocabulary sa RAG: kasama na sa paghahanap sa mensahe ang
/// UGAT ng salita (Stemmer, gaya ng search) at ang mga salitang natutunan ni
/// Zoe sa phone (RagLearning `learned`: "shrimpies" → hipon).
enum RecallKind {
  /// Allergic / hindi kumakain / vegetarian → paalala na mag-ingat.
  avoid,

  /// Paborito / favorite → masayang paalala.
  favorite,
}

/// Isang memory na nakilala mula sa content.
class RecallFact {
  const RecallFact(this.memory, this.kind, this.keywords);

  /// Ang memory mismo ("Allergic ako sa hipon").
  final String memory;
  final RecallKind kind;

  /// Mga salitang hahanapin sa mensahe ("hipon", "shrimp", "sugpo"…).
  final Set<String> keywords;

  @override
  String toString() => 'RecallFact($memory, $kind, $keywords)';
}

/// Resulta ng [MemoryRecall.check].
class RecallHit {
  const RecallHit(this.fact, {required this.known});

  final RecallFact fact;

  /// true = "diba sinabi ko sa'yo…?" → "Oo naman, naaalala ko…"
  /// false = paalala (avoid) o paborito.
  final bool known;
}

class MemoryRecall {
  MemoryRecall._();

  static final _rng = math.Random();

  // ── Pagbasa ng memory ────────────────────────────────────────────────

  static final _allergy = RegExp(
    r"\ballergic\s+(?:ako\s+|ka\s+)?(?:sa|to)\s+(.+)"
    r'|\bmay\s+allergy\s+ako\s+sa\s+(.+)'
    r'|\ballergy\s+(?:ko\s+)?(?:sa|ang)\s+(.+)'
    r'|\bi\s+have\s+(?:an?\s+)?allerg(?:y|ies)\s+to\s+(.+)',
  );

  static final _noEat = RegExp(
    r'\b(?:hindi|di)\s+ako\s+kumakain\s+ng\s+(.+)'
    r"|\bi\s+(?:don'?t|do\s+not)\s+eat\s+(.+)"
    r'|\b(?:bawal|iwas)\s+(?:ako\s+)?(?:sa\s+)?(.+)',
  );

  static final _veg = RegExp(r"\b(?:vegetarian|vegan)\b");

  static final _favorite = RegExp(
    r'\b(?:paborito|favou?rite)\s+(?:ko|kong)\s+(?:\w+\s+)?(?:ay|ang|is)\s+(.+)'
    r'|\bmy\s+favou?rite\s+(?:\w+\s+)?(?:is|are)\s+(.+)'
    r'|\b(?:paborito|favou?rite)\s+ko\s+(?:ang\s+)?(.+)',
  );

  /// Dito natatapos ang bagay ("hipon kasi namamaga ako" → "hipon").
  static final _clauseEnd = RegExp(
    r'\s*(?:[,.!?;]|\b(?:kasi|dahil|pero|but|because|so|kaya|since|diba|di\s+ba|ha|zoe|po)\b)',
  );

  /// Hindi keyword.
  static const _stop = {
    'ang', 'ng', 'mga', 'sa', 'the', 'and', 'at', 'any', 'kahit', 'anong', 'kind', 'of',
    'po', 'din', 'rin', 'talaga', 'lahat', 'na', 'lang', 'yung', 'ung', 'iyong', 'a', 'an',
    'kong', 'ko', 'all', 'kinds', 'type', 'types', 'some', 'too', 'also', 'very', 'much',
    'kulay', 'pagkain', 'food', 'ulam', 'color', 'colour', 'is', 'ay',
  };

  /// "baka" = baka (beef) o "baka" (maybe) — hinahanap lang bilang "ng baka".
  static const _ambiguous = {'baka'};

  /// Magkakaparehong bagay (Tagalog ↔ English ↔ mga putahe).
  static const _groups = <List<String>>[
    ['hipon', 'shrimp', 'prawn', 'prawns', 'sugpo', 'suahe', 'shrimps'],
    ['mani', 'peanut', 'peanuts', 'peanut butter'],
    ['alimango', 'alimasag', 'crab', 'crabs', 'talangka'],
    ['pusit', 'squid', 'calamares', 'calamari'],
    ['tahong', 'mussel', 'mussels', 'talaba', 'oyster', 'oysters', 'halaan', 'clams', 'clam'],
    ['isda', 'fish', 'tilapia', 'bangus', 'galunggong', 'tuna', 'salmon', 'tinapa', 'daing'],
    ['itlog', 'egg', 'eggs'],
    ['gatas', 'milk', 'dairy', 'keso', 'cheese'],
    ['baboy', 'pork', 'liempo', 'lechon', 'bacon', 'ham', 'tocino', 'longganisa', 'sisig', 'chicharon'],
    ['manok', 'chicken', 'inasal', 'fried chicken'],
    ['baka', 'beef', 'steak', 'bulalo', 'tapa', 'burger'],
  ];

  /// Pangkalahatang salita → lahat ng kasama. Isang direksyon lang:
  /// "allergic sa seafood" → hipon, pusit…; pero "allergic sa hipon" ≠ pusit.
  static const _umbrella = <String, List<String>>{
    'seafood': ['hipon', 'shrimp', 'sugpo', 'alimango', 'crab', 'alimasag', 'pusit', 'squid',
        'tahong', 'talaba', 'oyster', 'mussels', 'halaan', 'clams', 'shellfish'],
    'seafoods': ['hipon', 'shrimp', 'sugpo', 'alimango', 'crab', 'alimasag', 'pusit', 'squid',
        'tahong', 'talaba', 'oyster', 'mussels', 'halaan', 'clams', 'shellfish'],
    'shellfish': ['hipon', 'shrimp', 'sugpo', 'alimango', 'crab', 'alimasag', 'tahong', 'talaba',
        'oyster', 'mussels', 'halaan', 'clams'],
    'karne': ['baboy', 'pork', 'manok', 'chicken', 'beef', 'steak', 'lechon', 'liempo'],
    'meat': ['baboy', 'pork', 'manok', 'chicken', 'beef', 'steak', 'lechon', 'liempo'],
    'nuts': ['mani', 'peanut', 'peanuts', 'almonds', 'cashew', 'kasoy'],
  };

  /// Karne (vegetarian / vegan).
  static const _meat = {
    'karne', 'meat', 'baboy', 'pork', 'liempo', 'lechon', 'bacon', 'ham', 'tocino',
    'longganisa', 'sisig', 'manok', 'chicken', 'inasal', 'beef', 'steak', 'bulalo', 'tapa',
    'hotdog', 'chicharon', 'baka',
  };

  /// Nakikilala ba ni Recall ang [memory]? null = hindi (hal. "Call me AC").
  static RecallFact? factOf(String memory) {
    final lower = memory.toLowerCase().trim();
    if (lower.isEmpty) return null;

    final allergy = _firstGroup(_allergy.firstMatch(lower));
    if (allergy != null) return _fact(memory, RecallKind.avoid, allergy);

    final noEat = _firstGroup(_noEat.firstMatch(lower));
    if (noEat != null) return _fact(memory, RecallKind.avoid, noEat);

    if (_veg.hasMatch(lower)) {
      return RecallFact(memory, RecallKind.avoid, {..._meat});
    }

    final fav = _firstGroup(_favorite.firstMatch(lower));
    if (fav != null) return _fact(memory, RecallKind.favorite, fav);
    return null;
  }

  static String? _firstGroup(RegExpMatch? m) {
    if (m == null) return null;
    for (var i = 1; i <= m.groupCount; i++) {
      final g = m.group(i);
      if (g != null && g.trim().isNotEmpty) return g;
    }
    return null;
  }

  static RecallFact? _fact(String memory, RecallKind kind, String thing) {
    final end = _clauseEnd.firstMatch(thing);
    final part = end == null ? thing : thing.substring(0, end.start);
    final words = <String>{};
    for (final item in part.split(RegExp(r'\s+(?:at|and|o|or)\s+|/'))) {
      final tokens = _tokens(item).where((w) => w.length >= 3 && !_stop.contains(w)).toList();
      if (tokens.isEmpty) continue;
      words.addAll(tokens);
      // "fried chicken", "peanut butter" → buong pangalan din
      if (tokens.length > 1) words.add(tokens.join(' '));
    }
    if (words.isEmpty) return null;
    final keys = {...words};
    // Avoid lang: "hipon" = shrimp = sugpo. (Paborito: ang mismong sinabi lang —
    // ang "sinigang na baboy" ay hindi nangangahulugang paborito ang lechon.)
    if (kind == RecallKind.avoid) {
      for (final g in _groups) {
        if (g.any(words.contains)) keys.addAll(g);
      }
      for (final w in words) {
        keys.addAll(_umbrella[w] ?? const []);
      }
    }
    return RecallFact(memory, kind, keys);
  }

  static List<String> _tokens(String s) =>
      RegExp(r"[a-z0-9']+").allMatches(s.toLowerCase()).map((m) => m[0]!).toList();

  // ── Paghahanap sa mensahe ────────────────────────────────────────────

  /// "diba sinabi ko sa'yo", "alam mo naman", "naaalala mo ba", "told you"…
  /// (Ang "diba" lang ay hindi — "diba masarap ang hipon?" → paalala pa rin.)
  static final _youKnow = RegExp(
    r"\bsinabi\s+ko\b|\bsabi\s+ko\b|\bnasabi\s+ko\b|\balam\s+mo\s+(?:naman|na)\b"
    r"|\bnaaalala\s+mo\b|\bnaalala\s+mo\b|\btanda\s+mo\b|\btold\s+you\b|\bi\s+told\s+you\b"
    r"|\byou\s+(?:know|remember)\b|\bremember\s*\?|\bremember\s+(?:that|when)\b",
  );

  /// Umiiwas na ("hindi ako kakain ng hipon", "iiwas ako") → walang warning.
  static final _avoiding = RegExp(
    r"\b(?:hindi|di|ayoko|ayaw|iwas|iiwas|umiiwas|avoid|avoiding|won'?t|wont|never|bawal)\b",
  );

  /// Hanapin ang memory na may kinalaman sa [lower] (maliit na titik, malinis).
  /// null = walang tugma, o wala namang dapat sabihin.
  ///
  /// [learned] (R6) = natutunang salita (salita o ugat → kapareho), galing sa
  /// RagLearning — pareho ng ginagamit ng search.
  static RecallHit? check(
    String lower,
    Iterable<String> memories, {
    Map<String, List<String>> learned = const {},
  }) {
    if (lower.trim().isEmpty) return null;
    final tokens = _tokens(lower);
    final text = ' ${[...tokens, ..._learnedWords(tokens, learned)].join(' ')} ';
    final stems = _stemsOf(tokens);
    final youKnow = _youKnow.hasMatch(lower);

    for (final m in memories) {
      final fact = factOf(m);
      if (fact == null) continue;
      if (!_mentions(text, fact.keywords) && !_mentionsStem(stems, fact.keywords)) continue;
      if (youKnow) return RecallHit(fact, known: true);
      if (fact.kind == RecallKind.avoid && _avoiding.hasMatch(lower)) continue;
      return RecallHit(fact, known: false);
    }
    return null;
  }

  /// R6: ugat ng mga salita sa mensahe na iba sa salita mismo (5+ letra lang,
  /// para hindi magkamali sa maiikling salita).
  static Set<String> _stemsOf(List<String> tokens) => {
        for (final t in tokens)
          if (t.length >= 5 && Stemmer.stem(QueryTerms.fold(t)) != QueryTerms.fold(t))
            Stemmer.stem(QueryTerms.fold(t)),
      };

  /// Tumama ba ang ugat ng isang salita sa keyword (4+ letra, isang salita)?
  static bool _mentionsStem(Set<String> stems, Set<String> keys) {
    if (stems.isEmpty) return false;
    for (final k in keys) {
      if (k.length < 4 || k.contains(' ') || _ambiguous.contains(k)) continue;
      if (stems.contains(k)) return true;
    }
    return false;
  }

  /// R6: mga natutunang kapareho ng mga salita (o ugat) sa mensahe.
  static List<String> _learnedWords(List<String> tokens, Map<String, List<String>> learned) {
    if (learned.isEmpty) return const [];
    final out = <String>[];
    for (final t in tokens) {
      final key = QueryTerms.fold(t);
      final alts = learned[key] ?? learned[Stemmer.stem(key)];
      if (alts == null) continue;
      for (final a in alts) {
        if (!out.contains(a)) out.add(a);
      }
    }
    return out;
  }

  static bool _mentions(String text, Set<String> keys) {
    for (final k in keys) {
      if (_ambiguous.contains(k)) {
        if (RegExp(r'\b(?:ng|karne\s+ng)\s+baka\b').hasMatch(text)) return true;
        continue;
      }
      if (text.contains(' $k ') || text.contains(' ${k}s ') || text.contains(' ${k}es ')) {
        return true;
      }
    }
    return false;
  }

  // ── Mga linya ────────────────────────────────────────────────────────

  /// "Allergic ako sa hipon" → "allergic ka sa hipon".
  /// "I'm allergic to shrimp" → "you're allergic to shrimp".
  static String toYou(String memory) {
    var s = ' ${memory.trim().replaceAll(RegExp(r'[.!]+$'), '')} ';
    const swaps = {
      r"\bi'm\b": "you're",
      r'\bim\b': "you're",
      r'\bi\s+am\b': 'you are',
      r"\bi've\b": "you've",
      r'\bmy\b': 'your',
      r'\bme\b': 'you',
      r'\bi\b': 'you',
      r'\bako\b': 'ka',
      r'\bkong\b': 'mong',
      r'\bko\b': 'mo',
      r'\bsa\s+akin\b': "sa'yo",
      r'\bakin\b': 'iyo',
    };
    swaps.forEach((p, r) => s = s.replaceAll(RegExp(p, caseSensitive: false), r));
    s = s.trim();
    if (s.isEmpty) return s;
    // Maliit na unang titik (nasa gitna ng pangungusap), maliban sa "AC", "I"…
    final first = s.split(' ').first;
    if (first.length > 1 && first != first.toUpperCase()) {
      s = s[0].toLowerCase() + s.substring(1);
    }
    return s;
  }

  static const _lines = <RecallKind, Map<ZoeLanguage, List<String>>>{
    RecallKind.avoid: {
      ZoeLanguage.english: [
        'Wait — you told me {fact}. Please be careful! 😅',
        'Hold on, {fact}, right? Take care with that.',
        "Careful! I remember {fact}. 😅",
      ],
      ZoeLanguage.tagalog: [
        'Teka — sinabi mo sa akin na {fact}. Ingat ka ha! 😅',
        'Uy, diba {fact}? Ingat ka diyan.',
        'Sandali — naaalala ko, {fact}. Mag-ingat ka ha.',
      ],
      ZoeLanguage.both: [
        'Teka — diba {fact}? Ingat ka ha! 😅',
        'Uy wait, sabi mo {fact}. Be careful ha!',
        'Hala, naaalala ko — {fact}. Ingat ka diyan! 😅',
      ],
    },
    RecallKind.favorite: {
      ZoeLanguage.english: [
        "Oh, that's your favorite, right? 😋",
        'Nice — I remember {fact}! 😊',
      ],
      ZoeLanguage.tagalog: [
        "Uy, paborito mo 'yan diba? 😋",
        'Ayos — naaalala ko, {fact}! 😊',
      ],
      ZoeLanguage.both: [
        "Uy, favorite mo 'yan diba? 😋",
        'Nice — naaalala ko, {fact}! 😊',
      ],
    },
  };

  static const _known = <ZoeLanguage, List<String>>{
    ZoeLanguage.english: [
      'Yes, I remember — {fact}. 😊',
      "Of course! You told me {fact}. I won't forget.",
    ],
    ZoeLanguage.tagalog: [
      'Oo naman, tanda ko — {fact}. 😊',
      'Oo, sinabi mo na sa akin — {fact}. Hindi ko makakalimutan.',
    ],
    ZoeLanguage.both: [
      'Oo naman, naaalala ko — {fact}. 😊',
      "Yes, sinabi mo na 'yan — {fact}. Di ko makakalimutan.",
    ],
  };

  /// Linya ni Zoe para sa [hit].
  static String lineFor(RecallHit hit, ZoeLanguage lang) =>
      hit.known ? knownLine(hit.fact.memory, lang) : _pick(_lines[hit.fact.kind]![lang]!, hit.fact.memory);

  /// "Oo naman, naaalala ko — allergic ka sa hipon." (inulit ng user ang memory)
  static String knownLine(String memory, ZoeLanguage lang) => _pick(_known[lang]!, memory);

  static String _pick(List<String> options, String memory) =>
      options[_rng.nextInt(options.length)].replaceAll('{fact}', toYou(memory));
}