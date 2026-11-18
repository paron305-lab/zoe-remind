import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/features/companion/models/user_tone.dart';

/// Ano ang "dating" ng linggo ng user, ayon sa mood log (Level 2).
///
///  • busy  — ilang araw nang pagod / stressed
///  • heavy — ilang araw nang malungkot / inis / kabado
///  • good  — ilang araw nang masaya
enum WeekVibe { busy, heavy, good }

/// Isang row sa `mood_log`: ilang beses lumabas ang [tone] sa araw na [day].
/// Bilang lang — walang mensahe, walang text ng user.
class MoodLogEntry {
  const MoodLogEntry(this.day, this.tone, this.count);

  /// 'yyyy-MM-dd'
  final String day;
  final UserTone tone;
  final int count;

  /// Row → entry. Hindi kilala / sira ang tone → null (nilalaktawan).
  static MoodLogEntry? fromRow(Map<String, Object?> row) {
    final day = row['day'] as String? ?? '';
    final name = row['tone'] as String? ?? '';
    final count = (row['count'] as int?) ?? 0;
    final tone = UserTone.values.asNameMap()[name];
    if (day.isEmpty || tone == null || tone == UserTone.neutral || count <= 0) return null;
    return MoodLogEntry(day, tone, count);
  }

  @override
  String toString() => 'MoodLogEntry($day, ${tone.name}, $count)';
}

/// Buod ng huling 7 araw (Level 2). PURE — walang database, may test.
///
/// Rules:
///  • Today + 6 na araw bago nito lang ang binibilang.
///  • Kailangan ng 3 magkakaibang araw bago may masabi si Zoe
///    (isang masamang araw ≠ masamang linggo).
///  • Hindi ito diagnosis. Bilang lang para piliin ang tamang salita.
class MoodWeek {
  const MoodWeek._(this.counts, this.downDays, this.happyDays);

  /// Ilang araw ang itinatago (kasama ang ngayon).
  static const keepDays = 7;

  /// Ilang magkakaibang araw bago magsalita si Zoe tungkol sa linggo.
  static const minDays = 3;

  static const empty = MoodWeek._(<UserTone, int>{}, 0, 0);

  /// Bilang kada tone sa huling 7 araw.
  final Map<UserTone, int> counts;

  /// Ilang magkakaibang araw na may pagod / stressed / malungkot / inis / kabado.
  final int downDays;

  /// Ilang magkakaibang araw na may masaya.
  final int happyDays;

  /// Ang pinakaunang araw na binibilang. Ang mas luma ay binubura.
  /// Hal. ngayon = Nov 18 → '2026-11-12'.
  static String cutoffKey(DateTime now) =>
      ZoeDate.key(DateTime(now.year, now.month, now.day - (keepDays - 1)));

  factory MoodWeek.from(Iterable<MoodLogEntry> entries, DateTime now) {
    final cutoff = cutoffKey(now);
    final today = ZoeDate.key(now);
    final counts = <UserTone, int>{};
    final down = <String>{};
    final happy = <String>{};
    for (final e in entries) {
      // Luma na, o "bukas" pa (pinalitan ang oras ng phone) → hindi kasama.
      if (e.count <= 0 || e.day.compareTo(cutoff) < 0 || e.day.compareTo(today) > 0) continue;
      counts[e.tone] = (counts[e.tone] ?? 0) + e.count;
      if (e.tone.isDown) {
        down.add(e.day);
      } else if (e.tone == UserTone.happy) {
        happy.add(e.day);
      }
    }
    return MoodWeek._(Map.unmodifiable(counts), down.length, happy.length);
  }

  int count(UserTone tone) => counts[tone] ?? 0;

  int get total => counts.values.fold(0, (a, b) => a + b);

  bool get isEmpty => total == 0;

  /// Pagod + stressed.
  int get busyCount => count(UserTone.tired) + count(UserTone.stressed);

  /// Malungkot + inis + kabado.
  int get heavyCount => count(UserTone.sad) + count(UserTone.upset) + count(UserTone.worried);

  /// null = wala pang masasabi (kulang sa 3 araw, o halo-halo).
  WeekVibe? get vibe {
    if (downDays >= minDays) {
      return busyCount >= heavyCount ? WeekVibe.busy : WeekVibe.heavy;
    }
    if (happyDays >= minDays && happyDays > downDays) return WeekVibe.good;
    return null;
  }

  /// May sasabihin ba si Zoe tungkol sa linggo, ayon sa [tone] ng mensahe ngayon?
  ///  • pagod / stressed / malungkot… + busy o heavy na linggo → oo
  ///  • masaya + good na linggo → oo
  ///  • iba (hal. masaya ngayon pero busy ang linggo) → wala, para hindi sumalungat.
  WeekVibe? noteFor(UserTone tone) {
    final v = vibe;
    if (v == null) return null;
    if (tone.isDown && v != WeekVibe.good) return v;
    if (tone == UserTone.happy && v == WeekVibe.good) return v;
    return null;
  }

  @override
  String toString() =>
      'MoodWeek(${counts.map((k, v) => MapEntry(k.name, v))}, down $downDays, happy $happyDays)';
}