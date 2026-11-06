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
  static const _version = 5;

  Future<Database>? _opening;

  /// Opens the database once and reuses it.
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _fileName);
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, version) => _createAllTables(db),
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
        completed_at TEXT
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

    await batch.commit(noResult: true);
  }
}