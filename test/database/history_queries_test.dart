import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/models/reminder_occurrence.dart';
import 'package:zoe_remind/database/repositories/reminder_repository.dart';
import 'package:zoe_remind/database/repositories/task_repository.dart';

/// Takbuhin:  flutter test test/database/history_queries_test.dart
///
/// Totoong SQLite (sqflite_common_ffi sa PC), bagong zoe.db sa .dart_tool —
/// hindi ginagalaw ang database sa phone.
/// Sinisigurado na tama ang mga query na binabasa ng chat (A4) at RAG later.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final path = join(await databaseFactory.getDatabasesPath(), 'zoe.db');
    await databaseFactory.deleteDatabase(path);

    final db = await ZoeDatabase.instance.database;
    const history = StorageConstants.completionHistoryTable;
    await db.insert(history, {
      'item_type': 'task',
      'item_id': 1,
      'title': 'Review thesis',
      'completed_at': '2026-11-17T10:00:00.000',
    });
    await db.insert(history, {
      'item_type': 'task',
      'item_id': 2,
      'title': 'Iba pang task',
      'completed_at': '2026-11-16T23:59:00.000',
    });
    await db.insert(history, {
      'item_type': 'reminder', // hindi task → hindi kasama sa getCompleted
      'item_id': 5,
      'title': 'Inom gamot',
      'completed_at': '2026-11-17T08:05:00.000',
    });

    const occ = StorageConstants.reminderOccurrencesTable;
    for (final row in [
      (5, 'Inom gamot', '2026-11-17', 'done'),
      (5, 'Inom gamot', '2026-11-18', 'done'),
      (7, 'Bayad kuryente', '2026-11-15', 'missed'),
    ]) {
      await db.insert(occ, {
        'reminder_id': row.$1,
        'title': row.$2,
        'day': row.$3,
        'time': '08:00',
        'status': row.$4,
        'recorded_at': '${row.$3}T23:59:00.000',
      });
    }

    const taskHistory = StorageConstants.taskHistoryTable;
    for (final row in [
      (3, 'Labada', '2026-11-16'),
      (4, 'Lumang task', '2026-11-05'),
    ]) {
      await db.insert(taskHistory, {
        'task_id': row.$1,
        'title': row.$2,
        'day': row.$3,
        'time': null,
        'status': 'missed',
        'recorded_at': '${row.$3}T23:59:00.000',
      });
    }
  });

  test('getCompleted — isang araw, tasks lang', () async {
    final done = await TaskRepository()
        .getCompleted(from: DateTime(2026, 11, 17), to: DateTime(2026, 11, 17));
    expect(done.map((c) => c.title), ['Review thesis']);
    expect(done.single.taskId, 1);
  });

  test('getCompleted — saklaw ng ilang araw, luma → bago', () async {
    final done = await TaskRepository()
        .getCompleted(from: DateTime(2026, 11, 16), to: DateTime(2026, 11, 18));
    expect(done.map((c) => c.title), ['Iba pang task', 'Review thesis']);
  });

  test('getOccurrences — done sa isang araw', () async {
    final done = await ReminderRepository().getOccurrences(
      from: DateTime(2026, 11, 17),
      to: DateTime(2026, 11, 17),
      status: OccurrenceStatus.done,
    );
    expect(done.map((o) => o.title), ['Inom gamot']);
  });

  test('getMissed — huling 7 araw lang', () async {
    final missed = await TaskRepository().getMissed(from: '2026-11-12', to: '2026-11-18');
    expect(missed.map((r) => r['title']), ['Labada']);
  });
}