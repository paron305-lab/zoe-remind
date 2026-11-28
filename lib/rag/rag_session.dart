import 'package:zoe_remind/ai/parser/text_normalizer.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/retriever.dart';
import 'package:zoe_remind/rag/search_scope.dart';

/// R5 — ang huling paghahanap ni Zoe, para maintindihan ang maikling
/// follow-up pagkatapos nito:
///
///   "ano gamot ni mama?"  → sagot
///   "eh kay papa?"        → [FollowUpKind.swap]   → "gamot papa" ang hahanapin
///   "yung isa pa"         → [FollowUpKind.more]   → ang susunod na nahanap
///   "hindi yan"           → [FollowUpKind.reject] → iba na lang (o tapat na "wala na")
///   "buksan mo"           → [FollowUpKind.open]   → bubuksan ang note / reminder / task
///
/// Nasa RAM lang (isang usapan). Isang beses lang ginagamit: kapag ibang
/// mensahe ang sumunod (hindi follow-up), nawawala na ito. R6 ang magse-save
/// ng "hindi yan" / pinindot sa phone (search_log).
class RagSession {
  RagSession({
    required this.query,
    required this.hits,
    required this.at,
    this.shown = 0,
    Set<String>? rejected,
  }) : rejected = rejected ?? <String>{};

  /// Gaano katagal pwedeng mag-follow-up pagkatapos ng sagot.
  static const ttl = Duration(minutes: 15);

  /// Ilang resulta ang tinatandaan (para sa "yung isa pa").
  static const keep = 6;

  /// Ang talagang hinanap (mga salita ni Qwen, o ang buong tanong).
  final String query;

  /// Lahat ng nahanap, pinakamagaling muna. Walang laman = walang nahanap.
  final List<RetrievalHit> hits;

  /// Kailan sinagot (para sa [ttl]).
  final DateTime at;

  /// Index sa [hits] ng ipinapakita ngayon.
  int shown;

  /// Mga sinabing "hindi yan" (`source#id`).
  final Set<String> rejected;

  bool isFresh(DateTime now) => now.difference(at) <= ttl;

  bool get hasHits => hits.isNotEmpty;

  /// Ang ipinapakita ngayon (null kapag walang nahanap).
  RetrievalHit? get current => shown >= 0 && shown < hits.length ? hits[shown] : null;

  static String keyOf(RetrievalDoc d) => '${d.source.name}#${d.id}';

  /// Index ng susunod na resulta pagkatapos ng [shown] na hindi pa sinabing
  /// "hindi yan". null = wala na.
  int? nextIndex() {
    for (var i = shown + 1; i < hits.length; i++) {
      if (!rejected.contains(keyOf(hits[i].doc))) return i;
    }
    return null;
  }

  /// Ang mga resultang natitira (hindi "hindi yan"), simula sa [from].
  List<RetrievalHit> remainingFrom(int from) => [
        hits[from],
        for (var i = 0; i < hits.length; i++)
          if (i != from && !rejected.contains(keyOf(hits[i].doc))) hits[i],
      ];

  /// Pang-ilan ang [index] sa mga hindi pa tinanggihan (1-based), at ilan lahat.
  (int, int) positionOf(int index) {
    var pos = 0;
    var total = 0;
    for (var i = 0; i < hits.length; i++) {
      if (rejected.contains(keyOf(hits[i].doc)) && i != index) continue;
      total++;
      if (i <= index) pos++;
    }
    return (pos, total);
  }
}

/// Anong klaseng follow-up.
enum FollowUpKind {
  /// "yung isa pa", "iba pa?", "may iba pa ba?", "another one", "next"
  more,

  /// "buksan mo", "open it", "patingin ng buong note", "full note"
  open,

  /// "hindi yan", "mali", "hindi yan ang hinahanap ko", "not that one"
  reject,

  /// "eh kay papa?", "yung sa bahay naman", "what about dad?", "eh yung task?"
  swap,
}

/// Resulta ng [RagFollowUp.read].
class FollowUp {
  const FollowUp(this.kind);
  final FollowUpKind kind;

