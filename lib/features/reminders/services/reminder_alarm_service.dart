import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:zoe_remind/app/router.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/models/reminder.dart';
import 'package:zoe_remind/database/repositories/reminder_repository.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';

/// Info na pinapakita sa ringing screen (galing sa payload).
class RingInfo {
  const RingInfo(this.title, this.originalTime);
  final String title;
  final DateTime originalTime;
}

/// Lahat ng alarm logic: schedule, ring, snooze, done, dismiss.
/// Deterministic code — hindi si Qwen ang nag-schedule.
/// Alarm id = reminder id sa SQLite.
class ReminderAlarmService {
  ReminderAlarmService._();
  static final ReminderAlarmService instance = ReminderAlarmService._();

  static const String musicPath = 'assets/music/Morning_Zoe.mp3';
  static const List<int> snoozeOptions = [5, 10, 30];
  static const MethodChannel _lockChannel = MethodChannel('zoe/alarm_screen');

  /// Kulay ng notification (lavender na may pagka-blue).
  static const Color notifColor = Color(0xFF7B8CE6);
  static const _kEnabled = 'reminders_enabled';

  final _repo = ReminderRepository();
  final _settings = SettingsRepository();

  /// Master switch ng reminders (bell button sa Home).
  /// true = tutunog, false = walang alarm na ise-set.
  final ValueNotifier<bool> enabled = ValueNotifier(true);
  StreamSubscription<AlarmSet>? _ringSub;
  int? _showingId;

  /// Para mag-refresh ang Home pagkatapos ng Done / Dismiss / Snooze.
  final ValueNotifier<int> changes = ValueNotifier(0);

  /// Huling error (pinapakita sa Alarm Check screen sa Settings).
  String? lastError;

  /// Id ng test alarm (hindi galing sa database).
  static const int testAlarmId = 999999;

  /// TEST: tutunog after [delay]. Ibinabato ang error para makita sa screen.
  Future<void> scheduleTest({Duration delay = const Duration(seconds: 10)}) =>
      _setAlarm(
        id: testAlarmId,
        title: 'Test reminder ni Zoe',
        dateTime: DateTime.now().add(delay),
      );

  // ───────────────────────── Startup ─────────────────────────

  /// Tawagin isang beses sa main(), pagkatapos ng runApp().
  void startListening() {
    _ringSub ??= Alarm.ringing.listen(_onRinging);
  }

  // ───────────────────────── ON / OFF (bell sa Home) ─────────────────────────

  /// Basahin ang naka-save na ON/OFF (default ON).
  Future<bool> loadEnabled() async {
    try {
      enabled.value = await _settings.getValue(_kEnabled) != 'false';
    } catch (e) {
      lastError = 'Load enabled failed: $e';
    }
    return enabled.value;
  }

  /// OFF → burahin lahat ng alarm. ON → i-schedule ulit lahat.
  Future<void> setEnabled(bool on) async {
    enabled.value = on;
    await _settings.setValue(_kEnabled, on ? 'true' : 'false');
    if (on) {
      await syncAll();
    } else {
      await _stopAllScheduled();
    }
    changes.value++;
  }

  Future<void> _stopAllScheduled() async {
    try {
      for (final a in await Alarm.getAlarms()) {
        if (await Alarm.isRinging(a.id)) continue; // hayaan ang nagri-ring
        await Alarm.stop(a.id);
        if (a.id != testAlarmId) await _repo.setNotificationState(a.id, 'not_scheduled');
      }
    } catch (e) {
      lastError = 'Stop all failed: $e';
      debugPrint(lastError);
    }
  }

