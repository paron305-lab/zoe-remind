import 'dart:math' as math;

import 'package:zoe_remind/features/companion/models/mood_state.dart';

/// Mood Engine ni Zoe (Personality plan, P2 Mood).
///
/// PURE: walang database, walang timer, walang UI. Laging:
///   (kasalukuyang mood, event, oras ngayon) → bagong mood
/// kaya kayang i-test lahat nang walang phone at walang Qwen.
///
/// Mga rules:
///  • Priority kapag nagsabay: sorry > gentle > focused > proud > happy > sleepy > content.
///    Ang na-miss na reminder ay laging nananalo sa celebration.
///  • Isang celebration lang kada achievement kada araw.
///  • Intensity (0–3) ay nagpapalit lang ng salita, hindi ng ginagawa.
///  • Hindi kailanman haharangin ng mood ang isang task.
///
/// Decay (kusang lumilipas):
///  • happy  → content pagkalipas ng 2 oras
///  • proud  → happy pagkalipas ng 1 oras
///  • gentle → content pagkalipas ng 3 oras
///  • focused → bumabalik sa dating mood (o pagkalipas ng 5 minuto kung na-stuck)
///  • sorry  → content sa susunod na matagumpay na action (o pagkalipas ng 6 oras)
///  • content ↔ sleepy ayon sa gabi (default 23:00–05:00)
class MoodEngine {
  const MoodEngine({this.nightStartHour = 23, this.nightEndHour = 5});

  /// Simula ng gabi (sleepy). Sa P4, manggagaling ito sa Quiet hours setting.
  final int nightStartHour;

  /// Katapusan ng gabi.
  final int nightEndHour;

  static const happyLasts = Duration(hours: 2);
  static const proudLasts = Duration(hours: 1);
  static const gentleLasts = Duration(hours: 3);

  /// Safety: kung hindi dumating ang ThinkingFinished (hal. nag-crash).
  static const focusedMax = Duration(minutes: 5);

  /// Safety: para hindi habambuhay na "sorry" si Zoe.
  static const sorryMax = Duration(hours: 6);

  /// Streak days na sine-celebrate.
  static const celebrateStreaks = {3, 7, 30};

  /// Gabi na ba sa oras na [t]?
  bool isNight(DateTime t) {
    final h = t.hour;
    if (nightStartHour > nightEndHour) {
      // Tumatawid ng hatinggabi, hal. 23 → 5.
      return h >= nightStartHour || h < nightEndHour;
    }
    return h >= nightStartHour && h < nightEndHour;
  }

  // ───────────────────────────── reduce ─────────────────────────────

  /// May nangyari ([event]) → ano ang bagong mood?
  /// Inuuna munang i-[decay] ang [current] para tama ang basehan.
  ZoeMood reduce(ZoeMood current, ZoeEvent event, DateTime now) {
    final m = decay(current, now);

    switch (event) {
      case AppOpened(:final itemsToday):
        final morning = now.hour >= nightEndHour && now.hour < 12;
        if (morning && itemsToday > 0) {
          return _propose(m, MoodState.happy, 1, 'morning_plan', now);
        }
        return m;

      case TaskCompleted():
        return _propose(m, MoodState.happy, 1, 'task_done', now);

      case ReminderDone():
        return _propose(m, MoodState.happy, 1, 'reminder_done', now);

      case UserPositive():
        return _propose(m, MoodState.happy, 1, 'user_positive', now);

      case FirstReminderDone():
        return _celebrate(m, 'first_reminder', now);

      case AllTasksDone():
        return _celebrate(m, 'all_done', now);

      case StreakReached(:final days):
        if (!celebrateStreaks.contains(days)) return m;
        return _celebrate(m, 'streak:$days', now);

      case ReminderMissed():
        return _propose(m, MoodState.gentle, 1, 'missed_reminder', now);

      case OverdueTasks(:final count):
        if (count < 3) return m;
        return _propose(m, MoodState.gentle, count >= 6 ? 2 : 1, 'overdue:$count', now);

      case UserFeelsDown():
        return _propose(m, MoodState.gentle, 2, 'user_down', now);

      case ThinkingStarted():
        if (m.state == MoodState.focused) return m;
        if (m.state.priority > MoodState.focused.priority) return m; // gentle / sorry
        return ZoeMood(
          state: MoodState.focused,
          intensity: 1,
          since: now,
          reason: 'thinking',
          previous: m.copyWith(clearPrevious: true),
          celebrated: m.celebrated,
          celebratedOn: m.celebratedOn,
        );

      case ThinkingFinished():
        if (m.state != MoodState.focused) return m;
        return _restore(m, now);

      case ActionSucceeded():
        if (m.state == MoodState.sorry) return _rest(m, now, now, reason: 'fixed');
        if (m.state == MoodState.focused) return _restore(m, now);
        return m;

      case ZoeFailed(:final kind):
        return _propose(m, MoodState.sorry, 1, 'failed:${kind.name}', now);
    }
  }

