import 'package:flutter/foundation.dart';
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
  /// v9: model_state.size_bytes / file_path / verified_at,
  ///     ai_conversations + ai_messages (Zoe Chat history), memories
  /// v10: model_state.tier / model_name, dalawang row na ang pwede
  ///      (id 1 = Zoe Lite, id 2 = Zoe Plus)
  /// v11: zoe_mood (mood ni Zoe, para pareho pa rin pagbukas ulit ng app)
  /// v12: mood_log (Level 2: bilang ng pagod / stressed… sa huling 7 araw)
  /// v13: notes_fts + memories_fts (FTS4) + triggers — para sa RAG.
  ///      Ginagawa sa onOpen ([_ensureSearchIndex]), hindi sa batch, para
  ///      kahit walang FTS4 ang isang phone ay bumubukas pa rin ang app.
  ///      B6: "unicode61" tokenizer kapag kaya ng phone (Niño = nino);
  ///      kusang inililipat ang lumang "simple" index — walang version bump.
  /// v14: memories.kind + memories.value (Level 3 Companion memory).
  static const _version = 14;

  Future<Database>? _opening;

  /// true = gumagana ang FTS4 search index sa phone na ito.
  /// false = LIKE search ang gagamitin (SearchRepository).
  bool searchReady = false;

  /// Huling error sa paggawa ng search index (para sa Developer screen).
  String? searchError;

  /// Tokenizer ng search index: 'unicode61' (ñ = n) o 'simple'. null = wala.
  String? searchTokenizer;

  /// Opens the database once and reuses it.
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _fileName);
    return openDatabase(
      path,
      version: _version,
      // Bawat bukas: kapag may binura, pinapatungan ng zero ang lumang
      // laman sa file — hindi na mababasa kahit buksan ang zoe.db.
      onConfigure: (db) async {
        try {
          await db.rawQuery('PRAGMA secure_delete = ON');
        } catch (e) {
          debugPrint('secure_delete not available: $e');
        }
      },
      onCreate: (db, version) async {
        await _createAllTables(db);
        await seedTaskCategories(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createAllTables(db);
        await _migrate(db, oldVersion);
      },
      // Tuwing bubuksan: siguraduhing nandiyan at tugma ang search index.
      onOpen: (db) async {
        searchReady = await _ensureSearchIndex(db);
      },
    );
  }

  // ───────────────────────── Search index (FTS4, v13) ─────────────────────────

  static const _searchSpecs = [
    _FtsSpec(
      table: StorageConstants.notesTable,
      fts: StorageConstants.notesFtsTable,
      columns: ['title', 'content'],
    ),
    _FtsSpec(
      table: StorageConstants.memoriesTable,
      fts: StorageConstants.memoriesFtsTable,
      columns: ['content'],
    ),
  ];

  /// Gumagawa ng FTS4 tables + triggers kung wala pa, at nire-rebuild kapag
  /// hindi tugma ang bilang ng rows (hal. unang bukas pagkatapos ng update).
  ///
  /// FTS4 (hindi FTS5): kasama ito sa built-in SQLite ng Android.
  /// Tokenizer (B6): "unicode61" + remove_diacritics kapag kaya ng phone
  /// ("Niño" = "nino", "CAFÉ" = "cafe"); kung hindi, ang default na "simple".
  /// Kapag iba ang tokenizer ng lumang index (hal. "simple" mula B1), binubura
  /// ito at ginagawa ulit mula sa notes / memories — walang nawawalang data.
  ///
  /// Hindi nagt-throw: kapag pumalya (walang FTS4), false lang → LIKE search.
  static Future<bool> _ensureSearchIndex(Database db) async {
    try {
      final tokenizer = await _pickTokenizer(db);
      for (final spec in _searchSpecs) {
        final sql = await _tableSql(db, spec.fts);
        var fresh = sql == null;
        if (sql != null && tokenizerOf(sql) != tokenizer) {
          // Lumang tokenizer → gawin ulit (triggers muna, saka ang table).
          for (final drop in spec.dropTriggerSql) {
            await db.execute(drop);
          }
          await db.execute('DROP TABLE IF EXISTS ${spec.fts}');
          fresh = true;
        }
        if (fresh) await db.execute(spec.createSql(tokenizer));
        for (final trigger in spec.triggerSql) {
          await db.execute(trigger);
        }
        if (fresh || await _count(db, spec.table) != await _count(db, spec.fts)) {
          await _rebuild(db, spec);
        }
      }
      instance.searchError = null;
      instance.searchTokenizer = tokenizer;
      return true;
    } catch (e) {
      debugPrint('Search index (FTS4) not available: $e');
      instance.searchError = '$e';
      instance.searchTokenizer = null;
      return false;
    }
  }

  /// Ang tokenizer clause para sa unicode61 (walang tuldik).
  static const unicodeTokenizerSql = 'tokenize=unicode61 "remove_diacritics=1"';

  /// Kaya ba ng SQLite ng phone ang unicode61? Sinusubukan sa temp table.
  /// 'unicode61' o 'simple'.
  static Future<String> _pickTokenizer(Database db) async {
    const probe = 'temp.zoe_tokenizer_probe';
    try {
      await db.execute('CREATE VIRTUAL TABLE IF NOT EXISTS $probe USING fts4(x, $unicodeTokenizerSql)');
      await db.execute('DROP TABLE IF EXISTS $probe');
      return 'unicode61';
    } catch (e) {
      debugPrint('unicode61 tokenizer not available, using simple: $e');
      try {
        await db.execute('DROP TABLE IF EXISTS $probe');
      } catch (_) {}
      return 'simple';
    }
  }

  /// 'unicode61' o 'simple', mula sa CREATE VIRTUAL TABLE na SQL.
  static String tokenizerOf(String createSql) =>
      createSql.toLowerCase().contains('unicode61') ? 'unicode61' : 'simple';

  /// Ang CREATE SQL ng table (mula sa sqlite_master), o null kung wala.
  static Future<String?> _tableSql(Database db, String name) async {
    final rows = await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1", [name]);
    if (rows.isEmpty) return null;
    return (rows.first['sql'] as String?) ?? '';
  }

  /// Burahin at punuin ulit ang FTS table mula sa totoong table.
  static Future<void> _rebuild(Database db, _FtsSpec spec) async {
    final cols = spec.columns.join(', ');
    await db.transaction((txn) async {
      await txn.execute('DELETE FROM ${spec.fts}');
      await txn.execute(
          'INSERT INTO ${spec.fts} (docid, $cols) SELECT id, $cols FROM ${spec.table}');
    });
  }

  static Future<bool> _tableExists(Database db, String name) async {
    final rows = await db.rawQuery(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1", [name]);
    return rows.isNotEmpty;
  }

  static Future<int> _count(Database db, String table) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM $table');
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Para sa Developer screen: gumagana ba, at tugma ba ang bilang.
  Future<SearchIndexStatus> searchIndexStatus() async {
    final db = await database;
    final version = await db.rawQuery('SELECT sqlite_version() AS v');
    final counts = <String, (int, int?)>{};
    for (final spec in _searchSpecs) {
      final rows = await _count(db, spec.table);
      int? indexed;
      if (await _tableExists(db, spec.fts)) indexed = await _count(db, spec.fts);
      counts[spec.table] = (rows, indexed);
    }
    return SearchIndexStatus(
      ready: searchReady,
      sqliteVersion: '${version.first['v']}',
      counts: counts,
      error: searchError,
      tokenizer: searchTokenizer,
    );
  }

  /// Developer › "Rebuild": gawin ulit ang index (o subukan ulit kung pumalya).
  Future<SearchIndexStatus> rebuildSearchIndex() async {
    final db = await database;
    searchReady = await _ensureSearchIndex(db);
    if (searchReady) {
      for (final spec in _searchSpecs) {
        await _rebuild(db, spec);
      }
    }
    return searchIndexStatus();
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
      await seedTaskCategories(db);
      // Ang mga lumang na-miss na task ay mare-record ng
      // TaskRepository.recordMissed() pagbukas ng Tasks screen.
    }
    if (oldVersion < 9) {
      // Para sa Settings › Zoe's Brain (at sa model downloader later).
      await _addColumnIfMissing(db, 'model_state', 'size_bytes', 'INTEGER');
      await _addColumnIfMissing(db, 'model_state', 'file_path', 'TEXT');
      await _addColumnIfMissing(db, 'model_state', 'verified_at', 'TEXT');
    }
    if (oldVersion < 10) {
      await _rebuildModelState(db);
    }
    if (oldVersion < 14) {
      // Level 3: anong klaseng memory (nickname, style, stress_help, win,
      // routine, general) + ang value nito ("AC", "diretso", "listen").
      // Ang lumang memories ay 'general' lahat.
      await _addColumnIfMissing(
          db, StorageConstants.memoriesTable, 'kind', "TEXT NOT NULL DEFAULT 'general'");
      await _addColumnIfMissing(db, StorageConstants.memoriesTable, 'value', 'TEXT');
    }
    // v13: walang column change. Ang notes_fts / memories_fts ay ginagawa
    // at pinupuno sa onOpen (_ensureSearchIndex) — kasama ang lumang notes.
  }

  /// model_state: isang row kada model. id 1 = Zoe Lite, id 2 = Zoe Plus.
  static String _modelStateSql(String table) => '''
      CREATE TABLE IF NOT EXISTS $table (
        id INTEGER PRIMARY KEY CHECK (id IN (1, 2)),
        tier TEXT NOT NULL DEFAULT 'lite',
        model_name TEXT,
        status TEXT NOT NULL,
        model_version TEXT,
        size_bytes INTEGER,
        file_path TEXT,
        verified_at TEXT,
        updated_at TEXT NOT NULL
      )
    ''';

  /// v10: ang lumang model_state ay may CHECK (id = 1), kaya hindi
  /// makakapasok ang row ng Zoe Plus. Hindi natatanggal ang CHECK sa
  /// SQLite, kaya: gawa ng bagong table → kopya → palit.
  /// Ang dating row (id 1) ay nagiging Zoe Lite. Ang 0.8B lang ang
  /// model bago ang v10, kaya iyon ang model_name kapag may file na.
  static Future<void> _rebuildModelState(Database db) async {
    await db.execute('DROP TABLE IF EXISTS model_state_new');
    await db.execute(_modelStateSql('model_state_new'));
    await db.execute('''
      INSERT INTO model_state_new
        (id, tier, model_name, status, model_version,
         size_bytes, file_path, verified_at, updated_at)
      SELECT 1, 'lite',
             CASE WHEN file_path IS NOT NULL THEN 'Qwen3.5-0.8B-Q4_K_M' END,
             status, model_version,
             size_bytes, file_path, verified_at, updated_at
      FROM model_state
      WHERE id = 1
    ''');
    await db.execute('DROP TABLE model_state');
    await db.execute('ALTER TABLE model_state_new RENAME TO model_state');
  }

  /// Ang 7 dating categories. Tinatawag sa bagong install, pag-upgrade sa v7,
  /// at pagkatapos ng "Burahin lahat" (WipeRepository). Kapag dinelete ng user
  /// ang isa, hindi na ito babalik — maliban kung burahin lahat.
  /// Pareho ang key sa dati, kaya walang task na kailangang baguhin.
  static Future<void> seedTaskCategories(DatabaseExecutor db) async {
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

    // Bagong install: v10 schema agad. Lumang install: hindi ito
    // gagalaw (IF NOT EXISTS); _rebuildModelState ang mag-a-update.
    batch.execute(_modelStateSql('model_state'));

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

    // Zoe Chat history. Isang conversation = isang chat session.
    // role = 'user' / 'zoe'. Nabubura sa Settings › Privacy & Memory.
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${StorageConstants.conversationsTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${StorageConstants.messagesTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_messages_conversation '
      'ON ${StorageConstants.messagesTable} (conversation_id, created_at)',
    );

    // Long-term memory ni Zoe (hal. "Mas gusto ko ng morning reminders").
    // source = 'chat' (natutunan sa usapan) o 'user' (sinabi mismo).
    // importance 1–5. Hindi nagsasave dito kapag OFF ang long-term memory.
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${StorageConstants.memoriesTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'chat',
        importance INTEGER NOT NULL DEFAULT 3,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'general',
        value TEXT
      )
    ''');

    // Mood ni Zoe (Personality plan, P2b). Isang row lang (id 1).
    // Bagong table lang, kaya sapat na ang IF NOT EXISTS para sa v10 → v11.
    // celebrated = "all_done,streak:7" (comma-separated), para sa
    //   isang-beses-lang-kada-araw na celebration.
    // seen_day / seen_missed / seen_overdue = ilang na-miss / overdue na ang
    //   "nakita" ni Zoe ngayong araw (para hindi paulit-ulit mag-react).
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${StorageConstants.moodTable} (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        state TEXT NOT NULL,
        intensity INTEGER NOT NULL DEFAULT 0,
        since TEXT NOT NULL,
        reason TEXT NOT NULL DEFAULT '',
        celebrated TEXT NOT NULL DEFAULT '',
        celebrated_on TEXT NOT NULL DEFAULT '',
        seen_day TEXT NOT NULL DEFAULT '',
        seen_missed INTEGER NOT NULL DEFAULT 0,
        seen_overdue INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // Mood log (Companion Level 2). Isang row kada (araw, tone):
    // ilang beses pagod / stressed / masaya… ang user sa araw na iyon.
    // BILANG LANG — walang mensahe ng user. Kusang binubura ang mas luma
    // sa 7 araw (MoodLog). Bagong table lang → sapat ang IF NOT EXISTS (v11 → v12).
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ${StorageConstants.moodLogTable} (
        day TEXT NOT NULL,
        tone TEXT NOT NULL,
        count INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (day, tone)
      )
    ''');

    await batch.commit(noResult: true);
  }
}

