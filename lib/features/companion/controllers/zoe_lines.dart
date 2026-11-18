import 'dart:math';

import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';
import 'package:zoe_remind/features/companion/models/user_tone.dart';

/// Mga sitwasyon kung saan may sinasabi si Zoe.
enum ZoeSituation {
  greeting,
  thanks,
  unknown,
  askReminderTitle,
  askTime,
  askTaskTitle,
  askNote,
  todayFree,
  todayList,
  doneNone,
  doneList,
  missedNone,
  missedList,
  noteFound,
  noteNotFound,
  mathDivideByZero,

  /// Ibang araw (bukas, "sa Sabado") na walang laman. {day} = "Sat, Nov 21".
  dayFree,

  /// Ibang araw na may laman. {day}, {items}.
  dayList,

  /// Pagod / stressed ang user PERO may inuutos (reminder, task, listahan).
  /// Maikling linya bago ang card — hindi pinapalitan ang sagot.
  feelingAck,

  /// "patayin mo ang alarm" — hindi pa kaya mula sa chat.
  stopAlarmHelp,

  /// "pagod na ako", "I'm sad" — nagkukuwento ng nararamdaman.
  comfort,

  /// Mensaheng tungkol sa pananakit sa sarili (tingnan ang CrisisGuard).
  crisis,

  // ── Home header (bati ayon sa oras) ──────────────────────────────
  /// Bago mag-12:00.
  homeMorning,

  /// 12:00 hanggang bago mag-18:00.
  homeAfternoon,

  /// 18:00 pataas.
  homeEvening,

  // ── Home banner (katabi ni Zoe avatar) ───────────────────────────
  /// Walang laman ang araw.
  homeFreeDay,

  /// May {count} na gagawin ngayong araw. {count} ay numero.
  homeHasItems,

  /// May gagawin pero wala pang natatapos.
  homeStartFirst,

  /// Lahat tapos na.
  homeAllDone,

  /// May natapos na pero may natitira pa. {done} ay numero.
  homeKeepGoing,

  /// Mood gentle + may na-miss ngayong araw. "Okay lang, isa-isa lang tayo."
  homeGentleMissed,

  /// Mood gentle dahil sa ibang dahilan (hal. sinabi ng user na pagod siya).
  homeGentle,

  /// Mood proud + tapos lahat ngayong araw.
  homeProud,

  /// Gabi (mood sleepy) — tahimik, walang push.
  homeNight,

  // ── Sagot ayon sa nararamdaman ng user (ToneDetector) ────────────
  /// "pagod na ako", "I'm so tired", "puyat ako"
  feelingTired,

  /// "ang dami ko pang gagawin", "stressed ako", "overwhelmed"
  feelingStressed,

  /// "nalulungkot ako", "I feel sad", "naiiyak ako"
  feelingSad,

  /// "nakakainis", "badtrip ako", "I'm so annoyed"
  feelingUpset,

  /// "kinakabahan ako", "I'm nervous", "nag-aalala ako"
  feelingWorried,

  /// "natapos ko na lahat!!", "yay!", "hahaha"
  feelingHappy,
}

/// Zoe Lines — ang boses ni Zoe (Personality plan, P1 Voice).
///
/// Code ang pumipili ng sasabihin ni Zoe, hindi si Qwen, kaya laging tama
/// ang grammar sa English, Tagalog, at Taglish — at gumagana kahit walang model.
///
/// Personality: warm, encouraging, maikli at simple, honest. Walang sobrang
/// emoji, walang baby talk, walang paninisi.
///
/// Dalawang paraan ng pagkuha ng linya:
///  • [pick]   — random, iniiwasan ang huling 5 nasabi. Para sa chat.
///  • [stable] — laging ang unang linya. Para sa mga widget na madalas
///               mag-rebuild (Home header) para hindi kumikislap ang text.
///
/// Mood (2c): [pickFor] / [stableFor] ay tumitingin muna sa mood ni Zoe
/// (gentle, proud, sleepy…). Kapag walang espesyal na linya para sa mood na
/// iyon, ang karaniwang linya ang ginagamit — kaya hindi kailanman blangko.
class ZoeLines {
  ZoeLines._();

  static final _random = Random();

  /// Huling 5 linyang ginamit — para hindi paulit-ulit si Zoe.
  static final List<String> _recent = [];

