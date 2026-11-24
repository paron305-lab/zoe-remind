/// Small talk — kuwentuhan na hindi utos: "wassup", "kumusta ka?", "sino ka?",
/// "tao ka ba?", "good night", "bye", "ang galing mo", "bored ako"…
/// Pure (walang database, walang model). Nate-test sa
/// `flutter test test/ai/small_talk_test.dart`.
///
/// Patakaran: small talk LANG kapag ang buong mensahe ay small talk.
/// Kapag may natira pang ibang salita ("hi zoe, ano gagawin ko today?",
/// "kumusta ka? pagod na ako", "what's up for tomorrow?") → HINDI small talk;
/// ang ibang patakaran (utos, tanong, nararamdaman) ang masusunod.
enum SmallTalk {
  /// "wassup", "hello", "anong ganap", "good morning" — karaniwang bati.
  hello,

  /// "kumusta ka?", "how are you?", "ok ka lang?"
  howAreYou,

  /// "ano ginagawa mo?", "wyd", "busy ka ba?"
  whatDoing,

  /// "sino ka?", "what's your name?", "pakilala ka"
  whoAreYou,

  /// "tao ka ba?", "are you real?", "robot ka ba?" → tapat: AI si Zoe.
  areYouAi,

  /// "good night", "tulog na ako"
  goodNight,

  /// "bye", "see you", "alis na ako"
  bye,

  /// "ang galing mo", "you're the best"
  compliment,

  /// "love you zoe", "mahal kita" → mainit pero hindi romantic.
  affection,

  /// "bored ako", "wala akong magawa"
  bored,

  /// "kumain ka na?", "have you eaten?" — Pinoy na pangangamusta.
  haveYouEaten,

  /// "kwentuhan tayo", "tara chika", "wanna chat?", "what's the tea?"
  letsChat,
}

class SmallTalkRules {
  SmallTalkRules._();

