import 'package:zoe_remind/ai/parser/intent_classifier.dart';

/// Isang rule: kapag tumama ang [pattern] sa mensahe → [intent].
class _Rule {
  _Rule(this.intent, String pattern, {this.statementOnly = false, this.questionOnly = false})
      : regex = RegExp(pattern);

  final ZoeIntent intent;
  final RegExp regex;

  /// Para lang sa pahayag ("kailangan kong…"), hindi sa tanong.
  final bool statementOnly;

  /// Para lang sa tanong ("may meeting ba ako?"), hindi sa pahayag.
  final bool questionOnly;
}

/// Mabilis na hula ng CODE kung ano ang gusto ng user — walang Qwen, kaya agad.
///
/// Pure function ito (walang database, walang model), kaya nate-test sa
/// `flutter test test/ai/intent_rules_test.dart` kahit walang phone.
///
/// Mahalaga ang PAGKAKASUNOD ng rules: ang unang tumama ang panalo.
///   1. Malinaw na utos (note / reminder)      "i-note mo…", "gisingin mo ako…"
///   2. Tanong tungkol sa na-save              "naaalala mo ba…"
///   3. "Tandaan mo…"                          → note
///   4. Pahayag na may kailangan gawin / oras  → task / reminder
///   5. Tanong tungkol sa sariling data        na-miss, tapos, schedule
///   6. Bati
/// Walang tumama → [ZoeIntent.unknown] → si Qwen ang tatanungin.
class IntentRules {
  IntentRules._();

  static final _question = RegExp(
    r'\?|\bba(ng)?\b'
    r"|^(zoe[, ]+)?(ano|anong|ano'ng|what|what's|whats|saan|nasaan|where|kailan|when"
    r'|sino|who|bakit|why|paano|how|ilan|magkano|alin|which)\b'
    r'|^(zoe[, ]+)?((do|did|have|can|could|will|should) (i|you|we)|am i|is|are)\b',
  );

  /// true = mukhang tanong ang mensahe.
  static bool isQuestion(String lower) => _question.hasMatch(_clean(lower));

