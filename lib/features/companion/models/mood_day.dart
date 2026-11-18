import 'package:zoe_remind/features/companion/models/mood_state.dart';

/// Larawan ng araw ngayon, galing sa database (Personality plan, P2b).
/// Ginagawa ito ng MoodController; PURE data lang ito para madaling i-test.
class DaySnapshot {
  /// Petsa ngayon (yyyy-MM-dd).
  final String day;

  /// Ilang reminder + task ngayong araw (hindi kasama ang na-Dismiss).
  final int itemsToday;

  /// Ilan sa [itemsToday] ang tapos na.
  final int doneToday;

  /// Ilang reminder / task ngayong araw ang lumipas na ang oras at hindi tapos.
  final int missedToday;

  /// Ilang task (kahit anong araw) ang lumampas na sa oras at hindi pa tapos.
  final int overdueTasks;

  /// Sunod-sunod na araw na may natapos (StatisticsRepository.dayStreak).
  final int streak;

  /// May natapos ba NGAYONG araw? (Para hindi mag-celebrate ng streak
  /// na kahapon pa naabot.)
  final bool completedToday;

  const DaySnapshot({
    required this.day,
    this.itemsToday = 0,
    this.doneToday = 0,
    this.missedToday = 0,
    this.overdueTasks = 0,
    this.streak = 0,
    this.completedToday = false,
  });

  /// Tapos lahat ngayong araw (at may laman ang araw).
  bool get allDone => itemsToday > 0 && doneToday >= itemsToday;
}

/// Ano na ang "nakita" na ni Zoe ngayong araw — para isang beses lang
/// siyang mag-react sa bawat bagong na-miss / overdue, kahit ilang beses
/// pa i-check ang database.
class MoodSeen {
  /// Petsa (yyyy-MM-dd) ng mga bilang sa ibaba. Ibang araw → reset.
  final String day;
  final int missed;
  final int overdue;

  const MoodSeen({this.day = '', this.missed = 0, this.overdue = 0});

  @override
  bool operator ==(Object other) =>
      other is MoodSeen &&
      other.day == day &&
      other.missed == missed &&
      other.overdue == overdue;

  @override
  int get hashCode => Object.hash(day, missed, overdue);

  @override
  String toString() => 'MoodSeen($day, missed=$missed, overdue=$overdue)';
}

/// PURE rules: (larawan ng araw, nakita na) → (mga event, bagong nakita).
/// Walang database dito, kaya kayang i-test nang walang phone.
class MoodRules {
  MoodRules._();

  static (List<ZoeEvent>, MoodSeen) eventsFor(DaySnapshot snap, MoodSeen seen) {
    // Bagong araw → magsisimula ulit sa 0 ang bilang.
    final base = seen.day == snap.day ? seen : MoodSeen(day: snap.day);
    final events = <ZoeEvent>[];

    // May BAGONG na-miss (hindi pa nakita) → gentle. Isang event lang
    // kahit ilan ang sabay-sabay na na-miss.
    if (snap.missedToday > base.missed) {
      events.add(const ReminderMissed());
    }

    // Dumami ang overdue → ipaalam sa engine (gentle kapag 3 o higit pa).
    if (snap.overdueTasks > base.overdue) {
      events.add(OverdueTasks(snap.overdueTasks));
    }

    // Celebration. Ang MoodEngine na ang bahala na isang beses lang kada araw,
    // at na hindi ito mananalo sa gentle.
    if (snap.allDone) {
      events.add(const AllTasksDone());
    }
    if (snap.completedToday && snap.streak > 0) {
      events.add(StreakReached(snap.streak));
    }

    // Ang bagong "nakita" = kasalukuyang bilang. Kapag bumaba (hal. minark
    // as done nang late) at may na-miss ulit, mapapansin pa rin.
    final next = MoodSeen(
      day: snap.day,
      missed: snap.missedToday,
      overdue: snap.overdueTasks,
    );
    return (events, next);
  }
}