import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/repositories/wipe_repository.dart';

/// Takbuhin:  flutter test test/database/wipe_repository_test.dart
///
/// Totoong SQLite (sqflite_common_ffi sa PC), bagong zoe.db sa .dart_tool —
/// hindi ginagalaw ang database sa phone.
/// Sinisigurado na "Burahin lahat" = wala nang natirang data ng user,
/// pero nandiyan pa ang pangalan, settings ng app at ang model.
/// R6: kasama ang search_log, learned_terms at search_feedback.
void main() {
  const now = '2026-11-23T10:00:00.000';

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final path = join(await databaseFactory.getDatabasesPath(), 'zoe.db');
    await databaseFactory.deleteDatabase(path);
  });

  Future<void> fillEverything() async {
    final db = await ZoeDatabase.instance.database;

    // Hindi dapat mabura
    await db.insert('user_profile', {
      'id': 1,
      'name': 'AC',
      'age': 25,
      'policy_version': '1',
      'policy_accepted_at': now,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('model_state', {
      'id': 1,
      'tier': 'lite',
      'status': 'ready',
      'file_path': '/data/zoe/model.gguf',
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    for (final kv in {
      'language_mode': 'taglish',
      'dark_mode': 'true',
      'onboarding_done': 'true',
      'alarm_sound': 'chime',
      // Dapat mabura
      'mood_log_noted_on': '2026-11-23',
      'occurrences_scanned_until': '2026-11-23',
      'habit_suggest_study': '2026-11-20',
    }.entries) {
      await db.insert('settings', {'key': kv.key, 'value': kv.value, 'updated_at': now},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Dapat mabura
    await db.insert(StorageConstants.tasksTable, {'title': 'Review thesis', 'created_at': now});
    await db.insert(StorageConstants.completionHistoryTable, {
      'item_type': 'task',
      'item_id': 1,
      'title': 'Review thesis',
      'completed_at': now,
    });
    await db.insert(StorageConstants.taskHistoryTable, {
      'task_id': 1,
      'title': 'Review thesis',
      'day': '2026-11-22',
      'status': 'missed',
      'recorded_at': now,
    });
    await db.insert(StorageConstants.remindersTable, {
      'title': 'Inom gamot',
      'date': '2026-11-23',
      'time': '08:00',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert(StorageConstants.reminderOccurrencesTable, {
      'reminder_id': 1,
      'title': 'Inom gamot',
      'day': '2026-11-22',
      'time': '08:00',
      'status': 'done',
      'recorded_at': now,
    });
    await db.insert(StorageConstants.taskCategoriesTable, {
      'key': 'gym',
      'label': 'Gym',
      'color': 0xFF000000,
      'created_at': now,
    });
    // Binura ng user ang isang default — babalik pagkatapos ng wipe.
    await db.delete(StorageConstants.taskCategoriesTable, where: 'key = ?', whereArgs: ['habit']);
    await db.insert(StorageConstants.notesTable, {
      'title': 'Wifi',
      'content': 'ZoeHome / pass 1234',
      'created_at': now,
      'updated_at': now,
    });
    final conv = await db.insert(StorageConstants.conversationsTable, {
      'created_at': now,
      'updated_at': now,
    });
    await db.insert(StorageConstants.messagesTable, {
      'conversation_id': conv,
      'role': 'user',
      'content': 'pagod na ako',
      'created_at': now,
    });
    await db.insert(StorageConstants.memoriesTable, {
      'content': 'mas gusto ng morning reminders',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert(StorageConstants.moodTable, {
      'id': 1,
      'state': 'happy',
      'since': now,
      'updated_at': now,
    });
    await db.insert(StorageConstants.moodLogTable, {
      'day': '2026-11-23',
      'tone': 'tired',
      'count': 2,
      'updated_at': now,
    });
    // R6: natutunan ni Zoe.
    await db.insert(StorageConstants.searchLogTable, {
      'question': 'ano pw ng net ko?',
      'search_query': 'ano pw ng net ko?',
      'hit_count': 0,
      'outcome': 'none',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert(StorageConstants.learnedTermsTable, {
      'term': 'net',
      'alt': 'wifi',
      'count': 2,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert(StorageConstants.searchFeedbackTable, {
      'doc_key': 'note#1',
      'good': 1,
      'bad': 0,
      'updated_at': now,
    });
  }

  Future<String?> setting(String key) async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  test('may laman bago burahin (para totoo ang test)', () async {
    await fillEverything();
    final counts = await WipeRepository().counts();
    for (final table in WipeRepository.userTables) {
      expect(counts[table], greaterThan(0), reason: '$table dapat may laman');
    }
  });

  test('Burahin lahat → 0 rows sa lahat ng table ng user', () async {
    await WipeRepository().wipeUserData();
    final counts = await WipeRepository().counts();
    for (final entry in counts.entries) {
      if (entry.key == StorageConstants.taskCategoriesTable) continue;
      expect(entry.value, 0, reason: '${entry.key} may natira pa');
    }
  });

  test('task categories → balik sa 7 default, wala na ang sariling gawa', () async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.query(StorageConstants.taskCategoriesTable, orderBy: 'sort_order');
    final keys = rows.map((r) => r['key']).toList();
    expect(keys, ['study', 'thesis', 'work', 'errand', 'habit', 'personal', 'other']);
    expect(keys, isNot(contains('gym')));
  });

  test('nandiyan pa ang pangalan, model at settings ng app', () async {
    final db = await ZoeDatabase.instance.database;
    final profile = await db.query('user_profile');
    expect(profile.single['name'], 'AC');
    final model = await db.query('model_state', where: 'id = 1');
    expect(model.single['status'], 'ready');
    expect(model.single['file_path'], '/data/zoe/model.gguf');
    expect(await setting('language_mode'), 'taglish');
    expect(await setting('dark_mode'), 'true');
    expect(await setting('onboarding_done'), 'true');
    expect(await setting('alarm_sound'), 'chime');
  });

  test('nabura ang settings na galing sa gamit ng user', () async {
    expect(await setting('mood_log_noted_on'), isNull);
    expect(await setting('occurrences_scanned_until'), isNull);
    expect(await setting('habit_suggest_study'), isNull);
  });

  test('gumagana pa ang app pagkatapos: pwede ulit mag-add, at nasa search pa', () async {
    final db = await ZoeDatabase.instance.database;
    await db.insert(StorageConstants.notesTable, {
      'title': 'Bago',
      'content': 'bagong note pagkatapos burahin',
      'created_at': now,
      'updated_at': now,
    });
    final counts = await WipeRepository().counts();
    expect(counts[StorageConstants.notesTable], 1);
    // Sa PC na walang FTS4, walang notes_fts — skip ang check.
    if (counts.containsKey(StorageConstants.notesFtsTable)) {
      expect(counts[StorageConstants.notesFtsTable], 1);
    }
  });

  test('secure_delete naka-ON', () async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.rawQuery('PRAGMA secure_delete');
    expect(rows.first.values.first, 1);
  });
}