  @override
  String toString() => 'FollowUp(${kind.name})';
}

/// Pure (walang database) — nate-test sa `test/rag/rag_session_test.dart`.
///
/// Lahat ng check ay sa BUONG maikling mensahe. Mahabang pangungusap o bagong
/// buong tanong ("eh saan ko nilagay yung passport?") → hindi follow-up;
/// normal na paghahanap.
class RagFollowUp {
  RagFollowUp._();

  /// Pinakamahabang follow-up (bilang ng salita).
  static const maxWords = 7;

  /// Text-speak → buong salita, maliit na titik, walang bantas / emoji.
  static String clean(String text) => TextNormalizer.normalize(text)
      .toLowerCase()
      .replaceAll(RegExp(r'[!.?,~…]+'), ' ')
      .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Pambungad na pwedeng tanggalin ("ay", "teka", "ok", "zoe"…).
  static const _lead = {
    'ay', 'ah', 'oh', 'uy', 'oy', 'hmm', 'hmmm', 'wait', 'teka', 'sorry', 'zoe', 'ok', 'okay',
    'sige', 'so', 'pero', 'but', 'actually',
  };

  /// Pampalambot sa dulo ("po", "naman", "nga", "ba", "please"…).
  static const _soft = {
    'po', 'naman', 'nga', 'pa', 'ba', 'zoe', 'please', 'pls', 'lang', 'nalang', 'na', 'din',
    'rin', 'ha', 'oh', 'eh', 'e', 'kaya', 'nyan', 'niyan', 'dyan', 'diyan',
  };

  // ── more ────────────────────────────────────────────────────────────

  static final _more = RegExp(
    r'^(?:(?:yung|yong|ung|iyong|the|an?|meron|mayroon|may)\s+)?(?:'
    r'isa pa|isa pang|isa pang note|iba pa|ibang|iba|yung iba|ibang sagot|ibang resulta'
    r'|iba naman|pangalawa|ikalawa|susunod|kasunod|next|next one|another|another one'
    r'|other one|the other one|others|the others|other|more|show more|any more|anymore'
    r'|anything else|what else|ano pa|sino pa|meron pa|mayroon pa|meron pang iba|may iba pa'
    r'|may iba|iba ka pang nakita|ibang nakita|pakita mo pa|ipakita mo pa|labas mo pa'
    r'|second one|second|ano pang iba'
    r')(?:\s+(?:pa|ba|po|naman|nga|ka|zoe|please))*$',
  );

  // ── open ────────────────────────────────────────────────────────────

  static final _openVerb = RegExp(
    r'^(?:paki-?|pa-?)?(?:buksan|bukasan|open|i-?open|patingin|tingin|pakita|ipakita'
    r'|pakitang|tingnan|tignan|view|show)$',
  );

  /// Mga salitang pwedeng kasama ng [_openVerb] ("buksan mo yung note").
  static const _openFill = {
    'mo', 'na', 'nga', 'naman', 'po', 'it', 'that', 'yan', 'yun', 'iyan', 'iyon', 'ito', 'to',
    'ang', 'yung', 'yong', 'ung', 'the', 'note', 'reminder', 'task', 'buo', 'buong', 'full',
    'whole', 'me', 'ko', 'please', 'pls', 'zoe', 'nalang', 'lang', 'sa', 'akin', 'sakin',
    'item', 'one', 'first', 'una', 'unang', 'page', 'ng', 'this', 'up',
  };

  /// "buong note" / "full note" (walang pandiwa) → open din.
  static final _openPhrase = RegExp(
    r'^(?:(?:yung|ang|the)\s+)?(?:buong note|buo|full note|whole note|full|buong reminder|buong task)$',
  );

  // ── reject ──────────────────────────────────────────────────────────

  static const _negators = {
    'hindi', 'hinde', 'indi', 'di', 'mali', 'wrong', 'not', 'no', 'nope', 'nah', 'isnt',
  };

