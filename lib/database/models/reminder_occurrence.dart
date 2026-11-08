/// Ano ang nangyari sa isang reminder sa isang araw.
enum OccurrenceStatus { done, dismissed, missed }

/// Isang row ng reminder_occurrences: isang araw ng isang reminder.
/// Permanente ito — hindi napapalitan bukas, hindi nabubura kapag
/// na-delete ang reminder. Dito babasa ang History / Memory Engine.
class ReminderOccurrence {
  final int? id;
  final int reminderId;

  /// Snapshot ng title noong araw na iyon.
  final String title;

  /// Araw ng occurrence, 'yyyy-MM-dd'.
  final String day;

  /// Oras ng occurrence, 'HH:mm'.
  final String time;
  final OccurrenceStatus status;

  /// Kailan ito na-record (ISO 8601).
  final String recordedAt;

  const ReminderOccurrence({
    this.id,
    required this.reminderId,
    required this.title,
    required this.day,
    required this.time,
    required this.status,
    required this.recordedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'reminder_id': reminderId,
        'title': title,
        'day': day,
        'time': time,
        'status': status.name,
        'recorded_at': recordedAt,
      };

  factory ReminderOccurrence.fromMap(Map<String, Object?> m) => ReminderOccurrence(
        id: m['id'] as int?,
        reminderId: m['reminder_id'] as int,
        title: m['title'] as String,
        day: m['day'] as String,
        time: m['time'] as String,
        status: OccurrenceStatus.values.firstWhere(
          (s) => s.name == m['status'],
          orElse: () => OccurrenceStatus.missed,
        ),
        recordedAt: m['recorded_at'] as String,
      );
}