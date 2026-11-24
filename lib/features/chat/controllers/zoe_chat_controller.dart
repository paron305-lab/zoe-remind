import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zoe_remind/ai/parser/crisis_guard.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/models/model_info.dart';
import 'package:zoe_remind/database/models/note.dart';
import 'package:zoe_remind/database/models/reminder.dart';
import 'package:zoe_remind/database/models/task.dart';
import 'package:zoe_remind/database/repositories/chat_history_repository.dart';
import 'package:zoe_remind/database/repositories/memory_repository.dart';
import 'package:zoe_remind/database/repositories/note_repository.dart';
import 'package:zoe_remind/database/repositories/reminder_repository.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/database/repositories/task_repository.dart';
import 'package:zoe_remind/features/chat/controllers/chat_preview_brain.dart';
import 'package:zoe_remind/features/chat/controllers/context_replies.dart';
import 'package:zoe_remind/features/chat/models/chat_drafts.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';
import 'package:zoe_remind/features/companion/controllers/mood_controller.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';
import 'package:zoe_remind/features/reminders/services/reminder_alarm_service.dart';
import 'package:zoe_remind/memory/companion_facts.dart';
import 'package:zoe_remind/memory/habit_rules.dart';
import 'package:zoe_remind/memory/habit_watcher.dart';

/// Estado ng header: Ready / Thinking… / No brain yet / Downloading.
enum ZoeChatStatus { ready, thinking, preview, noBrain, downloading }

/// Lahat ng logic ng Zoe Chat screen (walang widgets dito).
///
/// Golden rule: si Zoe (AI) ay nagmumungkahi lang. Ang code na ito ang
/// nagva-validate at nagse-save — at laging pagkatapos ng Accept ng user.
class ZoeChatController extends ChangeNotifier {
  ZoeChatController({ChatPreviewBrain? brain, HabitWatcher? habits})
      : _brain = brain ?? ChatPreviewBrain(),
        _habits = habits ?? HabitWatcher();

  static const maxInput = 500; // Input Guard (length limit)

  final ChatPreviewBrain _brain;

  /// B6 implicit learning: napapansin ang ugali (hal. morning reminders).
  final HabitWatcher _habits;
  final _settings = SettingsRepository();
  final _history = ChatHistoryRepository();
  final _reminders = ReminderRepository();
  final _tasks = TaskRepository();
  final _notes = NoteRepository();
  final _memories = MemoryRepository();

  final List<ChatEntry> entries = [];
  ModelInfo model = ModelInfo.none;
  ZoeLanguage language = ZoeLanguage.both;
  String userName = '';
  bool loading = true;
  bool thinking = false;

  int? _conversationId;
  bool _writingHistory = false;
  bool _disposed = false;

  /// Nag-error ang huling sagot → "sorry" si Zoe hanggang sa susunod na maayos.
  bool _failedBefore = false;

  // ───────────────────────── Lifecycle ─────────────────────────

