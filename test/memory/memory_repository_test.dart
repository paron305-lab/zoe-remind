import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zoe_remind/database/repositories/memory_repository.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/rag/retriever.dart';

/// Takbuhin:  flutter test test/memory/memory_repository_test.dart
///
/// B5: MemoryRepository.add — walang doble, OFF = walang nase-save,
/// at nahahanap ng Retriever ang bagong salita (memories_fts).
/// Totoong SQLite (sqflite_common_ffi), sariling temp folder.
void main() {
  final repo = MemoryRepository();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = Directory.systemTemp.createTempSync('zoe_memory_repo_');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  setUp(() async {
    await SettingsRepository().setLongTermMemory(true);
    await repo.clearAll();
  });

  test('pareho → ina-update, hindi nadadagdagan', () async {
    final first = await repo.add('Mas gusto ko ng morning reminders', source: 'user');
    final again = await repo.add('Gusto ko ng morning reminders', source: 'user');
    expect(again, first);
    expect(await repo.count(), 1);
    expect((await repo.getAll()).single.content, 'Gusto ko ng morning reminders');
  });

  test('napalitan ang gusto → isang memory, bagong salita', () async {
    await repo.add('Gusto ko ng morning reminders', source: 'user');
    await repo.add('Ayoko ng morning reminders', source: 'chat');
    final all = await repo.getAll();
    expect(all.single.content, 'Ayoko ng morning reminders');
    expect(all.single.source, 'user'); // "sinabi mo mismo" ay nananatili
  });

  test('magkaiba → dalawa', () async {
    await repo.add('Mas gusto ko ng morning reminders', source: 'user');
    await repo.add('Ayoko ng maingay na alarm', source: 'user');
    expect(await repo.count(), 2);
  });

  test('OFF ang long-term memory → null, walang nase-save', () async {
    await SettingsRepository().setLongTermMemory(false);
    expect(await repo.add('Vegetarian ako', source: 'user'), isNull);
    expect(await repo.count(), 0);
  });

  test('Retriever: nahahanap ang bagong salita, hindi ang luma', () async {
    await repo.add('Gusto ko ng kape sa umaga', source: 'user');
    await repo.add('Ayoko ng kape sa umaga', source: 'user'); // napalitan
    final hits = await Retriever().search('ano ayaw ko sa umaga?');
    expect(hits.single.doc.text, 'Ayoko ng kape sa umaga');
  });
}