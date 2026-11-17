/// Mood ni Zoe (Personality plan, P2 Mood).
///
/// Ang code ang nagdedesisyon ng mood mula sa totoong nangyari sa app —
/// hindi si Qwen. Ang mood ay nagpapalit lang ng SALITA ni Zoe, hindi ng
/// ginagawa niya (hindi kailanman haharangin ng mood ang isang task).
enum MoodState {
  /// Default. Walang espesyal na nangyayari.
  content(0),

  /// Gabi (23:00–05:00). Mas tahimik, nagmumungkahing magpahinga.
  sleepy(1),

  /// May natapos, may plano sa umaga, may positibong sinabi ang user.
  happy(2),

  /// Tapos lahat ngayong araw, streak 3 / 7 / 30, unang reminder na natapos.
  proud(3),

  /// Si Zoe ay nag-iisip / may hinihintay na confirm. Maikling status lang.
  focused(4),

  /// May na-miss, maraming overdue, o pagod / malungkot ang user.
  gentle(5),

  /// May mali sa side ni Zoe: AI error, hindi tumunog ang alarm, sync problem.
  sorry(6);

  const MoodState(this.priority);

  /// Kapag nagsabay ang dalawang event, ang mas mataas ang nananalo:
  /// sorry > gentle > focused > proud > happy > sleepy > content.
  final int priority;
}

/// Ang kasalukuyang mood ni Zoe. Immutable — bawat pagbabago ay bagong ZoeMood.
class ZoeMood {
  final MoodState state;

  /// 0–3. Nagpapalit ng word choice, hindi ng behavior.
  /// (Hal. happy 3 = pwedeng isang emoji; happy 1 = wala.)
  final int intensity;

  /// Kailan nagsimula ang state na ito. Dito nakabase ang decay.
  final DateTime since;

  /// Bakit — para sa debug at test. Hal. "task_done", "missed_reminder", "streak:7".
  final String reason;

  /// Para sa focused lang: ang mood bago nag-isip si Zoe, babalikan pagkatapos.
  final ZoeMood? previous;

  /// Mga achievement na na-celebrate na ngayong araw ([celebratedOn]).
  /// Hal. {"all_done", "streak:7"} — para isang beses lang mag-celebrate.
  final Set<String> celebrated;

  /// Petsa (yyyy-MM-dd) ng [celebrated]. Kapag ibang araw na, nire-reset.
  final String celebratedOn;

  const ZoeMood({
    required this.state,
    required this.since,
    this.intensity = 0,
    this.reason = '',
    this.previous,
    this.celebrated = const {},
    this.celebratedOn = '',
  });

  /// Panimulang mood (bagong install, o walang naka-save).
  factory ZoeMood.initial(DateTime now) =>
      ZoeMood(state: MoodState.content, since: now, reason: 'start');

  ZoeMood copyWith({
    MoodState? state,
    int? intensity,
    DateTime? since,
    String? reason,
    ZoeMood? previous,
    bool clearPrevious = false,
    Set<String>? celebrated,
    String? celebratedOn,
  }) {
    return ZoeMood(
      state: state ?? this.state,
      intensity: intensity ?? this.intensity,
      since: since ?? this.since,
      reason: reason ?? this.reason,
      previous: clearPrevious ? null : (previous ?? this.previous),
      celebrated: celebrated ?? this.celebrated,
      celebratedOn: celebratedOn ?? this.celebratedOn,
    );
  }

  @override
  String toString() => 'ZoeMood(${state.name}, i=$intensity, $reason, since $since)';
}

/// Mga nangyayari sa app na pwedeng magpabago ng mood ni Zoe.
///
/// Sealed: alam ng MoodEngine ang lahat ng klase ng event, kaya kapag may
/// idinagdag dito, sasabihan ka ng compiler kung saan pa kailangang i-handle.
sealed class ZoeEvent {
  const ZoeEvent();
}

/// Binuksan ang app. [itemsToday] = ilang reminder/task ngayong araw.
class AppOpened extends ZoeEvent {
  final int itemsToday;
  const AppOpened({this.itemsToday = 0});
}

/// May task na natapos.
class TaskCompleted extends ZoeEvent {
  const TaskCompleted();
}

/// May reminder na pinindot ang Done.
class ReminderDone extends ZoeEvent {
  const ReminderDone();
}

/// Unang reminder na natapos — kahit kailan (first ever).
class FirstReminderDone extends ZoeEvent {
  const FirstReminderDone();
}

/// Natapos na lahat ng reminder/task ngayong araw.
class AllTasksDone extends ZoeEvent {
  const AllTasksDone();
}

/// Umabot ang day streak sa [days]. Nagse-celebrate lang sa 3, 7, at 30.
class StreakReached extends ZoeEvent {
  final int days;
  const StreakReached(this.days);
}

/// May reminder na na-miss.
class ReminderMissed extends ZoeEvent {
  const ReminderMissed();
}

/// Ilang task ang overdue ngayon. Nagiging gentle kapag 3 o higit pa.
class OverdueTasks extends ZoeEvent {
  final int count;
  const OverdueTasks(this.count);
}

/// Nagkuwento ang user na pagod / malungkot / "ang dami" (ZoeSituation.comfort).
/// Sa P3, papalitan / dadagdagan ito ng user_tone mula kay Qwen.
class UserFeelsDown extends ZoeEvent {
  const UserFeelsDown();
}

/// Positibo ang sinabi ng user ("yes!", "haha", "salamat").
class UserPositive extends ZoeEvent {
  const UserPositive();
}

/// Nagsimulang mag-isip si Zoe (Qwen) o may naghihintay na confirm card.
class ThinkingStarted extends ZoeEvent {
  const ThinkingStarted();
}

/// Tapos nang mag-isip (may sagot man o kinansela ang confirm).
class ThinkingFinished extends ZoeEvent {
  const ThinkingFinished();
}

/// Matagumpay na action (na-save ang reminder/task/note). Tinatapos ang sorry.
class ActionSucceeded extends ZoeEvent {
  const ActionSucceeded();
}

/// May mali sa side ni Zoe.
class ZoeFailed extends ZoeEvent {
  final ZoeFailure kind;
  const ZoeFailed(this.kind);
}

enum ZoeFailure { inference, alarm, sync }