import 'package:sqflite/sqflite.dart';
import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/models/reminder.dart';
import 'package:zoe_remind/database/models/reminder_occurrence.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';

/// The only place that reads/writes the reminders table
/// (and the reminder rows of completion_history + reminder_occurrences).
class ReminderRepository {
  static const _table = StorageConstants.remindersTable;
  static const _history = StorageConstants.completionHistoryTable;
  static const _occurrences = StorageConstants.reminderOccurrencesTable;
  static const _itemType = 'reminder';

  /// Settings key: unang araw na HINDI pa na-check para sa Missed.
  static const _scanKey = 'occurrences_scanned_until';

  /// Kapag matagal hindi nabuksan ang app, hanggang ilang araw pabalik lang.
  static const _maxScanDays = 62;

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
  /// Done -> also logged to completion_history + reminder_occurrences.
  /// Undo removes those rows, so a mis-tap doesn't count.
  Future<void> setDoneOn(int id, DateTime day, bool done) async {
    final db = await ZoeDatabase.instance.database;
    await db.transaction((txn) async {
      final rows = await txn.query(_table,
          columns: ['title', 'time'], where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return;
      final now = DateTime.now().toIso8601String();
      final dayKey = ZoeDate.key(day);

      await txn.update(
        _table,
        {
          'last_done_date': done ? dayKey : null,
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
        // Done ang mananaig kahit Missed / Dismissed ang naka-record dati.
        await txn.insert(
          _occurrences,
          _occurrenceRow(id, rows.first, dayKey, OccurrenceStatus.done, now),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await txn.rawDelete(
          'DELETE FROM $_history WHERE id = ('
          'SELECT id FROM $_history WHERE item_type = ? AND item_id = ? '
          'ORDER BY completed_at DESC LIMIT 1)',
          [_itemType, id],
        );
        await txn.delete(
          _occurrences,
          where: 'reminder_id = ? AND day = ? AND status = ?',
          whereArgs: [id, dayKey, OccurrenceStatus.done.name],
        );
      }
    });
  }

  /// Dismiss sa ringing screen: hindi done (walang history log),
  /// pero tanda na sinadya itong laktawan sa [day].
  Future<void> setDismissedOn(int id, DateTime day) async {
    final db = await ZoeDatabase.instance.database;
    await db.transaction((txn) async {
      final rows = await txn.query(_table,
          columns: ['title', 'time'], where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return;
      final now = DateTime.now().toIso8601String();
      final dayKey = ZoeDate.key(day);

      await txn.update(
        _table,
        {
          'last_done_date': dayKey,
          'status': 'dismissed',
          'completed_at': null,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      await txn.insert(
        _occurrences,
        _occurrenceRow(id, rows.first, dayKey, OccurrenceStatus.dismissed, now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  // ───────────────────── reminder_occurrences ─────────────────────

  Map<String, Object?> _occurrenceRow(int id, Map<String, Object?> reminder,
          String dayKey, OccurrenceStatus status, String now) =>
      {
        'reminder_id': id,
        'title': reminder['title'],
        'day': dayKey,
        'time': reminder['time'],
        'status': status.name,
        'recorded_at': now,
      };

  /// I-record bilang MISSED ang mga lumipas na araw na walang Done / Dismiss.
  /// Tinitingnan lang ang mga araw BAGO ngayon (tapos na sila); ang ngayong
  /// araw ay kinukuwenta pa rin sa Home.
  ///
  /// [pending] = ReminderAlarmService.activeAlarmOccurrences() — kung
  /// naka-snooze / nagri-ring pa ang occurrence, hindi muna Missed.
  ///
  /// Ligtas tawagin nang paulit-ulit: INSERT OR IGNORE, kaya hindi
  /// napapalitan ang Done / Dismissed na naka-record na.
  Future<void> recordMissed({
    Map<int, DateTime> pending = const {},
    DateTime? now,
  }) async {
    final settings = SettingsRepository();
    final today = ZoeDate.dayOnly(now ?? DateTime.now());

    final saved = await settings.getValue(_scanKey);
    if (saved == null) {
      // Unang takbo pagkatapos ng update: dito magsisimula.
      // Hindi binabalikan ang lumang araw (hindi natin alam ang totoong nangyari).
      await settings.setValue(_scanKey, ZoeDate.key(today));
      return;
    }

    var day = ZoeDate.parseKey(saved);
    final oldest = today.subtract(const Duration(days: _maxScanDays));
    if (day.isBefore(oldest)) day = oldest;
    if (!day.isBefore(today)) return; // wala pang bagong tapos na araw

    final db = await ZoeDatabase.instance.database;
    final recordedAt = DateTime.now().toIso8601String();
    DateTime? stopAt; // unang araw na may naka-snooze pa → babalikan ulit

    while (day.isBefore(today)) {
      final dayKey = ZoeDate.key(day);
      for (final r in await getForDay(day)) {
        final id = r.id;
        if (id == null) continue;

        final pendingAt = pending[id];
        if (pendingAt != null && ZoeDate.sameDay(pendingAt, day)) {
          stopAt ??= day;
          continue;
        }
        if (r.isDoneOn(day) || r.isDismissedOn(day)) continue;

        await db.insert(
          _occurrences,
          {
            'reminder_id': id,
            'title': r.title,
            'day': dayKey,
            'time': r.time,
            'status': OccurrenceStatus.missed.name,
            'recorded_at': recordedAt,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }

    await settings.setValue(_scanKey, ZoeDate.key(stopAt ?? today));
  }

  /// History mula [from] hanggang [to] (kasama pareho), luma → bago.
  /// [status] = isa lang (hal. missed) o lahat kung null.
  /// Para sa "See all" at Memory Engine later.
  Future<List<ReminderOccurrence>> getOccurrences({
    required DateTime from,
    required DateTime to,
    OccurrenceStatus? status,
  }) async {
    final db = await ZoeDatabase.instance.database;
    final where = StringBuffer('day >= ? AND day <= ?');
    final args = <Object?>[ZoeDate.key(from), ZoeDate.key(to)];
    if (status != null) {
      where.write(' AND status = ?');
      args.add(status.name);
    }
    final rows = await db.query(
      _occurrences,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'day ASC, time ASC',
    );
    return rows.map(ReminderOccurrence.fromMap).toList();
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

  /// Binubura ang reminder. Naiiwan ang reminder_occurrences at
  /// completion_history niya — history na iyon.
  Future<void> delete(int id) async {
    final db = await ZoeDatabase.instance.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}