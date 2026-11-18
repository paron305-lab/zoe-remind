import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:zoe_remind/ai/inference/qwen_engine.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/repositories/mood_repository.dart';
import 'package:zoe_remind/database/repositories/reminder_repository.dart';
import 'package:zoe_remind/database/repositories/statistics_repository.dart';
import 'package:zoe_remind/database/repositories/task_repository.dart';
import 'package:zoe_remind/features/companion/controllers/mood_engine.dart';
import 'package:zoe_remind/features/companion/models/mood_day.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';
import 'package:zoe_remind/features/reminders/models/reminder_status.dart';
import 'package:zoe_remind/features/reminders/services/reminder_alarm_service.dart';

/// Mood Controller ni Zoe (Personality plan, P2b).
///
/// Ang "tenga" ng MoodEngine: nakikinig sa nangyayari sa app, ipinapasa sa
/// engine, at sine-save ang mood sa `zoe_mood` para pareho pa rin ito
/// pagbukas ulit ng app.
///
/// Mga pinakikinggan:
///  • Pagbukas ng app (cold start, o pagbalik pagkalipas ng 30 min)
///  • Task / reminder na natapos  ← TaskRepository / ReminderRepository
///  • Bagong reminder / task na na-save ← (ActionSucceeded)
///  • Na-miss, overdue, tapos lahat, streak ← sinisilip ang database
///  • Qwen nag-iisip / tapos / nag-error ← QwenEngine.state
///
/// Ang UI ay nakikinig lang sa [mood] (ValueNotifier).
/// Bago tawagin ang [start], walang ginagawa ang lahat ng method dito
/// (kaya ligtas tawagin ng repositories kahit sa test).
class MoodController with WidgetsBindingObserver {
  MoodController._();
  static final instance = MoodController._();

  /// Ang kasalukuyang mood ni Zoe. Dito nakikinig ang Home / Chat (sa 2c).
  final mood = ValueNotifier<ZoeMood>(ZoeMood.initial(DateTime.now()));

  /// Huling mga event (pinakabago sa unahan) — para sa Developer screen.
  final List<String> recent = [];

  /// Gaano katagal dapat wala sa app bago ituring na "binuksan ulit".
  static const reopenAfter = Duration(minutes: 30);

  /// Gaano kadalas sisilipin ang database habang bukas ang app.
  static const checkEvery = Duration(minutes: 5);

  final _engine = const MoodEngine();
  final _repo = MoodRepository();

  MoodSeen _seen = const MoodSeen();
  bool _started = false;
  Timer? _timer;
  DateTime? _pausedAt;
  BrainState _lastBrain = BrainState.unloaded;

  /// Isa-isa ang trabaho (walang sabay na sulat sa DB / mood).
  Future<void> _queue = Future.value();

  bool get isStarted => _started;

  // ───────────────────────────── start ─────────────────────────────

