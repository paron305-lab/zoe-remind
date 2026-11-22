import 'package:zoe_remind/ai/parser/intent_classifier.dart';
import 'package:zoe_remind/rag/query_terms.dart';

/// Ang "label" ni Qwen para sa malabong tanong (B6) — hindi sagot.
///
///   "yung sinabi ko last time tungkol sa gamot ni mama"
///       Qwen: `search_notes | gamot, mama`
///       → ZoeLabel(searchNotes, words: [gamot, mama])
///   "may naiwan ba akong hindi nagawa these past few days?"
///       Qwen: `get_missed | last 3 days`
///       → ZoeLabel(getMissed, range: 'last 3 days')
///
/// Sandbox rules (code ang may huling salita):
///  • [words]: kinukuha LANG kung nasa mensahe mismo ng user ang salita.
///    Ang salitang inimbento ni Qwen (wala sa mensahe) ay tinatapon.
///  • [range]: isa lang sa [ranges] (allowlist), at kapag may binanggit na
///    panahon ang user ("nung", "last", "these days"…). Kung wala → null.
///  • Code pa rin ang naghahanap (Retriever, HistoryQuery). Ang sagot ay ang
///    note / history mismo — walang iniimbento si Zoe.
///
/// Pure (walang model, walang database) — `flutter test test/ai/zoe_label_test.dart`.
class ZoeLabel {
  const ZoeLabel(this.intent, {this.words = const [], this.range});

  final ZoeIntent intent;

  /// search_notes lang: mga salitang hahanapin (galing sa mensahe).
  final List<String> words;

  /// get_done / get_missed / get_today lang: isa sa [ranges].
  /// Ginagawang petsa ng `HistoryQuery.range(range)` (code).
  final String? range;

  /// Hanggang ilang salita.
  static const maxWords = 4;

  /// Mga saklaw na pwedeng sabihin ni Qwen. Lahat ay naiintindihan ng
  /// HistoryQuery. (Mas mahaba muna, para "day before yesterday" bago "yesterday".)
  static const ranges = [
    'day before yesterday',
    'the other day',
    'last 3 days',
    'last 7 days',
    'this week',
    'last week',
    'this month',
    'last month',
    'yesterday',
    'today',
  ];

  /// May binanggit bang panahon ang user? Kung wala, hindi tinatanggap ang range.
  static final _timeCue = RegExp(
    r'\b(kahapon|kamakalawa|kamakailan|kanina|ngayon|ngayong|nitong|nung|noong|nakaraan|nakaraang'
    r'|nakalipas|araw|linggo|buwan|yesterday|today|tonight|recently|lately|last|past|previous'
    r'|this|other|ago|days?|weeks?|months?)\b',
  );

  static bool _hasTimeCue(String message) => _timeCue.hasMatch(QueryTerms.fold(message));

  /// Ginagawang [ZoeLabel] ang hilaw na sagot ni Qwen.
  /// [intent] = ang napagpasyahan na (allowlist + code check sa IntentClassifier).
  /// [raw] = hilaw na sagot ni Qwen. [message] = mensahe ng user.
  static ZoeLabel from(ZoeIntent intent, String raw, String message) {
    final slots = _slotsAfter(intent, raw);
    if (slots.isEmpty) return ZoeLabel(intent);
    switch (intent) {
      case ZoeIntent.searchNotes:
        return ZoeLabel(intent, words: wordsIn(slots, message));
      case ZoeIntent.getDone:
      case ZoeIntent.getMissed:
      case ZoeIntent.getToday:
        return ZoeLabel(intent, range: rangeIn(slots, message));
      default:
        return ZoeLabel(intent);
    }
  }

  /// Ang nasa likod ng label: "search_notes | gamot, mama" → "gamot, mama".
  static String _slotsAfter(ZoeIntent intent, String raw) {
    final lower = raw.toLowerCase();
    final at = lower.indexOf(intent.label);
    if (at < 0) return '';
    final rest = lower.substring(at + intent.label.length);
    // Isang linya lang; tanggal ang "|", ":", "-" sa unahan.
    return rest.split('\n').first.replaceFirst(RegExp(r'^[\s|:=,\-]+'), '').trim();
  }

  /// Mga salita sa [slots] na NASA [message] din (o simula ng salita sa
  /// mensahe, 4+ letra). Walang stopword, walang ulit, hanggang [maxWords].
  static List<String> wordsIn(String slots, String message) {
    final inMessage = QueryTerms.tokens(message);
    final out = <String>[];
    final seen = <String>{};
    for (final w in QueryTerms.rawTokens(slots)) {
      final key = QueryTerms.fold(w);
      if (key.length < 2 || QueryTerms.stopWords.contains(key) || !seen.add(key)) continue;
      if (!inMessage.any((t) => _sameWord(key, t))) continue; // inimbento → tapon
      out.add(w);
      if (out.length == maxWords) break;
    }
    return out;
  }

  static bool _sameWord(String word, String token) {
    if (word == token) return true;
    if (word.length < 4 || token.length < 4) return false;
    return token.startsWith(word) || word.startsWith(token);
  }

  /// Isa sa [ranges] na nasa [slots], kapag may binanggit na panahon sa [message].
  static String? rangeIn(String slots, String message) {
    if (!_hasTimeCue(message)) return null;
    final s = ' ${slots.toLowerCase().replaceAll(RegExp(r'\s+'), ' ')} ';
    for (final r in ranges) {
      if (s.contains(' $r ') || s.contains(' $r,') || s.contains(' $r.')) return r;
    }
    return null;
  }

  @override
  String toString() {
    final extra = [
      if (words.isNotEmpty) words.join(', '),
      if (range != null) range!,
    ];
    return extra.isEmpty ? intent.label : '${intent.label} | ${extra.join(' · ')}';
  }
}