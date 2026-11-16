import 'dart:async';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:zoe_remind/ai/parser/intent_classifier.dart';
import 'package:zoe_remind/ai/parser/intent_rules.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/models/note.dart';
import 'package:zoe_remind/database/repositories/note_repository.dart';
import 'package:zoe_remind/database/repositories/reminder_repository.dart';
import 'package:zoe_remind/database/repositories/task_repository.dart';
import 'package:zoe_remind/features/chat/models/chat_drafts.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';
import 'package:zoe_remind/features/companion/controllers/zoe_lines.dart';

/// Utak ng Zoe Chat (hybrid): code muna, si Qwen kapag hindi sigurado ang code.
///
///   1. IntentRules (code) → agad ang sagot, gumagana kahit walang model.
///   2. Walang tumamang rule? → tinatanong si Qwen kung anong INTENT (label lang).
///   3. Date, time, title → laging code ang kumukuha (hindi si Qwen).
///   4. Lahat ng write    → confirmation card; walang nase-save hangga't
///                          hindi pinipindot ng user ang Accept.
///   5. Ang mga salita ni Zoe ay galing sa ZoeLines (code), hindi kay Qwen.
///
/// Subukan (may keyword → code):
///   "Zoe, remind me tomorrow at 7 PM to review my thesis"
///   "pa remind ako ng feb 12 2028 mga 9am kakain ako"
///   "add task buy groceries on Saturday"
///   "i-note mo: wifi password ng office ay zoe123"
///   "ano gagawin ko today?" · "ano ginawa ko kahapon?" · "ano na-miss ko?"
///   "ano locker code ko?"                 → hinahanap sa Notes (code)
///   "89+9"                                → code ang nagko-compute, hindi si Qwen
/// Subukan (walang salitang "remind/task/note" pero code pa rin → agad):
///   "gisingin mo ako bukas ng 5:30am" · "kailangan kong magbayad ng kuryente"
///   "tandaan mo, ang wifi password sa bahay ay zoe2026" · "busy ba ako bukas?"
/// Subukan (walang tumamang rule → Qwen, ilang segundo):
///   "sino ang presidente ng Pilipinas?" · "ang ganda ng panahon"
///   "test error"                          → error state + Retry
class ChatPreviewBrain {
  ChatPreviewBrain({
    ReminderRepository? reminders,
    TaskRepository? tasks,
    NoteRepository? notes,
    IntentClassifier? classifier,
  })  : _reminders = reminders ?? ReminderRepository(),
        _tasks = tasks ?? TaskRepository(),
        _notes = notes ?? NoteRepository(),
        _classifier = classifier ?? IntentClassifier();

  /// true = gumagana ang chat (keywords) kahit walang naka-download na model.
  static const enabled = true;

  final ReminderRepository _reminders;
  final TaskRepository _tasks;
  final NoteRepository _notes;
  final IntentClassifier _classifier;

  ZoeLanguage _lang = ZoeLanguage.both;

  /// true = nasimulan na ang pag-load kay Qwen sa background.
  bool _warmStarted = false;

  /// English → [en], Tagalog / Both → [tl]. (Para sa maliliit na label lang.)
  String _t(String en, String tl) => _lang == ZoeLanguage.english ? en : tl;

  /// Linya ni Zoe mula sa ZoeLines, ayon sa napiling language.
  String _say(ZoeSituation s, [Map<String, String> vars = const {}]) =>
      ZoeLines.pick(_lang, s, vars);

