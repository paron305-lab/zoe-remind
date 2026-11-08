import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/models/task.dart';

enum TaskFilter {
  all('All'),
  today('Today'),
  upcoming('Upcoming'),
  done('Done');

  final String label;
  const TaskFilter(this.label);
}

/// A day section on the Tasks screen ("TODAY", "TOMORROW", ...).
class TaskGroup {
  final String label;
  final List<Task> tasks;

  /// Coral header for missed tasks.
  final bool warn;

  /// Show the date on each card (sections that mix several days).
  final bool showDate;

  const TaskGroup(this.label, this.tasks, {this.warn = false, this.showDate = false});
}

/// Pure functions: filter, search, group. No Flutter widgets, no database,
/// so everything here is easy to unit-test.
class TaskListLogic {
  TaskListLogic._();

  /// [categoryLabel] = pangalan ng category ng task (para ma-search din ito).
  static bool matches(Task t, String query, {String Function(String key)? categoryLabel}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final cat = categoryLabel?.call(t.category) ?? t.category;
    return t.title.toLowerCase().contains(q) ||
        (t.description?.toLowerCase().contains(q) ?? false) ||
        cat.toLowerCase().contains(q);
  }

  /// Today  = due today + anything still missed from earlier days.
  /// Upcoming = not done, due after today, plus "Someday" tasks.
  static List<Task> applyFilter(List<Task> tasks, TaskFilter filter, DateTime now,
      {String query = '', String Function(String key)? categoryLabel}) {
    final today = ZoeDate.dayOnly(now);
    bool keep(Task t) {
      final day = t.day;
      return switch (filter) {
        TaskFilter.all => true,
        TaskFilter.today => day != null &&
            (ZoeDate.sameDay(day, today) || (!t.isDone && day.isBefore(today))),
        TaskFilter.upcoming => !t.isDone && (day == null || day.isAfter(today)),
        TaskFilter.done => t.isDone,
      };
    }

    return tasks
        .where((t) => keep(t) && matches(t, query, categoryLabel: categoryLabel))
        .toList();
  }

  static List<TaskGroup> group(List<Task> tasks, TaskFilter filter, DateTime now) {
    return filter == TaskFilter.done ? _groupDone(tasks, now) : _groupByDay(tasks, now);
  }

  static List<TaskGroup> _groupByDay(List<Task> tasks, DateTime now) {
    final today = ZoeDate.dayOnly(now);
    final tomorrow = today.add(const Duration(days: 1));

    final missed = <Task>[]; // not done, date already passed
    final earlier = <Task>[]; // done, date already passed
    final someday = <Task>[];
    final byDay = <DateTime, List<Task>>{};

    for (final t in tasks) {
      final day = t.day;
      if (day == null) {
        someday.add(t);
      } else if (day.isBefore(today)) {
        (t.isDone ? earlier : missed).add(t);
      } else {
        byDay.putIfAbsent(day, () => []).add(t);
      }
    }

    final groups = <TaskGroup>[];
    if (missed.isNotEmpty) {
      groups.add(TaskGroup('Missed', _sortByDateTime(missed), warn: true, showDate: true));
    }
    for (final day in byDay.keys.toList()..sort()) {
      final label = ZoeDate.sameDay(day, today)
          ? 'Today'
          : ZoeDate.sameDay(day, tomorrow)
              ? 'Tomorrow'
              : '${ZoeDate.weekday(day)} · ${ZoeDate.short(day)}';
      groups.add(TaskGroup(label, _sortByDateTime(byDay[day]!)));
    }
    if (someday.isNotEmpty) groups.add(TaskGroup('Someday', _sortByDateTime(someday)));
    if (earlier.isNotEmpty) {
      groups.add(TaskGroup('Earlier', _sortByDateTime(earlier).reversed.toList(),
          showDate: true));
    }
    return groups;
  }

  /// Done tab: grouped by the day it was finished, newest first.
  static List<TaskGroup> _groupDone(List<Task> tasks, DateTime now) {
    final today = ZoeDate.dayOnly(now);
    final byDay = <DateTime, List<Task>>{};
    for (final t in tasks) {
      final at = t.completedAtTime ?? DateTime.tryParse(t.createdAt) ?? now;
      byDay.putIfAbsent(ZoeDate.dayOnly(at), () => []).add(t);
    }

    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final day in days)
        TaskGroup(
          switch (today.difference(day).inDays) {
            0 => 'Finished today',
            1 => 'Finished yesterday',
            _ => 'Finished ${ZoeDate.short(day)}',
          },
          byDay[day]!
            ..sort((a, b) => (b.completedAt ?? '').compareTo(a.completedAt ?? '')),
          showDate: true,
        ),
    ];
  }

  /// Sort by date, then time (tasks without a time go last), then creation.
  static List<Task> _sortByDateTime(List<Task> list) {
    int cmp(String? a, String? b) {
      if (a == b) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return a.compareTo(b);
    }

    return list
      ..sort((a, b) {
        final byDate = cmp(a.date, b.date);
        if (byDate != 0) return byDate;
        final byTime = cmp(a.time, b.time);
        if (byTime != 0) return byTime;
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  /// Tasks due this week (Monday–Sunday): how many are still open.
  static ({int left, int total}) weekSummary(List<Task> tasks, DateTime now) {
    final today = ZoeDate.dayOnly(now);
    final monday = today.subtract(Duration(days: today.weekday - DateTime.monday));
    final nextMonday = monday.add(const Duration(days: 7));

    var total = 0;
    var left = 0;
    for (final t in tasks) {
      final day = t.day;
      if (day == null || day.isBefore(monday) || !day.isBefore(nextMonday)) continue;
      total++;
      if (!t.isDone) left++;
    }
    return (left: left, total: total);
  }

  static String weekSummaryText(({int left, int total}) s) {
    if (s.total == 0) return 'Nothing planned this week';
    if (s.left == 0) return 'All ${s.total} done this week';
    return '${s.left} of ${s.total} left this week';
  }
}