  // ───────────────────────────── decay ──────────────────────────────

  /// Lumipas ang oras → ano na ang mood ngayon ([now])?
  /// Walang event dito; oras lang.
  ZoeMood decay(ZoeMood current, DateTime now) {
    var m = _resetCelebrationsIfNewDay(current, now);
    // Ilang hakbang lang ang posible (hal. proud → happy → content → sleepy).
    for (var i = 0; i < 6; i++) {
      final next = _decayStep(m, now);
      if (identical(next, m)) break;
      m = next;
    }
    return m;
  }

  ZoeMood _decayStep(ZoeMood m, DateTime now) {
    final age = now.difference(m.since);

    switch (m.state) {
      case MoodState.content:
        if (isNight(now)) {
          return m.copyWith(state: MoodState.sleepy, intensity: 1, since: now, reason: 'night');
        }
      case MoodState.sleepy:
        if (!isNight(now)) {
          return m.copyWith(state: MoodState.content, intensity: 0, since: now, reason: 'morning');
        }
      case MoodState.happy:
        if (age >= happyLasts) return _rest(m, m.since.add(happyLasts), now);
      case MoodState.proud:
        if (age >= proudLasts) {
          return m.copyWith(
            state: MoodState.happy,
            intensity: 1,
            since: m.since.add(proudLasts),
            reason: 'after_proud',
          );
        }
      case MoodState.gentle:
        if (age >= gentleLasts) return _rest(m, m.since.add(gentleLasts), now);
      case MoodState.focused:
        if (age >= focusedMax) return _restore(m, now);
      case MoodState.sorry:
        if (age >= sorryMax) return _rest(m, m.since.add(sorryMax), now);
    }
    return m; // walang nagbago — parehong object
  }

  // ──────────────────────────── helpers ─────────────────────────────

  /// Subukang palitan ang mood. Tinatanggap lang kung pareho o mas mataas
  /// ang priority. Kapag parehong state: +1 intensity (max 3).
  ZoeMood _propose(ZoeMood m, MoodState state, int intensity, String reason, DateTime now) {
    // Habang nag-iisip si Zoe, ang mas mababang mood ay itinatabi sa "previous"
    // para hindi mawala (hal. may natapos na task habang naghihintay ng confirm).
    if (m.state == MoodState.focused && state.priority < MoodState.focused.priority) {
      final prev = m.previous ?? _rest(m, m.since, now);
      final updated = _propose(prev, state, intensity, reason, now);
      if (identical(updated, prev)) return m;
      return m.copyWith(previous: updated);
    }

    if (state.priority < m.state.priority) return m;

    if (state == m.state) {
      return m.copyWith(
        intensity: math.min(3, math.max(m.intensity + 1, intensity)),
        since: now,
        reason: reason,
      );
    }

    return ZoeMood(
      state: state,
      intensity: intensity.clamp(0, 3),
      since: now,
      reason: reason,
      celebrated: m.celebrated,
      celebratedOn: m.celebratedOn,
    );
  }

  /// Proud — pero isang beses lang kada [key] kada araw.
  /// Kapag hinarangan (hal. gentle si Zoe), HINDI ito binibilang na na-celebrate.
  ZoeMood _celebrate(ZoeMood m, String key, DateTime now) {
    if (m.celebrated.contains(key)) return m;
    final next = _propose(m, MoodState.proud, 2, key, now);
    if (identical(next, m)) return m;
    return next.copyWith(
      celebrated: {...m.celebrated, key},
      celebratedOn: _dayKey(now),
    );
  }

  /// Pahinga: content sa araw, sleepy sa gabi.
  ZoeMood _rest(ZoeMood m, DateTime at, DateTime now, {String reason = 'decay'}) {
    final night = isNight(now);
    return ZoeMood(
      state: night ? MoodState.sleepy : MoodState.content,
      intensity: night ? 1 : 0,
      since: at,
      reason: night ? 'night' : reason,
      celebrated: m.celebrated,
      celebratedOn: m.celebratedOn,
    );
  }

  /// Tapos nang mag-isip → balik sa mood bago nag-focused.
  ZoeMood _restore(ZoeMood focused, DateTime now) {
    final prev = focused.previous;
    if (prev == null) return _rest(focused, now, now);
    return decay(
      prev.copyWith(
        celebrated: focused.celebrated,
        celebratedOn: focused.celebratedOn,
        clearPrevious: true,
      ),
      now,
    );
  }

  ZoeMood _resetCelebrationsIfNewDay(ZoeMood m, DateTime now) {
    final today = _dayKey(now);
    if (m.celebratedOn == today) return m;
    return m.copyWith(celebrated: const <String>{}, celebratedOn: today);
  }

  static String _dayKey(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}