import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/models/task.dart';
import 'package:zoe_remind/database/models/task_category.dart';

/// Thrown when a category name is empty, too long, or already used.
class CategoryNameException implements Exception {
  final String message;
  const CategoryNameException(this.message);
  @override
  String toString() => message;
}

/// The only place that reads/writes the task_categories table.
class TaskCategoryRepository {
  static const _table = StorageConstants.taskCategoriesTable;
  static const _tasks = StorageConstants.tasksTable;

  Future<List<TaskCategory>> getAll() async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.query(_table, orderBy: 'sort_order ASC, id ASC');
    return rows.map(TaskCategory.fromMap).toList();
  }

  Future<TaskCategories> getLookup() async => TaskCategories(await getAll());

  /// Linis na pangalan, o exception kung bawal.
  /// [exceptKey] = sariling key kapag nag-e-edit (pwedeng parehong pangalan).
  Future<String> _validLabel(String raw, {String? exceptKey}) async {
    final label = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (label.isEmpty) throw const CategoryNameException('Lagyan mo ng pangalan.');
    if (label.length > TaskCategory.maxLabel) {
      throw const CategoryNameException('Hanggang ${TaskCategory.maxLabel} letters lang.');
    }
    if (label.toLowerCase() == TaskCategories.noneLabel.toLowerCase()) {
      throw const CategoryNameException('Bawal ang pangalang iyan.');
    }
    final all = await getAll();
    final taken = all.any((c) =>
        c.key != exceptKey && c.label.toLowerCase() == label.toLowerCase());
    if (taken) throw const CategoryNameException('Meron ka nang category na ganyan.');
    return label;
  }

  Future<TaskCategory> add(String rawLabel, int color) async {
    final label = await _validLabel(rawLabel);
    final db = await ZoeDatabase.instance.database;
    final maxRow = await db.rawQuery('SELECT MAX(sort_order) AS m FROM $_table');
    final order = ((maxRow.first['m'] as int?) ?? -1) + 1;
    final key = 'c${DateTime.now().microsecondsSinceEpoch}';
    final id = await db.insert(_table, {
      'key': key,
      'label': label,
      'color': color,
      'sort_order': order,
      'created_at': DateTime.now().toIso8601String(),
    });
    return TaskCategory(id: id, key: key, label: label, color: color, sortOrder: order);
  }

  /// Rename / recolor. Key stays the same, so every task follows automatically.
  Future<TaskCategory> update(TaskCategory category, String rawLabel, int color) async {
    final label = await _validLabel(rawLabel, exceptKey: category.key);
    final db = await ZoeDatabase.instance.database;
    await db.update(
      _table,
      {'label': label, 'color': color},
      where: 'key = ?',
      whereArgs: [category.key],
    );
    return category.copyWith(label: label, color: color);
  }

  /// Ilang task ang gumagamit ng category (para sa delete confirmation).
  Future<int> taskCount(String key) async {
    final db = await ZoeDatabase.instance.database;
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM $_tasks WHERE category = ?', [key]);
    return (r.first['c'] as int?) ?? 0;
  }

  /// Delete the category. Its tasks become "No category" ('none').
  /// Kasama ang history tasks — label lang ang nagbabago, hindi ang record.
  Future<void> delete(String key) async {
    final db = await ZoeDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.update(_tasks, {'category': Task.noCategory},
          where: 'category = ?', whereArgs: [key]);
      await txn.delete(_table, where: 'key = ?', whereArgs: [key]);
    });
  }
}