import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/database/models/reminder.dart';
import 'package:zoe_remind/features/reminders/services/reminder_alarm_service.dart';

/// Takbuhin:  flutter test test/reminders/reminder_repeat_test.dart
///
/// A5: monthly reminder sa 29–31 (katapusan, sweldo) → tutunog sa HULING araw
/// ng mas maikling buwan, hindi nilalaktawan ang buwan.
void main() {
  Reminder monthly(String date) => Reminder(
        id: 1,
        title: 'Sweldo',
        date: date,
        time: '09:00',
        repeat: ReminderRepeat.monthly,
        createdAt: '2026-01-01T08:00:00.000',
        updatedAt: '2026-01-01T08:00:00.000',
      );

  /// Mga araw sa [year]-[month] na tutunog ang reminder.
  List<int> daysIn(Reminder r, int year, int month) {
    final last = DateTime(year, month + 1, 0).day;
    return [
      for (var d = 1; d <= last; d++)
        if (r.occursOn(DateTime(year, month, d))) d,
    ];
  }

  test('31 → huling araw ng bawat buwan', () {
    final r = monthly('2026-01-31');
    expect(daysIn(r, 2026, 1), [31]);
    expect(daysIn(r, 2026, 2), [28]);
    expect(daysIn(r, 2026, 3), [31]);
    expect(daysIn(r, 2026, 4), [30]);
    expect(daysIn(r, 2026, 6), [30]);
    expect(daysIn(r, 2026, 9), [30]);
    expect(daysIn(r, 2026, 11), [30]);
    expect(daysIn(r, 2026, 12), [31]);
  });

  test('leap year: Feb 29', () {
    expect(daysIn(monthly('2027-12-31'), 2028, 2), [29]);
    expect(daysIn(monthly('2027-12-30'), 2028, 2), [29]);
    expect(daysIn(monthly('2027-12-29'), 2028, 2), [29]);
    expect(daysIn(monthly('2026-01-29'), 2026, 2), [28]);
  });

  test('30 → Feb 28, pero 30 pa rin sa ibang buwan (hindi 31)', () {
    final r = monthly('2026-01-30');
    expect(daysIn(r, 2026, 2), [28]);
    expect(daysIn(r, 2026, 3), [30]);
    expect(daysIn(r, 2026, 4), [30]);
  });

  test('karaniwang araw — walang nagbago', () {
    final r = monthly('2026-01-15');
    for (var m = 1; m <= 12; m++) {
      expect(daysIn(r, 2026, m), [15], reason: 'month $m');
    }
  });

  test('hindi tumutunog bago ang unang araw', () {
    final r = monthly('2026-03-31');
    expect(daysIn(r, 2026, 2), isEmpty);
  });

  test('susunod na alarm ng "31" pagkatapos ng Jan 31 → Feb 28', () {
    final r = monthly('2026-01-31');
    final next = ReminderAlarmService.nextFireTime(r, from: DateTime(2026, 1, 31, 10, 0));
    expect(next, DateTime(2026, 2, 28, 9, 0));
  });
}