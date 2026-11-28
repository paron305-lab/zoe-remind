import 'package:zoe_remind/ai/parser/intent_classifier.dart';
import 'package:zoe_remind/ai/parser/text_normalizer.dart';

/// Isang rule: kapag tumama ang [pattern] sa mensahe → [intent].
class _Rule {
  _Rule(this.intent, String pattern,
      {this.statementOnly = false, this.questionOnly = false, this.sure = true})
      : regex = RegExp(pattern);

  final ZoeIntent intent;
  final RegExp regex;

  /// Para lang sa pahayag ("kailangan kong…"), hindi sa tanong.
  final bool statementOnly;

  /// Para lang sa tanong ("may meeting ba ako?"), hindi sa pahayag.
  final bool questionOnly;

  /// false = mahinang palatandaan lang ("meeting 3pm bukas", "kailangan kong…",
  /// "task") → TATANUNGIN muna ni Zoe kung reminder / task / note ba,
  /// hindi agad gagawa ng card. true = malinaw na utos ("remind me…").
  final bool sure;
}

/// Resulta ng [IntentRules.matchFull].
class IntentMatch {
  const IntentMatch(this.intent, {this.sure = true});

  final ZoeIntent intent;

  /// false = hula lang (tanungin muna ang user bago gumawa ng card).
  final bool sure;
}

/// Mabilis na hula ng CODE kung ano ang gusto ng user — walang Qwen, kaya agad.
///
/// Pure function ito (walang database, walang model), kaya nate-test sa
/// `flutter test test/ai/intent_rules_test.dart` kahit walang phone.
///
/// Mahalaga ang PAGKAKASUNOD ng rules: ang unang tumama ang panalo.
///   0. Tanong tungkol sa sariling listahan   "ano mga reminders ko?" (hindi gagawa)
///      Utos na maghanap                       "hanapin mo yung note ko…"
///   1. Malinaw na utos (note / reminder / task) "i-note mo…", "remind me…", "add task…"
///   2. Tanong tungkol sa na-save              "naaalala mo ba…"
///   3. "Tandaan mo…"                          → note
///   4. Pahayag na may kailangan gawin / oras  → task / reminder (HINDI sigurado)
///   5. Tanong tungkol sa sariling data        na-miss, tapos, schedule
///   6. Bati
/// Walang tumama → [ZoeIntent.unknown] → si Qwen ang tatanungin.
///
/// Sigurado vs hula ([IntentMatch.sure]):
///   "remind me bukas 7pm…", "add task…", "set alarm 6am"   → sigurado → card
///   "meeting kay boss 3pm bukas", "kailangan kong…", "task" → hula → tanong muna
///
/// Text-speak ("pls rmnd me 2mrw") ay inaayos muna ng [TextNormalizer].
class IntentRules {
  IntentRules._();

  static final _question = RegExp(
    r'\?|\bba(ng)?\b'
    '|$_lead' r"(ano|anong|ano'ng|what|what's|whats|saan|san|nasaan|where|kailan|when"
    r'|sino|who|bakit|why|paano|how|ilan|magkano|alin|which)\b'
    '|$_lead' r'((do|did|have|can|could|will|should) (i|you|we)|am i|is|are)\b',
  );

  /// true = mukhang tanong ang mensahe.
  static bool isQuestion(String lower) => _question.hasMatch(_clean(lower));

  /// Text-speak → buong salita, maliit na titik, isang space lang.
  static String _clean(String text) =>
      TextNormalizer.normalize(text).toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Mga reminder / task / alarm (para sa tanong tungkol sa sariling listahan).
  static const _items = r'\b(reminders?|alarms?|tasks?|to-?dos?|gawain|paalala)\b';

  /// Utos na gumawa — kapag meron nito, HINDI ito tanong tungkol sa listahan.
  /// "pwede mo ba akong i-remind…", "can you set a reminder…"
  static const _create = r'\bremind (me|ako|mo)\b|\b(i|pa|ipa|paki)[- ]?remind\b|\bparemind\b'
      r'|\bset\b|\b(mag|i|pa)-?set\b|\badd\b|\b(mag|i|pa)-?add\b|\bcreate\b|\bmake\b|\bgumawa\b'
      r'|\bgawa(n|in)? (mo|ka)\b|\bgisingin\b|\bwake me\b|\bpaalalahanan\b|\bipaalala\b'
      r'|\b(i|ma|mag)?takda\b|\blagay\b|\bilagay\b|\b(i)?dagdag\b';

  /// Mga pambungad bago ang utos: "zoe,", "hey zoe,", "hi zoe!", "please", "uy"…
  static const _lead = r'^(?:(?:zoe|hey|hi|hello|uy|oy|yo|beh|please|ok|okay|sige)[,!.]*\s+)*';

