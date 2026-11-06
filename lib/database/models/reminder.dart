import 'package:zoe_remind/core/utils/zoe_date.dart';

enum ReminderRepeat { none, daily, weekly, monthly }

class Reminder {
  final int? id;
  final String title;

  /// First (or only) day, 'yyyy-MM-dd'
  final String date;

  /// 'HH:mm' 24h
  final String time;
  final ReminderRepeat repeat;

  /// 'pending' or 'done' (for one-time reminders)
  final String status;

  /// Day this reminder was last ticked off, 'yyyy-MM-dd'.
  /// Lets repeating reminders be "done for today" and fresh again tomorrow.
  final String? lastDoneDate;

  /// 'not_scheduled' for now — the notification step will update this.
  final String notificationState;
  final String createdAt;
  final String updatedAt;
  final String? completedAt;

  const Reminder({
    this.id,
    required this.title,
    required this.date,
    required this.time,
    this.repeat = ReminderRepeat.none,
    this.status = 'pending',
    this.lastDoneDate,
    this.notificationState = 'not_scheduled',
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  /// Copy with some fields changed. Use the clear… flags to set a field to null.
  Reminder copyWith({
    String? title,
    String? date,
    String? time,
    ReminderRepeat? repeat,
    String? status,
    String? lastDoneDate,
    bool clearLastDoneDate = false,
    String? updatedAt,
    String? completedAt,
    bool clearCompletedAt = false,
  }) =>
      Reminder(
        id: id,
        title: title ?? this.title,
        date: date ?? this.date,
        time: time ?? this.time,
        repeat: repeat ?? this.repeat,
        status: status ?? this.status,
        lastDoneDate: clearLastDoneDate ? null : (lastDoneDate ?? this.lastDoneDate),
        notificationState: notificationState,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'date': date,
        'time': time,
        'repeat': repeat.name,
        'status': status,
        'last_done_date': lastDoneDate,
        'notification_state': notificationState,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'completed_at': completedAt,
      };

  factory Reminder.fromMap(Map<String, Object?> m) => Reminder(
        id: m['id'] as int?,
        title: m['title'] as String,
        date: m['date'] as String,
        time: m['time'] as String,
        repeat: ReminderRepeat.values.firstWhere(
          (r) => r.name == m['repeat'],
          orElse: () => ReminderRepeat.none,
        ),
        status: (m['status'] as String?) ?? 'pending',
        lastDoneDate: m['last_done_date'] as String?,
        notificationState: (m['notification_state'] as String?) ?? 'not_scheduled',
        createdAt: m['created_at'] as String,
        updatedAt: m['updated_at'] as String,
        completedAt: m['completed_at'] as String?,
      );

  /// Deterministic recurrence check — does this reminder happen on [day]?
  bool occursOn(DateTime day) {
    final start = ZoeDate.parseKey(date);
    final d = ZoeDate.dayOnly(day);
    if (d.isBefore(start)) return false;
    return switch (repeat) {
      ReminderRepeat.none => ZoeDate.sameDay(d, start),
      ReminderRepeat.daily => true,
      ReminderRepeat.weekly => d.weekday == start.weekday,
      ReminderRepeat.monthly => d.day == start.day,
    };
  }

  bool isDoneOn(DateTime day) => lastDoneDate == ZoeDate.key(day);
}