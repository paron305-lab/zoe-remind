import 'package:flutter/material.dart';

/// Small date/time helpers so we don't need the intl package.
/// Storage format: date = 'yyyy-MM-dd', time = 'HH:mm' (24h).
class ZoeDate {
  ZoeDate._();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// 2026-09-20
  static String key(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  /// 19:00
  static String timeKey(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';

  static DateTime parseKey(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  static TimeOfDay parseTime(String s) {
    final p = s.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  /// Midnight of the given day (drops the time part).
  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Sep 20, 2026
  static String pretty(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

  /// Sep 20
  static String short(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  /// Monday
  static String weekday(DateTime d) => _weekdays[d.weekday - 1];

  /// 7:00 PM
  static String prettyTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    return '$h:${_two(t.minute)} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  /// "Today" / "Tomorrow" / "Sep 20"
  static String relative(DateTime d) {
    final today = dayOnly(DateTime.now());
    final diff = dayOnly(d).difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return short(d);
  }

  static DateTime combine(DateTime day, TimeOfDay t) =>
      DateTime(day.year, day.month, day.day, t.hour, t.minute);
}