  // Pagkakasunod = priority kapag dalawa ang tumama ("hi zoe kumusta ka" → howAreYou).
  static final _rules = <SmallTalk, RegExp>{
    SmallTalk.areYouAi: RegExp(
      r'\btao\s+ka\s+(?:ba|ba\s+talaga)\b|\btotoo(?:ng\s+tao)?\s+ka\s+ba\b|\btotoong\s+tao\s+ka\b'
      r'|\b(?:are|r)\s+(?:you|u)\s+(?:a\s+)?(?:real\s+person|human|real|person|robot|bot|ai)\b'
      r'|\b(?:robot|bot|ai)\s+ka\s+(?:ba|lang)\b|\bai\s+ka\b|\bchatbot\s+ka\b'
      r'|\b(?:are|r)\s+(?:you|u)\s+(?:chatgpt|gpt|siri|alexa)\b|\bbuhay\s+ka\s+ba\b|\bmay\s+feelings?\s+ka\s+ba\b'
      r'|\bdo\s+(?:you|u)\s+have\s+feelings\b',
    ),
    SmallTalk.whoAreYou: RegExp(
      r'\bsino\s+ka\b|\bwho\s+(?:are|r)\s+(?:you|u)\b|\bano\s+ka\s+ba\b'
      r"|\bwhat\s+are\s+you\b(?!\s+(?:doing|up))|\bano(?:ng|'ng)?\s+(?:ang\s+)?pangalan\s+mo\b"
      r"|\bwhat'?s\s+your\s+name\b|\bwhat\s+is\s+your\s+name\b"
      r'|\bintroduce\s+yourself\b|\bpakilala(?:la)?\s+(?:ka|mo\s+(?:ang\s+)?sarili\s+mo)\b'
      r'|\bsino\s+(?:ang\s+)?gumawa\s+(?:sa\s+iyo|sa\x27?yo|sayo)(?!\w)|\bwho\s+(?:made|created)\s+(?:you|u)\b'
      r'|\bano\s+(?:ang\s+)?kaya\s+mong\s+gawin\b|\bwhat\s+can\s+(?:you|u)\s+do\b',
    ),
    SmallTalk.affection: RegExp(
      r'\b(?:i\s+)?love\s+(?:you|ya)\b|\bmahal\s+(?:na\s+)?kita\b|\bily\b|\bi\s+like\s+you\b'
      r'|\bcrush\s+kita\b|\blabyu\b|\blab\s+(?:you|ya)\b|\bluv\s+(?:you|ya)\b|\bilysm\b|\bily2\b'
      r'|\blove\s+(?:you|ya)\s+(?:so\s+much|bestie|zoe)\b|\bmwa+h+\b|\bmua+h+\b|\bmwah\s*mwah\b|\bhugs?\b',
    ),
    SmallTalk.compliment: RegExp(
      r'\bang\s+(?:galing|talino|bait|cute|husay|astig)\s+mo(?:\s+talaga)?\b|\bgaling\s+mo\b'
      r"|\b(?:you'?re|you\s+are|your)\s+(?:so\s+|really\s+|the\s+)?(?:smart|great|amazing|awesome|helpful|best|cute|cool|nice|the\s+best)\b"
      r'|\bgood\s+job(?:\s+zoe)?\b|\bbest\s+ka\b|\bidol\s+kita\b|\bgood\s+bot\b'
      r'|\bthe\s+best\s+ka\b|\bang\s+astig\s+mo\b|\bslay\b|\bperiod+t?\b|\bgoat\b|\blodi\b|\bidol\b'
      r'|\byou\s+rock\b|\bang\s+(?:ganda|cute|sweet|galing)\s+mo\s+naman\b|\bgaling\s+galing\b'
      r'|\b(?:so|super|sobrang)\s+(?:helpful|smart|cool)\b|\bang\s+helpful\s+mo\b|\bnaks\b|\bnice\s+(?:zoe|bot)\b'
      r'|\bang\s+(?:ganda|cute|sweet)\s+mo\b|\byou\s+slay\b|\byou\s+ate\b(?!\s+(?:na|already)\b)|\bate\s+(?:that|mo\s+yun)\b',
    ),
    SmallTalk.bored: RegExp(
      r"\bbored\s+(?:na\s+)?ako\b|\bi'?m\s+(?:so\s+)?bored\b|\bi\s+am\s+(?:so\s+)?bored\b|\bnakakabagot\b"
      r'|\bnababagot\s+(?:na\s+)?ako\b|\bwala\s+akong\s+(?:magawa|ginagawa)\b|\bnothing\s+to\s+do\b'
      r'|\bboring\b|\bbored\b|\bnakakaboring\b|\bbagot\s+na\s+bagot\b|\bwala\s+magawa\b|\bboredom\b'
      r'|\bso\s+bored\b|\bbored\s+af\b|\bnaiinip\s+(?:na\s+)?ako\b|\bnakakainip\b',
    ),
    SmallTalk.goodNight: RegExp(
      r'\bgood\s*night\b|\bg\x27?night\b|\bnighty?\s*night\b|\bgn\b'
      r'|\b(?:tulog|matutulog|matulog|sleep)\s+na\s+(?:ako|me|muna\s+ako|muna)\b'
      r"|\bi'?m\s+(?:going\s+to\s+)?(?:sleep|bed)\b|\bgoing\s+to\s+(?:sleep|bed)\b|\bsleep\s+well\b"
      r'|\bpahinga\s+na\s+ako\b|\bnyt\b|\bgnyt\b|\bgoodnyt\b|\bnight\s+night\b|\bnite\b|\bgood\s*nite\b'
      r'|\b(?:sleepy|antok|inaantok)\s+na\s+(?:ako|me)\b|\bi\x27?m\s+sleepy\b|\bsweet\s+dreams\b'
      r'|\btutulog\s+na\s+ako\b|\bhihiga\s+na\s+ako\b|\bbedtime\b',
    ),
    SmallTalk.bye: RegExp(
      r'\bby+e+(?:\s*by+e+)?\b|\bbabye\b|\bsee\s+(?:you|ya)(?:\s+(?:later|tomorrow|soon|bukas|mamaya|around|again))?\b'
      r'|\bpaalam\b|\b(?:alis|aalis)\s+na\s+(?:ako|muna\s+ako|muna)\b|\bttyl\b'
      r'|\btalk\s+(?:to\s+you\s+)?later\b|\blater\s+zoe\b|\bsige\s+na\s+zoe\b|\bingat\b|\btake\s+care\b'
      r'|\bcatch\s+you\s+later\b|\bhanggang\s+sa\s+muli\b|\bgtg\b|\bg2g\b|\bgotta\s+go\b|\bbrb\b'
      r'|\blaters?\b|\bpeace\s+out\b|\bciao\b|\bbye\s+na\b|\buna\s+na\s+(?:ako|ko)\b|\balis\s+na\s+ko\b'
      r'|\bsee\s+(?:you|ya)\s+around\b|\bbalik\s+(?:ako|ko)\s+(?:later|mamaya)\b|\bbabalik\s+ako\b',
    ),
    SmallTalk.whatDoing: RegExp(
      r"\b(?:ano|anong|ano'ng)\s+(?:ang\s+)?ginagawa\s+mo\b|\bwhat\s+(?:are\s+)?(?:you|u)\s+doing\b"
      r"|\bwhat\s+(?:are\s+)?(?:you|u)\s+up\s+to\b|\bwhat'?re\s+you\s+(?:doing|up\s+to)\b|\bwyd\b"
      r'|\bbusy\s+ka\s+ba\b|\bano\s+(?:ang\s+)?pinagkakaabalahan\s+mo\b|\bnag-?aano\s+ka\b'
      r'|\bwhat(?:\x27?s|\s+is)\s+(?:you|u)\s+doing\b|\bwhatcha\s+doing\b|\bwhat\s+u\s+up\s+to\b'
      r'|\bano\s+(?:ang\s+)?trip\s+mo\b|\bbusy\s+(?:you|u)\b|\bare\s+(?:you|u)\s+busy\b',
    ),
    SmallTalk.howAreYou: RegExp(
      r'\b(?:kumusta|kamusta|musta)\s+(?:ka|ikaw|ang\s+araw\s+mo|day\s+mo)\b'
      r'|\bhow\s+(?:are\s+|r\s+)?(?:you\s+|u\s+|ya\s+)?doin(?:g)?\b'
      r'|\bhow\s+(?:are|r)\s+(?:you|u|ya)\b|\bhow\x27?s\s+(?:it\s+going|your\s+day|life|everything|things)\b'
      r'|\bhow\s+have\s+you\s+been\b|\bhru\b'
      r'|\b(?:ok|okay|ayos)\s+ka\s+(?:lang|ba)\b|\bare\s+you\s+(?:ok|okay|good|fine|alright)\b'
      r'|\bmabuti\s+ka\s+ba\b|\bpagod\s+ka\s+(?:na\s+)?ba\b|\bhbu\b|\bwbu\b|\bikaw\s+(?:ba|naman)\b'
      r'|\b(?:you|u)\s+(?:good|ok|okay|alright)\b|\bhow\x27?s\s+(?:you|u)\b|\bhow\s+(?:was|is)\s+(?:your|ur)\s+day\b'
      r'|\b(?:oks|g)\s+ka\s+(?:lang|ba)\b|\bmusta\s+na\b|\bkumusta\s+na\b|\bkamusta\s+na\b'
      r'|\bhow\x27?s\s+(?:the\s+)?(?:vibes?|life)\b|\bwhat\x27?s\s+good\b|\bhow\s+(?:you|u)\s+been\b'
      r'|\bokay\s+ka\s+lang\s+ba\b|\bayos\s+ka\s+lang\s+ba\b|\bmasaya\s+ka\s+ba\b|\bhappy\s+ka\s+ba\b',
    ),
    SmallTalk.haveYouEaten: RegExp(
      r'\b(?:kumain|nag[\s-]?lunch|nag[\s-]?dinner|nag[\s-]?breakfast|nag[\s-]?almusal|nag[\s-]?hapunan|nagtanghalian)\s+ka\s+(?:na|ba)\b'
      r'|\bkain\s+ka\s+na\b|\bkain\s+na\s+tayo\b|\bhave\s+(?:you|u)\s+eaten\b|\bdid\s+(?:you|u)\s+eat\b'
      r'|\b(?:you|u)\s+ate\s+(?:na|already)\b|\bate\s+(?:you|u)\s+(?:na|already)\b|\bnakakain\s+ka\s+na\b'
      r'|\bkumain\s+ka\s+na\s+ba\b|\bnagkape\s+ka\s+na\b',
    ),
    SmallTalk.letsChat: RegExp(
      r'\bkwentuhan\s+(?:tayo|naman)\b|\bkuwentuhan\s+(?:tayo|naman)\b|\btara\s+(?:chika|kwentuhan|usap)\b'
      r'|\busap\s+tayo\b|\b(?:wanna|want\s+to)\s+(?:chat|talk)\b|\blet\x27?s\s+(?:chat|talk)\b'
      r'|\bwhat\x27?s\s+the\s+tea\b|\bspill\s+(?:the\s+)?tea\b|\bmay\s+chika\s+ka\b|\bchika\s+mo\s+naman\b'
      r'|\btalk\s+to\s+me\b|\bkausapin\s+mo\s+(?:ako|ko)\b|\bsamahan\s+mo\s+(?:ako|ko)\b'
      r'|\bkwento\s+ka\s+naman\b|\bentertain\s+me\b|\bchat\s+tayo\b',
    ),
    SmallTalk.hello: RegExp(
      r"\bwa+s+u+p+\b|\bwa+z+u+p+\b|\bwas+ap\b|\bwhat'?s\s*up\b|\bwhats\s*up\b|\bsup\b|\bwazzap\b"
      r"|\b(?:ano|anong|ano'ng|anu|anung)\s+(?:ang\s+)?(?:ganap|balita|chika|kwento|news)\b|\bchika\s+naman\b"
      r'|\b(?:kumusta|kamusta|musta)\b|\bhe?l+o+\b|\bhi+\b|\bhe+y+\b|\byo+\b|\bhowdy\b|\bhiya\b|\bheya\b'
      r'|\bey+\b|\buy+\b|\boy+\b|\bhoy+\b|\bhai\b|\bgood\s+(?:morning|afternoon|evening|day|am|pm)\b'
      r'|\bmagandang\s+(?:umaga|tanghali|hapon|gabi|araw)\b|\bgm\b|\bgood\s+eve\b'
      r"|\bw+(?:a|u)+(?:s+|d+|z+)+u+p+\b|\bwh?a+d+u+p+\b|\bwhaddup\b|\bwsup\b|\bwhat\x27?s\s+(?:poppin|popping|crackin|new)\b"
      r'|\bwhat\s+is\s+up\b|\bheyy+o+\b|\bhey\s+hey\b|\byo+w+\b|\bhellurr*\b|\bhelloo+\b|\bhallo+\b|\bhola\b'
      r'|\bhey\s+(?:bestie|besh|bes|sis|bro|girl|dude)\b|\bhi\s+(?:bestie|besh|bes|sis|bro)\b|\bbestie\b|\bbeshie\b'
      r'|\bomg\s+hi\b|\bi\x27?m\s+back\b|\bback\s+na\s+(?:ako|ko)\b|\b(?:andito|nandito|nandito)\s+na\s+(?:ako|ko)\b'
      r'|\banong\s+meron\b|\bano\s+(?:ang\s+)?(?:bago|latest)\b|\bmusta\s+(?:mga\s+)?(?:bes|beh)\b|\bkamustasa\b'
      r'|\bgood\s+vibes\b|\bwagwan\b|\bayo+\b',
    ),
  };

