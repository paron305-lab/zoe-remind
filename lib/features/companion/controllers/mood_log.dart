import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/repositories/mood_log_repository.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/features/companion/models/mood_week.dart';
import 'package:zoe_remind/features/companion/models/user_tone.dart';

/// Mood log ni Zoe — Level 2: "Remember recent days".
///
/// Binibilang kung ilang beses pagod / stressed / masaya… ang user sa
/// huling 7 araw, para masabi ni Zoe: "Mukhang busy ang linggo mo."
///
/// Mga rules:
///  • Bilang lang. Hindi sine-save ang mensahe ng user.
///  • Sa phone lang (zoe.db). Walang upload.
///  • Kusang nabubura pagkalipas ng 7 araw.
///  • Settings › Privacy & memory: ON/OFF at "Burahin lahat".
///    Kapag OFF: walang binibilang, at binubura ang laman.
///  • Hindi binibilang ang crisis messages (laging nauuna ang CrisisGuard).
///  • Isang beses lang kada araw magsasalita si Zoe tungkol sa linggo.
///
/// Bago tawagin ang [start], walang ginagawa ang lahat ng method dito
/// (kaya ligtas sa test na walang database).
class MoodLog {
  MoodLog._();
  static final instance = MoodLog._();

  final _repo = MoodLogRepository();
  final _settings = SettingsRepository();

  /// ON/OFF (Settings). Default ON.
  final enabled = ValueNotifier<bool>(true);

  /// Tumataas kada may nabago — para mag-refresh ang Settings at Developer.
  final changes = ValueNotifier<int>(0);

  bool _started = false;
  bool get isStarted => _started;

  /// Isa-isa ang sulat sa DB (walang sabay).
  Future<void> _queue = Future.value();

  Future<void> _run(Future<void> Function() job) {
    final next = _queue.then((_) => job()).catchError((Object e) {
      debugPrint('Mood log failed: $e');
    });
    _queue = next;
    return next;
  }

  /// Tawagin isang beses sa main().
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      enabled.value = await _settings.isMoodLogOn();
    } catch (e) {
      debugPrint('Mood log setting load failed: $e');
    }
    await _run(() async {
      await _repo.pruneBefore(MoodWeek.cutoffKey(DateTime.now()));
    });
  }

  /// Galing sa chat: ang tone ng mensahe. Neutral → walang ginagawa.
  Future<void> record(UserTone tone) {
    if (!_started || !enabled.value || tone == UserTone.neutral) return Future.value();
    return _run(() async {
      final now = DateTime.now();
      await _repo.add(ZoeDate.key(now), tone, now);
      await _repo.pruneBefore(MoodWeek.cutoffKey(now));
      changes.value++;
    });
  }

  /// Buod ng huling 7 araw. OFF / hindi pa nagsisimula → empty.
  Future<MoodWeek> week() async {
    if (!_started || !enabled.value) return MoodWeek.empty;
    try {
      await _queue; // hintayin ang kasalukuyang sulat
      final now = DateTime.now();
      return MoodWeek.from(await _repo.since(MoodWeek.cutoffKey(now)), now);
    } catch (e) {
      debugPrint('Mood log read failed: $e');
      return MoodWeek.empty;
    }
  }

  /// Para sa chat: may sasabihin ba si Zoe tungkol sa linggo?
  /// Isang beses lang kada araw (settings: mood_log_noted_on).
  Future<WeekVibe?> noteFor(UserTone tone) async {
    if (!_started || !enabled.value || tone == UserTone.neutral) return null;
    try {
      final today = ZoeDate.key(DateTime.now());
      if (await _settings.getMoodLogNotedOn() == today) return null;
      final vibe = (await week()).noteFor(tone);
      if (vibe != null) await _settings.setMoodLogNotedOn(today);
      return vibe;
    } catch (e) {
      debugPrint('Mood log note failed: $e');
      return null;
    }
  }

  /// Settings toggle. OFF → binubura rin ang laman.
  Future<void> setEnabled(bool on) async {
    await _settings.setMoodLog(on);
    enabled.value = on;
    if (!on) await clearAll();
    changes.value++;
  }

  /// Settings › "Burahin lahat".
  Future<void> clearAll() => _run(() async {
        await _repo.clearAll();
        await _settings.setMoodLogNotedOn('');
        changes.value++;
      });

  // ───────────────────────── Developer ─────────────────────────

  /// Developer › "3 araw pagod": pagod kahapon, 2 at 3 araw na ang nakaraan,
  /// at pwede ulit magsalita si Zoe ngayong araw. Para ma-test agad sa phone.
  Future<void> seedTestDays([UserTone tone = UserTone.tired]) {
    if (!_started || !enabled.value) return Future.value();
    return _run(() async {
      final now = DateTime.now();
      for (var i = 1; i <= 3; i++) {
        final day = DateTime(now.year, now.month, now.day - i);
        await _repo.add(ZoeDate.key(day), tone, now);
      }
      await _settings.setMoodLogNotedOn('');
      changes.value++;
    });
  }

  /// Developer: para masabi ulit ni Zoe ngayong araw.
  Future<void> resetNotedToday() => _run(() async {
        await _settings.setMoodLogNotedOn('');
        changes.value++;
      });

  /// Developer: kailan huling nagsalita si Zoe tungkol sa linggo.
  Future<String> notedOn() async {
    try {
      return await _settings.getMoodLogNotedOn();
    } catch (_) {
      return '';
    }
  }
}