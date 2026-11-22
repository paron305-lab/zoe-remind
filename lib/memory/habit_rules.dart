import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/rag/query_terms.dart';

/// Mga ugali na kayang mapansin ni Zoe (B6 — implicit learning).
enum Habit {
  /// Madalas mag-set ng reminder nang maaga (4:00–8:00 AM).
  morning,

  /// Madalas mag-set ng reminder sa gabi (6:00–11:59 PM).
  evening,
}

/// Isang mungkahi: "Mukhang gusto mo ng morning reminders, tandaan ko ba?"
class HabitSuggestion {
  const HabitSuggestion(this.habit, this.count);

  final Habit habit;

  /// Ilang reminder ang tumugma (para sa linya ni Zoe: "5 beses…").
  final int count;

  /// Ang memory na ise-save KAPAG pinindot ang Accept (sa boses ng user,
  /// gaya ng "tandaan mo na…").
  String memory(ZoeLanguage lang) => switch ((habit, lang)) {
        (Habit.morning, ZoeLanguage.english) => 'I prefer morning reminders (8 AM or earlier)',
        (Habit.morning, _) => 'Mas gusto ko ng morning reminders (8 AM o mas maaga)',
        (Habit.evening, ZoeLanguage.english) => 'I prefer evening reminders (6 PM or later)',
        (Habit.evening, _) => 'Mas gusto ko ng reminders sa gabi (6 PM pataas)',
      };
}

/// Mga patakaran ng implicit learning — PURE (walang database).
/// Nate-test sa `flutter test test/memory/habit_rules_test.dart`.
///
/// Laging MUNGKAHI lang: card + Accept, at kapag ON lang ang Long-term memory
/// (tingnan ang HabitWatcher). Walang sine-save nang kusa.
///
///   5+ reminder na ginawa sa huling 30 araw ay 4:00–8:00 AM,
///   at ≥ 60% ng lahat ng reminder sa panahong iyon → [Habit.morning].
///   Pareho para sa 6 PM–11:59 PM → [Habit.evening].
///
/// Hindi na nagmumungkahi kapag:
///   • may memory na tungkol diyan ("Mas gusto ko ng morning…", o kahit
///     "Ayoko ng morning reminders") — [coveredBy]
///   • tinanggihan na ("Huwag") — hindi na kailanman — [canAsk]
///   • naipakita na sa huling [askAgainDays] araw — [canAsk]
class HabitRules {
  HabitRules._();

  /// Ilang reminder ang kailangan bago magmungkahi.
  static const minCount = 5;

  /// Bahagi ng lahat ng reminder (sa [days]) na dapat tumugma.
  static const minShare = 0.6;

  /// Ilang araw pabalik ang tinitingnan (ayon sa petsa ng paggawa).
  static const days = 30;

  /// Naipakita pero hindi sinagot → pwedeng itanong ulit pagkalipas nito.
  static const askAgainDays = 30;

  /// 'HH:mm' → minuto mula hatinggabi. null kapag hindi oras.
  static int? minutes(String time) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return h * 60 + min;
  }

  /// Saang ugali kabilang ang oras na ito? (4:00–8:00 = morning, 18:00–23:59 = evening)
  static Habit? habitAt(int minutes) {
    if (minutes >= 4 * 60 && minutes <= 8 * 60) return Habit.morning;
    if (minutes >= 18 * 60) return Habit.evening;
    return null;
  }

  /// [reminders] = (kailan ginawa, 'HH:mm'). Ang pinakamalakas na ugali, o null.
  static HabitSuggestion? check(
    Iterable<(DateTime createdAt, String time)> reminders, {
    required DateTime now,
  }) {
    final since = now.subtract(const Duration(days: days));
    var total = 0;
    final counts = {for (final h in Habit.values) h: 0};
    for (final (created, time) in reminders) {
      if (created.isBefore(since) || created.isAfter(now)) continue;
      final m = minutes(time);
      if (m == null) continue;
      total++;
      final h = habitAt(m);
      if (h != null) counts[h] = counts[h]! + 1;
    }
    HabitSuggestion? best;
    for (final h in Habit.values) {
      final n = counts[h]!;
      if (n < minCount || n / total < minShare) continue;
      if (best == null || n > best.count) best = HabitSuggestion(h, n);
    }
    return best;
  }

  static final _morningWords = RegExp(r'\b(morning|umaga|maaga|early|aga)\b');
  static final _eveningWords = RegExp(r'\b(evening|night|gabi|tonight|late)\b');

  /// May memory na ba tungkol sa ugaling ito (gusto man o ayaw)?
  static bool coveredBy(Habit habit, Iterable<String> memories) {
    final words = habit == Habit.morning ? _morningWords : _eveningWords;
    return memories.any((m) => words.hasMatch(QueryTerms.fold(m)));
  }

  /// Settings value → pwede bang itanong ngayon?
  ///   null                → oo (hindi pa naitatanong)
  ///   'declined'          → hindi na kailanman
  ///   'shown:yyyy-MM-dd'  → oo kapag ≥ [askAgainDays] araw na ang lumipas
  static bool canAsk(String? state, {required DateTime now}) {
    if (state == null || state.isEmpty) return true;
    if (state == 'declined') return false;
    if (state.startsWith('shown:')) {
      final day = DateTime.tryParse(state.substring(6));
      if (day == null) return true;
      return now.difference(day).inDays >= askAgainDays;
    }
    return false;
  }

  /// Ang settings value kapag naipakita ngayong araw.
  static String shownOn(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'shown:${now.year}-${two(now.month)}-${two(now.day)}';
  }

  /// Settings key para sa ugaling ito.
  static String key(Habit habit) => 'habit_suggest_${habit.name}';
}