  Future<List<ChatEntry>> reply(String text, ZoeLanguage lang) async {
    _lang = lang;
    final lower = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    bool has(List<String> words) => words.any(lower.contains);

    if (lower == 'test error') throw StateError('UI preview error');

    // Math → code ang sumasagot (laging tama), hindi si Qwen.
    final math = _math(lower);
    if (math != null) return [TextEntry(fromZoe: true, text: math)];

    // 1) Code muna (agad). 2) Kung hindi alam ng code → si Qwen (label lang).
    var intent = IntentRules.match(lower);
    var askedQwen = false;
    if (intent == ZoeIntent.unknown) {
      if (has(['salamat', 'thank'])) {
        return [TextEntry(fromZoe: true, text: _say(ZoeSituation.thanks))];
      }
      askedQwen = true;
      intent = await _classifier.classify(text) ?? ZoeIntent.unknown;
    } else if (!_warmStarted) {
      // Code ang sumagot ngayon. Habang nagbabasa ang user, ihanda na si Qwen
      // sa background para mabilis na siya kapag kinailangan mamaya.
      _warmStarted = true;
      unawaited(_classifier.warmUp());
    }

    switch (intent) {
      case ZoeIntent.createNote:
        return [_note(text)];
      case ZoeIntent.searchNotes:
        return [await _searchNotes(lower)];
      case ZoeIntent.createReminder:
        return [_reminder(text, lower)];
      case ZoeIntent.createTask:
        return [_task(text, lower)];
      case ZoeIntent.getDone:
        final day = has(['kahapon', 'yesterday']) ? _daysAgo(1) : _pastWeekday(lower);
        return [await _doneOn(day ?? _daysAgo(1))];
      case ZoeIntent.getMissed:
        return [await _missed()];
      case ZoeIntent.getToday:
        // "busy ba ako bukas?" → bukas ang titingnan, hindi today.
        return [await _scheduleOn(_day(lower) ?? _today0)];
      case ZoeIntent.greeting:
        return [TextEntry(fromZoe: true, text: _say(ZoeSituation.greeting))];
      case ZoeIntent.unknown:
        return [
          TextEntry(
            fromZoe: true,
            text: _say(ZoeSituation.unknown),
            // "AI: …" = pansamantala, para makita sa screenshot ang sagot at
            // bilis ni Qwen (hal. "unknown · 2.4s").
            footnote: 'Try: "remind me…", "add task…", "i-note mo…"'
                '${askedQwen ? ' · AI: ${IntentClassifier.lastResult}' : ''}',
          ),
        ];
    }
  }

  // ───────────────────────── Writes (cards) ─────────────────────────

  ChatEntry _reminder(String text, String lower) {
    final time = parseTime(lower);
    var day = _day(lower);
    // May oras pero walang araw → today, o bukas kung lumipas na ang oras.
    if (day == null && time != null) {
      final later = ZoeDate.combine(_today0, time).isAfter(DateTime.now());
      day = later ? _today0 : _today0.add(const Duration(days: 1));
    }
    var title = _cleanTitle(text);
    // "wake me up at 6am" → walang natirang title, pero malinaw ang ibig sabihin.
    if (title.isEmpty && lower.contains('wake me')) title = 'Wake up';
    if (title.isEmpty && lower.contains('gisingin')) title = _t('Wake up', 'Gumising');
    return completeReminder(ReminderDraft(title: title, date: day, time: time));
  }

  /// Kulang ang title → itanong. Kulang ang oras → chips. Kumpleto → card.
  ChatEntry completeReminder(ReminderDraft d) {
    if (d.title.isEmpty) {
      return ClarifyEntry(
        question: _say(ZoeSituation.askReminderTitle),
        reminder: d,
      );
    }
    if (d.time == null) {
      return ClarifyEntry(
        question: _say(ZoeSituation.askTime),
        reminder: d.copyWith(date: d.date ?? _today0.add(const Duration(days: 1))),
        chips: [
          const ClarifyChip('8 AM', TimeOfDay(hour: 8, minute: 0)),
          const ClarifyChip('12 PM', TimeOfDay(hour: 12, minute: 0)),
          const ClarifyChip('7 PM', TimeOfDay(hour: 19, minute: 0)),
          ClarifyChip(_t('Other', 'Iba pa'), null),
        ],
      );
    }
    return ConfirmEntry.reminder(d.copyWith(date: d.date ?? _today0));
  }

