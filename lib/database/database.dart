import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:zoe_remind/core/constants/storage_constants.dart';

/// Zoe's on-device database (zoe.db), stored in app-private storage.
///
/// To add a table later: add a CREATE TABLE IF NOT EXISTS to
/// _createAllTables and bump _version. Both new installs and phones
/// that already have the app will get it.
class ZoeDatabase {
  ZoeDatabase._();
  static final ZoeDatabase instance = ZoeDatabase._();

  static const _fileName = 'zoe.db';

  /// v1: settings, model_state
  /// v2: user_profile
  /// v3: tasks
  /// v4: reminders
  /// v5: tasks.category + tasks.updated_at, completion_history
  /// v6: reminder_occurrences (done / dismissed / missed bawat araw)
  /// v7: task_categories (sariling categories), tasks.missed_at, task_history
  /// v8: notes (Notes tab — typed + galing kay Zoe, pinned)
  static const _version = 8;

  Future<Database>? _opening;

  /// Opens the database once and reuses it.
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _fileName);
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await _createAllTables(db);
        await _seedTaskCategories(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createAllTables(db);
        await _migrate(db, oldVersion);
      },
    );
  }

  /// Column changes for phones that already have an older zoe.db.
  /// (CREATE TABLE IF NOT EXISTS can't add columns to an existing table.)
  static Future<void> _migrate(Database db, int oldVersion) async {
    if (oldVersion < 5) {
      await _addColumnIfMissing(
          db, StorageConstants.tasksTable, 'category', "TEXT NOT NULL DEFAULT 'other'");
      await _addColumnIfMissing(db, StorageConstants.tasksTable, 'updated_at', 'TEXT');
    }
    if (oldVersion < 6) {
      await _backfillOccurrences(db);
    }
    if (oldVersion < 7) {
      await _addColumnIfMissing(db, StorageConstants.tasksTable, 'missed_at', 'TEXT');
      await _seedTaskCategories(db);
      // Ang mga lumang na-miss na task ay mare-record ng
      // TaskRepository.recordMissed() pagbukas ng Tasks screen.
    }
  }

  /// Ang 7 dating categories. Isang beses lang ito tinatawag
  /// (bagong install o pag-upgrade sa v7), kaya kapag dinelete ng user
  /// ang isa, hindi na ito babalik.
  /// Pareho ang key sa dati, kaya walang task na kailangang baguhin.
  static Future<void> _seedTaskCategories(Database db) async {
    const seed = [
      ('study', 'Study', 0xFF3FBE93),
      ('thesis', 'Thesis', 0xFFF0768E),
      ('work', 'Work', 0xFF4FADE0),
      ('errand', 'Errand', 0xFF6E5BD6),
      ('habit', 'Habit', 0xFFF0AA45),
      ('personal', 'Personal', 0xFFC98BDB),
      ('other', 'Other', 0xFF8A8999),
    ];
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (var i = 0; i < seed.length; i++) {
      final (key, label, color) = seed[i];
      batch.rawInsert(
        'INSERT OR IGNORE INTO ${StorageConstants.taskCategoriesTable} '
        '(key, label, color, sort_order, created_at) VALUES (?, ?, ?, ?, ?)',
        [key, label, color, i, now],
      );
    }
    await batch.commit(noResult: true);
  }

  /// v6: ilipat sa reminder_occurrences ang mga dating record.
  /// - Done: galing sa completion_history (araw = petsa ng completed_at).
  /// - Dismissed: galing sa reminders.last_done_date (huling dismiss lang ang alam).
  /// Hindi na mababawi ang lumang Missed — walang na-save noon.
  static Future<void> _backfillOccurrences(Database db) async {
    const occ = StorageConstants.reminderOccurrencesTable;
    const history = StorageConstants.completionHistoryTable;
    const reminders = StorageConstants.remindersTable;

    await db.execute('''
      INSERT OR IGNORE INTO $occ (reminder_id, title, day, time, status, recorded_at)
      SELECT h.item_id, h.title, substr(h.completed_at, 1, 10),
             COALESCE(r.time, '00:00'), 'done', h.completed_at
      FROM $history h
      LEFT JOIN $reminders r ON r.id = h.item_id
      WHERE h.item_type = 'reminder'
    ''');

    await db.execute('''
      INSERT OR IGNORE INTO $occ (reminder_id, title, day, time, status, recorded_at)
      SELECT id, title, last_done_date, time, 'dismissed', updated_at
      FROM $reminders
      WHERE status = 'dismissed' AND last_done_date IS NOT NULL
    ''');
  }

  static Future<void> _addColumnIfMissing(
      Database db, String table, String column, String definition) async {
    final cols = await db.rawQuery('PRAGMA table_info($table)');
    final exists = cols.any((c) => c['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  /// Every table uses IF NOT EXISTS, so this is safe to run on
  /// a fresh install and on any older database.
  static Future<void> _createAllTables(Database db) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS model_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        status TEXT NOT NULL,
        model_version TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        policy_version TEXT NOT NULL,
        policy_accepted_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Columns follow the architecture doc's tasks table.
    // date 'yyyy-MM-dd' and time 'HH:mm' are optional (no date = "Someday").
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${StorageConstants.tasksTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        date TEXT,
        time TEXT,
        priority TEXT,
        category TEXT NOT NULL DEFAULT 'other',
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT,
        updated_at TEXT,
        completed_at TEXT,
        missed_at TEXT
      )
    ''');

    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_date '
      'ON ${StorageConstants.tasksTable} (date)',
    );

    // Append-only log of finished items, for "Ano natapos ko last week?".
    // item_type is 'task' for now; reminders can log here later.
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${StorageConstants.completionHistoryTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_type TEXT NOT NULL,
        item_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        completed_at TEXT NOT NULL
      )
    ''');

    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_history_completed_at '
      'ON ${StorageConstants.completionHistoryTable} (completed_at)',
    );

    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${StorageConstants.remindersTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        repeat TEXT NOT NULL DEFAULT 'none',
        status TEXT NOT NULL DEFAULT 'pending',
        last_done_date TEXT,
        notification_state TEXT NOT NULL DEFAULT 'not_scheduled',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        completed_at TEXT
      )
    ''');

    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminders_date '
      'ON ${StorageConstants.remindersTable} (date)',
    );

    // Isang row bawat araw ng bawat reminder: done / dismissed / missed.
    // Hindi nabubura kapag na-delete ang reminder — history ito.
    // title at time = snapshot noong araw na iyon (kahit ma-edit pa later).
    // Para sa Memory Engine: "Ano mga na-miss ko last week?"
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${StorageConstants.reminderOccurrencesTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reminder_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        day TEXT NOT NULL,
        time TEXT NOT NULL,
        status TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        UNIQUE (reminder_id, day)
      )
    ''');

    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_occurrences_day '
      'ON ${StorageConstants.reminderOccurrencesTable} (day)',
    );

    // Sariling categories ng user. key = naka-save sa tasks.category.
    // color = ARGB int (hal. 0xFF3FBE93).
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${StorageConstants.taskCategoriesTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        label TEXT NOT NULL,
        color INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // History ng tasks na hindi nabubura kahit ma-delete ang task.
    // Sa ngayon: 'missed' rows. (Done = nasa completion_history.)
    // title/day/time = snapshot noong na-miss.
    // Para sa Memory Engine: "Ano mga na-miss ko last week?"
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${StorageConstants.taskHistoryTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        day TEXT NOT NULL,
        time TEXT,
        status TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        UNIQUE (task_id, day, status)
      )
    ''');

    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_task_history_day '
      'ON ${StorageConstants.taskHistoryTable} (day)',
    );

    // Notes tab. source = 'typed' (Notes UI) o 'zoe' (sine-save ni Zoe sa chat).
    // pinned = 0/1. Walang FK sa iba — free text, searchable ng Memory Engine.
    // Bagong table lang (walang column change), kaya sapat na ang
    // IF NOT EXISTS para sa v7 → v8.
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${StorageConstants.notesTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        source TEXT NOT NULL DEFAULT 'typed',
        pinned INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_notes_updated_at '
      'ON ${StorageConstants.notesTable} (updated_at)',
    );

    await batch.commit(noResult: true);
  }
}