import 'package:zoe_remind/database/models/memory_item.dart';
import 'package:zoe_remind/memory/companion_facts.dart';

/// Level 3 — ang alam ni Zoe tungkol sa user, galing sa memories table.
/// Pure (walang database): binubuo mula sa listahan ng [MemoryItem].
///
/// Lahat ito ay SINABI o KINUMPIRMA ng user (confirm card / chip).
class CompanionProfile {
  const CompanionProfile({
    this.nickname,
    this.style,
    this.stressHelp,
    this.wins = const [],
    this.routines = const [],
  });

  /// Walang alam (OFF ang long-term memory, o wala pang sinasabi).
  static const empty = CompanionProfile();

  /// "AC" — ang itatawag ni Zoe sa user.
  final String? nickname;

  /// diretso / malambing. null = karaniwang Zoe.
  final TalkStyle? style;

  /// Ano'ng nakakatulong kapag stressed. null = hindi pa sinasabi.
  final StressHelp? stressHelp;

  /// Mga panalo, pinakabago muna ("Nakapasa ako sa board exam").
  final List<String> wins;

  /// Mga routine, pinakabago muna ("Nag-gy-gym ako tuwing MWF").
  final List<String> routines;

  bool get isEmpty =>
      nickname == null && style == null && stressHelp == null && wins.isEmpty && routines.isEmpty;

  bool get isDiretso => style == TalkStyle.diretso;
  bool get isMalambing => style == TalkStyle.malambing;

  /// [items] = galing sa MemoryRepository.getAll() (pinakabago muna).
  static CompanionProfile from(List<MemoryItem> items) {
    String? nickname;
    TalkStyle? style;
    StressHelp? help;
    final wins = <String>[];
    final routines = <String>[];
    for (final m in items) {
      switch (m.kind) {
        case FactKind.nickname:
          final v = m.value?.trim();
          if (nickname == null && v != null && v.isNotEmpty) nickname = v;
        case FactKind.style:
          style ??= TalkStyle.fromValue(m.value);
        case FactKind.stressHelp:
          help ??= StressHelp.fromValue(m.value);
        case FactKind.win:
          wins.add(m.content);
        case FactKind.routine:
          routines.add(m.content);
        case FactKind.general:
          break;
      }
    }
    return CompanionProfile(
      nickname: nickname,
      style: style,
      stressHelp: help,
      wins: List.unmodifiable(wins),
      routines: List.unmodifiable(routines),
    );
  }
}