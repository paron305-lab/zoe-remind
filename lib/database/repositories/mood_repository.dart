import 'package:sqflite/sqflite.dart';
import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/features/companion/models/mood_day.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';

/// Ang tanging nagbabasa / nagsusulat sa `zoe_mood` table (P2b).
/// Isang row lang: ang mood ni Zoe ngayon + ang "nakita" na niya ngayong araw.
class MoodRepository {
  static const _table = StorageConstants.moodTable;
  static const _history = StorageConstants.completionHistoryTable;

  /// null = wala pang naka-save (bagong install / bagong update).
  Future<(ZoeMood, MoodSeen)?> load() async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.query(_table, where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    return fromRow(rows.first);
  }

  Future<void> save(ZoeMood mood, MoodSeen seen) async {
    final db = await ZoeDatabase.instance.database;
    await db.insert(
      _table,
      toRow(mood, seen, DateTime.now()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Para sa Developer › "Reset mood".
  Future<void> clear() async {
    final db = await ZoeDatabase.instance.database;
    await db.delete(_table);
  }

  // ─────────────── basa lang sa completion_history ───────────────

  /// Ilan ang natapos (task + reminder) sa araw na [dayKey] (yyyy-MM-dd).
  Future<int> completionsOn(String dayKey) async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM $_history WHERE substr(completed_at, 1, 10) = ?',
      [dayKey],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Ilang beses nang may reminder na na-Done, kahit kailan.
  /// 1 = ito ang kauna-unahan → FirstReminderDone.
  Future<int> reminderCompletionsEver() async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS n FROM $_history WHERE item_type = 'reminder'",
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  // ───────────── row ↔ ZoeMood (pure, may test) ─────────────

  /// ZoeMood → row. Hindi sine-save ang `focused` (ilang segundo lang iyon,
  /// habang nag-iisip si Zoe): ang mood BAGO siya nag-isip ang sine-save.
  static Map<String, Object?> toRow(ZoeMood mood, MoodSeen seen, DateTime now) {
    final m = (mood.state == MoodState.focused && mood.previous != null)
        ? mood.previous!.copyWith(
            celebrated: mood.celebrated,
            celebratedOn: mood.celebratedOn,
          )
        : mood;
    final state = m.state == MoodState.focused ? MoodState.content : m.state;
    return {
      'id': 1,
      'state': state.name,
      'intensity': m.intensity,
      'since': m.since.toIso8601String(),
      'reason': m.reason,
      'celebrated': (m.celebrated.toList()..sort()).join(','),
      'celebrated_on': m.celebratedOn,
      'seen_day': seen.day,
      'seen_missed': seen.missed,
      'seen_overdue': seen.overdue,
      'updated_at': now.toIso8601String(),
    };
  }

  /// Row → ZoeMood. Kapag sira / hindi kilala ang value, ligtas na default.
  static (ZoeMood, MoodSeen) fromRow(Map<String, Object?> row) {
    final name = row['state'] as String? ?? '';
    final state = MoodState.values.firstWhere(
      (s) => s.name == name,
      orElse: () => MoodState.content,
    );
    final since = DateTime.tryParse(row['since'] as String? ?? '') ?? DateTime.now();
    final celebratedText = row['celebrated'] as String? ?? '';
    final mood = ZoeMood(
      state: state == MoodState.focused ? MoodState.content : state,
      intensity: ((row['intensity'] as int?) ?? 0).clamp(0, 3),
      since: since,
      reason: row['reason'] as String? ?? '',
      celebrated: {
        for (final c in celebratedText.split(','))
          if (c.trim().isNotEmpty) c.trim(),
      },
      celebratedOn: row['celebrated_on'] as String? ?? '',
    );
    final seen = MoodSeen(
      day: row['seen_day'] as String? ?? '',
      missed: (row['seen_missed'] as int?) ?? 0,
      overdue: (row['seen_overdue'] as int?) ?? 0,
    );
    return (mood, seen);
  }
}