  /// Mga salitang pwedeng kasama ng negator ("hindi yan ang hinahanap ko").
  static const _rejectFill = {
    'yan', 'yun', 'iyan', 'iyon', 'ito', 'to', 'yon', 'yung', 'ung', 'ang', 'that', 'this',
    'it', 'one', 'po', 'naman', 'eh', 'e', 'pala', 'zoe', 'ganun', 'ganon', 'ganyan',
    'hinahanap', 'hanap', 'ko', 'i', 'meant', 'mean', 'what', 'looking', 'for', 'im', 'am',
    'the', 'sagot', 'answer', 'note', 'reminder', 'task', 'ata', 'yata', 'talaga', 'sorry',
    'tinatanong', 'tanong', 'tama', 'correct', 'right', 's', 'thats', 'its', 'is', 'sa',
    'ibig', 'sabihin', 'kong', 'asked', 'ask', 'oh', 'ay', 'nope', 'quite', 'ba',
  };

  // ── swap ────────────────────────────────────────────────────────────

  /// Simula ng "eh kay papa?" / "what about dad?" / "yung sa bahay?".
  static const _swapLead = {
    'eh', 'e', 'ehh', 'tsaka', 'saka', 'paano', 'pano', 'papaano', 'panu', 'kumusta',
    'kamusta', 'and', 'also', 'yung', 'yong', 'ung', 'iyong', 'kay', 'kina', 'ni', 'nina',
    'sa', 'para', 'for', 'at',
  };

  /// Mga tanong na salita: kapag may ganito AT may bagong bagay
  /// ("eh saan ko nilagay yung passport?") → bagong tanong, hindi follow-up.
  static const _questionWords = {
    'ano', 'anong', 'saan', 'nasaan', 'kailan', 'sino', 'ilan', 'magkano', 'alin', 'bakit',
    'what', 'whats', 'where', 'when', 'who', 'which', 'why',
  };

  /// "ni mama", "kay papa", "sa bahay", "ng kotse", "of mom", "for dad" →
  /// ang susunod na salita ay "kanino / saan" (may-ari), hindi ang bagay.
  static const _ownerMarks = {
    'ni', 'kay', 'nina', 'kina', 'ng', 'sa', 'nasa', 'para', 'of', 'for', 'from', 'in',
  };

  /// Mga tao — laging "may-ari" kahit walang marker ("gamot mama", "mom's").
  static const people = {
    'mama', 'mommy', 'mommi', 'mom', 'mother', 'nanay', 'inay', 'nay', 'ina', 'ma',
    'papa', 'daddy', 'dad', 'father', 'tatay', 'itay', 'tay', 'ama', 'pa',
    'kuya', 'ate', 'bunso', 'lola', 'lolo', 'tita', 'tito', 'auntie', 'aunt', 'uncle', 'tiya',
    'tiyo', 'ninang', 'ninong', 'pinsan', 'cousin', 'kapatid', 'sister', 'brother', 'sis', 'bro',
    'asawa', 'misis', 'mister', 'hubby', 'wife', 'husband', 'jowa', 'bf', 'gf', 'boyfriend',
    'girlfriend', 'anak', 'son', 'daughter', 'baby', 'boss', 'manager', 'teacher', 'maam',
    'sir', 'doctor', 'doktor', 'dok', 'friend', 'kaibigan', 'barkada', 'bestfriend', 'bff',
    'kapitbahay', 'neighbor', 'officemate', 'classmate', 'roommate', 'landlord', 'landlady',
    'kasama', 'dentist', 'dentista', 'doc',
  };

