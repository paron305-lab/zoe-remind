import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/repositories/memory_repository.dart';
import 'package:zoe_remind/database/repositories/note_repository.dart';
import 'package:zoe_remind/database/repositories/search_repository.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/retriever.dart';

/// Takbuhin:  flutter test test/database/search_repository_test.dart
///
/// B2: SearchRepository + Retriever sa totoong SQLite (sqflite_common_ffi),
/// sariling temp folder. FTS4 at LIKE fallback — pareho dapat ang sagot
/// (R1: kasama ang ugat ng salita sa pareho).
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
    });
  }
}