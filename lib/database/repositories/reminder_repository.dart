import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/models/reminder.dart';

/// The only place that reads/writes the reminders table.
class ReminderRepository {
  static const _table = StorageConstants.remindersTable;

  Future<int> add(Reminder r) async {
    final db = await ZoeDatabase.instance.database;
    return db.insert(_table, r.toMap()..remove('id'));
  }

  /// All reminders that happen on [day] (one-time + repeating), sorted by time.
    Future<Reminder?> getById(int id) async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Reminder.fromMap(rows.first);
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
  Future<void> setDoneOn(int id, DateTime day, bool done) async {
    final db = await ZoeDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
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
  }

  Future<void> delete(int id) async {
    final db = await ZoeDatabase.instance.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}