  /// Ang mensahe ay follow-up? null = hindi (normal na reply).
  /// Hindi tinitingnan dito kung may naunang paghahanap — nasa brain iyon.
  static FollowUp? read(String text) {
    var t = clean(text);
    if (t.isEmpty) return null;
    var words = t.split(' ');
    if (words.length > maxWords + 2) return null;

    // Tanggalin ang pambungad at pampalambot.
    while (words.length > 1 && _lead.contains(words.first)) {
      words = words.sublist(1);
    }
    // "isa pa", "meron pa ba?", "may iba pa?" (bago tanggalin ang "pa" / "ba").
    if (words.length <= maxWords && _more.hasMatch(words.join(' '))) {
      return const FollowUp(FollowUpKind.more);
    }
    while (words.length > 1 && _soft.contains(words.last)) {
      words = words.sublist(0, words.length - 1);
    }
    t = words.join(' ');
    if (words.isEmpty || words.length > maxWords) return null;

    // "yung isa pa", "iba pa?", "next"
    if (_more.hasMatch(t)) return const FollowUp(FollowUpKind.more);

    // "buksan mo", "open it", "patingin ng buong note"
    final verbAt = words.length > 1 && (words.first == 'paki' || words.first == 'pa') ? 1 : 0;
    if (_openVerb.hasMatch(words[verbAt]) && words.skip(verbAt + 1).every(_openFill.contains)) {
      return const FollowUp(FollowUpKind.open);
    }
    if (_openPhrase.hasMatch(t)) return const FollowUp(FollowUpKind.open);

    // "hindi yan", "mali", "not that one", "that's not it"
    final tokens = QueryTerms.tokens(t);
    if (tokens.isNotEmpty &&
        tokens.any(_negators.contains) &&
        tokens.every((w) => _negators.contains(w) || _rejectFill.contains(w))) {
      return const FollowUp(FollowUpKind.reject);
    }

    // "eh kay papa?", "yung sa bahay naman", "what about dad?"
    if (_looksLikeSwap(text)) return const FollowUp(FollowUpKind.swap);
    return null;
  }

  /// May "eh / yung / kay / sa / what about…" sa unahan o "naman" sa dulo,
  /// maikli, may bagong salita, at hindi bagong buong tanong.
  static bool _looksLikeSwap(String text) {
    var words = clean(text).split(' ');
    while (words.length > 1 && _lead.contains(words.first)) {
      words = words.sublist(1);
    }
    if (words.isEmpty || words.length > maxWords) return false;
    final tokens = QueryTerms.tokens(words.join(' '));
    if (tokens.isEmpty) return false;

    final aboutLead = tokens.length >= 2 &&
        (tokens[0] == 'what' || tokens[0] == 'how') &&
        tokens[1] == 'about';
    final hasLead = aboutLead || _swapLead.contains(tokens.first);
    final namanTail = tokens.length >= 2 && tokens.last == 'naman';
    if (!hasLead && !namanTail) return false;

    final fresh = _words(words.join(' '));
    if (fresh.isEmpty) return false;
    // "eh saan ko nilagay yung passport?" → may tanong + bagong bagay → bagong tanong.
    final question = tokens.skip(aboutLead ? 2 : 0).any(_questionWords.contains);
    if (question && fresh.any((w) => w.slot == WordSlot.thing)) return false;
    return true;
  }

  // ── pagsasama ng tanong ─────────────────────────────────────────────

