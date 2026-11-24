/// Level 3 Companion memory — anong klaseng memory ito? (pure, walang database)
/// Nate-test sa `flutter test test/memory/companion_facts_test.dart`.
///
/// Iisang store pa rin ang memories table (B5). Ang `kind` lang ang
/// nagsasabi kung para saan ang memory:
///
///   "call me AC" / "tawagin mo akong AC"         → nickname     (isa lang)
///   "diretsuhin mo lang ako" / "be gentle"       → style        (isa lang)
///   "kapag stressed ako, makinig ka muna"        → stress_help  (isa lang)
///   "tandaan mo, nakapasa ako sa board exam"     → win          (marami)
///   "tandaan mo, nag-gy-gym ako tuwing MWF"      → routine      (marami)
///   "tandaan mo na mas gusto ko ng morning…"     → general      (marami)
///
/// Kung ano lang ang SINABI ng user ang nase-save — walang hula, walang
/// personality label ("moody ka" ❌). Laging may confirm card muna.
enum FactKind {
  general('general'),
  nickname('nickname'),
  style('style'),
  stressHelp('stress_help'),
  win('win'),
  routine('routine');

  const FactKind(this.db);

  /// Ang naka-save sa `memories.kind`.
  final String db;

  /// Isa lang ang pwede (bagong sabi = palit sa luma).
  bool get single => this == nickname || this == style || this == stressHelp;

  static FactKind fromDb(String? s) =>
      FactKind.values.firstWhere((k) => k.db == s, orElse: () => FactKind.general);
}

/// Paano kakausapin ni Zoe ang user.
enum TalkStyle {
  diretso('diretso'),
  malambing('malambing');

  const TalkStyle(this.value);
  final String value;

  static TalkStyle? fromValue(String? s) {
    for (final t in TalkStyle.values) {
      if (t.value == s) return t;
    }
    return null;
  }
}

/// Ano'ng nakakatulong kapag stressed / down ang user.
/// Pareho sa ZoeHope: makinig / payo / pampagaan.
enum StressHelp {
  listen('listen'),
  advice('advice'),
  lighten('lighten');

  const StressHelp(this.value);
  final String value;

  static StressHelp? fromValue(String? s) {
    for (final h in StressHelp.values) {
      if (h.value == s) return h;
    }
    return null;
  }
}

/// Resulta ng [CompanionFacts.read]: anong kind + ang value (kung meron).
///   nickname    → value = "AC"
///   style       → value = "diretso" / "malambing"
///   stress_help → value = "listen" / "advice" / "lighten"
///   win / routine / general → value = null (ang content mismo ang memory)
class FactRead {
  const FactRead(this.kind, [this.value]);

  final FactKind kind;
  final String? value;

  @override
  bool operator ==(Object other) =>
      other is FactRead && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => 'FactRead(${kind.db}, $value)';
}

class CompanionFacts {
  CompanionFacts._();

  /// Pinakamahabang nickname.
  static const maxNickname = 24;

  // ── nickname ──────────────────────────────────────────────────────────
  // Hindi kasama ang "call me later / at 7 / tomorrow…".
  static const _notName =
      r'(?!(?:later|tomorrow|back|when|if|at|tonight|maybe|now|asap|again|in|on|after|na|lang'
      r'|ano|anong|sino|paano|bakit|ang|yan|iyan|ito|to|you|your|me|ako|ko|mo|po)\b)';

  static final _nickPatterns = <RegExp>[
    RegExp(r"\bcall\s+me\s+" + _notName + r"([a-z0-9][a-z0-9 .'-]*)", caseSensitive: false),
    RegExp(r"\btawagin\s+(?:mo\s+)?(?:na\s+lang\s+)?(?:akong|ako)\s+(?:na\s+)?" + _notName +
        r"([a-z0-9][a-z0-9 .'-]*)",
        caseSensitive: false),
    RegExp(r"\b" + _notName +
        r"([a-z0-9][a-z0-9.'-]*)\s+(?:na\s+lang\s+)?(?:ang\s+)?(?:itawag|tawag|itatawag|itawag\s+mo\s+na)\s+(?:mo\s+)?(?:sa\s+akin|sakin)",
        caseSensitive: false),
    RegExp(r"\bmy\s+name\s+is\s+([a-z][a-z0-9 .'-]*)", caseSensitive: false),
    RegExp(r"\b(?:ang\s+)?pangalan\s+ko\s+ay\s+([a-z][a-z0-9 .'-]*)", caseSensitive: false),
  ];

