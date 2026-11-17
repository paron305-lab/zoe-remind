import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/models/task.dart';

/// Paano igugrupo ang bilang: kada araw, buwan, o taon.
/// Ang numero = haba ng susi na kinukuha sa petsa ('2026-09-20' → 10/7/4).
enum StatsGroup {
  day(10),
  month(7),
  year(4);

  final int keyLength;
  const StatsGroup(this.keyLength);
}

/// Lahat ng bilang para sa isang panahon, naka-grupo ayon sa susi.
/// Susi: '2026-09-20' (day), '2026-09' (month), '2026' (year).
class StatsBuckets {
  /// Natapos na task (completion_history, item_type = 'task').
  final Map<String, int> tasksDone;

  /// Task na hindi pa tapos (tasks.status != 'done').
  /// Petsa = tasks.date, o created_at kung "Someday".
  final Map<String, int> tasksOpen;

  /// Reminder na tumunog / na-handle (reminder_occurrences: done/dismissed/missed).
  final Map<String, int> reminders;

  /// Bagong notes (notes.created_at).
  final Map<String, int> notes;

  /// Mensahe ng user kay Zoe (ai_messages, role = 'user').
  final Map<String, int> chats;

  /// Na-miss na reminders + tasks.
  final Map<String, int> missed;

  const StatsBuckets({
    required this.tasksDone,
    required this.tasksOpen,
    required this.reminders,
    required this.notes,
    required this.chats,
    required this.missed,
  });

  static int sum(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);

  int get totalTasksDone => sum(tasksDone);
  int get totalTasksOpen => sum(tasksOpen);
  int get totalTasks => totalTasksDone + totalTasksOpen;
  int get totalReminders => sum(reminders);
  int get totalNotes => sum(notes);
  int get totalChats => sum(chats);
  int get totalMissed => sum(missed);

  /// Activities = tasks + reminders + notes + Zoe chats.
  /// (Hindi kasama ang missed — bahagi na sila ng tasks / reminders.)
  int activitiesFor(String key) =>
      (tasksDone[key] ?? 0) +
      (tasksOpen[key] ?? 0) +
      (reminders[key] ?? 0) +
      (notes[key] ?? 0) +
      (chats[key] ?? 0);

  /// Lahat ng susi na may kahit isang activity.
  Set<String> get activityKeys => {
        ...tasksDone.keys,
        ...tasksOpen.keys,
        ...reminders.keys,
        ...notes.keys,
        ...chats.keys,
      };

  int get totalActivities =>
      totalTasks + totalReminders + totalNotes + totalChats;
}

/// Read-only. Bumibilang mula sa SQLite para sa History screen
/// ("See all" sa Home) at sa day streak.
class StatisticsRepository {
  static const _tasks = StorageConstants.tasksTable;
  static const _history = StorageConstants.completionHistoryTable;
  static const _occ = StorageConstants.reminderOccurrencesTable;
  static const _taskHistory = StorageConstants.taskHistoryTable;
  static const _notes = StorageConstants.notesTable;
  static const _messages = StorageConstants.messagesTable;

  /// Bilang mula [from] (kasama) hanggang [to] (HINDI kasama), parehong hatinggabi.
  ///
  /// Gumagana ang string compare dahil pareho ang simula ng format:
  /// 'yyyy-MM-dd' (date/day) at 'yyyy-MM-ddTHH:mm:ss' (ISO timestamps).
  Future<StatsBuckets> load({
    required DateTime from,
    required DateTime to,
    required StatsGroup group,
  }) async {
    final db = await ZoeDatabase.instance.database;
    final n = group.keyLength;
    final args = [ZoeDate.key(from), ZoeDate.key(to)];

    Future<Map<String, int>> grouped(String column, String table,
        [String extraWhere = '', List<Object?> extraArgs = const []]) async {
      final rows = await db.rawQuery(
        'SELECT substr($column, 1, $n) AS k, COUNT(*) AS c FROM $table '
        'WHERE $column IS NOT NULL AND $column >= ? AND $column < ? $extraWhere '
        'GROUP BY k',
        [...args, ...extraArgs],
      );
      return {
        for (final r in rows)
          if (r['k'] != null) r['k'] as String: (r['c'] as int?) ?? 0,
      };
    }

    final tasksDone = await grouped('completed_at', _history, "AND item_type = 'task'");
    final tasksOpen = await grouped(
        'COALESCE(date, created_at)', _tasks, 'AND status != ?', [Task.statusDone]);
    final reminders = await grouped('day', _occ);
    final notes = await grouped('created_at', _notes);
    final chats = await grouped('created_at', _messages, "AND role = 'user'");
    final missedReminders = await grouped('day', _occ, "AND status = 'missed'");
    final missedTasks = await grouped('day', _taskHistory, "AND status = 'missed'");

    final missed = <String, int>{...missedReminders};
    missedTasks.forEach((k, v) => missed[k] = (missed[k] ?? 0) + v);

    return StatsBuckets(
      tasksDone: tasksDone,
      tasksOpen: tasksOpen,
      reminders: reminders,
      notes: notes,
      chats: chats,
      missed: missed,
    );
  }

  /// Pinakaunang araw na may kahit anong record. null = wala pang data.
  Future<DateTime?> earliestDay() async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT MIN(d) AS d FROM (
        SELECT MIN(completed_at) AS d FROM $_history
        UNION ALL SELECT MIN(COALESCE(date, created_at)) FROM $_tasks
        UNION ALL SELECT MIN(day) FROM $_occ
        UNION ALL SELECT MIN(created_at) FROM $_notes
        UNION ALL SELECT MIN(created_at) FROM $_messages
      )
    ''');
    final d = rows.first['d'] as String?;
    if (d == null || d.length < 10) return null;
    try {
      return ZoeDate.parseKey(d.substring(0, 10));
    } catch (_) {
      return null;
    }
  }

  /// Ilang sunod-sunod na araw na may natapos (task o reminder).
  /// Buhay pa ang streak kung wala pang natapos ngayon pero meron kahapon.
  Future<int> dayStreak({DateTime? now}) async {
    final today = ZoeDate.dayOnly(now ?? DateTime.now());
    final since = today.subtract(const Duration(days: 400));
    final db = await ZoeDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT substr(completed_at, 1, 10) AS d FROM $_history '
      'WHERE completed_at >= ?',
      [ZoeDate.key(since)],
    );
    final days = {for (final r in rows) r['d'] as String};

    var day = today;
    if (!days.contains(ZoeDate.key(day))) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    var streak = 0;
    while (days.contains(ZoeDate.key(day))) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }
}