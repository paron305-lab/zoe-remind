import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/models/memory_item.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/memory/companion_facts.dart';
import 'package:zoe_remind/memory/companion_profile.dart';
import 'package:zoe_remind/memory/memory_rules.dart';
import 'package:zoe_remind/rag/query_terms.dart';

/// Ang tanging nagbabasa/nagsusulat ng memories table (long-term memory ni Zoe).
/// Zoe Chat ("tandaan mo na mas gusto ko…", pagkatapos ng Accept) → add().
/// Settings › "Ano'ng alam ni Zoe tungkol sa akin" → list, delete, clearAll().
/// Hinahanap ng Retriever sa memories_fts (pinupuno ng triggers).
///
/// Level 3: may [FactKind] ang bawat memory. Isa lang ang nickname, style at
/// stress_help — ang bagong sabi ang pumapalit sa luma.
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
  /// [kind] nickname / style / stress_help → isa lang: kapag may luma na,
  /// iyon ang ina-update (bagong content + value) at ang id nito ang ibinabalik.
  ///
  /// Ibang kind → walang doble: kapag may kaparehong memory na
  /// (MemoryRules.sameMemory), iyon ang ina-update. Hal. "Gusto ko ng morning
  /// reminders" → "Ayoko ng morning reminders" = napapalitan, hindi nadadagdagan.
  Future<int?> add(
    String content, {
    String source = 'chat',
    int importance = 3,
    FactKind kind = FactKind.general,
    String? value,
  }) async {
    if (!await _settings.isLongTermMemoryOn()) return null;
    final text = content.trim();
    if (text.isEmpty) return null;
    final db = await ZoeDatabase.instance.database;
    final now = _now();
    // R1: mga ugat ng salita para sa search ("umiinom" → inom).
    final stems = QueryTerms.searchStems('', text);

    final existing = await db.query(
      _table,
      columns: ['id', 'content', 'source', 'importance', 'kind'],
      orderBy: 'updated_at DESC, id DESC',
    );
    for (final row in existing) {
      final rowKind = FactKind.fromDb(row['kind'] as String?);
      final same = kind.single
          ? rowKind == kind
          : !rowKind.single && MemoryRules.sameMemory(row['content'] as String, text);
      if (!same) continue;
      final id = row['id'] as int;
      final oldSource = row['source'] as String?;
      await db.update(
        _table,
        {
          'content': text,
          'search_stems': stems,
          // "sinabi mo mismo" ay hindi bumababa sa "natutunan sa chat"
          'source': oldSource == 'user' ? 'user' : source,
          'importance': math.max((row['importance'] as int?) ?? 3, importance).clamp(1, 5),
          'kind': kind.db,
          'value': value,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      // Single kind: kung may sobrang row (lumang bug / import), burahin.
      if (kind.single) {
        await db.delete(_table,
            where: 'kind = ? AND id != ?', whereArgs: [kind.db, id]);
      }
      changes.value++;
      return id;
    }

    final id = await db.insert(_table, {
      'content': text,
      'search_stems': stems,
      'source': source,
      'importance': importance.clamp(1, 5),
      'kind': kind.db,
      'value': value,
      'created_at': now,
      'updated_at': now,
    });
    changes.value++;
    return id;
  }

  /// Alam na ba ni Zoe ito? (Memory Recall: "diba sinabi ko sa'yo…" →
  /// "Oo naman, naaalala ko…" imbes na "I'll remember that.")
  ///   nickname / style / stress_help → parehong kind at value
  ///   iba → parehong mga salita ([MemoryRules.sameWords])
  /// OFF ang long-term memory → false.
  Future<bool> knows(String content, {FactKind kind = FactKind.general, String? value}) async {
    if (!await _settings.isLongTermMemoryOn()) return false;
    final text = content.trim();
    if (text.isEmpty) return false;
    final db = await ZoeDatabase.instance.database;
    final rows = await db.query(_table, columns: ['content', 'kind', 'value']);
    for (final row in rows) {
      final rowKind = FactKind.fromDb(row['kind'] as String?);
      if (kind.single) {
        if (rowKind == kind && row['value'] == value) return true;
        continue;
      }
      if (!rowKind.single && MemoryRules.sameWords(row['content'] as String, text)) return true;
    }
    return false;
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

  /// Level 3: nickname, style, stress help, wins, routines.
  /// OFF ang long-term memory → [CompanionProfile.empty] (hindi ginagamit).
  Future<CompanionProfile> profile() async {
    if (!await _settings.isLongTermMemoryOn()) return CompanionProfile.empty;
    return CompanionProfile.from(await getAll());
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