  /// Mga salitang tinatanggal sa dulo ng nickname ("AC na lang po" → "AC").
  static final _nickTail = RegExp(
    r"[\s,.!?]*\b(?:na\s+lang|lang|po|please|pls|zoe|ha|okay|ok|from\s+now\s+on|simula\s+ngayon"
    r"|thanks|thank\s+you|salamat|ty|nga|naman|haha\w*|hehe\w*|beh|sana|always|lagi|ah|eh)\b.*$",
    caseSensitive: false,
  );

  /// "Call me AC" → "AC". Walang nickname → null.
  static String? nicknameFrom(String text) {
    for (final p in _nickPatterns) {
      final m = p.firstMatch(text);
      if (m == null) continue;
      var name = m.group(1)!.replaceFirst(_nickTail, '');
      name = name.replaceAll(RegExp(r"[\s,.!?'-]+$"), '').trim();
      // isang tao lang, hindi buong pangungusap
      final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (words.isEmpty || words.length > 3) continue;
      name = words.join(' ');
      if (name.length > maxNickname) name = name.substring(0, maxNickname).trim();
      // Kung paano tinype ("AC", "JM", "Pao") — iyon ang susundin.
      if (name != name.toLowerCase()) return name;
      // lahat maliit: "ac" → "AC" (2 letra = initials), "aaron" → "Aaron"
      if (name.length <= 2) return name.toUpperCase();
      return name[0].toUpperCase() + name.substring(1);
    }
    return null;
  }

  // ── style ─────────────────────────────────────────────────────────────
  static final _diretso = RegExp(
    r'\b(?:diretsuhin|deretsuhin|diretsahin|derechuhin)\s+mo\b'
    r'|\b(?:diretso|deretso|direcho|diretsahan|deretsahan|diretsohan)\s+(?:ka|mo|lang|na\s+lang)\b'
    r'|\b(?:be|just\s+be)\s+(?:direct|straight\s+(?:up|with\s+me)|blunt)\b'
    r'|\bstraight\s+to\s+the\s+point\b|\bstraight\s+with\s+me\b|\btell\s+me\s+straight\b'
    r'|\b(?:short|maikli(?:ng)?)\s+(?:answers?|replies|sagot)\b'
    r'|\bkeep\s+(?:it|your\s+(?:answers?|replies|messages))\s+short\b'
    r'|\b(?:huwag|wag)\s+(?:mo\s+)?(?:na\s+)?(?:akong\s+)?(?:i-?)?baby\b'
    r"|\bno\s+sugarcoating\b|\b(?:huwag|wag)\s+mo\s+(?:nang\s+|na\s+)?(?:i-?)?sugarcoat\b"
    r"|\bdon'?t\s+sugarcoat\b",
    caseSensitive: false,
  );

  static final _malambing = RegExp(
    r'\bmalambing\b|\blambingin\s+mo\b|\bmaging\s+(?:mabait|malumanay|mahinahon)\b'
    r'|\bmahinahon\s+(?:ka|lang)\b'
    r'|\b(?:be|just\s+be)\s+(?:gentle|soft|sweet|kind)\b|\bgentle\s+(?:ka|lang|with\s+me)\b'
    r'|\bgo\s+easy\s+on\s+me\b|\btalk\s+to\s+me\s+gently\b'
    r'|\bdahan[\s-]?dahan\s+(?:ka\s+)?(?:lang\s+)?(?:sa\s+akin|sakin)\b',
    caseSensitive: false,
  );

  static TalkStyle? styleFrom(String text) {
    final d = _diretso.hasMatch(text);
    final m = _malambing.hasMatch(text);
    if (d == m) return null; // wala, o parehong nabanggit → hindi sigurado
    return d ? TalkStyle.diretso : TalkStyle.malambing;
  }