  ChatEntry _task(String text, String lower) {
    final time = parseTime(lower);
    final draft = TaskDraft(
      title: _cleanTitle(text),
      date: _day(lower) ?? (time == null ? null : _today0), // may oras → today
      time: time,
    );
    if (draft.title.isEmpty) {
      return ClarifyEntry(
        question: _say(ZoeSituation.askTaskTitle),
        task: draft,
      );
    }
    return ConfirmEntry.task(draft);
  }

  ChatEntry _note(String text) {
    // "i-note mo: abc" → kunin ang nasa likod ng ":" kung meron.
    // Hindi kasama ang ":" ng oras ("5:30").
    final colon = text.indexOf(RegExp(r':(?!\d\d)'));
    var content = colon >= 0 ? text.substring(colon + 1) : text;
    if (colon < 0) {
      for (final p in [
        r'\bzoe\b[,]?',
        r'\b(pa)?(i-?save|i-?note)\s+mo(\s+(ito|to))?(\s+as\s+(a\s+)?note)?',
        r'\b(save|add)\s+(this\s+)?(as\s+)?(a\s+)?(new\s+)?note\b',
        r'\bnew\s+note\b',
        r'\b(paki[\s-]?)?tandaan\s+mo(\s+(ito|to))?(\s+na)?\b',
        r'\b(write|jot)\s+(this|it|that)\s+down\b',
        r'\bremember\s+(that|this)\b',
        r'\b(keep|save)\s+(this|it)(\s+for\s+me)?\b',
        r'\btake\s+note(\s+(that|of))?\b',
        r'\b(isulat|i-?lista)\s+mo(\s+(ito|to))?(\s+na)?\b',
      ]) {
        content = content.replaceAll(RegExp(p, caseSensitive: false), ' ');
      }
    }
    content = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    content = content.replaceAll(RegExp(r'^[\s,.:;-]+'), '');

    final draft = NoteDraft(content: content);
    if (content.isEmpty) {
      return ClarifyEntry(
        question: _say(ZoeSituation.askNote),
        note: draft,
      );
    }
    return ConfirmEntry.note(draft);
  }

  // ───────────────────────── Reads (answer cards) ─────────────────────────
  // Deterministic code ang nagbabasa ng SQLite — ganito rin sa Memory Engine.

  /// Mga salitang hindi nakakatulong sa paghahanap ("ano", "ko", "the"…).
  static const _stopWords = {
    'ano', 'anong', "ano'ng", 'ang', 'ng', 'mga', 'ko', 'mo', 'ako', 'akin', 'yung', "'yung",
    'ba', 'sa', 'ay', 'na', 'nga', 'ulit', 'po', 'saan', 'nasaan', 'kailan', 'sino', 'zoe',
    'what', "what's", 'whats', 'is', 'are', 'was', 'the', 'my', 'a', 'an', 'of', 'where',
    'when', 'who', 'do', 'did', 'you', 'i', 'me', 'about', 'note', 'notes', 'remember',
    'nilagay', 'sinabi', 'told', 'again', 'please', 'paki',
    'naaalala', 'naalala', 'natatandaan', 'tanda', 'pa', 'still',
  };

