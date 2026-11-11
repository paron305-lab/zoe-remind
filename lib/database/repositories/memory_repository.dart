import 'package:flutter/foundation.dart';
import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/models/memory_item.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';

/// Ang tanging nagbabasa/nagsusulat ng memories table (long-term memory ni Zoe).
/// Memory Engine / RAG (later) → add(). Settings → list, delete, clearAll().
class MemoryRepository {
  MemoryRepository({SettingsRepository? settings})
      : _settings = settings ?? SettingsRepository();

  static const _table = StorageConstants.memoriesTable;
  static final changes = ValueNotifier<int>(0);

  final SettingsRepository _settings;

  String _now() => DateTime.now().toIso8601String();

  /// Nagsasave lang kapag ON ang long-term memory sa Settings.
  /// Returns null kapag OFF (walang na-save).
  Future<int?> add(String content, {String source = 'chat', int importance = 3}) async {
    if (!await _settings.isLongTermMemoryOn()) return null;
    final text = content.trim();
    if (text.isEmpty) return null;
    final db = await ZoeDatabase.instance.database;
    final now = _now();
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