  Future<void> _onRinging(AlarmSet set) async {
    if (set.alarms.isEmpty) return;
    final alarm = set.alarms.first;
    if (_showingId == alarm.id) return; // nakabukas na ang screen
    _showingId = alarm.id;

    await _setLockScreen(true);
    // Kung unlocked at nasa ibang app: ilabas si Zoe sa harap
    // (gumagana kung naka-allow ang "Display over other apps").
    await _invoke('bringToFront');

    // Hintayin na ready ang router (lalo na kung bagong bukas ang app).
    SchedulerBinding.instance.addPostFrameCallback((_) {
      appRouter.push('/ringing', extra: alarm);
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  /// Pagbukas ng app: siguraduhing may alarm ang bawat pending reminder,
  /// at walang natirang alarm para sa nabura na.
  /// Hindi ginagalaw ang alarm na naka-schedule na (hal. naka-snooze)
  /// o kasalukuyang nagri-ring.
  Future<void> syncAll() async {
    if (!await loadEnabled()) {
      await _stopAllScheduled(); // naka-OFF ang reminders
      return;
    }
    try {
      final reminders = await _repo.getAll();
      final ids = reminders.map((r) => r.id).whereType<int>().toSet();

      // 1. Alisin ang alarm ng mga reminder na wala na sa database.
      for (final a in await Alarm.getAlarms()) {
        if (!ids.contains(a.id) && !await Alarm.isRinging(a.id)) {
          await Alarm.stop(a.id);
        }
      }

      // 2. I-schedule ang mga wala pang alarm.
      for (final r in reminders) {
        final id = r.id;
        if (id == null) continue;
        if (await Alarm.getAlarm(id) != null) continue; // meron na
        await _scheduleNext(r);
      }
    } catch (e) {
      lastError = 'Alarm sync failed: $e';
      debugPrint(lastError);
    }
  }

  // ───────────────────────── Scheduling ─────────────────────────

  /// Pagkatapos mag-save / mag-edit / mag-tick:
  /// burahin ang lumang alarm at i-schedule ulit mula sa database.
  Future<void> syncById(int id) async {
    try {
      final r = await _repo.getById(id);
      await Alarm.stop(id);
      if (r == null) return;
      await _scheduleNext(r);
    } catch (e) {
      lastError = 'Alarm sync for $id failed: $e';
      debugPrint(lastError);
    }
  }

  /// Mga alarm na aktibo pa: reminder id → oras ng occurrence na tinutunog nito
  /// (galing sa payload). Hal. naka-snooze ang 7:00 PM → {id: 7:00 PM}.
  /// Para hindi agad lumabas na "Missed" ang naka-snooze o nagri-ring.
  Future<Map<int, DateTime>> activeAlarmOccurrences() async {
    try {
      final result = <int, DateTime>{};
      final now = DateTime.now();
      for (final a in await Alarm.getAlarms()) {
        if (a.dateTime.isAfter(now) || await Alarm.isRinging(a.id)) {
          result[a.id] = readPayload(a).originalTime;
        }
      }
      return result;
    } catch (e) {
      lastError = 'Active alarms failed: $e';
      return {};
    }
  }

  /// Pagkatapos mag-delete.
  Future<void> cancel(int id) async {
    try {
      await Alarm.stop(id);
    } catch (e) {
      lastError = 'Alarm cancel for $id failed: $e';
      debugPrint(lastError);
    }
  }

  /// Susunod na pag-ring ng reminder pagkatapos ng [from] (default: ngayon).
  /// null = wala nang susunod (tapos na / lumipas na ang one-time).
  static DateTime? nextFireTime(Reminder r, {DateTime? from}) {
    final after = from ?? DateTime.now();
    final t = ZoeDate.parseTime(r.time);

    if (r.repeat == ReminderRepeat.none) {
      if (r.status == 'done') return null;
      final d = ZoeDate.parseKey(r.date);
      final at = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      return at.isAfter(after) ? at : null;
    }

    // Daily / weekly / monthly: hanapin ang susunod na araw (max ~1 taon).
    var day = ZoeDate.dayOnly(after);
    for (var i = 0; i < 400; i++) {
      final at = DateTime(day.year, day.month, day.day, t.hour, t.minute);
      if (r.occursOn(day) && !r.isDoneOn(day) && at.isAfter(after)) return at;
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return null;
  }

  Future<void> _scheduleNext(Reminder r, {DateTime? from}) async {
    final id = r.id;
    if (id == null) return;
    final at = enabled.value ? nextFireTime(r, from: from) : null;
    if (at == null) {
      await _repo.setNotificationState(id, 'not_scheduled');
      return;
    }
    await _setAlarm(id: id, title: r.title, dateTime: at);
    await _repo.setNotificationState(id, 'scheduled');
  }

  Future<void> _setAlarm({
    required int id,
    required String title,
    required DateTime dateTime,
  }) async {
    final settings = AlarmSettings(
      id: id,
      dateTime: dateTime,
      assetAudioPath: musicPath,
      loopAudio: true, // tuloy-tuloy ang music hanggang may pinindot
      vibrate: true, // vibrate kahit naka-lock
      androidFullScreenIntent: true, // gigisingin ang screen
      androidStopAlarmOnTermination: false, // tutunog pa rin kahit i-swipe ang app
      warningNotificationOnKill: Platform.isIOS,
      payload: jsonEncode({
        'title': title,
        'originalTime': dateTime.toIso8601String(),
      }),
      // Walang `volume:` → hindi gagalawin ang volume ng phone, kaya
      // hindi lalabas ang volume slider. Fade-in pa rin ng music (3s).
      volumeSettings: VolumeSettings.fade(
        fadeDuration: const Duration(seconds: 3),
      ),
      notificationSettings: NotificationSettings(
        title: 'Zoe Reminder',
        body: title,
        androidStopAlarmOnDismiss: false, // bawal patayin sa swipe ng notif
        icon: 'notification_icon', // Zoe logo (res/drawable-*/notification_icon.png)
        iconColor: notifColor, // lavender-blue
      ),
    );
    await Alarm.set(alarmSettings: settings);
  }

  // ───────────────────────── Ringing actions ─────────────────────────

  /// SNOOZE: 5 / 10 / 30 min -> titigil, tapos magri-ring ulit.
  Future<void> snooze(AlarmSettings alarm, int minutes) async {
    assert(snoozeOptions.contains(minutes));
    await Alarm.stop(alarm.id);
    final next = DateTime.now().add(Duration(minutes: minutes));
    // copyWith -> pareho pa rin ang payload (originalTime), iba lang ang oras
    await Alarm.set(alarmSettings: alarm.copyWith(dateTime: next));
    await finish();
  }

  /// DONE: titigil + done sa SQLite + completion_history.
  /// Kung repeating -> automatic i-schedule ang susunod.
  Future<void> markDone(AlarmSettings alarm) async {
    await Alarm.stop(alarm.id);
    try {
      final day = readPayload(alarm).originalTime;
      await _repo.setDoneOn(alarm.id, day, true);
      final r = await _repo.getById(alarm.id);
      if (r != null) await _scheduleNext(r);
    } catch (e) {
      lastError = 'Mark done failed: $e';
      debugPrint(lastError);
    }
    await finish();
  }

  /// DISMISS: titigil, hindi done (walang history log).
  /// Lalabas na "Dismissed" sa Home; pwede pang i-mark as done nang late.
  /// One-time -> wala nang alarm. Repeating -> tutunog sa susunod na araw.
  Future<void> dismiss(AlarmSettings alarm) async {
    await Alarm.stop(alarm.id);
    try {
      final day = readPayload(alarm).originalTime;
      if (alarm.id != testAlarmId) await _repo.setDismissedOn(alarm.id, day);
      final r = await _repo.getById(alarm.id);
      if (r != null) {
        await _scheduleNext(r, from: day);
      }
    } catch (e) {
      lastError = 'Dismiss failed: $e';
      debugPrint(lastError);
    }
    await finish();
  }

  Future<void> finish() async {
    _showingId = null;
    changes.value++; // sabihan ang Home na mag-reload
    await _setLockScreen(false);
  }

  // ───────────────────────── Helpers ─────────────────────────

  Future<void> _invoke(String method) async {
    try {
      await _lockChannel.invokeMethod(method);
    } catch (_) {
      // Ibang platform / walang channel — ok lang.
    }
  }

  Future<void> _setLockScreen(bool on) async {
    try {
      await _lockChannel.invokeMethod(on ? 'showOverLockScreen' : 'clearLockScreen');
    } catch (_) {
      // Ibang platform / walang channel — ok lang.
    }
  }

  static RingInfo readPayload(AlarmSettings a) {
    try {
      final map = jsonDecode(a.payload ?? '{}') as Map<String, dynamic>;
      return RingInfo(
        (map['title'] as String?) ?? a.notificationSettings.body,
        DateTime.tryParse((map['originalTime'] as String?) ?? '') ?? a.dateTime,
      );
    } catch (_) {
      return RingInfo(a.notificationSettings.body, a.dateTime);
    }
  }
}