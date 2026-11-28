import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/repositories/memory_repository.dart';
import 'package:zoe_remind/database/repositories/note_repository.dart';
import 'package:zoe_remind/database/repositories/search_repository.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/retriever.dart';

/// Takbuhin:  flutter test test/database/search_repository_test.dart
///
/// B2: SearchRepository + Retriever sa totoong SQLite (sqflite_common_ffi),
/// sariling temp folder. FTS4 at LIKE fallback — pareho dapat ang sagot
/// (R1: kasama ang ugat ng salita sa pareho).
/// R2: corpusStats (N + df para sa IDF) — FTS4 lang; LIKE → null.
/// R4: reminders + tasks — kasama sa candidates (FTS4 at LIKE), at sa
/// corpusStats pagkatapos ng candidates.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = Directory.systemTemp.createTempSync('zoe_search_repo_');
    await databaseFactory.setDatabasesPath(dir.path);

    final notes = NoteRepository();
    await notes.add(title: 'Wifi', content: 'Wi-Fi password ng office ay zoe123');
    await notes.add(title: 'Shopping list', content: 'itlog, gatas, tinapay');
    await notes.add(title: 'Bahay', content: 'wifi sa bahay: zoe2026');
    await notes.add(title: 'Passport', content: 'passport number P1234567');
    await notes.add(title: 'Sapatos', content: 'Binili ko ang running shoes sa SM'); // R1
    await MemoryRepository().add('Mas gusto ko ng morning reminders', source: 'user');

    // R4: diretso sa table (walang alarm / mood na kailangan sa test).
    final db = await ZoeDatabase.instance.database;
    const t = '2026-11-20T09:00:00.000';
    await db.insert(StorageConstants.remindersTable, {
      'title': 'Dentist appointment', 'date': '2026-12-03', 'time': '15:00',
      'repeat': 'none', 'created_at': t, 'updated_at': t,
    });
    await db.insert(StorageConstants.remindersTable, {
      'title': 'Bayaran ang Meralco', 'date': '2026-11-15', 'time': '09:00',
      'repeat': 'monthly', 'created_at': t, 'updated_at': t,
    });
    await db.insert(StorageConstants.tasksTable, {
      'title': 'Ayusin ang resume', 'created_at': t, 'updated_at': t,
    });
    await db.insert(StorageConstants.tasksTable, {
      'title': 'Linisin ang kwarto', 'status': 'done', 'created_at': t, 'updated_at': t,
      'completed_at': t,
    });
  });

  for (final fts in [true, false]) {
    group(fts ? 'FTS4' : 'LIKE (walang FTS4)', () {
      setUp(() async {
        await ZoeDatabase.instance.database;
        ZoeDatabase.instance.searchReady = fts;
      });

      test('candidates: "wifi password" → Wifi at Bahay', () async {
        final docs = await SearchRepository().candidates(QueryTerms.parse('wifi password'));
        expect(docs.map((d) => d.title).toSet(), {'Wifi', 'Bahay'});
      });

      test('Retriever: "ano wifi password ko?" → Wifi muna', () async {
        final hits = await Retriever().search('ano wifi password ko?');
        expect(hits.map((h) => h.doc.title).toList(), ['Wifi', 'Bahay']);
      });

      test('"pin" ay hindi lumalabas sa "Shopping list"', () async {
        expect(await Retriever().search('ano pin ko'), isEmpty);
      });

      test('R1: "saan ako bumili ng sapatos?" → "Binili ko…" (ugat sa search_stems)', () async {
        final docs = await SearchRepository().candidates(QueryTerms.parse('bumili'));
        expect(docs.map((d) => d.title), ['Sapatos']);
        final hits = await Retriever().search('saan ako bumili ng sapatos?');
        expect(hits.first.doc.title, 'Sapatos');
        expect((await Retriever().search('what shoes did I buy?')).first.doc.title, 'Sapatos');
      });

      test('memories kasama lang kapag includeMemories', () async {
        final on = await Retriever().search('anong reminders gusto ko?');
        expect(on.single.doc.isMemory, isTrue);
        final off = await Retriever().search('anong reminders gusto ko?', includeMemories: false);
        expect(off, isEmpty);
      });

      test('R2: "ano wifi password ko?" → Wifi sigurado, Bahay hindi', () async {
        final hits = await Retriever().search('ano wifi password ko?');
        expect(hits.first.isSure, isTrue);
        expect(hits[1].isSure, isFalse);
      });

      test('R4: candidates — reminders + tasks (title, ugat)', () async {
        final docs = await SearchRepository().candidates(QueryTerms.parse('dentist'));
        expect(docs.map((d) => (d.source, d.title)), [(RetrievalSource.reminder, 'Dentist appointment')]);
        // "maglinis" → ugat "linis" ↔ "Linisin" (tapos na, kasama pa rin)
        final clean = await SearchRepository().candidates(QueryTerms.parse('maglinis'));
        expect(clean.single.title, 'Linisin ang kwarto');
        expect(clean.single.done, isTrue);
      });

      test('R4: "may reminder ba ako tungkol sa dentist?" → reminder + kailan', () async {
        final hits = await Retriever().search('may reminder ba ako tungkol sa dentist?');
        final d = hits.single.doc;
        expect(d.source, RetrievalSource.reminder);
        expect((d.title, d.date, d.time, d.repeat, d.done),
            ('Dentist appointment', '2026-12-03', '15:00', 'none', false));
      });

      test('R4: "anong task ko sa resume?" → task · "meralco" → reminder', () async {
        final task = (await Retriever().search('anong task ko sa resume?')).first.doc;
        expect((task.source, task.title), (RetrievalSource.task, 'Ayusin ang resume'));
        final bill = (await Retriever().search('kailan ko babayaran ang meralco?')).first.doc;
        expect((bill.source, bill.repeat), (RetrievalSource.reminder, 'monthly'));
      });
    });
  }

  test('R2: corpusStats — FTS4 → N at df; LIKE → null', () async {
    await ZoeDatabase.instance.database;
    final terms = QueryTerms.parse('wifi password');

    ZoeDatabase.instance.searchReady = false;
    expect(await SearchRepository().corpusStats(terms), isNull);

    ZoeDatabase.instance.searchReady = true;
    final stats = await SearchRepository().corpusStats(terms);
    if (stats == null) return; // walang FTS4 sa PC na ito (pumalya ang MATCH) → null, OK
    expect(stats.docCount, 6); // 5 notes + 1 memory
    expect(stats.docFreq, [2, 1]); // wifi: Wifi + Bahay · password: Wifi
    final noMemories = await SearchRepository().corpusStats(terms, includeMemories: false);
    expect(noMemories!.docCount, 5);
  });

  test('R4: corpusStats pagkatapos ng candidates → + reminders + tasks', () async {
    await ZoeDatabase.instance.database;
    ZoeDatabase.instance.searchReady = true;
    final repo = SearchRepository();
    final terms = QueryTerms.parse('dentist resume');
    await repo.candidates(terms);
    expect(repo.itemTotals, {RetrievalSource.reminder: 2, RetrievalSource.task: 2});
    final stats = await repo.corpusStats(terms);
    if (stats == null) return; // walang FTS4 sa PC na ito
    expect(stats.docCount, 10); // 5 notes + 1 memory + 2 reminders + 2 tasks
    expect(stats.docFreq, [1, 1]); // dentist: reminder · resume: task
  });
}