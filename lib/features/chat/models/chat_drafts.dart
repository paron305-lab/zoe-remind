import 'package:flutter/material.dart' show TimeOfDay;
import 'package:zoe_remind/database/models/reminder.dart';
import 'package:zoe_remind/database/models/task.dart';

/// Mga "draft" galing sa Zoe chat — HINDI pa naka-save.
/// Ang user ang magde-decide (Accept / Edit / Cancel),
/// at ang app code (hindi si Qwen) ang nagse-save sa database.

class ReminderDraft {
  const ReminderDraft({
    required this.title,
    this.date,
    this.time,
    this.repeat = ReminderRepeat.none,
  });

  final String title;

  /// Araw lang (midnight). null = hindi pa sinabi.
  final DateTime? date;

  /// null = hindi pa sinabi → magtatanong si Zoe ng "Anong oras?"
  final TimeOfDay? time;
  final ReminderRepeat repeat;

  bool get hasWhen => date != null && time != null;

  ReminderDraft copyWith({
    String? title,
    DateTime? date,
    TimeOfDay? time,
    ReminderRepeat? repeat,
  }) =>
      ReminderDraft(
        title: title ?? this.title,
        date: date ?? this.date,
        time: time ?? this.time,
        repeat: repeat ?? this.repeat,
      );
}

class TaskDraft {
  const TaskDraft({
    required this.title,
    this.notes,
    this.date,
    this.time,
    this.priority = TaskPriority.medium,
    this.category,
  });

  final String title;
  final String? notes;

  /// null = "No date" (Someday)
  final DateTime? date;

  /// null = "Any time"
  final TimeOfDay? time;
  final TaskPriority priority;

  /// Key ng category. null = default category.
  final String? category;

  TaskDraft copyWith({String? title, DateTime? date, TimeOfDay? time}) => TaskDraft(
        title: title ?? this.title,
        notes: notes,
        date: date ?? this.date,
        time: time ?? this.time,
        priority: priority,
        category: category,
      );
}

class NoteDraft {
  const NoteDraft({this.title = '', required this.content});

  final String title;
  final String content;

  NoteDraft copyWith({String? title, String? content}) =>
      NoteDraft(title: title ?? this.title, content: content ?? this.content);
}