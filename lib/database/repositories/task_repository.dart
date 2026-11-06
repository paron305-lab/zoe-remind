import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/models/task.dart';

/// The only place that reads/writes the tasks table
/// (and the task rows of completion_history).
class TaskRepository {
  static const _table = StorageConstants.tasksTable;
  static const _history = StorageConstants.completionHistoryTable;
  static const _itemType = 'task';

  /// Dated tasks first (by date, then time), "Someday" tasks last.
  static const _order =
      'date IS NULL, date ASC, time IS NULL, time ASC, created_at ASC';

  String _now() => DateTime.now().toIso8601String();

  Future<int> add(Task task) async {
    final db = await ZoeDatabase.instance.database;
    final now = _now();
    final row = task.toMap()
      ..remove('id')
      ..['updated_at'] = now;
    return db.insert(_table, row);
  }

  /// Saves every editable field of [task]. Status / completion are
  /// changed only through [setDone], so an edit can't fake a completion.
  Future<void> update(Task task) async {
    if (task.id == null) throw ArgumentError('Task has no id');
    final db = await ZoeDatabase.instance.database;
    await db.update(
      _table,
      {
        'title': task.title,
        'description': task.description,
        'date': task.date,
        'time': task.time,
        'priority': task.priority.name,
        'category': task.category.name,
        'updated_at': _now(),
      },
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<Task?> getById(int id) async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Task.fromMap(rows.first);
  }

  Future<List<Task>> getAll() async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.query(_table, orderBy: _order);
    return rows.map(Task.fromMap).toList();
  }

  /// Tick / untick. Done → also logged to completion_history.
  /// Undo removes that latest log row, so a mis-tap doesn't count
  /// as "finished" in memory search.
  Future<void> setDone(int id, bool done) async {
    final db = await ZoeDatabase.instance.database;
    await db.transaction((txn) async {
      final rows = await txn.query(_table,
          columns: ['title'], where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return;
      final now = _now();

      await txn.update(
        _table,
        {
          'status': done ? Task.statusDone : Task.statusPending,
          'completed_at': done ? now : null,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      if (done) {
        await txn.insert(_history, {
          'item_type': _itemType,
          'item_id': id,
          'title': rows.first['title'],
          'completed_at': now,
        });
      } else {
        await txn.rawDelete(
          'DELETE FROM $_history WHERE id = ('
          'SELECT id FROM $_history WHERE item_type = ? AND item_id = ? '
          'ORDER BY id DESC LIMIT 1)',
          [_itemType, id],
        );
      }
    });
  }

  /// Deletes the task. Its completion_history rows are kept on purpose:
  /// the history is a record of what was finished.
  Future<void> delete(int id) async {
    final db = await ZoeDatabase.instance.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// How many times this task was completed (used by tests / stats later).
  Future<int> historyCount(int id) async {
    final db = await ZoeDatabase.instance.database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_history WHERE item_type = ? AND item_id = ?',
      [_itemType, id],
    );
    return (r.first['c'] as int?) ?? 0;
  }
}