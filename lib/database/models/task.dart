import 'package:flutter/material.dart' show TimeOfDay;
import 'package:zoe_remind/core/utils/zoe_date.dart';

enum TaskPriority { low, medium, high }

/// One row of the `tasks` table.
/// Storage format: date = 'yyyy-MM-dd', time = 'HH:mm' (24h), both optional.
///
/// [category] = key ng isang row sa `task_categories` (hal. 'study', 'c1731...').
/// 'none' = walang category (na-delete ang category o hindi pumili).
class Task {
  static const statusPending = 'pending';
  static const statusDone = 'done';

  static const noCategory = 'none';
  static const defaultCategory = 'other';

  final int? id;
  final String title;
  final String? description;
  final String? date;
  final String? time;
  final TaskPriority priority;
  final String category;

  /// 'pending' or 'done'
  final String status;
  final String createdAt;
  final String? updatedAt;
  final String? completedAt;

  /// Kailan ito na-miss (= oras na dapat tapos na). Sine-set ng
  /// TaskRepository.recordMissed(). Hindi binubura kahit i-done nang late.
  final String? missedAt;

  const Task({
    this.id,
    required this.title,
    this.description,
    this.date,
    this.time,
    this.priority = TaskPriority.medium,
    this.category = defaultCategory,
    this.status = statusPending,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.missedAt,
  });

  bool get isDone => status == statusDone;

  /// The task's day at midnight, or null if it has no date ("Someday").
  DateTime? get day => date == null ? null : ZoeDate.parseKey(date!);

  TimeOfDay? get timeOfDay => time == null ? null : ZoeDate.parseTime(time!);

  DateTime? get completedAtTime =>
      completedAt == null ? null : DateTime.tryParse(completedAt!);

  /// Kailan ito magiging "Missed" kung hindi pa tapos.
  /// - may oras  → petsa + oras
  /// - "Any time" → pagkatapos ng araw (12:00 AM kinabukasan)
  /// - "No date" → null (hindi kailanman magiging missed)
  DateTime? get dueAt {
    final d = day;
    if (d == null) return null;
    final t = timeOfDay;
    return t == null ? d.add(const Duration(days: 1)) : ZoeDate.combine(d, t);
  }

  /// Lumampas na ang oras at hindi pa tapos.
  bool isMissedAt(DateTime now) {
    final due = dueAt;
    return !isDone && due != null && !now.isBefore(due);
  }

  /// HISTORY 🔒: done, at lumipas na ang araw na na-done ito.
  /// Bawal na i-uncheck, i-edit, o i-delete.
  /// (Done ngayong araw → pwede pa hanggang 11:59 PM.)
  bool isLockedAt(DateTime now) {
    if (!isDone) return false;
    final at = completedAtTime;
    if (at == null) return false;
    return ZoeDate.dayOnly(at).isBefore(ZoeDate.dayOnly(now));
  }

  /// Use [clearDate] / [clearTime] / [clearDescription] to set those back to null.
  Task copyWith({
    int? id,
    String? title,
    String? description,
    bool clearDescription = false,
    String? date,
    bool clearDate = false,
    String? time,
    bool clearTime = false,
    TaskPriority? priority,
    String? category,
    String? status,
    String? updatedAt,
    String? completedAt,
    bool clearCompletedAt = false,
    String? missedAt,
  }) =>
      Task(
        id: id ?? this.id,
        title: title ?? this.title,
        description: clearDescription ? null : (description ?? this.description),
        date: clearDate ? null : (date ?? this.date),
        time: clearTime ? null : (time ?? this.time),
        priority: priority ?? this.priority,
        category: category ?? this.category,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
        missedAt: missedAt ?? this.missedAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date,
        'time': time,
        'priority': priority.name,
        'category': category,
        'status': status,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'completed_at': completedAt,
        'missed_at': missedAt,
      };

  factory Task.fromMap(Map<String, Object?> m) => Task(
        id: m['id'] as int?,
        title: m['title'] as String,
        description: m['description'] as String?,
        date: m['date'] as String?,
        time: m['time'] as String?,
        priority: _parsePriority(m['priority']),
        category: (m['category'] as String?) ?? defaultCategory,
        status: (m['status'] as String?) ?? statusPending,
        createdAt: (m['created_at'] as String?) ?? DateTime.now().toIso8601String(),
        updatedAt: m['updated_at'] as String?,
        completedAt: m['completed_at'] as String?,
        missedAt: m['missed_at'] as String?,
      );

  /// Old test rows stored priority as 0/1/2 — read those too.
  static TaskPriority _parsePriority(Object? raw) {
    final s = raw?.toString();
    return switch (s) {
      '0' => TaskPriority.low,
      '1' => TaskPriority.medium,
      '2' => TaskPriority.high,
      _ => TaskPriority.values.firstWhere(
          (p) => p.name == s,
          orElse: () => TaskPriority.medium,
        ),
    };
  }
}