/// Isang FTS4 mirror: [fts] ay kopya ng [columns] ng [table], docid = id.
class _FtsSpec {
  const _FtsSpec({required this.table, required this.fts, required this.columns});

  final String table;
  final String fts;
  final List<String> columns;

  /// CREATE VIRTUAL TABLE na may [tokenizer] ('unicode61' o 'simple').
  String createSql(String tokenizer) {
    final cols = columns.join(', ');
    final tok = tokenizer == 'unicode61' ? ', ${ZoeDatabase.unicodeTokenizerSql}' : '';
    return 'CREATE VIRTUAL TABLE IF NOT EXISTS $fts USING fts4($cols$tok)';
  }

  /// Para sa paggawa ulit ng index (ibang tokenizer).
  List<String> get dropTriggerSql => [
        'DROP TRIGGER IF EXISTS ${fts}_ai',
        'DROP TRIGGER IF EXISTS ${fts}_au',
        'DROP TRIGGER IF EXISTS ${fts}_ad',
      ];

  /// Insert / update / delete sa [table] → sabay sa [fts].
  /// Update: binubura at ini-insert ulit (gumagana kahit nawawala ang row sa
  /// index). "UPDATE OF" — ang pin / importance lang ay hindi gumagalaw sa index.
  List<String> get triggerSql {
    final cols = columns.join(', ');
    final newCols = columns.map((c) => 'new.$c').join(', ');
    return [
      'CREATE TRIGGER IF NOT EXISTS ${fts}_ai AFTER INSERT ON $table BEGIN '
          'INSERT INTO $fts (docid, $cols) VALUES (new.id, $newCols); END',
      'CREATE TRIGGER IF NOT EXISTS ${fts}_au AFTER UPDATE OF $cols ON $table BEGIN '
          'DELETE FROM $fts WHERE docid = old.id; '
          'INSERT INTO $fts (docid, $cols) VALUES (new.id, $newCols); END',
      'CREATE TRIGGER IF NOT EXISTS ${fts}_ad AFTER DELETE ON $table BEGIN '
          'DELETE FROM $fts WHERE docid = old.id; END',
    ];
  }
}

/// Estado ng search index (Developer screen).
class SearchIndexStatus {
  const SearchIndexStatus({
    required this.ready,
    required this.sqliteVersion,
    required this.counts,
    this.error,
    this.tokenizer,
  });

  /// true = FTS4 ang ginagamit; false = LIKE.
  final bool ready;
  final String sqliteVersion;

  /// table → (bilang ng rows, bilang sa index o null kung walang index).
  final Map<String, (int, int?)> counts;
  final String? error;

  /// 'unicode61' (ñ = n) o 'simple'. null = walang FTS4.
  final String? tokenizer;

  /// Tugma lahat ng bilang.
  bool get inSync => counts.values.every((c) => c.$2 == c.$1);
}