  /// Tawagin isang beses sa main(), pagkatapos ng runApp.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      final saved = await _repo.load();
      if (saved != null) {
        final (m, seen) = saved;
        mood.value = _engine.decay(m, DateTime.now());
        _seen = seen;
      }
    } catch (e) {
      debugPrint('Mood load failed: $e');
    }

    WidgetsBinding.instance.addObserver(this);
    ReminderAlarmService.instance.changes.addListener(_onAlarmChanged);
    final brain = QwenEngine.instance.state;
    _lastBrain = brain.value;
    brain.addListener(_onBrainChanged);
    _timer = Timer.periodic(checkEvery, (_) => refresh());

    _opened();
  }

  /// Ihinto ang pakikinig (timer + listeners). Para sa test / hot restart.
  /// Pwedeng i-start() ulit pagkatapos.
  void stop() {
    if (!_started) return;
    _started = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    ReminderAlarmService.instance.changes.removeListener(_onAlarmChanged);
    QwenEngine.instance.state.removeListener(_onBrainChanged);
  }

  // ─────────────── mga tinatawag ng ibang bahagi ng app ───────────────

  /// May task na na-check as done (TaskRepository.setDone).
  void taskDone() {
    if (!_started) return;
    _enqueue(() async {
      await _apply(const TaskCompleted());
      await _check();
    });
  }

  /// May reminder na na-Done (ReminderRepository.setDoneOn).
  void reminderDone() {
    if (!_started) return;
    _enqueue(() async {
      await _apply(const ReminderDone());
      if (await _repo.reminderCompletionsEver() == 1) {
        await _apply(const FirstReminderDone());
      }
      await _check();
    });
  }

  /// May bagong reminder / task na na-save. Tinatapos ang "sorry".
  void saved() {
    if (!_started) return;
    _enqueue(() => _apply(const ActionSucceeded()));
  }

  /// Kahit anong event (hal. galing sa chat sa 2c: UserFeelsDown).
  void add(ZoeEvent event) {
    if (!_started) return;
    _enqueue(() => _apply(event));
  }

  /// Silipin ulit ang database (na-miss, overdue, tapos lahat, streak).
  void refresh() {
    if (!_started) return;
    _enqueue(_check);
  }

  /// Developer › Reset: balik sa content, burado ang naka-save.
  Future<void> reset() async {
    final done = Completer<void>();
    _enqueue(() async {
      try {
        await _repo.clear();
        mood.value = ZoeMood.initial(DateTime.now());
        _seen = const MoodSeen();
        recent.clear();
        _log('reset');
      } finally {
        done.complete();
      }
    });
    return done.future;
  }

  // ─────────────────────────── listeners ───────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        final away = _pausedAt == null
            ? Duration.zero
            : DateTime.now().difference(_pausedAt!);
        _pausedAt = null;
        if (away >= reopenAfter) {
          _opened();
        } else {
          refresh();
        }
      case AppLifecycleState.paused:
        _pausedAt ??= DateTime.now();
      default:
        break;
    }
  }

  /// Done / Snooze / Dismiss sa ringing screen, o nag-sync ang alarms.
  void _onAlarmChanged() => refresh();

  /// Qwen: nag-iisip → focused; tapos → balik; nag-error → sorry.
  void _onBrainChanged() {
    final now = QwenEngine.instance.state.value;
    final before = _lastBrain;
    _lastBrain = now;
    if (now == before) return;

    if (now == BrainState.generating) {
      add(const ThinkingStarted());
    } else if (before == BrainState.generating) {
      add(const ThinkingFinished());
    }

    if (now == BrainState.error && !_noModelYet()) {
      add(const ZoeFailed(ZoeFailure.inference));
    }
  }

  /// "Wala pang model" ay hindi kasalanan ni Zoe — hindi siya magso-sorry.
  bool _noModelYet() =>
      (QwenEngine.instance.lastError ?? '').contains('Wala pang model');

  // ─────────────────────────── internals ───────────────────────────

  /// Binuksan ang app: AppOpened (may plano ngayong umaga?) + silip sa DB.
  void _opened() {
    _enqueue(() async {
      final snap = await _snapshot();
      await _apply(AppOpened(itemsToday: snap.itemsToday));
      await _applySnapshot(snap);
    });
  }

  Future<void> _check() async {
    final snap = await _snapshot();
    await _applySnapshot(snap);
  }

  Future<void> _applySnapshot(DaySnapshot snap) async {
    final (events, seen) = MoodRules.eventsFor(snap, _seen);
    final seenChanged = seen != _seen;
    _seen = seen;

    final before = mood.value;
    var m = _engine.decay(before, DateTime.now());
    for (final e in events) {
      final next = _engine.reduce(m, e, DateTime.now());
      // Log lang kung may binago (hindi paulit-ulit ang "all_done" kada 5 min).
      if (!identical(next, m)) _log(_name(e));
      m = next;
    }
    if (!identical(m, before)) mood.value = m;
    if (seenChanged || !identical(m, before)) await _save();
  }

  Future<void> _apply(ZoeEvent e) async {
    final before = mood.value;
    final next = _engine.reduce(before, e, DateTime.now());
    _log(_name(e));
    if (identical(next, before)) return;
    mood.value = next;
    await _save();
  }

  Future<void> _save() async {
    try {
      await _repo.save(mood.value, _seen);
    } catch (e) {
      debugPrint('Mood save failed: $e');
    }
  }

  /// Basahin ang araw ngayon mula sa database.
  Future<DaySnapshot> _snapshot() async {
    final now = DateTime.now();
    final today = ZoeDate.dayOnly(now);
    final todayKey = ZoeDate.key(today);

    var items = 0, done = 0, missed = 0, overdue = 0;

    // Reminders ngayong araw (parehong rules ng Home).
    final active = await ReminderAlarmService.instance.activeAlarmOccurrences();
    for (final r in await ReminderRepository().getForDay(today)) {
      final pendingAt = active[r.id];
      final alarmPending = pendingAt != null && ZoeDate.sameDay(pendingAt, today);
      final status = ReminderStatusRules.statusOn(r, today,
          now: now, alarmPending: alarmPending);
      if (status == ReminderStatus.dismissed) continue; // sinadyang laktawan
      items++;
      if (status.isDone) done++;
      if (status == ReminderStatus.missed) missed++;
    }

    // Tasks: ngayong araw + lahat ng overdue.
    for (final t in await TaskRepository().getAll()) {
      final missedNow = t.isMissedAt(now);
      if (missedNow) overdue++;
      if (t.date == todayKey) {
        items++;
        if (t.isDone) {
          done++;
        } else if (missedNow) {
          missed++;
        }
      }
    }

    final streak = await StatisticsRepository().dayStreak(now: now);
    final completedToday = await _repo.completionsOn(todayKey) > 0;

    return DaySnapshot(
      day: todayKey,
      itemsToday: items,
      doneToday: done,
      missedToday: missed,
      overdueTasks: overdue,
      streak: streak,
      completedToday: completedToday,
    );
  }

  void _enqueue(Future<void> Function() job) {
    _queue = _queue.then((_) => job()).catchError((Object e) {
      debugPrint('Mood job failed: $e');
    });
  }

  void _log(String text) {
    final t = DateTime.now();
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    recent.insert(0, '$hm  $text');
    if (recent.length > 12) recent.removeLast();
  }

  static String _name(ZoeEvent e) => switch (e) {
        AppOpened(:final itemsToday) => 'app_opened (items: $itemsToday)',
        TaskCompleted() => 'task_done',
        ReminderDone() => 'reminder_done',
        FirstReminderDone() => 'first_reminder',
        AllTasksDone() => 'all_done',
        StreakReached(:final days) => 'streak:$days',
        ReminderMissed() => 'missed',
        OverdueTasks(:final count) => 'overdue:$count',
        UserFeelsDown() => 'user_down',
        UserPositive() => 'user_positive',
        ThinkingStarted() => 'thinking',
        ThinkingFinished() => 'thinking_done',
        ActionSucceeded() => 'saved',
        ZoeFailed(:final kind) => 'failed:${kind.name}',
      };
}