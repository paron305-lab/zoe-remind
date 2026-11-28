import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/repositories/memory_repository.dart';
import 'package:zoe_remind/database/repositories/note_repository.dart';
import 'package:zoe_remind/rag/retriever.dart';
import 'package:zoe_remind/rag/stemmer.dart';

/// Takbuhin:  flutter test test/database/search_index_test.dart
///
/// B1: FTS4 search index (DB v13). R1: search_stems (DB v15) — mga ugat ng
/// salita, kasama sa index. Totoong SQLite sa PC (sqflite_common_ffi),
/// sariling temp folder — hindi kasabay ng ibang DB test, hindi ang phone.
///
/// Sinisimulan sa LUMANG zoe.db (v12, may notes na) para ma-test ang
/// upgrade: dapat kasama sa index ang mga lumang notes.
///
/// PAALALA: ang SQLite ng sqflite_common_ffi sa Windows ay WALANG FTS4
/// ("no such module: fts4"). Sa ganoong PC, nilalaktawan (skip) ang mga
/// FTS4 test — pero tine-test pa rin na hindi nagka-crash ang app at LIKE
/// search ang ginagamit. Ang FTS4 mismo ay i-check sa phone:
/// Settings › Developer › 8. Search index.
Future<void> main() async {
  sqfliteFfiInit();
  final fts4 = await _hasFts4();
  final unicode61 = fts4 && await _hasUnicode61();
  final skipFts = fts4
      ? false
      : 'Walang FTS4 ang SQLite sa PC na ito — i-check sa phone (Developer › 8. Search index)';

  late Database db;

  Future<List<int>> notesMatching(String match) async {
    final rows = await db.rawQuery(
      'SELECT docid FROM ${StorageConstants.notesFtsTable} '
      'WHERE ${StorageConstants.notesFtsTable} MATCH ? ORDER BY docid',
      [match],
    );
    return rows.map((r) => r['docid'] as int).toList();
  }

  Future<int> count(String table) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM $table');
    return rows.first['n'] as int;
  }

  setUpAll(() async {
    databaseFactory = databaseFactoryFfi;
    final dir = Directory.systemTemp.createTempSync('zoe_search_index_');
    await databaseFactory.setDatabasesPath(dir.path);
    final path = join(dir.path, 'zoe.db');

    // Lumang install (v12): notes + memories, walang FTS.
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 12,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE notes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              content TEXT NOT NULL DEFAULT '',
              source TEXT NOT NULL DEFAULT 'typed',
              pinned INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )''');
          await db.execute('''
            CREATE TABLE memories (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              content TEXT NOT NULL,
              source TEXT NOT NULL DEFAULT 'chat',
              importance INTEGER NOT NULL DEFAULT 3,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )''');
          const t = '2026-11-01T08:00:00.000';
          await db.insert('notes', {
            'title': 'Wifi',
            'content': 'Wi-Fi password ng office ay zoe123',
            'created_at': t,
            'updated_at': t,
          });
          await db.insert('notes', {
            'title': 'Shopping list',
            'content': 'itlog, gatas, tinapay',
            'created_at': t,
            'updated_at': t,
          });
          await db.insert('memories', {
            'content': 'Mas gusto ko ng morning reminders',
            'source': 'user',
            'created_at': t,
            'updated_at': t,
          });
        },
      ),
    );
    await old.close();

    db = await ZoeDatabase.instance.database; // v12 → v16 + onOpen
  });

  test('upgrade v12 → v16: bumubukas kahit walang FTS4, at nahahanap pa rin ang notes', () async {
    expect(await db.getVersion(), 16);
    expect(ZoeDatabase.instance.searchReady, fts4);
    if (!fts4) expect(ZoeDatabase.instance.searchError, contains('fts4'));
    // FTS4 o LIKE — pareho dapat ang sagot.
    final hits = await Retriever().search('ano wifi password ko?');
    expect(hits.first.doc.title, 'Wifi');
    expect(await Retriever().search('ano pin ko'), isEmpty); // hindi "shopping"
  });

  test('upgrade v12 → v16: lumang memory ay "general" (Level 3 kind + value)', () async {
    final rows = await db.query('memories', columns: ['kind', 'value']);
    expect(rows.single['kind'], 'general');
    expect(rows.single['value'], isNull);
  });

  test('upgrade v12 → v16 (R6): use_count = 0 ang lumang memory, may learning tables', () async {
    final rows = await db.query('memories', columns: ['use_count', 'last_used_at']);
    expect(rows.single['use_count'], 0);
    expect(rows.single['last_used_at'], isNull);
    for (final t in [
      StorageConstants.searchLogTable,
      StorageConstants.learnedTermsTable,
      StorageConstants.searchFeedbackTable,
    ]) {
      expect(await count(t), 0, reason: t);
    }
  });

  test('upgrade v12 → v16 (R1): napunan ang search_stems ng lumang notes / memories', () async {
    final notes = await db.query('notes', columns: ['id', 'search_stems'], orderBy: 'id');
    expect(notes.map((r) => r['search_stems']).toList(), ['', 'shop']); // "Shopping list" → shop
    final mem = await db.query('memories', columns: ['search_stems']);
    expect(mem.single['search_stems'], 'reminder'); // "reminders" → reminder
    final version = await db.query('settings',
        where: 'key = ?', whereArgs: [ZoeDatabase.stemsVersionKey]);
    expect(version.single['value'], '${Stemmer.version}');
  });

  test('R1: bagong note → may search_stems; "bumili" → "Binili ko…" (FTS4 o LIKE)', () async {
    final repo = NoteRepository();
    final id = await repo.add(title: 'Sapatos', content: 'Binili ko ang shoes sa SM');
    final row = await db.query('notes', where: 'id = ?', whereArgs: [id]);
    expect(row.single['search_stems'], 'bili shoe');

    final hits = await Retriever().search('saan ako bumili ng sapatos?');
    expect(hits.first.doc.id, id);
    expect((await Retriever().search('what shoes did I buy?')).first.doc.id, id);

    // edit → nagbabago rin ang search_stems
    await repo.update((await repo.getById(id))!.copyWith(content: 'Nagluto ako ng adobo'));
    final edited = await db.query('notes', where: 'id = ?', whereArgs: [id]);
    expect(edited.single['search_stems'], 'luto');
    await repo.delete(id);
  });

  test('upgrade v12 → v16: gumagana ang FTS4 at kasama ang lumang notes', () async {
    expect(ZoeDatabase.instance.searchReady, isTrue, reason: ZoeDatabase.instance.searchError);
    expect(await db.getVersion(), 16);
    expect(await count(StorageConstants.notesFtsTable), 2);
    expect(await count(StorageConstants.memoriesFtsTable), 1);
    expect(await notesMatching('zoe123'), [1]);
    expect(await notesMatching('wifi*'), [1]);
    expect(await notesMatching('"wi fi"'), [1]); // "Wi-Fi" → wi + fi
    expect(await notesMatching('tinapay'), [2]);
    expect(await notesMatching('shop'), [2]); // R1: ugat sa search_stems
  }, skip: skipFts);

  test('R1: ugat sa FTS4 — "bili" → "Binili", sabay sa add / edit / delete', () async {
    final repo = NoteRepository();
    final id = await repo.add(title: 'Sapatos', content: 'Binili ko ang sapatos sa SM');
    expect(await notesMatching('bili'), [id]);
    await repo.update((await repo.getById(id))!.copyWith(content: 'Nagluto ako ng adobo'));
    expect(await notesMatching('bili'), isEmpty);
    expect(await notesMatching('luto'), [id]);
    await repo.delete(id);
    expect(await notesMatching('luto'), isEmpty);

    final memories = MemoryRepository();
    final mid = await memories.add('Hindi ako umiinom ng kape', source: 'user');
    final rows = await db.rawQuery(
      'SELECT docid FROM ${StorageConstants.memoriesFtsTable} '
      'WHERE ${StorageConstants.memoriesFtsTable} MATCH ?',
      ['inom'],
    );
    expect(rows.map((r) => r['docid']), [mid]);
    await memories.delete(mid!);
  }, skip: skipFts);

  test('R1: lumang index na walang search_stems → kusang ginagawa ulit', () async {
    // Gayahin ang index bago ang v15 (title, content lang).
    for (final t in ['ai', 'au', 'ad']) {
      await db.execute('DROP TRIGGER IF EXISTS ${StorageConstants.notesFtsTable}_$t');
    }
    await db.execute('DROP TABLE ${StorageConstants.notesFtsTable}');
    final tok = unicode61 ? ', ${ZoeDatabase.unicodeTokenizerSql}' : '';
    await db.execute(
        'CREATE VIRTUAL TABLE ${StorageConstants.notesFtsTable} USING fts4(title, content$tok)');
    await db.execute('INSERT INTO ${StorageConstants.notesFtsTable} (docid, title, content) '
        'SELECT id, title, content FROM notes');
    expect(await notesMatching('shop'), isEmpty);

    final status = await ZoeDatabase.instance.rebuildSearchIndex();
    expect(status.ready, isTrue);
    expect(status.inSync, isTrue);
    final sql = await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE name = '${StorageConstants.notesFtsTable}'");
    expect(sql.first['sql'] as String, contains('search_stems'));
    expect(await notesMatching('shop'), [2]);
  }, skip: skipFts);

  test('hasColumns', () {
    expect(ZoeDatabase.hasColumns('CREATE VIRTUAL TABLE x USING fts4(title, content)',
        ['title', 'content', 'search_stems']), isFalse);
    expect(ZoeDatabase.hasColumns(
        'CREATE VIRTUAL TABLE x USING fts4(title, content, search_stems, tokenize=unicode61 "remove_diacritics=1")',
        ['title', 'content', 'search_stems']), isTrue);
  });

  test('"pin" ay hindi tumatama sa "shopping" (hindi na substring)', () async {
    expect(await notesMatching('pin'), isEmpty);
  }, skip: skipFts);

  test('add / edit / pin / delete ng note → sabay ang index', () async {
    final repo = NoteRepository();
    final id = await repo.add(title: 'Locker', content: 'Locker code sa gym: 4521');
    expect(await notesMatching('locker*'), contains(id));

    final note = (await repo.getById(id))!;
    await repo.update(note.copyWith(content: 'Gym locker: 9999'));
    expect(await notesMatching('4521'), isEmpty);
    expect(await notesMatching('9999'), [id]);

    await repo.setPinned(id, true); // hindi edit ng text — index pareho pa rin
    expect(await notesMatching('9999'), [id]);

    await repo.delete(id);
    expect(await notesMatching('locker*'), isEmpty);
    expect(await count(StorageConstants.notesFtsTable), await count(StorageConstants.notesTable));
  }, skip: skipFts);

  test('memories: add at clearAll → sabay ang index', () async {
    final repo = MemoryRepository();
    await repo.add('Ayoko ng maingay na alarm', source: 'user');
    expect(await count(StorageConstants.memoriesFtsTable), 2);
    await repo.clearAll();
    expect(await count(StorageConstants.memoriesFtsTable), 0);
  }, skip: skipFts);

  test('B6: unicode61 tokenizer — "nino" = "Niño", "cafe" = "CAFÉ"', () async {
    final status = await ZoeDatabase.instance.searchIndexStatus();
    expect(status.tokenizer, 'unicode61');
    final repo = NoteRepository();
    final id = await repo.add(title: 'Bday ni Niño', content: 'Kape sa CAFÉ ni Ñaña');
    expect(await notesMatching('nino'), contains(id));
    expect(await notesMatching('niño'), contains(id));
    expect(await notesMatching('cafe'), contains(id));
    expect(await notesMatching('nana'), contains(id));
    final hits = await Retriever().search('kailan bday ni nino?');
    expect(hits.first.doc.id, id);
    await repo.delete(id);
  }, skip: skipFts == false && !unicode61 ? 'Walang unicode61 ang SQLite sa PC na ito' : skipFts);

  test('B6: lumang "simple" index → kusang nagiging unicode61, kumpleto pa rin', () async {
    // Gayahin ang index mula B1 (simple tokenizer).
    for (final t in ['ai', 'au', 'ad']) {
      await db.execute('DROP TRIGGER IF EXISTS ${StorageConstants.notesFtsTable}_$t');
    }
    await db.execute('DROP TABLE ${StorageConstants.notesFtsTable}');
    await db.execute('CREATE VIRTUAL TABLE ${StorageConstants.notesFtsTable} USING fts4(title, content)');
    await db.execute('INSERT INTO ${StorageConstants.notesFtsTable} (docid, title, content) '
        'SELECT id, title, content FROM notes');

    final status = await ZoeDatabase.instance.rebuildSearchIndex();
    expect(status.ready, isTrue);
    expect(status.tokenizer, 'unicode61');
    expect(status.inSync, isTrue);
    final sql = await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE name = '${StorageConstants.notesFtsTable}'");
    expect(sql.first['sql'] as String, contains('unicode61'));
    expect(await notesMatching('zoe123'), [1]);

    // Gumagana pa rin ang triggers pagkatapos ng paglipat.
    final id = await NoteRepository().add(title: 'Piñata', content: 'para sa party');
    expect(await notesMatching('pinata'), [id]);
    await NoteRepository().delete(id);
  }, skip: skipFts == false && !unicode61 ? 'Walang unicode61 ang SQLite sa PC na ito' : skipFts);

  test('status at rebuild (Developer screen)', () async {
    await db.execute('DELETE FROM ${StorageConstants.notesFtsTable}'); // sirain
    var status = await ZoeDatabase.instance.searchIndexStatus();
    expect(status.inSync, isFalse);

    status = await ZoeDatabase.instance.rebuildSearchIndex();
    expect(status.ready, isTrue);
    expect(status.inSync, isTrue);
    expect(status.counts[StorageConstants.notesTable], (2, 2));
    expect(await notesMatching('zoe123'), [1]);
  }, skip: skipFts);
}

/// May unicode61 tokenizer ba (B6)?
Future<bool> _hasUnicode61() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  try {
    await db.execute('CREATE VIRTUAL TABLE tok_probe USING fts4(a, ${ZoeDatabase.unicodeTokenizerSql})');
    return true;
  } catch (_) {
    return false;
  } finally {
    await db.close();
  }
}

/// May FTS4 ba ang SQLite na gamit ng test (sqflite_common_ffi sa PC)?
Future<bool> _hasFts4() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  try {
    await db.execute('CREATE VIRTUAL TABLE fts_probe USING fts4(a)');
    return true;
  } catch (_) {
    return false;
  } finally {
    await db.close();
  }
}