  /// Pumili ng linya (random). [vars]: {'items': 'Study, Grocery'} → pinapalitan ang {items}.
  static String pick(
    ZoeLanguage lang,
    ZoeSituation situation, [
    Map<String, String> vars = const {},
  ]) =>
      pickFor(lang, situation, MoodState.content, vars);

  /// Gaya ng [pick], pero ayon sa [mood] ni Zoe.
  /// Hal. gentle + greeting → "Hi. Nandito lang ako — ano'ng kailangan mo?"
  static String pickFor(
    ZoeLanguage lang,
    ZoeSituation situation,
    MoodState mood, [
    Map<String, String> vars = const {},
  ]) {
    final options = _options(lang, situation, mood);
    if (options.isEmpty) return '';

    final fresh = options.where((o) => !_recent.contains(o)).toList();
    final pool = fresh.isEmpty ? options : fresh;
    final chosen = pool[_random.nextInt(pool.length)];

    _recent.add(chosen);
    if (_recent.length > 5) _recent.removeAt(0);

    return _fill(chosen, vars);
  }

  /// Laging ang unang linya — walang random, hindi binabago ang [_recent].
  /// Ginagamit ng Home header para pare-pareho ang text kahit mag-rebuild.
  static String stable(
    ZoeLanguage lang,
    ZoeSituation situation, [
    Map<String, String> vars = const {},
  ]) =>
      stableFor(lang, situation, MoodState.content, vars);

  /// Gaya ng [stable], pero ayon sa [mood] ni Zoe.
  static String stableFor(
    ZoeLanguage lang,
    ZoeSituation situation,
    MoodState mood, [
    Map<String, String> vars = const {},
  ]) {
    final options = _options(lang, situation, mood);
    if (options.isEmpty) return '';
    return _fill(options.first, vars);
  }

  /// Linya para sa mood kung meron; kung wala, ang karaniwang linya.
  static List<String> _options(ZoeLanguage lang, ZoeSituation situation, MoodState mood) {
    final byMood = _moodLines[situation]?[mood]?[lang];
    if (byMood != null && byMood.isNotEmpty) return byMood;
    return _lines[situation]?[lang] ?? const <String>[];
  }

  /// Pumili ng bati sa Home ayon sa oras (0–23).
  static ZoeSituation homeGreetingFor(int hour) {
    if (hour < 12) return ZoeSituation.homeMorning;
    if (hour < 18) return ZoeSituation.homeAfternoon;
    return ZoeSituation.homeEvening;
  }

  /// Pumili ng banner line sa Home ayon sa nangyari sa araw at sa mood ni Zoe.
  ///
  ///  • Gabi (sleepy)          → tahimik: "Gabi na — magpahinga ka…"
  ///  • Walang laman           → homeFreeDay
  ///  • Tapos lahat            → proud? "Proud ako sa'yo!" : "Tapos na lahat"
  ///  • Gentle + may na-miss   → "Okay lang, isa-isa lang tayo"
  ///  • Gentle (pagod ang user)→ "Dahan-dahan lang…"
  ///  • Wala pang tapos        → "Simulan na natin ang una"
  ///  • May tapos na           → "{done} na ang tapos — tuloy lang"
  static ZoeSituation homeBannerFor({
    required int total,
    required int done,
    int missed = 0,
    MoodState mood = MoodState.content,
  }) {
    if (mood == MoodState.sleepy) return ZoeSituation.homeNight;
    if (total == 0) return ZoeSituation.homeFreeDay;
    if (done >= total) {
      return mood == MoodState.proud ? ZoeSituation.homeProud : ZoeSituation.homeAllDone;
    }
    if (mood == MoodState.gentle) {
      return missed > 0 ? ZoeSituation.homeGentleMissed : ZoeSituation.homeGentle;
    }
    if (done == 0) return ZoeSituation.homeStartFirst;
    return ZoeSituation.homeKeepGoing;
  }

  /// Aling script ang sasagot sa nararamdaman ng user? Neutral → null.
  static ZoeSituation? situationForTone(UserTone tone) => switch (tone) {
        UserTone.neutral => null,
        UserTone.happy => ZoeSituation.feelingHappy,
        UserTone.tired => ZoeSituation.feelingTired,
        UserTone.stressed => ZoeSituation.feelingStressed,
        UserTone.sad => ZoeSituation.feelingSad,
        UserTone.upset => ZoeSituation.feelingUpset,
        UserTone.worried => ZoeSituation.feelingWorried,
      };