  /// Araw / oras sa mensahe (para sa "alarm bukas", "paalala 7am…").
  static const _when = r'\d|\b(bukas|mamaya|mamayang|ngayon|ngayong|tonight|tomorrow|later|today'
      r'|lunes|martes|miyerkules|huwebes|biyernes|sabado|linggo|monday|tuesday|wednesday'
      r'|thursday|friday|saturday|sunday|umaga|tanghali|hapon|gabi|morning|evening'
      r'|next|susunod|every|everyday|daily|araw-araw|kada|bawat)\b';

  /// Na-miss / hindi nagawa.
  static const _missedWords = r'\b(na-?)?miss(ed)?\b|nakalimutan|nalimutan|nakaligtaan'
      r'|nalampasan|nalagpasan|overdue|\bskipped\b|\b(hindi|di) ko (pa )?(na)?gawa\b';

  /// Natapos / nagawa.
  static const _doneWords =
      r'\b(natapos|tapos|nagawa|ginawa|done|finish(ed)?|complete(d)?|accomplish(ed)?|get done|got done)\b';

  static final _rules = <_Rule>[
    // 0) TANONG tungkol sa sariling reminders / tasks → sagot, HINDI bagong item.
    //    "ano mga reminders ko bukas?", "may alarm ba ako bukas?",
    //    "anong tasks ko today?", "may na-miss ba akong reminder?"
    //    Pero "pwede mo ba akong i-remind…" → reminder pa rin (may [_create]).
    _Rule(ZoeIntent.getMissed, '^(?!.*($_create))(?=.*$_items)(?=.*($_missedWords))',
        questionOnly: true),
    _Rule(ZoeIntent.getDone, '^(?!.*($_create))(?=.*$_items)(?=.*$_doneWords)',
        questionOnly: true),
    _Rule(ZoeIntent.getToday, '^(?!.*($_create))(?=.*$_items)', questionOnly: true),
    // "show my reminders", "ipakita mo ang mga task ko" (utos, hindi tanong)
    _Rule(ZoeIntent.getToday, '^(?!.*($_create)).*\\b(show|list|ipakita|pakita)\\b.*$_items'),

    // 0b) Utos na maghanap sa notes (bago ang "note" rules).
    //    "hanapin mo yung note ko about wifi", "find my note about the wifi"
    _Rule(ZoeIntent.searchNotes,
        r'\b(hanapin|hanap|paki-?hanap|i-?search|search|find|look up|lookup|check)\b.*\b(notes?|sinabi|na-?save'
        r'|saved|password|passcode|code|pin|number|address|plate|locker)\b'),

    // 1) Malinaw na utos na mag-note.
    _Rule(ZoeIntent.createNote,
        r'i-?note|i-?save|\bas (a )?note\b|\bnote:|\b(add|new) (a )?note\b|\bpa-?note\b'
        r'|\bsave (mo|ko|this|it)\b|\bnote (mo|this|it)\b'),

    // 2) Malinaw na utos na magpaalala (sigurado).
    _Rule(ZoeIntent.createReminder,
        r'\bremind (me|ako|mo|kami|us)\b|\b(i|pa|ipa|paki)[- ]?remind\b|\bparemind\b'
        r'|\bpaalalahanan\b|\bipaalala\b|\bpaalala(han)? mo\b'),
    // "paalala bukas 7am: …", "reminder 5pm inom gamot" — utos na may oras / araw.
    _Rule(ZoeIntent.createReminder, '$_lead(paalala|reminder|remind)\\b(?=.*($_when))'),
    // "make a reminder…", "create an alarm…", "gumawa ka ng paalala…"
    _Rule(ZoeIntent.createReminder,
        r'\b(make|create|add|new|gumawa|gawa|gawan)\b( (ka|mo|ako|nga|naman|po))*( (an?|the|ng|na))? '
        r'(reminder|alarm|paalala)\b'),
    _Rule(ZoeIntent.createReminder,
        r'\bgisingin\b|\bwake me\b|\bpaki-?gising\b|\bgising(in)? mo (ako|ko|kami)\b'),
    _Rule(ZoeIntent.createReminder,
        r'\b(paki-?)?(sabihan|abisuhan|i-?alert) mo (ako|ko)\b|\balert me\b'),
    _Rule(ZoeIntent.createReminder, r"\b(huwag|wag) mo(ng)? (akong )?kalimutan|\bdon'?t let me forget\b"),
    _Rule(ZoeIntent.createReminder,
        r'\b(set|i-?set|mag-?set|pa-?set)\b( (ka|mo|naman|po|nga))*( (ng|an?|the|my))? (alarm|reminder|paalala)\b'
        r'|\b(mag|i)-?alarm\b'),
    // MASSIVE (tl-PH): "magtakda ng pampagising…", "itakda ang hudyat…"
    _Rule(ZoeIntent.createReminder,
        r'\b(itakda|magtakda|takdaan)\b.*\b(hudyat|alarm|pampagising|paalala|reminder)\b|\bpampagising\b'),
    // "remind", "paalala", "reminder" lang (walang utos) → hula, tanong muna.
    _Rule(ZoeIntent.createReminder, r'remind|paalala', sure: false),

    // 2b) Malinaw na utos na magdagdag ng task (sigurado).
    //    "add task…", "lagay mo sa tasks ko: …", "dagdag mo sa to-do ko…", "new task: …"
    _Rule(ZoeIntent.createTask,
        r'\b(add|i-?add|pa-?add|paki-?add|create|new|(paki-?)?lagay|ilagay|(paki-?)?dagdag|idagdag|isama)\b'
        r'.*\b(tasks?|to-?dos?|gawain)\b'
        r'|\b(tasks?|to-?dos?|gawain)\s*:'),

    // 3) Tanong tungkol sa sinabi / na-save dati.
    _Rule(ZoeIntent.searchNotes, r'\b(na)?aalala mo\b|\bnatatandaan mo\b|\btanda mo pa\b'),
    _Rule(ZoeIntent.searchNotes, r'\bdo you (still )?remember\b|\bi told you\b|\bsinabi ko sa\b'),
    _Rule(ZoeIntent.searchNotes, r'\bwhat was (my|the)\b|\b(ano|saan|nasaan) (na )?nga\b'),

    // 4) "Tandaan mo…" at mga kahawig → note.
    _Rule(ZoeIntent.createNote, r'\b(paki[ -]?)?tandaan mo\b|\bisulat mo\b|\bi-?lista mo\b'),
    _Rule(ZoeIntent.createNote, r'\bremember (that|this)\b|\b(write|jot) (this|it|that) down\b'),
    _Rule(ZoeIntent.createNote, r'\bkeep this\b|\bsave (this|it)\b|\btake note\b'),

    // 5) Mga dating keyword (hula lang → tanong muna).
    //    "alarm bukas" → tanong. "ang ingay ng alarm ko" (walang araw/oras) → hindi.
    _Rule(ZoeIntent.createReminder, '^(?=.*($_when)).*\\balarms?\\b', sure: false),
    // "alarm" / "alarm pls" lang → tanong muna.
    _Rule(ZoeIntent.createReminder, '$_lead(alarm|alarma)( (po|please|naman|lang|nga))*\$', sure: false),
    _Rule(ZoeIntent.createTask, r'task|todo|to-do|gawain', sure: false),

    // 6) Pahayag na may kailangang gawin → task (hula → tanong muna).
    _Rule(ZoeIntent.createTask, r'\b(kailangan|kelangan|need) ko(ng)?\b|\bdapat (ko(ng)?|akong)\b',
        statementOnly: true, sure: false),
    _Rule(ZoeIntent.createTask, r"\bi (need|have|got) to\b|\bi (must|should|gotta)\b|\bi'?ve got to\b",
        statementOnly: true, sure: false),

    // 7) Pahayag na may oras ("meeting kay boss 3pm bukas") → reminder (hula → tanong muna).
    _Rule(ZoeIntent.createReminder, r'\b\d{1,2}(:\d{2})? ?([ap]m\b|[ap]\.m\.)',
        statementOnly: true, sure: false),
    _Rule(ZoeIntent.createReminder, r'\balas[ -]?\d{1,2}\b|\b([01]?\d|2[0-3]):[0-5]\d\b',
        statementOnly: true, sure: false),
    // "sunduin si mama 6 ng gabi"
    _Rule(ZoeIntent.createReminder,
        r'\b\d{1,2}(:\d{2})?\s+(ng|sa)\s+(umaga|tanghali|hapon|gabi|madaling[\s-]?araw)\b',
        statementOnly: true, sure: false),

    // 8) Ano ang na-miss.
    //    "na-miss" / "missed" lang — ang "miss" na mag-isa ay pangungulila
    //    ("i miss my mom", "miss ko na si mama"), hindi tanong tungkol sa tasks.
    //    "na-miss kita" / "I missed you" → bati (sa 12).
    _Rule(ZoeIntent.getMissed,
        r"\b(na-?miss|missed)\b(?! (na )?(kita|ka|you|ya|u|me|mo (ba )?ako)\b)|nakalimutan"
        r'|nalimutan|nakaligtaan'),
    _Rule(ZoeIntent.getMissed, r'nalampasan|nalagpasan|overdue'),
    _Rule(ZoeIntent.getMissed, r'\b(hindi|di) ko (pa )?(na)?gawa\b'),
    _Rule(ZoeIntent.getMissed, r'\bdid i (forget|miss|skip)\b|\banything i (forgot|missed|skipped)\b'),

    // 9) Ano ang natapos.
    _Rule(ZoeIntent.getDone, r'kahapon|yesterday|ginawa|what did i do|natapos'),
    _Rule(ZoeIntent.getDone, r'\btapos (ko |na )|\bnagawa ko\b|\bna-?accomplish'),
    _Rule(ZoeIntent.getDone,
        r'\b(finished|completed|accomplish(ed)?|wrapped up)\b|\bdone so far\b'),
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
    // "ano plano ko bukas?", "what do i have tomorrow?", "what's my day like?"
    _Rule(ZoeIntent.getToday,
        r'\b(plano|plans?|lakad|gala|day like|week like|up for (today|tomorrow|tonight))\b'
        r'|\bwhat (do|will) i have\b',
        questionOnly: true),
    // "anong sched ko bukas?", "anu ganap ko today?", MASSIVE: "pagpupulong", "tipanan"
    _Rule(ZoeIntent.getToday,
        r'\b(sched|ganap|iskedyul|kalendaryo|calendar|pagpupulong|tipanan|naka-?schedule'
        r'|nakatakda)\b',
        questionOnly: true),
    _Rule(ZoeIntent.getToday, r"\b(ano|anong|ano'ng) (ang )?(meron|mayroon) (ako|ko|akong)\b",
        questionOnly: true),

    // 11) "ano locker code ko?", "what's my wifi password?", "saan ko nilagay ang susi?"
    _Rule(
        ZoeIntent.searchNotes,
        '$_lead' r"(ano|anong|ano'ng|what|what's|whats|saan|san|nasaan|where|kailan|when"
        r'|sino|who|magkano|ilan|alin|which)\b(?=.*\b(ko|my|akin|ako)\b|.*\b(did|have|had) i\b)'),
    // "did i pay meralco?", "have i paid the rent?" — tanong tungkol sa nagawa / na-save.
    // (Ang "did i forget / finish…" ay nasa 8 at 9 na.)
    _Rule(ZoeIntent.searchNotes, '$_lead(did|have|had) i\\b', questionOnly: true),
    // "anu password ng wifi?" — tanong tungkol sa nakasave na impormasyon, kahit walang "ko".
    _Rule(
        ZoeIntent.searchNotes,
        r'\b(password|passcode|pin|code|plate|locker|address|bday|birthday|wifi|wi-fi|number'
        r'|numero)\b',
        questionOnly: true),

    // 12) Bati.
    _Rule(ZoeIntent.greeting, r'\b(hi|hello|hey|kumusta|kamusta|musta|uy|oy|hoy|hai|helo)\b'),
    // "yo" sa simula lang ("salamat sa'yo" ay hindi bati).
    _Rule(ZoeIntent.greeting, r'^yo\b'),
    _Rule(ZoeIntent.greeting, r'\bgood (morning|afternoon|evening|eve|night|day|am|pm)\b'),
    // "zoe!" lang → bati.
    _Rule(ZoeIntent.greeting, r'^(zoe|zoey)[!.~ ]*$'),
    _Rule(ZoeIntent.greeting, r'\bmagandang (umaga|tanghali|hapon|gabi|araw)\b'),
    _Rule(ZoeIntent.greeting, r'\bgising ka (pa|na)\b|\b(nandyan|andyan|nandiyan) ka\b'),
    _Rule(ZoeIntent.greeting, r'\b(na-?)?miss(ed)? (na )?(kita|ka|you|ya|u|me|mo (ba )?ako)\b'),
  ];

  /// Ang hula ng code. [ZoeIntent.unknown] = walang tumama (ipasa kay Qwen).
  static ZoeIntent match(String text) => matchFull(text).intent;

  /// Gaya ng [match], pero sinasabi rin kung SIGURADO ([IntentMatch.sure]).
  /// Hindi sigurado ang reminder / task → tatanungin muna ng chat.
  static IntentMatch matchFull(String text) {
    final lower = _clean(text);
    if (lower.isEmpty) return const IntentMatch(ZoeIntent.unknown);
    final question = _question.hasMatch(lower);

    for (final rule in _rules) {
      if (rule.statementOnly && question) continue;
      if (rule.questionOnly && !question) continue;
      if (rule.regex.hasMatch(lower)) return IntentMatch(rule.intent, sure: rule.sure);
    }
    return const IntentMatch(ZoeIntent.unknown);
  }

  static final _stopAlarm = RegExp(
    r'\b(patayin|pinatay|paki-?patay|patay|i-?off|itigil|ihinto|tanggalin|turn off|switch off|stop|cancel'
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