  /// "ano locker code ko?" → hanapin ang "locker" at "code" sa Notes.
  /// Ang note mismo ang ipinapakita — walang iniimbento si Zoe.
  Future<ChatEntry> _searchNotes(String lower) async {
    final words = lower
        .replaceAll(RegExp(r"[^a-z0-9ñ'\s-]"), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2 && !_stopWords.contains(w))
        .take(6)
        .toList();

    // Bilangin kung ilang salita ang tumama sa bawat note.
    final hits = <int, int>{};
    final found = <int, Note>{};
    for (final word in words) {
      for (final note in await _notes.search(word, limit: 20)) {
        final id = note.id;
        if (id == null) continue;
        found[id] = note;
        hits[id] = (hits[id] ?? 0) + 1;
      }
    }

    if (found.isEmpty) {
      return AnswerEntry(
        assumption: _t('Searched your notes', 'Hinanap sa notes mo'),
        text: _say(ZoeSituation.noteNotFound),
      );
    }

    // Pinakamaraming tumamang salita ang una.
    final ranked = found.values.toList()
      ..sort((a, b) => hits[b.id]!.compareTo(hits[a.id]!));
    final best = ranked.first;
    final content = best.content.trim().isEmpty ? best.title : best.content.trim();
    final shown = content.length > 300 ? '${content.substring(0, 300)}…' : content;

    return AnswerEntry(
      assumption: _t('From your notes', 'Galing sa notes mo'),
      text: _say(ZoeSituation.noteFound, {'note': shown}),
      rows: [
        for (final other in ranked.skip(1).take(2))
          AnswerRow(AnswerTone.event, other.title),
      ],
    );
  }

  /// "89+9", "what is 12 x 3?", "100 / 8" → "100 ÷ 8 = 12.5". null = hindi math.
  String? _math(String lower) {
    final m = RegExp(
      r"^(?:(?:what is|what's|ano ang|magkano ang|ilan ang)\s+)?"
      r'(-?\d+(?:\.\d+)?)\s*([+\-*/x×÷])\s*(-?\d+(?:\.\d+)?)\s*[=?]*$',
    ).firstMatch(lower);
    if (m == null) return null;

    final a = double.parse(m.group(1)!);
    final b = double.parse(m.group(3)!);
    final op = m.group(2)!;
    double result;
    String sign;
    if (op == '+') {
      result = a + b;
      sign = '+';
    } else if (op == '-') {
      result = a - b;
      sign = '−';
    } else if (op == '/' || op == '÷') {
      if (b == 0) return _say(ZoeSituation.mathDivideByZero);
      result = a / b;
      sign = '÷';
    } else {
      result = a * b; // *, x, ×
      sign = '×';
    }
    return '${_num(a)} $sign ${_num(b)} = ${_num(result)}';
  }

