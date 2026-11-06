import 'package:flutter/material.dart' show TimeOfDay;
import 'package:zoe_remind/core/utils/zoe_date.dart';

enum TaskPriority { low, medium, high }

/// Fixed list so the AI (later) can only ever pick a known category.
enum TaskCategory {
  study('Study'),
  thesis('Thesis'),
  work('Work'),
  errand('Errand'),
  habit('Habit'),
  personal('Personal'),
  other('Other');

  final String label;
  const TaskCategory(this.label);
}

/// One row of the `tasks` table.
/// Storage format: date = 'yyyy-MM-dd', time = 'HH:mm' (24h), both optional.
class Task {
  static const statusPending = 'pending';
  static const statusDone = 'done';

  final int? id;
  final String title;
  final String? description;
  final String? date;
  final String? time;
  final TaskPriority priority;
  final TaskCategory category;

  /// 'pending' or 'done'
  final String status;
  final String createdAt;
  final String? updatedAt;
  final String? completedAt;

  const Task({
    this.id,
    required this.title,
    this.description,
    this.date,
    this.time,
    this.priority = TaskPriority.medium,
    this.category = TaskCategory.other,
    this.status = statusPending,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  bool get isDone => status == statusDone;

  /// The task's day at midnight, or null if it has no date ("Someday").
  DateTime? get day => date == null ? null : ZoeDate.parseKey(date!);

  TimeOfDay? get timeOfDay => time == null ? null : ZoeDate.parseTime(time!);

  DateTime? get completedAtTime =>
      completedAt == null ? null : DateTime.tryParse(completedAt!);

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
    TaskCategory? category,
    String? status,
    String? updatedAt,
    String? completedAt,
    bool clearCompletedAt = false,
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
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date,
        'time': time,
        'priority': priority.name,
        'category': category.name,
        'status': status,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'completed_at': completedAt,
      };

  factory Task.fromMap(Map<String, Object?> m) => Task(
        id: m['id'] as int?,
        title: m['title'] as String,
        description: m['description'] as String?,
        date: m['date'] as String?,
        time: m['time'] as String?,
        priority: _parsePriority(m['priority']),
        category: TaskCategory.values.firstWhere(
          (c) => c.name == m['category'],
          orElse: () => TaskCategory.other,
        ),
        status: (m['status'] as String?) ?? statusPending,
        createdAt: (m['created_at'] as String?) ?? DateTime.now().toIso8601String(),
        updatedAt: m['updated_at'] as String?,
        completedAt: m['completed_at'] as String?,
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