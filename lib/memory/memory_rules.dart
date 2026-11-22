import 'package:zoe_remind/ai/parser/when_parser.dart';
import 'package:zoe_remind/rag/query_terms.dart';

/// Long-term memory ni Zoe (RAG B5) — mga patakaran, pure (walang database).
/// Nate-test sa `flutter test test/memory/memory_rules_test.dart`.
///
/// NOTE vs MEMORY:
///   "tandaan mo, ang wifi password ay zoe2026"      → NOTE (impormasyon / data)
///   "tandaan mo na ang locker code ko ay 4521"      → NOTE
///   "tandaan mo na mas gusto ko ng morning reminders" → MEMORY (tungkol sa iyo)
///   "remember that I'm vegetarian"                  → MEMORY
///   "tandaan mo, gisingin mo ako 6am"               → hindi memory (may oras → reminder)
///   "you have to remember i love sinigang"          → MEMORY
///   "call me AC" / "tawagin mo akong AC"            → MEMORY (kahit walang "tandaan")
///   "remember… i love to remind about…"             → TANONG muna (memory o reminder?)
class MemoryRules {
  MemoryRules._();

  /// Pinakamahabang memory na sine-save.
  static const maxLength = 300;

  static const _triggerPattern = r'\b(?:paki[\s-]?)?tandaan\s+mo\b|\blagi\s+mong\s+tandaan\b'
      r'|\btatandaan\s+mo\b'
      r'|\b(?:(?:you\s+(?:have|need)\s+to|you\s+should|please|always)\s+)?remember'
      r"(?:\s*(?:that|this)\b|\s*:|\s+(?=(?:i|i'm|im|my|me|na|ako|ko)\b))"
      r'|\b(?:you\s+(?:have|need)\s+to|please|always)\s+remember\b'
      r'|\bkeep\s+in\s+mind\b|\b(?:isaisip|isa-isip|alalahanin)\s+mo\b'
      r"|\b(?:don'?t|never)\s+forget\b(?:\s+that\b)?"
      r'|\b(?:huwag|wag)\s+mong?\s+(?:kakalimutan|kalimutan)\s+na\b'
      r"|\bnote\s+that\s+(?=(?:i|i'm|im|my)\b)|\bfor\s+the\s+record\b|\bfyi\b";

  /// "tandaan mo", "remember that", "keep in mind"…
  static final _trigger = RegExp(_triggerPattern, caseSensitive: false);

  /// Tungkol sa user mismo: gusto / ayaw, pangalan, birthday, allergy…
  static final _aboutMe = RegExp(
    r'\b(?:mas\s+)?gusto\s+ko(?:ng)?\b|\bayoko\b|\bayaw\s+ko(?:ng)?\b|\bprefer\b'
    r"|\bi\s+(?:really\s+)?(?:like|love|hate|enjoy|prefer|don'?t\s+like|do\s+not\s+like)\b"
    r'|\bfavou?rite\b|\bpaborito\b|\btawagin\s+mo\s+(?:akong|ako)\b|\bcall\s+me\b'
    r'|\bmy\s+name\s+is\b|\bpangalan\s+ko\b'
    r'|\b(?:birthday|bday|kaarawan)\s+ko\b|\bmy\s+(?:birthday|bday)\b'
    r"|\ballergic\b|\ballergy\b|\b(?:hindi|di)\s+ako\s+kumakain\b|\bi\s+don'?t\s+eat\b"
    r"|\bvegetarian\b|\bvegan\b|\bi'?m\s+an?\b|\bi\s+am\s+an?\b|\bako\s+ay\b",
  );

  /// Pangalan / tawag sa user — memory kahit walang "tandaan mo".
  /// "call me AC", "tawagin mo akong AC", "AC na lang itawag mo sa akin",
  /// "my name is Aaron". Hindi: "call me later", "call me at 7".
  static final _identity = RegExp(
    r"\bcall\s+me\s+(?!(?:later|tomorrow|back|when|if|at|tonight|maybe|now|asap|again|in|on|after)\b)[a-z0-9]"
    r'|\btawagin\s+mo\s+(?:akong|ako)\s+(?:na\s+)?[a-z0-9]'
    r'|\b[a-z0-9]+\s+na\s+lang\s+(?:ang\s+)?(?:itawag|tawag)\s+mo\s+(?:sa\s+akin|sakin)\b'
    r'|\bmy\s+name\s+is\s+[a-z]|\b(?:ang\s+)?pangalan\s+ko\s+ay\s+[a-z]',
  );

