import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/database/models/task.dart';

/// Estado ng isang task ngayon. Deterministic code ang nagdedesisyon — hindi si Qwen.
enum TaskStatus {
  /// Hindi pa tapos, hindi pa lumalampas ang oras → checkbox.
  pending,

  /// Na-done ngayong araw → naka-check, pwede pang i-uncheck / i-edit / i-delete.
  doneToday,

  /// Done at lumipas na ang araw na na-done → HISTORY 🔒.
  history,

  /// Lumampas ang oras, hindi pa tapos → "Missed". Pwede pang i-check nang late.
  missed;

  static TaskStatus of(Task t, DateTime now) {
    if (t.isLockedAt(now)) return TaskStatus.history;
    if (t.isDone) return TaskStatus.doneToday;
    if (t.isMissedAt(now)) return TaskStatus.missed;
    return TaskStatus.pending;
  }
}

extension TaskStatusX on TaskStatus {
  bool get isLocked => this == TaskStatus.history;

  bool get isDone => this == TaskStatus.doneToday || this == TaskStatus.history;

  /// May pill sa right side ng card.
  bool get hasLabel => this == TaskStatus.history || this == TaskStatus.missed;

  /// Text ng pill (sumusunod sa language setting, gaya ng reminders).
  String label(ZoeLanguage lang) => switch (this) {
        TaskStatus.history => lang == ZoeLanguage.tagalog ? 'Tapos na ✓' : 'Done ✓',
        TaskStatus.missed => lang == ZoeLanguage.english ? 'Missed' : 'Na-miss',
        _ => '',
      };

  Color get color => switch (this) {
        TaskStatus.history => const Color(0xFF3FBE93), // mint
        TaskStatus.missed => const Color(0xFFF0768E), // coral
        _ => HomeColors.lavender,
      };

  Color get background => switch (this) {
        TaskStatus.history => HomeColors.mintLight,
        TaskStatus.missed => HomeColors.coralLight,
        _ => HomeColors.lavenderLight,
      };
}