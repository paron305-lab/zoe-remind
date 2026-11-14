import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/models/reminder.dart';

/// Estado ng isang reminder sa isang araw.
/// Deterministic code ang nagdedesisyon — hindi si Qwen.
enum ReminderStatus {
  /// Hindi pa oras, hindi pa done → checkbox.
  upcoming,

  /// Na-check nang maaga, hindi pa oras → checkbox (pwede pang i-uncheck).
  doneEarly,

  /// Done at lumipas na ang oras → HISTORY 🔒 (bawal uncheck / edit / delete).
  history,

  /// Pinindot ang Dismiss sa ringing screen.
  dismissed,

  /// Lumipas na ang oras, walang ginawa (walang Done / Snooze / Dismiss).
  missed,
}

extension ReminderStatusX on ReminderStatus {
  /// History na → naka-lock.
  bool get isLocked => this == ReminderStatus.history;

  /// Checkbox ang nasa right side (hindi pa oras).
  bool get showsCheckbox =>
      this == ReminderStatus.upcoming || this == ReminderStatus.doneEarly;

  /// Naka-check / naka-strikethrough.
  bool get isDone =>
      this == ReminderStatus.doneEarly || this == ReminderStatus.history;

  /// Pwedeng pindutin para i-mark as done nang late.
  bool get canMarkLate =>
      this == ReminderStatus.dismissed || this == ReminderStatus.missed;

  /// Text sa right side ng card (sumusunod sa language setting).
  String label(ZoeLanguage lang) => switch (this) {
        ReminderStatus.history => lang == ZoeLanguage.tagalog ? 'Tapos na ✓' : 'Done ✓',
        ReminderStatus.dismissed =>
          lang == ZoeLanguage.tagalog ? 'Nilaktawan' : 'Dismissed',
        ReminderStatus.missed => lang == ZoeLanguage.english ? 'Missed' : 'Na-miss',
        _ => '',
      };

  Color get color => switch (this) {
        ReminderStatus.history => const Color(0xFF3FBE93), // mint
        ReminderStatus.dismissed => const Color(0xFFF0AA45), // amber
        ReminderStatus.missed => const Color(0xFFF0768E), // coral
        _ => const Color(0xFF8B7FE0),
      };

  Color get background => switch (this) {
        ReminderStatus.history => HomeColors.mintLight,
        ReminderStatus.dismissed => HomeColors.amberLight,
        ReminderStatus.missed => HomeColors.coralLight,
        _ => HomeColors.lavenderLight,
      };
}

class ReminderStatusRules {
  ReminderStatusRules._();

  /// Oras ng reminder sa [day].
  static DateTime occurrenceTime(Reminder r, DateTime day) =>
      ZoeDate.combine(day, ZoeDate.parseTime(r.time));

  /// Estado ng [r] sa [day].
  /// [alarmPending] = may naka-schedule pang alarm (hal. naka-snooze o
  /// kasalukuyang nagri-ring) → hindi pa "Missed".
  static ReminderStatus statusOn(
    Reminder r,
    DateTime day, {
    DateTime? now,
    bool alarmPending = false,
  }) {
    final passed = !occurrenceTime(r, day).isAfter(now ?? DateTime.now());

    if (r.isDoneOn(day)) {
      return passed ? ReminderStatus.history : ReminderStatus.doneEarly;
    }
    if (r.isDismissedOn(day)) return ReminderStatus.dismissed;
    if (passed && !alarmPending) return ReminderStatus.missed;
    return ReminderStatus.upcoming;
  }

  /// Naka-lock ba ang BUONG reminder (para sa Edit / Delete)?
  /// - One-time: oo, kung history na.
  /// - Repeating: hindi — ang ngayong araw lang ang naka-lock; pwede pang
  ///   baguhin ang series (nasa completion_history na ang mga natapos).
  static bool isLockedForEdit(Reminder r, {DateTime? now}) {
    if (r.repeat != ReminderRepeat.none) return false;
    final day = ZoeDate.parseKey(r.date);
    return statusOn(r, day, now: now) == ReminderStatus.history;
  }
}