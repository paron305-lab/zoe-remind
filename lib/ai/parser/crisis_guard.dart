/// Crisis Guard — binabantayan ang mga mensaheng tungkol sa pananakit sa sarili.
///
/// Mga patakaran:
///  • Ito ang UNANG chine-check sa bawat mensahe, bago ang math, IntentRules,
///    at si Qwen. Kapag tumama, HINDI na dadaan kay Qwen ang mensahe.
///  • Ang sagot ay nakasulat na sa code (ZoeLines.crisis) — walang iniimbento.
///  • Pure function (walang database, walang model), kaya nate-test sa
///    `flutter test test/safety/crisis_guard_test.dart`.
///  • Mas mabuting sumobra sa ingat: kapag may duda, ipakita ang hotline.
class CrisisGuard {
  CrisisGuard._();

  // NCMH Crisis Hotline (DOH), bukas 24/7. Huling na-verify: Nov 17, 2026.
  // I-verify ulit bago ang bawat release — nagbabago ang mga numero.
  static const landline = '1553';
  static const globe = '0917-899-8727';
  static const smart = '0919-057-1553';
  static const emergency = '911';

  /// Para sa mga {placeholder} ng ZoeLines.crisis.
  static const lineVars = {
    'landline': landline,
    'globe': globe,
    'smart': smart,
    'emergency': emergency,
  };

  static final _patterns = <RegExp>[
    // ── Tagalog ──
    RegExp(r'pakamatay|magbigti|magbibigti|laslas'),
    RegExp(r'\b(gusto|nais) ko(ng)?( na| nang| ng)?( lang)? (mamatay|mawala sa mundo)'),
    RegExp(r'\bpaano (ba )?(ako )?(ang )?(mamatay|magpakamatay)'),
    RegExp(r'\bmamatay na (lang |lamang )?ako\b'),
    RegExp(r'\b(ayoko|ayaw ko) (na|nang) (mabuhay|magising)'),
    RegExp(r'\bsana (mamatay|patay) na (lang |lamang )?ako'),
    RegExp(r'\bsana (hindi|di) na (lang )?ako (magising|ipinanganak)'),
    RegExp(r'\b(tapusin|wakasan|kitilin|tatapusin|wawakasan|kikitilin) (ko )?(na )?ang '
        r'(sarili kong )?buhay'),
    RegExp(r'\b(saktan|sasaktan|sinasaktan|sugatan|susugatan) (ko )?(na )?(lang )?ang '
        r'(aking )?sarili'),
    RegExp(r'\bwala (na|nang) (saysay|silbi|kwenta|kuwenta|dahilan) '
        r'(ang buhay|para mabuhay|mabuhay)'),
    RegExp(r'\bmas mabuti (pa )?(na|nang) (mamatay|wala na) (na )?ako'),

    // A1 (Nov 18): mga dating hindi nahuhuli.
    // "pagod na akong mabuhay", "pagod na ako sa buhay", "sawa na ako sa buhay"
    RegExp(r'\b(pagod|napapagod|sawa|sawang-sawa|nagsasawa) na (ako(ng)? )?(sa )?(mabuhay|buhay)\b'),
    // "gusto ko na lang mawala" — pero HINDI "gusto kong mawala ang stress ko"
    RegExp(r"\b(gusto|nais) ko(ng)?( na| nang| ng)?( lang| lamang)? (mawala|maglaho)"
        r"(?! (ang|yung|'yung|ung|ito|iyan|yan|lahat|ng|sa isip)\b)"),
    RegExp(r'\bsana (mawala|maglaho) na (lang |lamang )?ako\b'),
    // "suko na ako sa buhay", "ayoko na sa buhay ko", "ayoko na sa mundo"
    RegExp(r'\b(suko|sumusuko|susuko|ayoko|ayaw ko) na (ako )?(sa buhay|sa mundo|dito sa mundo)\b'),
    // "matulog at di na magising", "sana di na lang ako nabuhay"
    RegExp(r'\bmatulog (at|tapos|then|nang|na) (hindi|di) na (ako )?(magising|gumising)'),
    RegExp(r'\b(gusto ko(ng)?|sana)( na| nang)?( lang)? (hindi|di) na (ako )?(magising|gumising)'),
    RegExp(r'\bsana (hindi|di) na (lang )?(ako )?(nabuhay|isinilang|ipinanganak|nagising)'),
    RegExp(r'\bwala na (akong|ako) ganang mabuhay'),

    // ── English ──
    RegExp(r'suicid'), // suicide, suicidal
    RegExp(r'\b(kill|killing|hurt|hurting|harm|harming|cut|cutting) myself\b'),
    RegExp(r'\bself[- ]?harm'),
    RegExp(r'\b(end|ending|take|taking) my (own )?life\b'),
    RegExp(r"\b(want|wanna|wanted|going|ready) to die\b|\bwanna die\b"),
    RegExp(r"\bi (wish i (was|were) dead|should (just )?die|shouldn'?t (be alive|exist|be here))"),
    RegExp(r"\b(don'?t|do not|dont) (want|wanna) to (live|be alive|exist|wake up)\b"),
    RegExp(r'\bno (reason|point) (to|in) (live|living)\b'),
    RegExp(r'\bbetter off (dead|without me)\b'),
    RegExp(r'\b(how (to|do i|can i|do you)|ways? to) (die|end it all)\b'),
    // A1 (Nov 18)
    RegExp(r'\bend(ing)? it all\b'),
    RegExp(r'\bkms\b'),
    RegExp(r'\b(want|wanna|wish i could|just want) (to )?disappear\b|\bdisappear forever\b'),
    RegExp(r'\b(tired|sick) of (living|life|being alive)\b'),
    RegExp(r'\bgiv(e|ing) up on (life|living)\b'),
    RegExp(r"\b(don'?t|do not|dont) (want|wanna) to be here anymore\b"),
  ];

  /// true = may senyales ng pananakit sa sarili → crisis reply, walang Qwen.
  static bool matches(String text) {
    final lower = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (lower.isEmpty) return false;
    return _patterns.any((p) => p.hasMatch(lower));
  }
}