  /// Para sa test: may linya ba ang [situation] sa lahat ng language?
  static bool hasAllLanguages(ZoeSituation situation) {
    final byLang = _lines[situation];
    if (byLang == null) return false;
    return ZoeLanguage.values.every((l) => (byLang[l] ?? const []).isNotEmpty);
  }

  /// Para sa test: lahat ng posibleng linya (hindi pa napapalitan ang {vars}).
  static List<String> optionsFor(ZoeLanguage lang, ZoeSituation situation,
          [MoodState mood = MoodState.content]) =>
      List.unmodifiable(_options(lang, situation, mood));

  /// Lahat ng (situation, mood) na may sariling linya — para sa test.
  static List<(ZoeSituation, MoodState)> get moodVariants => [
        for (final s in _moodLines.entries)
          for (final m in s.value.keys) (s.key, m),
      ];

  /// Para sa test: may linya ba ang mood variant sa lahat ng language?
  static bool moodVariantHasAllLanguages(ZoeSituation situation, MoodState mood) {
    final byLang = _moodLines[situation]?[mood];
    if (byLang == null) return false;
    return ZoeLanguage.values.every((l) => (byLang[l] ?? const []).isNotEmpty);
  }

  static String _fill(String line, Map<String, String> vars) {
    var out = line;
    for (final e in vars.entries) {
      out = out.replaceAll('{${e.key}}', e.value);
    }
    return out;
  }

