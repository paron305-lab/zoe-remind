import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zoe_remind/database/repositories/memory_repository.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/memory/companion_facts.dart';

/// Takbuhin:  flutter test test/memory/companion_memory_repository_test.dart
///
/// Level 3 (DB v14): memories.kind + memories.value. Isa lang ang nickname /
/// style / stress help; marami ang wins / routines. Totoong SQLite (ffi).
void main() {
  final repo = MemoryRepository();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = Directory.systemTemp.createTempSync('zoe_companion_repo_');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  setUp(() async {
    await SettingsRepository().setLongTermMemory(true);
    await repo.clearAll();
  });

  test('nickname: bagong sabi → palit, hindi dagdag', () async {
    final a = await repo.add('Tawagin akong AC', source: 'user', kind: FactKind.nickname, value: 'AC');
    final b = await repo.add('Tawagin akong Pao', source: 'user', kind: FactKind.nickname, value: 'Pao');
    expect(b, a);
    final all = await repo.getAll();
    expect(all, hasLength(1));
    expect(all.single.kind, FactKind.nickname);
    expect(all.single.value, 'Pao');
    expect((await repo.profile()).nickname, 'Pao');
  });

  test('style at stress help: isa-isa lang', () async {
    await repo.add('Diretsuhin mo lang ako', kind: FactKind.style, value: 'diretso');
    await repo.add('Maging malambing ka sa akin', kind: FactKind.style, value: 'malambing');
    await repo.add('Kapag stressed ako, makinig ka muna', kind: FactKind.stressHelp, value: 'listen');
    await repo.add('Kapag stressed ako, bigyan mo ako ng payo', kind: FactKind.stressHelp, value: 'advice');
    expect(await repo.count(), 2);
    final p = await repo.profile();
    expect(p.style, TalkStyle.malambing);
    expect(p.stressHelp, StressHelp.advice);
  });

  test('wins / routines: marami; hindi nagagalaw ng nickname', () async {
    await repo.add('Nakapasa ako sa board exam', kind: FactKind.win);
    await repo.add('Natapos ko ang thesis ko', kind: FactKind.win);
    await repo.add('Nag-gy-gym ako tuwing MWF', kind: FactKind.routine);
    await repo.add('Tawagin akong AC', kind: FactKind.nickname, value: 'AC');
    final p = await repo.profile();
    expect(p.wins, hasLength(2));
    expect(p.routines, hasLength(1));
    expect(p.nickname, 'AC');
  });

  test('lumang memory (general) ay hindi napapalitan ng nickname', () async {
    await repo.add('Mas gusto ko ng morning reminders', source: 'user');
    await repo.add('Tawagin akong AC', kind: FactKind.nickname, value: 'AC');
    expect(await repo.count(), 2);
    final general = (await repo.getAll()).where((m) => m.kind == FactKind.general).single;
    expect(general.content, 'Mas gusto ko ng morning reminders');
    expect(general.value, isNull);
  });

  test('OFF ang long-term memory → walang save, empty profile', () async {
    await repo.add('Tawagin akong AC', kind: FactKind.nickname, value: 'AC');
    await SettingsRepository().setLongTermMemory(false);
    expect(await repo.add('Tawagin akong Pao', kind: FactKind.nickname, value: 'Pao'), isNull);
    expect((await repo.profile()).isEmpty, isTrue);
  });
}