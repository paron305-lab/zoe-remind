import 'package:flutter/material.dart' show TimeOfDay;
import 'package:zoe_remind/features/chat/models/chat_drafts.dart';

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

enum DraftKind { reminder, task, note }

enum DraftStatus { pending, saving, saved, cancelled }

/// "Create this reminder?" card — [Edit] [Cancel] [Accept].
/// Walang nase-save hangga't hindi pinipindot ng user ang Accept
/// (o Save sa Edit screen).
class ConfirmEntry extends ChatEntry {
  ConfirmEntry.reminder(ReminderDraft this.reminder) : task = null, note = null;
  ConfirmEntry.task(TaskDraft this.task) : reminder = null, note = null;
  ConfirmEntry.note(NoteDraft this.note) : reminder = null, task = null;

  ReminderDraft? reminder;
  TaskDraft? task;
  NoteDraft? note;

  DraftStatus status = DraftStatus.pending;

  /// Database id kapag na-save na (para sa "View" link).
  int? savedId;

  /// true = na-save mula sa Edit screen (may binago ang user).
  bool edited = false;

  DraftKind get kind => reminder != null
      ? DraftKind.reminder
      : task != null
          ? DraftKind.task
          : DraftKind.note;

  bool get isPending => status == DraftStatus.pending;
}

/// Isang quick-reply chip. [time] == null → "Iba pa" (bubuksan ang time picker).
class ClarifyChip {
  const ClarifyChip(this.label, this.time);
  final String label;
  final TimeOfDay? time;
}

/// Tanong ni Zoe kapag kulang ang detalye.
/// - May [chips] → "Anong oras?" [8 AM] [12 PM] [Iba pa]
/// - Walang chips → hinihintay ang susunod na type ng user (hal. title).
class ClarifyEntry extends ChatEntry {
  ClarifyEntry({
    required this.question,
    this.chips = const [],
    this.reminder,
    this.task,
    this.note,
  });

  final String question;
  final List<ClarifyChip> chips;

  /// Ang draft na kinukumpleto.
  final ReminderDraft? reminder;
  final TaskDraft? task;
  final NoteDraft? note;

  /// Nasagot na → wala nang chips.
  bool answered = false;

  /// Kailangan ng title (type ng user ang sagot).
  bool get wantsText => chips.isEmpty;
}

enum AnswerTone { done, reminder, event, missed }

class AnswerRow {
  const AnswerRow(this.tone, this.label);
  final AnswerTone tone;
  final String label;
}

/// Sagot sa tanong tungkol sa sariling data (Memory Engine later).
/// "📅 Assuming Sept 3, 2026" chip + text + colored summary rows.
class AnswerEntry extends ChatEntry {
  AnswerEntry({required this.assumption, required this.text, this.rows = const []});
  final String assumption;
  final String text;
  final List<AnswerRow> rows;
}

/// "Pasensya, hindi ko naintindihan…" + [Retry].
class ErrorEntry extends ChatEntry {
  ErrorEntry({required this.text, required this.retryText});
  final String text;

  /// Ang mensaheng ipapadala ulit kapag pinindot ang Retry.
  final String retryText;
}