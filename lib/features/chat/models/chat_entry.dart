import 'package:flutter/material.dart' show TimeOfDay;
import 'package:zoe_remind/features/chat/models/chat_drafts.dart';
import 'package:zoe_remind/rag/snippet.dart';

/// Lahat ng puwedeng lumabas sa Zoe chat list.
/// UI lang ito — ang naka-save sa ai_messages ay text bubbles lang.
sealed class ChatEntry {
  ChatEntry() : id = _next++;
  static int _next = 0;

  /// Para sa Flutter keys (hindi database id).
  final int id;
}

/// Ordinaryong bubble. [footnote] = maliit na grey na linya sa ilalim
/// (hal. "Assuming you mean Monday, Sep 22").
class TextEntry extends ChatEntry {
  TextEntry({required this.fromZoe, required this.text, this.footnote});
  final bool fromZoe;
  final String text;
  final String? footnote;
}

/// Maliit na pill sa gitna (hal. "Language: English", "New chat").
class InfoEntry extends ChatEntry {
  InfoEntry(this.text);
  final String text;
}

/// Tatlong tuldok habang "nag-iisip" si Zoe.
class TypingEntry extends ChatEntry {}

enum DraftKind { reminder, task, note, memory }

enum DraftStatus { pending, saving, saved, cancelled }

/// "Create this reminder?" card — [Edit] [Cancel] [Accept].
/// Walang nase-save hangga't hindi pinipindot ng user ang Accept
/// (o Save sa Edit screen).
class ConfirmEntry extends ChatEntry {
  ConfirmEntry.reminder(ReminderDraft this.reminder) : task = null, note = null, memory = null;
  ConfirmEntry.task(TaskDraft this.task) : reminder = null, note = null, memory = null;
  ConfirmEntry.note(NoteDraft this.note) : reminder = null, task = null, memory = null;
  ConfirmEntry.memory(MemoryDraft this.memory) : reminder = null, task = null, note = null;

  ReminderDraft? reminder;
  TaskDraft? task;
  NoteDraft? note;
  MemoryDraft? memory;

  DraftStatus status = DraftStatus.pending;

  /// Database id kapag na-save na (para sa "View" link).
  int? savedId;

  /// true = na-save mula sa Edit screen (may binago ang user).
  bool edited = false;

  DraftKind get kind => reminder != null
      ? DraftKind.reminder
      : task != null
          ? DraftKind.task
          : note != null
              ? DraftKind.note
              : DraftKind.memory;

  bool get isPending => status == DraftStatus.pending;
}

/// Isang quick-reply chip.
///   Oras:  [8 AM] [12 PM] [7 PM] — [time]; "Iba pa" = time null (time picker).
///   Uri:   [⏰ Reminder] [✅ Task] [📝 Note] [💜 Tandaan] — [kind].
///   Tulong (Level 3): [🎧 Makinig] [💡 Payo] [😄 Pampagaan] — [help].
///   Wala:  [✖ Wala] — [skip] = true (walang gagawin).
class ClarifyChip {
  const ClarifyChip(this.label, this.time) : kind = null, skip = false, help = null;
  const ClarifyChip.kind(this.label, DraftKind this.kind) : time = null, skip = false, help = null;
  const ClarifyChip.skip(this.label) : time = null, kind = null, skip = true, help = null;

  /// Level 3: "Kapag stressed ka, ano'ng nakakatulong?" — 'listen' / 'advice' / 'lighten'.
  const ClarifyChip.help(this.label, String this.help) : time = null, kind = null, skip = false;

  final String label;
  final TimeOfDay? time;

  /// Chip na pumipili ng uri (reminder / task / note / memory).
  final DraftKind? kind;

  /// "✖ Wala" — walang gagawin.
  final bool skip;

  /// Chip ng stress help (StressHelp.value).
  final String? help;

  /// Chip ng oras ("8 AM" o "Iba pa").
  bool get isTime => kind == null && !skip && help == null;
}

/// Tanong ni Zoe kapag kulang ang detalye.
/// - May [chips] → "Anong oras?" [8 AM] [12 PM] [Iba pa]
/// - Walang chips → hinihintay ang susunod na type ng user (hal. title).
/// - [source] != null → "Reminder ba 'to, task, o note?" (hindi sigurado si Zoe);
///   ang [source] ay ang orihinal na mensahe na gagawing card kapag pumili.
class ClarifyEntry extends ChatEntry {
  ClarifyEntry({
    required this.question,
    this.chips = const [],
    this.reminder,
    this.task,
    this.note,
    this.source,
    this.asksHelp = false,
  });

  final String question;
  final List<ClarifyChip> chips;

  /// Ang draft na kinukumpleto.
  final ReminderDraft? reminder;
  final TaskDraft? task;
  final NoteDraft? note;

  /// Orihinal na mensahe (para sa "reminder / task / note?" na tanong).
  final String? source;

  /// Level 3: "Kapag stressed ka, ano'ng nakakatulong?" (isang beses lang).
  final bool asksHelp;

  /// Nasagot na → wala nang chips.
  bool answered = false;

  /// "Reminder ba 'to, task, o note?"
  bool get asksKind => source != null;

  /// Kailangan ng title (type ng user ang sagot).
  bool get wantsText => chips.isEmpty;
}

/// note / memory = source row ng RAG ("📝 Wifi · Nov 18").
enum AnswerTone { done, reminder, event, missed, note, memory }

class AnswerRow {
  const AnswerRow(this.tone, this.label, {this.route});
  final AnswerTone tone;
  final String label;

  /// May route → napipindot (hal. '/notes/edit/3' para buksan ang note).
  final String? route;
}

/// R3: "Buong note →" sa ilalim ng snippet (bubuksan ang note).
class AnswerLink {
  const AnswerLink(this.label, this.route);
  final String label;
  final String route;
}

/// Sagot sa tanong tungkol sa sariling data (Memory Engine / RAG).
/// "📅 Assuming Sept 3, 2026" chip + text + colored summary rows.
/// Kapag galing sa notes / memories: ang rows ay ang mga SOURCE.
///
/// R3: [bold] = mga bahagi ng [text] na naka-bold (ang mga salitang tumama
/// sa tanong). [more] = "Buong note →" kapag bahagi lang ng note ang
/// ipinakita.
class AnswerEntry extends ChatEntry {
  AnswerEntry({
    required this.assumption,
    required this.text,
    this.rows = const [],
    this.bold = const [],
    this.more,
  });
  final String assumption;
  final String text;
  final List<AnswerRow> rows;
  final List<SnippetSpan> bold;
  final AnswerLink? more;
}

/// "Pasensya, hindi ko naintindihan…" + [Retry].
class ErrorEntry extends ChatEntry {
  ErrorEntry({required this.text, required this.retryText});
  final String text;

  /// Ang mensaheng ipapadala ulit kapag pinindot ang Retry.
  final String retryText;
}