  // ── stress help ───────────────────────────────────────────────────────
  static final _whenDown = RegExp(
    r'\b(?:kapag|kung|pag|pag-?|when(?:ever)?|if)\s+(?:i\s+am\s+|i\x27?m\s+|im\s+|ako\s+ay\s+)?'
    r'(?:[\w-]+\s+){0,2}(?:stressed|stress|pagod|down|malungkot|sad|anxious|overwhelmed|burnout|burned\s+out|nalulungkot|napapagod|na-?stress)\b',
    caseSensitive: false,
  );

  static final _listen = RegExp(
    r'\bmakinig\b|\bpakinggan\b|\blisten\b|\bhear\s+me\s+out\b|\bmagkwento\b|\bmag-?vent\b|\bvent\b'
    r'|\bmakikinig\b',
    caseSensitive: false,
  );
  static final _advice =
      RegExp(r'\bpayo\b|\bpayuhan\b|\badvice\b|\badvise\s+me\b|\btips?\b|\bsolusyon\b|\bsolutions?\b',
          caseSensitive: false);
  static final _lighten = RegExp(
    r'\bpampagaan\b|\bpagaanin\b|\bjokes?\b|\bpatawa(?:hin|nin)?\b|\b(?:mag|bumi)?biro\b|\bcheer\s+me\s+up\b'
    r'|\bpasayahin\b|\bmake\s+me\s+(?:laugh|smile)\b|\bpangitiin\b',
    caseSensitive: false,
  );

  static StressHelp? stressHelpFrom(String text) {
    if (!_whenDown.hasMatch(text)) return null;
    final found = <StressHelp>[
      if (_listen.hasMatch(text)) StressHelp.listen,
      if (_advice.hasMatch(text)) StressHelp.advice,
      if (_lighten.hasMatch(text)) StressHelp.lighten,
    ];
    return found.length == 1 ? found.first : null;
  }

  // ── wins / routines ───────────────────────────────────────────────────
  static final _win = RegExp(
    r'\bnatapos\s+ko\b|\bnakapasa\s+ako\b|\bpumasa\s+ako\b|\bnanalo\s+ako\b|\bnatanggap\s+ako\b'
    r'|\bna-?promote\s+ako\b|\bgraduate\s+na\s+ako\b|\bnag-?graduate\s+ako\b'
    r'|\bi\s+(?:passed|finished|won|graduated|got\s+(?:the|a)\s+job|got\s+promoted|got\s+hired)\b'
    r"|\bi'?ve\s+(?:passed|finished|graduated)\b",
    caseSensitive: false,
  );

  static final _routine = RegExp(
    r'\btuwing\b|\baraw-?araw\b|\bgabi-?gabi\b|\bumaga-?umaga\b|\blinggo-?linggo\b'
    r'|\bevery\s+(?:day|morning|night|evening|week|weekend|mon|tue|wed|thu|fri|sat|sun)\w*'
    r'|\b(?:i|ako)\s+(?:usually|always)\b|\busually\s+(?:i|ako)\b|\blagi\s+akong\b'
    r'|\bgumigising\s+ako\b|\bi\s+wake\s+up\b|\bnatutulog\s+ako\b|\bi\s+sleep\s+at\b',
    caseSensitive: false,
  );

  /// Anong klaseng memory ang [text]? Tinitingnan ang buong mensahe ng user
  /// (o ang na-extract na content) — pareho lang ang sagot.
  static FactRead read(String text) {
    final nick = nicknameFrom(text);
    if (nick != null) return FactRead(FactKind.nickname, nick);
    final help = stressHelpFrom(text);
    if (help != null) return FactRead(FactKind.stressHelp, help.value);
    final style = styleFrom(text);
    if (style != null) return FactRead(FactKind.style, style.value);
    if (_win.hasMatch(text)) return const FactRead(FactKind.win);
    if (_routine.hasMatch(text)) return const FactRead(FactKind.routine);
    return const FactRead(FactKind.general);
  }

  /// Sagot sa tanong ni Zoe na "Kapag stressed ka, ano'ng nakakatulong?"
  /// (hindi na kailangan ng "kapag stressed"): "makinig ka lang" → listen.
  /// Dalawa o wala → null.
  static StressHelp? helpChoice(String text) {
    final found = <StressHelp>[
      if (_listen.hasMatch(text)) StressHelp.listen,
      if (_advice.hasMatch(text)) StressHelp.advice,
      if (_lighten.hasMatch(text)) StressHelp.lighten,
    ];
    return found.length == 1 ? found.first : null;
  }

