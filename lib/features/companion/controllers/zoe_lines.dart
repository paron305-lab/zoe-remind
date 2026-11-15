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
  };
}