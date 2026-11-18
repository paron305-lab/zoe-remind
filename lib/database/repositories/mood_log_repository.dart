import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/features/companion/models/mood_week.dart';
import 'package:zoe_remind/features/companion/models/user_tone.dart';

/// Ang tanging nagbabasa / nagsusulat sa `mood_log` table (Level 2).
///
/// Isang row kada (araw, tone): ilang beses napansin ni Zoe na pagod,
/// stressed, masaya… ang user sa araw na iyon.
/// BILANG LANG — hindi sine-save ang mensahe ng user.
class MoodLogRepository {
  static const _table = StorageConstants.moodLogTable;

  /// +1 sa (day, tone). Walang row pa → gagawa ng bago.
  /// (UPDATE muna, saka INSERT — gumagana kahit sa lumang SQLite ng Android.)
  Future<void> add(String day, UserTone tone, DateTime now) async {
    if (tone == UserTone.neutral) return;
    final db = await ZoeDatabase.instance.database;
    final stamp = now.toIso8601String();
    await db.transaction((txn) async {
      final changed = await txn.rawUpdate(
        'UPDATE $_table SET count = count + 1, updated_at = ? WHERE day = ? AND tone = ?',
        [stamp, day, tone.name],
      );
      if (changed == 0) {
        await txn.insert(_table, {
          'day': day,
          'tone': tone.name,
          'count': 1,
          'updated_at': stamp,
        });
      }
    });
  }

  /// Lahat ng row mula sa [fromDay] ('yyyy-MM-dd') pataas.
  Future<List<MoodLogEntry>> since(String fromDay) async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.query(
      _table,
      where: 'day >= ?',
      whereArgs: [fromDay],
      orderBy: 'day ASC',
    );
    return [
      for (final row in rows)
        if (MoodLogEntry.fromRow(row) case final entry?) entry,
    ];
  }

  /// Burahin ang mas luma kaysa [day]. (Ang 'yyyy-MM-dd' ay tama ang
  /// pagkakasunod kahit string ang compare.)
  Future<int> pruneBefore(String day) async {
    final db = await ZoeDatabase.instance.database;
    return db.delete(_table, where: 'day < ?', whereArgs: [day]);
  }

  /// Settings › "Burahin lahat".
  Future<void> clearAll() async {
    final db = await ZoeDatabase.instance.database;
    await db.delete(_table);
  }
}