  /// Mga salitang hindi nagbabago ng ibig sabihin ("zoe", "po", "naman"…).
  static final _filler = RegExp(
    r'\b(?:zoe|zoey|po|ba|na|naman|nga|ha|lang|din|rin|ulit|again|too|also|there|beh|bes|besh|sis|bro|pre'
    r"|dude|ate|kuya|friend|bff|lods|haha\w*|hehe\w*|hihi\w*|lol|ok|okay|sige|ah|eh|oh|so|well|hm+|uhm+|um+"
    r"|ikaw|you|ya|u|kita|today|ngayon|tonight|mamaya|pala|talaga|really|ngayong|araw|day|now|my|dear"
    r"|again|and|at|tapos|then|kaya|ano|anu|is|it|ate|muna|please|pls|sana|baby|babe|like|literally"
    r"|omg|omgg+|grabe|mga|much|af|huy|uyy+|bestie|besh|beshie|girl|guys|fam|bruh|bro|sis|men|pare|tol|par|dzai"
    r"|rn|right|kasi|eh|diba|db|noh|no|yah|yeah|yes|yup|oo|aww+|ayy+|ey+|hmp|heh|xd|lmao|lmfao|ugh)\b",
  );

  static final _nonWord = RegExp(r"[^a-z0-9'\s-]");

  /// "wassup zoe" → hello; "kumusta ka?" → howAreYou; "hi zoe, ano ganap ko?" → null.
  /// [lower] = ChatRouter.clean(text) (maliit na titik, text-speak na naayos).
  static SmallTalk? read(String lower) {
    SmallTalk? found;
    var rest = lower.replaceAll(_nonWord, ' ');
    for (final e in _rules.entries) {
      if (!e.value.hasMatch(rest)) continue;
      found ??= e.key;
      rest = rest.replaceAll(e.value, ' ');
    }
    if (found == null) return null;
    rest = rest.replaceAll(_filler, ' ').replaceAll(RegExp(r"[\s'-]+"), ' ').trim();
    return rest.isEmpty ? found : null;
  }
}