  /// Mga posibleng bagong tanong mula sa [previous] + [followUp], ang pinaka-
  /// malamang muna, walang ulit. Hinahanap lahat ng brain at ang may
  /// pinakamagandang sagot ang pinipili.
  ///
  ///   "ano gamot ni mama?"  + "eh kay papa?"     → ["gamot papa", …]
  ///   "susi ng kotse"       + "eh yung sa motor?" → ["susi motor", …]
  ///   "bayad ng kuryente"   + "eh tubig?"         → ["kuryente tubig", "bayad tubig", …]
  ///   "wifi password"       + "eh sa bahay?"      → ["wifi password bahay", …]
  ///   "may reminder ba ako tungkol sa dentist?" + "eh yung task?" → ["dentist task", …]
  ///
  /// 1. Ayon sa uri ng salita: may-ari ↔ may-ari, bagay ↔ huling bagay,
  ///    uri (reminder / task) ↔ uri. Walang kapareho → idinadagdag.
  /// 2. Huling salita ng naunang tanong ↔ bagong salita.
  /// 3. Lahat (luma + bago).
  static List<String> swapQueries(String previous, String followUp) {
    final old = _words(previous);
    final fresh = _words(followUp);
    if (fresh.isEmpty) return const [];

    final out = <String>[];
    void add(List<SlotWord> words) {
      final seen = <String>{};
      final unique = [
        for (final w in words)
          if (seen.add(QueryTerms.fold(w.text))) w.text,
      ];
      final q = unique.join(' ');
      if (q.isNotEmpty && !out.contains(q)) out.add(q);
    }

    // 1. Ayon sa uri ng salita.
    final freshSlots = {for (final w in fresh) w.slot};
    final kept = <SlotWord>[];
    final freshThings = fresh.where((w) => w.slot == WordSlot.thing).length;
    final oldThings = [for (final w in old) if (w.slot == WordSlot.thing) w];
    // Bagay: ang huling N bagay ng luma ang papalitan (N = ilang bagay ang bago).
    final dropThings = oldThings.length - freshThings < 0
        ? oldThings.toSet()
        : oldThings.sublist(oldThings.length - freshThings).toSet();
    for (final w in old) {
      if (w.slot == WordSlot.thing && dropThings.contains(w)) continue;
      if (w.slot != WordSlot.thing && freshSlots.contains(w.slot)) continue;
      kept.add(w);
    }
    // Isang salita lang ang luma (bukod sa uri) → iyon ang papalitan.
    final oldContent = old.where((w) => w.slot != WordSlot.kind).toList();
    final freshContent = fresh.where((w) => w.slot != WordSlot.kind).toList();
    if (oldContent.length == 1 &&
        freshContent.isNotEmpty &&
        kept.contains(oldContent.single)) {
      kept.remove(oldContent.single);
    }
    add([...kept, ...fresh]);

    // 2. Huling salita (hindi uri) ng luma ↔ bago.
    if (oldContent.isNotEmpty && freshContent.isNotEmpty) {
      final last = oldContent.last;
      add([for (final w in old) if (!identical(w, last)) w, ...fresh]);
    }

    // 3. Lahat.
    add([...old, ...fresh]);
    return out;
  }

  /// Mga salitang may laman ng [text], may uri (may-ari / bagay / uri ng item).
  static List<SlotWord> _words(String text) {
    final tokens = QueryTerms.rawTokens(clean(text));
    final out = <SlotWord>[];
    var owner = false;
    for (var i = 0; i < tokens.length; i++) {
      final key = QueryTerms.fold(tokens[i]);
      if (_ownerMarks.contains(key)) {
        // "tungkol sa dentist" / "about the dentist" → paksa, hindi may-ari.
        final before = i > 0 ? QueryTerms.fold(tokens[i - 1]) : '';
        owner = before != 'tungkol' && before != 'about';
        continue;
      }
      if (SearchScope.kindWords.containsKey(key)) {
        out.add(SlotWord(key, WordSlot.kind));
        owner = false;
        continue;
      }
      if (!_isContent(key)) continue;
      out.add(SlotWord(
        tokens[i],
        owner || people.contains(key) ? WordSlot.owner : WordSlot.thing,
      ));
      owner = false;
    }
    return out;
  }

  static bool _isContent(String key) =>
      key.length >= 2 &&
      !QueryTerms.stopWords.contains(key) &&
      !Retriever.weakWords.contains(key) &&
      !_lead.contains(key) &&
      !_soft.contains(key) &&
      !_swapLead.contains(key) &&
      !_questionWords.contains(key) &&
      !const {'how', 'naman', 'ano', 'pano', 'kaya', 'ganun', 'din', 'rin', 'same'}.contains(key);
}

/// Uri ng salita sa tanong (para sa [RagFollowUp.swapQueries]).
enum WordSlot {
  /// Ang hinahanap: "gamot", "susi", "password".
  thing,

  /// Kanino / saan: "mama" (ni mama), "kotse" (ng kotse), "bahay" (sa bahay).
  owner,

  /// Uri ng item: "reminder", "task", "note".
  kind,
}

/// Isang salita + ang uri nito.
class SlotWord {
  const SlotWord(this.text, this.slot);
  final String text;
  final WordSlot slot;

  @override
  String toString() => '$text(${slot.name})';
}