  /// Tanong ("…?", "ba", "ano", "paano", "what", "how", "any").
  static final _asks =
      RegExp(r'\?|\b(?:ba|ano|anong|paano|what|how|any|do\s+you\s+have)\b', caseSensitive: false);

  static final _soon =
      RegExp(r'\b(?:bukas|tomorrow|mamaya|mamayang|tonight|ngayong\s+gabi)\b|\blater\s+today\b');

  static final _remindVerb = RegExp(
    r'\b(?:remind(?:ed|ing)?|i-?remind|pa-?remind|paremind|paalalahanan|ipaalala|pinapaalala'
    r'|gisingin|ginigising|gigisingin|wake\s+me|waking\s+me|alarm)\b',
  );

  /// Para sa ChatRouter: pahayag ba ito ng Level 3 fact? [lower] = maliit na titik.
  ///   • nickname / style / stress help → oo, kahit walang "tandaan mo"
  ///   • win / routine → kailangan ng "tandaan mo / remember" ([hasTrigger]),
  ///     walang utos na magpaalala, at walang "bukas / mamaya"
  /// Tanong ("ano tawag mo sa akin?") → hindi (walang tumatamang pattern).
  /// Stress help na tanong ("may tips ka ba kapag stressed ako?") → hindi.
  static bool isStatement(String lower, {required bool hasTrigger}) {
    if (_remindVerb.hasMatch(lower) || _soon.hasMatch(lower)) return false;
    if (nicknameFrom(lower) != null) return true;
    // "may tips ka ba kapag stressed ako?" → humihingi ng tips ngayon, hindi kagustuhan.
    if (stressHelpFrom(lower) != null) return !_asks.hasMatch(lower);
    if (styleFrom(lower) != null) return true;
    if (!hasTrigger) return false;
    return _win.hasMatch(lower) || _routine.hasMatch(lower);
  }

  /// Ang isusulat sa memory card para sa nickname / style / stress help
  /// (malinaw at pare-pareho, para madaling basahin sa Settings).
  /// Win / routine / general → null (ang sinabi ng user ang gagamitin).
  static String? cardText(FactRead r, {required bool tagalog}) {
    switch (r.kind) {
      case FactKind.nickname:
        return tagalog ? 'Tawagin akong ${r.value}' : 'Call me ${r.value}';
      case FactKind.style:
        return switch (TalkStyle.fromValue(r.value)) {
          TalkStyle.diretso =>
            tagalog ? 'Diretsuhin mo lang ako (maikli, walang paligoy)' : 'Be direct with me (short answers)',
          TalkStyle.malambing =>
            tagalog ? 'Maging malambing ka sa akin' : 'Be gentle with me',
          null => null,
        };
      case FactKind.stressHelp:
        return switch (StressHelp.fromValue(r.value)) {
          StressHelp.listen =>
            tagalog ? 'Kapag stressed ako, makinig ka muna' : "When I'm stressed, listen first",
          StressHelp.advice =>
            tagalog ? 'Kapag stressed ako, bigyan mo ako ng payo' : "When I'm stressed, give me advice",
          StressHelp.lighten =>
            tagalog ? 'Kapag stressed ako, patawanin mo ako' : "When I'm stressed, cheer me up",
          null => null,
        };
      case FactKind.win:
      case FactKind.routine:
      case FactKind.general:
        return null;
    }
  }

  /// Settings label ng bawat kind.
  static String label(FactKind kind, {required bool tagalog}) => switch (kind) {
        FactKind.nickname => tagalog ? 'Tawag sa iyo' : 'What to call you',
        FactKind.style => tagalog ? 'Paano ka kausapin' : 'How to talk to you',
        FactKind.stressHelp => tagalog ? 'Kapag stressed ka' : 'When you\'re stressed',
        FactKind.win => tagalog ? 'Mga panalo mo' : 'Your wins',
        FactKind.routine => tagalog ? 'Mga routine mo' : 'Your routines',
        FactKind.general => tagalog ? 'Iba pa' : 'Other things',
      };
}