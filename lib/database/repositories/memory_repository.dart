import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/models/memory_item.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/memory/memory_rules.dart';

/// Ang tanging nagbabasa/nagsusulat ng memories table (long-term memory ni Zoe).
/// Zoe Chat ("tandaan mo na mas gusto ko…", pagkatapos ng Accept) → add().
/// Settings › Zoe's memories → list, delete, clearAll().
/// Hinahanap ng Retriever sa memories_fts (pinupuno ng triggers).
class MemoryRepository {
  MemoryRepository({SettingsRepository? settings})
      : _settings = settings ?? SettingsRepository();

  static const _table = StorageConstants.memoriesTable;
  static final changes = ValueNotifier<int>(0);

  final SettingsRepository _settings;

  String _now() => DateTime.now().toIso8601String();

  /// Nagsasave lang kapag ON ang long-term memory sa Settings.
  /// Returns null kapag OFF (walang na-save).
  ///
  /// Walang doble: kapag may kaparehong memory na (MemoryRules.sameMemory),
  /// iyon ang ina-update (bagong salita + bagong oras) at ang id nito ang
  /// ibinabalik. Hal. "Gusto ko ng morning reminders" → "Ayoko ng morning
  /// reminders" = napapalitan, hindi nadadagdagan.
  Future<int?> add(String content, {String source = 'chat', int importance = 3}) async {
    if (!await _settings.isLongTermMemoryOn()) return null;
    final text = content.trim();
    if (text.isEmpty) return null;
    final db = await ZoeDatabase.instance.database;
    final now = _now();

    final existing = await db.query(
      _table,
      columns: ['id', 'content', 'source', 'importance'],
      orderBy: 'updated_at DESC, id DESC',
    );
    for (final row in existing) {
      if (!MemoryRules.sameMemory(row['content'] as String, text)) continue;
      final id = row['id'] as int;
      final oldSource = row['source'] as String?;
      await db.update(
        _table,
        {
          'content': text,
          // "sinabi mo mismo" ay hindi bumababa sa "natutunan sa chat"
          'source': oldSource == 'user' ? 'user' : source,
          'importance': math.max((row['importance'] as int?) ?? 3, importance).clamp(1, 5),
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      changes.value++;
      return id;
    }

    final id = await db.insert(_table, {
      'content': text,
      'source': source,
      'importance': importance.clamp(1, 5),
      'created_at': now,
      'updated_at': now,
    });
    changes.value++;
    return id;
  }

  Future<int> count() async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM $_table');
    return (rows.first['n'] as int?) ?? 0;
  }

  Future<List<MemoryItem>> getAll() async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.query(_table, orderBy: 'updated_at DESC, id DESC');
    return rows.map(MemoryItem.fromRow).toList();
  }

  Future<void> delete(int id) async {
    final db = await ZoeDatabase.instance.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    changes.value++;
  }

  Future<void> clearAll() async {
    final db = await ZoeDatabase.instance.database;
    await db.delete(_table);
    changes.value++;
  }
}