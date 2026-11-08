import 'package:flutter/material.dart' show Color;
import 'package:zoe_remind/database/models/task.dart';

/// One row of the `task_categories` table.
class TaskCategory {
  static const maxLabel = 20;

  final int? id;

  /// Naka-save sa tasks.category. Hindi nagbabago kahit i-rename.
  final String key;
  final String label;

  /// ARGB int, hal. 0xFF3FBE93
  final int color;
  final int sortOrder;

  const TaskCategory({
    this.id,
    required this.key,
    required this.label,
    required this.color,
    this.sortOrder = 0,
  });

  Color get colorValue => Color(color);

  TaskCategory copyWith({String? label, int? color}) => TaskCategory(
        id: id,
        key: key,
        label: label ?? this.label,
        color: color ?? this.color,
        sortOrder: sortOrder,
      );

  factory TaskCategory.fromMap(Map<String, Object?> m) => TaskCategory(
        id: m['id'] as int?,
        key: m['key'] as String,
        label: m['label'] as String,
        color: m['color'] as int,
        sortOrder: (m['sort_order'] as int?) ?? 0,
      );
}

/// Lookup ng categories by key. Kapag wala ang key (na-delete o 'none'),
/// "No category" na gray ang lalabas.
class TaskCategories {
  static const noneLabel = 'No category';
  static const noneColor = Color(0xFFC9C7D4);

  final List<TaskCategory> list;
  final Map<String, TaskCategory> _byKey;

  TaskCategories(this.list) : _byKey = {for (final c in list) c.key: c};

  static final empty = TaskCategories(const []);

  TaskCategory? byKey(String key) => _byKey[key];

  bool has(String key) => _byKey.containsKey(key);

  String label(String key) => _byKey[key]?.label ?? noneLabel;

  Color color(String key) => _byKey[key]?.colorValue ?? noneColor;

  /// Default ng bagong task: "Other" kung meron pa, kung wala → No category.
  String get defaultKey => has(Task.defaultCategory) ? Task.defaultCategory : Task.noCategory;
}