  /// 98.0 → "98", 12.5 → "12.5", 0.333333 → "0.3333".
  String _num(double n) {
    if (n == n.roundToDouble() && n.abs() < 1e15) return n.round().toString();
    return n.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '');
  }

  /// Ano ang naka-schedule sa [day] (today, bukas, o "sa Sabado").
  Future<ChatEntry> _scheduleOn(DateTime day) async {
    final isToday = ZoeDate.sameDay(day, _today0);
    final label = ZoeDate.pretty(day);
    final reminders = await _reminders.getForDay(day);
    final tasks = (await _tasks.getAll()).where((t) => t.date == ZoeDate.key(day)).toList();
    final pending = tasks.where((t) => !t.isDone).toList();
    final done = tasks.length - pending.length;

    final names = [
      ...pending.take(3).map((t) => t.title),
      ...reminders.take(2).map((r) => r.title),
    ];
    final items = names.join(', ');
    final String text;
    if (isToday) {
      text = names.isEmpty
          ? _say(ZoeSituation.todayFree)
          : _say(ZoeSituation.todayList, {'items': items});
    } else {
      // Ililipat sa ZoeLines kasabay ng P2 Mood.
      text = names.isEmpty
          ? _t('Nothing scheduled on $label.', 'Wala kang naka-schedule sa $label.')
          : _t('On $label you have: $items.', 'Sa $label, meron kang: $items.');
    }

    return AnswerEntry(
      assumption: isToday ? 'Assuming today, $label' : 'Assuming $label',
      text: text,
      rows: [
        if (pending.isNotEmpty)
          AnswerRow(AnswerTone.event, '${pending.length} ${_plural(pending.length, 'task')} to do'),
        if (done > 0) AnswerRow(AnswerTone.done, '$done ${_plural(done, 'task')} completed'),
        if (reminders.isNotEmpty)
          AnswerRow(
            AnswerTone.reminder,
            '${reminders.length} ${_plural(reminders.length, 'reminder')}'
            ' · ${ZoeDate.prettyTime(ZoeDate.parseTime(reminders.first.time))}',
          ),
      ],
    );
  }

  Future<ChatEntry> _doneOn(DateTime day) async {
    final tasks = (await _tasks.getAll())
        .where((t) => t.isDone && t.completedAtTime != null && ZoeDate.sameDay(t.completedAtTime!, day))
        .toList();
    final reminders = (await _reminders.getForDay(day)).where((r) => r.isDoneOn(day)).toList();
    final names = [...tasks.map((t) => t.title), ...reminders.map((r) => r.title)];

    return AnswerEntry(
      assumption: 'Assuming ${ZoeDate.pretty(day)}',
      text: names.isEmpty
          ? _say(ZoeSituation.doneNone)
          : _say(ZoeSituation.doneList, {'items': names.take(4).join(', ')}),
      rows: [
        if (tasks.isNotEmpty)
          AnswerRow(AnswerTone.done, '${tasks.length} ${_plural(tasks.length, 'task')} completed'),
        if (reminders.isNotEmpty)
          AnswerRow(AnswerTone.reminder,
              '${reminders.length} ${_plural(reminders.length, 'reminder')} done'),
      ],
    );
  }

  Future<ChatEntry> _missed() async {
    final now = DateTime.now();
    final missed = (await _tasks.getAll()).where((t) => t.isMissedAt(now)).toList();
    return AnswerEntry(
      assumption: _t('Assuming the last 7 days', 'Assuming last 7 days'),
      text: missed.isEmpty
          ? _say(ZoeSituation.missedNone)
          : _say(ZoeSituation.missedList,
              {'items': missed.take(4).map((t) => t.title).join(', ')}),
      rows: [
        if (missed.isNotEmpty)
          AnswerRow(AnswerTone.missed, '${missed.length} missed ${_plural(missed.length, 'task')}'),
      ],
    );
  }

  // ───────────────────────── Helpers ─────────────────────────

  DateTime get _today0 => ZoeDate.dayOnly(DateTime.now());
  DateTime _daysAgo(int n) => _today0.subtract(Duration(days: n));
  String _plural(int n, String word) => n == 1 ? word : '${word}s';

  static const _weekdays = {
    'monday': 1, 'lunes': 1,
    'tuesday': 2, 'martes': 2,
    'wednesday': 3, 'miyerkules': 3,
    'thursday': 4, 'huwebes': 4,
    'friday': 5, 'biyernes': 5,
    'saturday': 6, 'sabado': 6,
    'sunday': 7, 'linggo': 7,
  };

  /// Walang "may" (Tagalog: "may 5 akong gagawin") — "mayo" ang gamitin.
  static const _months = {
    'january': 1, 'jan': 1, 'enero': 1,
    'february': 2, 'feb': 2, 'pebrero': 2,
    'march': 3, 'mar': 3, 'marso': 3,
    'april': 4, 'apr': 4, 'abril': 4,
    'mayo': 5,
    'june': 6, 'jun': 6, 'hunyo': 6,
    'july': 7, 'jul': 7, 'hulyo': 7,
    'august': 8, 'aug': 8, 'agosto': 8,
    'september': 9, 'sept': 9, 'sep': 9, 'setyembre': 9,
    'october': 10, 'oct': 10, 'oktubre': 10,
    'november': 11, 'nov': 11, 'nobyembre': 11,
    'december': 12, 'dec': 12, 'disyembre': 12,
  };

  /// "feb 12", "Feb. 12, 2028", "disyembre 5" — buwan + araw (+ taon).
  static final _monthDatePattern =
      '\\b(${_months.keys.join('|')})\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:,?\\s+(\\d{4}))?\\b';

  /// Walang taon at lumipas na ngayong taon → susunod na taon.
  DateTime? _monthDate(String lower) {
    final m = RegExp(_monthDatePattern).firstMatch(lower);
    if (m == null) return null;
    final month = _months[m.group(1)!]!;
    final dayNum = int.parse(m.group(2)!);
    final year = int.tryParse(m.group(3) ?? '');
    var date = DateTime(year ?? _today0.year, month, dayNum);
    if (date.month != month) return null; // hal. "feb 31"
    if (year == null && date.isBefore(_today0)) {
      date = DateTime(_today0.year + 1, month, dayNum);
    }
    return date;
  }

  DateTime? _day(String lower) {
    final exact = _monthDate(lower);
    if (exact != null) return exact;
    if (lower.contains('tomorrow') || lower.contains('bukas')) {
      return _today0.add(const Duration(days: 1));
    }
    if (RegExp(r'\b(today|ngayon|ngayong|mamaya|mamayang|tonight|later)\b').hasMatch(lower)) {
      return _today0;
    }
    for (final e in _weekdays.entries) {
      if (RegExp('\\b${e.key}\\b').hasMatch(lower)) {
        var ahead = (e.value - _today0.weekday + 7) % 7;
        if (ahead == 0) ahead = 7; // "on Monday" = susunod na Monday
        return _today0.add(Duration(days: ahead));
      }
    }
    return null;
  }

  /// "last Monday" / "noong Lunes" → pinakahuling Monday bago ngayon.
  DateTime? _pastWeekday(String lower) {
    for (final e in _weekdays.entries) {
      if (RegExp('\\b${e.key}\\b').hasMatch(lower)) {
        var back = (_today0.weekday - e.value + 7) % 7;
        if (back == 0) back = 7;
        return _today0.subtract(Duration(days: back));
      }
    }
    return null;
  }

  /// "7 PM", "7:30pm", "alas 7 ng gabi", "19:00", "noon" → TimeOfDay.
  TimeOfDay? parseTime(String lower) {
    final ampm = RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)').firstMatch(lower);
    if (ampm != null) {
      final h = int.parse(ampm.group(1)!);
      final m = int.tryParse(ampm.group(2) ?? '') ?? 0;
      if (h < 1 || h > 12 || m > 59) return null;
      final pm = ampm.group(3)!.startsWith('p');
      return TimeOfDay(hour: h % 12 + (pm ? 12 : 0), minute: m);
    }
    // "alas 7 ng gabi", "alas-8 ng umaga"
    final alas = RegExp(r'\balas[\s-]*(\d{1,2})(?::(\d{2}))?').firstMatch(lower);
    if (alas != null) {
      final h = int.parse(alas.group(1)!);
      final m = int.tryParse(alas.group(2) ?? '') ?? 0;
      if (h < 1 || h > 12 || m > 59) return null;
      final pm = lower.contains('gabi') || lower.contains('hapon');
      return TimeOfDay(hour: h % 12 + (pm ? 12 : 0), minute: m);
    }
    // "at 19:30"
    final h24 = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)\b').firstMatch(lower);
    if (h24 != null) {
      return TimeOfDay(hour: int.parse(h24.group(1)!), minute: int.parse(h24.group(2)!));
    }
    if (RegExp(r'\b(noon|tanghali)\b').hasMatch(lower)) {
      return const TimeOfDay(hour: 12, minute: 0);
    }
    return null;
  }

  /// "Zoe, remind me tomorrow at 7 PM to review my thesis" → "Review my thesis"
  String _cleanTitle(String text) {
    var s = text;
    for (final p in [
      r'\bzoe\b[,:]?',
      r'\b(pa[\s-]?)?remind\s+(me|ako|mo\s+ako)\b',
      r'\b(please\s+)?wake\s+me(\s+up)?\b',
      r'\b(paki[\s-]?)?gisingin\s+mo\s+(ako|ko)\b',
      r'\b(paki[\s-]?)?(sabihan|abisuhan|i-?alert)\s+mo\s+(ako|ko)\b',
      r"\bdon'?t\s+let\s+me\s+forget\b",
      r'\b(huwag|wag)\s+mo(ng)?\s+kalimutan(g)?\s+(sabihan|paalalahanan)\s+(ako|ko)\b',
      r'\b(huwag|wag)\s+mo(ng)?\s+(akong\s+)?kalimutan(g)?\b',
      r"\b(i\s+need\s+to|i\s+have\s+to|i\s+got\s+to|i'?ve\s+got\s+to|i\s+must|i\s+should|i\s+gotta)\b",
      r'\b(kailangan|kelangan|need)\s+ko(ng)?\b',
      r'\bdapat\s+(ko(ng)?|akong)\b',
      r'\b(pa)?gawan\s+mo\s+(ako|ko)(\s+ng)?\b',
      r'\b(ang\s+)?title\s*(ay|is|:)?',
      r'\b(time|oras)\s*(ay|is|:)?\s*(?=\d)',
      '\\b(on|sa|ng|noong)?\\s*$_monthDatePattern',
      r'\b(pa)?paalala(han)?\s+mo\s+(ako|ko)\b',
      r'\bipaalala\s+mo(\s+sa\s+akin)?\b',
      r'\bset\s+(an?\s+)?(alarm|reminder)\b',
      r'\b(add|create|new)\s+(an?\s+)?(task|todo|to-do)\b',
      r'\b(task|todo|to-do|gawain)\b[:]?',
      r'\b((at|by|sa|ng|mga)\s+)*\d{1,2}(:\d{2})?\s*(am|pm|a\.m\.|p\.m\.)',
      r'\b(at|sa)?\s*alas[\s-]*\d{1,2}(:\d{2})?',
      r'\b(at|by)?\s*([01]?\d|2[0-3]):[0-5]\d\b',
      r'\bng\s+(umaga|gabi|hapon|tanghali)\b',
      r'\b(at\s+)?(noon|tanghali)\b',
      r'\b(tomorrow|bukas|today|ngayon|ngayong|mamaya|mamayang|tonight|later)\b',
      r'\b(on|by|sa|this|next)?\s*(monday|tuesday|wednesday|thursday|friday|saturday|sunday|lunes|martes|miyerkules|huwebes|biyernes|sabado|linggo)\b',
    ]) {
      s = s.replaceAll(RegExp(p, caseSensitive: false), ' ');
    }
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // tanggalin ang "to", "na", "ng", "mga", "para", bantas sa unahan / hulihan
    s = s.replaceFirst(
        RegExp(r'^((to|na|ng|mga|para|that|about)\s+)+', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'^[\s,.:;!?-]+|[\s,.:;!?-]+$'), '');
    if (s.isEmpty) return '';
    final title = s[0].toUpperCase() + s.substring(1);
    return title.length > 100 ? title.substring(0, 100) : title;
  }
}

/// Emoji sa card (display lang, hindi sine-save sa title).
String draftEmoji(String title, DraftKind kind) {
  final l = title.toLowerCase();
  bool has(List<String> w) => w.any(l.contains);
  if (has(['thesis', 'study', 'aral', 'review', 'exam', 'chapter'])) return '📚';
  if (has(['gamot', 'medicine', 'vitamin', 'pill'])) return '💊';
  if (has(['grocery', 'groceries', 'palengke', 'buy', 'bili'])) return '🛒';
  if (has(['meeting', 'call', 'tawag', 'zoom'])) return '📞';
  if (has(['workout', 'gym', 'run', 'exercise', 'takbo'])) return '🏃';
  if (has(['bayad', 'pay', 'bill', 'rent'])) return '💳';
  if (has(['birthday', 'bday', 'kaarawan'])) return '🎂';
  return switch (kind) {
    DraftKind.reminder => '🔔',
    DraftKind.task => '✅',
    DraftKind.note => '📝',
  };
}