  static const _lines = <ZoeSituation, Map<ZoeLanguage, List<String>>>{
    ZoeSituation.greeting: {
      ZoeLanguage.english: [
        'Hi! What can I help you with today?',
        'Hey! What do you need today?',
      ],
      ZoeLanguage.tagalog: [
        "Hi! Ano ang maitutulong ko sa'yo ngayon?",
        'Kumusta! Ano ang kailangan mo ngayon?',
      ],
      ZoeLanguage.both: [
        "Hi! Ano maitutulong ko sa'yo today?",
        "Hey! Ano'ng kailangan mo today?",
      ],
    },
    ZoeSituation.thanks: {
      ZoeLanguage.english: ['Anytime!', "You're welcome!"],
      ZoeLanguage.tagalog: ['Walang anuman!', 'Sige lang, anumang oras.'],
      ZoeLanguage.both: ['Walang anuman!', 'No problem, anytime!'],
    },
    ZoeSituation.unknown: {
      ZoeLanguage.english: [
        "Sorry, I didn't get that. Can you say it another way?",
        "I'm not sure what you mean yet. Try telling me what to remind you about.",
      ],
      ZoeLanguage.tagalog: [
        'Pasensya, hindi ko nakuha. Pwede mo bang sabihin sa ibang paraan?',
        'Hindi pa ako sigurado sa ibig mong sabihin. Subukan mong sabihin kung ano ang ipapaalala ko.',
      ],
      ZoeLanguage.both: [
        'Sorry, hindi ko na-gets. Pwede mo bang ulitin in another way?',
        "Hindi pa ako sure sa ibig mong sabihin. Try mo sabihin kung ano'ng ipapaalala ko.",
      ],
    },
    ZoeSituation.askReminderTitle: {
      ZoeLanguage.english: ['What should I remind you about?'],
      ZoeLanguage.tagalog: ["Ano ang ipapaalala ko sa'yo?"],
      ZoeLanguage.both: ["Ano'ng ipapaalala ko sa'yo?"],
    },
    ZoeSituation.askTime: {
      ZoeLanguage.english: ['What time?'],
      ZoeLanguage.tagalog: ['Anong oras?'],
      ZoeLanguage.both: ['Anong oras?'],
    },
    ZoeSituation.askTaskTitle: {
      ZoeLanguage.english: ["What's the task?"],
      ZoeLanguage.tagalog: ['Ano ang gawaing idadagdag ko?'],
      ZoeLanguage.both: ["Ano'ng task ang idadagdag ko?"],
    },
    ZoeSituation.askNote: {
      ZoeLanguage.english: ['What should I put in the note?'],
      ZoeLanguage.tagalog: ['Ano ang ilalagay ko sa note?'],
      ZoeLanguage.both: ["Ano'ng ilalagay ko sa note?"],
    },
    ZoeSituation.todayFree: {
      ZoeLanguage.english: ['Nothing scheduled today. Your day is free.'],
      ZoeLanguage.tagalog: ['Wala kang naka-schedule ngayon. Libre ang araw mo.'],
      ZoeLanguage.both: ['Wala ka pang naka-schedule today. Free day!'],
    },
    ZoeSituation.todayList: {
      ZoeLanguage.english: ['Today you have: {items}.'],
      ZoeLanguage.tagalog: ['Ngayong araw: {items}.'],
      ZoeLanguage.both: ['Today meron kang: {items}.'],
    },
    ZoeSituation.doneNone: {
      ZoeLanguage.english: ['I have nothing recorded as done that day.'],
      ZoeLanguage.tagalog: ['Wala akong nakitang natapos mo noong araw na iyon.'],
      ZoeLanguage.both: ['Wala akong nakitang natapos mo that day.'],
    },
    ZoeSituation.doneList: {
      ZoeLanguage.english: ['That day you finished: {items}.'],
      ZoeLanguage.tagalog: ['Noong araw na iyon, natapos mo: {items}.'],
      ZoeLanguage.both: ['That day, natapos mo: {items}.'],
    },
    ZoeSituation.missedNone: {
      ZoeLanguage.english: ["You didn't miss anything. Nice work."],
      ZoeLanguage.tagalog: ['Wala kang na-miss. Ang galing.'],
      ZoeLanguage.both: ['Wala kang na-miss. Nice!'],
    },
    ZoeSituation.missedList: {
      ZoeLanguage.english: ['You missed: {items}.'],
      ZoeLanguage.tagalog: ['Na-miss mo: {items}.'],
      ZoeLanguage.both: ['Na-miss mo: {items}.'],
    },
    ZoeSituation.noteFound: {
      ZoeLanguage.english: ['I found this in your notes: {note}'],
      ZoeLanguage.tagalog: ['Ito ang nakita ko sa notes mo: {note}'],
      ZoeLanguage.both: ['Ito ang nakita ko sa notes mo: {note}'],
    },
    ZoeSituation.noteNotFound: {
      ZoeLanguage.english: [
        "I couldn't find that in your notes. If you tell me, I can save it.",
      ],
      ZoeLanguage.tagalog: [
        'Wala akong nakitang ganyan sa notes mo. Sabihin mo sa akin at ise-save ko.',
      ],
      ZoeLanguage.both: [
        'Wala akong nakitang ganyan sa notes mo. Sabihin mo lang at ise-save ko.',
      ],
    },
    ZoeSituation.mathDivideByZero: {
      ZoeLanguage.english: ["That one can't be divided by zero."],
      ZoeLanguage.tagalog: ['Hindi pwedeng hatiin sa zero.'],
      ZoeLanguage.both: ['Hindi pwedeng i-divide sa zero.'],
    },
    // Dati: nakasulat sa loob ng ChatPreviewBrain._scheduleOn.
    ZoeSituation.dayFree: {
      ZoeLanguage.english: ['Nothing scheduled on {day}.'],
      ZoeLanguage.tagalog: ['Wala kang naka-schedule sa {day}.'],
      ZoeLanguage.both: ['Wala kang naka-schedule sa {day}.'],
    },
    ZoeSituation.dayList: {
      ZoeLanguage.english: ['On {day} you have: {items}.'],
      ZoeLanguage.tagalog: ['Sa {day}, meron kang: {items}.'],
      ZoeLanguage.both: ['Sa {day}, meron kang: {items}.'],
    },
    ZoeSituation.feelingAck: {
      ZoeLanguage.english: [
        'Got it — one thing at a time.',
        "Okay. Let's make it a little lighter.",
      ],
      ZoeLanguage.tagalog: [
        'Sige, isa-isa lang tayo.',
        'Sige, gagaanin natin kahit kaunti.',
      ],
      ZoeLanguage.both: [
        'Got it, isa-isa lang tayo.',
        'Okay, gaanin natin kahit konti.',
      ],
    },
    ZoeSituation.stopAlarmHelp: {
      ZoeLanguage.english: [
        "I can't turn off an alarm from chat yet. When it rings, tap Done or Dismiss. "
            'To stop it from ringing again, switch off the bell on that reminder.',
      ],
      ZoeLanguage.tagalog: [
        'Hindi ko pa kayang patayin ang alarm mula sa chat. Kapag tumunog, pindutin ang '
            'Done o Dismiss. Para hindi na ito tumunog ulit, i-off ang bell ng reminder na iyon.',
      ],
      ZoeLanguage.both: [
        'Hindi ko pa kayang i-off ang alarm from chat. Kapag tumunog, tap Done o Dismiss. '
            'Para hindi na tumunog ulit, i-off ang bell ng reminder na iyon.',
      ],
    },
    ZoeSituation.comfort: {
      ZoeLanguage.english: [
        "That sounds like a heavy day. It's okay to rest. I'm here if you want me to "
            'keep track of something for you.',
        "I'm sorry it feels that way right now. Take it one small step at a time. "
            'Want me to hold on to anything so you can rest?',
      ],
      ZoeLanguage.tagalog: [
        'Mukhang mabigat ang araw mo. Okay lang magpahinga. Nandito ako kung may gusto '
            'kang ipatanda sa akin.',
        'Pasensya at ganyan ang nararamdaman mo ngayon. Paisa-isang hakbang lang. May '
            'gusto ka bang ipaalala ko para makapagpahinga ka?',
      ],
      ZoeLanguage.both: [
        'Mukhang heavy ang araw mo. Okay lang magpahinga. Nandito ako kung may gusto '
            'kang ipatanda sa akin.',
        'Sorry at ganyan ang feeling mo ngayon. One step at a time lang. May gusto ka '
            'bang i-remind ko para makapagpahinga ka?',
      ],
    },
    // Isang linya lang kada language — sadyang hindi paiba-iba.
    // Ang mga numero ay galing sa CrisisGuard.lineVars.
    ZoeSituation.crisis: {
      ZoeLanguage.english: [
        "Thank you for telling me. I'm really sorry you're going through this, and "
            "you don't have to face it alone.\n\n"
            'Please talk to someone who can help right now. The NCMH Crisis Hotline '
            'is open 24/7:\n'
            '• {landline} (landline)\n'
            '• {globe} (Globe/TM)\n'
            '• {smart} (Smart/TNT)\n\n'
            'If you are in danger right now, call {emergency} or go to someone you trust.',
      ],
      ZoeLanguage.tagalog: [
        'Salamat at sinabi mo sa akin. Nalulungkot ako na ganito ang pinagdadaanan mo, '
            'at hindi mo ito kailangang harapin nang mag-isa.\n\n'
            'Pakiusap, makipag-usap ka sa taong makakatulong ngayon din. Bukas 24 oras '
            'ang NCMH Crisis Hotline:\n'
            '• {landline} (landline)\n'
            '• {globe} (Globe/TM)\n'
            '• {smart} (Smart/TNT)\n\n'
            'Kung nasa panganib ka ngayon, tumawag sa {emergency} o lumapit sa taong '
            'pinagkakatiwalaan mo.',
      ],
      ZoeLanguage.both: [
        'Salamat at sinabi mo sa akin. Nalulungkot ako na ganito ang pinagdadaanan mo, '
            'at hindi mo ito kailangang harapin nang mag-isa.\n\n'
            'Please, makipag-usap ka sa taong makakatulong ngayon din. Open 24/7 '
            'ang NCMH Crisis Hotline:\n'
            '• {landline} (landline)\n'
            '• {globe} (Globe/TM)\n'
            '• {smart} (Smart/TNT)\n\n'
            'Kung nasa panganib ka ngayon, tumawag sa {emergency} o lumapit sa taong '
            'pinagkakatiwalaan mo.',
      ],
    },

    // ── Home header: bati ayon sa oras ───────────────────────────────
    // Unang linya ang ginagamit ng [stable]; ang iba ay para sa P2 Mood.
    ZoeSituation.homeMorning: {
      ZoeLanguage.english: ['Good morning ☀️'],
      ZoeLanguage.tagalog: ['Magandang umaga ☀️'],
      ZoeLanguage.both: ['Good morning ☀️'],
    },
    ZoeSituation.homeAfternoon: {
      ZoeLanguage.english: ['Good afternoon 🌤️'],
      ZoeLanguage.tagalog: ['Magandang hapon 🌤️'],
      ZoeLanguage.both: ['Good afternoon 🌤️'],
    },
    ZoeSituation.homeEvening: {
      ZoeLanguage.english: ['Good evening 🌙'],
      ZoeLanguage.tagalog: ['Magandang gabi 🌙'],
      ZoeLanguage.both: ['Good evening 🌙'],
    },

    // ── Home banner ──────────────────────────────────────────────────
    ZoeSituation.homeFreeDay: {
      ZoeLanguage.english: ['Free day today!'],
      ZoeLanguage.tagalog: ['Libre ang araw mo ngayon!'],
      ZoeLanguage.both: ['Free day today!'],
    },
    // {count} = bilang ng gagawin. Sa English, {s} = '' o 's'.
    ZoeSituation.homeHasItems: {
      ZoeLanguage.english: ['You have {count} thing{s} today!'],
      ZoeLanguage.tagalog: ['May {count} kang gagawin ngayong araw!'],
      ZoeLanguage.both: ['May {count} kang gagawin today!'],
    },
    ZoeSituation.homeStartFirst: {
      ZoeLanguage.english: ["Let's start the first one 💪"],
      ZoeLanguage.tagalog: ['Simulan na natin ang una 💪'],
      ZoeLanguage.both: ["Let's start sa una 💪"],
    },
    ZoeSituation.homeAllDone: {
      ZoeLanguage.english: ['All done — great job! 🎉'],
      ZoeLanguage.tagalog: ['Tapos na lahat — ang galing mo! 🎉'],
      ZoeLanguage.both: ['All done — ang galing mo! 🎉'],
    },
    // {done} = bilang ng natapos.
    ZoeSituation.homeKeepGoing: {
      ZoeLanguage.english: ['{done} done already — keep going 💪'],
      ZoeLanguage.tagalog: ['{done} na ang tapos — tuloy lang 💪'],
      ZoeLanguage.both: ['{done} na ang tapos — keep going 💪'],
    },
    ZoeSituation.homeGentleMissed: {
      ZoeLanguage.english: ["That's okay — one at a time 🌱"],
      ZoeLanguage.tagalog: ['Okay lang, isa-isa lang tayo 🌱'],
      ZoeLanguage.both: ['Okay lang, isa-isa lang tayo 🌱'],
    },
    ZoeSituation.homeGentle: {
      ZoeLanguage.english: ["Go easy today — I'll keep track 🌱"],
      ZoeLanguage.tagalog: ['Dahan-dahan lang ngayon, ako na ang bahala sa listahan 🌱'],
      ZoeLanguage.both: ['Easy lang today, ako na bahala mag-track 🌱'],
    },
    ZoeSituation.homeProud: {
      ZoeLanguage.english: ['You finished everything. Proud of you! 🎉'],
      ZoeLanguage.tagalog: ["Natapos mo lahat. Proud ako sa'yo! 🎉"],
      ZoeLanguage.both: ["Natapos mo lahat today. Proud ako sa'yo! 🎉"],
    },
    ZoeSituation.homeNight: {
      ZoeLanguage.english: ["It's late — rest when you can 🌙"],
      ZoeLanguage.tagalog: ['Gabi na — magpahinga ka kapag kaya mo na 🌙'],
      ZoeLanguage.both: ['Late na — pahinga ka kapag kaya mo na 🌙'],
    },

    // ── Sagot ayon sa nararamdaman ng user ───────────────────────────
    // Mga rules: maikli, mainit, walang paninisi, hindi nagda-diagnose.
    // Ang inaalok na tulong ay mga bagay na KAYA na ni Zoe (reminder, listahan).
    ZoeSituation.feelingTired: {
      ZoeLanguage.english: [
        "Sounds like you're running low. Rest counts too. Want me to remind you to "
            'take a break later?',
        "You've done a lot today. Take it easy for a bit — I'll keep track of things for you.",
      ],
      ZoeLanguage.tagalog: [
        'Mukhang pagod ka na. Mahalaga rin ang pahinga. Gusto mo bang paalalahanan '
            'kita mamaya na magpahinga?',
        'Ang dami mo nang nagawa ngayong araw. Magpahinga ka muna, ako na ang '
            'magbabantay sa mga gagawin mo.',
      ],
      ZoeLanguage.both: [
        'Mukhang drained ka na. Rest counts din. Gusto mo i-remind kita mamaya na '
            'mag-break?',
        'Ang dami mo nang nagawa today. Pahinga ka muna, ako na bahala mag-track.',
      ],
    },
    ZoeSituation.feelingStressed: {
      ZoeLanguage.english: [
        "That's a lot on your plate. Let's take it one at a time. Tell me the most "
            "important one and I'll set a reminder for it.",
        "Okay, deep breath. You don't have to do everything at once. Ask me "
            '"what\'s today" and we\'ll look at it together.',
      ],
      ZoeLanguage.tagalog: [
        'Ang dami nga. Isa-isa lang tayo. Sabihin mo ang pinakamahalaga at '
            'ise-set ko ang reminder.',
        'Sige, hinga muna nang malalim. Hindi mo kailangang gawin lahat nang sabay. '
            'Itanong mo sa akin "ano meron ngayon" at titingnan natin nang magkasama.',
      ],
      ZoeLanguage.both: [
        "Ang dami nga. One at a time lang tayo. Sabihin mo yung pinaka-importante "
            "at ise-set ko ang reminder.",
        'Okay, deep breath muna. Di mo kailangang gawin lahat at once. Tanong mo '
            'sa akin "ano meron today" at sabay nating titingnan.',
      ],
    },
    ZoeSituation.feelingSad: {
      ZoeLanguage.english: [
        "I'm sorry you're feeling down. You don't have to explain. It's okay to go "
            'easy on yourself today.',
        'That sounds hard. Is there someone you trust you could talk to today? '
            'I can remind you to reach out.',
      ],
      ZoeLanguage.tagalog: [
        'Pasensya at malungkot ka. Hindi mo kailangang magpaliwanag. Okay lang na '
            'dahan-dahan ka ngayon.',
        'Mabigat iyan. May taong pinagkakatiwalaan ka ba na pwede mong kausapin '
            'ngayon? Pwede kitang paalalahanan na i-message sila.',
      ],
      ZoeLanguage.both: [
        'Sorry at malungkot ka. Di mo kailangang mag-explain. Okay lang mag-slow '
            'down today.',
        'Mabigat iyan. May tao ka bang pwedeng kausapin today? Pwede kitang '
            'i-remind na i-message sila.',
      ],
    },
    ZoeSituation.feelingUpset: {
      ZoeLanguage.english: [
        "That sounds frustrating. It's okay to be annoyed. Maybe take a minute "
            'before the next thing.',
        "Ugh, that's annoying. Want me to remind you to take a short break in "
            '15 minutes?',
      ],
      ZoeLanguage.tagalog: [
        'Nakakainis nga iyan. Okay lang mainis. Huminga ka muna bago ang susunod.',
        'Ang hirap niyan. Gusto mo bang paalalahanan kita na magpahinga sandali '
            'pagkalipas ng 15 minuto?',
      ],
      ZoeLanguage.both: [
        'Nakakainis nga iyan. Okay lang mainis. Take a minute muna bago yung next.',
        'Hassle nga iyan. Gusto mo i-remind kita mag-short break after 15 minutes?',
      ],
    },
    ZoeSituation.feelingWorried: {
      ZoeLanguage.english: [
        "Feeling nervous is normal before something big. Want me to set a reminder "
            "so you don't have to keep it all in your head?",
        "That sounds worrying. Let's write it down so it's off your mind. What "
            'should I remind you about?',
      ],
      ZoeLanguage.tagalog: [
        'Normal lang kabahan bago ang isang malaking bagay. Gusto mo bang mag-set '
            'ako ng reminder para hindi mo na kailangang isipin palagi?',
        'Nakakapag-alala nga iyan. Isulat natin para gumaan ang isip mo. Ano ang '
            'ipapaalala ko?',
      ],
      ZoeLanguage.both: [
        'Normal lang kabahan before something big. Gusto mo mag-set ako ng '
            'reminder para di mo na kailangang isipin lagi?',
        "Nakaka-worry nga iyan. Isulat natin para gumaan isip mo. Ano'ng "
            'ipapaalala ko?',
      ],
    },
    ZoeSituation.feelingHappy: {
      ZoeLanguage.english: ['Love that! Nice work.', "That's great to hear!"],
      ZoeLanguage.tagalog: ['Ang saya naman! Ang galing mo.', 'Ang sarap pakinggan niyan!'],
      ZoeLanguage.both: ['Love that! Ang galing mo.', 'Nice, ang saya niyan!'],
    },
  };

