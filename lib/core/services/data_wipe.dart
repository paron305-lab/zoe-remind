import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:zoe_remind/database/repositories/chat_history_repository.dart';
import 'package:zoe_remind/database/repositories/memory_repository.dart';
import 'package:zoe_remind/database/repositories/note_repository.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/database/repositories/wipe_repository.dart';
import 'package:zoe_remind/features/companion/controllers/mood_controller.dart';
import 'package:zoe_remind/features/companion/controllers/mood_log.dart';

/// Iisang "Burahin lahat ng data" ng buong app.
/// Lahat ng button na nagbubura ng LAHAT ay dapat dito dumaan.
///
/// Pagkakasunod:
///   1. Patayin ang lahat ng naka-schedule na alarm (para walang tumunog
///      para sa reminder na wala na).
///   2. Burahin ang database (WipeRepository — isang transaction + VACUUM).
///   3. I-reset ang nasa memory ng app (mood ni Zoe, mood log).
///   4. Sabihan ang mga screen na mag-refresh.
///
/// Hindi binubura: pangalan, language, settings ng app, na-download na model.
/// Pagkatapos: mananatili sa Home ang user (walang onboarding).
class DataWipe {
  DataWipe._();
  static final instance = DataWipe._();

  final _wipe = WipeRepository();

  bool _running = false;

  /// Huling error (para sa Developer screen). null = ayos.
  String? lastError;

  /// true = tapos at malinis. false = may pumalya (tingnan ang [lastError]).
  Future<bool> wipeAll() async {
    if (_running) return false;
    _running = true;
    lastError = null;
    try {
      await _stopAllAlarms();
      await _wipe.wipeUserData();
      await MoodController.instance.reset();
      await MoodLog.instance.clearAll();
      _notifyScreens();
      return true;
    } catch (e) {
      lastError = 'Wipe failed: $e';
      debugPrint(lastError);
      _notifyScreens();
      return false;
    } finally {
      _running = false;
    }
  }

  /// Lahat — kasama ang nagri-ring. Wala nang reminder na babalikan nito.
  Future<void> _stopAllAlarms() async {
    try {
      for (final a in await Alarm.getAlarms()) {
        await Alarm.stop(a.id);
      }
    } catch (e) {
      // Hindi dahilan para hindi burahin ang data.
      lastError = 'Stop alarms failed: $e';
      debugPrint(lastError);
    }
  }

  void _notifyScreens() {
    ChatHistoryRepository.changes.value++;
    MemoryRepository.changes.value++;
    NoteRepository.changes.value++;
    SettingsRepository.changes.value++;
  }
}