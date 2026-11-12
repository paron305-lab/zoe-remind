import 'package:flutter/material.dart' show TimeOfDay;
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/repositories/reminder_repository.dart';
import 'package:zoe_remind/database/repositories/task_repository.dart';
import 'package:zoe_remind/features/chat/models/chat_drafts.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';

/// ⚠️ UI PREVIEW LANG — HINDI ITO SI QWEN.
///
/// Simpleng keyword matcher para ma-test ang lahat ng UI ng Zoe Chat
/// (confirmation cards, clarification chips, answer cards, error) kahit
/// wala pang AI. Papalitan ito ng totoong pipeline:
///   Input Guard → Qwen → JSON Validator → Allowlist → Safety Engine → code
///
/// Subukan:
///   "Zoe, remind me tomorrow at 7 PM to review my thesis"
///   "remind me bukas to call mama"        → magtatanong ng oras
///   "add task buy groceries on Saturday"
///   "i-note mo: wifi password ng office ay zoe123"
///   "ano gagawin ko today?" · "ano ginawa ko kahapon?" · "ano na-miss ko?"
///   "test error"                          → error state + Retry
class ChatPreviewBrain {
  ChatPreviewBrain({ReminderRepository? reminders, TaskRepository? tasks})
      : _reminders = reminders ?? ReminderRepository(),
        _tasks = tasks ?? TaskRepository();

  /// true = gumagana ang chat kahit walang naka-download na model.
  /// Gawing false kapag naka-wire na si Qwen.
  static const enabled = true;

  final ReminderRepository _reminders;
  final TaskRepository _tasks;

  ZoeLanguage _lang = ZoeLanguage.both;

  /// English → [en], Tagalog / Both → [tl].
  String _t(String en, String tl) => _lang == ZoeLanguage.english ? en : tl;

  Future<List<ChatEntry>> reply(String text, ZoeLanguage lang) async {
    _lang = lang;
    final lower = text.toLowerCase().trim();
    bool has(List<String> words) => words.any(lower.contains);

    if (lower == 'test error') throw StateError('UI preview error');

    if (has(['i-note', 'inote', 'i-save', 'isave', 'as note', 'as a note', 'note:', 'add note',
      'new note', 'add a note'])) {
      return [_note(text)];
    }
    if (has(['remind', 'paalala', 'ipaalala', 'alarm'])) return [_reminder(text, lower)];
    if (has(['task', 'todo', 'to-do', 'gawain'])) return [_task(text, lower)];

    if (has(['kahapon', 'yesterday'])) return [await _doneOn(_daysAgo(1))];
    if (has(['ginawa', 'what did i do', 'natapos'])) {
      return [await _doneOn(_pastWeekday(lower) ?? _daysAgo(1))];
    }
    if (has(['miss', 'nakalimutan'])) return [await _missed()];
    if (has(['today', 'ngayon', 'gagawin', 'schedule'])) return [await _today()];

    if (RegExp(r'\b(hi|hello|hey|kumusta|musta|good (morning|afternoon|evening))\b')
        .hasMatch(lower)) {
      return [
        TextEntry(
          fromZoe: true,
          text: _t('Hi! What can I help you with today? 😊',
              'Hi! Ano maitutulong ko sa\'yo today? 😊'),
        ),
      ];
    }
    if (has(['salamat', 'thank'])) {
      return [TextEntry(fromZoe: true, text: _t('Anytime! 💜', 'Walang anuman! 💜'))];
    }

    return [
      TextEntry(
        fromZoe: true,
        text: _t("Sorry, I didn't understand that. Can you say it another way?",
            'Pasensya, hindi ko naintindihan. Pwede mo bang ulitin?'),
        footnote: 'UI preview: try "remind me…", "add task…", "i-note mo…"',
      ),
    ];
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
    return completeReminder(ReminderDraft(title: _cleanTitle(text), date: day, time: time));
  }

  /// Kulang ang title → itanong. Kulang ang oras → chips. Kumpleto → card.
  ChatEntry completeReminder(ReminderDraft d) {
    if (d.title.isEmpty) {
      return ClarifyEntry(
        question: _t('What should I remind you about?', "Ano'ng ipapaalala ko sa'yo?"),
        reminder: d,
      );
    }
    if (d.time == null) {
      return ClarifyEntry(
        question: _t('What time?', 'Anong oras?'),
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
        question: _t("What's the task?", "Ano'ng task ang idadagdag ko?"),
        task: draft,
      );
    }
    return ConfirmEntry.task(draft);
  }