  // ───────────────────── Mga linya ayon sa mood ni Zoe ─────────────────────
  // Kapag wala rito ang (situation, mood), ang karaniwang linya sa [_lines]
  // ang ginagamit. Ang "focused" ay walang sariling linya (maikling status lang).
  // Rules: walang paninisi, walang guilt sa streak, walang "ako lang ang kaibigan mo".
  static const _moodLines =
      <ZoeSituation, Map<MoodState, Map<ZoeLanguage, List<String>>>>{
    ZoeSituation.greeting: {
      MoodState.gentle: {
        ZoeLanguage.english: [
          "Hi. I'm here — what do you need?",
          'Hey. Take your time — what can I help with?',
        ],
        ZoeLanguage.tagalog: [
          'Hi. Nandito lang ako — ano ang kailangan mo?',
          'Kumusta. Dahan-dahan lang — ano ang maitutulong ko?',
        ],
        ZoeLanguage.both: [
          "Hi. Nandito lang ako — ano'ng kailangan mo?",
          'Hey. Take your time — ano maitutulong ko?',
        ],
      },
      MoodState.happy: {
        ZoeLanguage.english: ["Hi! Your day's going well. What's next?"],
        ZoeLanguage.tagalog: ['Hi! Maganda ang takbo ng araw mo. Ano ang susunod?'],
        ZoeLanguage.both: ["Hi! Ang ganda ng flow ng araw mo. Ano'ng next?"],
      },
      MoodState.proud: {
        ZoeLanguage.english: ["Hi! You're on a roll today. What's next?"],
        ZoeLanguage.tagalog: ['Hi! Ang galing mo ngayong araw. Ano ang susunod?'],
        ZoeLanguage.both: ["Hi! Ang galing mo today. Ano'ng next?"],
      },
      MoodState.sleepy: {
        ZoeLanguage.english: ["Hi. It's late — want me to set something for tomorrow?"],
        ZoeLanguage.tagalog: ['Hi. Gabi na — may gusto ka bang ipaalala ko bukas?'],
        ZoeLanguage.both: ['Hi. Late na — may gusto ka bang i-remind ko bukas?'],
      },
      MoodState.sorry: {
        ZoeLanguage.english: ["Hi. Sorry about earlier — I'm ready now. What do you need?"],
        ZoeLanguage.tagalog: ['Hi. Pasensya kanina — ayos na ako. Ano ang kailangan mo?'],
        ZoeLanguage.both: ["Hi. Sorry kanina — okay na ako. Ano'ng kailangan mo?"],
      },
    },
    ZoeSituation.thanks: {
      MoodState.gentle: {
        ZoeLanguage.english: ['Anytime. Take care of yourself.'],
        ZoeLanguage.tagalog: ['Walang anuman. Ingatan mo ang sarili mo.'],
        ZoeLanguage.both: ['Anytime. Take care ka, ha.'],
      },
    },
    ZoeSituation.todayList: {
      MoodState.gentle: {
        ZoeLanguage.english: ["Today you have: {items}. One at a time — you've got this."],
        ZoeLanguage.tagalog: ["Ngayong araw: {items}. Isa-isa lang, kaya mo 'yan."],
        ZoeLanguage.both: ["Today meron kang: {items}. Isa-isa lang, kaya mo 'yan."],
      },
      MoodState.proud: {
        ZoeLanguage.english: ["Today you have: {items}. You're doing great so far."],
        ZoeLanguage.tagalog: ['Ngayong araw: {items}. Ang ganda ng takbo mo.'],
        ZoeLanguage.both: ['Today meron kang: {items}. Ang galing mo so far.'],
      },
    },
    ZoeSituation.todayFree: {
      MoodState.gentle: {
        ZoeLanguage.english: ['Nothing scheduled today. A good day to go easy on yourself.'],
        ZoeLanguage.tagalog: ['Wala kang naka-schedule ngayon. Pwede kang magdahan-dahan.'],
        ZoeLanguage.both: ['Wala kang naka-schedule today. Okay lang mag-slow down.'],
      },
      MoodState.sleepy: {
        ZoeLanguage.english: ['Nothing scheduled today. Rest well tonight.'],
        ZoeLanguage.tagalog: ['Wala kang naka-schedule ngayon. Magpahinga ka nang maayos ngayong gabi.'],
        ZoeLanguage.both: ['Wala kang naka-schedule today. Rest well tonight.'],
      },
    },
    ZoeSituation.missedList: {
      MoodState.gentle: {
        ZoeLanguage.english: ["You missed: {items}. That's okay — we can pick them up one at a time."],
        ZoeLanguage.tagalog: ['Na-miss mo: {items}. Okay lang — isa-isahin natin.'],
        ZoeLanguage.both: ['Na-miss mo: {items}. Okay lang — isa-isahin natin.'],
      },
    },
    ZoeSituation.missedNone: {
      MoodState.proud: {
        ZoeLanguage.english: ["You didn't miss anything. Proud of you!"],
        ZoeLanguage.tagalog: ["Wala kang na-miss. Proud ako sa'yo!"],
        ZoeLanguage.both: ["Wala kang na-miss. Proud ako sa'yo!"],
      },
    },
  };
}