  /// Utos na magpaalala sa loob ng memory na mensahe → TANUNGIN muna.
  /// ("reminders" na pangngalan ay hindi kasama: "gusto ko ng morning reminders").
  static final _remindVerb = RegExp(
    r'\b(?:remind(?:ed|ing)?|i-?remind|pa-?remind|paremind|paalalahanan|ipaalala|pinapaalala'
    r'|gisingin|ginigising|gigisingin|wake\s+me|waking\s+me)\b',
  );

  /// Malapit na oras → reminder / note, hindi memory.
  static final _soon =
      RegExp(r'\b(?:bukas|tomorrow|mamaya|mamayang|tonight|ngayong\s+gabi)\b|\blater\s+today\b');

  /// true = ("tandaan mo / remember that" + tungkol sa iyo) o pangalan,
  /// at walang oras. [lower] = maliit na titik (na-normalize na).
  static bool isRememberAboutMe(String lower) {
    final aboutMe = _trigger.hasMatch(lower) && _aboutMe.hasMatch(lower);
    if (!aboutMe && !_identity.hasMatch(lower)) return false;
    if (WhenParser.time(lower) != null || _soon.hasMatch(lower)) return false;
    return true;
  }

  /// May "tandaan mo / remember" ba? (Para sa 💜 Tandaan chip sa tanong.)
  static bool hasTrigger(String lower) => _trigger.hasMatch(lower) || _identity.hasMatch(lower);

  /// May utos na magpaalala ("remind", "gisingin")? Kapag memory + ito →
  /// hindi sigurado si Zoe → magtatanong: tandaan ba, o gawing reminder?
  static bool mentionsReminder(String lower) => _remindVerb.hasMatch(lower);

  /// "Zoe, tandaan mo na mas gusto ko ng morning reminders."
  ///   → "Mas gusto ko ng morning reminders"
  static String extract(String text) {
    var s = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceFirst(RegExp(r'^zoe\b[\s,:]*', caseSensitive: false), '');
    final m = _trigger.firstMatch(s);
    if (m != null) s = '${s.substring(0, m.start)} ${s.substring(m.end)}';
    s = s.trim();
    // "… na / that / ito: …" sa unahan
    s = s.replaceFirst(
        RegExp(r'^[\s,.:;-]*(?:(?:na|that|po|ito|to)\b[\s,:;-]*)?', caseSensitive: false), '');
    // "…, zoe" / "…, ha" / "… yan" sa hulihan
    s = s.replaceFirst(
        RegExp(r'[\s,]*\b(?:zoe|yan|iyan|ha|ah|okay|ok|please|po)\b[\s.!?]*$', caseSensitive: false),
        '');
    s = s.replaceAll(RegExp(r'^[\s,.:;-]+|[\s,.!;:-]+$'), '').replaceAll(RegExp(r'\s+'), ' ');
    if (s.isEmpty) return '';
    s = s[0].toUpperCase() + s.substring(1);
    return s.length <= maxLength ? s : s.substring(0, maxLength);
  }

  /// Hindi binibilang sa paghahambing ("mas", "talaga"…).
  static const _filler = {'mas', 'talaga', 'sana', 'really', 'more', 'very', 'super', 'also', 'too'};

  /// Gusto / ayaw — kapag ito lang ang nagbago, PAREHONG memory (napalitan
  /// ang gusto mo): "gusto ko ng morning reminders" → "ayoko ng morning reminders".
  static const _polarity = {
    'gusto', 'ayoko', 'ayaw', 'like', 'love', 'hate', 'prefer', 'dislike', 'enjoy', 'don',
    'dont', 'not', 'hindi', 'no',
  };

  static Set<String> _words(String s) => QueryTerms.tokens(s)
      .where((w) => w.length >= 2 && !QueryTerms.stopWords.contains(w) && !_filler.contains(w))
      .toSet();

  /// Pareho ba ang [a] at [b]? (para hindi dumoble sa Zoe's memories)
  ///   - parehong mga salita ("Mas gusto ko ng X" = "Gusto ko ng X")
  ///   - parehong paksa, ibang gusto/ayaw ("Gusto ko ng X" → "Ayoko ng X")
  ///   - halos pareho (≥ 80% ng mga salita)
  static bool sameMemory(String a, String b) {
    final wa = _words(a);
    final wb = _words(b);
    if (wa.isEmpty || wb.isEmpty) {
      return QueryTerms.tokens(a).join(' ') == QueryTerms.tokens(b).join(' ');
    }
    if (_sameSet(wa, wb)) return true;

    final ta = wa.difference(_polarity);
    final tb = wb.difference(_polarity);
    final hasPolarity = ta.length != wa.length || tb.length != wb.length;
    if (hasPolarity && ta.isNotEmpty && _sameSet(ta, tb)) return true;

    final common = wa.intersection(wb).length;
    final all = wa.union(wb).length;
    return all >= 3 && common / all >= 0.8;
  }

  static bool _sameSet(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);
}