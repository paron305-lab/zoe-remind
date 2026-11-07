import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/models/reminder.dart';

/// The only place that reads/writes the reminders table
/// (and the reminder rows of completion_history).
class ReminderRepository {
  static const _table = StorageConstants.remindersTable;
  static const _history = StorageConstants.completionHistoryTable;
  static const _itemType = 'reminder';

  Future<int> add(Reminder r) async {
    final db = await ZoeDatabase.instance.database;
    return db.insert(_table, r.toMap()..remove('id'));
  }

  Future<Reminder?> getById(int id) async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Reminder.fromMap(rows.first);
  }

  /// Every reminder — used to sync alarms when the app starts.
  Future<List<Reminder>> getAll() async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.query(_table);
    return rows.map(Reminder.fromMap).toList();
  }

  Future<void> update(Reminder r) async {
    final db = await ZoeDatabase.instance.database;
    await db.update(
      _table,
      r.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  /// All reminders that happen on [day] (one-time + repeating), sorted by time.
  Future<List<Reminder>> getForDay(DateTime day) async {
    final db = await ZoeDatabase.instance.database;
    final key = ZoeDate.key(day);
    final rows = await db.query(
      _table,
      // exact day, OR a repeating reminder that started on/before this day
      where: "date = ? OR (repeat != 'none' AND date <= ?)",
      whereArgs: [key, key],
      orderBy: 'time ASC',
    );
    return rows.map(Reminder.fromMap).where((r) => r.occursOn(day)).toList();
  }

  /// Next [days] days after today, as (day, reminder) pairs.
  Future<List<(DateTime, Reminder)>> getUpcoming({int days = 7}) async {
    final today = ZoeDate.dayOnly(DateTime.now());
    final result = <(DateTime, Reminder)>[];
    for (var i = 1; i <= days; i++) {
      final day = today.add(Duration(days: i));
      for (final r in await getForDay(day)) {
        result.add((day, r));
      }
    }
    return result;
  }

  /// Tick / untick a reminder for a specific day.
  /// Done -> also logged to completion_history.
  /// Undo removes that latest log row, so a mis-tap doesn't count.
  Future<void> setDoneOn(int id, DateTime day, bool done) async {
    final db = await ZoeDatabase.instance.database;
    await db.transaction((txn) async {
      final rows = await txn.query(_table,
          columns: ['title'], where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return;
      final now = DateTime.now().toIso8601String();

      await txn.update(
        _table,
        {
          'last_done_date': done ? ZoeDate.key(day) : null,
          'status': done ? 'done' : 'pending',
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
          'ORDER BY completed_at DESC LIMIT 1)',
          [_itemType, id],
        );
      }
    });
  }

  /// 'scheduled' / 'not_scheduled' — updated by ReminderAlarmService.
  Future<void> setNotificationState(int id, String state) async {
    final db = await ZoeDatabase.instance.database;
    await db.update(
      _table,
      {'notification_state': state},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    final db = await ZoeDatabase.instance.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}