  Future<void> init() async {
    SettingsRepository.changes.addListener(_loadSettings);
    ChatHistoryRepository.changes.addListener(_onHistoryChanged);
    await _loadSettings();
    loading = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    SettingsRepository.changes.removeListener(_loadSettings);
    ChatHistoryRepository.changes.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _loadSettings() async {
    try {
      model = await _settings.getModelInfo();
      language = await _settings.getLanguage();
      userName = (await _settings.getUserName()) ?? '';
    } catch (e) {
      debugPrint('Zoe chat: loading settings failed: $e');
    }
    _notify();
  }

  /// Na-clear ang chat history sa Settings → linisin din ang screen.
  Future<void> _onHistoryChanged() async {
    final id = _conversationId;
    if (_writingHistory || id == null) return;
    final msgs = await _history.messages(id);
    if (msgs.isEmpty) {
      entries.clear();
      _conversationId = null;
      _notify();
    }
  }

  // ───────────────────────── Status ─────────────────────────

  /// Pwedeng mag-type? Ready ang brain, o naka-on ang UI preview.
  bool get canChat => model.isReady || ChatPreviewBrain.enabled;

  ZoeChatStatus get status {
    if (thinking) return ZoeChatStatus.thinking;
    if (model.isReady) return ZoeChatStatus.ready;
    if (model.isDownloading || model.isQueued) return ZoeChatStatus.downloading;
    if (ChatPreviewBrain.enabled) return ZoeChatStatus.preview;
    return ZoeChatStatus.noBrain;
  }

  bool get isEmpty => entries.isEmpty;

  String t(String en, String tl) => language == ZoeLanguage.english ? en : tl;

  String get inputHint => switch (language) {
        ZoeLanguage.english => 'Message Zoe…',
        ZoeLanguage.tagalog => 'Mag-message kay Zoe…',
        ZoeLanguage.both => 'Message Zoe in Taglish…',
      };

  List<String> get suggestions => [
        t('What do I have today?', 'Ano gagawin ko today?'),
        t('Remind me tomorrow at 7 PM to…', 'Remind me bukas ng 7 PM to…'),
        t('What did I miss?', 'Ano na-miss ko?'),
        t('Save a note…', 'I-note mo: …'),
      ];

  // ───────────────────────── Sending ─────────────────────────

  /// Ipadala ang mensahe ng user.
  /// Returns ang card na na-ACCEPT sa pamamagitan ng "oo" / "sige" (para ma-check
  /// ng screen ang alarm permissions), o null.
  Future<ConfirmEntry?> send(String raw) async {
    var text = raw.trim();
    if (text.isEmpty || thinking || !canChat) return null;
    if (text.length > maxInput) text = text.substring(0, maxInput);

    // Card na naghihintay (bago idagdag ang mensahe ng user).
    final card = _pendingCardOnTop();

    entries.add(TextEntry(fromZoe: false, text: text));
    _notify();
    unawaited(_save('user', text));

    // "ay wag na pala" / "oo" / "mali, 8pm pala" → tungkol sa card sa itaas.
    // (Pananakit sa sarili → laging crisis reply, hindi ito.)
    if (card != null && !CrisisGuard.matches(text)) {
      final handled = await _cardReply(card, text);
      if (handled != null) return handled.accepted;
    }

    // May hinihintay bang sagot si Zoe (uri / title / oras)?
    final pending = _openClarify();
    if (pending != null) {
      pending.answered = true;
      final next = await _answerClarify(pending, text);
      if (next != null) {
        await _zoeSays(next);
        return null;
      }
    }
    await _respond(text);
    return null;
  }

  /// Ang pinakahuling entry ay card na naghihintay ng Accept? (Info pills ay nilalaktawan.)
  ConfirmEntry? _pendingCardOnTop() {
    for (final e in entries.reversed) {
      if (e is InfoEntry) continue;
      return e is ConfirmEntry && e.isPending ? e : null;
    }
    return null;
  }

  /// Maikling sagot sa card. null = hindi tungkol sa card (normal na reply).
  Future<_CardReply?> _cardReply(ConfirmEntry card, String text) async {
    if (ContextReplies.isCancel(text)) {
      cancel(card);
      return const _CardReply();
    }
    if (ContextReplies.isYes(text)) {
      final saved = await accept(card);
      // Memory: may sariling linya na si Zoe pagkatapos ng accept (Level 3).
      if (saved && card.kind != DraftKind.memory) {
        entries.add(TextEntry(fromZoe: true, text: t('Done — saved! ✓', 'Ayan, na-save na! ✓')));
        _notify();
      }
      return _CardReply(saved ? card : null);
    }
    final fixable = card.kind == DraftKind.reminder || card.kind == DraftKind.task;
    if (fixable && ContextReplies.isCorrection(text, now: _brain.now)) {
      final lower = ContextReplies.clean(text);
      final time = _brain.parseTime(lower);
      final day = _brain.parseDay(lower);
      card.status = DraftStatus.cancelled; // papalitan ng bagong card
      final fixed = card.kind == DraftKind.reminder
          ? ConfirmEntry.reminder(card.reminder!.copyWith(time: time, date: day))
          : ConfirmEntry.task(card.task!.copyWith(time: time, date: day));
      await _zoeSays([
        TextEntry(fromZoe: true, text: t("Got it, I fixed it. Here's the new one:",
            'Sige, inayos ko. Ito na ang bago:')),
        fixed,
      ]);
      return const _CardReply();
    }
    return null;
  }

  /// Retry ng error bubble → ipadala ulit nang hindi dinodoble ang user bubble.
  Future<void> retry(ErrorEntry e) async {
    entries.remove(e);
    _notify();
    await _respond(e.retryText);
  }

  Future<void> _respond(String text) async {
    final typing = TypingEntry();
    thinking = true;
    entries.add(typing);
    _notify();

    List<ChatEntry> reply;
    try {
      // Maliit na delay para makita ang "Thinking…" state (UI preview).
      final results = await Future.wait([
        _brain.reply(text, language),
        Future<void>.delayed(const Duration(milliseconds: 700)),
      ]);
      reply = results.first as List<ChatEntry>;
      if (_failedBefore) {
        // Nakasagot na ulit nang maayos (ang sagot na ito ay "Sorry kanina…"
        // pa kung bati) → tapos na ang sorry mood.
        _failedBefore = false;
        MoodController.instance.add(const ActionSucceeded());
      }
    } catch (e) {
      debugPrint('Zoe chat reply failed: $e');
      // Kasalanan ni Zoe ito → "sorry" mood. Matatapos sa susunod na na-save.
      _failedBefore = true;
      MoodController.instance.add(const ZoeFailed(ZoeFailure.inference));
      reply = [
        ErrorEntry(
          text: t("Sorry, something went wrong. Can you try again?",
              'Pasensya, hindi ko naintindihan. Pwede mo bang ulitin?'),
          retryText: text,
        ),
      ];
    }

    entries.remove(typing);
    thinking = false;
    await _zoeSays(reply);
  }

  Future<void> _zoeSays(List<ChatEntry> reply) async {
    entries.addAll(reply);
    _notify();
    for (final r in reply) {
      final line = switch (r) {
        TextEntry(fromZoe: true, :final text) => text,
        ClarifyEntry(:final question) => question,
        AnswerEntry(:final text) => text,
        ConfirmEntry card => _cardSummary(card),
        _ => null,
      };
      if (line != null) await _save('zoe', line);
    }
  }

  // ───────────────────────── Clarification ─────────────────────────

  ClarifyEntry? _openClarify() {
    for (final e in entries.reversed) {
      if (e is ClarifyEntry && !e.answered) return e;
      if (e is ConfirmEntry) return null; // may mas bago nang card
    }
    return null;
  }

  /// Ang type ng user ay sagot sa tanong ni Zoe. null = hindi sagot (normal na reply).
  Future<List<ChatEntry>?> _answerClarify(ClarifyEntry c, String text) async {
    // Kahit may nakabinbing tanong ("Anong oras?"), hindi ginagawang title o
    // note ang mensaheng tungkol sa pananakit sa sarili → crisis reply.
    if (CrisisGuard.matches(text)) return null;

    // Level 3: "Kapag stressed ka, ano'ng nakakatulong?" → "makinig ka lang" / "wag na".
    if (c.asksHelp) {
      final help = CompanionFacts.helpChoice(ContextReplies.clean(text));
      if (help != null) {
        try {
          return await _saveHelp(help);
        } catch (e) {
          debugPrint('Zoe chat: saving stress help failed: $e');
          return [
            TextEntry(
              fromZoe: true,
              text: t("I couldn't save that. Please try again.", 'Hindi ko na-save. Pakisubukan ulit.'),
            ),
          ];
        }
      }
      if (ContextReplies.isCancel(text)) {
        return [TextEntry(fromZoe: true, text: await _brain.helpSkipLine(language))];
      }
      return null; // ibang mensahe → normal na reply
    }

    // "Reminder ba 'to, task, o note?" → "task" / "reminder na lang" / "wag na".
    if (c.asksKind) {
      final kind = ContextReplies.kindFromText(text);
      if (kind != null) {
        if (kind == DraftKind.memory && !c.chips.any((x) => x.kind == DraftKind.memory)) {
          return null; // walang Tandaan sa tanong na ito → normal na reply
        }
        return _brain.draftFor(kind, c.source!, language);
      }
      if (ContextReplies.isCancel(text)) {
        return [TextEntry(fromZoe: true, text: _brain.skipLine(language))];
      }
      return null; // ibang mensahe → normal na reply
    }

    final title = text.length > 100 ? text.substring(0, 100) : text;
    if (c.reminder != null) {
      final d = c.reminder!;
      if (c.wantsText) return [_brain.completeReminder(d.copyWith(title: title))];
      // "Anong oras?" pero nag-type → subukang basahin ang oras.
      final time = _brain.parseTime(ContextReplies.clean(text));
      if (time != null) return [ConfirmEntry.reminder(d.copyWith(time: time))];
      return null; // ibang tanong → normal na reply
    }
    if (c.task != null) return [ConfirmEntry.task(c.task!.copyWith(title: title))];
    if (c.note != null) return [ConfirmEntry.note(c.note!.copyWith(content: text))];
    return null;
  }

  /// Pinindot ang chip ng uri ([⏰ Reminder] [✅ Task] [📝 Note] [💜 Tandaan] [✖ Wala]).
  Future<void> pickKind(ClarifyEntry c, ClarifyChip chip) async {
    if (c.asksHelp) return pickHelp(c, chip);
    if (c.answered || !c.asksKind || chip.isTime) return;
    c.answered = true;
    entries.add(TextEntry(fromZoe: false, text: chip.label));
    _notify();
    unawaited(_save('user', chip.label));
    if (chip.skip) {
      await _zoeSays([TextEntry(fromZoe: true, text: _brain.skipLine(language))]);
      return;
    }
    List<ChatEntry> next;
    try {
      next = await _brain.draftFor(chip.kind!, c.source!, language);
    } catch (e) {
      debugPrint('Zoe chat: making card failed: $e');
      next = [
        ErrorEntry(
          text: t('Sorry, something went wrong. Can you try again?',
              'Pasensya, may mali. Pwede mo bang ulitin?'),
          retryText: c.source!,
        ),
      ];
    }
    await _zoeSays(next);
  }

  /// Level 3: pinindot ang [🎧 Makinig] [💡 Payo] [😄 Pampagaan] [✖ Huwag na].
  /// Ang pagpindot mismo ang pagkumpirma ng user → nase-save agad.
  Future<void> pickHelp(ClarifyEntry c, ClarifyChip chip) async {
    if (c.answered || !c.asksHelp) return;
    c.answered = true;
    entries.add(TextEntry(fromZoe: false, text: chip.label));
    _notify();
    unawaited(_save('user', chip.label));
    final help = StressHelp.fromValue(chip.help);
    List<ChatEntry> next;
    try {
      next = chip.skip || help == null
          ? [TextEntry(fromZoe: true, text: await _brain.helpSkipLine(language))]
          : await _saveHelp(help);
    } catch (e) {
      debugPrint('Zoe chat: saving stress help failed: $e');
      next = [
        TextEntry(
          fromZoe: true,
          text: t("I couldn't save that. Please try again.", 'Hindi ko na-save. Pakisubukan ulit.'),
        ),
      ];
    }
    await _zoeSays(next);
  }

  /// I-save ang stress help (isa lang — napapalitan ang luma) + linya ni Zoe.
  Future<List<ChatEntry>> _saveHelp(StressHelp help) async {
    final fact = FactRead(FactKind.stressHelp, help.value);
    final content = CompanionFacts.cardText(fact, tagalog: language != ZoeLanguage.english)!;
    final id = await _memories.add(content, source: 'user', kind: fact.kind, value: fact.value);
    if (id == null) {
      return [
        TextEntry(
          fromZoe: true,
          text: t('Long-term memory is off. Turn it on in Settings › Privacy & Memory.',
              'Naka-OFF ang long-term memory. I-ON mo sa Settings › Privacy & Memory.'),
        ),
      ];
    }
    return [TextEntry(fromZoe: true, text: await _brain.savedLine(fact, language))];
  }

  /// Pinindot ang chip (8 AM / 12 PM / 7 PM o napili sa time picker).
  Future<void> pickTime(ClarifyEntry c, TimeOfDay time) async {
    if (c.answered || c.reminder == null) return;
    c.answered = true;
    final label = ZoeDate.prettyTime(time);
    entries.add(TextEntry(fromZoe: false, text: label));
    _notify();
    unawaited(_save('user', label));
    await _zoeSays([ConfirmEntry.reminder(c.reminder!.copyWith(time: time))]);
  }

  // ───────────────────────── Confirmation cards ─────────────────────────

  void cancel(ConfirmEntry e) {
    if (!e.isPending) return;
    e.status = DraftStatus.cancelled;
    // B6: "Huwag" sa mungkahi ni Zoe → hindi na niya ito itatanong ulit.
    final habit = e.memory?.habit;
    if (habit != null) {
      for (final h in Habit.values) {
        if (h.name == habit) unawaited(_declineHabit(h));
      }
    }
    entries.add(TextEntry(
      fromZoe: true,
      text: t("Okay, I won't save it.", 'Sige, hindi ko na ise-save. 👍'),
    ));
    _notify();
  }

  /// [Accept] → validate (code ang nagdedesisyon) → save.
  /// Returns true kapag na-save (para sa reminder: i-check ang permissions).
  Future<bool> accept(ConfirmEntry e) async {
    if (!e.isPending) return false;

    final problem = _validate(e);
    if (problem != null) {
      entries.add(TextEntry(fromZoe: true, text: problem));
      _notify();
      return false;
    }

    e.status = DraftStatus.saving;
    _notify();
    final now = DateTime.now().toIso8601String();

    try {
      switch (e.kind) {
        case DraftKind.reminder:
          final d = e.reminder!;
          final id = await _reminders.add(Reminder(
            title: d.title,
            date: ZoeDate.key(d.date!),
            time: ZoeDate.timeKey(d.time!),
            repeat: d.repeat,
            createdAt: now,
            updatedAt: now,
          ));
          await ReminderAlarmService.instance.syncById(id);
          e.savedId = id;
        case DraftKind.task:
          final d = e.task!;
          e.savedId = await _tasks.add(Task(
            title: d.title,
            description: d.notes,
            date: d.date == null ? null : ZoeDate.key(d.date!),
            time: d.date == null || d.time == null ? null : ZoeDate.timeKey(d.time!),
            priority: d.priority,
            category: d.category ?? Task.defaultCategory,
            createdAt: now,
          ));
        case DraftKind.note:
          final d = e.note!;
          e.savedId = await _notes.add(
            title: d.title,
            content: d.content,
            source: NoteSource.zoe,
          );
        case DraftKind.memory:
          // 'user' = sinabi mo mismo. 'chat' = mungkahi ni Zoe na in-Accept mo (B6).
          // null = OFF ang long-term memory.
          // Level 3: anong klase (nickname / style / stress help / win / routine).
          final fact = CompanionFacts.read(e.memory!.content);
          final id = await _memories.add(
            e.memory!.content,
            source: e.memory!.isSuggestion ? 'chat' : 'user',
            kind: fact.kind,
            value: fact.value,
          );
          if (id == null) {
            e.status = DraftStatus.pending;
            entries.add(TextEntry(
              fromZoe: true,
              text: t('Long-term memory is off. Turn it on in Settings › Privacy & Memory.',
                  'Naka-OFF ang long-term memory. I-ON mo sa Settings › Privacy & Memory.'),
            ));
            _notify();
            return false;
          }
          e.savedId = id;
      }
      e.status = DraftStatus.saved;
      _notify();
      await _save('zoe', _savedLine(e));
      // B6: bagong reminder → may napansing ugali ba? (mungkahi lang, may card)
      if (e.kind == DraftKind.reminder) unawaited(_offerHabit());
      // Level 3: "AC na ang itatawag ko sa'yo." / "Short and direct from now on."
      if (e.kind == DraftKind.memory) unawaited(_afterMemory(e.memory!.content));
      return true;
    } catch (err) {
      debugPrint('Zoe chat: saving card failed: $err');
      e.status = DraftStatus.pending;
      entries.add(TextEntry(
        fromZoe: true,
        text: t("I couldn't save that. Please try again.",
            'Hindi ko na-save. Pakisubukan ulit.'),
      ));
      _notify();
      return false;
    }
  }

  /// Linya ni Zoe pagkatapos ma-save ang memory (ayon sa uri).
  Future<void> _afterMemory(String content) async {
    try {
      final line = await _brain.savedLine(CompanionFacts.read(content), language);
      if (_disposed) return;
      await _zoeSays([TextEntry(fromZoe: true, text: line)]);
    } catch (err) {
      debugPrint('Zoe chat: memory line failed: $err');
    }
  }

  // ───────────────────────── Implicit learning (B6) ─────────────────────────

  /// Pagkatapos mag-save ng reminder: "Napansin ko… tandaan ko ba?" + card.
  /// Walang lalabas kapag OFF ang long-term memory, may memory na tungkol
  /// diyan, tinanggihan na, o naitanong na kamakailan (HabitWatcher).
  Future<void> _offerHabit() async {
    try {
      final suggestion = await _habits.next();
      if (suggestion == null || _disposed) return;
      await _zoeSays(_brain.habitOffer(suggestion, language));
    } catch (err) {
      debugPrint('Zoe chat: habit check failed: $err');
    }
  }

  Future<void> _declineHabit(Habit habit) async {
    try {
      await _habits.decline(habit);
    } catch (err) {
      debugPrint('Zoe chat: saving habit decline failed: $err');
    }
  }

  /// Validation bago mag-save. null = OK.
  String? _validate(ConfirmEntry e) {
    final now = DateTime.now();
    final today = ZoeDate.dayOnly(now);
    switch (e.kind) {
      case DraftKind.reminder:
        final d = e.reminder!;
        if (d.title.trim().isEmpty || !d.hasWhen) {
          return t('Something is missing — tap Edit to fill it in.',
              'May kulang pa — pindutin ang Edit para kumpletuhin.');
        }
        if (d.repeat == ReminderRepeat.none &&
            !ZoeDate.combine(d.date!, d.time!).isAfter(now)) {
          return t('That time already passed — tap Edit to pick a later time.',
              'Lumipas na yung oras na yan — pindutin ang Edit para pumili ng bago.');
        }
      case DraftKind.task:
        final d = e.task!;
        if (d.title.trim().isEmpty) {
          return t('The task needs a title — tap Edit.', 'Walang title ang task — pindutin ang Edit.');
        }
        if (d.date != null && d.date!.isBefore(today)) {
          return t('That day already passed — tap Edit to pick another date.',
              'Lumipas na ang araw na yan — pindutin ang Edit para pumili ng iba.');
        }
      case DraftKind.note:
        if (e.note!.content.trim().isEmpty) {
          return t('The note is empty — tap Edit.', 'Walang laman ang note — pindutin ang Edit.');
        }
      case DraftKind.memory:
        if (e.memory!.content.trim().isEmpty) {
          return t('There is nothing to remember — tap Edit.',
              'Walang laman — pindutin ang Edit.');
        }
    }
    return null;
  }

  /// Na-save mula sa Edit screen (reminder / task form) → i-update ang card.
  Future<void> savedFromEditor(ConfirmEntry e, int id) async {
    try {
      switch (e.kind) {
        case DraftKind.reminder:
          final r = await _reminders.getById(id);
          if (r != null) {
            e.reminder = ReminderDraft(
              title: r.title,
              date: ZoeDate.parseKey(r.date),
              time: ZoeDate.parseTime(r.time),
              repeat: r.repeat,
            );
          }
        case DraftKind.task:
          final task = await _tasks.getById(id);
          if (task != null) {
            e.task = TaskDraft(
              title: task.title,
              notes: task.description,
              date: task.day,
              time: task.timeOfDay,
              priority: task.priority,
              category: task.category,
            );
          }
        case DraftKind.note:
        case DraftKind.memory:
          break;
      }
    } catch (err) {
      debugPrint('Zoe chat: reloading saved item failed: $err');
    }
    e
      ..savedId = id
      ..edited = true
      ..status = DraftStatus.saved;
    _notify();
    await _save('zoe', _savedLine(e));
  }

  /// Note card [Edit] (bottom sheet) → palitan ang draft, pending pa rin.
  void updateNote(ConfirmEntry e, NoteDraft draft) {
    if (!e.isPending) return;
    e.note = draft;
    _notify();
  }

  /// Memory card [Edit] (bottom sheet) → palitan ang draft, pending pa rin.
  void updateMemory(ConfirmEntry e, MemoryDraft draft) {
    if (!e.isPending) return;
    e.memory = draft;
    _notify();
  }

  // ───────────────────────── Menu / language ─────────────────────────

  /// "Clear chat" → bagong conversation. Nasa Settings › Chat history pa rin ang luma.
  void clearChat() {
    entries.clear();
    _conversationId = null;
    _notify();
  }

  Future<void> setLanguage(ZoeLanguage lang) async {
    if (lang == language) return;
    language = lang;
    entries.add(InfoEntry('Language: ${lang.label}'));
    entries.add(TextEntry(
      fromZoe: true,
      text: switch (lang) {
        ZoeLanguage.english => "Okay! I'll reply in English from now on.",
        ZoeLanguage.tagalog => 'Sige! Sasagot na ako sa Tagalog.',
        ZoeLanguage.both => 'Game! Taglish tayo — halo English at Tagalog.',
      },
    ));
    _notify();
    try {
      await _settings.setLanguage(lang);
    } catch (e) {
      debugPrint('Saving language failed: $e');
    }
  }

  // ───────────────────────── History (ai_messages) ─────────────────────────

  /// Isa-isa ang pag-save para hindi dumoble ang conversation.
  Future<void> _saveQueue = Future.value();

  Future<void> _save(String role, String content) {
    _saveQueue = _saveQueue.then((_) => _saveNow(role, content));
    return _saveQueue;
  }

  Future<void> _saveNow(String role, String content) async {
    _writingHistory = true;
    try {
      _conversationId ??= await _history.startConversation();
      await _history.addMessage(_conversationId!, role, content);
    } catch (e) {
      debugPrint('Saving chat message failed: $e');
    } finally {
      _writingHistory = false;
    }
  }

  String _cardSummary(ConfirmEntry e) => switch (e.kind) {
        DraftKind.reminder => 'Create this reminder? ${e.reminder!.title}',
        DraftKind.task => 'Add this task? ${e.task!.title}',
        DraftKind.note => 'Save this note? ${Note.titleFrom(e.note!.title, e.note!.content)}',
        DraftKind.memory => 'Remember this? ${e.memory!.content}',
      };

  String _savedLine(ConfirmEntry e) => switch (e.kind) {
        DraftKind.reminder => '✓ Reminder saved: ${e.reminder!.title}',
        DraftKind.task => '✓ Task saved: ${e.task!.title}',
        DraftKind.note => '✓ Note saved: ${Note.titleFrom(e.note!.title, e.note!.content)}',
        DraftKind.memory => '✓ Zoe will remember: ${e.memory!.content}',
      };
}

/// Resulta ng maikling sagot sa card ("oo" / "wag na" / "8pm pala").
class _CardReply {
  const _CardReply([this.accepted]);

  /// Ang card na na-accept ("oo", "sige"); null = na-cancel o naitama.
  final ConfirmEntry? accepted;
}