  ChatEntry _note(String text) {
    // "i-note mo: abc" → kunin ang nasa likod ng ":" kung meron.
    final colon = text.indexOf(':');
    var content = colon >= 0 ? text.substring(colon + 1) : text;
    if (colon < 0) {
      for (final p in [
        r'\bzoe\b[,]?',
        r'\b(pa)?(i-?save|i-?note)\s+mo(\s+(ito|to))?(\s+as\s+(a\s+)?note)?',
        r'\b(save|add)\s+(this\s+)?(as\s+)?(a\s+)?(new\s+)?note\b',
        r'\bnew\s+note\b',
      ]) {
        content = content.replaceAll(RegExp(p, caseSensitive: false), ' ');
      }
    }
    content = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    content = content.replaceAll(RegExp(r'^[\s,.:;-]+'), '');

    final draft = NoteDraft(content: content);
    if (content.isEmpty) {
      return ClarifyEntry(
        question: _t('What should I put in the note?', "Ano'ng ilalagay ko sa note?"),
        note: draft,
      );
    }
    return ConfirmEntry.note(draft);
  }

  // ───────────────────────── Reads (answer cards) ─────────────────────────
  // Deterministic code ang nagbabasa ng SQLite — ganito rin sa Memory Engine.

  Future<ChatEntry> _today() async {
    final day = _today0;
    final reminders = await _reminders.getForDay(day);
    final tasks = (await _tasks.getAll()).where((t) => t.date == ZoeDate.key(day)).toList();
    final pending = tasks.where((t) => !t.isDone).toList();
    final done = tasks.length - pending.length;

    final names = [
      ...pending.take(3).map((t) => t.title),
      ...reminders.take(2).map((r) => r.title),
    ];
    final text = names.isEmpty
        ? _t('Your day is free — nothing scheduled yet. ✨',
            'Wala ka pang naka-schedule today. Free day! ✨')
        : _t('Today you have: ${names.join(', ')}.', 'Ngayong araw: ${names.join(', ')}.');

    return AnswerEntry(
      assumption: 'Assuming today, ${ZoeDate.pretty(day)}',
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
          ? _t('I have nothing recorded as done that day.', 'Wala akong nakitang natapos mo noong araw na iyon.')
          : _t('That day you finished: ${names.take(4).join(', ')}.',
              'Noong araw na iyon, natapos mo: ${names.take(4).join(', ')}.'),
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
          ? _t("You didn't miss anything. Great job! 🎉", 'Wala kang na-miss. Galing! 🎉')
          : _t('You missed: ${missed.take(4).map((t) => t.title).join(', ')}.',
              'Na-miss mo: ${missed.take(4).map((t) => t.title).join(', ')}.'),
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

  DateTime? _day(String lower) {
    if (lower.contains('tomorrow') || lower.contains('bukas')) {
      return _today0.add(const Duration(days: 1));
    }
    if (RegExp(r'\b(today|ngayon|mamaya|tonight)\b').hasMatch(lower)) return _today0;
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
      r'\bremind\s+me\b',
      r'\b(pa)?paalala(han)?\s+mo\s+(ako|ko)\b',
      r'\bipaalala\s+mo(\s+sa\s+akin)?\b',
      r'\bset\s+(an?\s+)?(alarm|reminder)\b',
      r'\b(add|create|new)\s+(an?\s+)?(task|todo|to-do)\b',
      r'\b(task|todo|to-do|gawain)\b[:]?',
      r'\b(at|by|sa|ng)?\s*\d{1,2}(:\d{2})?\s*(am|pm|a\.m\.|p\.m\.)',
      r'\b(at|sa)?\s*alas[\s-]*\d{1,2}(:\d{2})?',
      r'\b(at|by)?\s*([01]?\d|2[0-3]):[0-5]\d\b',
      r'\bng\s+(umaga|gabi|hapon|tanghali)\b',
      r'\b(at\s+)?(noon|tanghali)\b',
      r'\b(tomorrow|bukas|today|ngayon|mamaya|tonight)\b',
      r'\b(on|sa|this|next)?\s*(monday|tuesday|wednesday|thursday|friday|saturday|sunday|lunes|martes|miyerkules|huwebes|biyernes|sabado|linggo)\b',
    ]) {
      s = s.replaceAll(RegExp(p, caseSensitive: false), ' ');
    }
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // tanggalin ang "to", "na", "para", bantas sa unahan / hulihan
    s = s.replaceFirst(RegExp(r'^(to|na|para|that|about)\s+', caseSensitive: false), '');
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