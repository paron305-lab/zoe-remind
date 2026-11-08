import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/models/task.dart';

/// Thrown when someone tries to change a task that is already history 🔒.
class TaskLockedException implements Exception {
  const TaskLockedException();
  @override
  String toString() => 'Tapos na ito, kasama na sa history mo.';
}

/// The only place that reads/writes the tasks table
/// (and the task rows of completion_history / task_history).
class TaskRepository {
  static const _table = StorageConstants.tasksTable;
  static const _history = StorageConstants.completionHistoryTable;
  static const _taskHistory = StorageConstants.taskHistoryTable;
  static const _itemType = 'task';
  static const _missed = 'missed';

  /// Dated tasks first (by date, then time), "Someday" tasks last.
  static const _order =
      'date IS NULL, date ASC, time IS NULL, time ASC, created_at ASC';

  String _now() => DateTime.now().toIso8601String();

  Future<int> add(Task task) async {
    final db = await ZoeDatabase.instance.database;
    final now = _now();
    final row = task.toMap()
      ..remove('id')
      ..remove('missed_at')
      ..['updated_at'] = now;
    return db.insert(_table, row);
  }

  /// Saves every editable field of [task]. Status / completion are
  /// changed only through [setDone], so an edit can't fake a completion.
  /// History 🔒 tasks can't be edited.
  ///
  /// Kapag inilipat ang petsa/oras ng na-miss na task, nire-reset ang
  /// missed_at para ma-record ulit kung ma-miss ulit. Ang lumang
  /// "missed" record ay nananatili sa task_history.
  Future<void> update(Task task) async {
    if (task.id == null) throw ArgumentError('Task has no id');
    final current = await getById(task.id!);
    if (current == null) return;
    if (current.isLockedAt(DateTime.now())) throw const TaskLockedException();

    final rescheduled = current.date != task.date || current.time != task.time;
    final db = await ZoeDatabase.instance.database;
    await db.update(
      _table,
      {
        'title': task.title,
        'description': task.description,
        'date': task.date,
        'time': task.time,
        'priority': task.priority.name,
        'category': task.category,
        'updated_at': _now(),
        if (rescheduled) 'missed_at': null,
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
  /// as "finished" in memory search. History 🔒 tasks can't be unticked.
  Future<void> setDone(int id, bool done) async {
    final db = await ZoeDatabase.instance.database;
    await db.transaction((txn) async {
      final rows = await txn.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return;
      final task = Task.fromMap(rows.first);
      if (task.isLockedAt(DateTime.now())) throw const TaskLockedException();
      if (task.isDone == done) return; // nothing to change
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
          'title': task.title,
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

  /// Deletes the task. History 🔒 tasks can't be deleted.
  /// Its completion_history and task_history rows are kept on purpose:
  /// they are the record of what was finished / missed.
  Future<void> delete(int id) async {
    final current = await getById(id);
    if (current == null) return;
    if (current.isLockedAt(DateTime.now())) throw const TaskLockedException();
    final db = await ZoeDatabase.instance.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Hinahanap ang mga task na lumampas na sa oras at hindi pa tapos,
  /// tapos sine-save: tasks.missed_at + isang 'missed' row sa task_history.
  /// Isang beses lang bawat task (hangga't hindi inililipat ang petsa).
  /// Tinatawag pagbukas ng Tasks screen at kada minuto habang bukas ito.
  /// Returns kung ilan ang bagong na-record.
  Future<int> recordMissed({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final db = await ZoeDatabase.instance.database;
    final rows = await db.query(
      _table,
      where: 'status = ? AND date IS NOT NULL AND missed_at IS NULL',
      whereArgs: [Task.statusPending],
    );

    final missed = rows.map(Task.fromMap).where((t) => t.isMissedAt(at)).toList();
    if (missed.isEmpty) return 0;

    final recordedAt = at.toIso8601String();
    await db.transaction((txn) async {
      for (final t in missed) {
        await txn.update(
          _table,
          {'missed_at': t.dueAt!.toIso8601String()},
          where: 'id = ?',
          whereArgs: [t.id],
        );
        await txn.rawInsert(
          'INSERT OR IGNORE INTO $_taskHistory '
          '(task_id, title, day, time, status, recorded_at) VALUES (?, ?, ?, ?, ?, ?)',
          [t.id, t.title, t.date, t.time, _missed, recordedAt],
        );
      }
    });
    return missed.length;
  }

  /// Mga na-miss na task sa pagitan ng dalawang araw ('yyyy-MM-dd'),
  /// kasama ang mga na-delete na. Para sa Memory Engine / History later.
  Future<List<Map<String, Object?>>> getMissed({String? from, String? to}) async {
    final db = await ZoeDatabase.instance.database;
    final where = <String>['status = ?'];
    final args = <Object?>[_missed];
    if (from != null) {
      where.add('day >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('day <= ?');
      args.add(to);
    }
    return db.query(_taskHistory,
        where: where.join(' AND '), whereArgs: args, orderBy: 'day ASC, time ASC');
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