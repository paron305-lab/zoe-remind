import 'package:zoe_remind/database/repositories/memory_repository.dart';
import 'package:zoe_remind/database/repositories/reminder_repository.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/memory/habit_rules.dart';

/// Implicit learning (B6): tinitingnan kung may ugaling pwedeng imungkahi
/// pagkatapos mag-save ng reminder sa chat.
///
///   5 reminder na 8 AM o mas maaga → "Mukhang gusto mo ng morning reminders,
///   tandaan ko ba?" + memory card (Accept muna).
///
/// Mga patakaran:
///   • OFF ang Long-term memory → walang mungkahi.
///   • May memory na tungkol diyan → walang mungkahi.
///   • "Huwag" sa card → hindi na itatanong ([decline]).
///   • Isang beses lang kada [HabitRules.askAgainDays] araw kapag hindi sinagot.
///   • Ang reminders table lang ang binabasa (oras + kailan ginawa) —
///     hindi ang mga title, at walang ipinapadala kahit saan.
class HabitWatcher {
  HabitWatcher({
    ReminderRepository? reminders,
    MemoryRepository? memories,
    SettingsRepository? settings,
    DateTime Function()? clock,
  })  : _reminders = reminders ?? ReminderRepository(),
        _memories = memories ?? MemoryRepository(),
        _settings = settings ?? SettingsRepository(),
        _clock = clock ?? DateTime.now;

  final ReminderRepository _reminders;
  final MemoryRepository _memories;
  final SettingsRepository _settings;
  final DateTime Function() _clock;

  /// Ang mungkahi ngayon, o null. Kapag may ibinalik, minamarkahan na itong
  /// "naipakita" (para hindi ulit-ulitin).
  Future<HabitSuggestion?> next() async {
    if (!await _settings.isLongTermMemoryOn()) return null;
    final now = _clock();

    final all = await _reminders.getAll();
    final suggestion = HabitRules.check(
      [
        for (final r in all)
          if (DateTime.tryParse(r.createdAt) case final created?) (created, r.time),
      ],
      now: now,
    );
    if (suggestion == null) return null;

    final memories = await _memories.getAll();
    if (HabitRules.coveredBy(suggestion.habit, memories.map((m) => m.content))) return null;

    final key = HabitRules.key(suggestion.habit);
    if (!HabitRules.canAsk(await _settings.getValue(key), now: now)) return null;

    await _settings.setValue(key, HabitRules.shownOn(now));
    return suggestion;
  }

  /// "Huwag" / "wag na" sa mungkahi → hindi na itatanong kailanman.
  Future<void> decline(Habit habit) => _settings.setValue(HabitRules.key(habit), 'declined');
}