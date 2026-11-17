import 'dart:math';

import 'package:zoe_remind/core/constants/zoe_language.dart';

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

  /// "patayin mo ang alarm" — hindi pa kaya mula sa chat.
  stopAlarmHelp,

  /// "pagod na ako", "I'm sad" — nagkukuwento ng nararamdaman.
  comfort,

  /// Mensaheng tungkol sa pananakit sa sarili (tingnan ang CrisisGuard).
  crisis,
}

/// Zoe Lines — ang boses ni Zoe (Personality plan, P1 Voice).
///
/// Code ang pumipili ng sasabihin ni Zoe, hindi si Qwen, kaya laging tama
/// ang grammar sa English, Tagalog, at Taglish — at gumagana kahit walang model.
///
/// Personality: warm, encouraging, maikli at simple, honest. Walang sobrang
/// emoji, walang baby talk, walang paninisi.
///
/// Susunod (P2 Mood): dadagdagan ng mood (happy / gentle / sleepy…) ang pagpili.
class ZoeLines {
  ZoeLines._();

  static final _random = Random();

  /// Huling 5 linyang ginamit — para hindi paulit-ulit si Zoe.
  static final List<String> _recent = [];

  /// Pumili ng linya. [vars]: {'items': 'Study, Grocery'} → pinapalitan ang {items}.
  static String pick(
    ZoeLanguage lang,
    ZoeSituation situation, [
    Map<String, String> vars = const {},
  ]) {
    final options = _lines[situation]?[lang] ?? const <String>[];
    if (options.isEmpty) return '';

    final fresh = options.where((o) => !_recent.contains(o)).toList();
    final pool = fresh.isEmpty ? options : fresh;
    final chosen = pool[_random.nextInt(pool.length)];

    _recent.add(chosen);
    if (_recent.length > 5) _recent.removeAt(0);

    var line = chosen;
    for (final e in vars.entries) {
      line = line.replaceAll('{${e.key}}', e.value);
    }
    return line;
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
  };
}