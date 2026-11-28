import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';

/// "Burahin lahat ng data" — ang database na bahagi lang.
///
/// BINUBURA (data ng user):
///   tasks, task_history, completion_history,
///   reminders, reminder_occurrences,
///   notes (+ notes_fts), ai_conversations + ai_messages,
///   memories (+ memories_fts), zoe_mood, mood_log,
///   R6: search_log, learned_terms, search_feedback (natutunan ni Zoe),
///   sariling task categories (babalik ang 7 default),
///   settings na galing sa gamit ng user (mood log noted, habit suggestions,
///   missed scan).
///
/// HINDI ginagalaw (para manatili sa Home, hindi onboarding):
///   user_profile (pangalan), model_state (na-download na Qwen),
///   at settings ng app (language, dark mode, alarm sound, toggles…).
///
/// Ang alarms at ang mga controller sa memory ay nasa [DataWipe]
/// (lib/core/services/data_wipe.dart). Ito ay puro database para ma-test sa PC.
class WipeRepository {
  /// Mga table na buong binubura. Pagkakasunod: anak muna bago magulang.
  static const userTables = [
    StorageConstants.messagesTable,
    StorageConstants.conversationsTable,
    StorageConstants.reminderOccurrencesTable,
    StorageConstants.remindersTable,
    StorageConstants.taskHistoryTable,
    StorageConstants.completionHistoryTable,
    StorageConstants.tasksTable,
    StorageConstants.taskCategoriesTable,
    StorageConstants.notesTable,
    StorageConstants.memoriesTable,
    StorageConstants.moodTable,
    StorageConstants.moodLogTable,
    // R6: natutunan ni Zoe (mga tanong sa chat, salita, feedback).
    StorageConstants.searchLogTable,
    StorageConstants.learnedTermsTable,
    StorageConstants.searchFeedbackTable,
  ];

  /// Search index (FTS4). Kusang nabubura ng triggers, pero binubura rin
  /// nang direkta para siguradong walang matira (hal. index na hindi tugma).
  static const ftsTables = [
    StorageConstants.notesFtsTable,
    StorageConstants.memoriesFtsTable,
  ];

  /// Settings keys na galing sa gamit ng user (eksakto).
  static const userSettingKeys = [
    'mood_log_noted_on',
    'occurrences_scanned_until',
    // Level 3: naitanong na ba ang "Kapag stressed ka, ano'ng nakakatulong?"
    'companion_help_asked',
  ];

  /// Settings keys na nagsisimula sa mga ito (hal. habit_suggest_study).
  static const userSettingPrefixes = ['habit_suggest_'];

  /// Burahin lahat ng data ng user. Isang transaction: lahat o wala.
  /// Pagkatapos: VACUUM para lumiit ang file at walang matirang lumang laman.
  Future<void> wipeUserData() async {
    final db = await ZoeDatabase.instance.database;
    final existing = await _tableNames(db);

    await db.transaction((txn) async {
      for (final table in userTables) {
        if (existing.contains(table)) await txn.delete(table);
      }
      for (final fts in ftsTables) {
        if (existing.contains(fts)) await txn.execute('DELETE FROM $fts');
      }
      for (final key in userSettingKeys) {
        await txn.delete('settings', where: 'key = ?', whereArgs: [key]);
      }
      for (final prefix in userSettingPrefixes) {
        await txn.delete('settings', where: 'key LIKE ?', whereArgs: ['$prefix%']);
      }
      // Babalik ang 7 default categories (Study, Thesis, Work…).
      await ZoeDatabase.seedTaskCategories(txn);
    });

    // Sa labas ng transaction (bawal ang VACUUM sa loob).
    // Kapag pumalya, burado pa rin ang data — mas malaki lang ang file.
    for (final fts in ftsTables) {
      if (!existing.contains(fts)) continue;
      try {
        await db.execute("INSERT INTO $fts($fts) VALUES('optimize')");
      } catch (e) {
        debugPrint('FTS optimize failed ($fts): $e');
      }
    }
    try {
      await db.execute('VACUUM');
    } catch (e) {
      debugPrint('VACUUM failed: $e');
    }
  }

  /// Bilang ng rows sa bawat table ng user — para sa test at Developer screen.
  /// 0 lahat (maliban sa task_categories = 7) = malinis.
  Future<Map<String, int>> counts() async {
    final db = await ZoeDatabase.instance.database;
    final existing = await _tableNames(db);
    final out = <String, int>{};
    for (final table in [...userTables, ...ftsTables]) {
      if (!existing.contains(table)) continue;
      final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM $table');
      out[table] = (rows.first['n'] as int?) ?? 0;
    }
    return out;
  }

  /// Developer: naka-ON ba ang secure_delete sa connection na ito.
  Future<bool> secureDeleteOn() async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.rawQuery('PRAGMA secure_delete');
    return rows.isNotEmpty && rows.first.values.first == 1;
  }

  static Future<Set<String>> _tableNames(DatabaseExecutor db) async {
    final rows = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
    return rows.map((r) => r['name'] as String).toSet();
  }
}