  /// Maliit na titik, isang space lang sa pagitan ng mga salita.
  static String _clean(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static final _rules = <_Rule>[
    // 1) Malinaw na utos na mag-note.
    _Rule(ZoeIntent.createNote, r'i-?note|i-?save|\bas (a )?note\b|\bnote:|\b(add|new) (a )?note\b'),

    // 2) Malinaw na utos na magpaalala.
    _Rule(ZoeIntent.createReminder, r'remind|paalala'),
    _Rule(ZoeIntent.createReminder, r'\bgisingin\b|\bwake me\b'),
    _Rule(ZoeIntent.createReminder, r'\b(sabihan|abisuhan|i-?alert) mo (ako|ko)\b'),
    _Rule(ZoeIntent.createReminder, r"\b(huwag|wag) mo(ng)? (akong )?kalimutan|\bdon'?t let me forget\b"),
    _Rule(ZoeIntent.createReminder, r'\bset (an? |the )?(alarm|reminder)\b|\b(mag|i)-?alarm\b'),

    // 3) Tanong tungkol sa sinabi / na-save dati.
    _Rule(ZoeIntent.searchNotes, r'\b(na)?aalala mo\b|\bnatatandaan mo\b|\btanda mo pa\b'),
    _Rule(ZoeIntent.searchNotes, r'\bdo you (still )?remember\b|\bi told you\b|\bsinabi ko sa\b'),
    _Rule(ZoeIntent.searchNotes, r'\bwhat was (my|the)\b|\b(ano|saan|nasaan) (na )?nga\b'),

    // 4) "Tandaan mo…" at mga kahawig → note.
    _Rule(ZoeIntent.createNote, r'\b(paki[ -]?)?tandaan mo\b|\bisulat mo\b|\bi-?lista mo\b'),
    _Rule(ZoeIntent.createNote, r'\bremember (that|this)\b|\b(write|jot) (this|it|that) down\b'),
    _Rule(ZoeIntent.createNote, r'\bkeep this\b|\bsave (this|it)\b|\btake note\b'),

    // 5) Mga dating keyword.
    _Rule(ZoeIntent.createReminder, r'alarm'),
    _Rule(ZoeIntent.createTask, r'task|todo|to-do|gawain'),

    // 6) Pahayag na may kailangang gawin → task.
    _Rule(ZoeIntent.createTask, r'\b(kailangan|kelangan|need) ko(ng)?\b|\bdapat (ko(ng)?|akong)\b',
        statementOnly: true),
    _Rule(ZoeIntent.createTask, r"\bi (need|have|got) to\b|\bi (must|should|gotta)\b|\bi'?ve got to\b",
        statementOnly: true),

    // 7) Pahayag na may oras ("meeting kay boss 3pm bukas") → reminder.
    _Rule(ZoeIntent.createReminder, r'\b\d{1,2}(:\d{2})? ?([ap]m\b|[ap]\.m\.)',
        statementOnly: true),
    _Rule(ZoeIntent.createReminder, r'\balas[ -]?\d{1,2}\b|\b([01]?\d|2[0-3]):[0-5]\d\b',
        statementOnly: true),

    // 8) Ano ang na-miss.
    _Rule(ZoeIntent.getMissed, r'\b(na-?)?miss(ed)?\b|nakalimutan|nalimutan|nakaligtaan'),
    _Rule(ZoeIntent.getMissed, r'nalampasan|nalagpasan|overdue'),
    _Rule(ZoeIntent.getMissed, r'\b(hindi|di) ko (pa )?(na)?gawa\b'),
    _Rule(ZoeIntent.getMissed, r'\bdid i (forget|miss|skip)\b|\banything i (forgot|missed|skipped)\b'),

    // 9) Ano ang natapos.
    _Rule(ZoeIntent.getDone, r'kahapon|yesterday|ginawa|what did i do|natapos'),
    _Rule(ZoeIntent.getDone, r'\btapos (ko |na )|\bnagawa ko\b|\bna-?accomplish'),
    _Rule(ZoeIntent.getDone, r'\b(finished|completed|accomplished|wrapped up)\b|\bdone so far\b'),
    _Rule(ZoeIntent.getDone, r'\b(have|did) i (done|do|finish|complete)\b'),

    // 10) Ano ang naka-schedule.
    _Rule(ZoeIntent.getToday, r'today|ngayon|gagawin|schedule'),
    _Rule(ZoeIntent.getToday, r'\b(busy|free|libre|bakante) ba\b|\bam i (busy|free)\b'),
    _Rule(
        ZoeIntent.getToday,
        r'\b(may|meron|merong|mayroon|mayroong) (ba )?(ako |akong )?'
        r'(lakad|pasok|meeting|appointment|plano|sched|event)',
        questionOnly: true),
    _Rule(ZoeIntent.getToday, r"\bwhat'?s (on|planned|next)\b|\bdo i have (anything|something|plans)\b"),
    _Rule(ZoeIntent.getToday, r'\banything (planned|scheduled|lined up|coming up)\b|\bagenda\b'),

    // 11) "ano locker code ko?", "what's my wifi password?", "saan ko nilagay ang susi?"
    _Rule(
        ZoeIntent.searchNotes,
        r"^(zoe[, ]+)?(ano|anong|ano'ng|what|what's|whats|saan|nasaan|where|kailan|when"
        r'|sino|who|magkano|ilan|alin|which)\b(?=.*\b(ko|my|akin|ako)\b)'),

    // 12) Bati.
    _Rule(ZoeIntent.greeting, r'\b(hi|hello|hey|kumusta|kamusta|musta|uy|oy|hoy)\b'),
    _Rule(ZoeIntent.greeting, r'\bgood (morning|afternoon|evening|night|day)\b'),
    _Rule(ZoeIntent.greeting, r'\bmagandang (umaga|tanghali|hapon|gabi|araw)\b'),
    _Rule(ZoeIntent.greeting, r'\bgising ka (pa|na)\b|\b(nandyan|andyan|nandiyan) ka\b'),
  ];

  /// Ang hula ng code. [ZoeIntent.unknown] = walang tumama (ipasa kay Qwen).
  static ZoeIntent match(String text) {
    final lower = _clean(text);
    if (lower.isEmpty) return ZoeIntent.unknown;
    final question = _question.hasMatch(lower);

    for (final rule in _rules) {
      if (rule.statementOnly && question) continue;
      if (rule.questionOnly && !question) continue;
      if (rule.regex.hasMatch(lower)) return rule.intent;
    }
    return ZoeIntent.unknown;
  }

  static final _stopAlarm = RegExp(
    r'\b(patayin|pinatay|i-?off|itigil|ihinto|tanggalin|turn off|switch off|stop|cancel'
    r'|disable|silence|mute)\b.*\balarm'
    r'|\balarm\b.*\b(off|patayin|itigil|ihinto)\b',
  );

  /// "patayin mo ang alarm", "turn off the alarm" — HINDI ito bagong reminder.
  /// Chine-check ito bago ang [match], dahil may salitang "alarm".
  static bool isStopAlarm(String text) => _stopAlarm.hasMatch(_clean(text));

  static final _feelingWord = RegExp(
    r'\b(pagod|napapagod|nakakapagod|malungkot|nalulungkot|nahihirapan|kinakabahan'
    r'|stressed|na-?stress|nai-?stress|nag-?iisa|tired|exhausted|sad|lonely|burned out'
    r'|burnt out|overwhelmed|anxious|depressed)\b',
  );
  static final _aboutMe = RegExp(r"\b(ako|ko|akong|i'?m|i am|i feel|feeling)\b");

  /// "hindi ako pagod", "di naman ako stressed", "I'm not tired".
  /// Tinitingnan ang text BAGO ang salitang nararamdaman (gaya ng ToneDetector).
  static final _negatedBefore = RegExp(
    r"(^|\s)(hindi|hinde|di|'di|not|never|no|don'?t|isn'?t|wasn'?t|ain'?t)\s+"
    r"((naman|na|ako|ko|i|am|im|i'm|really|so|very|masyado|gaano|feel|feeling)\s+){0,3}$",
  );

  /// "pagod na ako", "I'm so tired" — nagkukuwento lang ng nararamdaman.
  /// Ginagamit lang kapag WALANG tumamang rule sa [match], kaya ang
  /// "remind me to rest, pagod ako" ay reminder pa rin.
  /// "hindi ako pagod" → false (may negation bago ang salita).
  static bool isFeeling(String text) {
    final lower = _clean(text);
    if (!_aboutMe.hasMatch(lower)) return false;
    for (final m in _feelingWord.allMatches(lower)) {
      if (!_negatedBefore.hasMatch(lower.substring(0, m.start))) return true;
    }
    return false;
  }
}