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
  static const _version = 3;

  Future<Database>? _opening;

  /// Opens the database once and reuses it.
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _fileName);
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, version) => _createAllTables(db),
      onUpgrade: (db, oldVersion, newVersion) => _createAllTables(db),
    );
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
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${StorageConstants.tasksTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        date TEXT,
        time TEXT,
        priority TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT,
        completed_at TEXT
      )
    ''');

    await batch.commit(noResult: true);
  }
}
